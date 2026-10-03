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
        readonly Label day, time, status, nextCaption, nextName, nextDetail, waiting, promptVerb, promptTarget, promptKey, urgentChip;
        readonly VisualElement crosshair, prompt, promptBox, objectives, objList, hints, nextCard;
        string hintsSignature, objectivesSignature;

        public HudView(UIRoot ui, VisualElement parent) : base(ui)
        {
            Root = UIX.Div(parent, "layer", "hidden");
            var clock = UIX.Div(Root, "hud-clock");
            day = UIX.Text(clock, "", "t-caption", "w600");
            time = UIX.Text(clock, "08:30", "mono-b", "t-h1");
            status = UIX.Text(clock, "", "t-small");

            nextCard = UIX.Div(Root, "hud-next");
            var nrow = UIX.Div(nextCard, "row");
            nextCaption = UIX.Text(nrow, "", "t-caption", "w600");
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

            hints = UIX.Div(Root, "hud-hints");
            SetHints("E", "Interagir", "Maj", "Courir", "Échap", "Pause");
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

        /// <summary>Raccourcis affichés en bas à gauche : paires (touche, action).</summary>
        public void SetHints(params string[] pairs)
        {
            string sig = string.Join("|", pairs);
            if (sig == hintsSignature) return;
            hintsSignature = sig;
            hints.Clear();
            for (int i = 0; i + 1 < pairs.Length; i += 2) Hint(hints, pairs[i], pairs[i + 1]);
            UIX.IgnorePicking(hints);
        }

        /// <summary>Carte horloge (en haut à gauche).</summary>
        public void SetClock(string caption, string clock, string detail)
        {
            day.text = caption ?? "";
            time.text = clock ?? "";
            status.text = detail ?? "";
        }

        /// <summary>Carte d'information (en haut à droite) : patient, intervention…</summary>
        public void SetCard(string caption, string name, string detail, string chip = null, bool urgent = false)
        {
            nextCaption.text = caption ?? "";
            nextName.text = name ?? "";
            nextDetail.text = detail ?? "";
            urgentChip.EnableInClassList("hidden", !urgent);
            waiting.text = chip ?? "";
            UIX.Show(waiting, !string.IsNullOrEmpty(chip));
        }

        public void SetObjectives(string[] items, bool[] done = null)
        {
            string sig = items == null ? "" : string.Join("|", items);
            if (done != null) foreach (var d in done) sig += d ? "1" : "0";
            if (sig == objectivesSignature) return;
            objectivesSignature = sig;
            objList.Clear();
            if (items == null) return;
            for (int i = 0; i < items.Length; i++)
            {
                bool ok = done != null && i < done.Length && done[i];
                var row = UIX.Div(objList, "row");
                row.style.marginBottom = 4;
                var d = UIX.Div(row, "dot", ok ? "good" : "");
                d.style.marginTop = 0;
                var t = UIX.Text(row, items[i], "t-small", ok ? "t-muted" : "");
                t.style.flexShrink = 1;
            }
            UIX.IgnorePicking(objList);
        }

#if BB_STORY_MODE
        /// <summary>Mode histoire : horloge, patients vus, prochain patient, salle d'attente.</summary>
        public void TickStory(GameRoot g)
        {
            if (!Visible) return;
            var dd = g.Day;
            int seen = 0, total = dd.Visits.Count, waitingCount = 0;
            foreach (var v in dd.Visits)
            {
                if (v.Status == VisitStatus.Done) seen++;
                if (v.Status == VisitStatus.Waiting) waitingCount++;
            }
            SetClock(dd.Plan != null ? ("JOUR " + (dd.Plan.Index + 1) + " · " + dd.Plan.DateLabel.ToUpperInvariant()) : "",
                GameClock.Format(g.Clock.Minutes), seen + " / " + total + " patients vus · " + g.Save.money + " €");

            var next = dd.NextToCall();
            var active = dd.ActiveConsultVisit();
            string chip = waitingCount == 0 ? "Salle d'attente vide" : waitingCount + (waitingCount > 1 ? " patients en attente" : " patient en attente");
            if (active != null)
            {
                SetCard(active.Status == VisitStatus.Called ? "PATIENT APPELÉ" : "AU CABINET", active.Patient.DisplayName,
                    active.Status == VisitStatus.Called ? "Se rend dans votre cabinet…" : "Vous attend dans le cabinet : allez lui parler (E).", chip, active.IsUrgent);
            }
            else if (next != null)
            {
                SetCard("EN SALLE D'ATTENTE", next.Patient.DisplayName + " · " + next.Patient.AgeLabel,
                    next.Patient.Case.Motif + (next.Plan.WalkIn ? " · sans rendez-vous" : " · RDV " + GameClock.FormatSpoken(next.ScheduledTime)), chip, next.IsUrgent);
            }
            else
            {
                VisitRuntime up = null;
                foreach (var v in dd.Visits) if (v.Status == VisitStatus.Upcoming && !v.Plan.WalkIn && (up == null || v.ScheduledTime < up.ScheduledTime)) up = v;
                SetCard(up != null ? "PROCHAIN RENDEZ-VOUS" : (dd.AllDone ? "JOURNÉE TERMINÉE" : "EN ATTENTE"),
                    up != null ? up.Patient.DisplayName : (dd.AllDone ? "Tous les patients ont été vus" : "Aucun patient pour l'instant"),
                    up != null ? "RDV " + GameClock.FormatSpoken(up.ScheduledTime) + " · " + up.Patient.Case.Motif : "", chip);
            }
            if (dd.CanSkipTime()) SetHints("Tab", "Agenda", "E", "Interagir", "F", "Avancer le temps", "Échap", "Pause");
            else SetHints("Tab", "Agenda", "E", "Interagir", "Échap", "Pause");
        }
#endif

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
        public override void Hide() { base.Hide(); Root.AddToClassList("hidden"); SetPrompt(null); }

        public void SetObjectivesVisible(bool v) => objectives.EnableInClassList("hidden", !v);
    }

    // ====================================================================== Menu principal

    /// <summary>
    /// Menu principal : choix d'un prototype (consultation, SAMU, urgences) puis d'un cas.
    /// Le mode histoire n'apparaît qu'avec le symbole BB_STORY_MODE.
    /// </summary>
    public sealed class MainMenuView : View
    {
        readonly GameRoot game;
        readonly VisualElement picker, caseList;
        readonly Label pickCaption, pickTitle, pickDesc, pickCount;
        readonly Button launchBtn;
        readonly Dictionary<PrototypeKind, Button> protoButtons = new Dictionary<PrototypeKind, Button>();
        readonly Dictionary<string, Button> caseRows = new Dictionary<string, Button>();
        PrototypeKind? current;
        string selectedCase;
        float lastSelectTime;
#if BB_STORY_MODE
        readonly VisualElement storyPanel;
        readonly Button continueBtn, storyBtn;
        readonly Label stats;
#endif

        public PrototypeKind? CurrentPrototype => current;

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
            col.style.top = 130;
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
            UIX.Text(col, "Simulateur médical · prototypes jouables", "t-body");
            UIX.Spacer(col, 44);

            UIX.Text(col, "PROTOTYPES", "t-caption", "w600");
            UIX.Spacer(col, 6);
            foreach (var k in PrototypeCatalog.All)
            {
                var kind = k;
                protoButtons[k] = UIX.Plain(col, PrototypeCatalog.Name(k), () => OpenPicker(kind), "menu-item");
            }
#if BB_STORY_MODE
            storyBtn = UIX.Plain(col, "Mode histoire", OpenStory, "menu-item");
#endif
            UIX.Spacer(col, 18);
            UIX.Plain(col, "Paramètres", () => game.OpenSettings(), "menu-item");
            UIX.Plain(col, "Quitter", () => game.QuitGame(), "menu-item");

            // ------------------------------------------------------------ sélection du cas
            picker = UIX.Div(s, "panel", "col");
            picker.style.position = Position.Absolute;
            picker.style.right = 80;
            picker.style.top = 90;
            picker.style.bottom = 90;
            picker.style.width = 720;
            var head = UIX.Div(picker, "row");
            var hcol = UIX.Div(head, "col", "grow");
            pickCaption = UIX.Text(hcol, "", "t-caption", "w600");
            pickTitle = UIX.Text(hcol, "", "w800", "t-h2");
            UIX.Btn(head, "Fermer", ClosePicker, "ghost", "small");
            UIX.Spacer(picker, 10);
            pickDesc = UIX.Text(picker, "", "t-body");
            UIX.Spacer(picker, 16);
            pickCount = UIX.Text(picker, "", "t-caption", "w600");
            UIX.Spacer(picker, 8);
            var scroll = new ScrollView(ScrollViewMode.Vertical);
            scroll.style.flexGrow = 1;
            picker.Add(scroll);
            caseList = scroll.contentContainer;
            UIX.Spacer(picker, 14);
            var foot = UIX.Div(picker, "row");
            UIX.Btn(foot, "Cas au hasard", () => { if (current.HasValue) game.StartPrototype(current.Value, null); });
            UIX.Div(foot, "spacer");
            launchBtn = UIX.Btn(foot, "Lancer le cas", Launch, "primary", "big");
            UIX.Show(picker, false);

#if BB_STORY_MODE
            storyPanel = UIX.Div(s, "panel", "col");
            storyPanel.style.position = Position.Absolute;
            storyPanel.style.right = 80;
            storyPanel.style.top = 90;
            storyPanel.style.width = 720;
            UIX.Text(storyPanel, "MODE HISTOIRE · EXPÉRIMENTAL", "t-caption", "w600");
            UIX.Text(storyPanel, "Le cabinet des Tilleuls", "w800", "t-h2");
            UIX.Spacer(storyPanel, 10);
            UIX.Text(storyPanel, "Reprenez la patientèle du Dr Lemoine : des matinées entières de consultations, des imprévus, des urgences, une réputation à construire.", "t-body");
            UIX.Spacer(storyPanel, 14);
            stats = UIX.Text(storyPanel, "", "t-small");
            UIX.Spacer(storyPanel, 18);
            var srow = UIX.Div(storyPanel, "row");
            continueBtn = UIX.Btn(srow, "Continuer", () => game.ContinueGame(), "primary", "big");
            UIX.HSpace(srow, 12);
            UIX.Btn(srow, "Nouvelle partie", () =>
            {
                if (SaveSystem.HasSave()) ui.Confirm("Nouvelle partie", "Votre progression actuelle sera effacée. Commencer une nouvelle carrière au cabinet des Tilleuls ?", "Commencer", game.NewGame);
                else game.NewGame();
            });
            UIX.Show(storyPanel, false);
#endif

            var ver = UIX.Text(s, "Prototype 0.2 · contenu pédagogique de jeu, ne remplace pas un avis médical", "t-tiny");
            ver.style.position = Position.Absolute;
            ver.style.left = 120;
            ver.style.bottom = 36;
        }

        /// <summary>Affiche le menu ; ouvre directement la liste des cas d'un prototype si demandé.</summary>
        public void Show(PrototypeKind? openPicker)
        {
            if (openPicker.HasValue) OpenPicker(openPicker.Value);
            Show();
        }

        public override void Show()
        {
#if BB_STORY_MODE
            bool has = SaveSystem.HasSave();
            continueBtn.EnableInClassList("hidden", !has);
            if (has)
            {
                var sd = game.Save;
                continueBtn.text = "Continuer · Jour " + (sd.dayIndex + 1);
                stats.text = "Réputation " + Mathf.RoundToInt(sd.reputation) + "/100 · " + sd.totalPatients + " patients soignés · note moyenne " + Mathf.RoundToInt(sd.AverageScore) + "/100";
            }
            else stats.text = "Aucune partie en cours.";
#endif
            base.Show();
        }

        void OpenPicker(PrototypeKind kind)
        {
#if BB_STORY_MODE
            UIX.Show(storyPanel, false);
            storyBtn.RemoveFromClassList("selected");
#endif
            if (current != kind) selectedCase = null;
            current = kind;
            foreach (var kv in protoButtons) kv.Value.EnableInClassList("selected", kv.Key == kind);
            pickCaption.text = PrototypeCatalog.Caption(kind);
            pickTitle.text = PrototypeCatalog.Name(kind);
            pickDesc.text = PrototypeCatalog.Description(kind);
            RebuildCases();
            UIX.Show(picker, true);
        }

        void ClosePicker()
        {
            current = null;
            selectedCase = null;
            foreach (var kv in protoButtons) kv.Value.RemoveFromClassList("selected");
            UIX.Show(picker, false);
        }

