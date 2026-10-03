using System;
using BlouseBlanche.Characters;
using BlouseBlanche.Core;
using BlouseBlanche.Medical;
using BlouseBlanche.World;
using UnityEngine;
using L = BlouseBlanche.World.ClinicLayout;

namespace BlouseBlanche.Gameplay
{
    /// <summary>
    /// Patient (et éventuel accompagnant) dans le monde : trajets, gestes liés aux symptômes,
    /// paroles, interactions avec le joueur.
    /// </summary>
    public sealed class PatientAgent : MonoBehaviour, IInteractable
    {
        public VisitRuntime Visit;
        public HumanAgent Body;
        public HumanAgent Companion;
        ClinicWorld world;
        IVisitHost director;
        SeatSpot waitingSeat, companionSeat;
        float lookAtPlayerTimer;

        public HumanRig Rig => Body != null ? Body.Rig : null;
        public HumanAnimator Anim => Body != null ? Body.Anim : null;

        public static PatientAgent Spawn(IVisitHost director, ClinicWorld world, WorldKit kit, VisitRuntime visit, Transform parent)
        {
            var p = visit.Patient;
            var rig = HumanBuilder.Build(kit, parent, p.Look, "Patient_" + p.LastName);
            var agent = rig.gameObject.AddComponent<PatientAgent>();
            agent.Visit = visit;
            agent.world = world;
            agent.director = director;
            agent.Body = MakeAgent(rig, world, p.Age >= 70 ? 0.8f : p.IsChild ? 1.0f : 1.15f);
            var c = p.Case;
            if (c.Limp) { agent.Body.WalkSpeed = 0.75f; agent.Anim.Limp = true; }
            if (c.Urgency == Urgency.Vitale) agent.Body.WalkSpeed = 0.7f;
            agent.ApplyPose(c.Pose, c.Cough);

            if (p.CompanionLook != null)
            {
                var crig = HumanBuilder.Build(kit, parent, p.CompanionLook, "Accompagnant_" + p.LastName);
                agent.Companion = MakeAgent(crig, world, p.Age >= 70 ? 0.8f : 1.1f);
            }
            visit.Agent = agent;
            return agent;
        }

        static HumanAgent MakeAgent(HumanRig rig, ClinicWorld world, float speed)
        {
            var anim = rig.gameObject.AddComponent<HumanAnimator>();
            anim.Rig = rig;
            var a = rig.gameObject.AddComponent<HumanAgent>();
            a.Rig = rig;
            a.Anim = anim;
            a.Nav = world.Nav;
            a.WalkSpeed = speed;
            DoorSensors.Register(rig.transform);
            return a;
        }

        void ApplyPose(PatientPose pose, bool cough)
        {
            var anim = Anim;
            switch (pose)
            {
                case PatientPose.Ventre: anim.Gesture = Gesture.HoldBelly; anim.PainSway = 1.5f; break;
                case PatientPose.Poitrine: anim.Gesture = Gesture.HoldChest; anim.PainSway = 2.5f; break;
                case PatientPose.Dos: anim.Gesture = Gesture.HoldBack; anim.PainSway = 1f; break;
                case PatientPose.Tete: anim.Gesture = Gesture.HoldHead; break;
                case PatientPose.Oeil: anim.Gesture = Gesture.HoldHead; break;
                case PatientPose.Fatigue: anim.PainSway = 1.2f; break;
            }
            anim.CoughPeriodically = cough;
            anim.OnCough = () =>
            {
                var audio = GameRoot.Instance != null ? GameRoot.Instance.Audio : null;
                if (audio != null && Rig != null) audio.PlayAt(UnityEngine.Random.value < 0.5f ? Sfx.Cough0 : Sfx.Cough1, Rig.HeadCenter, 0.7f, 0.08f);
            };
        }

        /// <summary>Le geste "de douleur" est mis en pause pendant les examens qui en imposent un autre.</summary>
        public void SetExamGesture(Gesture g)
        {
            if (Anim == null) return;
            if (g == Gesture.None) ApplyPose(Visit.Patient.Case.Pose, Visit.Patient.Case.Cough);
            else { Anim.Gesture = g; Anim.CoughPeriodically = false; }
        }

