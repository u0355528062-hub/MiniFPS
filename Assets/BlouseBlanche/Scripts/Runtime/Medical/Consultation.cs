using System.Collections.Generic;
using BlouseBlanche.Characters;
using UnityEngine;

namespace BlouseBlanche.Medical
{
    /// <summary>Dossier patient (identité + cas + constantes).</summary>
    public sealed class PatientRecord
    {
        public string FirstName, LastName;
        public Sex Sex;
        public int Age;
        public int Seed;
        public CaseDef Case;
        public Vitals Vitals;
        public HumanAppearance Look;
        public HumanAppearance CompanionLook;
        public string[] History, Meds, Allergies;
        public string Notes;

        public bool IsChild => Age < 13;
        public string FullName => FirstName + " " + LastName;
        public string DisplayName => IsChild ? FirstName + " " + LastName : (Sex == Sex.Homme ? "M. " : "Mme ") + LastName;
        public string ShortName => IsChild ? FirstName : (Sex == Sex.Homme ? "M. " : "Mme ") + LastName;
        public string AgeLabel => Age + (Age > 1 ? " ans" : " an");
    }

    public enum FeedbackKind { Good, Info, Warning, Bad, Critical }

    public sealed class FeedbackItem
    {
        public FeedbackKind Kind;
        public string Text;
        public FeedbackItem(FeedbackKind k, string t) { Kind = k; Text = t; }
    }

    public sealed class ConsultationResult
    {
        public int Total;
        public int Approach, Diagnosis, Treatment, Orientation, Efficiency, Hygiene;
        public bool Critical;
        public string Grade;
        public int Stars;
        public int Fee;
        public float ReputationDelta;
        public float Minutes;
        public readonly List<FeedbackItem> Feedback = new List<FeedbackItem>();
        public string Teaching;
        public string CorrectDiagnosis;
        public string ChosenDiagnosis;
    }

    /// <summary>Déroulé d'une consultation : interrogatoire, examens, décisions.</summary>
    public sealed class ConsultationSession
    {
        public readonly PatientRecord Patient;
        public CaseDef Case => Patient.Case;
        public float Minutes;
        public float WaitedMinutes;
        public bool HandsWashed;

        public readonly List<string> AskedQuestions = new List<string>();
        public readonly List<KeyValuePair<string, Finding>> ExamResults = new List<KeyValuePair<string, Finding>>();
        public string Diagnosis;
        public readonly HashSet<string> Treatments = new HashSet<string>();
        public Orientation? Orientation;
        public float OrientationMinute = -1f;

        public ConsultationSession(PatientRecord patient) { Patient = patient; }

        public bool HasAsked(string q) => AskedQuestions.Contains(q);
        public bool HasExam(string e)
        {
            foreach (var kv in ExamResults) if (kv.Key == e) return true;
            return false;
        }

        string Speaker => !string.IsNullOrEmpty(Case.Companion) ? "(" + Case.Companion + ") " : "";

        public string Opening => Speaker + Case.Opening;

        /// <summary>Réponse du patient (ou de l'accompagnant) à une question.</summary>
        public string Answer(string questionId)
        {
            if (!AskedQuestions.Contains(questionId)) AskedQuestions.Add(questionId);
            string text;
            if (Case.Answers.TryGetValue(questionId, out var a)) text = a;
            else
            {
                switch (questionId)
                {
                    case "q_antecedents":
                        text = Patient.History != null && Patient.History.Length > 0 ? "Oui : " + string.Join(", ", Patient.History).ToLowerInvariant() + "." : "Non, aucun antécédent particulier.";
                        break;
                    case "q_traitements":
                        text = Patient.Meds != null && Patient.Meds.Length > 0 ? "Oui : " + string.Join(", ", Patient.Meds) + "." : "Non, aucun traitement.";
                        break;
                    case "q_allergies":
                        text = Patient.Allergies != null && Patient.Allergies.Length > 0 ? "Oui, je suis allergique : " + string.Join(", ", Patient.Allergies).ToLowerInvariant() + "." : "Non, aucune allergie connue.";
                        break;
                    case "q_grossesse":
                        text = Patient.Sex == Sex.Femme && Patient.Age >= 14 && Patient.Age <= 50 ? "Non, ce n'est pas possible." : "Ce n'est pas concerné.";
                        break;
                    default:
                        text = MedicalCatalog.Question(questionId)?.DefaultAnswer ?? "Je ne sais pas trop…";
                        break;
                }
            }
            return Speaker + text;
        }

