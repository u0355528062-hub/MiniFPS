using System;
using BlouseBlanche.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    public enum ToastKind { Info, Warning, Urgent, Success }

    /// <summary>
    /// Racine de l'interface : document UI Toolkit, calques, notifications, sous-titres, fondus,
    /// et toutes les vues du jeu.
    /// </summary>
    public sealed class UIRoot : MonoBehaviour
    {
        public const string ResourceFolder = "BlouseBlanche/UI/";

        UIDocument doc;
        public VisualElement Root { get; private set; }
        public VisualElement LayerHud { get; private set; }
        public VisualElement LayerScreens { get; private set; }
        public VisualElement LayerModal { get; private set; }
        VisualElement layerToasts, layerSubtitle, layerFade;
        VisualElement toastStack;
        VisualElement subtitle;
        Label subtitleSpeaker, subtitleText;
        IVisualElementScheduledItem subtitleHide;

        public HudView Hud { get; private set; }
        public MainMenuView Menu { get; private set; }
        public SettingsView Settings { get; private set; }
        public PauseView Pause { get; private set; }
        public ConsultationView Consult { get; private set; }
        public EmergencyView Emergency { get; private set; }
        public ToolWheelView Wheel { get; private set; }
        public ResultView Result { get; private set; }
#if BB_STORY_MODE
        public DayIntroView DayIntro { get; private set; }
        public AgendaView Agenda { get; private set; }
        public DaySummaryView Summary { get; private set; }
#endif

        VisualElement loading;
        VisualElement loadingFill;
        Label loadingStep;

        public bool Ready { get; private set; }

        public void Build(GameRoot game)
        {
            var go = new GameObject("UIDocument");
            go.SetActive(false);
            go.transform.SetParent(transform, false);
            doc = go.AddComponent<UIDocument>();
            doc.panelSettings = LoadPanelSettings();
            go.SetActive(true);

            var ve = doc.rootVisualElement;
            var sheet = Resources.Load<StyleSheet>(ResourceFolder + "Main");
            if (sheet != null) ve.styleSheets.Add(sheet);
            else Debug.LogError("[BlouseBlanche] Feuille de style introuvable : Resources/" + ResourceFolder + "Main.uss");

            Root = UIX.Div(ve, "bb-root");
            Root.pickingMode = PickingMode.Ignore;
            LayerHud = UIX.Div(Root, "layer");
            LayerHud.pickingMode = PickingMode.Ignore;
            LayerScreens = UIX.Div(Root, "layer");
            LayerScreens.pickingMode = PickingMode.Ignore;
            LayerModal = UIX.Div(Root, "layer");
            LayerModal.pickingMode = PickingMode.Ignore;
            layerSubtitle = UIX.Div(Root, "layer");
            layerSubtitle.pickingMode = PickingMode.Ignore;
            layerToasts = UIX.Div(Root, "layer");
            layerToasts.pickingMode = PickingMode.Ignore;
            layerFade = UIX.Div(Root, "layer", "fade");
            layerFade.pickingMode = PickingMode.Ignore;

            toastStack = UIX.Div(layerToasts, "toasts");
            toastStack.pickingMode = PickingMode.Ignore;

            subtitle = UIX.Div(layerSubtitle, "subtitle");
            var sbox = UIX.Div(subtitle, "subtitle-box");
            var srow = UIX.Div(sbox, "row");
            subtitleSpeaker = UIX.Text(srow, "", "w700", "t-accent");
            UIX.HSpace(srow, 10);
            subtitleText = UIX.Text(srow, "", "t-h3");
            subtitleText.style.flexShrink = 1;
            UIX.IgnorePicking(subtitle);

            BuildLoading();

            Hud = new HudView(this, LayerHud);
            Menu = new MainMenuView(this, LayerScreens, game);
#if BB_STORY_MODE
            DayIntro = new DayIntroView(this, LayerScreens, game);
            Agenda = new AgendaView(this, LayerScreens, game);
            Summary = new DaySummaryView(this, LayerScreens, game);
#endif
            Consult = new ConsultationView(this, LayerScreens, game);
            Emergency = new EmergencyView(this, LayerScreens, game);
            Wheel = new ToolWheelView(this, LayerScreens, game);
            Result = new ResultView(this, LayerScreens, game);
            Pause = new PauseView(this, LayerModal, game);
            Settings = new SettingsView(this, LayerModal, game);
            Ready = true;
        }

        PanelSettings LoadPanelSettings()
        {
            var ps = Resources.Load<PanelSettings>(ResourceFolder + "PanelSettings");
            if (ps == null)
            {
                ps = ScriptableObject.CreateInstance<PanelSettings>();
                ps.themeStyleSheet = Resources.Load<ThemeStyleSheet>(ResourceFolder + "BlouseBlancheTheme");
                Debug.LogWarning("[BlouseBlanche] PanelSettings créé à l'exécution (lancez « Blouse Blanche > Configurer le projet » avant un build).");
            }
            else ps = Instantiate(ps);
            ps.scaleMode = PanelScaleMode.ScaleWithScreenSize;
            ps.referenceResolution = new Vector2Int(1920, 1080);
            ps.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight;
            ps.match = 0.5f;
            ps.sortingOrder = 10;
            return ps;
        }

        // ================================================================== chargement

        void BuildLoading()
        {
            loading = UIX.Div(LayerModal, "layer", "scrim-strong");
            loading.style.backgroundColor = new Color(0.03f, 0.05f, 0.09f, 1f);
            loading.style.alignItems = Align.Center;
            loading.style.justifyContent = Justify.Center;
            var brand = UIX.Div(loading, "row");
            var mark = UIX.Div(brand, "logo-mark");
            UIX.Div(mark, "logo-cross-v");
            UIX.Div(mark, "logo-cross-h");
            var titles = UIX.Div(brand, "col");
            UIX.Text(titles, "BLOUSE BLANCHE", "w800", "t-h1");
            UIX.Text(titles, "Simulateur médical", "t-body");
            UIX.Spacer(loading, 48);
            var bar = UIX.Div(loading, "loading-bar");
            loadingFill = UIX.Div(bar, "loading-fill");
            loadingFill.style.width = Length.Percent(0);
            UIX.Spacer(loading, 14);
            loadingStep = UIX.Text(loading, "Préparation…", "t-small");
            UIX.Spacer(loading, 60);
            UIX.Text(loading, "Conseil : interrogez avant d'examiner, examinez avant de prescrire.", "t-tiny");
            UIX.IgnorePicking(loading);
        }

        public void SetLoading(float progress, string step)
        {
            if (loading == null) return;
            loadingFill.style.width = Length.Percent(Mathf.Clamp01(progress) * 100f);
            if (!string.IsNullOrEmpty(step)) loadingStep.text = step + "…";
        }

        public void HideLoading()
        {
            if (loading == null) return;
            loading.AddToClassList("loading-out");
            var l = loading;
            l.schedule.Execute(() => l.RemoveFromHierarchy()).StartingIn(900);
            loading = null;
        }

        // ================================================================== notifications

        public void Toast(string title, string message, ToastKind kind = ToastKind.Info, float seconds = 5.5f)
        {
            if (toastStack == null) return;
            var t = UIX.Div(toastStack, "toast", kind.ToString().ToLowerInvariant());
            UIX.Div(t, "toast-bar");
            var body = UIX.Div(t, "toast-body");
            UIX.Text(body, title, "w700", kind == ToastKind.Urgent ? "t-danger" : "");
            UIX.Spacer(body, 2);
            UIX.Text(body, message, "t-small");
            UIX.IgnorePicking(t);
            t.schedule.Execute(() => t.AddToClassList("visible")).StartingIn(20);
            t.schedule.Execute(() => t.RemoveFromClassList("visible")).StartingIn((long)(seconds * 1000));
            t.schedule.Execute(() => t.RemoveFromHierarchy()).StartingIn((long)(seconds * 1000) + 400);
            while (toastStack.childCount > 4) toastStack.RemoveAt(0);
        }

        public void Subtitle(string speaker, string text, float seconds = 0f)
        {
            if (subtitle == null) return;
            subtitleSpeaker.text = speaker;
            subtitleText.text = text;
            subtitle.AddToClassList("visible");
            float dur = seconds > 0f ? seconds : Mathf.Clamp(2f + text.Length * 0.05f, 3f, 9f);
            subtitleHide?.Pause();
            subtitleHide = subtitle.schedule.Execute(() => subtitle.RemoveFromClassList("visible")).StartingIn((long)(dur * 1000));
        }

        public void HideSubtitle()
        {
            subtitleHide?.Pause();
            subtitle?.RemoveFromClassList("visible");
        }

        public void Fade(bool toBlack) => layerFade?.EnableInClassList("on", toBlack);

        /// <summary>Écrans de prise en charge : notifications et sous-titres se décalent pour ne pas masquer les panneaux.</summary>
        public void SetInCare(bool inCare) => Root?.EnableInClassList("in-care", inCare);

        // ================================================================== boîte de dialogue

        public void Confirm(string title, string message, string ok, Action onOk, string cancel = "Annuler")
        {
            var scrim = UIX.Div(LayerModal, "layer", "scrim");
            scrim.pickingMode = PickingMode.Position;
            var box = UIX.Div(scrim, "modal", "panel");
            UIX.Text(box, title, "w700", "t-h2");
            UIX.Spacer(box, 10);
            UIX.Text(box, message, "t-body");
            UIX.Spacer(box, 22);
            var row = UIX.Div(box, "row");
            UIX.Div(row, "spacer");
            UIX.Btn(row, cancel, () => scrim.RemoveFromHierarchy(), "ghost");
            UIX.HSpace(row, 10);
            UIX.Btn(row, ok, () => { scrim.RemoveFromHierarchy(); onOk?.Invoke(); }, "primary");
        }

        /// <summary>Vrai si un élément interactif a le focus clavier (pour ne pas voler les touches).</summary>
        public void BlurFocus()
        {
            var f = Root?.panel?.focusController?.focusedElement as VisualElement;
            f?.Blur();
        }
    }
}
