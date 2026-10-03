using System;
using BlouseBlanche.Core;
using BlouseBlanche.Medical;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    /// <summary>Barème affiché : consultation de ville ou intervention SAMU / urgences.</summary>
    public enum ResultLayout { Consultation, Emergency }

    /// <summary>Bouton proposé sous la note (continuer, rejouer, autre cas…).</summary>
    public struct ResultAction
    {
        public string Label;
        public Action Run;
        public bool Primary;

        public ResultAction(string label, Action run, bool primary = false)
        {
            Label = label;
            Run = run;
            Primary = primary;
        }
    }

    /// <summary>Bilan d'une prise en charge : note, détail des critères, retours, point pédagogique.</summary>
    public sealed class ResultView : View
    {
        readonly VisualElement ring, stars, bars, feedback, teaching, actions;
        readonly Label caption, score, grade, title, diag, footnote;

        public ResultView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            var s = MakeScreen(parent, "scrim");
            s.style.alignItems = Align.Center;
            s.style.justifyContent = Justify.Center;
            var p = UIX.Div(s, "panel");
            p.style.width = 1200;
            p.style.height = 820;
            p.style.flexDirection = FlexDirection.Row;

            // ------------------------------------------------------------ colonne note
            var left = UIX.Div(p, "col");
            left.style.width = 320;
            left.style.alignItems = Align.Center;
            caption = UIX.Text(left, "BILAN DE CONSULTATION", "t-caption", "w600");
            UIX.Spacer(left, 16);
            ring = UIX.Div(left, "score-ring");
            score = UIX.Text(ring, "0", "w800", "t-display");
            UIX.Text(ring, "/ 100", "t-small");
            UIX.Spacer(left, 12);
            grade = UIX.Text(left, "", "w800", "t-h2", "t-center");
            UIX.Spacer(left, 8);
            stars = UIX.Div(left, "row");
            UIX.Spacer(left, 18);
            title = UIX.Text(left, "", "w700", "t-h3", "t-center");
            UIX.Spacer(left, 6);
            diag = UIX.Text(left, "", "t-small", "t-center");
            UIX.Spacer(left, 12);
            footnote = UIX.Text(left, "", "w600", "t-success", "t-center");
            UIX.Div(left, "spacer");
            actions = UIX.Div(left, "col");
            actions.style.alignSelf = Align.Stretch;

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

        /// <summary>Remplit et affiche le bilan.</summary>
        /// <param name="who">Nom du patient (ou intitulé du cas).</param>
        /// <param name="note">Ligne sous le diagnostic (honoraires, durée…), vide pour aucune.</param>
        public void Set(ResultLayout layout, string who, ConsultationResult r, string note, params ResultAction[] buttons)
        {
            caption.text = layout == ResultLayout.Emergency ? "BILAN D'INTERVENTION" : "BILAN DE CONSULTATION";
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
            title.text = who;
            diag.text = "Diagnostic attendu : " + r.CorrectDiagnosis + "\nVotre diagnostic : " + r.ChosenDiagnosis;
            footnote.text = note ?? "";
            UIX.Show(footnote, !string.IsNullOrEmpty(note));

            bars.Clear();
            if (layout == ResultLayout.Emergency)
            {
                Bar("Survie", r.Efficiency, 25);
                Bar("Gestes vitaux", r.Treatment, 40);
                Bar("Bilan", r.Approach, 15);
                Bar("Diagnostic", r.Diagnosis, 10);
                Bar("Orientation", r.Orientation, 10);
                if (r.Hygiene < 0) Penalty("Sécurité (pénalités)", r.Hygiene);
            }
            else
            {
                Bar("Démarche clinique", r.Approach, 20);
                Bar("Diagnostic", r.Diagnosis, 35);
                Bar("Traitement", r.Treatment, 30);
                Bar("Orientation", r.Orientation, 10);
                Bar("Efficacité", r.Efficiency, 5);
                Bar("Hygiène (bonus)", r.Hygiene, 3);
            }

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

            actions.Clear();
            for (int i = 0; i < buttons.Length; i++)
            {
                var a = buttons[i];
                if (i > 0) UIX.Spacer(actions, 8);
                var b = UIX.Btn(actions, a.Label, () => a.Run?.Invoke(), a.Primary ? "primary" : "", a.Primary ? "big" : "");
                b.style.alignSelf = Align.Stretch;
            }
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

        void Penalty(string label, int value)
        {
            var row = UIX.Div(bars, "row");
            row.style.marginBottom = 9;
            var l = UIX.Text(row, label, "t-small");
            l.style.width = 180;
            UIX.Div(row, "spacer");
            var v = UIX.Text(row, value.ToString(), "mono-b", "t-danger");
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
