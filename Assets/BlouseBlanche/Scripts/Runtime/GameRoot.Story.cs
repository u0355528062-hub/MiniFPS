#if BB_STORY_MODE
// Mode histoire (mis en pause) : activer le symbole BB_STORY_MODE pour le réintégrer.
using BlouseBlanche.Core;
using BlouseBlanche.Gameplay;
using BlouseBlanche.Medical;
using BlouseBlanche.UI;
using UnityEngine;

namespace BlouseBlanche
{
    /// <summary>Mode histoire : journées au cabinet, agenda, bilan de fin de journée, sauvegarde.</summary>
    public sealed partial class GameRoot
    {
        public DayDirector Day { get; private set; }
        DayPlan pendingPlan;
        bool agendaOpen;
        bool dayFinished;

        void InitStory()
        {
            Day = gameObject.AddComponent<DayDirector>();
            Day.Initialize(this, World, Kit);
            Day.DayCompleted += OnDayCompleted;
        }

        void CleanupStory()
        {
            if (Day != null && Day.Active) Day.EndDay();
            agendaOpen = false;
            pendingPlan = null;
            if (UI == null) return;
            UI.Agenda.Hide();
            UI.DayIntro.Hide();
            UI.Summary.Hide();
        }

        public void ContinueGame() => StartCoroutine(Transition(() => ShowDayIntro(Save.dayIndex)));

        public void NewGame()
        {
            SaveSystem.Delete();
            Save = new SaveData();
            StartCoroutine(Transition(() => ShowDayIntro(0)));
        }

        public void NextDay() => StartCoroutine(Transition(() => ShowDayIntro(Save.dayIndex)));

        void ShowDayIntro(int dayIndex)
        {
            CleanupRun();
            prototype = null;
            caseId = null;
            UI.Menu.Hide();
            pendingPlan = StoryCampaign.Build(dayIndex);
            EnterInterfaceMode(GameMode.Screen);
            Audio.SetMusic(true);
            UI.DayIntro.Set(pendingPlan);
            UI.DayIntro.Show();
        }

        public void StartDay()
        {
            if (pendingPlan == null || transitioning) return;
            var plan = pendingPlan;
            pendingPlan = null;
            StartCoroutine(Transition(() =>
            {
                UI.DayIntro.Hide();
                dayFinished = false;
                Day.BeginDay(plan);
                Player.Teleport(World.PlayerSpawn, World.PlayerSpawnYaw);
                handsWashed = false;
                EnterExplore(0f);
                UI.Hud.SetObjectives(plan.Objectives);
                if (!string.IsNullOrEmpty(plan.SecretaryGreeting)) UI.Subtitle("Sophie", plan.SecretaryGreeting, 7f);
            }));
        }

        // ================================================================== agenda

        void OpenStoryAgenda()
        {
            if (agendaOpen || Mode != GameMode.Explore) return;
            agendaOpen = true;
            EnterInterfaceMode(GameMode.Screen);
            Clock.Running = true;   // le temps continue pendant la lecture de l'agenda
            UI.Agenda.Show();
        }

        public void CloseAgenda()
        {
            if (!agendaOpen) return;
            agendaOpen = false;
            UI.Agenda.Hide();
            EnterExplore(0.3f);
        }

        void UpdateStoryScreen()
        {
            if (!agendaOpen) return;
            UI.Agenda.Tick();
            if (GameInput.AgendaDown()) CloseAgenda();
            else if (GameInput.SkipTimeDown()) SkipTime();
        }

        public void SkipTime()
        {
            if (Day == null || !Day.CanSkipTime()) return;
            Day.SkipTime();
            Audio.PlayUI(Sfx.UiConfirm, 0.5f);
            UI.Toast("Le temps passe…", "Il est maintenant " + GameClock.FormatSpoken(Clock.Minutes) + ".", ToastKind.Info, 3f);
        }

        // ================================================================== fin de journée

        public void FinishDay()
        {
            if (Day == null || !Day.Active) return;
            OnDayCompleted(Day.BuildSummary());
        }

        void OnDayCompleted(DaySummary s)
        {
            if (dayFinished || Consult.Active) return;
            dayFinished = true;
            Save.days.Add(new DayRecord
            {
                dayIndex = s.Plan.Index,
                patientsSeen = s.Seen,
                patientsLost = s.Lost,
                averageScore = s.AverageScore,
                money = s.Money,
                reputationDelta = s.ReputationDelta
            });
            Save.money += s.Money;
            Save.reputation = Mathf.Clamp(Save.reputation + s.ReputationDelta, 0f, 100f);
            Save.totalPatients += s.Seen;
            Save.totalScore += s.AverageScore * s.Seen;
            Save.dayIndex = s.Plan.Index + 1;
            SaveSystem.Write(Save);

            CloseToolWheel(false);
            agendaOpen = false;
            UI.Agenda.Hide();
            EnterInterfaceMode(GameMode.Screen);
            UI.Summary.Set(s, Save);
            UI.Summary.Show();
            Audio.PlayUI(Sfx.Success, 0.7f);
        }
    }
}
#endif