        public void Say(string text)
        {
            if (Anim != null) Anim.Talk(Mathf.Clamp(text.Length * 0.045f, 1.2f, 6f));
            if (Companion != null && !string.IsNullOrEmpty(Visit.Patient.Case.Companion) && text.StartsWith("("))
                Companion.Anim.Talk(Mathf.Clamp(text.Length * 0.045f, 1.2f, 6f));
        }

        // ================================================================== scénario

        public void Arrive()
        {
            string street = UnityEngine.Random.value < 0.5f ? L.Street : "streetE";
            Body.Teleport(world.Nav.Position(street), 90f, street);
            Visit.Status = VisitStatus.Arriving;
            Body.WalkTo(L.Inside).WalkTo(L.Queue)
                .WaitUntil(() => director.TryTakeDesk(this), 120f)
                .WalkTo(L.Desk).Face(0f)
                .Then(() => { Visit.Status = VisitStatus.CheckIn; director.OnCheckIn(Visit); })
                .Wait(Visit.IsUrgent ? 2.0f : 3.2f)
                .Then(() => { director.ReleaseDesk(this); GoWait(); });

            if (Companion != null)
            {
                Companion.Teleport(world.Nav.Position(street) + new Vector3(street == L.Street ? -0.9f : 0.9f, 0f, 0.3f), 90f, street);
                Companion.Wait(0.8f).WalkTo(L.Inside).WalkTo(L.LobbyE).FaceTowards(world.Nav.Position(L.Desk));
            }
        }

        /// <summary>Prototype "intervention unique" : le patient est déjà installé face au bureau.</summary>
        public void PlaceReadyInConsultRoom()
        {
            Body.PlaceSeated(world.PatientChair);
            if (Companion != null) Companion.PlaceSeated(world.CompanionChair);
            Visit.Status = VisitStatus.Ready;
            Visit.ArrivalMinute = GameRoot.Instance != null ? GameRoot.Instance.Clock.Minutes : 0f;
        }

        void GoWait()
        {
            var r = new System.Random(Visit.Patient.Seed);
            waitingSeat = world.FreeWaitingSeat(r);
            Visit.Status = VisitStatus.Waiting;
            director.OnWaiting(Visit);
            if (waitingSeat != null) Body.SitOn(waitingSeat);
            else Body.WalkTo(L.LobbyC);

            if (Companion != null)
            {
                companionSeat = NeighbourSeat(waitingSeat);
                if (companionSeat != null) Companion.SitOn(companionSeat);
                else Companion.WalkTo(L.LobbyC);
            }
        }

        SeatSpot NeighbourSeat(SeatSpot seat)
        {
            if (seat == null) return world.FreeWaitingSeat(new System.Random(3));
            int idx = world.WaitingSeats.IndexOf(seat);
            for (int d = 1; d < world.WaitingSeats.Count; d++)
            {
                foreach (int j in new[] { idx + d, idx - d })
                {
                    if (j < 0 || j >= world.WaitingSeats.Count) continue;
                    var s = world.WaitingSeats[j];
                    if (s.Free && s.Id[0] == seat.Id[0]) return s;
                }
            }
            return world.FreeWaitingSeat(new System.Random(5));
        }

        /// <summary>Le médecin appelle le patient : il se rend au cabinet et s'assoit face au bureau.</summary>
        public void CallToConsultation(Action onReady)
        {
            Visit.Status = VisitStatus.Called;
            Body.ClearSteps();
            if (Body.Seat != null) Body.StandUp();
            Body.WalkTo(L.ConsultIn).SitOn(world.PatientChair).Then(() =>
            {
                Visit.Status = VisitStatus.Ready;
                onReady?.Invoke();
            });
            if (Companion != null)
            {
                Companion.ClearSteps();
                if (Companion.Seat != null) Companion.StandUp();
                Companion.Wait(1.2f).WalkTo(L.ConsultIn).SitOn(world.CompanionChair);
            }
        }

