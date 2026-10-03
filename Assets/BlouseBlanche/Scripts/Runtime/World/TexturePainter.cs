using UnityEngine;

namespace BlouseBlanche.World
{
    /// <summary>
    /// Toile de dessin en mémoire (C# pur) : primitives anti-aliasées, dégradés, texte bitmap,
    /// bruit périodique (tuilable) et calcul de normal map. Les couleurs sont exprimées en sRGB.
    /// </summary>
    public sealed class TexturePainter
    {
        public readonly int W;
        public readonly int H;
        public readonly Color[] Px;
        public readonly float[] Height;

        public TexturePainter(int w, int h, Color fill, bool withHeight = false)
        {
            W = w;
            H = h;
            Px = new Color[w * h];
            for (int i = 0; i < Px.Length; i++) Px[i] = fill;
            if (withHeight) Height = new float[w * h];
        }

        // ------------------------------------------------------------------ bruit tuilable

        static uint Hash(int x, int y, int seed)
        {
            unchecked
            {
                uint h = (uint)(x * 374761393) + (uint)(y * 668265263) + (uint)(seed * 1442695041);
                h = (h ^ (h >> 13)) * 1274126177u;
                h ^= h >> 16;
                return h;
            }
        }

        public static float Rand01(int x, int y, int seed) => (Hash(x, y, seed) & 0xFFFFFF) / 16777216f;

        static int Mod(int a, int m) { int r = a % m; return r < 0 ? r + m : r; }

        /// <summary>Bruit de valeur lissé, périodique de période "period" (en unités de grille).</summary>
        public static float ValueNoise(float x, float y, int period, int seed)
        {
            period = Mathf.Max(1, period);
            int x0 = Mathf.FloorToInt(x), y0 = Mathf.FloorToInt(y);
            float fx = x - x0, fy = y - y0;
            int xa = Mod(x0, period), xb = Mod(x0 + 1, period);
            int ya = Mod(y0, period), yb = Mod(y0 + 1, period);
            float u = fx * fx * (3f - 2f * fx);
            float v = fy * fy * (3f - 2f * fy);
            float a = Rand01(xa, ya, seed), b = Rand01(xb, ya, seed);
            float c = Rand01(xa, yb, seed), d = Rand01(xb, yb, seed);
            return Mathf.Lerp(Mathf.Lerp(a, b, u), Mathf.Lerp(c, d, u), v);
        }

        /// <summary>fBm périodique. (u, v) dans [0,1) couvrent exactement une période → tuilable.</summary>
        public static float Fbm(float u, float v, int basePeriod, int octaves, int seed, float persistence = 0.5f)
        {
            float sum = 0f, amp = 1f, norm = 0f;
            int period = basePeriod;
            for (int o = 0; o < octaves; o++)
            {
                sum += ValueNoise(u * period, v * period, period, seed + o * 131) * amp;
                norm += amp;
                amp *= persistence;
                period *= 2;
            }
            return sum / norm;
        }

        /// <summary>fBm anisotrope (périodes différentes en u et v) — fibres de bois, métal brossé.</summary>
        public static float FbmAniso(float u, float v, int periodU, int periodV, int octaves, int seed)
        {
            float sum = 0f, amp = 1f, norm = 0f;
            for (int o = 0; o < octaves; o++)
            {
                int pu = periodU << o, pv = periodV << o;
                // Grille déformée : on échantillonne une grille carrée de pas commun puis on étire.
                float n = ValueNoise2(u * pu, v * pv, pu, pv, seed + o * 71);
                sum += n * amp;
                norm += amp;
                amp *= 0.5f;
            }
            return sum / norm;
        }

        static float ValueNoise2(float x, float y, int periodX, int periodY, int seed)
        {
            int x0 = Mathf.FloorToInt(x), y0 = Mathf.FloorToInt(y);
            float fx = x - x0, fy = y - y0;
            int xa = Mod(x0, Mathf.Max(1, periodX)), xb = Mod(x0 + 1, Mathf.Max(1, periodX));
            int ya = Mod(y0, Mathf.Max(1, periodY)), yb = Mod(y0 + 1, Mathf.Max(1, periodY));
            float u = fx * fx * (3f - 2f * fx);
            float v = fy * fy * (3f - 2f * fy);
            float a = Rand01(xa, ya, seed), b = Rand01(xb, ya, seed);
            float c = Rand01(xa, yb, seed), d = Rand01(xb, yb, seed);
            return Mathf.Lerp(Mathf.Lerp(a, b, u), Mathf.Lerp(c, d, u), v);
        }

