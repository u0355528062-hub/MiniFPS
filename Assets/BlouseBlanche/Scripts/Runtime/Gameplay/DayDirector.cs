#if BB_STORY_MODE
// Mode histoire (mis en pause) : activer le symbole BB_STORY_MODE pour le réintégrer.
using System;
using System.Collections.Generic;
using BlouseBlanche.Core;
using BlouseBlanche.Medical;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    public sealed class DaySummary
    {
        public DayPlan Plan;
        public int Seen, Lost, Transferred, Critical;
        public float AverageScore;
        public int Money;
        public float ReputationDelta;
        public readonly List<VisitRuntime> Visits = new List<VisitRuntime>();
    }

    /// <summary>
    /// Orchestration d'une journée : arrivées selon l'horloge, accueil, patience, urgences,
    /// appel des patients, fin de journée.
    /// </summary>
    public sealed class DayDirector : MonoBehaviour, IVisitHost
    {
        public DayPlan Plan { get; private set; }
        public readonly List<VisitRuntime> Visits = new List<VisitRuntime>();
        public bool Active { get; private set; }
        public event Action<DaySummary> DayCompleted;

        GameRoot root;
        ClinicWorld world;
        WorldKit kit;
        Transform actorsRoot;
        SecretaryAgent secretary;
        PatientAgent deskOwner;
        float reputationDelta;
        int money;
        bool completionSent;
        float endCheckTimer;

        public SecretaryAgent Secretary => secretary;

        public void Initialize(GameRoot root, ClinicWorld world, WorldKit kit)
        {
            this.root = root;
            this.world = world;
            this.kit = kit;
        }

        // ================================================================== cycle de vie

        public void BeginDay(DayPlan plan)
        {
            EndDay();
            Plan = plan;
            actorsRoot = WorldKit.Group(world.Root, "Personnages_Jour" + (plan.Index + 1), Vector3.zero);
            secretary = SecretaryAgent.Spawn(this, world, kit, actorsRoot);
            for (int i = 0; i < plan.Visits.Count; i++)
            {
                var v = plan.Visits[i];
                Visits.Add(new VisitRuntime { Plan = v, Patient = StoryCampaign.CreatePatient(v, plan.Index, i), Order = i });
            }
            root.Clock.Set(plan.Start);
            reputationDelta = 0f;
            money = 0;
            completionSent = false;
            Active = true;
        }

        public void EndDay()
        {
            Active = false;
            foreach (var v in Visits) if (v.Agent != null) v.Agent.Despawn();
            Visits.Clear();
            deskOwner = null;
            if (actorsRoot != null) Destroy(actorsRoot.gameObject);
            actorsRoot = null;
            secretary = null;
            foreach (var s in world.WaitingSeats) s.Occupant = null;
            if (world.PatientChair != null) world.PatientChair.Occupant = null;
            if (world.CompanionChair != null) world.CompanionChair.Occupant = null;
            if (world.ExamTable != null) world.ExamTable.Occupant = null;
        }

        void Update()
        {
            if (!Active || root == null) return;
            float now = root.Clock.Minutes;

            foreach (var v in Visits)
            {
                if (v.Status == VisitStatus.Upcoming && now >= v.ArrivalTime)
                {
                    v.ArrivalMinute = now;
                    var agent = PatientAgent.Spawn(this, world, kit, v, actorsRoot);
                    agent.Arrive();
                }

                if (v.Status == VisitStatus.Waiting || v.Status == VisitStatus.CheckIn || v.Status == VisitStatus.Arriving)
                {
                    float waitRef = v.IsUrgent || v.Plan.WalkIn ? v.ArrivalMinute : Mathf.Max(v.ArrivalMinute, v.ScheduledTime);
                    v.WaitedMinutes = Mathf.Max(0f, now - waitRef);
                    if (v.IsUrgent)
                    {
                        if (!v.Deteriorated && v.WaitedMinutes > v.Patient.Case.DeteriorationMinutes)
                        {
                            v.Deteriorated = true;
                            TransferBySecretary(v);
                        }
                    }
                    else if (v.Status == VisitStatus.Waiting && v.WaitedMinutes > v.Patient.Case.PatienceMinutes)
                    {
                        PatientGivesUp(v);
                    }
                }
            }

            endCheckTimer -= Time.deltaTime;
            if (endCheckTimer <= 0f)
            {
                endCheckTimer = 1f;
                CheckDayEnd();
            }
        }

        // ================================================================== accueil

        public bool TryTakeDesk(PatientAgent p)
        {
            if (deskOwner == null || deskOwner == p) { deskOwner = p; return true; }
            return false;
        }

        public void ReleaseDesk(PatientAgent p)
        {
            if (deskOwner == p) deskOwner = null;
            secretary?.StopAttending(p);
        }

        public void OnCheckIn(VisitRuntime v)
        {
            secretary?.Attend(v.Agent);
            secretary?.Speak(2.5f);
            var p = v.Patient;
            if (v.IsUrgent)
            {
                v.UrgentAlertSent = true;
                root.Audio.PlayUI(Sfx.Urgent, 0.9f);
                root.PostFX.Pulse(0.25f);
                root.UI.Toast("URGENCE", p.DisplayName + ", " + p.AgeLabel + " — " + p.Case.Motif.ToLowerInvariant() + ". Sophie vous demande de venir tout de suite !", ToastKind.Urgent, 9f);
                root.UI.Subtitle("Sophie", "Docteur ! " + p.ShortName + " ne va pas bien du tout : " + p.Case.Motif.ToLowerInvariant() + ". Il faut le voir immédiatement !");
            }
            else if (v.Plan.WalkIn)
            {
                root.Audio.PlayUI(Sfx.Notify, 0.7f);
                root.UI.Toast("Patient sans rendez-vous", p.DisplayName + ", " + p.AgeLabel + " — " + p.Case.Motif.ToLowerInvariant(), ToastKind.Warning);
            }
            else
            {
                root.Audio.PlayUI(Sfx.Notify, 0.55f);
                string late = v.ArrivalMinute > v.ScheduledTime + 2f ? " (en retard)" : "";
                root.UI.Toast("Patient arrivé" + late, p.DisplayName + " — RDV " + GameClock.FormatSpoken(v.ScheduledTime), ToastKind.Info);
            }
        }

        public void OnWaiting(VisitRuntime v)
        {
            if (v.WaitStartMinute < 0f) v.WaitStartMinute = root.Clock.Minutes;
        }

        void PatientGivesUp(VisitRuntime v)
        {
            reputationDelta -= 4f;
            root.Audio.PlayUI(Sfx.UiBack, 0.8f);
            root.UI.Toast("Patient parti", v.Patient.DisplayName + " est reparti(e) après " + Mathf.RoundToInt(v.WaitedMinutes) + " min d'attente.", ToastKind.Warning, 7f);
            LeaveOverride(v, VisitStatus.Left);
        }

        void TransferBySecretary(VisitRuntime v)
        {
            reputationDelta -= 10f;
            root.Save.criticalErrors++;
            root.Audio.PlayUI(Sfx.Urgent, 1f);
            root.UI.Toast("Prise en charge trop tardive", "Sophie a dû appeler le 15 : " + v.Patient.DisplayName + " a été emmené(e) par le SAMU sans votre examen.", ToastKind.Urgent, 10f);
            LeaveOverride(v, VisitStatus.Transferred);
        }

        void LeaveOverride(VisitRuntime v, VisitStatus final)
        {
            // Le statut final est fixé immédiatement pour la logique de journée ; l'agent quitte le cabinet.
            if (v.Agent != null) v.Agent.Leave(null);
            v.Status = final;
        }

        // ================================================================== consultation

        public VisitRuntime ActiveConsultVisit()
        {
            foreach (var v in Visits)
                if (v.Status == VisitStatus.Called || v.Status == VisitStatus.Ready || v.Status == VisitStatus.Consulting) return v;
            return null;
        }

        public bool CanCall(VisitRuntime v) => v.Status == VisitStatus.Waiting && ActiveConsultVisit() == null;

        public VisitRuntime NextToCall()
        {
            VisitRuntime best = null;
            foreach (var v in Visits)
            {
                if (v.Status != VisitStatus.Waiting) continue;
                if (best == null) { best = v; continue; }
                if (v.IsUrgent && !best.IsUrgent) { best = v; continue; }
                if (best.IsUrgent && !v.IsUrgent) continue;
                float tv = v.Plan.WalkIn ? v.ArrivalMinute + 15f : v.ScheduledTime;
                float tb = best.Plan.WalkIn ? best.ArrivalMinute + 15f : best.ScheduledTime;
                if (tv < tb) best = v;
            }
            return best;
        }

        public void CallPatient(VisitRuntime v)
        {
            if (!CanCall(v) || v.Agent == null) return;
            root.Audio.PlayUI(Sfx.UiConfirm, 0.7f);
            root.UI.Subtitle("Vous", v.Patient.ShortName + ", c'est à vous ! Suivez-moi, je vous en prie.");
            v.Agent.CallToConsultation(() =>
            {
                root.UI.Toast("Patient installé", v.Patient.DisplayName + " vous attend dans le cabinet.", ToastKind.Info, 5f);
            });
        }

        public void StartConsultation(VisitRuntime v)
        {
            if (v.Status != VisitStatus.Ready) return;
            root.BeginConsultation(v);
        }

        public void OnConsultationFinished(VisitRuntime v, ConsultationResult r)
        {
            v.Result = r;
            money += r.Fee;
            reputationDelta += r.ReputationDelta;
            if (r.Critical) root.Save.criticalErrors++;
            if (v.Agent != null) v.Agent.Leave(null);
            v.Status = VisitStatus.Done;
        }

        // ================================================================== temps

        public bool AnyonePresent()
        {
            foreach (var v in Visits)
                if (v.Status == VisitStatus.Arriving || v.IsPresent) return true;
            return false;
        }

        public float NextArrival()
        {
            float best = float.MaxValue;
            foreach (var v in Visits) if (v.Status == VisitStatus.Upcoming) best = Mathf.Min(best, v.ArrivalTime);
            return best;
        }

        /// <summary>Avance l'horloge jusqu'au prochain évènement (si personne n'attend).</summary>
        public bool CanSkipTime() => Active && !AnyonePresent() && NextArrival() < float.MaxValue && NextArrival() - root.Clock.Minutes > 2f;

        public void SkipTime()
        {
            if (!CanSkipTime()) return;
            float target = NextArrival() - 1f;
            root.Clock.Advance(target - root.Clock.Minutes);
        }

        void CheckDayEnd()
        {
            if (completionSent || Visits.Count == 0) return;
            foreach (var v in Visits)
                if (!v.IsFinished) return;
            // Attendre que le dernier patient ait quitté le bâtiment
            foreach (var v in Visits) if (v.Agent != null) return;
            completionSent = true;
            DayCompleted?.Invoke(BuildSummary());
        }

        public DaySummary BuildSummary()
        {
            var s = new DaySummary { Plan = Plan, Money = money, ReputationDelta = reputationDelta };
            float total = 0f;
            foreach (var v in Visits)
            {
                s.Visits.Add(v);
                if (v.Status == VisitStatus.Done && v.Result != null) { s.Seen++; total += v.Result.Total; if (v.Result.Critical) s.Critical++; }
                else if (v.Status == VisitStatus.Left) s.Lost++;
                else if (v.Status == VisitStatus.Transferred) { s.Transferred++; s.Critical++; }
            }
            s.AverageScore = s.Seen > 0 ? total / s.Seen : 0f;
            return s;
        }

        public bool AllDone
        {
            get
            {
                foreach (var v in Visits) if (!v.IsFinished) return false;
                return true;
            }
        }

        // ================================================================== Sophie

        public string SecretaryLine()
        {
            float now = root.Clock.Minutes;
            var next = NextToCall();
            if (next != null && next.IsUrgent) return "Docteur, " + next.Patient.ShortName + " est une urgence ! Ne le faites pas attendre.";
            int waiting = 0;
            foreach (var v in Visits) if (v.Status == VisitStatus.Waiting) waiting++;
            if (waiting > 0 && next != null)
                return waiting + (waiting > 1 ? " patients attendent." : " patient attend.") + " Le prochain : " + next.Patient.DisplayName + (next.Plan.WalkIn ? " (sans rendez-vous)." : ", RDV de " + GameClock.FormatSpoken(next.ScheduledTime) + ".");
            float na = NextArrival();
            if (na < float.MaxValue)
            {
                VisitRuntime up = null;
                foreach (var v in Visits) if (v.Status == VisitStatus.Upcoming && (up == null || v.ArrivalTime < up.ArrivalTime)) up = v;
                if (up != null && !up.Plan.WalkIn) return "Prochain rendez-vous : " + up.Patient.DisplayName + " à " + GameClock.FormatSpoken(up.ScheduledTime) + ". Vous pouvez souffler un peu (touche F pour avancer le temps).";
                return "Pas de rendez-vous pour le moment. Profitez-en pour prendre un café en salle de pause !";
            }
            if (AllDone) return "C'est fini pour ce matin ! Belle journée, Docteur.";
            string[] tips =
            {
                "N'oubliez pas de vous laver les mains entre deux patients, le lavabo est dans votre cabinet.",
                "Vous pouvez consulter le dossier du patient pendant la consultation : allergies, traitements…",
                "Clic droit maintenu pendant la consultation pour choisir vos instruments.",
            };
            return tips[Mathf.FloorToInt(now) % tips.Length];
        }
    }
}
#endif
