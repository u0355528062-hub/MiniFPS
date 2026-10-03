using System.Collections.Generic;
using BlouseBlanche.Emergency;
using BlouseBlanche.Medical;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.UI
{
    /// <summary>
    /// Icônes des outils médicaux, dessinées en code (traits blancs sur fond transparent,
    /// teintées par l'interface). C# pur pour la partie dessin.
    /// </summary>
    public static class ToolIcons
    {
        static readonly Color Clear = new Color(1f, 1f, 1f, 0f);
        static readonly Color W = Color.white;
        const float Stroke = 7f;

        static readonly Dictionary<MedicalTool, Texture2D> cache = new Dictionary<MedicalTool, Texture2D>();

        static readonly Dictionary<EmergencyTool, Texture2D> emergencyCache = new Dictionary<EmergencyTool, Texture2D>();

        public static Texture2D Get(MedicalTool tool)
        {
            if (cache.TryGetValue(tool, out var t) && t != null) return t;
            t = ToTexture(Paint(tool, 128), "Icon_" + tool);
            cache[tool] = t;
            return t;
        }

        /// <summary>Icônes du matériel d'urgence (prototypes SAMU / urgences).</summary>
        public static Texture2D Get(EmergencyTool tool)
        {
            if (emergencyCache.TryGetValue(tool, out var t) && t != null) return t;
            t = ToTexture(Paint(tool, 128), "IconUrg_" + tool);
            emergencyCache[tool] = t;
            return t;
        }

        static Texture2D ToTexture(TexturePainter p, string name)
        {
            var t = new Texture2D(p.W, p.H, TextureFormat.RGBA32, true, false)
            {
                name = name,
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Trilinear
            };
            t.SetPixels32(p.ToColor32());
            t.Apply(true, true);
            return t;
        }

        public static TexturePainter Paint(MedicalTool tool, int s)
        {
            var p = new TexturePainter(s, s, Clear);
            float u = s / 128f;
            switch (tool)
            {
                case MedicalTool.Mains: Hand(p, u); break;
                case MedicalTool.Stethoscope: Stethoscope(p, u); break;
                case MedicalTool.Tensiometre: Tensiometer(p, u); break;
                case MedicalTool.Thermometre: Thermometer(p, u); break;
                case MedicalTool.Oxymetre: Oximeter(p, u); break;
                case MedicalTool.Otoscope: Otoscope(p, u); break;
                case MedicalTool.AbaisseLangue: Depressor(p, u); break;
                case MedicalTool.Marteau: Hammer(p, u); break;
                case MedicalTool.Debitmetre: PeakFlow(p, u); break;
                case MedicalTool.ECG: Ecg(p, u); break;
                case MedicalTool.TestsRapides: RapidTest(p, u); break;
                case MedicalTool.Balance: Scale(p, u); break;
            }
            return p;
        }

        public static TexturePainter Paint(EmergencyTool tool, int s)
        {
            var p = new TexturePainter(s, s, Clear);
            float u = s / 128f;
            switch (tool)
            {
                case EmergencyTool.Bilan: Clipboard(p, u); break;
                case EmergencyTool.Scope: Monitor(p, u); break;
                case EmergencyTool.ECG: Ecg(p, u); break;
                case EmergencyTool.Defibrillateur: Defibrillator(p, u); break;
                case EmergencyTool.RCP: Cpr(p, u); break;
                case EmergencyTool.Oxygene: OxygenBottle(p, u); break;
                case EmergencyTool.Perfusion: IvBag(p, u); break;
                case EmergencyTool.Medicaments: Syringe(p, u); break;
                case EmergencyTool.Glucometre: Glucometer(p, u); break;
                case EmergencyTool.Immobilisation: Splint(p, u); break;
                case EmergencyTool.Biologie: TestTubes(p, u); break;
                case EmergencyTool.Imagerie: XRay(p, u); break;
            }
            return p;
        }

        static void Outline(TexturePainter p, float x0, float y0, float x1, float y1, float r, float u)
        {
            p.FillRoundRect(x0 * u, y0 * u, x1 * u, y1 * u, r * u, W);
            p.FillRoundRect((x0 + Stroke) * u, (y0 + Stroke) * u, (x1 - Stroke) * u, (y1 - Stroke) * u, Mathf.Max(0f, r - Stroke) * u, Clear);
        }

        static void L(TexturePainter p, float ax, float ay, float bx, float by, float u, float w = Stroke)
            => p.Line(ax * u, ay * u, bx * u, by * u, w * u, W);

        static void Curve(TexturePainter p, float u, float w, params Vector2[] pts)
        {
            // Catmull-Rom échantillonnée
            var outPts = new List<Vector2>();
            for (int i = 0; i < pts.Length - 1; i++)
            {
                Vector2 p0 = pts[Mathf.Max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Mathf.Min(pts.Length - 1, i + 2)];
                for (int k = 0; k < 10; k++)
                {
                    float t = k / 10f, t2 = t * t, t3 = t2 * t;
                    outPts.Add(0.5f * ((2f * p1) + (-p0 + p2) * t + (2f * p0 - 5f * p1 + 4f * p2 - p3) * t2 + (-p0 + 3f * p1 - 3f * p2 + p3) * t3) * u);
                }
            }
            outPts.Add(pts[pts.Length - 1] * u);
            p.Polyline(outPts.ToArray(), w * u, W);
        }

        static void Hand(TexturePainter p, float u)
        {
            p.FillRoundRect(36 * u, 22 * u, 88 * u, 70 * u, 18 * u, W);
            float[] fx = { 38, 51, 64, 77 };
            float[] fh = { 92, 104, 106, 96 };
            for (int i = 0; i < 4; i++) p.FillRoundRect(fx[i] * u, 56 * u, (fx[i] + 11) * u, fh[i] * u, 5.5f * u, W);
            p.Line(88 * u, 48 * u, 106 * u, 72 * u, 12 * u, W);
            p.FillCircle(106 * u, 72 * u, 6 * u, W);
            // pli de la paume
            p.Line(48 * u, 40 * u, 74 * u, 46 * u, 3 * u, Clear);
        }

        static void Stethoscope(TexturePainter p, float u)
        {
            p.FillCircle(34 * u, 112 * u, 6 * u, W);
            p.FillCircle(66 * u, 112 * u, 6 * u, W);
            Curve(p, u, Stroke, new Vector2(34, 110), new Vector2(30, 84), new Vector2(50, 60), new Vector2(70, 84), new Vector2(66, 110));
            Curve(p, u, Stroke, new Vector2(50, 60), new Vector2(50, 40), new Vector2(62, 22), new Vector2(84, 22), new Vector2(98, 38), new Vector2(98, 56));
            p.FillCircle(98 * u, 70 * u, 16 * u, W);
            p.FillCircle(98 * u, 70 * u, 8 * u, Clear);
            p.FillCircle(98 * u, 70 * u, 4 * u, W);
        }

        static void Tensiometer(TexturePainter p, float u)
        {
            Outline(p, 14, 52, 74, 98, 10, u);
            L(p, 26, 75, 62, 75, u, 4);
            Curve(p, u, 5, new Vector2(74, 64), new Vector2(86, 54), new Vector2(92, 40));
            p.FillCircle(96 * u, 32 * u, 20 * u, W);
            p.FillCircle(96 * u, 32 * u, 13 * u, Clear);
            L(p, 96, 32, 104, 40, u, 4);
            p.FillCircle(96 * u, 32 * u, 3.5f * u, W);
            Curve(p, u, 5, new Vector2(44, 52), new Vector2(40, 34), new Vector2(30, 24));
            p.FillEllipse(26 * u, 18 * u, 9 * u, 12 * u, W);
        }

        static void Thermometer(TexturePainter p, float u)
        {
            // Thermomètre digital en diagonale
            p.Line(30 * u, 30 * u, 96 * u, 96 * u, 22 * u, W);
            p.Line(30 * u, 30 * u, 96 * u, 96 * u, 9 * u, Clear);
            p.FillCircle(24 * u, 24 * u, 12 * u, W);
            p.Line(28 * u, 28 * u, 70 * u, 70 * u, 6 * u, W);
            p.FillRoundRect(84 * u, 98 * u, 116 * u, 118 * u, 5 * u, W);
            p.FillRect((int)(90 * u), (int)(103 * u), (int)(110 * u), (int)(113 * u), Clear);
        }

        static void Oximeter(TexturePainter p, float u)
        {
            Outline(p, 22, 36, 106, 96, 22, u);
            p.FillRoundRect(40 * u, 54 * u, 78 * u, 78 * u, 5 * u, W);
            p.Text("98", (int)(43 * u), (int)(59 * u), Mathf.Max(1, Mathf.RoundToInt(2.4f * u)), Clear);
            p.FillCircle(90 * u, 66 * u, 6 * u, W);
            // doigt
            p.FillRoundRect(4 * u, 58 * u, 34 * u, 74 * u, 8 * u, W);
        }

        static void Otoscope(TexturePainter p, float u)
        {
            // manche strié
            p.FillRoundRect(52 * u, 8 * u, 76 * u, 66 * u, 9 * u, W);
            for (int i = 0; i < 4; i++) p.Line(56 * u, (20 + i * 11) * u, 72 * u, (20 + i * 11) * u, 2.5f * u, Clear);
            p.FillRect((int)(58 * u), (int)(64 * u), (int)(70 * u), (int)(74 * u), W);
            // tête avec lentille
            p.FillCircle(64 * u, 88 * u, 19 * u, W);
            p.FillCircle(64 * u, 88 * u, 11 * u, Clear);
            // spéculum conique vers la droite
            for (int i = 0; i <= 26; i++)
            {
                float t = i / 26f;
                float x = Mathf.Lerp(80f, 120f, t);
                float hh = Mathf.Lerp(12f, 3.5f, t);
                p.Line(x * u, (88f - hh) * u, x * u, (88f + hh) * u, 2.2f * u, W);
            }
        }

        static void Depressor(TexturePainter p, float u)
        {
            p.Line(18 * u, 30 * u, 92 * u, 86 * u, 16 * u, W);
            p.FillCircle(18 * u, 30 * u, 8 * u, W);
            p.FillCircle(92 * u, 86 * u, 8 * u, W);
            // lampe stylo
            p.Line(70 * u, 20 * u, 112 * u, 52 * u, 9 * u, W);
            for (int i = -1; i <= 1; i++)
            {
                float a = Mathf.Atan2(32f, 42f) + i * 0.35f;
                p.Line(118 * u, 57 * u, (118 + Mathf.Cos(a) * 14f) * u, (57 + Mathf.Sin(a) * 14f) * u, 3 * u, W);
            }
        }

        static void Hammer(TexturePainter p, float u)
        {
            // marteau de Taylor : tête triangulaire perpendiculaire au manche
            p.Line(64 * u, 104 * u, 64 * u, 14 * u, 8 * u, W);
            p.FillCircle(64 * u, 14 * u, 6 * u, W);
            for (int x = 0; x <= 76; x++)
            {
                float t = x / 76f;
                float half = Mathf.Lerp(15f, 2.5f, t);
                p.Line((26 + x) * u, (106 - half) * u, (26 + x) * u, (106 + half) * u, 1.6f * u, W);
            }
            p.FillCircle(26 * u, 106 * u, 15 * u, W);
        }

        static void PeakFlow(TexturePainter p, float u)
        {
            Outline(p, 26, 46, 110, 82, 12, u);
            p.FillRoundRect(6 * u, 54 * u, 28 * u, 74 * u, 6 * u, W);
            for (int i = 0; i < 6; i++) L(p, 44 + i * 10, 76, 44 + i * 10, 68, u, 2.5f);
            p.FillRect((int)(70 * u), (int)(54 * u), (int)(76 * u), (int)(76 * u), W);
            Curve(p, u, 4, new Vector2(20, 98), new Vector2(50, 108), new Vector2(84, 100));
            L(p, 84, 100, 76, 108, u, 4);
            L(p, 84, 100, 76, 93, u, 4);
        }

        static void Ecg(TexturePainter p, float u)
        {
            Outline(p, 8, 24, 120, 104, 14, u);
            var pts = new[]
            {
                new Vector2(18, 62), new Vector2(38, 62), new Vector2(44, 70), new Vector2(50, 62), new Vector2(56, 62),
                new Vector2(62, 92), new Vector2(68, 38), new Vector2(74, 62), new Vector2(86, 62), new Vector2(92, 72),
                new Vector2(98, 62), new Vector2(110, 62)
            };
            for (int i = 0; i < pts.Length; i++) pts[i] *= u;
            p.Polyline(pts, 5 * u, W);
        }

        static void RapidTest(TexturePainter p, float u)
        {
            p.FillRoundRect(28 * u, 14 * u, 76 * u, 114 * u, 12 * u, W);
            p.FillRoundRect(40 * u, 56 * u, 64 * u, 96 * u, 4 * u, Clear);
            p.Line(44 * u, 84 * u, 60 * u, 84 * u, 3.5f * u, W);
            p.Line(44 * u, 70 * u, 60 * u, 70 * u, 3.5f * u, W);
            p.FillCircle(52 * u, 32 * u, 7 * u, Clear);
            // goutte
            p.FillCircle(98 * u, 44 * u, 12 * u, W);
            for (int y = 0; y < 18; y++)
            {
                float half = Mathf.Lerp(11f, 0.5f, y / 18f);
                p.Line((98 - half) * u, (48 + y) * u, (98 + half) * u, (48 + y) * u, 1.6f * u, W);
            }
        }

        static void Scale(TexturePainter p, float u)
        {
            p.FillRoundRect(14 * u, 14 * u, 114 * u, 34 * u, 8 * u, W);
            L(p, 64, 34, 64, 92, u, 8);
            p.FillCircle(64 * u, 100 * u, 20 * u, W);
            p.FillCircle(64 * u, 100 * u, 13 * u, Clear);
            L(p, 64, 100, 72, 108, u, 4);
            for (int i = 0; i < 5; i++) L(p, 90, 44 + i * 10, 100, 44 + i * 10, u, 3);
            L(p, 104, 40, 104, 92, u, 4);
        }

        // ================================================================== matériel d'urgence

        static void Clipboard(TexturePainter p, float u)
        {
            Outline(p, 26, 8, 102, 112, 12, u);
            p.FillRoundRect(46 * u, 100 * u, 82 * u, 120 * u, 6 * u, W);
            p.FillRoundRect(56 * u, 106 * u, 72 * u, 114 * u, 3 * u, Clear);
            p.Polyline(new[] { new Vector2(42, 62) * u, new Vector2(58, 46) * u, new Vector2(88, 80) * u }, 9 * u, W);
            L(p, 42, 28, 86, 28, u, 4);
        }

        static void Monitor(TexturePainter p, float u)
        {
            Outline(p, 8, 34, 120, 112, 12, u);
            L(p, 64, 34, 64, 18, u, 8);
            L(p, 40, 14, 88, 14, u, 8);
            var pts = new[]
            {
                new Vector2(20, 74), new Vector2(40, 74), new Vector2(47, 92), new Vector2(55, 56), new Vector2(62, 74),
                new Vector2(78, 74), new Vector2(84, 82), new Vector2(90, 74), new Vector2(108, 74)
            };
            for (int i = 0; i < pts.Length; i++) pts[i] *= u;
            p.Polyline(pts, 5 * u, W);
        }

        static void Defibrillator(TexturePainter p, float u)
        {
            p.Polyline(new[] { new Vector2(74, 122) * u, new Vector2(50, 82) * u, new Vector2(72, 82) * u, new Vector2(54, 44) * u }, 9 * u, W);
            p.FillRoundRect(8 * u, 8 * u, 52 * u, 32 * u, 9 * u, W);
            p.FillRoundRect(76 * u, 8 * u, 120 * u, 32 * u, 9 * u, W);
            L(p, 30, 32, 30, 52, u, 7);
            L(p, 98, 32, 98, 52, u, 7);
        }

        static void Cpr(TexturePainter p, float u)
        {
            p.Heart(64 * u, 46 * u, 34 * u, W);
            L(p, 64, 124, 64, 94, u, 8);
            L(p, 64, 90, 50, 104, u, 7);
            L(p, 64, 90, 78, 104, u, 7);
        }

        static void OxygenBottle(TexturePainter p, float u)
        {
            p.FillRoundRect(38 * u, 6 * u, 90 * u, 92 * u, 20 * u, W);
            p.FillRect((int)(56 * u), (int)(90 * u), (int)(72 * u), (int)(104 * u), W);
            p.FillRoundRect(46 * u, 102 * u, 82 * u, 116 * u, 4 * u, W);
            L(p, 82, 110, 104, 110, u, 6);
            p.Text("O2", (int)(47 * u), (int)(38 * u), Mathf.Max(1, Mathf.RoundToInt(3f * u)), Clear);
        }

        static void IvBag(TexturePainter p, float u)
        {
            Outline(p, 32, 54, 96, 120, 16, u);
            p.FillRoundRect(42 * u, 64 * u, 86 * u, 88 * u, 6 * u, W);
            L(p, 64, 54, 64, 42, u, 5);
            p.FillRoundRect(55 * u, 22 * u, 73 * u, 44 * u, 5 * u, W);
            L(p, 64, 22, 64, 4, u, 4);
            L(p, 52, 120, 76, 120, u, 5);
        }

        static void Syringe(TexturePainter p, float u)
        {
            p.Line(34 * u, 34 * u, 86 * u, 86 * u, 24 * u, W);
            p.Line(40 * u, 40 * u, 80 * u, 80 * u, 11 * u, Clear);
            p.Line(40 * u, 40 * u, 58 * u, 58 * u, 11 * u, W);
            L(p, 34, 34, 10, 10, u, 3.5f);
            L(p, 76, 96, 96, 76, u, 6);
            L(p, 86, 86, 106, 106, u, 6);
            L(p, 98, 114, 114, 98, u, 7);
        }

        static void Glucometer(TexturePainter p, float u)
        {
            Outline(p, 26, 8, 94, 88, 16, u);
            p.FillRoundRect(38 * u, 46 * u, 82 * u, 74 * u, 5 * u, W);
            p.Text("1,0", (int)(43 * u), (int)(52 * u), Mathf.Max(1, Mathf.RoundToInt(2f * u)), Clear);
            p.FillCircle(60 * u, 26 * u, 6 * u, W);
            L(p, 60, 88, 60, 104, u, 8);
            p.FillCircle(104 * u, 106 * u, 11 * u, W);
            for (int y = 0; y < 16; y++)
            {
                float half = Mathf.Lerp(10f, 0.5f, y / 16f);
                p.Line((104 - half) * u, (110 + y) * u, (104 + half) * u, (110 + y) * u, 1.6f * u, W);
            }
        }

        static void Splint(TexturePainter p, float u)
        {
            L(p, 46, 12, 46, 116, u, 14);
            L(p, 82, 12, 82, 116, u, 14);
            for (int i = 0; i < 3; i++)
            {
                float y = 30 + i * 34;
                p.FillRoundRect(30 * u, (y - 6) * u, 98 * u, (y + 6) * u, 4 * u, W);
                p.FillRoundRect(54 * u, (y - 2) * u, 74 * u, (y + 2) * u, 1 * u, Clear);
            }
        }

        static void TestTubes(TexturePainter p, float u)
        {
            foreach (float x in new[] { 24f, 56f, 88f })
            {
                p.FillRoundRect(x * u, 12 * u, (x + 18) * u, 110 * u, 9 * u, W);
                p.FillRoundRect((x + 5) * u, 17 * u, (x + 13) * u, 104 * u, 4 * u, Clear);
                p.FillRoundRect((x + 5) * u, 17 * u, (x + 13) * u, (x == 56f ? 70 : 52) * u, 4 * u, W);
                L(p, x - 4, 110, x + 22, 110, u, 5);
            }
            L(p, 12, 72, 116, 72, u, 6);
        }

        static void XRay(TexturePainter p, float u)
        {
            Outline(p, 10, 10, 118, 118, 12, u);
            L(p, 64, 26, 64, 102, u, 6);
            for (int i = 0; i < 4; i++)
            {
                float y = 92 - i * 17;
                Curve(p, u, 5, new Vector2(64, y), new Vector2(46, y + 3), new Vector2(30, y - 6));
                Curve(p, u, 5, new Vector2(64, y), new Vector2(82, y + 3), new Vector2(98, y - 6));
            }
        }
    }
}