        // ------------------------------------------------------------------ accès

        public void Set(int x, int y, Color c)
        {
            if ((uint)x >= (uint)W || (uint)y >= (uint)H) return;
            Px[y * W + x] = c;
        }

        public void Blend(int x, int y, Color c, float a)
        {
            if ((uint)x >= (uint)W || (uint)y >= (uint)H || a <= 0f) return;
            int i = y * W + x;
            Px[i] = Color.Lerp(Px[i], c, Mathf.Clamp01(a));
        }

        public void SetHeight(int x, int y, float h)
        {
            if (Height == null || (uint)x >= (uint)W || (uint)y >= (uint)H) return;
            Height[y * W + x] = h;
        }

        // ------------------------------------------------------------------ primitives (y = 0 en bas)

        public void FillRect(int x0, int y0, int x1, int y1, Color c, float alpha = 1f)
        {
            if (x0 > x1) { int t = x0; x0 = x1; x1 = t; }
            if (y0 > y1) { int t = y0; y0 = y1; y1 = t; }
            x0 = Mathf.Max(0, x0); y0 = Mathf.Max(0, y0);
            x1 = Mathf.Min(W - 1, x1); y1 = Mathf.Min(H - 1, y1);
            for (int y = y0; y <= y1; y++)
                for (int x = x0; x <= x1; x++)
                    Blend(x, y, c, alpha);
        }

        public void FillRoundRect(float x0, float y0, float x1, float y1, float radius, Color c, float alpha = 1f)
        {
            float cx = (x0 + x1) * 0.5f, cy = (y0 + y1) * 0.5f;
            float hx = Mathf.Abs(x1 - x0) * 0.5f, hy = Mathf.Abs(y1 - y0) * 0.5f;
            radius = Mathf.Min(radius, Mathf.Min(hx, hy));
            int ix0 = Mathf.Max(0, Mathf.FloorToInt(cx - hx - 1)), ix1 = Mathf.Min(W - 1, Mathf.CeilToInt(cx + hx + 1));
            int iy0 = Mathf.Max(0, Mathf.FloorToInt(cy - hy - 1)), iy1 = Mathf.Min(H - 1, Mathf.CeilToInt(cy + hy + 1));
            for (int y = iy0; y <= iy1; y++)
            {
                for (int x = ix0; x <= ix1; x++)
                {
                    float qx = Mathf.Abs(x + 0.5f - cx) - (hx - radius);
                    float qy = Mathf.Abs(y + 0.5f - cy) - (hy - radius);
                    float ox = Mathf.Max(qx, 0f), oy = Mathf.Max(qy, 0f);
                    float d = Mathf.Sqrt(ox * ox + oy * oy) + Mathf.Min(Mathf.Max(qx, qy), 0f) - radius;
                    float cov = Mathf.Clamp01(0.5f - d);
                    if (cov > 0f) Blend(x, y, c, cov * alpha);
                }
            }
        }

        public void FillCircle(float cx, float cy, float r, Color c, float alpha = 1f)
        {
            int x0 = Mathf.Max(0, Mathf.FloorToInt(cx - r - 1)), x1 = Mathf.Min(W - 1, Mathf.CeilToInt(cx + r + 1));
            int y0 = Mathf.Max(0, Mathf.FloorToInt(cy - r - 1)), y1 = Mathf.Min(H - 1, Mathf.CeilToInt(cy + r + 1));
            for (int y = y0; y <= y1; y++)
            {
                for (int x = x0; x <= x1; x++)
                {
                    float dx = x + 0.5f - cx, dy = y + 0.5f - cy;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    float cov = Mathf.Clamp01(r - d + 0.5f);
                    if (cov > 0f) Blend(x, y, c, cov * alpha);
                }
            }
        }

        public void Ring(float cx, float cy, float r, float thickness, Color c, float alpha = 1f)
        {
            int x0 = Mathf.Max(0, Mathf.FloorToInt(cx - r - thickness - 1)), x1 = Mathf.Min(W - 1, Mathf.CeilToInt(cx + r + thickness + 1));
            int y0 = Mathf.Max(0, Mathf.FloorToInt(cy - r - thickness - 1)), y1 = Mathf.Min(H - 1, Mathf.CeilToInt(cy + r + thickness + 1));
            for (int y = y0; y <= y1; y++)
            {
                for (int x = x0; x <= x1; x++)
                {
                    float dx = x + 0.5f - cx, dy = y + 0.5f - cy;
                    float d = Mathf.Abs(Mathf.Sqrt(dx * dx + dy * dy) - r);
                    float cov = Mathf.Clamp01(thickness * 0.5f - d + 0.5f);
                    if (cov > 0f) Blend(x, y, c, cov * alpha);
                }
            }
        }

