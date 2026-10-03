using BlouseBlanche.Emergency;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    /// <summary>
    /// Écran de scope "vivant" dans le décor : texture redessinée en continu (tracés + valeurs),
    /// appliquée en albédo et en émission sur l'écran du moniteur ou du défibrillateur.
    /// </summary>
    public sealed class LiveMonitor : MonoBehaviour
    {
        const int W = 320, H = 200;
        static readonly Color32 Bg = new Color32(3, 7, 10, 255);
        static readonly Color32 Grid = new Color32(14, 30, 30, 255);
        static readonly Color32 Green = new Color32(70, 255, 120, 255);
        static readonly Color32 Cyan = new Color32(80, 225, 255, 255);
        static readonly Color32 Yellow = new Color32(255, 214, 80, 255);
        static readonly Color32 White = new Color32(220, 230, 235, 255);
        static readonly Color32 Red = new Color32(255, 70, 70, 255);
        static readonly Color32 Dim = new Color32(60, 80, 85, 255);

        Texture2D tex;
        Color32[] px;
        Material mat;
        float timer;
        public MonitorSignal Signal;
        public EmergencySession Session;
        public bool Alarm;

        public static LiveMonitor Attach(Renderer screen, MonitorSignal signal)
        {
            if (screen == null) return null;
            var lm = screen.gameObject.AddComponent<LiveMonitor>();
            lm.Signal = signal;
            lm.Init(screen);
            return lm;
        }

        void Init(Renderer r)
        {
            tex = new Texture2D(W, H, TextureFormat.RGBA32, false, false) { name = "LiveMonitor", wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
            px = new Color32[W * H];
            mat = new Material(r.sharedMaterial) { name = "LiveMonitorMat" };
            mat.SetTexture("_BaseMap", tex);
            mat.SetTexture("_MainTex", tex);
            mat.SetTexture("_EmissionMap", tex);
            mat.SetColor("_BaseColor", Color.white);
            mat.SetColor("_EmissionColor", Color.white * 1.7f);
            mat.EnableKeyword("_EMISSION");
            mat.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
            r.sharedMaterial = mat;
            Redraw();
        }

        void Update()
        {
            timer -= Time.deltaTime;
            if (timer > 0f) return;
            timer = 1f / 24f;
            Redraw();
        }

        void Redraw()
        {
            if (px == null) return;
            for (int i = 0; i < px.Length; i++) px[i] = Bg;
            for (int x = 0; x < W; x += 16) for (int y = 0; y < H; y += 4) px[y * W + x] = Grid;
            for (int y = 0; y < H; y += 16) for (int x = 0; x < W; x += 4) px[y * W + x] = Grid;

            bool on = Signal != null && Signal.Connected && Session != null;
            int traceW = 222;
            if (on)
            {
                Trace(Signal.Ecg, 150, 34f, traceW, Green);
                Trace(Signal.Pleth, 92, 22f, traceW, Cyan);
                Trace(Signal.Resp, 40, 14f, traceW, Yellow);
                var s = Session.S;
                bool flat = !s.Pulse;
                Text("FC", 232, 186, 1, Green);
                Text(flat ? "0" : Mathf.RoundToInt(s.Hr).ToString(), 232, 156, 4, Alarm && flat ? Red : Green);
                Text("SPO2", 232, 126, 1, Cyan);
                Text(flat || s.Spo2 < 40f ? "--" : Mathf.RoundToInt(s.Spo2).ToString(), 232, 100, 3, s.Spo2 < 90f ? Red : Cyan);
                Text("PNI", 232, 80, 1, White);
                Text(flat ? "--/--" : Mathf.RoundToInt(s.Sys) + "/" + Mathf.RoundToInt(s.Dia), 232, 64, 2, s.Sys < 90f ? Red : White);
                Text("FR", 232, 44, 1, Yellow);
                Text(Mathf.RoundToInt(s.Rr).ToString(), 232, 22, 3, Yellow);
                if (Alarm && Mathf.Repeat(Time.time, 1f) < 0.6f)
                {
                    for (int x = 0; x < W; x++) { px[(H - 1) * W + x] = Red; px[(H - 2) * W + x] = Red; px[x] = Red; px[W + x] = Red; }
                    Text(flat ? "ALARME" : "ALERTE", 8, 184, 1, Red);
                }
                else Text(s.RhythmName.Length > 22 ? s.RhythmName.Substring(0, 22) : s.RhythmName, 8, 184, 1, Green);
            }
            else
            {
                Text("PAS DE SIGNAL", 96, 104, 2, Dim);
                Text("BRANCHER LES CAPTEURS", 92, 84, 1, Dim);
            }
            tex.SetPixels32(px);
            tex.Apply(false, false);
        }

        void Trace(float[] data, int baseY, float amp, int width, Color32 c)
        {
            int n = data.Length;
            int prevY = int.MinValue;
            for (int x = 0; x < width; x++)
            {
                int i = x * n / width;
                if (Signal.IsGap(i)) { prevY = int.MinValue; continue; }
                float v = data[i];
                if (float.IsNaN(v)) { prevY = int.MinValue; continue; }
                int y = Mathf.Clamp(baseY + Mathf.RoundToInt(v * amp), 1, H - 2);
                int y0 = prevY == int.MinValue ? y : prevY;
                int a = Mathf.Min(y0, y), b = Mathf.Max(y0, y);
                for (int yy = a; yy <= b; yy++) { px[yy * W + x + 4] = c; px[Mathf.Min(H - 1, yy + 1) * W + x + 4] = c; }
                prevY = y;
            }
        }

        void Text(string s, int x, int y, int scale, Color32 c)
        {
            s = s.ToUpperInvariant();
            int cx = x;
            foreach (char ch in s)
            {
                char g = PixelFont.Normalize(ch);
                for (int gy = 0; gy < PixelFont.GlyphH; gy++)
                    for (int gx = 0; gx < PixelFont.GlyphW; gx++)
                    {
                        if (!PixelFont.Pixel(g, gx, gy)) continue;
                        for (int sy = 0; sy < scale; sy++)
                            for (int sx = 0; sx < scale; sx++)
                            {
                                int px0 = cx + gx * scale + sx;
                                int py0 = y + (PixelFont.GlyphH - 1 - gy) * scale + sy;
                                if (px0 >= 0 && px0 < W && py0 >= 0 && py0 < H) px[py0 * W + px0] = c;
                            }
                    }
                cx += (PixelFont.GlyphW + 1) * scale;
            }
        }

        void OnDestroy()
        {
            if (tex != null) Destroy(tex);
            if (mat != null) Destroy(mat);
        }
    }
}
