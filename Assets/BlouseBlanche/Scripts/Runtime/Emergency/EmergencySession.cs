using System;
using System.Collections.Generic;
using BlouseBlanche.Medical;
using UnityEngine;

namespace BlouseBlanche.Emergency
{
    public sealed class TimedEntry
    {
        public float Minute;
        public string Kind;   // "action", "result", "event", "danger", "dialog"
        public string Text;
    }

    public sealed class PendingResult
    {
        public string Id;
        public float ReadyAt;
    }

    /// <summary>
    /// Intervention SAMU ou urgences : l'état du patient évolue en continu et réagit à chaque geste.
    /// </summary>
    public sealed class EmergencySession
    {
        public readonly EmergencyCase Case;
        public readonly PatientState S;
        public EmergencySetting Setting => Case.Setting;
        public float Minutes { get; private set; }
        public bool ScopeOn, Iv, Cpr, O2, Bavu, Pls, Immobilized;
        public int Shocks, Adrenaline;
        public bool Amiodarone;
        public string Diagnosis, Destination;
        public bool Finished;

        public readonly List<TimedEntry> Log = new List<TimedEntry>();
        public readonly Dictionary<string, float> FirstDone = new Dictionary<string, float>();
        public readonly List<string> HarmfulDone = new List<string>();
        public readonly List<PendingResult> Pending = new List<PendingResult>();
        public readonly Dictionary<string, string> Results = new Dictionary<string, string>();
        public readonly HashSet<string> Asked = new HashSet<string>();

        public event Action<TimedEntry> Logged;

        readonly System.Random rng;
        float rcpMinutes;
        float glucoseEffectAt = -1f, naloxoneAt = -1f, adrenImAt = -1f;
        bool sca_vfDone;

        public EmergencySession(EmergencyCase c, int seed)
        {
            Case = c;
            S = c.Initial != null ? c.Initial() : new PatientState();
            rng = new System.Random(seed);
            AddLog("event", c.Dispatch);
        }

        public bool Done(string id) => FirstDone.ContainsKey(id);

        void AddLog(string kind, string text)
        {
            var e = new TimedEntry { Minute = Minutes, Kind = kind, Text = text };
            Log.Add(e);
            Logged?.Invoke(e);
        }

        // ================================================================== interrogatoire

        public static readonly string[][] Questions =
        {
            new[] { "w_quoi", "Que s'est-il passé ?" },
            new[] { "w_quand", "Depuis combien de temps ?" },
            new[] { "w_antecedents", "Quels sont ses antécédents ?" },
            new[] { "w_traitements", "Quels traitements prend-il ?" },
            new[] { "w_allergies", "Des allergies connues ?" },
            new[] { "w_avant", "Qu'a-t-il fait juste avant ?" },
        };

        public string Ask(string id, out string speaker)
        {
            Asked.Add(id);
            bool witness = !string.IsNullOrEmpty(Case.Witness);
            speaker = witness ? "Témoin (" + Case.Witness + ")" : "Patient";
            if (!witness && (S.Gcs < 13 || !S.Alive)) { speaker = "Patient"; return "… (le patient ne peut pas répondre)"; }
            string a = Case.Answers.TryGetValue(id, out var t) ? t : "Je ne sais pas…";
            AdvanceTime(0.5f);
            AddLog("dialog", speaker + " : " + a);
            return a;
        }

        // ================================================================== actions

        /// <summary>Exécute un geste ; renvoie le texte de résultat.</summary>
        public string Do(string actionId)
        {
            if (Finished) return "";
            var def = EmergencyCatalog.Action(actionId);
            if (def == null) return "";
            if (def.NeedsIv && !Iv) return "Il faut d'abord poser une voie veineuse.";

            if (!FirstDone.ContainsKey(actionId)) FirstDone[actionId] = Minutes;
            if (Case.Harmful.TryGetValue(actionId, out var harm)) HarmfulDone.Add(actionId);

            string text = Apply(def);
            AdvanceTime(def.Minutes);
            AddLog(Case.Harmful.ContainsKey(actionId) ? "danger" : "action", def.Name + " — " + text);
            return text;
        }

