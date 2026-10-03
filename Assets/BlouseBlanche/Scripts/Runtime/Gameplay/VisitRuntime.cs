using BlouseBlanche.Medical;

namespace BlouseBlanche.Gameplay
{
    public enum VisitStatus
    {
        Upcoming,        // pas encore arrivé
        Arriving,        // marche vers l'accueil
        CheckIn,         // à l'accueil
        Waiting,         // en salle d'attente
        Called,          // se rend au cabinet
        Ready,           // assis au cabinet, en attente du médecin
        Consulting,      // consultation en cours
        Leaving,         // repart
        Done,            // vu
        Left,            // parti sans être vu (attente trop longue)
        Transferred      // pris en charge par le SAMU
    }

    /// <summary>État vivant d'un rendez-vous pendant la journée.</summary>
    public sealed class VisitRuntime
    {
        public ScheduledVisit Plan;
        public PatientRecord Patient;
        public VisitStatus Status = VisitStatus.Upcoming;
        public PatientAgent Agent;
        public float ArrivalMinute = -1f;     // heure d'arrivée réelle
        public float WaitStartMinute = -1f;   // début de l'attente
        public float WaitedMinutes;
        public ConsultationResult Result;
        public bool UrgentAlertSent;
        public bool Deteriorated;
        public int Order;

        public bool IsUrgent => Patient.Case.Urgency == Urgency.Vitale;
        public bool IsPresent => Status == VisitStatus.CheckIn || Status == VisitStatus.Waiting || Status == VisitStatus.Called || Status == VisitStatus.Ready || Status == VisitStatus.Consulting;
        public bool IsFinished => Status == VisitStatus.Done || Status == VisitStatus.Left || Status == VisitStatus.Transferred;
        public float ScheduledTime => Plan.Time;
        public float ArrivalTime => Plan.Time + Plan.ArrivalOffset;

        public string StatusLabel
        {
            get
            {
                switch (Status)
                {
                    case VisitStatus.Upcoming: return "À venir";
                    case VisitStatus.Arriving: return "Arrive";
                    case VisitStatus.CheckIn: return "À l'accueil";
                    case VisitStatus.Waiting: return "En salle d'attente";
                    case VisitStatus.Called: return "Appelé";
                    case VisitStatus.Ready: return "Au cabinet";
                    case VisitStatus.Consulting: return "En consultation";
                    case VisitStatus.Leaving: return "Repart";
                    case VisitStatus.Done: return "Vu";
                    case VisitStatus.Left: return "Parti sans être vu";
                    case VisitStatus.Transferred: return "Pris en charge par le SAMU";
                    default: return Status.ToString();
                }
            }
        }
    }
}
