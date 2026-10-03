using System.Collections.Generic;
using BlouseBlanche.Core;
using BlouseBlanche.Gameplay;
using BlouseBlanche.Medical;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    public abstract class View
    {
        protected readonly UIRoot ui;
        public VisualElement Root { get; protected set; }
        public bool Visible { get; private set; }

        protected View(UIRoot ui) { this.ui = ui; }

        protected VisualElement MakeScreen(VisualElement parent, params string[] extra)
        {
            var e = UIX.Div(parent, "layer", "screen", "hidden");
            foreach (var c in extra) e.AddToClassList(c);
            Root = e;
            return e;
        }

        public virtual void Show() { Visible = true; UIX.Fade(Root, true); }
        public virtual void Hide() { Visible = false; UIX.Fade(Root, false); }
    }

    // ====================================================================== HUD

    public sealed class HudView : View
    {
        readonly Label day, time, status, nextCaption, nextName, nextDetail, waiting, promptVerb, promptTarget, promptKey;
        readonly VisualElement crosshair, prompt, promptBox, objectives, objList, skipHint, nextCard;
        readonly Label urgentChip;

        public HudView(UIRoot ui, VisualElement parent) : base(ui)
        {
            Root = UIX.Div(parent, "layer", "hidden");
            var clock = UIX.Div(Root, "hud-clock");
            day = UIX.Text(clock, "", "t-caption", "w600");
            time = UIX.Text(clock, "08:30", "mono-b", "t-h1");
            status = UIX.Text(clock, "", "t-small");

            nextCard = UIX.Div(Root, "hud-next");
            var nrow = UIX.Div(nextCard, "row");
            nextCaption = UIX.Text(nrow, "PROCHAIN PATIENT", "t-caption", "w600");
            UIX.Div(nrow, "spacer");
            urgentChip = UIX.Chip(nrow, "URGENCE", "solid-bad");
            UIX.Spacer(nextCard, 6);
            nextName = UIX.Text(nextCard, "", "w700", "t-h3");
            nextDetail = UIX.Text(nextCard, "", "t-small");
            UIX.Spacer(nextCard, 8);
            waiting = UIX.Chip(nextCard, "", "info");
            waiting.style.alignSelf = Align.FlexStart;

            objectives = UIX.Div(Root, "hud-objectives");
            UIX.Text(objectives, "OBJECTIFS", "t-caption", "w600");
            UIX.Spacer(objectives, 6);
            objList = UIX.Div(objectives, "col");

            crosshair = UIX.Div(Root, "crosshair");

            prompt = UIX.Div(Root, "prompt");
            promptBox = UIX.Div(prompt, "prompt-box");
            promptKey = UIX.Key(promptBox, "E");
            UIX.HSpace(promptBox, 12);
            var pcol = UIX.Div(promptBox, "col");
            promptVerb = UIX.Text(pcol, "", "w600", "t-h3");
            promptTarget = UIX.Text(pcol, "", "t-small");

            var hints = UIX.Div(Root, "hud-hints");
            Hint(hints, "Tab", "Agenda");
            Hint(hints, "Échap", "Pause");
            skipHint = Hint(hints, "F", "Avancer le temps");
            UIX.IgnorePicking(Root);
        }

        static VisualElement Hint(VisualElement parent, string key, string label)
        {
            var row = UIX.Div(parent, "row");
            row.style.marginRight = 22;
            UIX.Key(row, key);
            UIX.HSpace(row, 8);
            UIX.Text(row, label, "t-small");
            return row;
        }

        public void SetObjectives(string[] items)
        {
            objList.Clear();
            if (items == null) return;
            foreach (var s in items)
            {
                var row = UIX.Div(objList, "row");
                row.style.marginBottom = 4;
                var d = UIX.Div(row, "dot", "good");
                d.style.marginTop = 0;
                UIX.Text(row, s, "t-small");
            }
            UIX.IgnorePicking(objList);
        }

        public void Tick(GameRoot g)
        {
            if (!Visible) return;
            var dd = g.Day;
            day.text = dd.Plan != null ? ("JOUR " + (dd.Plan.Index + 1) + " · " + dd.Plan.DateLabel.ToUpperInvariant()) : "";
            time.text = GameClock.Format(g.Clock.Minutes);
            int seen = 0, total = dd.Visits.Count, waitingCount = 0;
            foreach (var v in dd.Visits)
            {
                if (v.Status == VisitStatus.Done) seen++;
                if (v.Status == VisitStatus.Waiting) waitingCount++;
            }
            status.text = seen + " / " + total + " patients vus · " + g.Save.money + " €";

            var next = dd.NextToCall();
            var active = dd.ActiveConsultVisit();
            urgentChip.EnableInClassList("hidden", next == null || !next.IsUrgent);
            if (active != null)
            {
                nextCaption.text = active.Status == VisitStatus.Called ? "PATIENT APPELÉ" : "AU CABINET";
                nextName.text = active.Patient.DisplayName;
                nextDetail.text = active.Status == VisitStatus.Called ? "Se rend dans votre cabinet…" : "Vous attend dans le cabinet : allez lui parler (E).";
            }
            else if (next != null)
            {
                nextCaption.text = "EN SALLE D'ATTENTE";
                nextName.text = next.Patient.DisplayName + " · " + next.Patient.AgeLabel;
                nextDetail.text = next.Patient.Case.Motif + (next.Plan.WalkIn ? " · sans rendez-vous" : " · RDV " + GameClock.FormatSpoken(next.ScheduledTime));
            }
            else
            {
                VisitRuntime up = null;
                foreach (var v in dd.Visits) if (v.Status == VisitStatus.Upcoming && !v.Plan.WalkIn && (up == null || v.ScheduledTime < up.ScheduledTime)) up = v;
                nextCaption.text = up != null ? "PROCHAIN RENDEZ-VOUS" : (dd.AllDone ? "JOURNÉE TERMINÉE" : "EN ATTENTE");
                nextName.text = up != null ? up.Patient.DisplayName : (dd.AllDone ? "Tous les patients ont été vus" : "Aucun patient pour l'instant");
                nextDetail.text = up != null ? "RDV " + GameClock.FormatSpoken(up.ScheduledTime) + " · " + up.Patient.Case.Motif : "";
            }
            waiting.text = waitingCount == 0 ? "Salle d'attente vide" : waitingCount + (waitingCount > 1 ? " patients en attente" : " patient en attente");
            skipHint.EnableInClassList("hidden", !dd.CanSkipTime());
        }

        public void SetPrompt(IInteractable it)
        {
            bool show = it != null && !string.IsNullOrEmpty(it.InteractionVerb);
            prompt.EnableInClassList("visible", show);
            crosshair.EnableInClassList("target", show);
            if (!show) return;
            promptVerb.text = it.InteractionVerb;
            promptTarget.text = it.CanInteract ? it.InteractionTarget : (string.IsNullOrEmpty(it.UnavailableReason) ? it.InteractionTarget : it.UnavailableReason);
            promptBox.EnableInClassList("disabled", !it.CanInteract);
        }

        public override void Show() { base.Show(); Root.RemoveFromClassList("hidden"); }
        public override void Hide() { base.Hide(); Root.AddToClassList("hidden"); }

        public void SetObjectivesVisible(bool v) => objectives.EnableInClassList("hidden", !v);
    }

    // ====================================================================== Menu principal

    public sealed class MainMenuView : View
    {
        readonly GameRoot game;
        readonly Button continueBtn;
        readonly Label stats;

        public MainMenuView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            this.game = game;
            var s = MakeScreen(parent);
            s.pickingMode = PickingMode.Ignore;
            var grad = UIX.Div(s, "menu-gradient");
            grad.pickingMode = PickingMode.Ignore;

            var col = UIX.Div(s, "col");
            col.style.position = Position.Absolute;
            col.style.left = 120;
            col.style.top = 150;
            col.style.width = 560;

            var brand = UIX.Div(col, "row");
            var mark = UIX.Div(brand, "logo-mark");
            UIX.Div(mark, "logo-cross-v");
            UIX.Div(mark, "logo-cross-h");
            var titles = UIX.Div(brand, "col");
            UIX.Text(titles, "BLOUSE", "w800", "t-display");
            var t2 = UIX.Text(titles, "BLANCHE", "w800", "t-display", "t-accent");
            t2.style.marginTop = -26;
            UIX.Spacer(col, 6);
            UIX.Text(col, "Simulateur de médecine générale · Mode histoire", "t-body");
            UIX.Spacer(col, 56);

            continueBtn = UIX.Plain(col, "Continuer", () => game.ContinueGame(), "menu-item");
            UIX.Plain(col, "Nouvelle partie", () =>
            {
                if (SaveSystem.HasSave()) ui.Confirm("Nouvelle partie", "Votre progression actuelle sera effacée. Commencer une nouvelle carrière au cabinet des Tilleuls ?", "Commencer", game.NewGame);
                else game.NewGame();
            }, "menu-item");
            UIX.Plain(col, "Paramètres", () => game.OpenSettings(), "menu-item");
            UIX.Plain(col, "Quitter", () => game.QuitGame(), "menu-item");
            UIX.Spacer(col, 30);
            stats = UIX.Text(col, "", "t-small");

            // Cartes de modes de jeu
            var modes = UIX.Div(s, "row");
            modes.style.position = Position.Absolute;
            modes.style.right = 60;
            modes.style.bottom = 60;
            Mode(modes, "MODE HISTOIRE", "Médecin généraliste", "Disponible", true);
            Mode(modes, "URGENCES", "Urgentiste / SAMU", "Bientôt", false);
            Mode(modes, "BLOC OPÉRATOIRE", "Chirurgie", "Bientôt", false);
            Mode(modes, "BAC À SABLE", "Création libre", "Bientôt", false);

            var ver = UIX.Text(s, "Prototype 0.1 · contenu pédagogique de jeu, ne remplace pas un avis médical", "t-tiny");
            ver.style.position = Position.Absolute;
            ver.style.left = 120;
            ver.style.bottom = 36;
        }

        static void Mode(VisualElement parent, string caption, string title, string state, bool active)
        {
            var card = UIX.Div(parent, "mode-card", active ? "active" : "locked");
            UIX.Text(card, caption, "t-caption", "w600");
            UIX.Spacer(card, 8);
            UIX.Text(card, title, "w700", "t-h3");
            UIX.Div(card, "spacer");
            UIX.Chip(card, state, active ? "accent" : "info").style.alignSelf = Align.FlexStart;
            card.RegisterCallback<PointerEnterEvent>(_ => UIX.Sound(Sfx.UiHover, 0.3f));
        }

        public override void Show()
        {
            bool has = SaveSystem.HasSave();
            continueBtn.EnableInClassList("hidden", !has);
            if (has)
            {
                var sd = game.Save;
                continueBtn.text = "Continuer · Jour " + (sd.dayIndex + 1);
                stats.text = "Réputation " + Mathf.RoundToInt(sd.reputation) + "/100 · " + sd.totalPatients + " patients soignés · note moyenne " + Mathf.RoundToInt(sd.AverageScore) + "/100";
            }
            else stats.text = "";
            base.Show();
        }
    }

    // ====================================================================== Pause

    public sealed class PauseView : View
    {
        public PauseView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            var s = MakeScreen(parent, "scrim");
            s.style.alignItems = Align.Center;
            s.style.justifyContent = Justify.Center;
            var p = UIX.Div(s, "panel");
            p.style.width = 460;
            UIX.Text(p, "PAUSE", "t-caption", "w600");
            UIX.Spacer(p, 6);
            UIX.Text(p, "Le cabinet est en suspens", "w700", "t-h2");
            UIX.Spacer(p, 22);
            UIX.Btn(p, "Reprendre", () => game.Resume(), "primary", "big");
            UIX.Spacer(p, 10);
            UIX.Btn(p, "Paramètres", () => game.OpenSettings());
            UIX.Spacer(p, 10);
            UIX.Btn(p, "Menu principal", () => ui.Confirm("Retour au menu", "La journée en cours ne sera pas sauvegardée. Vous reprendrez au début de cette journée.", "Quitter la journée", game.BackToMenu));
            UIX.Spacer(p, 10);
            UIX.Btn(p, "Quitter le jeu", () => ui.Confirm("Quitter", "Quitter Blouse Blanche ? La journée en cours sera perdue.", "Quitter", game.QuitGame), "ghost");
        }
    }

    // ====================================================================== Paramètres

    public sealed class SettingsView : View
    {
        readonly GameRoot game;
        readonly VisualElement body;

        public SettingsView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            this.game = game;
            var s = MakeScreen(parent, "scrim");
            s.style.alignItems = Align.Center;
            s.style.justifyContent = Justify.Center;
            var p = UIX.Div(s, "panel");
            p.style.width = 780;
            var head = UIX.Div(p, "row");
            var tcol = UIX.Div(head, "col");
            UIX.Text(tcol, "RÉGLAGES", "t-caption", "w600");
            UIX.Text(tcol, "Paramètres", "w700", "t-h2");
            UIX.Div(head, "spacer");
            UIX.Btn(head, "Terminé", () => game.CloseSettings(), "primary");
            UIX.Spacer(p, 12);
            body = UIX.Div(p, "col");
        }

        public override void Show()
        {
            Rebuild();
            base.Show();
        }

        void Rebuild()
        {
            body.Clear();
            var st = game.Settings;
            Section("Contrôles");
            Slider("Sensibilité de la souris", 0.2f, 3f, st.mouseSensitivity, v => st.mouseSensitivity = v, v => v.ToString("0.00"));
            Toggle("Inverser l'axe vertical", st.invertY, v => st.invertY = v);
            Slider("Champ de vision", 60f, 95f, st.fieldOfView, v => st.fieldOfView = Mathf.Round(v), v => Mathf.RoundToInt(v) + "°");
            Toggle("Balancement de la tête", st.headBob, v => st.headBob = v);
            Section("Affichage");
            Segmented("Qualité graphique", new[] { "Basse", "Moyenne", "Haute", "Ultra" }, st.quality, v => st.quality = v);
            Slider("Luminosité", -1f, 1f, st.brightness, v => st.brightness = v, v => (v >= 0 ? "+" : "") + v.ToString("0.0"));
            Toggle("Synchronisation verticale", st.vSync, v => st.vSync = v);
            Toggle("Plein écran", st.fullscreen, v => st.fullscreen = v);
            Section("Son");
            Slider("Volume général", 0f, 1f, st.masterVolume, v => st.masterVolume = v, v => Mathf.RoundToInt(v * 100) + " %");
            Slider("Musique", 0f, 1f, st.musicVolume, v => st.musicVolume = v, v => Mathf.RoundToInt(v * 100) + " %");
            Section("Aide");
            Toggle("Afficher les objectifs et conseils", st.showTutorialHints, v => st.showTutorialHints = v);
        }

        void Section(string name)
        {
            UIX.Spacer(body, 10);
            UIX.Text(body, name.ToUpperInvariant(), "t-caption", "w600");
            UIX.Spacer(body, 6);
        }

        VisualElement Row(string label)
        {
            var r = UIX.Div(body, "row");
            r.style.height = 42;
            var l = UIX.Text(r, label, "t-body");
            l.style.width = 300;
            return r;
        }

        void Slider(string label, float min, float max, float value, System.Action<float> set, System.Func<float, string> fmt)
        {
            var r = Row(label);
            var sl = new BBSlider(min, max, value);
            r.Add(sl);
            UIX.HSpace(r, 14);
            var val = UIX.Text(r, fmt(value), "mono", "t-small");
            val.style.width = 70;
            val.AddToClassList("t-right");
            sl.Changed += v => { set(v); val.text = fmt(v); game.ApplySettings(); };
        }

        void Toggle(string label, bool value, System.Action<bool> set)
        {
            var r = Row(label);
            UIX.Div(r, "spacer");
            var t = new BBToggle(value);
            r.Add(t);
            t.Changed += v => { set(v); game.ApplySettings(); };
        }

        void Segmented(string label, string[] options, int value, System.Action<int> set)
        {
            var r = Row(label);
            var seg = new BBSegmented(options, value);
            seg.style.flexGrow = 1;
            r.Add(seg);
            seg.Changed += v => { set(v); game.ApplySettings(); };
        }
    }

}