        string Apply(EmergencyActionDef def)
        {
            var s = Case;
            switch (def.Id)
            {
                // ------------------------------------------------ bilan
                case "conscience": return "Glasgow " + S.Gcs + " : " + S.ConsciousnessLabel + ".";
                case "ventilation": return BreathingText();
                case "pouls": return S.Pulse ? "Pouls carotidien présent, environ " + Mathf.RoundToInt(S.Hr) + "/min." : "AUCUN POULS CAROTIDIEN.";
                case "pupilles": return F("pupilles", S.Gcs < 6 && !S.Pulse ? "Pupilles en mydriase, peu réactives." : "Pupilles intermédiaires, égales et réactives.");
                case "examen": return F("examen", "Examen sans particularité notable.");
                case "auscultation":
                    if (!S.Pulse) return "Aucun bruit du cœur audible.";
                    return F("auscultation", "Bruits du cœur réguliers à " + Mathf.RoundToInt(S.Hr) + "/min, murmure vésiculaire symétrique.");
                case "abdomen": return F("abdomen", "Abdomen souple, dépressible, indolore.");
                case "temperature": return "Température " + Vitals.F1(S.Temp) + " °C.";

                // ------------------------------------------------ monitorage
                case "scope":
                    ScopeOn = true;
                    return "Scope branché : " + S.RhythmName + (S.Pulse ? ", FC " + Mathf.RoundToInt(S.Hr) + ", PA " + Mathf.RoundToInt(S.Sys) + "/" + Mathf.RoundToInt(S.Dia) + ", SpO2 " + Mathf.RoundToInt(S.Spo2) + " %." : ".");
                case "ecg":
                    if (!S.Pulse) return "Tracé : " + S.RhythmName + ".";
                    if ((s.Condition == Condition.ArretCardiaque && S.Rosc) || s.Condition == Condition.InfarctusST)
                        return F("ecg", "Sus-décalage du segment ST en territoire inférieur (DII, DIII, aVF) : infarctus.");
                    return F("ecg", S.RhythmName + " à " + Mathf.RoundToInt(S.Hr) + "/min, pas de trouble de repolarisation.");
                case "glycemie": return "Glycémie capillaire : " + Vitals.F2(S.Glyc) + " g/L." + (S.Glyc < 0.6f ? " HYPOGLYCÉMIE." : "");

                // ------------------------------------------------ gestes
                case "rcp":
                    Cpr = !Cpr;
                    if (Cpr && S.Pulse) { HarmfulDone.Add("rcp_pouls"); return "Massage débuté… alors que le patient a un pouls !"; }
                    return Cpr ? "Massage cardiaque en cours : 110 compressions/min, relais toutes les 2 minutes." : "Massage interrompu.";
                case "choc": return Shock();
                case "o2":
                    O2 = true;
                    if (!S.Pulse || S.Breathing == Breathing.Absente) return "Masque posé, mais le patient ne respire pas efficacement : il faut ventiler.";
                    return "Oxygène 15 L/min au masque haute concentration.";
                case "bavu":
                    Bavu = true; O2 = true;
                    return S.Breathing == Breathing.Normale && S.Gcs >= 13 ? "Le patient respire et se débat : la ventilation au ballon n'est pas indiquée." : "Ventilation au ballon avec oxygène, thorax qui se soulève bien.";
                case "pls":
                    Pls = true;
                    return S.Pulse && S.Breathing != Breathing.Absente ? "Patient installé en position latérale de sécurité." : "La PLS n'est pas adaptée : le patient ne respire pas, il faut masser.";
                case "vvp": Iv = true; return "Voie veineuse périphérique posée au pli du coude.";
                case "remplissage":
                    if (!S.Pulse) return "Remplissage passé, sans effet visible en l'absence de circulation.";
                    S.Sys = Mathf.Min(S.Sys + (s.Condition == Condition.ChocSeptique || s.Condition == Condition.HemorragieDigestive || s.Condition == Condition.Anaphylaxie ? 12f : 4f), 135f);
                    S.Dia = Mathf.Min(S.Dia + 6f, 80f);
                    S.Hr = Mathf.Max(70f, S.Hr - 4f);
                    return "500 mL de sérum physiologique passés.";
                case "transfusion":
                    if (s.Condition == Condition.HemorragieDigestive) { S.Sys = Mathf.Min(S.Sys + 14f, 125f); S.Hr = Mathf.Max(85f, S.Hr - 10f); return "Deux culots globulaires transfusés : meilleure tolérance."; }
                    HarmfulDone.Add("transfusion");
                    return "Transfusion réalisée… sans indication.";
                case "collier": return "Collier cervical posé.";
                case "matelas": Immobilized = true; return "Patient immobilisé dans le matelas à dépression.";
                case "attelle": return "Membre immobilisé.";
                case "exsufflation":
                    if (s.Condition == Condition.Pneumothorax) { S.Spo2 = 96f; S.Rr = 17f; S.Hr = 92f; S.Pain = 3f; return "Exsufflation réalisée : le poumon se ré-expand, le patient respire mieux."; }
                    HarmfulDone.Add("exsufflation");
                    return "Geste invasif réalisé sans pneumothorax : complication possible.";

                // ------------------------------------------------ médicaments
                case "adrenaline_iv":
                    if (!S.Pulse) { Adrenaline++; return "Adrénaline 1 mg injectée (" + Adrenaline + "e dose)."; }
                    S.Hr = Mathf.Min(170f, S.Hr + 40f); S.Sys = Mathf.Min(220f, S.Sys + 60f);
                    return "Adrénaline IV chez un patient qui a un pouls : tachycardie et poussée hypertensive majeures !";
                case "adrenaline_im":
                    if (s.Condition == Condition.Anaphylaxie) { adrenImAt = Minutes; return "Adrénaline 0,5 mg en intramusculaire dans la cuisse."; }
                    return "Adrénaline IM injectée sans indication.";
                case "amiodarone":
                    if (!S.Pulse) { Amiodarone = true; return "Amiodarone 300 mg IV."; }
                    return "Amiodarone injectée.";
                case "aspirine": return "Aspirine 250 mg IV.";
                case "heparine": return "Héparine IV.";
                case "morphine":
                    if (s.Condition == Condition.Opiaces) { S.Rr = Mathf.Max(0f, S.Rr - 3f); S.Spo2 -= 6f; return "Morphine injectée : la respiration ralentit encore !"; }
                    if (S.Sys < 95f) S.Sys -= 8f;
                    S.Pain = Mathf.Max(1f, S.Pain - 5f);
                    return "Morphine titrée : la douleur diminue nettement.";
                case "ketoprofene":
                    S.Pain = Mathf.Max(1f, S.Pain - (s.Condition == Condition.ColiqueNephretique ? 6f : 2f));
                    return "Kétoprofène 100 mg IV.";
                case "paracetamol":
                    S.Pain = Mathf.Max(1f, S.Pain - 2f);
                    if (S.Temp > 38f) S.Temp -= 0.8f;
                    return "Paracétamol 1 g IV.";
                case "glucose":
                    if (S.Glyc < 0.7f) { S.Glyc = 1.45f; glucoseEffectAt = Minutes; return "Glucose 30 % injecté."; }
                    S.Glyc += 0.6f;
                    return "Glucose injecté (la glycémie n'était pas basse).";
                case "glucagon":
                    if (S.Glyc < 0.7f) { S.Glyc = 1.0f; glucoseEffectAt = Minutes + 3f; return "Glucagon 1 mg IM : effet attendu en quelques minutes."; }
                    return "Glucagon injecté sans hypoglycémie.";
                case "naloxone":
                    if (s.Condition == Condition.Opiaces) { naloxoneAt = Minutes; return "Naloxone titrée."; }
                    return "Naloxone : aucun effet.";
                case "salbutamol":
                    if (S.Breathing == Breathing.Sifflante) { S.Spo2 = Mathf.Min(99f, S.Spo2 + 2f); S.Rr = Mathf.Max(16f, S.Rr - 4f); }
                    return "Nébulisation de salbutamol.";
                case "corticoide": return "Méthylprednisolone IV.";
                case "trinitrine":
                    if (S.Sys < 100f) { S.Sys -= 15f; return "Trinitrine : la tension chute dangereusement !"; }
                    S.Pain = Mathf.Max(2f, S.Pain - 1f);
                    return "Trinitrine sublinguale.";
                case "antibio": return "Antibiothérapie IV débutée (céfotaxime).";
                case "ipp": return "Oméprazole IV.";
            }

            // ------------------------------------------------ examens différés
            if (def.ResultDelay > 0f)
            {
                if (Results.ContainsKey(def.Id)) return "Résultat déjà disponible.";
                foreach (var p in Pending) if (p.Id == def.Id) return "Examen déjà demandé.";
                Pending.Add(new PendingResult { Id = def.Id, ReadyAt = Minutes + def.ResultDelay });
                return "Demandé : résultat dans environ " + Mathf.RoundToInt(def.ResultDelay) + " min.";
            }
            return "Fait.";
        }

