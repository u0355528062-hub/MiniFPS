using System;
using BlouseBlanche.Core;
using BlouseBlanche.Medical;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    /// <summary>Bilan d'une consultation : note, détail des critères, retours, point pédagogique.</summary>
    public sealed class ResultView : View
    {
        readonly GameRoot game;
        readonly VisualElement ring, stars, bars, feedback, teaching;
        readonly Label score, grade, title, diag, money;
        Action onContinue;

        public ResultView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            this.game = game;
            var s = MakeScreen(parent, "scrim");
            s.style.alignItems = Align.Center;
            s.style.justifyContent = Justify.Center;
            var p = UIX.Div(s, "panel");
            p.style.width = 1200;
            p.style.height = 800;
            p.style.flexDirection = FlexDirection.Row;

            // ------------------------------------------------------------ colonne note
            var left = UIX.Div(p, "col");
            left.style.width = 320;
            left.style.alignItems = Align.Center;
            UIX.Text(left, "BILAN DE CONSULTATION", "t-caption", "w600");
            UIX.Spacer(left, 18);
            ring = UIX.Div(left, "score-ring");
            score = UIX.Text(ring, "0", "w800", "t-display");
            UIX.Text(ring, "/ 100", "t-small");
            UIX.Spacer(left, 14);
            grade = UIX.Text(left, "", "w800", "t-h2");
            UIX.Spacer(left, 10);
            stars = UIX.Div(left, "row");
            UIX.Spacer(left, 24);
            title = UIX.Text(left, "", "w700", "t-h3", "t-center");
            UIX.Spacer(left, 6);
            diag = UIX.Text(left, "", "t-small", "t-center");
            UIX.Spacer(left, 18);
            money = UIX.Text(left, "", "w600", "t-success", "t-center");
            UIX.Div(left, "spacer");
            UIX.Btn(left, "Continuer", () => onContinue?.Invoke(), "primary", "big").style.alignSelf = Align.Stretch;

            UIX.HSpace(p, 30);

            // ------------------------------------------------------------ détail
            var right = UIX.Div(p, "col", "grow");
            UIX.Text(right, "CRITÈRES", "t-caption", "w600");
            UIX.Spacer(right, 8);
            bars = UIX.Div(right, "col");
            UIX.Spacer(right, 12);
            UIX.Text(right, "RETOURS", "t-caption", "w600");
            UIX.Spacer(right, 8);
            var fscroll = new ScrollView(ScrollViewMode.Vertical);
            fscroll.style.flexGrow = 1;
            right.Add(fscroll);
            feedback = fscroll.contentContainer;
            UIX.Spacer(right, 10);
            var tcard = UIX.Div(right, "panel-2");
            tcard.style.borderLeftWidth = 3;
            tcard.style.borderLeftColor = UIX.Hex("#2FD4C0");
            UIX.Text(tcard, "À RETENIR", "t-caption", "w600");
            UIX.Spacer(tcard, 6);
            teaching = UIX.Div(tcard, "col");
        }

        public void Set(PatientRecord patient, ConsultationResult r, Action continueAction)
        {
            onContinue = continueAction;
            string cls = r.Critical || r.Total < 50 ? "bad" : r.Total < 75 ? "warn" : "";
            ring.EnableInClassList("bad", cls == "bad");
            ring.EnableInClassList("warn", cls == "warn");
            AnimateScore(r.Total);
            grade.text = (r.Critical ? "Erreur critique" : GradeLabel(r.Grade)) + " · " + r.Grade;
            grade.EnableInClassList("t-danger", r.Critical);
            stars.Clear();
            for (int i = 0; i < 5; i++)
            {
                var d = UIX.Div(stars, "dot", i < r.Stars ? "good" : "");
                d.style.width = 16; d.style.height = 16; d.style.borderTopLeftRadius = 8; d.style.borderTopRightRadius = 8; d.style.borderBottomLeftRadius = 8; d.style.borderBottomRightRadius = 8;
                d.style.marginRight = 8;
                if (i >= r.Stars) d.style.backgroundColor = new Color(1f, 1f, 1f, 0.12f);
            }
            title.text = patient.FullName;
            diag.text = "Diagnostic attendu : " + r.CorrectDiagnosis + "\nVotre diagnostic : " + r.ChosenDiagnosis;
            money.text = "Honoraires : +" + r.Fee + " €   ·   Réputation " + (r.ReputationDelta >= 0 ? "+" : "") + r.ReputationDelta.ToString("0.0");

            bars.Clear();
            Bar("Démarche clinique", r.Approach, 20);
            Bar("Diagnostic", r.Diagnosis, 35);
            Bar("Traitement", r.Treatment, 30);
            Bar("Orientation", r.Orientation, 10);
            Bar("Efficacité", r.Efficiency, 5);
            Bar("Hygiène (bonus)", r.Hygiene, 3);

            feedback.Clear();
            foreach (var f in r.Feedback)
            {
                var row = UIX.Div(feedback, "feedback");
                string dot = f.Kind == FeedbackKind.Good ? "good" : f.Kind == FeedbackKind.Warning ? "warn" : f.Kind == FeedbackKind.Bad ? "bad" : f.Kind == FeedbackKind.Critical ? "critical" : "";
                UIX.Div(row, "dot", dot);
                var t = UIX.Text(row, f.Text, f.Kind == FeedbackKind.Critical ? "t-danger" : "", f.Kind == FeedbackKind.Critical ? "w700" : "");
                t.style.flexShrink = 1;
            }
            teaching.Clear();
            UIX.Text(teaching, r.Teaching ?? "", "t-body");
            Show();
        }

        static string GradeLabel(string g)
        {
            switch (g)
            {
                case "A+": return "Remarquable";
                case "A": return "Très bonne prise en charge";
                case "B": return "Bonne prise en charge";
                case "C": return "Prise en charge perfectible";
                default: return "Prise en charge insuffisante";
            }
        }

        void Bar(string label, int value, int max)
        {
            var row = UIX.Div(bars, "row");
            row.style.marginBottom = 9;
            var l = UIX.Text(row, label, "t-small");
            l.style.width = 180;
            var bar = UIX.Div(row, "bar", "grow");
            var fill = UIX.Div(bar, "bar-fill");
            float t = max > 0 ? Mathf.Clamp01(value / (float)max) : 0f;
            if (t < 0.5f) fill.AddToClassList(t < 0.25f ? "bad" : "warn");
            fill.style.width = Length.Percent(0);
            fill.schedule.Execute(() => fill.style.width = Length.Percent(t * 100f)).StartingIn(120);
            UIX.HSpace(row, 12);
            var v = UIX.Text(row, value + " / " + max, "mono", "t-small");
            v.style.width = 70;
            v.AddToClassList("t-right");
        }

        void AnimateScore(int target)
        {
            int shown = 0;
            score.text = "0";
            score.schedule.Execute(() =>
            {
                shown = Mathf.Min(target, shown + Mathf.Max(1, target / 30));
                score.text = shown.ToString();
            }).Every(25).Until(() => shown >= target);
        }
    }
}
