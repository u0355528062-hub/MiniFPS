using BlouseBlanche.Medical;

namespace BlouseBlanche.Gameplay
{
    /// <summary>
    /// Ce dont un patient a besoin de son "hôte" (journée du mode histoire, ou prototype à intervention unique).
    /// </summary>
    public interface IVisitHost
    {
        bool TryTakeDesk(PatientAgent p);
        void ReleaseDesk(PatientAgent p);
        void OnCheckIn(VisitRuntime v);
        void OnWaiting(VisitRuntime v);
        bool CanCall(VisitRuntime v);
        void CallPatient(VisitRuntime v);
        void StartConsultation(VisitRuntime v);
        void OnConsultationFinished(VisitRuntime v, ConsultationResult r);
        string SecretaryLine();
    }
}