#if BB_STORY_MODE
        void OpenStory()
        {
            ClosePicker();
            storyBtn.AddToClassList("selected");
            UIX.Show(storyPanel, true);
        }
#endif

        void RebuildCases()
        {
            caseList.Clear();
            caseRows.Clear();
            if (!current.HasValue) return;
            var cases = PrototypeCatalog.Cases(current.Value);
            pickCount.text = cases.Count + " CAS · DOUBLE-CLIC POUR LANCER";
            foreach (var c in cases)
            {
                string id = c.Id;
                var row = UIX.Plain(caseList, "", () => Select(id), "list-btn");
                row.style.flexDirection = FlexDirection.Column;
                row.style.alignItems = Align.Stretch;
                var top = UIX.Div(row, "row");
                var name = UIX.Text(top, c.Title, "w700");
                name.style.flexGrow = 1;
                name.style.flexShrink = 1;
                if (c.Urgent) { UIX.Chip(top, "URGENCE VITALE", "solid-bad"); UIX.HSpace(top, 6); }
                UIX.Chip(top, PrototypeCatalog.DifficultyLabel(c.Difficulty), c.Difficulty >= 3 ? "bad" : c.Difficulty == 2 ? "warn" : "ok");
                UIX.Spacer(row, 4);
                var detail = UIX.Text(row, c.Detail, "t-tiny");
                detail.style.whiteSpace = WhiteSpace.Normal;
                UIX.IgnorePicking(top);
                detail.pickingMode = PickingMode.Ignore;
                caseRows[id] = row;
            }
            RefreshSelection();
        }

        void Select(string id)
        {
            // Double clic sur le même cas : lancement direct.
            bool again = id == selectedCase && Time.unscaledTime - lastSelectTime < 0.45f;
            selectedCase = id;
            lastSelectTime = Time.unscaledTime;
            RefreshSelection();
            if (again) Launch();
        }

        void RefreshSelection()
        {
            foreach (var kv in caseRows) kv.Value.EnableInClassList("selected", kv.Key == selectedCase);
            launchBtn.SetEnabled(selectedCase != null);
        }

        void Launch()
        {
            if (!current.HasValue || selectedCase == null) return;
            game.StartPrototype(current.Value, selectedCase);
        }
    }

    // ====================================================================== Pause

    public sealed class PauseView : View
    {
        readonly Label subtitle;
        readonly Button restartBtn;
        string menuWarning = "La partie en cours sera abandonnée.";

        public PauseView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            var s = MakeScreen(parent, "scrim");
            s.style.alignItems = Align.Center;
            s.style.justifyContent = Justify.Center;
            var p = UIX.Div(s, "panel");
            p.style.width = 460;
            UIX.Text(p, "PAUSE", "t-caption", "w600");
            UIX.Spacer(p, 6);
            subtitle = UIX.Text(p, "Le temps est suspendu", "w700", "t-h2");
            UIX.Spacer(p, 22);
            UIX.Btn(p, "Reprendre", () => game.Resume(), "primary", "big");
            UIX.Spacer(p, 10);
            restartBtn = UIX.Btn(p, "Recommencer ce cas", () => ui.Confirm("Recommencer", "Reprendre ce cas depuis le début ?", "Recommencer", game.RestartCase));
            UIX.Spacer(p, 10);
            UIX.Btn(p, "Paramètres", () => game.OpenSettings());
            UIX.Spacer(p, 10);
            UIX.Btn(p, "Menu principal", () => ui.Confirm("Retour au menu", menuWarning, "Quitter", game.BackToMenu));
            UIX.Spacer(p, 10);
            UIX.Btn(p, "Quitter le jeu", () => ui.Confirm("Quitter", "Quitter Blouse Blanche ? " + menuWarning, "Quitter", game.QuitGame), "ghost");
        }

        /// <summary>Adapte la pause au contexte (prototype ou journée du mode histoire).</summary>
        public void Configure(string title, string warning, bool canRestart)
        {
            subtitle.text = title;
            menuWarning = warning;
            UIX.Show(restartBtn, canRestart);
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