        public void FillEllipse(float cx, float cy, float rx, float ry, Color c, float alpha = 1f)
        {
            int x0 = Mathf.Max(0, Mathf.FloorToInt(cx - rx - 1)), x1 = Mathf.Min(W - 1, Mathf.CeilToInt(cx + rx + 1));
            int y0 = Mathf.Max(0, Mathf.FloorToInt(cy - ry - 1)), y1 = Mathf.Min(H - 1, Mathf.CeilToInt(cy + ry + 1));
            float rm = Mathf.Min(rx, ry);
            for (int y = y0; y <= y1; y++)
            {
                for (int x = x0; x <= x1; x++)
                {
                    float dx = (x + 0.5f - cx) / rx, dy = (y + 0.5f - cy) / ry;
                    float d = (Mathf.Sqrt(dx * dx + dy * dy) - 1f) * rm;
                    float cov = Mathf.Clamp01(0.5f - d);
                    if (cov > 0f) Blend(x, y, c, cov * alpha);
                }
            }
        }

        public void Line(float ax, float ay, float bx, float by, float width, Color c, float alpha = 1f)
        {
            float minX = Mathf.Min(ax, bx) - width, maxX = Mathf.Max(ax, bx) + width;
            float minY = Mathf.Min(ay, by) - width, maxY = Mathf.Max(ay, by) + width;
            int x0 = Mathf.Max(0, Mathf.FloorToInt(minX)), x1 = Mathf.Min(W - 1, Mathf.CeilToInt(maxX));
            int y0 = Mathf.Max(0, Mathf.FloorToInt(minY)), y1 = Mathf.Min(H - 1, Mathf.CeilToInt(maxY));
            float vx = bx - ax, vy = by - ay;
            float len2 = vx * vx + vy * vy;
            for (int y = y0; y <= y1; y++)
            {
                for (int x = x0; x <= x1; x++)
                {
                    float px = x + 0.5f - ax, py = y + 0.5f - ay;
                    float t = len2 > 1e-6f ? Mathf.Clamp01((px * vx + py * vy) / len2) : 0f;
                    float dx = px - vx * t, dy = py - vy * t;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    float cov = Mathf.Clamp01(width * 0.5f - d + 0.5f);
                    if (cov > 0f) Blend(x, y, c, cov * alpha);
                }
            }
        }

        public void Polyline(Vector2[] pts, float width, Color c)
        {
            for (int i = 0; i < pts.Length - 1; i++) Line(pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, width, c);
        }

        public void VerticalGradient(Color bottom, Color top)
        {
            for (int y = 0; y < H; y++)
            {
                Color c = Color.Lerp(bottom, top, y / (float)(H - 1));
                for (int x = 0; x < W; x++) Px[y * W + x] = c;
            }
        }

        public void DiagonalGradient(Color a, Color b)
        {
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                    Px[y * W + x] = Color.Lerp(a, b, (x / (float)W + y / (float)H) * 0.5f);
        }

        /// <summary>Cœur plein (courbe implicite), centré.</summary>
        public void Heart(float cx, float cy, float size, Color c)
        {
            int x0 = Mathf.Max(0, Mathf.FloorToInt(cx - size * 1.4f)), x1 = Mathf.Min(W - 1, Mathf.CeilToInt(cx + size * 1.4f));
            int y0 = Mathf.Max(0, Mathf.FloorToInt(cy - size * 1.4f)), y1 = Mathf.Min(H - 1, Mathf.CeilToInt(cy + size * 1.4f));
            for (int y = y0; y <= y1; y++)
            {
                for (int x = x0; x <= x1; x++)
                {
                    // super-échantillonnage 2x2 pour l'anti-aliasing
                    float cov = 0f;
                    for (int s = 0; s < 4; s++)
                    {
                        float px = (x + 0.25f + 0.5f * (s & 1) - cx) / size;
                        float py = (y + 0.25f + 0.5f * (s >> 1) - cy) / size;
                        float a = px * px + py * py - 1f;
                        if (a * a * a - px * px * py * py * py <= 0f) cov += 0.25f;
                    }
                    if (cov > 0f) Blend(x, y, c, cov);
                }
            }
        }

