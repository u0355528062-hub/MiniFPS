using System;
using System.Collections.Generic;
using BlouseBlanche.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace BlouseBlanche.UI
{
    /// <summary>Un emplacement de la roue d'outils.</summary>
    public sealed class WheelSlot
    {
        public string Name, Description, Hotkey, Detail;
        public Texture2D Icon;
        public bool Enabled = true;
    }

    /// <summary>
    /// Roue d'outils radiale (style "roue d'armes") : maintenir clic droit, viser, relâcher.
    /// Générique : utilisée par la consultation de ville comme par les prototypes SAMU / urgences.
    /// </summary>
    public sealed class ToolWheelView : View
    {
        const float Size = 840f, Radius = 330f;
        readonly VisualElement wheel, slotsRoot;
        readonly Label centerCaption, centerName, centerDesc, centerDetail;
        readonly List<VisualElement> slotEls = new List<VisualElement>();
        List<WheelSlot> slots = new List<WheelSlot>();
        Action<int> onPick;
        int hover = -1, current = -1;

        public bool IsOpen => Visible;

        public ToolWheelView(UIRoot ui, VisualElement parent, GameRoot game) : base(ui)
        {
            var s = MakeScreen(parent, "wheel-backdrop");
            s.RemoveFromClassList("screen");
            wheel = UIX.Div(s, "wheel");
            UIX.Div(wheel, "wheel-ring").pickingMode = PickingMode.Ignore;
            slotsRoot = UIX.Div(wheel, "layer");
            slotsRoot.pickingMode = PickingMode.Ignore;
            var center = UIX.Div(wheel, "wheel-center");
            centerCaption = UIX.Text(center, "OUTIL", "t-caption", "w600", "t-center");
            UIX.Spacer(center, 8);
            centerName = UIX.Text(center, "", "w800", "t-h2", "t-center");
            UIX.Spacer(center, 8);
            centerDesc = UIX.Text(center, "", "t-body", "t-center");
            UIX.Spacer(center, 12);
            centerDetail = UIX.Text(center, "", "t-small", "t-center", "t-accent");
            UIX.IgnorePicking(center);
            s.RegisterCallback<PointerMoveEvent>(e => UpdateHover(e.position));
            s.RegisterCallback<PointerDownEvent>(e => { if (e.button == 0) { UpdateHover(e.position); Pick(); } });
        }

        public void SetSlots(List<WheelSlot> list, Action<int> pick)
        {
            slots = list ?? new List<WheelSlot>();
            onPick = pick;
            slotsRoot.Clear();
            slotEls.Clear();
            int n = Mathf.Max(1, slots.Count);
            for (int i = 0; i < slots.Count; i++)
            {
                float a = (-90f + i * 360f / n) * Mathf.Deg2Rad;
                var slot = UIX.Div(slotsRoot, "wheel-slot");
                slot.style.left = Size * 0.5f + Radius * Mathf.Cos(a);
                slot.style.top = Size * 0.5f + Radius * Mathf.Sin(a);
                var icon = UIX.Div(slot, "wheel-icon");
                if (slots[i].Icon != null) icon.style.backgroundImage = new StyleBackground(slots[i].Icon);
                if (!string.IsNullOrEmpty(slots[i].Hotkey)) UIX.Text(slot, slots[i].Hotkey, "wheel-key", "mono-b", "t-small");
                if (!slots[i].Enabled) slot.style.opacity = 0.35f;
                UIX.IgnorePicking(slot);
                slotEls.Add(slot);
            }
        }

        public void SetCurrent(int index)
        {
            current = index;
            for (int i = 0; i < slotEls.Count; i++) slotEls[i].EnableInClassList("current", i == current);
            if (hover < 0) ShowInfo(current);
        }

        public void Open()
        {
            if (Visible) return;
            hover = -1;
            ShowInfo(current);
            base.Show();
            Root.RemoveFromClassList("hidden");
            wheel.schedule.Execute(() => wheel.AddToClassList("visible")).StartingIn(10);
            UIX.Sound(Sfx.UiHover, 0.5f);
        }

        /// <summary>Ferme la roue ; si pick, équipe l'outil survolé.</summary>
        public void Close(bool pick)
        {
            if (!Visible) return;
            if (pick) Pick();
            wheel.RemoveFromClassList("visible");
            base.Hide();
            Root.AddToClassList("hidden");
        }

        void Pick()
        {
            if (hover >= 0 && hover < slots.Count && slots[hover].Enabled)
            {
                current = hover;
                SetCurrent(current);
                onPick?.Invoke(hover);
                UIX.Sound(Sfx.UiConfirm, 0.5f);
            }
        }

        void UpdateHover(Vector2 panelPos)
        {
            Rect b = wheel.worldBound;
            Vector2 c = b.center;
            Vector2 d = panelPos - c;
            float scale = b.width > 1f ? Size / b.width : 1f;
            float dist = d.magnitude * scale;
            int h = -1;
            if (dist > 150f && slots.Count > 0)
            {
                float ang = Mathf.Atan2(d.y, d.x) * Mathf.Rad2Deg + 90f;
                if (ang < 0f) ang += 360f;
                float step = 360f / slots.Count;
                h = Mathf.RoundToInt(ang / step) % slots.Count;
            }
            if (h == hover) return;
            hover = h;
            for (int i = 0; i < slotEls.Count; i++) slotEls[i].EnableInClassList("hover", i == hover);
            if (hover >= 0) UIX.Sound(Sfx.UiHover, 0.25f);
            ShowInfo(hover >= 0 ? hover : current);
        }

        void ShowInfo(int i)
        {
            if (i < 0 || i >= slots.Count)
            {
                centerCaption.text = "ROUE DES OUTILS";
                centerName.text = "Visez un outil";
                centerDesc.text = "Relâchez le clic droit pour le prendre en main.";
                centerDetail.text = "";
                return;
            }
            var s = slots[i];
            centerCaption.text = i == current ? "OUTIL EN MAIN" : "OUTIL";
            centerName.text = s.Name;
            centerDesc.text = s.Description;
            centerDetail.text = s.Enabled ? s.Detail : "Indisponible ici";
        }
    }
}