        /// <summary>Résultat d'un examen (constantes calculées, sinon résultat du cas, sinon examen normal).</summary>
        public Finding Examine(string examId)
        {
            var f = ComputeFinding(examId);
            for (int i = 0; i < ExamResults.Count; i++)
                if (ExamResults[i].Key == examId) { ExamResults[i] = new KeyValuePair<string, Finding>(examId, f); return f; }
            ExamResults.Add(new KeyValuePair<string, Finding>(examId, f));
            return f;
        }

        Finding ComputeFinding(string examId)
        {
            var v = Patient.Vitals;
            bool child = Patient.IsChild;
            if (Case.Findings.TryGetValue(examId, out var custom)) return custom;
            switch (examId)
            {
                case "ex_ta":
                {
                    var s = Severity.Normal;
                    if (!child && (v.Sys >= 140 || v.Dia >= 90)) s = Severity.Attention;
                    if (v.Sys >= 180 || v.Dia >= 110) s = Severity.Critique;
                    if (v.Hr > (child ? 130 : 100) || v.Irregular) s = s == Severity.Critique ? s : Severity.Attention;
                    return new Finding("TA " + v.Sys + "/" + v.Dia + " mmHg — pouls " + v.Hr + "/min, " + (v.Irregular ? "irrégulier." : "régulier."), s);
                }
                case "ex_temp":
                {
                    var s = v.Temp >= 40f ? Severity.Critique : v.Temp >= 38f ? Severity.Attention : Severity.Normal;
                    return new Finding("Température : " + Vitals.F1(v.Temp) + " °C.", s);
                }
                case "ex_spo2":
                {
                    var s = v.Spo2 < 92 ? Severity.Critique : v.Spo2 < 95 ? Severity.Attention : Severity.Normal;
                    return new Finding("SpO2 " + v.Spo2 + " % en air ambiant — fréquence respiratoire " + v.Rr + "/min.", s);
                }
                case "ex_glyc":
                {
                    var s = v.Glyc < 0.6f || v.Glyc > 3f ? Severity.Critique : v.Glyc > 1.8f ? Severity.Attention : Severity.Normal;
                    return new Finding("Glycémie capillaire : " + Vitals.F2(v.Glyc) + " g/L.", s);
                }
                case "ex_poids":
                {
                    float bmi = v.Bmi;
                    var s = !child && (bmi >= 30f || bmi < 18.5f) ? Severity.Attention : Severity.Normal;
                    string txt = "Poids " + Vitals.F1(v.Weight) + " kg — taille " + Vitals.F2(v.Height) + " m";
                    if (!child) txt += " — IMC " + Vitals.F1(bmi);
                    return new Finding(txt + ".", s);
                }
            }
            var def = MedicalCatalog.Exam(examId);
            return new Finding(def?.DefaultFinding ?? "Examen sans particularité.", Severity.Normal);
        }

        // ================================================================== évaluation

