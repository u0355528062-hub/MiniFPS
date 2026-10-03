#if BB_STORY_MODE
// Vues du mode histoire (mis en pause) : activer le symbole BB_STORY_MODE pour les réintégrer.
using BlouseBlanche.Core;
using BlouseBlanche.Gameplay;
using BlouseBlanche.Medical;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    // ====================================================================== Introduction de journée

    public sealed class DayIntroView : View
    {
        readonly GameRoot game;
        readonly Label caption, title, intro, hours;
        readonly VisualElement objectives;

        public DayIntroView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            this.game = game;
            var s = MakeScreen(parent, "scrim-strong");
            s.style.alignItems = Align.Center;
            s.style.justifyContent = Justify.Center;
            var col = UIX.Div(s, "col");
            col.style.width = 920;
            caption = UIX.Text(col, "", "t-caption", "w600");
            UIX.Spacer(col, 10);
            title = UIX.Text(col, "", "w800", "t-h1");
            UIX.Spacer(col, 16);
            intro = UIX.Text(col, "", "t-body");
            intro.style.fontSize = 20;
            UIX.Spacer(col, 26);
            var card = UIX.Div(col, "panel-2");
            UIX.Text(card, "OBJECTIFS DU JOUR", "t-caption", "w600");
            UIX.Spacer(card, 8);
            objectives = UIX.Div(card, "col");
            UIX.Spacer(col, 14);
            hours = UIX.Text(col, "", "t-small");
            UIX.Spacer(col, 30);
            var row = UIX.Div(col, "row");
            UIX.Btn(row, "Commencer la journée", () => game.StartDay(), "primary", "big");
            UIX.HSpace(row, 14);
            UIX.Btn(row, "Menu principal", () => game.BackToMenu(), "ghost");
        }

        public void Set(DayPlan plan)
        {
            caption.text = "JOUR " + (plan.Index + 1) + " · " + plan.DateLabel.ToUpperInvariant();
            title.text = plan.Title;
            intro.text = plan.Intro;
            objectives.Clear();
            foreach (var o in plan.Objectives)
            {
                var r = UIX.Div(objectives, "row");
                r.style.marginBottom = 6;
                UIX.Div(r, "dot", "good").style.marginTop = 0;
                UIX.Text(r, o, "t-body");
            }
            int rdv = 0;
            foreach (var v in plan.Visits) if (!v.WalkIn) rdv++;
            hours.text = "Consultations de " + GameClock.FormatSpoken(plan.Open) + " à " + GameClock.FormatSpoken(plan.End) + " · " + rdv + " rendez-vous programmés · patients sans rendez-vous possibles";
        }
    }

    // ====================================================================== Fin de journée

    public sealed class DaySummaryView : View
    {
        readonly GameRoot game;
        readonly Label caption, title;
        readonly VisualElement stats, list;
        readonly Button nextBtn;

        public DaySummaryView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            this.game = game;
            var s = MakeScreen(parent, "scrim-strong");
            s.style.alignItems = Align.Center;
            s.style.justifyContent = Justify.Center;
            var p = UIX.Div(s, "panel");
            p.style.width = 1120;
            p.style.maxHeight = Length.Percent(90);
            caption = UIX.Text(p, "FIN DE JOURNÉE", "t-caption", "w600");
            title = UIX.Text(p, "", "w800", "t-h1");
            UIX.Spacer(p, 18);
            stats = UIX.Div(p, "row");
            UIX.Spacer(p, 18);
            UIX.Text(p, "PATIENTS DE LA MATINÉE", "t-caption", "w600");
            UIX.Spacer(p, 8);
            var scroll = new ScrollView(ScrollViewMode.Vertical);
            scroll.style.maxHeight = 340;
            p.Add(scroll);
            list = scroll.contentContainer;
            UIX.Spacer(p, 18);
            var row = UIX.Div(p, "row");
            UIX.Div(row, "spacer");
            UIX.Btn(row, "Menu principal", () => game.BackToMenu(), "ghost");
            UIX.HSpace(row, 12);
            nextBtn = UIX.Btn(row, "Journée suivante", () => game.NextDay(), "primary", "big");
        }

        public void Set(DaySummary s, SaveData save)
        {
            title.text = s.Plan.DateLabel + " — bilan";
            stats.Clear();
            Stat("Patients soignés", s.Seen + " / " + s.Visits.Count, s.Lost > 0 ? s.Lost + " parti(s) sans être vu(s)" : "Aucun patient perdu");
            Stat("Note moyenne", Mathf.RoundToInt(s.AverageScore) + " / 100", s.AverageScore >= 80 ? "Excellent travail" : s.AverageScore >= 60 ? "Solide" : "À améliorer");
            Stat("Honoraires", "+" + s.Money + " €", "Total : " + save.money + " €");
            Stat("Réputation", (s.ReputationDelta >= 0 ? "+" : "") + s.ReputationDelta.ToString("0.0"), "Actuelle : " + Mathf.RoundToInt(save.reputation) + " / 100");
            list.Clear();
            foreach (var v in s.Visits)
            {
                var r = UIX.Div(list, "card", "row");
                r.style.marginBottom = 8;
                var t = UIX.Text(r, GameClock.Format(v.ArrivalMinute > 0 ? v.ArrivalMinute : v.ScheduledTime), "mono", "t-small");
                t.style.width = 70;
                var c = UIX.Div(r, "col", "grow");
                UIX.Text(c, v.Patient.DisplayName + " · " + v.Patient.AgeLabel, "w600");
                UIX.Text(c, v.Patient.Case.Title + (v.Plan.WalkIn ? " · sans rendez-vous" : ""), "t-small");
                if (v.Result != null)
                {
                    UIX.Chip(r, v.Result.Grade + " · " + v.Result.Total + "/100", v.Result.Critical ? "bad" : v.Result.Total >= 80 ? "ok" : v.Result.Total >= 55 ? "warn" : "bad");
                }
                else UIX.Chip(r, v.StatusLabel, "bad");
            }
        }

        void Stat(string label, string value, string sub)
        {
            var st = UIX.Div(stats, "stat");
            UIX.Text(st, label.ToUpperInvariant(), "t-caption", "w600");
            UIX.Spacer(st, 6);
            UIX.Text(st, value, "w800", "t-h2");
            UIX.Text(st, sub, "t-small");
        }
    }
}
#endif