        /// <summary>Texte bitmap. (x, y) = coin bas-gauche. scale = taille d'un "pixel" de police.</summary>
        public void Text(string text, int x, int y, int scale, Color c, float alpha = 1f)
        {
            if (string.IsNullOrEmpty(text)) return;
            int cx = x;
            foreach (char ch in text)
            {
                for (int gy = 0; gy < PixelFont.GlyphH; gy++)
                {
                    for (int gx = 0; gx < PixelFont.GlyphW; gx++)
                    {
                        if (!PixelFont.Pixel(ch, gx, gy)) continue;
                        int px = cx + gx * scale;
                        int py = y + (PixelFont.GlyphH - 1 - gy) * scale;
                        FillRect(px, py, px + scale - 1, py + scale - 1, c, alpha);
                    }
                }
                cx += (PixelFont.GlyphW + 1) * scale;
            }
        }

        public void TextCentered(string text, int centerX, int y, int scale, Color c, float alpha = 1f)
        {
            Text(text, centerX - PixelFont.TextWidth(text, scale) / 2, y, scale, c, alpha);
        }

        /// <summary>Lignes grises simulant du texte courant.</summary>
        public void FakeTextLines(int x0, int x1, int yTop, int lines, int lineHeight, int thickness, Color c, int seed, float alpha = 0.85f)
        {
            for (int l = 0; l < lines; l++)
            {
                int y = yTop - l * lineHeight;
                float lenFactor = l == lines - 1 ? 0.45f + 0.3f * Rand01(l, 7, seed) : 0.82f + 0.18f * Rand01(l, 3, seed);
                int end = x0 + Mathf.RoundToInt((x1 - x0) * lenFactor);
                int x = x0;
                int w = 0;
                while (x < end)
                {
                    int wordLen = 6 + Mathf.FloorToInt(Rand01(l, w, seed + 11) * 22f);
                    FillRoundRect(x, y, Mathf.Min(end, x + wordLen), y + thickness, thickness * 0.5f, c, alpha);
                    x += wordLen + thickness + 2;
                    w++;
                }
            }
        }

        public void Noise(float amount, int period, int octaves, int seed)
        {
            for (int y = 0; y < H; y++)
            {
                for (int x = 0; x < W; x++)
                {
                    float n = (Fbm(x / (float)W, y / (float)H, period, octaves, seed) - 0.5f) * 2f * amount;
                    int i = y * W + x;
                    Color c = Px[i];
                    Px[i] = new Color(Mathf.Clamp01(c.r + n), Mathf.Clamp01(c.g + n), Mathf.Clamp01(c.b + n), c.a);
                }
            }
        }

        // ------------------------------------------------------------------ export

        public Color32[] ToColor32()
        {
            var o = new Color32[Px.Length];
            for (int i = 0; i < Px.Length; i++) o[i] = Px[i];
            return o;
        }

        /// <summary>Normal map (espace tangent) depuis la hauteur, encodée RGB (+A=1), pour texture linéaire.</summary>
        public Color32[] NormalMap(float strength)
        {
            var o = new Color32[W * H];
            if (Height == null)
            {
                for (int i = 0; i < o.Length; i++) o[i] = new Color32(128, 128, 255, 255);
                return o;
            }
            for (int y = 0; y < H; y++)
            {
                int yu = (y + 1) % H, yd = (y - 1 + H) % H;
                for (int x = 0; x < W; x++)
                {
                    int xr = (x + 1) % W, xl = (x - 1 + W) % W;
                    float dx = (Height[y * W + xr] - Height[y * W + xl]) * strength;
                    float dy = (Height[yu * W + x] - Height[yd * W + x]) * strength;
                    var n = new Vector3(-dx, -dy, 1f).normalized;
                    o[y * W + x] = new Color32(
                        (byte)Mathf.Clamp(Mathf.RoundToInt((n.x * 0.5f + 0.5f) * 255f), 0, 255),
                        (byte)Mathf.Clamp(Mathf.RoundToInt((n.y * 0.5f + 0.5f) * 255f), 0, 255),
                        (byte)Mathf.Clamp(Mathf.RoundToInt((n.z * 0.5f + 0.5f) * 255f), 0, 255),
                        255);
                }
            }
            return o;
        }
    }
}
