using System;
using System.Collections;
using BlouseBlanche.Characters;
using BlouseBlanche.Core;
using BlouseBlanche.Emergency;
using BlouseBlanche.Medical;
using BlouseBlanche.UI;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    /// <summary>
    /// Prototype SAMU / urgences : un patient, un lieu, une intervention où le temps s'écoule en continu.
    /// Fait vivre la séance (<see cref="EmergencySession"/>) : scope du décor, bips, alarmes, massage,
    /// ventilation, choc électrique, plans caméra sur les gestes.
    /// </summary>
    public sealed class EmergencyController : MonoBehaviour
    {
        /// <summary>Écoulement du temps pendant la prise en charge (minutes de jeu par seconde réelle).</summary>
        public const float MinutesPerSecond = 0.1f;
        /// <summary>Ralenti quand la roue du matériel est ouverte.</summary>
        const float WheelSlowMotion = 0.25f;
        const float CompressionsPerMinute = 110f;

        public EmergencyCase Case { get; private set; }
        public EmergencyLocation Location { get; private set; }
        public EmergencySession Session { get; private set; }
        public EmergencyPatient Patient { get; private set; }
        public MonitorSignal Signal { get; private set; }
        public LiveMonitor Monitor { get; private set; }
        public EmergencyTool? Tool { get; private set; }
        public bool Busy { get; private set; }
        public bool SlowMotion { get; set; }
        public string PatientLabel { get; private set; }
        public string LastResult { get; private set; }

        /// <summary>Un cas est chargé (approche ou prise en charge).</summary>
        public bool Active => Case != null;
        /// <summary>Prise en charge en cours.</summary>
        public bool InCare => Session != null && !Session.Finished;
        public bool HasWitness => Case != null && !string.IsNullOrEmpty(Case.Witness);
        public bool CanConclude => InCare && !Busy && (!Session.S.Alive || (!string.IsNullOrEmpty(Session.Diagnosis) && !string.IsNullOrEmpty(Session.Destination)));

        public event Action CareStarted;
        public event Action Changed;
        /// <summary>Entrée du journal (séance, ou question posée par le joueur : Kind = "question").</summary>
        public event Action<TimedEntry> Logged;
        public event Action<ConsultationResult> Finished;

        GameRoot root;
        ClinicWorld world;
        WorldKit kit;
        Transform actors;
        int seed;
        float lastMinutes;
        float cprPhase, bagTimer, alarmTimer;
        Vector3 monitorPos;

        public void Initialize(GameRoot root, ClinicWorld world, WorldKit kit)
        {
            this.root = root;
            this.world = world;
            this.kit = kit;
        }

        // ================================================================== cycle de vie

        public void Begin(EmergencyCase c, int seed)
        {
            End();
            Case = c;
            this.seed = seed;
            Location = c.Setting == EmergencySetting.Samu ? world.Salon : world.ErBox;
            actors = WorldKit.Group(world.Root, "Intervention_" + c.Id, Vector3.zero);
            Patient = EmergencyPatient.Spawn(kit, Location, c, seed, actors, TakeCharge);

            var r = new System.Random(seed + 7);
            string last = NameGenerator.LastName(r);
            PatientLabel = (Patient.Sex == Sex.Homme ? "M. " : "Mme ") + last + ", " + Patient.Age + " ans";

            Signal = new MonitorSignal(seed);
            Signal.Beat += OnBeat;
            var screen = FindScreen(Location, c.Setting);
            Monitor = LiveMonitor.Attach(screen, Signal);
            monitorPos = screen != null ? screen.bounds.center : Location.PatientPelvis + Vector3.up;

            Tool = null;
            Busy = false;
            SlowMotion = false;
            LastResult = "";
            cprPhase = 0f;
            bagTimer = 0f;
            alarmTimer = 0f;

            if (c.Setting == EmergencySetting.Samu)
            {
                root.Audio.PlayAt(Sfx.Siren, Location.PlayerSpawn + new Vector3(10f, 1.5f, -6f), 0.55f, 0f);
                root.UI.Toast("Régulation du SAMU", c.Dispatch, ToastKind.Urgent, 10f);
                if (HasWitness) StartCoroutine(SayLater(Capitalize(c.Witness), "Par ici ! Vite, je vous en prie !", 2.2f, true));
            }
            else
            {
                root.Audio.PlayUI(Sfx.Notify, 0.7f);
                root.UI.Toast("Infirmière d'accueil · Box 3", c.Dispatch, ToastKind.Warning, 10f);
            }
            Changed?.Invoke();
        }

        /// <summary>Retire le patient, rend l'écran du décor, arrête la séance.</summary>
        public void End()
        {
            StopAllCoroutines();
            if (Patient != null) Patient.Despawn();
            if (Monitor != null) Destroy(Monitor);
            if (actors != null) Destroy(actors.gameObject);
            if (Signal != null) Signal.Beat -= OnBeat;
            Patient = null;
            Monitor = null;
            actors = null;
            Signal = null;
            Session = null;
            Case = null;
            Location = null;
            Tool = null;
            Busy = false;
            SlowMotion = false;
        }

        static Renderer FindScreen(EmergencyLocation loc, EmergencySetting s)
        {
            if (loc == null || loc.Root == null) return null;
            var t = loc.Root.Find(s == EmergencySetting.Samu ? "Defibrillateur/Ecran" : "Scope/Ecran");
            return t != null ? t.GetComponent<Renderer>() : null;
        }

        /// <summary>Le joueur s'agenouille près du patient : début du chronomètre.</summary>
        void TakeCharge()
        {
            if (Case == null || Session != null) return;
            Session = new EmergencySession(Case, seed);
            Session.Logged += OnSessionLog;
            lastMinutes = 0f;
            Patient.Session = Session;
            Patient.InCare = true;
            if (Monitor != null) Monitor.Session = Session;
            root.Audio.PlayUI(Sfx.UiConfirm, 0.7f);
            CareStarted?.Invoke();
            Changed?.Invoke();
        }

        // ================================================================== temps réel

        void Update()
        {
            if (Session == null || Patient == null) return;
            float dt = Time.deltaTime;
            if (dt <= 0f) return;

            if (!Session.Finished)
            {
                Session.Tick(dt * MinutesPerSecond * (SlowMotion ? WheelSlowMotion : 1f));
                SyncClock();
            }

            var s = Session.S;
            bool stElevation = Case.Condition == Condition.InfarctusST || (Case.Condition == Condition.ArretCardiaque && s.Rosc);
            Signal.Connected = Session.ScopeOn;
            Signal.Tick(dt, s, Session.Cpr && !Session.Finished, Session.Bavu, stElevation);

            if (Session.Finished) { if (Monitor != null) Monitor.Alarm = false; return; }

            // Massage cardiaque : compressions visibles et audibles
            if (Session.Cpr)
            {
                cprPhase += dt * CompressionsPerMinute / 60f;
                if (cprPhase >= 1f)
                {
                    cprPhase -= 1f;
                    Patient.CompressionVisual = 1f;
                    root.Audio.PlayAt(Sfx.Compression, ChestPoint(), 0.45f, 0.06f);
                }
            }
            else cprPhase = 0f;

            // Ventilation au ballon tant que la respiration est insuffisante
            bool needsBag = !s.Pulse || s.Breathing == Breathing.Absente || s.Breathing == Breathing.Agonique || s.Breathing == Breathing.Lente;
            if (Session.Bavu && needsBag && s.Alive)
            {
                bagTimer -= dt;
                if (bagTimer <= 0f)
                {
                    bagTimer = Session.Cpr ? 8f : 5f;
                    root.Audio.PlayAt(Sfx.BagValve, HeadPoint(), 0.45f, 0.04f);
                }
            }

            // Alarme du scope
            bool alarm = Session.ScopeOn && (!s.Pulse || s.Spo2 < 88f || s.Sys < 85f || s.Hr > 140f || s.Hr < 45f);
            if (Monitor != null) Monitor.Alarm = alarm;
            if (alarm)
            {
                alarmTimer -= dt;
                if (alarmTimer <= 0f)
                {
                    alarmTimer = 2.4f;
                    root.Audio.PlayAt(Sfx.Alarm, monitorPos, 0.3f, 0f);
                }
            }
            else alarmTimer = 0.5f;
        }

        void SyncClock()
        {
            float delta = Session.Minutes - lastMinutes;
            if (delta > 0f) root.Clock.Advance(delta);
            lastMinutes = Session.Minutes;
        }

        void OnBeat()
        {
            if (Session == null || !Session.ScopeOn || Session.Finished) return;
            var src = root.Audio.PlayAt(Sfx.ScopeBeep, monitorPos, 0.22f, 0f);
            // Comme un vrai scope : le bip descend dans les graves quand la saturation baisse.
            if (src != null) src.pitch = Mathf.Lerp(0.78f, 1.08f, Mathf.InverseLerp(80f, 99f, Session.S.Spo2));
        }

        void OnSessionLog(TimedEntry e)
        {
            Logged?.Invoke(e);
            switch (e.Kind)
            {
                case "danger":
                    root.Audio.PlayUI(Sfx.Urgent, 0.8f);
                    root.PostFX.Pulse(0.25f);
                    root.UI.Toast("Alerte", e.Text, ToastKind.Urgent, 7f);
                    break;
                case "result":
                    root.Audio.PlayUI(Sfx.Notify, 0.6f);
                    root.UI.Toast("Résultat disponible", e.Text, ToastKind.Info, 7f);
                    break;
                case "event":
                    if (Session != null && Session.Log.Count > 1) root.UI.Toast("Évolution", e.Text, ToastKind.Success, 6f);
                    break;
            }
            Changed?.Invoke();
        }

        // ================================================================== matériel et gestes

        public void SelectTool(EmergencyTool? tool)
        {
            if (Case == null) return;
            if (tool.HasValue && !EmergencyCatalog.ToolAvailable(tool.Value, Case.Setting)) return;
            Tool = tool;
            root.Audio.PlayUI(Sfx.UiClick, 0.5f);
            Changed?.Invoke();
        }

        public void Do(string actionId)
        {
            if (!InCare || Busy) return;
            var def = EmergencyCatalog.Action(actionId);
            if (def == null) return;
            if (def.NeedsIv && !Session.Iv)
            {
                root.Audio.PlayUI(Sfx.UiBack, 0.7f);
                root.UI.Toast("Voie veineuse nécessaire", def.Name + " : posez d'abord une voie veineuse (matériel de perfusion).", ToastKind.Warning);
                return;
            }
            if (Tool != def.Tool) Tool = def.Tool;
            StartCoroutine(ActionRoutine(def));
        }

        IEnumerator ActionRoutine(EmergencyActionDef def)
        {
            Busy = true;
            Changed?.Invoke();
            Vector3 target = FocusPoint(def.Id);
            var care = Location.CareShot;
            Vector3 camPos = Vector3.Lerp(care.position, target, 0.4f) + Vector3.up * 0.15f;
            root.CameraDirector.SetShotLookAt(camPos, target, 42f, 0.7f, 0.002f);

            string text;
            switch (def.Id)
            {
                case "choc":
                {
                    root.Audio.PlayAt(Sfx.DefibCharge, target, 0.8f, 0f);
                    root.UI.Subtitle("Vous", "Analyse en cours… Écartez-vous du patient !", 2.2f);
                    yield return new WaitForSeconds(2.0f);
                    int before = Session.Shocks;
                    text = Session.Do("choc");
                    if (Session.Shocks > before)
                    {
                        root.Audio.PlayAt(Sfx.DefibShock, target, 1f, 0f);
                        Patient.ShockJolt();
                        root.PostFX.Pulse(0.35f);
                    }
                    else root.Audio.PlayAt(Sfx.DeviceBeep, target, 0.7f, 0f);
                    break;
                }
                case "auscultation":
                    if (Session.S.Pulse) root.Audio.PlayAt(Sfx.Heartbeat, target, 0.7f, 0.02f);
                    yield return new WaitForSeconds(1.4f);
                    text = Session.Do(def.Id);
                    break;
                case "scope":
                case "ecg":
                case "glycemie":
                case "temperature":
                    yield return new WaitForSeconds(0.6f);
                    root.Audio.PlayAt(Sfx.DeviceBeep, target, 0.7f, 0.02f);
                    yield return new WaitForSeconds(0.4f);
                    text = Session.Do(def.Id);
                    break;
                case "bavu":
                    root.Audio.PlayAt(Sfx.BagValve, target, 0.6f, 0.04f);
                    yield return new WaitForSeconds(0.8f);
                    text = Session.Do(def.Id);
                    bagTimer = 3f;
                    break;
                case "rcp":
                    yield return new WaitForSeconds(0.3f);
                    text = Session.Do(def.Id);
                    break;
                default:
                    if (def.Category == ActionCategory.Medicament || def.Tool == EmergencyTool.Perfusion) root.Audio.PlayAt(Sfx.Paper, target, 0.4f, 0.1f);
                    yield return new WaitForSeconds(def.ResultDelay > 0f ? 0.5f : 0.9f);
                    text = Session.Do(def.Id);
                    break;
            }
            SyncClock();
            LastResult = def.Name + " : " + text;
            if (def.Id == "conscience" && Session.S.Gcs >= 13 && Session.S.Alive && Case.PatientTalks)
                Patient.Speak(1.6f, false);

            yield return new WaitForSeconds(0.35f);
            root.CameraDirector.SetShot(care.position, care.rotation, 50f, 0.8f);
            Busy = false;
            Changed?.Invoke();
        }

        // ================================================================== interrogatoire et décisions

        public void Ask(string questionId)
        {
            if (!InCare || Busy) return;
            string question = null;
            foreach (var q in EmergencySession.Questions) if (q[0] == questionId) question = q[1];
            if (question == null) return;
            Logged?.Invoke(new TimedEntry { Minute = Session.Minutes, Kind = "question", Text = "Vous : " + question });
            string answer = Session.Ask(questionId, out string speaker);
            SyncClock();
            Patient.Speak(Mathf.Clamp(answer.Length * 0.045f, 1.2f, 6f), HasWitness);
            root.UI.Subtitle(speaker, answer);
            Changed?.Invoke();
        }

        public void SetDiagnosis(string id)
        {
            if (!InCare) return;
            Session.Diagnosis = id;
            root.Audio.PlayUI(Sfx.Pen, 0.35f);
            Changed?.Invoke();
        }

        public void SetDestination(string id)
        {
            if (!InCare) return;
            Session.Destination = id;
            root.Audio.PlayUI(Sfx.Pen, 0.35f);
            Changed?.Invoke();
        }

        public void Conclude()
        {
            if (!CanConclude) return;
            Session.Finished = true;
            if (Monitor != null) Monitor.Alarm = false;
            var result = Session.Evaluate();
            root.Audio.PlayUI(result.Total >= 65 && !result.Critical ? Sfx.Success : Sfx.Fail, 0.8f);
            Changed?.Invoke();
            Finished?.Invoke(result);
        }

        // ================================================================== mise en scène

        IEnumerator SayLater(string speaker, string text, float delay, bool witness)
        {
            yield return new WaitForSeconds(delay);
            if (Patient == null) yield break;
            Patient.Speak(Mathf.Clamp(text.Length * 0.045f, 1.2f, 4f), witness);
            root.UI.Subtitle(speaker, text);
        }

        static string Capitalize(string s) => string.IsNullOrEmpty(s) ? s : char.ToUpperInvariant(s[0]) + s.Substring(1);

        Vector3 ChestPoint() => Patient != null && Patient.Rig != null ? Patient.Rig.ChestCenter : Location.PatientPelvis;
        Vector3 HeadPoint() => Patient != null && Patient.Rig != null ? Patient.Rig.HeadCenter : Location.PatientPelvis;

        Vector3 FocusPoint(string actionId)
        {
            var rig = Patient != null ? Patient.Rig : null;
            if (rig == null) return Location.PatientPelvis + Vector3.up * 0.3f;
            switch (actionId)
            {
                case "conscience": case "ventilation": case "pupilles": case "o2": case "bavu": case "naloxone": case "temperature":
                    return rig.HeadCenter;
                case "pouls": case "collier":
                    return rig.Neck.position;
                case "abdomen": case "echo": case "scanner_abdo":
                    return rig.BellyCenter;
                case "vvp": case "remplissage": case "transfusion": case "bio": case "gaz": case "hemocultures":
                    return rig.ElbowL.position;
                case "glycemie":
                    return rig.WristL.position;
                case "attelle": case "matelas":
                    return rig.KneeR.position;
                default:
                    return rig.ChestCenter;
            }
        }
    }
}
