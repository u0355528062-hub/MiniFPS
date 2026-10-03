using System;
using BlouseBlanche.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    /// <summary>Petites fabriques d'éléments UI Toolkit (lisibilité du code des vues).</summary>
    public static class UIX
    {
        public static VisualElement Div(params string[] classes)
        {
            var e = new VisualElement();
            foreach (var c in classes) if (!string.IsNullOrEmpty(c)) e.AddToClassList(c);
            return e;
        }

        public static VisualElement Div(VisualElement parent, params string[] classes)
        {
            var e = Div(classes);
            parent?.Add(e);
            return e;
        }

        public static Label Text(VisualElement parent, string text, params string[] classes)
        {
            var l = new Label(text);
            l.pickingMode = PickingMode.Ignore;
            foreach (var c in classes) if (!string.IsNullOrEmpty(c)) l.AddToClassList(c);
            parent?.Add(l);
            return l;
        }

        public static Button Btn(VisualElement parent, string text, Action onClick, params string[] classes)
        {
            var b = new Button();
            b.text = text;
            b.AddToClassList("bb-btn");
            foreach (var c in classes) if (!string.IsNullOrEmpty(c)) b.AddToClassList(c);
            b.clicked += () =>
            {
                Sound(Sfx.UiClick, 0.55f);
                onClick?.Invoke();
            };
            b.RegisterCallback<PointerEnterEvent>(_ => { if (b.enabledInHierarchy) Sound(Sfx.UiHover, 0.35f); });
            parent?.Add(b);
            return b;
        }

        /// <summary>Bouton sans la classe bb-btn (styles de liste, menu, onglets).</summary>
        public static Button Plain(VisualElement parent, string text, Action onClick, params string[] classes)
        {
            var b = new Button();
            b.text = text;
            foreach (var c in classes) if (!string.IsNullOrEmpty(c)) b.AddToClassList(c);
            b.clicked += () =>
            {
                Sound(Sfx.UiClick, 0.5f);
                onClick?.Invoke();
            };
            b.RegisterCallback<PointerEnterEvent>(_ => { if (b.enabledInHierarchy) Sound(Sfx.UiHover, 0.3f); });
            parent?.Add(b);
            return b;
        }

        public static void Sound(Sfx s, float v)
        {
            var root = GameRoot.Instance;
            if (root != null && root.Audio != null) root.Audio.PlayUI(s, v);
        }

        public static Label Chip(VisualElement parent, string text, string kind)
        {
            var l = Text(parent, text, "chip", kind);
            return l;
        }

        public static VisualElement Spacer(VisualElement parent, float height)
        {
            var e = new VisualElement();
            e.style.height = height;
            e.style.flexShrink = 0;
            e.pickingMode = PickingMode.Ignore;
            parent?.Add(e);
            return e;
        }

        public static VisualElement HSpace(VisualElement parent, float width)
        {
            var e = new VisualElement();
            e.style.width = width;
            e.style.flexShrink = 0;
            e.pickingMode = PickingMode.Ignore;
            parent?.Add(e);
            return e;
        }

        public static Label Key(VisualElement parent, string key)
        {
            var l = Text(parent, key, "keycap");
            return l;
        }

        /// <summary>Rend un élément et tous ses enfants transparents aux clics (HUD).</summary>
        public static void IgnorePicking(VisualElement e)
        {
            e.pickingMode = PickingMode.Ignore;
            foreach (var c in e.Children()) IgnorePicking(c);
        }

        public static void Show(VisualElement e, bool show)
        {
            if (e == null) return;
            e.EnableInClassList("hidden", !show);
        }

        /// <summary>Affiche/masque avec la transition .screen/.visible.</summary>
        public static void Fade(VisualElement e, bool show)
        {
            if (e == null) return;
            if (show)
            {
                e.RemoveFromClassList("hidden");
                e.schedule.Execute(() => e.AddToClassList("visible")).StartingIn(16);
            }
            else
            {
                e.RemoveFromClassList("visible");
                e.schedule.Execute(() => { if (!e.ClassListContains("visible")) e.AddToClassList("hidden"); }).StartingIn(360);
            }
        }

        public static Color Hex(string hex)
        {
            return ColorUtility.TryParseHtmlString(hex, out var c) ? c : Color.white;
        }
    }

    // ====================================================================== contrôles maison

    /// <summary>Curseur au style du jeu (piste, remplissage, bouton).</summary>
    public sealed class BBSlider : VisualElement
    {
        readonly VisualElement track, fill, knob;
        readonly float min, max;
        float value;
        public event Action<float> Changed;

        public BBSlider(float min, float max, float value)
        {
            this.min = min;
            this.max = max;
            AddToClassList("slider");
            track = UIX.Div(this, "slider-track");
            fill = UIX.Div(track, "slider-fill");
            knob = UIX.Div(track, "slider-knob");
            fill.pickingMode = PickingMode.Ignore;
            knob.pickingMode = PickingMode.Ignore;
            style.flexGrow = 1;
            SetValueWithoutNotify(value);
            RegisterCallback<PointerDownEvent>(OnDown);
            RegisterCallback<PointerMoveEvent>(OnMove);
            RegisterCallback<PointerUpEvent>(OnUp);
        }

        public float Value => value;

        public void SetValueWithoutNotify(float v)
        {
            value = Mathf.Clamp(v, min, max);
            float t = Mathf.Approximately(max, min) ? 0f : (value - min) / (max - min);
            fill.style.width = Length.Percent(t * 100f);
            knob.style.left = Length.Percent(t * 100f);
        }

        void SetFromPointer(Vector2 localPos)
        {
            float w = track.layout.width;
            if (w <= 1f) return;
            Vector2 p = this.ChangeCoordinatesTo(track, localPos);
            float t = Mathf.Clamp01(p.x / w);
            float v = Mathf.Lerp(min, max, t);
            if (!Mathf.Approximately(v, value))
            {
                SetValueWithoutNotify(v);
                Changed?.Invoke(value);
            }
        }

        void OnDown(PointerDownEvent e)
        {
            this.CapturePointer(e.pointerId);
            SetFromPointer(e.localPosition);
            e.StopPropagation();
        }

        void OnMove(PointerMoveEvent e)
        {
            if (!this.HasPointerCapture(e.pointerId)) return;
            SetFromPointer(e.localPosition);
        }

        void OnUp(PointerUpEvent e)
        {
            if (this.HasPointerCapture(e.pointerId)) this.ReleasePointer(e.pointerId);
            UIX.Sound(Sfx.UiClick, 0.3f);
        }
    }

    /// <summary>Interrupteur on/off.</summary>
    public sealed class BBToggle : VisualElement
    {
        bool on;
        public event Action<bool> Changed;

        public BBToggle(bool value)
        {
            AddToClassList("toggle");
            var knob = UIX.Div(this, "toggle-knob");
            knob.pickingMode = PickingMode.Ignore;
            Set(value, false);
            RegisterCallback<ClickEvent>(_ =>
            {
                Set(!on, true);
                UIX.Sound(Sfx.UiClick, 0.5f);
            });
        }

        public bool Value => on;

        public void Set(bool v, bool notify)
        {
            on = v;
            EnableInClassList("on", v);
            if (notify) Changed?.Invoke(v);
        }
    }

    /// <summary>Sélecteur segmenté (ex. qualité graphique).</summary>
    public sealed class BBSegmented : VisualElement
    {
        readonly Button[] buttons;
        int index;
        public event Action<int> Changed;

        public BBSegmented(string[] options, int selected)
        {
            AddToClassList("segmented");
            buttons = new Button[options.Length];
            for (int i = 0; i < options.Length; i++)
            {
                int k = i;
                buttons[i] = UIX.Plain(this, options[i], () => Select(k, true), "segment");
            }
            Select(selected, false);
        }

        public void Select(int i, bool notify)
        {
            index = Mathf.Clamp(i, 0, buttons.Length - 1);
            for (int b = 0; b < buttons.Length; b++) buttons[b].EnableInClassList("on", b == index);
            if (notify) Changed?.Invoke(index);
        }
    }
}