        string F(string key, string fallback) => Case.Findings.TryGetValue(key, out var t) ? t : fallback;

        string BreathingText()
        {
            switch (S.Breathing)
            {
                case Breathing.Absente: return "RESPIRATION ABSENTE.";
                case Breathing.Agonique: return "Respiration agonique (gasps) : équivaut à une absence de respiration.";
                case Breathing.Lente: return "Respiration très lente et superficielle : " + Mathf.RoundToInt(S.Rr) + "/min.";
                case Breathing.Sifflante: return "Respiration sifflante, rapide : " + Mathf.RoundToInt(S.Rr) + "/min.";
                case Breathing.Rapide: return "Respiration rapide : " + Mathf.RoundToInt(S.Rr) + "/min.";
                default: return "Respiration normale : " + Mathf.RoundToInt(S.Rr) + "/min.";
            }
        }

        string Shock()
        {
            if (!S.Alive) return "Le patient est décédé.";
            if (!S.Shockable)
            {
                HarmfulDone.Add("choc_inapproprie");
                return S.Pulse ? "Analyse : rythme non choquable, le patient a un pouls. Choc non délivré." : "Analyse : asystolie, rythme non choquable. Continuer le massage.";
            }
            Shocks++;
            float chance = 0.3f + Mathf.Min(2, Adrenaline) * 0.12f + (Amiodarone ? 0.2f : 0f) + (rcpMinutes > 1f ? 0.12f : -0.15f) - S.NoFlowMinutes * 0.04f;
            bool success = rng.NextDouble() < Mathf.Clamp(chance, 0.08f, 0.9f) || (Shocks >= 4 && Adrenaline > 0 && Amiodarone);
            if (success)
            {
                S.Rhythm = Rhythm.Sinusal;
                S.Hr = 108; S.Sys = 96; S.Dia = 58; S.Spo2 = O2 || Bavu ? 93 : 85; S.Rr = 10; S.Gcs = 5;
                S.Breathing = Breathing.Lente;
                S.Rosc = true;
                Cpr = false;
                return "CHOC DÉLIVRÉ (" + Shocks + "e). Reprise d'une activité cardiaque spontanée !";
            }
            return "Choc délivré (" + Shocks + "e) : persistance de la fibrillation ventriculaire. Reprendre le massage.";
        }

