#if BB_STORY_MODE
// Mode histoire (mis en pause) : activer le symbole BB_STORY_MODE pour le réintégrer.
using BlouseBlanche.Core;
using BlouseBlanche.Gameplay;
using BlouseBlanche.Medical;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    /// <summary>Agenda / logiciel médical : planning du jour, dossiers, appel des patients, gestion du temps.</summary>
    public sealed class AgendaView : View
    {
        readonly GameRoot game;
        readonly Label date, clock, money, rep;
        readonly VisualElement list, dossier, actions;
        VisitRuntime selected;
        float refresh;

        public AgendaView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            this.game = game;
            var s = MakeScreen(parent, "scrim");
            s.style.alignItems = Align.Center;
            s.style.justifyContent = Justify.Center;
            var p = UIX.Div(s, "panel");
            p.style.width = 1280;
            p.style.height = 780;

            var head = UIX.Div(p, "row");
            var tcol = UIX.Div(head, "col");
            UIX.Text(tcol, "LOGICIEL MÉDICAL · AGENDA", "t-caption", "w600");
            date = UIX.Text(tcol, "", "w800", "t-h2");
            UIX.Div(head, "spacer");
            clock = UIX.Text(head, "", "mono-b", "t-h2");
            UIX.HSpace(head, 20);
            money = UIX.Chip(head, "", "ok");
            UIX.HSpace(head, 8);
            rep = UIX.Chip(head, "", "accent");
            UIX.HSpace(head, 16);
            UIX.Btn(head, "Fermer  (Tab)", () => game.CloseAgenda(), "ghost");
            UIX.Spacer(p, 16);

            var body = UIX.Div(p, "row");
            body.style.flexGrow = 1;
            body.style.alignItems = Align.Stretch;

            var left = UIX.Div(body, "col");
            left.style.width = 640;
            UIX.Text(left, "PLANNING DE LA MATINÉE", "t-caption", "w600");
            UIX.Spacer(left, 8);
            var scroll = new ScrollView(ScrollViewMode.Vertical);
            left.Add(scroll);
            list = scroll.contentContainer;

            UIX.HSpace(body, 20);
            var right = UIX.Div(body, "panel-2");
            right.style.flexGrow = 1;
            var dscroll = new ScrollView(ScrollViewMode.Vertical);
            right.Add(dscroll);
            dossier = dscroll.contentContainer;

            UIX.Spacer(p, 14);
            actions = UIX.Div(p, "row");
        }

        public override void Show()
        {
            selected = game.Day.NextToCall() ?? selected;
            Rebuild();
            base.Show();
        }

        public void Tick()
        {
            if (!Visible) return;
            refresh -= Time.unscaledDeltaTime;
            clock.text = GameClock.Format(game.Clock.Minutes);
            if (refresh <= 0f)
            {
                refresh = 0.5f;
                string sig = Signature();
                if (sig != lastSignature) Rebuild();
            }
        }

        string lastSignature;

        string Signature()
        {
            var sb = new System.Text.StringBuilder();
            foreach (var v in game.Day.Visits) sb.Append((int)v.Status).Append(',');
            sb.Append(selected != null ? selected.Order : -1).Append(game.Day.CanSkipTime() ? 'S' : 's');
            return sb.ToString();
        }

        public void Rebuild()
        {
            lastSignature = Signature();
            var dd = game.Day;
            date.text = dd.Plan != null ? dd.Plan.DateLabel : "";
            clock.text = GameClock.Format(game.Clock.Minutes);
            money.text = game.Save.money + " €";
            rep.text = "Réputation " + Mathf.RoundToInt(game.Save.reputation);

            list.Clear();
            foreach (var v in dd.Visits)
            {
                var visit = v;
                bool visible = !v.Plan.WalkIn || v.Status != VisitStatus.Upcoming;
                if (!visible) continue;
                var row = UIX.Div(list, "card", "row");
                row.style.marginBottom = 8;
                if (selected == v) row.style.borderLeftColor = UIX.Hex("#2FD4C0");
                row.style.borderLeftWidth = selected == v ? 3 : 1;
                var time = UIX.Text(row, v.Plan.WalkIn ? GameClock.Format(v.ArrivalMinute) : GameClock.Format(v.ScheduledTime), "mono-b", "t-h3");
                time.style.width = 82;
                var c = UIX.Div(row, "col", "grow");
                var nm = UIX.Div(c, "row");
                UIX.Text(nm, v.Patient.DisplayName, "w700");
                UIX.HSpace(nm, 8);
                UIX.Text(nm, v.Patient.AgeLabel, "t-small");
                if (v.Plan.WalkIn) { UIX.HSpace(nm, 8); UIX.Chip(nm, "Sans RDV", "warn"); }
                if (v.IsUrgent && v.Status != VisitStatus.Upcoming) { UIX.HSpace(nm, 6); UIX.Chip(nm, "URGENCE", "solid-bad"); }
                UIX.Text(c, v.Patient.Case.Motif, "t-small");
                UIX.Chip(row, v.StatusLabel, StatusKind(v.Status));
                row.RegisterCallback<ClickEvent>(_ => { selected = visit; UIX.Sound(Sfx.UiClick, 0.4f); Rebuild(); });
                row.RegisterCallback<PointerEnterEvent>(_ => row.style.backgroundColor = new Color(1f, 1f, 1f, 0.07f));
                row.RegisterCallback<PointerLeaveEvent>(_ => row.style.backgroundColor = StyleKeyword.Null);
            }

            BuildDossier();
            BuildActions();
        }

        static string StatusKind(VisitStatus s)
        {
            switch (s)
            {
                case VisitStatus.Done: return "ok";
                case VisitStatus.Waiting: case VisitStatus.CheckIn: return "warn";
                case VisitStatus.Called: case VisitStatus.Ready: case VisitStatus.Consulting: return "accent";
                case VisitStatus.Left: case VisitStatus.Transferred: return "bad";
                default: return "info";
            }
        }

        void BuildDossier()
        {
            dossier.Clear();
            if (selected == null)
            {
                UIX.Text(dossier, "Sélectionnez un patient pour ouvrir son dossier.", "t-body");
                return;
            }
            var p = selected.Patient;
            var head = UIX.Div(dossier, "row");
            var av = UIX.Div(head, "avatar");
            UIX.Text(av, Initials(p), "w800", "t-h3", "t-accent");
            UIX.HSpace(head, 14);
            var hc = UIX.Div(head, "col");
            UIX.Text(hc, p.FullName, "w800", "t-h2");
            UIX.Text(hc, (p.Sex == Characters.Sex.Homme ? "Homme" : "Femme") + " · " + p.AgeLabel + " · " + selected.StatusLabel, "t-small");
            UIX.Spacer(dossier, 16);
            Field("Motif de consultation", p.Case.Motif);
            Field("Antécédents", p.History != null && p.History.Length > 0 ? string.Join(" · ", p.History) : "Aucun antécédent notable");
            Field("Traitements en cours", p.Meds != null && p.Meds.Length > 0 ? string.Join(" · ", p.Meds) : "Aucun");
            bool allergic = p.Allergies != null && p.Allergies.Length > 0;
            Field("Allergies", allergic ? string.Join(" · ", p.Allergies) : "Aucune allergie connue", allergic ? "t-danger" : null);
            if (!string.IsNullOrEmpty(p.Notes)) Field("Documents apportés", p.Notes);
            if (selected.Result != null)
            {
                UIX.Spacer(dossier, 6);
                Field("Consultation du jour", "Note " + selected.Result.Total + "/100 (" + selected.Result.Grade + ") · " + selected.Result.CorrectDiagnosis);
            }
        }

        void Field(string label, string value, string valueClass = null)
        {
            UIX.Text(dossier, label.ToUpperInvariant(), "t-caption", "w600");
            UIX.Spacer(dossier, 4);
            UIX.Text(dossier, value, "t-body", valueClass);
            UIX.Spacer(dossier, 14);
        }

        static string Initials(PatientRecord p) => (p.FirstName.Length > 0 ? p.FirstName.Substring(0, 1) : "") + (p.LastName.Length > 0 ? p.LastName.Substring(0, 1) : "");

        void BuildActions()
        {
            actions.Clear();
            var dd = game.Day;
            var next = dd.NextToCall();
            if (selected != null && selected.Status == VisitStatus.Waiting)
            {
                var b = UIX.Btn(actions, "Appeler " + selected.Patient.ShortName, () => { dd.CallPatient(selected); game.CloseAgenda(); }, "primary");
                b.SetEnabled(dd.CanCall(selected));
                UIX.HSpace(actions, 10);
            }
            if (next != null && next != selected)
            {
                var b2 = UIX.Btn(actions, "Appeler le patient suivant (" + next.Patient.ShortName + ")", () => { dd.CallPatient(next); game.CloseAgenda(); });
                b2.SetEnabled(dd.CanCall(next));
                UIX.HSpace(actions, 10);
            }
            UIX.Div(actions, "spacer");
            if (dd.CanSkipTime())
            {
                UIX.Btn(actions, "Avancer jusqu'au prochain patient  (F)", () => { game.SkipTime(); Rebuild(); });
                UIX.HSpace(actions, 10);
            }
            if (dd.AllDone) UIX.Btn(actions, "Terminer la journée", () => game.FinishDay(), "primary");
            var active = dd.ActiveConsultVisit();
            if (active != null)
            {
                var hint = UIX.Text(actions, active.Patient.ShortName + (active.Status == VisitStatus.Called ? " se rend au cabinet." : " vous attend au cabinet."), "t-small");
                hint.style.marginLeft = 10;
            }
        }
    }
}
#endif