        public void GoToExamTable(Action onDone)
        {
            Body.ClearSteps();
            if (Body.Seat != null) Body.StandUp();
            Body.WalkTo(L.ExamNode).SitOn(world.ExamTable).Then(() => onDone?.Invoke());
        }

        public void GoToChair(Action onDone)
        {
            Body.ClearSteps();
            if (Body.Seat != null) Body.StandUp();
            Body.WalkTo(L.PatientChairNode).SitOn(world.PatientChair).Then(() => onDone?.Invoke());
        }

        public bool IsBusyMoving => Body != null && !Body.Idle;

        public void Leave(Action onGone)
        {
            Visit.Status = VisitStatus.Leaving;
            Body.ClearSteps();
            if (Body.Seat != null) Body.StandUp();
            string exit = UnityEngine.Random.value < 0.5f ? L.Street : "streetE";
            Body.WalkTo(L.Inside).WalkTo(exit).Then(() => { onGone?.Invoke(); Despawn(); });
            if (Companion != null)
            {
                Companion.ClearSteps();
                if (Companion.Seat != null) Companion.StandUp();
                Companion.Wait(0.6f).WalkTo(L.Inside).WalkTo(exit);
            }
        }

        public void Despawn()
        {
            if (waitingSeat != null && waitingSeat.Occupant == (object)Body) waitingSeat.Occupant = null;
            if (companionSeat != null && Companion != null && companionSeat.Occupant == (object)Companion) companionSeat.Occupant = null;
            ReleaseSeat(world.PatientChair, Body);
            ReleaseSeat(world.ExamTable, Body);
            if (Companion != null) ReleaseSeat(world.CompanionChair, Companion);
            if (Body != null) DoorSensors.Unregister(Body.transform);
            if (Companion != null)
            {
                DoorSensors.Unregister(Companion.transform);
                Destroy(Companion.gameObject);
            }
            Destroy(gameObject);
        }

        static void ReleaseSeat(SeatSpot s, HumanAgent a)
        {
            if (s != null && a != null && s.Occupant == (object)a) s.Occupant = null;
        }

        void Update()
        {
            if (Anim == null) return;
            var root = GameRoot.Instance;
            if (root == null || root.CameraDirector == null || root.CameraDirector.Cam == null) return;
            Vector3 cam = root.CameraDirector.Cam.transform.position;
            float d = Vector3.Distance(cam, Rig.HeadCenter);
            if (Visit.Status == VisitStatus.Consulting || Visit.Status == VisitStatus.Ready || d < 2.6f)
            {
                Anim.LookTarget = cam;
                lookAtPlayerTimer = 2f;
            }
            else if (Visit.Status == VisitStatus.CheckIn) Anim.LookTarget = world.SecretaryHead;
            else
            {
                lookAtPlayerTimer -= Time.deltaTime;
                if (lookAtPlayerTimer <= 0f) Anim.LookTarget = null;
            }
            if (Companion != null)
            {
                Companion.Anim.LookTarget = Visit.Status == VisitStatus.Consulting ? cam : Rig.HeadCenter;
            }
        }

        // ================================================================== IInteractable

        public bool CanInteract
        {
            get
            {
                if (director == null) return false;
                if (Visit.Status == VisitStatus.Waiting) return director.CanCall(Visit);
                return Visit.Status == VisitStatus.Ready;
            }
        }

        public string InteractionVerb
        {
            get
            {
                switch (Visit.Status)
                {
                    case VisitStatus.Waiting: return "Appeler en consultation";
                    case VisitStatus.Ready: return "Commencer la consultation";
                    default: return "";
                }
            }
        }

        public string InteractionTarget => Visit.Patient.DisplayName + " · " + Visit.Patient.Case.Motif.ToLowerInvariant();

        public string UnavailableReason => Visit.Status == VisitStatus.Waiting ? "Un patient est déjà en consultation." : "";

        public void Interact()
        {
            if (director == null) return;
            if (Visit.Status == VisitStatus.Waiting) director.CallPatient(Visit);
            else if (Visit.Status == VisitStatus.Ready) director.StartConsultation(Visit);
        }
    }
}