        // ================================================================== temps

        public void Tick(float dtMinutes) => AdvanceTime(dtMinutes);

        void AdvanceTime(float dt)
        {
            if (dt <= 0f || Finished) return;
            Minutes += dt;

            // Résultats différés
            for (int i = Pending.Count - 1; i >= 0; i--)
            {
                if (Minutes < Pending[i].ReadyAt) continue;
                string id = Pending[i].Id;
                Pending.RemoveAt(i);
                string res = Case.Results.TryGetValue(id, out var t) ? t : DefaultResult(id);
                Results[id] = res;
                AddLog("result", EmergencyCatalog.ActionName(id) + " : " + res);
            }

            if (!S.Alive) return;

            // Arrêt cardiaque : no-flow / low-flow
            if (!S.Pulse)
            {
                if (Cpr) { S.LowFlowMinutes += dt; rcpMinutes += dt; }
                else S.NoFlowMinutes += dt;
                S.Hr = 0; S.Sys = Cpr ? 45 : 0; S.Dia = Cpr ? 15 : 0; S.Spo2 = 0; S.Rr = Bavu ? 10 : 0; S.Gcs = 3;
                S.Breathing = Bavu ? Breathing.Lente : Breathing.Absente;
                if (S.NoFlowMinutes > 10f || S.NoFlowMinutes + S.LowFlowMinutes > 40f)
                {
                    S.Alive = false;
                    S.Rhythm = Rhythm.Asystolie;
                    AddLog("danger", "Le patient est décédé : réanimation inefficace.");
                }
                else if (S.Rhythm == Rhythm.FibrillationVentriculaire && S.NoFlowMinutes > 8f)
                {
                    S.Rhythm = Rhythm.Asystolie;
                    AddLog("danger", "La fibrillation ventriculaire dégénère en asystolie.");
                }
                return;
            }

            switch (Case.Condition)
            {
                case Condition.ArretCardiaque:
                    // Après reprise : besoin de ventilation/oxygène
                    if (Bavu || O2) S.Spo2 = Mathf.MoveTowards(S.Spo2, 95f, dt * 4f);
                    else S.Spo2 = Mathf.MoveTowards(S.Spo2, 80f, dt * 2f);
                    S.Gcs = Mathf.Min(8, S.Gcs + (Minutes > 20f ? 1 : 0));
                    break;

                case Condition.Hypoglycemie:
                    if (glucoseEffectAt >= 0f && Minutes >= glucoseEffectAt + 1f)
                    {
                        if (S.Gcs < 15) { S.Gcs = Mathf.Min(15, S.Gcs + 3); if (S.Gcs >= 15) AddLog("event", "Le patient se réveille, conscient et orienté."); }
                        S.Hr = Mathf.MoveTowards(S.Hr, 82f, dt * 6f);
                    }
                    else if (glucoseEffectAt < 0f)
                    {
                        S.Glyc = Mathf.Max(0.18f, S.Glyc - dt * 0.004f);
                        int target = S.Glyc < 0.25f ? 5 : S.Glyc < 0.3f ? 7 : 8;
                        S.Gcs = Mathf.Min(S.Gcs, target);
                    }
                    break;

                case Condition.Opiaces:
                    if (naloxoneAt >= 0f && Minutes >= naloxoneAt + 1f)
                    {
                        S.Rr = Mathf.MoveTowards(S.Rr, 15f, dt * 6f);
                        S.Breathing = Breathing.Normale;
                        if (S.Gcs < 14) { S.Gcs = 14; AddLog("event", "Le patient ouvre les yeux et respire normalement."); }
                        S.Spo2 = Mathf.MoveTowards(S.Spo2, O2 ? 98f : 94f, dt * 8f);
                        S.Hr = Mathf.MoveTowards(S.Hr, 88f, dt * 5f);
                    }
                    else if (Bavu) S.Spo2 = Mathf.MoveTowards(S.Spo2, 95f, dt * 7f);
                    else
                    {
                        S.Spo2 = Mathf.Max(40f, S.Spo2 - dt * (O2 ? 0.6f : 1.6f));
                        if (S.Spo2 < 62f) { S.Rhythm = Rhythm.Asystolie; S.Breathing = Breathing.Absente; AddLog("danger", "Arrêt cardio-respiratoire hypoxique !"); }
                    }
                    break;

                case Condition.InfarctusST:
                    if (O2) S.Spo2 = Mathf.MoveTowards(S.Spo2, 99f, dt * 2f);
                    if (!sca_vfDone && Minutes > 16f)
                    {
                        sca_vfDone = true;
                        S.Rhythm = Rhythm.FibrillationVentriculaire;
                        S.Gcs = 3;
                        S.Breathing = Breathing.Agonique;
                        AddLog("danger", "Le patient perd connaissance : FIBRILLATION VENTRICULAIRE !");
                    }
                    break;

                case Condition.Anaphylaxie:
                    if (adrenImAt >= 0f && Minutes >= adrenImAt + 1f)
                    {
                        S.Sys = Mathf.MoveTowards(S.Sys, 112f, dt * 10f);
                        S.Dia = Mathf.MoveTowards(S.Dia, 68f, dt * 6f);
                        S.Hr = Mathf.MoveTowards(S.Hr, 108f, dt * 5f);
                        S.Spo2 = Mathf.MoveTowards(S.Spo2, O2 ? 98f : 95f, dt * 2f);
                        if (S.Breathing == Breathing.Sifflante && Minutes > adrenImAt + 4f) S.Breathing = Breathing.Normale;
                        S.Gcs = 15;
                    }
                    else
                    {
                        S.Sys = Mathf.Max(30f, S.Sys - dt * 2.4f);
                        S.Dia = Mathf.Max(18f, S.Dia - dt * 1.4f);
                        S.Hr = Mathf.Min(160f, S.Hr + dt * 1.2f);
                        S.Spo2 = Mathf.Max(70f, S.Spo2 - dt * (O2 ? 0.2f : 0.7f));
                        if (S.Sys < 60f) S.Gcs = Mathf.Min(S.Gcs, 9);
                        if (S.Sys < 45f) { S.Rhythm = Rhythm.Asystolie; AddLog("danger", "Arrêt cardiaque sur choc anaphylactique !"); }
                    }
                    break;

                case Condition.EmboliePulmonaire:
                    S.Spo2 = O2 ? Mathf.MoveTowards(S.Spo2, 95f, dt * 3f) : Mathf.Max(84f, S.Spo2 - dt * 0.15f);
                    break;

                case Condition.ChocSeptique:
                {
                    bool abx = Done("antibio");
                    int fluids = 0;
                    foreach (var e in Log) if (e.Text.StartsWith("Remplissage")) fluids++;
                    if (fluids >= 2 && abx) S.Sys = Mathf.MoveTowards(S.Sys, 104f, dt * 1.5f);
                    else S.Sys = Mathf.Max(55f, S.Sys - dt * 0.35f);
                    S.Hr = Mathf.Clamp(S.Hr + (S.Sys < 80f ? dt * 0.5f : -dt * 0.3f), 95f, 150f);
                    if (O2) S.Spo2 = Mathf.MoveTowards(S.Spo2, 97f, dt * 2f);
                    break;
                }

                case Condition.HemorragieDigestive:
                    if (!Done("remplissage") && !Done("transfusion")) { S.Sys = Mathf.Max(55f, S.Sys - dt * 0.4f); S.Hr = Mathf.Min(150f, S.Hr + dt * 0.4f); }
                    if (S.Sys < 65f) S.Gcs = Mathf.Min(S.Gcs, 12);
                    break;

                case Condition.Pneumothorax:
                    if (!Done("exsufflation")) S.Spo2 = O2 ? Mathf.MoveTowards(S.Spo2, 95f, dt * 2f) : Mathf.Max(86f, S.Spo2 - dt * 0.1f);
                    break;
            }
        }

