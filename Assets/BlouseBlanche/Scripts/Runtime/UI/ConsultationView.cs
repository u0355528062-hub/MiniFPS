using System.Collections.Generic;
using BlouseBlanche.Characters;
using BlouseBlanche.Core;
using BlouseBlanche.Gameplay;
using BlouseBlanche.Medical;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    /// <summary>Journal des échanges (patient / médecin), réutilisable.</summary>
    public sealed class DialogLog
    {
        readonly ScrollView scroll;
        public VisualElement Root { get; }

        public DialogLog(VisualElement parent, string caption)
        {
            Root = UIX.Div(parent, "panel-2");
            UIX.Text(Root, caption, "t-caption", "w600");
            UIX.Spacer(Root, 6);
            scroll = new ScrollView(ScrollViewMode.Vertical);
            Root.Add(scroll);
        }

        public void Clear() => scroll.contentContainer.Clear();

        public void Add(string speaker, string text, bool doctor)
        {
            var line = UIX.Div(scroll.contentContainer, "dialog-line", "row");
            line.style.alignItems = Align.FlexStart;
            var who = UIX.Text(line, speaker, "w700", doctor ? "t-dim" : "t-accent");
            who.style.width = 130;
            who.style.flexShrink = 0;
            var t = UIX.Text(line, text, doctor ? "t-small" : "");
            t.style.flexShrink = 1;
            while (scroll.contentContainer.childCount > 40) scroll.contentContainer.RemoveAt(0);
            scroll.schedule.Execute(() => scroll.scrollOffset = new Vector2(0f, scroll.contentContainer.layout.height)).StartingIn(30);
        }
    }

    /// <summary>Écran de consultation de médecine générale.</summary>
    public sealed class ConsultationView : View
    {
        readonly GameRoot game;
        readonly Label patientName, patientInfo, initials, elapsed, clock, stationInfo, busyChip;
        readonly VisualElement chips, dossier, vitals, tabsRow, content, footer, contentBlocker;
        readonly ScrollView contentScroll;
        readonly DialogLog log;
        readonly Dictionary<string, Button> tabs = new Dictionary<string, Button>();
        string tab = "interrogatoire";
        bool wheelByClick;

        ConsultationController C => game.Consult;

        public ConsultationView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            this.game = game;
            var s = MakeScreen(parent);
            s.pickingMode = PickingMode.Ignore;

            // ------------------------------------------------------------ barre supérieure
            var top = UIX.Div(s, "row", "panel-2");
            top.style.position = Position.Absolute;
            top.style.left = 24; top.style.right = 24; top.style.top = 20;
            var av = UIX.Div(top, "avatar");
            initials = UIX.Text(av, "", "w800", "t-h3", "t-accent");
            UIX.HSpace(top, 14);
            var ncol = UIX.Div(top, "col");
            patientName = UIX.Text(ncol, "", "w800", "t-h2");
            patientInfo = UIX.Text(ncol, "", "t-small");
            UIX.HSpace(top, 16);
            chips = UIX.Div(top, "row");
            UIX.Div(top, "spacer");
            busyChip = UIX.Chip(top, "Examen en cours…", "accent");
            UIX.HSpace(top, 16);
            var tcol = UIX.Div(top, "col");
            UIX.Text(tcol, "DURÉE", "t-caption", "w600");
            elapsed = UIX.Text(tcol, "0 min", "mono-b", "t-h3");
            UIX.HSpace(top, 20);
            var ccol = UIX.Div(top, "col");
            UIX.Text(ccol, "HEURE", "t-caption", "w600");
            clock = UIX.Text(ccol, "", "mono-b", "t-h3");
            UIX.HSpace(top, 24);
            UIX.Btn(top, "APPELER LE 15", () => ui.Confirm("Appel du SAMU", "Appeler le 15 met fin à la consultation : le SAMU prend le patient en charge. Confirmer l'urgence vitale ?", "Appeler le 15", () => C.CallSamu()), "danger");

            // ------------------------------------------------------------ colonne gauche : dossier + constantes
            var left = UIX.Div(s, "panel");
            left.style.position = Position.Absolute;
            left.style.left = 24; left.style.top = 116; left.style.bottom = 24; left.style.width = 400;
            left.style.paddingTop = 18; left.style.paddingBottom = 18;
            var lscroll = new ScrollView(ScrollViewMode.Vertical);
            left.Add(lscroll);
            UIX.Text(lscroll.contentContainer, "CONSTANTES", "t-caption", "w600");
            UIX.Spacer(lscroll.contentContainer, 8);
            vitals = UIX.Div(lscroll.contentContainer, "row");
            vitals.style.flexWrap = Wrap.Wrap;
            UIX.Spacer(lscroll.contentContainer, 10);
            UIX.Text(lscroll.contentContainer, "DOSSIER MÉDICAL", "t-caption", "w600");
            UIX.Spacer(lscroll.contentContainer, 8);
            dossier = UIX.Div(lscroll.contentContainer, "col");

            // ------------------------------------------------------------ colonne droite : onglets
            var right = UIX.Div(s, "panel");
            right.style.position = Position.Absolute;
            right.style.right = 24; right.style.top = 116; right.style.bottom = 24; right.style.width = 560;
            right.style.paddingTop = 12;
            tabsRow = UIX.Div(right, "tabs");
            Tab("interrogatoire", "Interrogatoire");
            Tab("examen", "Examen");
            Tab("diagnostic", "Diagnostic");
            Tab("prescription", "Prescription");
            stationInfo = UIX.Text(right, "", "t-small");
            UIX.Spacer(right, 8);
            var holder = UIX.Div(right, "grow");
            contentScroll = new ScrollView(ScrollViewMode.Vertical);
            holder.Add(contentScroll);
            content = contentScroll.contentContainer;
            contentBlocker = UIX.Div(holder, "layer");
            contentBlocker.style.backgroundColor = new Color(0.05f, 0.08f, 0.13f, 0.45f);
            footer = UIX.Div(right, "col");

            // ------------------------------------------------------------ échanges
            log = new DialogLog(s, "ÉCHANGES");
            log.Root.style.position = Position.Absolute;
            log.Root.style.left = 444; log.Root.style.right = 604; log.Root.style.bottom = 24; log.Root.style.height = 210;
            log.Root.style.backgroundColor = new Color(0.04f, 0.07f, 0.12f, 0.82f);

            var hint = UIX.Text(s, "Clic droit maintenu : roue des outils  ·  1 à = : raccourcis  ·  Échap : pause", "t-tiny");
            hint.style.position = Position.Absolute;
            hint.style.left = 444; hint.style.bottom = 244;
        }

        void Tab(string id, string label)
        {
            var b = UIX.Plain(tabsRow, label, () => { tab = id; Refresh(); }, "tab");
            tabs[id] = b;
        }

        // ================================================================== cycle

        public void Begin()
        {
            log.Clear();
            tab = "interrogatoire";
            var p = C.Session.Patient;
            initials.text = (p.FirstName.Substring(0, 1) + p.LastName.Substring(0, 1)).ToUpperInvariant();
            patientName.text = p.FullName;
            patientInfo.text = (p.Sex == Sex.Homme ? "Homme" : "Femme") + " · " + p.AgeLabel + (string.IsNullOrEmpty(p.Case.Companion) ? "" : " · accompagné(e) de " + p.Case.Companion);
            chips.Clear();
            UIX.Chip(chips, p.Case.Motif, "info");
            if (C.Visit.Plan.WalkIn) { UIX.HSpace(chips, 6); UIX.Chip(chips, "Sans rendez-vous", "warn"); }
            if (C.Visit.IsUrgent) { UIX.HSpace(chips, 6); UIX.Chip(chips, "URGENCE", "solid-bad"); }
            if (C.Session.HandsWashed) { UIX.HSpace(chips, 6); UIX.Chip(chips, "Mains lavées", "ok"); }
            BuildDossier(p);
            Show();
            Refresh();
        }

        public void OnSpoke(string speaker, string text) => log.Add(speaker, text, speaker == "Vous");

        public void OnExam(string examId, Finding f)
        {
            log.Add("Examen", MedicalCatalog.ExamName(examId) + " : " + f.Text, true);
        }

        void BuildDossier(PatientRecord p)
        {
            dossier.Clear();
            Field("Antécédents", p.History != null && p.History.Length > 0 ? string.Join("\n", p.History) : "Aucun antécédent notable", null);
            Field("Traitements", p.Meds != null && p.Meds.Length > 0 ? string.Join("\n", p.Meds) : "Aucun", null);
            bool allergic = p.Allergies != null && p.Allergies.Length > 0;
            Field("Allergies", allergic ? string.Join("\n", p.Allergies) : "Aucune allergie connue", allergic ? "t-danger" : null);
            if (!string.IsNullOrEmpty(p.Notes)) Field("Documents apportés", p.Notes, null);
        }

        void Field(string label, string value, string cls)
        {
            var c = UIX.Div(dossier, "card");
            c.style.marginBottom = 8;
            UIX.Text(c, label, "w600", "t-small");
            UIX.Spacer(c, 3);
            UIX.Text(c, value, cls ?? "");
        }

        public void Tick()
        {
            if (!Visible || !C.Active) return;
            elapsed.text = Mathf.RoundToInt(C.Session.Minutes) + " min";
            clock.text = GameClock.Format(game.Clock.Minutes);
            busyChip.EnableInClassList("hidden", !C.Busy);
            contentBlocker.EnableInClassList("hidden", !C.Busy);
            contentBlocker.pickingMode = C.Busy ? PickingMode.Position : PickingMode.Ignore;
        }

        public void Refresh()
        {
            if (!C.Active) return;
            foreach (var kv in tabs) kv.Value.EnableInClassList("on", kv.Key == tab);
            string tool = C.Tool.HasValue ? MedicalTools.Name(C.Tool.Value) : "aucun";
            stationInfo.text = "Patient : " + (C.Station == PatientStation.Chair ? "assis au bureau" : "installé sur le divan") + "  ·  Outil en main : " + tool;
            BuildVitals();
            content.Clear();
            footer.Clear();
            switch (tab)
            {
                case "interrogatoire": BuildQuestions(); break;
                case "examen": BuildExams(); break;
                case "diagnostic": BuildDiagnosis(); break;
                default: BuildPrescription(); break;
            }
            BuildFooter();
        }

        // ================================================================== constantes

        void BuildVitals()
        {
            vitals.Clear();
            var s = C.Session;
            var v = s.Patient.Vitals;
            Finding Get(string id)
            {
                foreach (var kv in s.ExamResults) if (kv.Key == id) return kv.Value;
                return null;
            }
            var ta = Get("ex_ta");
            var temp = Get("ex_temp");
            var sp = Get("ex_spo2");
            var gl = Get("ex_glyc");
            var po = Get("ex_poids");
            Vital("Température", temp != null ? Vitals.F1(v.Temp) + "°" : "—", temp?.Severity);
            Vital("Tension", ta != null ? v.Sys + "/" + v.Dia : "—", ta?.Severity);
            Vital("Pouls", ta != null || sp != null ? v.Hr + "/min" : "—", ta != null && (v.Hr > (s.Patient.IsChild ? 130 : 100) || v.Irregular) ? Severity.Attention : (Severity?)null);
            Vital("SpO2", sp != null ? v.Spo2 + " %" : "—", sp?.Severity);
            Vital("Glycémie", gl != null ? Vitals.F2(v.Glyc) : "—", gl?.Severity);
            Vital(s.Patient.IsChild ? "Poids" : "IMC", po != null ? (s.Patient.IsChild ? Vitals.F1(v.Weight) + " kg" : Vitals.F1(v.Bmi)) : "—", po?.Severity);
        }

        void Vital(string label, string value, Severity? sev)
        {
            var c = UIX.Div(vitals, "vital");
            if (sev == Severity.Attention) c.AddToClassList("attention");
            if (sev == Severity.Critique) c.AddToClassList("critique");
            UIX.Text(c, label, "t-tiny");
            UIX.Text(c, value, "mono-b", "t-h3", sev == Severity.Critique ? "t-danger" : sev == Severity.Attention ? "t-warning" : "");
        }

        // ================================================================== onglets

        void BuildQuestions()
        {
            var s = C.Session;
            string cat = null;
            foreach (var q in MedicalCatalog.Questions)
            {
                if (q.WomenOnly && !(s.Patient.Sex == Sex.Femme && s.Patient.Age >= 14 && s.Patient.Age <= 52)) continue;
                if (q.Category != cat)
                {
                    cat = q.Category;
                    UIX.Spacer(content, cat == "Motif" ? 0 : 8);
                    UIX.Text(content, cat.ToUpperInvariant(), "t-caption", "w600");
                    UIX.Spacer(content, 6);
                }
                string id = q.Id;
                bool asked = s.HasAsked(id);
                var b = UIX.Plain(content, q.Text, () => C.Ask(id), "list-btn");
                if (asked) b.AddToClassList("done");
            }
        }

        void BuildExams()
        {
            var s = C.Session;
            // Position du patient
            var st = UIX.Div(content, "segmented");
            var a = UIX.Plain(st, "Patient au bureau", () => C.MoveTo(PatientStation.Chair), "segment");
            var b = UIX.Plain(st, "Installer sur le divan", () => C.MoveTo(PatientStation.Table), "segment");
            a.EnableInClassList("on", C.Station == PatientStation.Chair);
            b.EnableInClassList("on", C.Station == PatientStation.Table);
            UIX.Spacer(content, 14);

            // Grille d'outils (clic) — la roue reste le moyen rapide
            var head = UIX.Div(content, "row");
            UIX.Text(head, "OUTILS", "t-caption", "w600");
            UIX.Div(head, "spacer");
            UIX.Btn(head, "Ouvrir la roue", () => { wheelByClick = true; game.OpenToolWheel(); }, "small");
            UIX.Spacer(content, 8);
            var grid = UIX.Div(content, "row");
            grid.style.flexWrap = Wrap.Wrap;
            for (int i = 0; i < MedicalTools.Count; i++)
            {
                var tool = (MedicalTool)i;
                var cell = UIX.Plain(grid, "", () => C.SelectTool(tool), "list-btn");
                cell.style.width = 122; cell.style.height = 86; cell.style.marginRight = 8;
                cell.style.alignItems = Align.Center; cell.style.justifyContent = Justify.Center;
                cell.style.paddingTop = 6; cell.style.paddingBottom = 6;
                var icon = UIX.Div(cell, "wheel-icon");
                icon.style.width = 40; icon.style.height = 40;
                icon.style.backgroundImage = new StyleBackground(ToolIcons.Get(tool));
                icon.pickingMode = PickingMode.Ignore;
                var l = UIX.Text(cell, MedicalTools.Name(tool), "t-tiny", "t-center");
                l.style.whiteSpace = WhiteSpace.Normal;
                if (C.Tool == tool) cell.AddToClassList("selected");
            }
            UIX.Spacer(content, 10);

            if (C.Tool.HasValue)
            {
                UIX.Text(content, ("EXAMENS · " + MedicalTools.Name(C.Tool.Value)).ToUpperInvariant(), "t-caption", "w600");
                UIX.Spacer(content, 6);
                foreach (var e in MedicalCatalog.ExamsForTool(C.Tool.Value))
                {
                    string id = e.Id;
                    var row = UIX.Plain(content, "", () => C.Examine(id), "list-btn");
                    row.style.flexDirection = FlexDirection.Row;
                    row.style.alignItems = Align.Center;
                    var name = UIX.Text(row, e.Name, "w500");
                    name.style.flexGrow = 1;
                    if (e.NeedsTable) { UIX.Chip(row, "Divan", "info"); UIX.HSpace(row, 6); }
                    UIX.Text(row, e.Minutes + " min", "mono", "t-small");
                    if (s.HasExam(id)) row.AddToClassList("done");
                }
            }
            else UIX.Text(content, "Choisissez un outil (clic droit maintenu ou grille ci-dessus).", "t-small");

            if (s.ExamResults.Count > 0)
            {
                UIX.Spacer(content, 12);
                UIX.Text(content, "RÉSULTATS", "t-caption", "w600");
                UIX.Spacer(content, 6);
                for (int i = s.ExamResults.Count - 1; i >= 0; i--)
                {
                    var kv = s.ExamResults[i];
                    var f = UIX.Div(content, "finding", kv.Value.Severity == Severity.Critique ? "critique" : kv.Value.Severity == Severity.Attention ? "attention" : "");
                    UIX.Text(f, MedicalCatalog.ExamName(kv.Key), "w600", "t-small");
                    UIX.Text(f, kv.Value.Text);
                }
            }
        }

        void BuildDiagnosis()
        {
            var s = C.Session;
            UIX.Text(content, "Quel est votre diagnostic principal ?", "t-small");
            UIX.Spacer(content, 8);
            string cat = null;
            foreach (var d in MedicalCatalog.Diagnoses)
            {
                if (d.Category != cat)
                {
                    cat = d.Category;
                    UIX.Spacer(content, 6);
                    UIX.Text(content, cat.ToUpperInvariant(), "t-caption", "w600");
                    UIX.Spacer(content, 6);
                }
                string id = d.Id;
                var b = UIX.Plain(content, d.Name, () => { C.SetDiagnosis(id); Refresh(); }, "list-btn");
                if (s.Diagnosis == id) b.AddToClassList("selected");
            }
        }

        void BuildPrescription()
        {
            var s = C.Session;
            string cat = null;
            foreach (var t in MedicalCatalog.Treatments)
            {
                if (t.Category != cat)
                {
                    cat = t.Category;
                    UIX.Spacer(content, cat == "Médicaments" ? 0 : 8);
                    UIX.Text(content, cat.ToUpperInvariant(), "t-caption", "w600");
                    UIX.Spacer(content, 6);
                }
                string id = t.Id;
                var row = UIX.Plain(content, "", () => { C.ToggleTreatment(id); Refresh(); }, "list-btn");
                row.style.flexDirection = FlexDirection.Row;
                row.style.alignItems = Align.Center;
                var col = UIX.Div(row, "col", "grow");
                UIX.Text(col, t.Name, "w600");
                UIX.Text(col, t.Detail, "t-tiny");
                if (s.Treatments.Contains(id)) { row.AddToClassList("selected"); UIX.Chip(row, "Prescrit", "accent"); }
            }
            UIX.Spacer(content, 12);
            UIX.Text(content, "ORIENTATION", "t-caption", "w600");
            UIX.Spacer(content, 6);
            foreach (Orientation o in System.Enum.GetValues(typeof(Orientation)))
            {
                var ori = o;
                var row = UIX.Plain(content, "", () => { C.SetOrientation(ori); Refresh(); }, "list-btn");
                var col = UIX.Div(row, "col");
                UIX.Text(col, OrientationInfo.Name(o), "w600", o == Orientation.Urgences15 ? "t-danger" : "");
                UIX.Text(col, OrientationInfo.Detail(o), "t-tiny");
                if (s.Orientation == o) row.AddToClassList("selected");
            }
        }

        void BuildFooter()
        {
            var s = C.Session;
            UIX.Spacer(footer, 10);
            var summary = UIX.Text(footer,
                "Diagnostic : " + (string.IsNullOrEmpty(s.Diagnosis) ? "—" : MedicalCatalog.DiagnosisName(s.Diagnosis)) +
                "   ·   Prescriptions : " + s.Treatments.Count +
                "   ·   Orientation : " + (s.Orientation.HasValue ? OrientationInfo.Name(s.Orientation.Value) : "—"), "t-small");
            summary.style.whiteSpace = WhiteSpace.Normal;
            UIX.Spacer(footer, 8);
            bool ready = !string.IsNullOrEmpty(s.Diagnosis) && s.Orientation.HasValue;
            var b = UIX.Btn(footer, ready ? "Terminer la consultation" : "Choisissez un diagnostic et une orientation", () => C.Conclude(), "primary", "big");
            b.SetEnabled(ready && !C.Busy);
        }

        // ================================================================== roue

        public void OnToolPicked()
        {
            if (wheelByClick) { wheelByClick = false; game.CloseToolWheel(false); }
            if (tab != "examen") tab = "examen";
            Refresh();
        }
    }
}
