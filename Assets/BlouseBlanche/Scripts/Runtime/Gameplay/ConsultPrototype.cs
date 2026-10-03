using System;
using BlouseBlanche.Core;
using BlouseBlanche.Medical;
using BlouseBlanche.World;
using UnityEngine;
using L = BlouseBlanche.World.ClinicLayout;

namespace BlouseBlanche.Gameplay
{
    /// <summary>
    /// Prototype « consultation unique » : un patient déjà installé face au bureau, Sophie à l'accueil.
    /// Le joueur se lave les mains, va parler au patient, mène la consultation.
    /// </summary>
    public sealed class ConsultPrototype : MonoBehaviour, IVisitHost
    {
        public CaseDef Case { get; private set; }
        public VisitRuntime Visit { get; private set; }
        public bool Active => Visit != null;
        public bool HandsWashed { get; private set; }
        public bool Done => Visit != null && Visit.Status == VisitStatus.Done;

        /// <summary>Position et orientation du joueur au début du cas (entrée du cabinet, face au patient).</summary>
        public Vector3 PlayerStart { get; private set; }
        public float PlayerStartYaw { get; private set; }

        public event Action Changed;

        GameRoot root;
        ClinicWorld world;
        WorldKit kit;
        Transform actors;
        SecretaryAgent secretary;

        public void Initialize(GameRoot root, ClinicWorld world, WorldKit kit)
        {
            this.root = root;
            this.world = world;
            this.kit = kit;
        }

        public void Begin(CaseDef c, int seed)
        {
            End();
            Case = c;
            HandsWashed = false;
            actors = WorldKit.Group(world.Root, "Prototype_Consultation", Vector3.zero);
            secretary = SecretaryAgent.Spawn(this, world, kit, actors);

            var plan = new ScheduledVisit { CaseId = c.Id, Time = root.Clock.Minutes };
            Visit = new VisitRuntime { Plan = plan, Patient = StoryCampaign.CreatePatient(plan, seed, 0), Order = 0 };
            var agent = PatientAgent.Spawn(this, world, kit, Visit, actors);
            agent.PlaceReadyInConsultRoom();

            PlayerStart = world.Nav.Position(L.ConsultIn);
            Vector3 toPatient = world.PatientChair.Anchor - PlayerStart;
            PlayerStartYaw = Mathf.Atan2(toPatient.x, toPatient.z) * Mathf.Rad2Deg;
            Changed?.Invoke();
        }

        public void End()
        {
            if (Visit != null && Visit.Agent != null) Visit.Agent.Despawn();
            if (actors != null) Destroy(actors.gameObject);
            actors = null;
            secretary = null;
            Visit = null;
            Case = null;
            HandsWashed = false;
            if (world != null)
            {
                if (world.PatientChair != null) world.PatientChair.Occupant = null;
                if (world.CompanionChair != null) world.CompanionChair.Occupant = null;
                if (world.ExamTable != null) world.ExamTable.Occupant = null;
                if (world.SecretaryChair != null) world.SecretaryChair.Occupant = null;
            }
        }

        public void OnHandsWashed()
        {
            if (!Active || HandsWashed) return;
            HandsWashed = true;
            Changed?.Invoke();
        }

        /// <summary>Résumé « logiciel médical » du dossier (ordinateur du bureau).</summary>
        public string DossierSummary()
        {
            if (Visit == null) return "";
            var p = Visit.Patient;
            string history = p.History != null && p.History.Length > 0 ? string.Join(", ", p.History) : "aucun antécédent notable";
            string allergies = p.Allergies != null && p.Allergies.Length > 0 ? "ALLERGIE : " + string.Join(", ", p.Allergies) : "pas d'allergie connue";
            return p.FullName + ", " + p.AgeLabel + " · " + history + " · " + allergies + ".";
        }

        // ================================================================== IVisitHost

        public bool TryTakeDesk(PatientAgent p) => true;
        public void ReleaseDesk(PatientAgent p) { }
        public void OnCheckIn(VisitRuntime v) { }
        public void OnWaiting(VisitRuntime v) { }
        public bool CanCall(VisitRuntime v) => false;
        public void CallPatient(VisitRuntime v) { }

        public void StartConsultation(VisitRuntime v)
        {
            if (v != Visit || v.Status != VisitStatus.Ready) return;
            root.BeginConsultation(v);
        }

        public void OnConsultationFinished(VisitRuntime v, ConsultationResult r)
        {
            v.Result = r;
            v.Status = VisitStatus.Done;
            if (v.Agent != null) v.Agent.Leave(null);
            Changed?.Invoke();
        }

        public string SecretaryLine()
        {
            if (Visit == null) return "Bonjour Docteur !";
            var p = Visit.Patient;
            if (Done) return "Belle consultation, Docteur ! Un autre patient vous attend quand vous voulez (Échap pour changer de cas).";
            if (Visit.IsUrgent) return "Docteur, " + p.ShortName + " n'a vraiment pas l'air bien… Il faut le voir tout de suite !";
            if (!HandsWashed) return p.DisplayName + " vous attend dans votre cabinet. Pensez à vous laver les mains avant de l'examiner !";
            return p.DisplayName + " vous attend dans votre cabinet : motif « " + p.Case.Motif.ToLowerInvariant() + " ».";
        }
    }
}