        static string DefaultResult(string id)
        {
            switch (id)
            {
                case "bio": return "Bilan sanguin sans anomalie significative.";
                case "gaz": return "Gaz du sang normaux.";
                case "bu": return "Bandelette urinaire négative.";
                case "radio_thorax": return "Radiographie thoracique normale.";
                case "echo": return "Échographie sans anomalie.";
                case "scanner_abdo": return "Scanner abdominal normal.";
                case "angioscanner": return "Pas d'embolie pulmonaire.";
                case "scanner_cerebral": return "Scanner cérébral normal.";
                case "hemocultures": return "Prélevées (résultats différés).";
                default: return "Normal.";
            }
        }

        // ================================================================== évaluation

        public ConsultationResult Evaluate()
        {
            var c = Case;
            var r = new ConsultationResult
            {
                Minutes = Minutes,
                Teaching = c.Teaching,
                CorrectDiagnosis = EmergencyCases.DiagnosisName(c.Diagnosis),
                ChosenDiagnosis = string.IsNullOrEmpty(Diagnosis) ? "Aucun" : EmergencyCases.DiagnosisName(Diagnosis)
            };
            var fb = r.Feedback;

            // Survie (25)
            int survival = S.Alive ? 25 : 0;
            if (S.Alive) fb.Add(new FeedbackItem(FeedbackKind.Good, "Patient vivant à la fin de la prise en charge."));
            else { fb.Add(new FeedbackItem(FeedbackKind.Critical, "Le patient est décédé.")); r.Critical = true; }

            // Gestes critiques (40)
            int totalW = 0, gotW = 0;
            foreach (var need in c.Critical)
            {
                totalW += need.Weight;
                float when = -1f;
                foreach (var id in need.AnyOf) if (FirstDone.TryGetValue(id, out var t) && (when < 0f || t < when)) when = t;
                if (when < 0f) fb.Add(new FeedbackItem(FeedbackKind.Bad, "Geste attendu non réalisé : " + need.Label + "."));
                else if (need.Deadline > 0f && when > need.Deadline)
                {
                    gotW += Mathf.Max(0, need.Weight - 1);
                    fb.Add(new FeedbackItem(FeedbackKind.Warning, need.Label + " : réalisé trop tard (" + Mathf.RoundToInt(when) + " min, objectif < " + Mathf.RoundToInt(need.Deadline) + " min)."));
                }
                else { gotW += need.Weight; fb.Add(new FeedbackItem(FeedbackKind.Good, need.Label + (need.Deadline > 0f ? " (à " + Mathf.Max(0, Mathf.RoundToInt(when)) + " min)" : "") + ".")); }
            }
            int critical = totalW > 0 ? Mathf.RoundToInt(40f * gotW / totalW) : 40;

            // Bilan (15)
            int keyDone = 0;
            foreach (var k in c.KeyExams) if (Done(k)) keyDone++;
            int bilan = c.KeyExams.Count > 0 ? Mathf.RoundToInt(15f * keyDone / c.KeyExams.Count) : 15;
            foreach (var k in c.KeyExams) if (!Done(k)) fb.Add(new FeedbackItem(FeedbackKind.Warning, "Bilan incomplet : " + EmergencyCatalog.ActionName(k) + "."));

            // Diagnostic (10) et orientation (10)
            int diag = Diagnosis == c.Diagnosis ? 10 : 0;
            fb.Add(diag > 0 ? new FeedbackItem(FeedbackKind.Good, "Diagnostic exact : " + r.CorrectDiagnosis + ".")
                            : new FeedbackItem(FeedbackKind.Bad, "Diagnostic : " + r.ChosenDiagnosis + ". Il s'agissait de : " + r.CorrectDiagnosis + "."));
            int dest = 0;
            if (!S.Alive) dest = 0;
            else if (Destination == c.Destination) { dest = 10; fb.Add(new FeedbackItem(FeedbackKind.Good, "Orientation : " + EmergencyCatalog.DestinationName(Destination) + ".")); }
            else if (!string.IsNullOrEmpty(Destination) && c.AcceptableDestinations.Contains(Destination)) { dest = 6; fb.Add(new FeedbackItem(FeedbackKind.Info, "Orientation acceptable. L'idéal : " + EmergencyCatalog.DestinationName(c.Destination) + ".")); }
            else fb.Add(new FeedbackItem(FeedbackKind.Bad, "Orientation inadaptée. Il fallait : " + EmergencyCatalog.DestinationName(c.Destination) + "."));

            // Sécurité
            int penalty = 0;
            foreach (var h in HarmfulDone)
            {
                penalty += 10;
                string why = c.Harmful.TryGetValue(h, out var w) ? w : h == "choc_inapproprie" ? "Choc électrique sur un rythme non choquable." : h == "rcp_pouls" ? "Massage cardiaque chez un patient qui a un pouls." : "Geste sans indication.";
                bool grave = why.StartsWith("Faute grave");
                if (grave) r.Critical = true;
                fb.Add(new FeedbackItem(grave ? FeedbackKind.Critical : FeedbackKind.Bad, EmergencyCatalog.ActionName(h) + " : " + why));
            }

            r.Approach = bilan;
            r.Treatment = critical;
            r.Diagnosis = diag;
            r.Orientation = dest;
            r.Efficiency = survival;
            r.Hygiene = -penalty;
            r.Total = Mathf.Clamp(survival + critical + bilan + diag + dest - penalty, 0, 100);
            if (!S.Alive) r.Total = Mathf.Min(r.Total, 30);
            r.Grade = r.Total >= 90 ? "A+" : r.Total >= 80 ? "A" : r.Total >= 65 ? "B" : r.Total >= 50 ? "C" : "D";
            r.Stars = r.Total >= 90 ? 5 : r.Total >= 78 ? 4 : r.Total >= 62 ? 3 : r.Total >= 45 ? 2 : 1;
            return r;
        }
    }
}
