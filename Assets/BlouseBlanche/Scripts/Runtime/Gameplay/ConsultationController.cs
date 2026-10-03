using System;
using System.Collections;
using BlouseBlanche.Core;
using BlouseBlanche.Medical;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    public enum PatientStation { Chair, Table }

    /// <summary>
    /// Mise en scène et logique d'une consultation : plans caméra, déplacement du patient vers le divan,
    /// gestes d'examen avec l'outil tenu en main, avancée du temps, conclusion et évaluation.
    /// </summary>
    public sealed class ConsultationController : MonoBehaviour
    {
        public ConsultationSession Session { get; private set; }
        public VisitRuntime Visit { get; private set; }
        public PatientStation Station { get; private set; }
        public MedicalTool? Tool { get; private set; }
        public bool Busy { get; private set; }
        public bool Active => Session != null;

        public event Action Changed;
        public event Action<string, string> PatientSpoke;          // (orateur, texte)
        public event Action<string, Finding> ExamDone;             // (examen, résultat)
        public event Action<ConsultationResult> Finished;

        GameRoot root;
        ClinicWorld world;
        HeldToolView held;

        public void Initialize(GameRoot root, ClinicWorld world, HeldToolView held)
        {
            this.root = root;
            this.world = world;
            this.held = held;
        }

        PatientAgent Agent => Visit?.Agent;

        // ================================================================== début / fin

        IVisitHost host;

        public void Begin(VisitRuntime visit, bool handsWashed, IVisitHost host)
        {
            this.host = host;
            Visit = visit;
            Session = new ConsultationSession(visit.Patient) { WaitedMinutes = visit.WaitedMinutes, HandsWashed = handsWashed };
            Station = PatientStation.Chair;
            Tool = null;
            Busy = false;
            visit.Status = VisitStatus.Consulting;
            root.CameraDirector.SetShot(world.DeskShot.position, world.DeskShot.rotation, 48f, 1.2f);
            FocusOn(Agent != null ? Agent.Rig.HeadCenter : world.DeskShot.position + world.DeskShot.forward * 2f);
            string opening = Session.Opening;
            StartCoroutine(SayLater(opening, 1.0f));
            Changed?.Invoke();
        }

        IEnumerator SayLater(string text, float delay)
        {
            yield return new WaitForSeconds(delay);
            Speak(text);
        }

        void Speak(string text)
        {
            if (Agent != null) Agent.Say(text);
            string speaker = text.StartsWith("(") ? "Accompagnant" : Visit.Patient.ShortName;
            PatientSpoke?.Invoke(speaker, text);
        }

        void FocusOn(Vector3 target)
        {
            float d = Vector3.Distance(root.CameraDirector.Cam.transform.position, target);
            if (root.CameraDirector.CurrentMode == CameraDirector.Mode.Shot) d = Vector3.Distance(StationPose().position, target);
            root.PostFX.SetFocus(true, d + 0.8f, d + 5f);
        }

        Pose StationPose() => Station == PatientStation.Chair ? world.DeskShot : world.ExamShot;

        void Advance(float minutes)
        {
            Session.Minutes += minutes;
            root.Clock.Advance(minutes);
        }

        // ================================================================== interrogatoire

        public void Ask(string questionId)
        {
            if (!Active || Busy) return;
            var q = MedicalCatalog.Question(questionId);
            if (q == null) return;
            PatientSpoke?.Invoke("Vous", q.Text);
            string answer = Session.Answer(questionId);
            Advance(1f);
            StartCoroutine(SayLater(answer, 0.6f));
            Changed?.Invoke();
        }

        // ================================================================== outils et examens

        public void SelectTool(MedicalTool? tool)
        {
            if (!Active) return;
            Tool = tool;
            held.Show(tool);
            root.Audio.PlayUI(Sfx.UiClick, 0.5f);
            Changed?.Invoke();
        }

        public void Examine(string examId)
        {
            if (!Active || Busy) return;
            var def = MedicalCatalog.Exam(examId);
            if (def == null) return;
            if (Tool != def.Tool) SelectTool(def.Tool);
            StartCoroutine(ExamRoutine(def));
        }

        IEnumerator ExamRoutine(ExamDef def)
        {
            Busy = true;
            Changed?.Invoke();
            if (def.NeedsTable && Station != PatientStation.Table)
            {
                yield return MoveRoutine(PatientStation.Table);
            }
            var agent = Agent;
            Vector3 target = BodyPoint(def.Focus);
            // Plan rapproché vers la zone examinée
            Vector3 camPos = DetailCameraPosition(def.Focus, target);
            root.CameraDirector.SetShotLookAt(camPos, target, 42f, 0.9f, 0.002f);
            root.PostFX.SetFocus(true, Vector3.Distance(camPos, target) + 0.3f, Vector3.Distance(camPos, target) + 2.5f);
            if (agent != null) agent.SetExamGesture(def.PatientGesture);
            yield return new WaitForSeconds(0.7f);
            held.Reach(true);
            root.Audio.PlayAt(def.Sound, target, 0.8f, 0.02f);
            if (def.Sound == Sfx.Heartbeat)
            {
                for (int i = 0; i < 3; i++) { yield return new WaitForSeconds(0.86f); root.Audio.PlayAt(Sfx.Heartbeat, target, 0.8f, 0.02f); }
            }
            else yield return new WaitForSeconds(def.Sound == Sfx.BloodPressure ? 2.6f : 1.4f);
            held.Reach(false);
            var finding = Session.Examine(def.Id);
            Advance(def.Minutes);
            if (agent != null) agent.SetExamGesture(Gesture.None);
            ExamDone?.Invoke(def.Id, finding);
            yield return new WaitForSeconds(0.35f);
            var pose = StationPose();
            root.CameraDirector.SetShot(pose.position, pose.rotation, Station == PatientStation.Chair ? 48f : 50f, 0.9f);
            if (agent != null) FocusOn(agent.Rig.HeadCenter);
            Busy = false;
            Changed?.Invoke();
        }

        public void MoveTo(PatientStation station)
        {
            if (!Active || Busy || station == Station) return;
            StartCoroutine(MoveWrapper(station));
        }

        IEnumerator MoveWrapper(PatientStation station)
        {
            Busy = true;
            Changed?.Invoke();
            yield return MoveRoutine(station);
            Busy = false;
            Changed?.Invoke();
        }

        IEnumerator MoveRoutine(PatientStation station)
        {
            var agent = Agent;
            bool done = false;
            if (agent == null) { Station = station; yield break; }
            if (station == PatientStation.Table)
            {
                Speak("D'accord, je m'installe sur la table.");
                agent.GoToExamTable(() => done = true);
            }
            else agent.GoToChair(() => done = true);
            var pose = station == PatientStation.Table ? world.ExamShot : world.DeskShot;
            root.CameraDirector.SetShot(pose.position, pose.rotation, station == PatientStation.Table ? 50f : 48f, 2.2f);
            Advance(1f);
            float timeout = 25f;
            while (!done && timeout > 0f) { timeout -= Time.deltaTime; yield return null; }
            Station = station;
            FocusOn(agent.Rig.HeadCenter);
        }

        Vector3 BodyPoint(BodyFocus f)
        {
            var rig = Agent != null ? Agent.Rig : null;
            if (rig == null) return StationPose().position + StationPose().forward * 1.5f;
            Vector3 fwd = rig.transform.forward, right = rig.transform.right;
            float h = rig.HeadHeight;
            switch (f)
            {
                case BodyFocus.Tete: return rig.HeadCenter;
                case BodyFocus.Bouche: return rig.Head.TransformPoint(new Vector3(0f, h * 0.32f, h * 0.38f));
                case BodyFocus.Yeux: return rig.Head.TransformPoint(new Vector3(0f, h * 0.56f, h * 0.38f));
                case BodyFocus.Oreille: return rig.Head.TransformPoint(new Vector3(h * 0.34f, h * 0.52f, 0f));
                case BodyFocus.Cou: return rig.Neck.position + fwd * 0.05f;
                case BodyFocus.Thorax: return rig.ChestCenter;
                case BodyFocus.Bras: return rig.ElbowL.position;
                case BodyFocus.Main: return rig.WristL.position;
                case BodyFocus.Abdomen: return rig.BellyCenter;
                case BodyFocus.Dos: return rig.Spine.position + Vector3.up * rig.Torso_Length * 0.2f - fwd * 0.12f;
                case BodyFocus.Pied: return rig.AnkleR.position;
                default: return rig.ChestCenter;
            }
        }

        Vector3 DetailCameraPosition(BodyFocus f, Vector3 target)
        {
            var rig = Agent != null ? Agent.Rig : null;
            Vector3 fwd = rig != null ? rig.transform.forward : Vector3.forward;
            Vector3 right = rig != null ? rig.transform.right : Vector3.right;
            Vector3 dir;
            float dist = 0.75f;
            switch (f)
            {
                case BodyFocus.Oreille: dir = (right * 1f + fwd * 0.35f).normalized; dist = 0.55f; break;
                case BodyFocus.Dos: dir = (-fwd + right * 0.4f).normalized; dist = 0.9f; break;
                case BodyFocus.Pied: dir = (fwd + right * 0.5f + Vector3.up * 0.6f).normalized; dist = 0.85f; break;
                case BodyFocus.Bouche:
                case BodyFocus.Yeux: dir = (fwd + right * 0.2f).normalized; dist = 0.55f; break;
                case BodyFocus.Bras:
                case BodyFocus.Main: dir = (fwd - right * 0.6f + Vector3.up * 0.3f).normalized; break;
                default: dir = (fwd + right * 0.35f + Vector3.up * 0.15f).normalized; break;
            }
            return target + dir * dist + Vector3.up * 0.05f;
        }

        // ================================================================== décisions

        public void SetDiagnosis(string id)
        {
            if (!Active) return;
            Session.Diagnosis = id;
            Changed?.Invoke();
        }

        public void ToggleTreatment(string id)
        {
            if (!Active) return;
            if (!Session.Treatments.Remove(id)) Session.Treatments.Add(id);
            root.Audio.PlayUI(Sfx.Pen, 0.35f);
            Changed?.Invoke();
        }

        public void SetOrientation(Orientation o)
        {
            if (!Active) return;
            Session.Orientation = o;
            if (o == Orientation.Urgences15 && Session.OrientationMinute < 0f) Session.OrientationMinute = Session.Minutes;
            Changed?.Invoke();
        }

        /// <summary>Appel immédiat du SAMU : termine la consultation sans attendre.</summary>
        public void CallSamu()
        {
            if (!Active) return;
            Session.Orientation = Orientation.Urgences15;
            Session.OrientationMinute = Session.Minutes;
            root.Audio.PlayUI(Sfx.Urgent, 0.6f);
            PatientSpoke?.Invoke("Vous", "Allô, le 15 ? Médecin généraliste au cabinet des Tilleuls, j'ai besoin d'une équipe en urgence…");
            Advance(3f);
            Conclude();
        }

        public void Conclude()
        {
            if (!Active) return;
            Advance(2f);
            var result = Session.Evaluate();
            root.Audio.PlayUI(result.Total >= 65 && !result.Critical ? Sfx.Success : Sfx.Fail, 0.8f);
            held.Show(null);
            Tool = null;
            Finished?.Invoke(result);
        }

        /// <summary>Après l'écran de résultat : le patient part, le joueur reprend la main.</summary>
        public void Close(ConsultationResult result)
        {
            var v = Visit;
            Session = null;
            Visit = null;
            Busy = false;
            StopAllCoroutines();
            held.Show(null);
            root.PostFX.SetFocus(false);
            if (v != null) host?.OnConsultationFinished(v, result);
            Changed?.Invoke();
        }
    }
}