        public ConsultationResult Evaluate()
        {
            var c = Case;
            var r = new ConsultationResult
            {
                Minutes = Minutes,
                Teaching = c.Teaching,
                CorrectDiagnosis = MedicalCatalog.DiagnosisName(c.Diagnosis),
                ChosenDiagnosis = string.IsNullOrEmpty(Diagnosis) ? "Aucun" : MedicalCatalog.DiagnosisName(Diagnosis)
            };
            var fb = r.Feedback;

            // --- Démarche (20)
            int kq = 0; foreach (var q in c.KeyQuestions) if (AskedQuestions.Contains(q)) kq++;
            int ke = 0; foreach (var e in c.KeyExams) if (HasExam(e)) ke++;
            float qf = c.KeyQuestions.Count == 0 ? 1f : kq / (float)c.KeyQuestions.Count;
            float ef = c.KeyExams.Count == 0 ? 1f : ke / (float)c.KeyExams.Count;
            r.Approach = Mathf.RoundToInt(qf * 8f + ef * 12f);
            foreach (var q in c.KeyQuestions)
                if (!AskedQuestions.Contains(q)) fb.Add(new FeedbackItem(FeedbackKind.Warning, "Question clé oubliée : « " + MedicalCatalog.QuestionText(q) + " »"));
            foreach (var e in c.KeyExams)
                if (!HasExam(e)) fb.Add(new FeedbackItem(FeedbackKind.Warning, "Examen clé non réalisé : " + MedicalCatalog.ExamName(e) + "."));
            if (qf >= 1f && ef >= 1f) fb.Add(new FeedbackItem(FeedbackKind.Good, "Démarche clinique complète : interrogatoire et examens pertinents."));

            // --- Diagnostic (35)
            if (Diagnosis == c.Diagnosis) { r.Diagnosis = 35; fb.Add(new FeedbackItem(FeedbackKind.Good, "Bon diagnostic : " + r.CorrectDiagnosis + ".")); }
            else if (!string.IsNullOrEmpty(Diagnosis) && c.PartialDiagnoses.Contains(Diagnosis)) { r.Diagnosis = 15; fb.Add(new FeedbackItem(FeedbackKind.Warning, "Diagnostic proche mais inexact. Il s'agissait de : " + r.CorrectDiagnosis + ".")); }
            else { r.Diagnosis = 0; fb.Add(new FeedbackItem(FeedbackKind.Bad, "Diagnostic erroné (" + r.ChosenDiagnosis + "). Il s'agissait de : " + r.CorrectDiagnosis + ".")); }

            // --- Traitement (30)
            float tx = 0f;
            int groupsOk = 0;
            foreach (var group in c.RequiredTx)
            {
                bool ok = false;
                foreach (var id in group) if (Treatments.Contains(id)) ok = true;
                if (ok) groupsOk++;
                else
                {
                    var names = new List<string>();
                    foreach (var id in group) names.Add(MedicalCatalog.TreatmentName(id));
                    fb.Add(new FeedbackItem(FeedbackKind.Bad, "Traitement indispensable manquant : " + string.Join(" ou ", names) + "."));
                }
            }
            tx += c.RequiredTx.Count == 0 ? 18f : 18f * groupsOk / c.RequiredTx.Count;
            int recOk = 0;
            foreach (var id in c.RecommendedTx) if (Treatments.Contains(id)) recOk++;
            tx += c.RecommendedTx.Count == 0 ? 8f : 8f * recOk / c.RecommendedTx.Count;
            bool harmful = false;
            foreach (var id in Treatments)
            {
                if (c.HarmfulTx.TryGetValue(id, out var why))
                {
                    harmful = true;
                    tx -= 12f;
                    bool grave = why.StartsWith("FAUTE GRAVE");
                    if (grave) r.Critical = true;
                    fb.Add(new FeedbackItem(grave ? FeedbackKind.Critical : FeedbackKind.Bad, MedicalCatalog.TreatmentName(id) + " : " + why));
                }
                else if (c.DiscouragedTx.TryGetValue(id, out var why2))
                {
                    tx -= 4f;
                    fb.Add(new FeedbackItem(FeedbackKind.Warning, MedicalCatalog.TreatmentName(id) + " : " + why2));
                }
                else if (!c.RecommendedTx.Contains(id) && !c.AcceptableTx.Contains(id) && !InRequired(c, id))
                {
                    tx -= 2f;
                    fb.Add(new FeedbackItem(FeedbackKind.Info, MedicalCatalog.TreatmentName(id) + " : non indiqué dans cette situation."));
                }
            }
            if (!harmful) tx += 4f;
            if (groupsOk == c.RequiredTx.Count && c.RequiredTx.Count > 0 && !harmful) fb.Add(new FeedbackItem(FeedbackKind.Good, "Prescription adaptée."));
            r.Treatment = Mathf.Clamp(Mathf.RoundToInt(tx), 0, 30);

            // --- Orientation (10)
            var chosen = Orientation ?? Medical.Orientation.Domicile;
            if (chosen == c.Orientation) { r.Orientation = 10; fb.Add(new FeedbackItem(FeedbackKind.Good, "Orientation juste : " + OrientationInfo.Name(chosen) + ".")); }
            else if (c.AcceptableOrientations.Contains(chosen)) { r.Orientation = 6; fb.Add(new FeedbackItem(FeedbackKind.Info, "Orientation acceptable. L'idéal : " + OrientationInfo.Name(c.Orientation) + ".")); }
            else
            {
                r.Orientation = 0;
                if (c.Orientation == Medical.Orientation.Urgences15)
                {
                    r.Critical = true;
                    fb.Add(new FeedbackItem(FeedbackKind.Critical, "URGENCE VITALE MANQUÉE : il fallait appeler immédiatement le 15 (SAMU)."));
                }
                else if (chosen == Medical.Orientation.Urgences15)
                    fb.Add(new FeedbackItem(FeedbackKind.Bad, "Appel du 15 injustifié : le SAMU a été mobilisé inutilement."));
                else
                    fb.Add(new FeedbackItem(FeedbackKind.Warning, "Orientation inadaptée. Il fallait : " + OrientationInfo.Name(c.Orientation) + "."));
            }

            // --- Efficacité (5)
            if (c.Orientation == Medical.Orientation.Urgences15 && chosen == Medical.Orientation.Urgences15)
            {
                float t = OrientationMinute >= 0f ? OrientationMinute : Minutes;
                if (t <= 10f) { r.Efficiency = 5; fb.Add(new FeedbackItem(FeedbackKind.Good, "Appel du 15 rapide (" + Mathf.RoundToInt(t) + " min) : chaque minute compte.")); }
                else { r.Efficiency = 0; fb.Add(new FeedbackItem(FeedbackKind.Bad, "Prise en charge trop lente : " + Mathf.RoundToInt(t) + " min avant d'appeler le 15.")); }
            }
            else
            {
                if (Minutes <= c.IdealMinutes) r.Efficiency = 5;
                else if (Minutes <= c.IdealMinutes * 1.5f) r.Efficiency = 3;
                else { r.Efficiency = 1; fb.Add(new FeedbackItem(FeedbackKind.Info, "Consultation longue (" + Mathf.RoundToInt(Minutes) + " min) : certains examens n'étaient pas utiles.")); }
            }

            // --- Hygiène (bonus)
            r.Hygiene = HandsWashed ? 3 : 0;
            fb.Add(HandsWashed
                ? new FeedbackItem(FeedbackKind.Good, "Hygiène des mains respectée avant l'examen.")
                : new FeedbackItem(FeedbackKind.Info, "Pensez à vous laver les mains (lavabo ou gel) avant chaque patient."));

            r.Total = Mathf.Clamp(r.Approach + r.Diagnosis + r.Treatment + r.Orientation + r.Efficiency + r.Hygiene, 0, 100);
            if (r.Critical) r.Total = Mathf.Min(r.Total, 25);

            r.Grade = r.Total >= 90 ? "A+" : r.Total >= 80 ? "A" : r.Total >= 65 ? "B" : r.Total >= 50 ? "C" : "D";
            r.Stars = r.Total >= 90 ? 5 : r.Total >= 78 ? 4 : r.Total >= 62 ? 3 : r.Total >= 45 ? 2 : 1;
            r.Fee = 30 + (Patient.Age < 6 ? 5 : 0);
            r.ReputationDelta = r.Critical ? -8f : (r.Total - 60) / 10f - Mathf.Max(0f, WaitedMinutes - 30f) / 30f;
            return r;
        }

        static bool InRequired(CaseDef c, string id)
        {
            foreach (var g in c.RequiredTx) foreach (var x in g) if (x == id) return true;
            return false;
        }
    }
}
