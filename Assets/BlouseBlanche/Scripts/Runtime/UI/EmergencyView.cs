using System.Collections.Generic;
using BlouseBlanche.Core;
using BlouseBlanche.Emergency;
using BlouseBlanche.Gameplay;
using BlouseBlanche.Medical;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    /// <summary>
    /// Écran d'intervention SAMU / urgences : scope en direct, constantes mesurées, matériel et gestes,
    /// interrogatoire du témoin, diagnostic, orientation, journal horodaté.
    /// </summary>
    public sealed class EmergencyView : View
    {
        readonly GameRoot game;
        readonly Label caption, title, info, elapsed, clock, busyChip, scopeLabel, lastResult;
        readonly VisualElement chips, scopeImage, scopeOff, vitals, measures, pending, tabsRow, content, contentBlocker, footer;
        readonly ScrollView logScroll;
        readonly Dictionary<string, Button> tabs = new Dictionary<string, Button>();
        string tab = "gestes";
        float slowTimer;
        bool wheelByClick;

        EmergencyController E => game.Emergency;

        public EmergencyView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            this.game = game;
            var s = MakeScreen(parent);
            s.pickingMode = PickingMode.Ignore;

            // ------------------------------------------------------------ barre supérieure
            var top = UIX.Div(s, "row", "panel-2");
            top.style.position = Position.Absolute;
            top.style.left = 24; top.style.right = 24; top.style.top = 20;
            var av = UIX.Div(top, "avatar");
            var red = UIX.Hex("#FF5A6A");
            av.style.borderTopColor = red; av.style.borderRightColor = red; av.style.borderBottomColor = red; av.style.borderLeftColor = red;
            av.style.backgroundColor = new Color(0.25f, 0.06f, 0.09f, 1f);
            UIX.Div(av, "logo-cross-v").style.backgroundColor = UIX.Hex("#FF5A6A");
            UIX.Div(av, "logo-cross-h").style.backgroundColor = UIX.Hex("#FF5A6A");
            UIX.HSpace(top, 14);
            var ncol = UIX.Div(top, "col");
            ncol.style.flexShrink = 1;
            caption = UIX.Text(ncol, "", "t-caption", "w600");
            title = UIX.Text(ncol, "", "w800", "t-h2");
            info = UIX.Text(ncol, "", "t-small");
            UIX.HSpace(top, 16);
            chips = UIX.Div(top, "row");
            UIX.Div(top, "spacer");
            busyChip = UIX.Chip(top, "Geste en cours…", "accent");
            UIX.HSpace(top, 16);
            var tcol = UIX.Div(top, "col");
            UIX.Text(tcol, "PRISE EN CHARGE", "t-caption", "w600");
            elapsed = UIX.Text(tcol, "00:00", "mono-b", "t-h3");
            UIX.HSpace(top, 20);
            var ccol = UIX.Div(top, "col");
            UIX.Text(ccol, "HEURE", "t-caption", "w600");
            clock = UIX.Text(ccol, "", "mono-b", "t-h3");

            // ------------------------------------------------------------ colonne gauche : scope, constantes, état
            var left = UIX.Div(s, "panel");
            left.style.position = Position.Absolute;
            left.style.left = 24; left.style.top = 140; left.style.bottom = 24; left.style.width = 420;
            left.style.paddingTop = 16; left.style.paddingBottom = 16;
            var lscroll = new ScrollView(ScrollViewMode.Vertical);
            left.Add(lscroll);
            var lc = lscroll.contentContainer;
            var shead = UIX.Div(lc, "row");
            UIX.Text(shead, "SCOPE", "t-caption", "w600");
            UIX.Div(shead, "spacer");
            scopeLabel = UIX.Text(shead, "", "mono", "t-small");
            UIX.Spacer(lc, 8);
            var scopeBox = UIX.Div(lc, "scope-box");
            scopeImage = UIX.Div(scopeBox, "layer");
            scopeImage.pickingMode = PickingMode.Ignore;
            scopeOff = UIX.Div(scopeBox, "layer");
            scopeOff.style.alignItems = Align.Center;
            scopeOff.style.justifyContent = Justify.Center;
            UIX.Text(scopeOff, "Scope non branché", "w600", "t-dim");
            UIX.Text(scopeOff, "Matériel « Scope » : brancher le scope multiparamétrique", "t-tiny");
            UIX.IgnorePicking(scopeOff);
            UIX.Spacer(lc, 12);
            UIX.Text(lc, "CONSTANTES", "t-caption", "w600");
            UIX.Spacer(lc, 8);
            vitals = UIX.Div(lc, "row");
            vitals.style.flexWrap = Wrap.Wrap;
            UIX.Spacer(lc, 6);
            UIX.Text(lc, "EN COURS", "t-caption", "w600");
            UIX.Spacer(lc, 8);
            measures = UIX.Div(lc, "row");
            measures.style.flexWrap = Wrap.Wrap;
            UIX.Spacer(lc, 10);
            pending = UIX.Div(lc, "col");

            // ------------------------------------------------------------ colonne droite : onglets
            var right = UIX.Div(s, "panel");
            right.style.position = Position.Absolute;
            right.style.right = 24; right.style.top = 140; right.style.bottom = 24; right.style.width = 580;
            right.style.paddingTop = 12;
            tabsRow = UIX.Div(right, "tabs");
            Tab("gestes", "Matériel & gestes");
            Tab("interrogatoire", "Interrogatoire");
            Tab("diagnostic", "Diagnostic");
            Tab("orientation", "Orientation");
            var holder = UIX.Div(right, "grow");
            var contentScroll = new ScrollView(ScrollViewMode.Vertical);
            holder.Add(contentScroll);
            content = contentScroll.contentContainer;
            contentBlocker = UIX.Div(holder, "layer");
            contentBlocker.style.backgroundColor = new Color(0.05f, 0.08f, 0.13f, 0.45f);
            footer = UIX.Div(right, "col");

            // ------------------------------------------------------------ dernier résultat + journal
            lastResult = UIX.Text(s, "", "t-body", "result-banner");
            lastResult.style.position = Position.Absolute;
            lastResult.style.left = 468; lastResult.style.right = 628; lastResult.style.top = 140;

            var logPanel = UIX.Div(s, "panel-2");
            logPanel.style.position = Position.Absolute;
            logPanel.style.left = 468; logPanel.style.right = 628; logPanel.style.bottom = 24; logPanel.style.height = 250;
            logPanel.style.backgroundColor = new Color(0.04f, 0.07f, 0.12f, 0.84f);
            UIX.Text(logPanel, "JOURNAL DE L'INTERVENTION", "t-caption", "w600");
            UIX.Spacer(logPanel, 6);
            logScroll = new ScrollView(ScrollViewMode.Vertical);
            logPanel.Add(logScroll);

            var hint = UIX.Text(s, "Clic droit maintenu : roue du matériel  ·  1 à = : raccourcis  ·  Échap : pause", "t-tiny");
            hint.style.position = Position.Absolute;
            hint.style.left = 468; hint.style.bottom = 284;
        }

        void Tab(string id, string label)
        {
            var b = UIX.Plain(tabsRow, label, () => { tab = id; Refresh(); }, "tab");
            tabs[id] = b;
        }

        // ================================================================== cycle

        public void Begin()
        {
            var c = E.Case;
            tab = "gestes";
            caption.text = c.Setting == EmergencySetting.Samu ? "SAMU · INTERVENTION À DOMICILE" : "URGENCES · BOX 3";
            title.text = c.Title;
            info.text = E.PatientLabel + (E.HasWitness ? " · témoin : " + c.Witness : "") + " · " + E.Location.Name;
            chips.Clear();
            UIX.Chip(chips, PrototypeCatalog.DifficultyLabel(c.Difficulty), c.Difficulty >= 3 ? "bad" : c.Difficulty == 2 ? "warn" : "ok");
            lastResult.text = "";
            UIX.Show(lastResult, false);
            logScroll.contentContainer.Clear();
            foreach (var e in E.Session.Log) AddLog(e);
            if (E.Monitor != null && E.Monitor.Texture != null) scopeImage.style.backgroundImage = new StyleBackground(E.Monitor.Texture);
            else scopeImage.style.backgroundImage = StyleKeyword.None;
            Show();
            Refresh();
        }

        public void AddLog(TimedEntry e)
        {
            var line = UIX.Div(logScroll.contentContainer, "dialog-line", "row");
            line.style.alignItems = Align.FlexStart;
            var t = UIX.Text(line, FormatMinute(e.Minute), "mono", "t-small", "t-muted");
            t.style.width = 64;
            t.style.flexShrink = 0;
            string cls;
            switch (e.Kind)
            {
                case "danger": cls = "t-danger"; break;
                case "result": cls = "t-success"; break;
                case "dialog": cls = "t-accent"; break;
                case "event": cls = "w600"; break;
                case "question": cls = "t-dim"; break;
                default: cls = ""; break;
            }
            var txt = UIX.Text(line, e.Text, "t-small", cls);
            txt.style.flexShrink = 1;
            while (logScroll.contentContainer.childCount > 80) logScroll.contentContainer.RemoveAt(0);
            logScroll.schedule.Execute(() => logScroll.scrollOffset = new Vector2(0f, logScroll.contentContainer.layout.height)).StartingIn(30);
        }

        static string FormatMinute(float m)
        {
            int total = Mathf.FloorToInt(Mathf.Max(0f, m) * 60f);
            return (total / 60).ToString("00") + ":" + (total % 60).ToString("00");
        }

        /// <summary>Appelé à chaque image : scope, chronomètre, constantes (4 fois par seconde).</summary>
        public void Tick()
        {
            if (!Visible || E.Session == null) return;
            var se = E.Session;
            elapsed.text = FormatMinute(se.Minutes);
            clock.text = GameClock.Format(game.Clock.Minutes);
            busyChip.EnableInClassList("hidden", !E.Busy);
            contentBlocker.EnableInClassList("hidden", !E.Busy);
            contentBlocker.pickingMode = E.Busy ? PickingMode.Position : PickingMode.Ignore;

            bool on = se.ScopeOn;
            UIX.Show(scopeOff, !on);
            scopeImage.EnableInClassList("hidden", !on);
            // La texture du scope est redessinée en place : il faut redemander le rendu du panneau.
            if (on) scopeImage.MarkDirtyRepaint();

            slowTimer -= Time.unscaledDeltaTime;
            if (slowTimer > 0f) return;
            slowTimer = 0.25f;
            scopeLabel.text = on ? se.S.RhythmName : "";
            BuildVitals();
            BuildMeasures();
            BuildPending();
        }

        public void ShowResult(string text)
        {
            lastResult.text = text;
            UIX.Show(lastResult, !string.IsNullOrEmpty(text));
        }

        // ================================================================== colonne gauche

        void BuildVitals()
        {
            vitals.Clear();
            var se = E.Session;
            var s = se.S;
            bool scope = se.ScopeOn;
            bool flat = !s.Pulse;
            Vital("FC", scope ? (flat ? "0" : Mathf.RoundToInt(s.Hr).ToString()) : "—", scope ? Sev(flat || s.Hr > 130f || s.Hr < 45f, s.Hr > 105f || s.Hr < 55f) : (Severity?)null);
            Vital("PA", scope ? (flat ? "--/--" : Mathf.RoundToInt(s.Sys) + "/" + Mathf.RoundToInt(s.Dia)) : "—", scope ? Sev(flat || s.Sys < 80f, s.Sys < 95f || s.Sys > 170f) : (Severity?)null);
            Vital("SpO2", scope ? (flat || s.Spo2 < 40f ? "--" : Mathf.RoundToInt(s.Spo2) + " %") : "—", scope ? Sev(flat || s.Spo2 < 88f, s.Spo2 < 94f) : (Severity?)null);
            bool rrKnown = scope || se.Done("ventilation");
            Vital("FR", rrKnown ? Mathf.RoundToInt(s.Rr) + "/min" : "—", rrKnown ? Sev(s.Rr < 8f || s.Rr > 30f, s.Rr < 12f || s.Rr > 22f) : (Severity?)null);
            bool gcs = se.Done("conscience");
            Vital("Glasgow", gcs ? s.Gcs.ToString() : "—", gcs ? Sev(s.Gcs <= 8, s.Gcs < 15) : (Severity?)null);
            bool gly = se.Done("glycemie");
            Vital("Glycémie", gly ? Vitals.F2(s.Glyc) : "—", gly ? Sev(s.Glyc < 0.6f, s.Glyc < 0.8f || s.Glyc > 2f) : (Severity?)null);
        }

        static Severity? Sev(bool critical, bool attention) => critical ? Severity.Critique : attention ? Severity.Attention : Severity.Normal;

        void Vital(string label, string value, Severity? sev)
        {
            var c = UIX.Div(vitals, "vital");
            if (sev == Severity.Attention) c.AddToClassList("attention");
            if (sev == Severity.Critique) c.AddToClassList("critique");
            UIX.Text(c, label, "t-tiny");
            UIX.Text(c, value, "mono-b", "t-h3", sev == Severity.Critique ? "t-danger" : sev == Severity.Attention ? "t-warning" : "");
        }

        void BuildMeasures()
        {
            measures.Clear();
            var se = E.Session;
            int n = 0;
            void Chip(bool on, string text, string kind)
            {
                if (!on) return;
                var l = UIX.Chip(measures, text, kind);
                l.style.marginRight = 6;
                l.style.marginBottom = 6;
                n++;
            }
            Chip(!se.S.Alive, "Décédé", "solid-bad");
            Chip(se.Cpr, "Massage en cours", "solid-bad");
            Chip(se.ScopeOn, "Scope", "ok");
            Chip(se.Bavu, "Ventilation au ballon", "accent");
            Chip(se.O2 && !se.Bavu, "Oxygène", "info");
            Chip(se.Iv, "Voie veineuse", "info");
            Chip(se.Pls, "PLS", "info");
            Chip(se.Immobilized, "Immobilisé", "info");
            Chip(se.Shocks > 0, se.Shocks + (se.Shocks > 1 ? " chocs" : " choc"), "warn");
            Chip(se.Adrenaline > 0, "Adrénaline × " + se.Adrenaline, "warn");
            Chip(se.Amiodarone, "Amiodarone", "warn");
            if (n == 0) UIX.Text(measures, "Aucun geste en cours.", "t-small");
        }

        void BuildPending()
        {
            pending.Clear();
            var se = E.Session;
            if (se.Pending.Count == 0) return;
            UIX.Text(pending, "RÉSULTATS ATTENDUS", "t-caption", "w600");
            UIX.Spacer(pending, 6);
            foreach (var p in se.Pending)
            {
                var row = UIX.Div(pending, "row");
                row.style.marginBottom = 4;
                var name = UIX.Text(row, EmergencyCatalog.ActionName(p.Id), "t-small");
                name.style.flexGrow = 1;
                name.style.flexShrink = 1;
                UIX.Text(row, "≈ " + Mathf.Max(1, Mathf.CeilToInt(p.ReadyAt - se.Minutes)) + " min", "mono", "t-small", "t-warning");
            }
        }

        // ================================================================== onglets

        public void Refresh()
        {
            if (!Visible || E.Session == null) return;
            foreach (var kv in tabs) kv.Value.EnableInClassList("on", kv.Key == tab);
            content.Clear();
            footer.Clear();
            switch (tab)
            {
                case "interrogatoire": BuildQuestions(); break;
                case "diagnostic": BuildDiagnosis(); break;
                case "orientation": BuildDestinations(); break;
                default: BuildTools(); break;
            }
            BuildFooter();
            ShowResult(E.LastResult);
            slowTimer = 0f;
        }

        void BuildTools()
        {
            var se = E.Session;
            var setting = E.Case.Setting;
            var head = UIX.Div(content, "row");
            UIX.Text(head, "MATÉRIEL", "t-caption", "w600");
            UIX.Div(head, "spacer");
            UIX.Btn(head, "Ouvrir la roue", () => { wheelByClick = true; game.OpenToolWheel(); }, "small");
            UIX.Spacer(content, 8);
            var grid = UIX.Div(content, "row");
            grid.style.flexWrap = Wrap.Wrap;
            foreach (EmergencyTool t in System.Enum.GetValues(typeof(EmergencyTool)))
            {
                var tool = t;
                bool available = EmergencyCatalog.ToolAvailable(tool, setting);
                var cell = UIX.Plain(grid, "", () => E.SelectTool(tool), "list-btn");
                cell.style.width = 122; cell.style.height = 86; cell.style.marginRight = 8;
                cell.style.alignItems = Align.Center; cell.style.justifyContent = Justify.Center;
                cell.style.paddingTop = 6; cell.style.paddingBottom = 6;
                var icon = UIX.Div(cell, "wheel-icon");
                icon.style.width = 40; icon.style.height = 40;
                icon.style.backgroundImage = new StyleBackground(ToolIcons.Get(tool));
                icon.pickingMode = PickingMode.Ignore;
                var l = UIX.Text(cell, EmergencyCatalog.ToolName(tool), "t-tiny", "t-center");
                l.style.whiteSpace = WhiteSpace.Normal;
                if (E.Tool == tool) cell.AddToClassList("selected");
                cell.SetEnabled(available);
            }
            UIX.Spacer(content, 10);

            if (!E.Tool.HasValue)
            {
                UIX.Text(content, "Choisissez du matériel (clic droit maintenu ou grille ci-dessus). Commencez par le bilan : conscience, respiration, pouls.", "t-small");
                return;
            }
            UIX.Text(content, EmergencyCatalog.ToolName(E.Tool.Value).ToUpperInvariant(), "t-caption", "w600");
            UIX.Spacer(content, 6);
            foreach (var a in EmergencyCatalog.ForTool(E.Tool.Value, setting))
            {
                string id = a.Id;
                var row = UIX.Plain(content, "", () => E.Do(id), "list-btn");
                row.style.flexDirection = FlexDirection.Row;
                row.style.alignItems = Align.Center;
                var col = UIX.Div(row, "col", "grow");
                col.style.flexShrink = 1;
                UIX.Text(col, a.Name, "w600");
                var d = UIX.Text(col, a.Detail, "t-tiny");
                d.style.whiteSpace = WhiteSpace.Normal;
                UIX.HSpace(row, 8);
                if (id == "rcp" && se.Cpr) { UIX.Chip(row, "EN COURS", "solid-bad"); UIX.HSpace(row, 6); }
                else if (a.NeedsIv && !se.Iv) { UIX.Chip(row, "Voie veineuse", "warn"); UIX.HSpace(row, 6); }
                bool waiting = false;
                foreach (var p in se.Pending) if (p.Id == id) waiting = true;
                if (waiting) { UIX.Chip(row, "En attente", "info"); UIX.HSpace(row, 6); }
                else if (se.Results.ContainsKey(id)) { UIX.Chip(row, "Résultat", "ok"); UIX.HSpace(row, 6); }
                UIX.Text(row, a.ResultDelay > 0f ? Mathf.RoundToInt(a.ResultDelay) + " min" : FormatDuration(a.Minutes), "mono", "t-small");
                UIX.IgnorePicking(col);
                if (se.Done(id) && id != "rcp") row.AddToClassList("done");
            }
        }

        static string FormatDuration(float minutes)
        {
            if (minutes < 1f) return Mathf.Max(5, Mathf.RoundToInt(minutes * 60f / 5f) * 5) + " s";
            return Mathf.RoundToInt(minutes) + " min";
        }

        void BuildQuestions()
        {
            var se = E.Session;
            var c = E.Case;
            if (E.HasWitness) UIX.Text(content, "Le témoin (" + c.Witness + ") répond à vos questions.", "t-small");
            else UIX.Text(content, "Le patient répond lui-même, s'il est conscient.", "t-small");
            UIX.Spacer(content, 10);
            foreach (var q in EmergencySession.Questions)
            {
                string id = q[0];
                var b = UIX.Plain(content, q[1], () => E.Ask(id), "list-btn");
                if (se.Asked.Contains(id)) b.AddToClassList("done");
            }
        }

        void BuildDiagnosis()
        {
            var se = E.Session;
            UIX.Text(content, "Quelle est votre hypothèse diagnostique principale ?", "t-small");
            UIX.Spacer(content, 8);
            foreach (var d in EmergencyCases.Diagnoses)
            {
                string id = d.Id;
                var b = UIX.Plain(content, d.Name, () => E.SetDiagnosis(id), "list-btn");
                if (se.Diagnosis == id) b.AddToClassList("selected");
            }
        }

        void BuildDestinations()
        {
            var se = E.Session;
            bool samu = E.Case.Setting == EmergencySetting.Samu;
            UIX.Text(content, samu ? "Où le patient doit-il être transporté ?" : "Où le patient doit-il être orienté ?", "t-small");
            UIX.Spacer(content, 8);
            foreach (var d in EmergencyCatalog.Destinations)
            {
                if (samu ? !d.Samu : !d.Urgences) continue;
                string id = d.Id;
                var row = UIX.Plain(content, "", () => E.SetDestination(id), "list-btn");
                var col = UIX.Div(row, "col");
                UIX.Text(col, d.Name, "w600");
                UIX.Text(col, d.Detail, "t-tiny");
                UIX.IgnorePicking(col);
                if (se.Destination == id) row.AddToClassList("selected");
            }
        }

        void BuildFooter()
        {
            var se = E.Session;
            UIX.Spacer(footer, 10);
            var summary = UIX.Text(footer,
                "Diagnostic : " + (string.IsNullOrEmpty(se.Diagnosis) ? "—" : EmergencyCases.DiagnosisName(se.Diagnosis)) +
                "   ·   Orientation : " + (string.IsNullOrEmpty(se.Destination) ? "—" : EmergencyCatalog.DestinationName(se.Destination)), "t-small");
            summary.style.whiteSpace = WhiteSpace.Normal;
            UIX.Spacer(footer, 8);
            string label;
            if (!se.S.Alive) label = "Le patient est décédé : terminer l'intervention";
            else if (string.IsNullOrEmpty(se.Diagnosis) || string.IsNullOrEmpty(se.Destination)) label = "Choisissez un diagnostic et une orientation";
            else label = se.Setting == EmergencySetting.Samu ? "Terminer : transport du patient" : "Terminer : orienter le patient";
            var b = UIX.Btn(footer, label, () => E.Conclude(), se.S.Alive ? "primary" : "danger", "big");
            b.SetEnabled(E.CanConclude);
        }

        // ================================================================== roue

        public void OnToolPicked()
        {
            if (wheelByClick) { wheelByClick = false; game.CloseToolWheel(false); }
            tab = "gestes";
            Refresh();
        }

        public override void Hide()
        {
            wheelByClick = false;
            base.Hide();
        }
    }
}
