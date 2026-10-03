using System.Collections.Generic;
using UnityEngine;

namespace BlouseBlanche.World
{
    /// <summary>Paire albédo + normal map générée procéduralement.</summary>
    public sealed class SurfaceTextures
    {
        public Texture2D Albedo;
        public Texture2D Normal;
        public float MetersPerTile = 1f;
    }

    /// <summary>
    /// Toutes les textures du jeu, générées au chargement (aucun fichier image).
    /// Les fonctions "Paint*" sont du C# pur ; "Make*" crée les Texture2D.
    /// </summary>
    public sealed class TextureLibrary
    {
        readonly Dictionary<string, SurfaceTextures> surfaces = new Dictionary<string, SurfaceTextures>();
        readonly Dictionary<string, Texture2D> decals = new Dictionary<string, Texture2D>();
        readonly List<Texture2D> owned = new List<Texture2D>();

        public int QualitySize = 1024;

        public SurfaceTextures Surface(string key) => surfaces.TryGetValue(key, out var s) ? s : null;
        public Texture2D Decal(string key) => decals.TryGetValue(key, out var t) ? t : null;

        // ------------------------------------------------------------------ création Texture2D

        Texture2D Create(string name, TexturePainter p, bool linear, TextureWrapMode wrap, int aniso, Color32[] data = null)
        {
            var tex = new Texture2D(p.W, p.H, TextureFormat.RGBA32, true, linear)
            {
                name = name,
                wrapMode = wrap,
                filterMode = FilterMode.Trilinear,
                anisoLevel = aniso
            };
            tex.SetPixels32(data ?? p.ToColor32());
            tex.Apply(true, true);
            owned.Add(tex);
            return tex;
        }

        void AddSurface(string key, TexturePainter p, float normalStrength, float metersPerTile, int aniso = 4)
        {
            var s = new SurfaceTextures
            {
                Albedo = Create(key + "_Albedo", p, false, TextureWrapMode.Repeat, aniso),
                Normal = p.Height != null ? Create(key + "_Normal", p, true, TextureWrapMode.Repeat, aniso, p.NormalMap(normalStrength)) : null,
                MetersPerTile = metersPerTile
            };
            surfaces[key] = s;
        }

        void AddDecal(string key, TexturePainter p)
        {
            decals[key] = Create(key, p, false, TextureWrapMode.Clamp, 4);
        }

        /// <summary>Étapes de génération (exécutées une par frame pendant le chargement).</summary>
        public IEnumerable<string> GenerateAll()
        {
            int big = QualitySize;
            int mid = Mathf.Max(256, big / 2);

            AddSurface("Laminate", PaintLaminate(big, 7), 2.2f, 2.4f, 8); yield return "Parquet";
            AddSurface("Vinyl", PaintVinyl(big, new Color(0.80f, 0.82f, 0.82f), 3), 1.0f, 2f, 8); yield return "Sol vinyle";
            AddSurface("VinylBreak", PaintVinyl(mid, new Color(0.74f, 0.71f, 0.66f), 5), 1.0f, 2f, 8); yield return "Sol salle de pause";
            AddSurface("Paint", PaintWall(mid, new Color(0.93f, 0.92f, 0.89f), 11), 1.2f, 2f); yield return "Peinture";
            AddSurface("Ceiling", PaintCeiling(mid), 2.0f, 1.2f); yield return "Plafond";
            AddSurface("Fabric", PaintFabric(mid, 13), 1.6f, 0.35f); yield return "Tissus";
            AddSurface("Leather", PaintLeather(mid, 17), 1.4f, 0.4f); yield return "Similicuir";
            AddSurface("Metal", PaintBrushedMetal(mid, 19), 0.6f, 0.5f); yield return "Métal brossé";
            AddSurface("Oak", PaintVeneer(mid, new Color(0.72f, 0.56f, 0.39f), new Color(0.55f, 0.40f, 0.26f), 23), 1.2f, 1.0f); yield return "Chêne";
            AddSurface("Walnut", PaintVeneer(mid, new Color(0.45f, 0.31f, 0.21f), new Color(0.30f, 0.19f, 0.12f), 29), 1.2f, 1.0f); yield return "Noyer";
            AddSurface("Tiles", PaintTiles(mid, 8, new Color(0.95f, 0.96f, 0.96f), new Color(0.72f, 0.74f, 0.75f), 31), 3f, 1.2f); yield return "Faïence";
            AddSurface("Plaster", PaintWall(mid, new Color(0.90f, 0.86f, 0.79f), 37, 0.06f), 2.5f, 3f); yield return "Enduit";
            AddSurface("Grass", PaintGrass(mid, 41), 2f, 3f, 8); yield return "Gazon";
            AddSurface("Asphalt", PaintAsphalt(mid, 43), 2f, 4f, 8); yield return "Bitume";
            AddSurface("Paving", PaintPaving(mid, 47), 3f, 1.2f, 8); yield return "Trottoir";
            AddSurface("Brick", PaintBrick(mid, 53), 3f, 1.6f); yield return "Briques";
            AddSurface("Mat", PaintMat(256, 59), 3f, 0.5f); yield return "Tapis";

            AddDecal("PosterHeart", PaintPosterHeart(384, 544)); yield return "Affiches";
            AddDecal("PosterHands", PaintPosterHands(384, 544));
            AddDecal("PosterVaccine", PaintPosterVaccine(384, 544));
            AddDecal("PosterLungs", PaintPosterLungs(384, 544)); yield return "Affiches";
            AddDecal("PosterAnatomy", PaintPosterAnatomy(384, 544));
            AddDecal("Diploma", PaintDiploma(512, 384, "DOCTEUR EN MEDECINE", 61));
            AddDecal("Diploma2", PaintDiploma(512, 384, "MEDECINE GENERALE", 67));
            AddDecal("KidsDrawing", PaintKidsDrawing(384, 288)); yield return "Décoration";
            AddDecal("Monitor", PaintMonitorScreen(512, 320)); yield return "Écrans";
            AddDecal("MonitorReception", PaintMonitorScreen(512, 320, true));
            AddDecal("Tv", PaintTvScreen(512, 288));
            AddDecal("ClockFace", PaintClockFace(256));
            AddDecal("Calendar", PaintCalendar(320, 448));
            AddDecal("SignConsult", PaintDoorSign(512, 160, "CONSULTATION", "DR. MARTIN"));
            AddDecal("SignBreak", PaintDoorSign(512, 160, "SALLE DE PAUSE", "PRIVE"));
            AddDecal("SignWc", PaintDoorSign(512, 160, "WC", "PATIENTS"));
            AddDecal("SignReception", PaintDoorSign(512, 160, "ACCUEIL", "SECRETARIAT"));
            AddDecal("SignWaiting", PaintDoorSign(512, 160, "SALLE D'ATTENTE", "MERCI DE PATIENTER"));
            AddDecal("ClinicSign", PaintClinicSign(768, 192)); yield return "Signalétique";
            for (int i = 0; i < 6; i++) AddDecal("Magazine" + i, PaintMagazine(192, 256, i));
            AddDecal("Paper", PaintPaper(256, 362, 71));
            AddDecal("Prescription", PaintPrescription(256, 362));
            AddDecal("Leaf", PaintLeaf(128, 256)); yield return "Détails";
            for (int i = 0; i < 3; i++) AddDecal("Art" + i, PaintArt(384, 288, i));
            AddDecal("ScopeScreen", PaintScopeScreen(512, 320));
            AddDecal("FamilyPhoto", PaintFamilyPhoto(256, 192));
            AddDecal("SignBox", PaintDoorSign(512, 160, "BOX 3", "URGENCES ADULTES"));
            AddSurface("Wallpaper", PaintWallpaper(mid, 83), 1.0f, 1.2f); yield return "Salon et urgences";
        }

        public void Dispose()
        {
            foreach (var t in owned) if (t != null) Object.Destroy(t);
            owned.Clear();
            surfaces.Clear();
            decals.Clear();
        }

        // ================================================================== Surfaces (C# pur)

        public static TexturePainter PaintLaminate(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.white, true);
            const float tileMeters = 2.4f, plankW = 0.2f, plankL = 1.2f;
            int rows = Mathf.RoundToInt(tileMeters / plankW);
            var offsets = new float[rows];
            for (int r = 0; r < rows; r++) offsets[r] = Mathf.Floor(TexturePainter.Rand01(r, 1, seed) * 6f) * 0.2f;
            Color light = new Color(0.76f, 0.60f, 0.42f), dark = new Color(0.56f, 0.41f, 0.27f);
            float seamU = 1.6f / size * tileMeters * 1.2f;
            for (int y = 0; y < size; y++)
            {
                float my = (y + 0.5f) / size * tileMeters;
                int row = Mathf.Min(rows - 1, Mathf.FloorToInt(my / plankW));
                float ly = my - row * plankW;
                for (int x = 0; x < size; x++)
                {
                    float mx = (x + 0.5f) / size * tileMeters;
                    float sx = Mathf.Repeat(mx + offsets[row], tileMeters);
                    int col = Mathf.FloorToInt(sx / plankL);
                    float lx = sx - col * plankL;
                    int plank = row * 4 + col;
                    float tint = 0.88f + 0.22f * TexturePainter.Rand01(plank, 5, seed);
                    float hueShift = (TexturePainter.Rand01(plank, 9, seed) - 0.5f) * 0.06f;

                    float u = x / (float)size, v = y / (float)size;
                    float grain = TexturePainter.FbmAniso(u + plank * 0.37f, v, 2, 48, 4, seed + plank);
                    float rings = Mathf.Sin((v * 160f + grain * 9f + plank * 1.7f) * Mathf.PI) * 0.5f + 0.5f;
                    float fine = TexturePainter.FbmAniso(u, v, 8, 256, 2, seed + 3);
                    float t = Mathf.Clamp01(grain * 0.55f + rings * 0.3f + fine * 0.25f);
                    Color c = Color.Lerp(light, dark, t) * tint;
                    c.r += hueShift; c.b -= hueShift * 0.5f;

                    float h = 0.5f + (fine - 0.5f) * 0.25f + (rings - 0.5f) * 0.08f;
                    float edgeY = Mathf.Min(ly, plankW - ly);
                    float edgeX = Mathf.Min(lx, plankL - lx);
                    float seam = Mathf.Min(edgeY / (plankW * 0.012f), edgeX / seamU);
                    if (seam < 1f)
                    {
                        float k = 1f - seam;
                        c = Color.Lerp(c, c * 0.45f, k);
                        h -= 0.6f * k;
                    }
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = h;
                }
            }
            return p;
        }

        public static TexturePainter PaintVinyl(int size, Color baseColor, int seed)
        {
            var p = new TexturePainter(size, size, baseColor, true);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float cloud = TexturePainter.Fbm(u, v, 4, 4, seed);
                    Color c = baseColor * (0.95f + cloud * 0.1f);
                    int cx = x / 3, cy = y / 3;
                    float r = TexturePainter.Rand01(cx, cy, seed + 1);
                    if (r < 0.035f) c = Color.Lerp(c, baseColor * 0.55f, 0.85f);
                    else if (r < 0.06f) c = Color.Lerp(c, Color.white, 0.6f);
                    else if (r < 0.064f) c = Color.Lerp(c, new Color(0.25f, 0.55f, 0.6f), 0.7f);
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = TexturePainter.Fbm(u, v, 64, 2, seed + 2) * 0.3f;
                }
            }
            return p;
        }

        public static TexturePainter PaintWall(int size, Color baseColor, int seed, float variation = 0.025f)
        {
            var p = new TexturePainter(size, size, baseColor, true);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float n = TexturePainter.Fbm(u, v, 6, 5, seed);
                    Color c = baseColor * (1f - variation + n * variation * 2f);
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = TexturePainter.Fbm(u, v, 48, 3, seed + 5) * 0.5f + n * 0.2f;
                }
            }
            return p;
        }

        public static TexturePainter PaintCeiling(int size)
        {
            var p = new TexturePainter(size, size, Color.white, true);
            const float tileM = 1.2f, cell = 0.6f, bar = 0.024f;
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float mx = (x + 0.5f) / size * tileM, my = (y + 0.5f) / size * tileM;
                    float lx = Mathf.Repeat(mx, cell), ly = Mathf.Repeat(my, cell);
                    float dEdge = Mathf.Min(Mathf.Min(lx, cell - lx), Mathf.Min(ly, cell - ly));
                    float u = x / (float)size, v = y / (float)size;
                    Color c;
                    float h;
                    if (dEdge < bar * 0.5f)
                    {
                        c = new Color(0.9f, 0.9f, 0.89f);
                        h = 1f;
                    }
                    else
                    {
                        float n = TexturePainter.Fbm(u, v, 32, 3, 77);
                        bool pit = TexturePainter.Rand01(x / 2, y / 2, 78) < 0.05f;
                        c = new Color(0.94f, 0.94f, 0.92f) * (0.94f + n * 0.08f);
                        if (pit) c *= 0.82f;
                        h = 0.55f + n * 0.25f - (pit ? 0.3f : 0f);
                        if (dEdge < bar) { c *= 0.9f; h -= 0.25f; }
                    }
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = h;
                }
            }
            return p;
        }

        public static TexturePainter PaintFabric(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.white, true);
            const int threads = 96;
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float wx = Mathf.Sin(u * threads * Mathf.PI * 2f), wy = Mathf.Sin(v * threads * Mathf.PI * 2f);
                    bool over = ((Mathf.FloorToInt(u * threads) + Mathf.FloorToInt(v * threads)) & 1) == 0;
                    float weave = over ? Mathf.Abs(wx) : Mathf.Abs(wy);
                    float n = TexturePainter.Fbm(u, v, 8, 4, seed);
                    float g = 0.78f + weave * 0.12f + (n - 0.5f) * 0.12f;
                    p.Px[y * size + x] = new Color(g, g, g, 1f);
                    p.Height[y * size + x] = weave * 0.6f + n * 0.2f;
                }
            }
            return p;
        }

        public static TexturePainter PaintLeather(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.white, true);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float n1 = TexturePainter.Fbm(u, v, 24, 3, seed);
                    float n2 = TexturePainter.Fbm(u, v, 6, 3, seed + 1);
                    float cells = Mathf.Abs(n1 - 0.5f) * 2f;
                    float g = 0.86f + (n2 - 0.5f) * 0.08f - cells * 0.05f;
                    p.Px[y * size + x] = new Color(g, g, g, 1f);
                    p.Height[y * size + x] = 1f - cells;
                }
            }
            return p;
        }

        public static TexturePainter PaintBrushedMetal(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.white, true);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float s = TexturePainter.FbmAniso(u, v, 2, 256, 3, seed);
                    float g = 0.82f + (s - 0.5f) * 0.12f;
                    p.Px[y * size + x] = new Color(g, g, g * 1.01f, 1f);
                    p.Height[y * size + x] = s * 0.3f;
                }
            }
            return p;
        }

        public static TexturePainter PaintVeneer(int size, Color light, Color dark, int seed)
        {
            var p = new TexturePainter(size, size, light, true);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float g = TexturePainter.FbmAniso(u, v, 2, 24, 4, seed);
                    float rings = Mathf.Sin((v * 40f + g * 6f) * Mathf.PI * 2f) * 0.5f + 0.5f;
                    float pores = TexturePainter.FbmAniso(u, v, 16, 192, 2, seed + 9);
                    float t = Mathf.Clamp01(g * 0.5f + Mathf.Pow(rings, 3f) * 0.35f + pores * 0.2f);
                    Color c = Color.Lerp(light, dark, t);
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = pores * 0.3f + rings * 0.1f;
                }
            }
            return p;
        }

        public static TexturePainter PaintTiles(int size, int perSide, Color tile, Color grout, int seed)
        {
            var p = new TexturePainter(size, size, tile, true);
            float cell = size / (float)perSide;
            float groutPx = Mathf.Max(1.5f, cell * 0.05f);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float lx = Mathf.Repeat(x + 0.5f, cell), ly = Mathf.Repeat(y + 0.5f, cell);
                    float d = Mathf.Min(Mathf.Min(lx, cell - lx), Mathf.Min(ly, cell - ly));
                    int id = Mathf.FloorToInt(x / cell) + Mathf.FloorToInt(y / cell) * 31;
                    float tint = 0.97f + TexturePainter.Rand01(id, 3, seed) * 0.05f;
                    Color c;
                    float h;
                    if (d < groutPx * 0.5f) { c = grout; h = 0f; }
                    else
                    {
                        float bevel = Mathf.Clamp01((d - groutPx * 0.5f) / (groutPx * 1.5f));
                        c = tile * tint;
                        h = 0.4f + 0.6f * bevel;
                    }
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = h;
                }
            }
            return p;
        }

        public static TexturePainter PaintGrass(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.green, true);
            Color a = new Color(0.20f, 0.33f, 0.12f), b = new Color(0.36f, 0.48f, 0.19f), dry = new Color(0.50f, 0.50f, 0.28f);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float n = TexturePainter.Fbm(u, v, 4, 4, seed);
                    float blades = TexturePainter.FbmAniso(u, v, 96, 32, 2, seed + 4);
                    Color c = Color.Lerp(a, b, Mathf.Clamp01(n * 0.7f + blades * 0.5f));
                    float patch = TexturePainter.Fbm(u, v, 3, 3, seed + 8);
                    if (patch > 0.62f) c = Color.Lerp(c, dry, (patch - 0.62f) * 2f);
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = blades;
                }
            }
            return p;
        }

        public static TexturePainter PaintAsphalt(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.gray, true);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float n = TexturePainter.Fbm(u, v, 8, 4, seed);
                    float stone = TexturePainter.Rand01(x / 2, y / 2, seed + 2);
                    float g = 0.17f + n * 0.07f + (stone > 0.92f ? 0.08f : 0f) - (stone < 0.05f ? 0.04f : 0f);
                    p.Px[y * size + x] = new Color(g, g, g * 1.03f, 1f);
                    p.Height[y * size + x] = stone * 0.4f + n * 0.3f;
                }
            }
            return p;
        }

        public static TexturePainter PaintPaving(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.gray, true);
            float cell = size / 2f;
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float lx = Mathf.Repeat(x + 0.5f, cell), ly = Mathf.Repeat(y + 0.5f, cell);
                    float d = Mathf.Min(Mathf.Min(lx, cell - lx), Mathf.Min(ly, cell - ly));
                    float n = TexturePainter.Fbm(u, v, 8, 4, seed);
                    int id = Mathf.FloorToInt(x / cell) + Mathf.FloorToInt(y / cell) * 7;
                    float g = 0.62f + n * 0.1f + (TexturePainter.Rand01(id, 1, seed) - 0.5f) * 0.06f;
                    float h = 0.6f + n * 0.3f;
                    if (d < 2.5f) { g *= 0.55f; h = 0f; }
                    p.Px[y * size + x] = new Color(g, g * 0.99f, g * 0.97f, 1f);
                    p.Height[y * size + x] = h;
                }
            }
            return p;
        }

        public static TexturePainter PaintBrick(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.red, true);
            int rows = 16;
            float rowH = size / (float)rows, brickW = size / 4f;
            for (int y = 0; y < size; y++)
            {
                int row = Mathf.FloorToInt(y / rowH);
                float ly = y - row * rowH;
                for (int x = 0; x < size; x++)
                {
                    float sx = Mathf.Repeat(x + (row % 2 == 0 ? 0f : brickW * 0.5f), size);
                    int col = Mathf.FloorToInt(sx / brickW);
                    float lx = sx - col * brickW;
                    float d = Mathf.Min(Mathf.Min(lx, brickW - lx), Mathf.Min(ly, rowH - ly));
                    float u = x / (float)size, v = y / (float)size;
                    float n = TexturePainter.Fbm(u, v, 16, 3, seed);
                    float tint = TexturePainter.Rand01(col + row * 9, 2, seed);
                    Color c = Color.Lerp(new Color(0.62f, 0.30f, 0.22f), new Color(0.74f, 0.42f, 0.30f), tint) * (0.9f + n * 0.2f);
                    float h = 0.7f + n * 0.3f;
                    if (d < 2f) { c = new Color(0.72f, 0.70f, 0.66f); h = 0f; }
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = h;
                }
            }
            return p;
        }

        public static TexturePainter PaintMat(int size, int seed)
        {
            var p = new TexturePainter(size, size, Color.gray, true);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float rib = Mathf.Abs(Mathf.Sin(y / (float)size * Mathf.PI * 24f));
                    float n = TexturePainter.Fbm(x / (float)size, y / (float)size, 16, 3, seed);
                    float g = 0.16f + rib * 0.05f + n * 0.04f;
                    p.Px[y * size + x] = new Color(g, g * 1.02f, g * 1.08f, 1f);
                    p.Height[y * size + x] = rib;
                }
            }
            return p;
        }

        // ================================================================== Affiches & décors (C# pur)

        static readonly Color Navy = new Color(0.07f, 0.13f, 0.24f);
        static readonly Color Teal = new Color(0.12f, 0.72f, 0.66f);
        static readonly Color Paper = new Color(0.97f, 0.96f, 0.93f);
        static readonly Color Ink = new Color(0.16f, 0.19f, 0.25f);

        public static TexturePainter PaintPosterHeart(int w, int h)
        {
            var p = new TexturePainter(w, h, Navy);
            p.VerticalGradient(new Color(0.05f, 0.16f, 0.30f), new Color(0.06f, 0.42f, 0.47f));
            p.Heart(w * 0.5f, h * 0.55f, w * 0.26f, new Color(0.92f, 0.24f, 0.30f));
            p.FillEllipse(w * 0.42f, h * 0.64f, w * 0.05f, w * 0.03f, new Color(1f, 0.55f, 0.55f), 0.7f);
            float y0 = h * 0.42f;
            var ecg = new[]
            {
                new Vector2(0, y0), new Vector2(w * 0.25f, y0), new Vector2(w * 0.3f, y0 + 14), new Vector2(w * 0.34f, y0 - 10),
                new Vector2(w * 0.4f, y0 + 70), new Vector2(w * 0.46f, y0 - 44), new Vector2(w * 0.5f, y0), new Vector2(w * 0.62f, y0),
                new Vector2(w * 0.68f, y0 + 18), new Vector2(w * 0.74f, y0), new Vector2(w, y0)
            };
            p.Polyline(ecg, 5f, Color.white);
            p.TextCentered("PREVENTION", w / 2, h - 70, 6, Color.white);
            p.TextCentered("CARDIO-VASCULAIRE", w / 2, h - 110, 3, new Color(0.7f, 0.95f, 0.9f));
            p.FakeTextLines(36, w - 36, 120, 4, 18, 6, new Color(1f, 1f, 1f, 1f), 3, 0.55f);
            p.FillRect(0, 0, w - 1, 40, Teal);
            p.TextCentered("MOUVEZ-VOUS 30 MIN PAR JOUR", w / 2, 13, 2, Navy);
            return p;
        }

        public static TexturePainter PaintPosterHands(int w, int h)
        {
            var p = new TexturePainter(w, h, Paper);
            p.FillRect(0, h - 96, w - 1, h - 1, new Color(0.15f, 0.47f, 0.80f));
            p.TextCentered("LAVAGE", w / 2, h - 48, 5, Color.white);
            p.TextCentered("DES MAINS", w / 2, h - 84, 4, Color.white);
            int cols = 2, rows = 3;
            float cw = w / (float)cols, ch = (h - 150) / (float)rows;
            for (int r = 0; r < rows; r++)
            {
                for (int c = 0; c < cols; c++)
                {
                    float cx = cw * (c + 0.5f), cy = h - 120 - ch * (r + 0.5f);
                    p.FillCircle(cx, cy, Mathf.Min(cw, ch) * 0.36f, new Color(0.82f, 0.92f, 0.98f));
                    p.FillEllipse(cx - 12, cy, 22, 34, new Color(0.96f, 0.80f, 0.68f));
                    p.FillEllipse(cx + 14, cy + 4, 22, 34, new Color(0.93f, 0.75f, 0.62f));
                    for (int d = 0; d < 3; d++) p.FillCircle(cx - 30 + d * 30, cy + 42, 5, new Color(0.3f, 0.65f, 0.95f));
                    p.Text((r * cols + c + 1).ToString(), (int)(cx - cw * 0.4f), (int)(cy + ch * 0.25f), 4, new Color(0.15f, 0.47f, 0.80f));
                }
            }
            p.TextCentered("30 SECONDES", w / 2, 18, 3, Ink);
            return p;
        }

        public static TexturePainter PaintPosterVaccine(int w, int h)
        {
            var p = new TexturePainter(w, h, new Color(0.98f, 0.94f, 0.86f));
            p.FillRect(0, h - 110, w - 1, h - 1, new Color(0.96f, 0.55f, 0.25f));
            p.TextCentered("VACCINATION", w / 2, h - 60, 5, Color.white);
            p.TextCentered("PROTEGEONS-NOUS", w / 2, h - 96, 3, Color.white);
            // seringue stylisée
            float cy = h * 0.58f;
            p.FillRoundRect(w * 0.22f, cy - 22, w * 0.68f, cy + 22, 8, new Color(0.85f, 0.93f, 0.98f));
            p.FillRect((int)(w * 0.26f), (int)(cy - 14), (int)(w * 0.5f), (int)(cy + 14), new Color(0.35f, 0.7f, 0.95f));
            p.FillRect((int)(w * 0.68f), (int)(cy - 6), (int)(w * 0.8f), (int)(cy + 6), new Color(0.6f, 0.65f, 0.7f));
            p.Line(w * 0.8f, cy, w * 0.9f, cy, 2f, new Color(0.5f, 0.55f, 0.6f));
            p.FillRect((int)(w * 0.12f), (int)(cy - 30), (int)(w * 0.16f), (int)(cy + 30), new Color(0.6f, 0.65f, 0.7f));
            p.FillRect((int)(w * 0.16f), (int)(cy - 5), (int)(w * 0.22f), (int)(cy + 5), new Color(0.6f, 0.65f, 0.7f));
            // calendrier
            for (int r = 0; r < 3; r++)
                for (int c = 0; c < 4; c++)
                {
                    float x0 = 40 + c * ((w - 80) / 4f), y0 = 60 + r * 46;
                    bool on = (r * 4 + c) % 3 == 0;
                    p.FillRoundRect(x0 + 4, y0, x0 + (w - 80) / 4f - 4, y0 + 38, 6, on ? new Color(0.96f, 0.55f, 0.25f) : new Color(0.9f, 0.86f, 0.78f));
                }
            return p;
        }

        public static TexturePainter PaintPosterLungs(int w, int h)
        {
            var p = new TexturePainter(w, h, Navy);
            p.VerticalGradient(new Color(0.10f, 0.08f, 0.20f), new Color(0.20f, 0.18f, 0.40f));
            p.TextCentered("STOP TABAC", w / 2, h - 66, 6, Color.white);
            float cx = w * 0.5f, cy = h * 0.5f;
            p.FillEllipse(cx - 62, cy, 52, 104, new Color(0.95f, 0.55f, 0.62f));
            p.FillEllipse(cx + 62, cy, 52, 104, new Color(0.95f, 0.55f, 0.62f));
            p.FillRect((int)cx - 6, (int)cy + 40, (int)cx + 6, (int)cy + 130, new Color(0.85f, 0.85f, 0.9f));
            p.Line(cx, cy + 40, cx - 40, cy + 10, 8, new Color(0.85f, 0.85f, 0.9f));
            p.Line(cx, cy + 40, cx + 40, cy + 10, 8, new Color(0.85f, 0.85f, 0.9f));
            p.Ring(w * 0.78f, h * 0.24f, 44, 10, new Color(0.95f, 0.25f, 0.3f));
            p.Line(w * 0.78f - 30, h * 0.24f - 30, w * 0.78f + 30, h * 0.24f + 30, 10, new Color(0.95f, 0.25f, 0.3f));
            p.TextCentered("TABAC INFO SERVICE 39 89", w / 2, 30, 2, new Color(0.8f, 0.8f, 0.95f));
            return p;
        }

        public static TexturePainter PaintPosterAnatomy(int w, int h)
        {
            var p = new TexturePainter(w, h, Paper);
            p.TextCentered("ANATOMIE", w / 2, h - 50, 5, Ink);
            float cx = w * 0.5f;
            Color skin = new Color(0.94f, 0.80f, 0.70f), bone = new Color(0.97f, 0.95f, 0.88f), organ = new Color(0.86f, 0.36f, 0.38f);
            p.FillCircle(cx, h - 120, 34, skin);
            p.FillRoundRect(cx - 62, h * 0.38f, cx + 62, h - 160, 28, skin);
            p.FillRoundRect(cx - 100, h * 0.42f, cx - 70, h - 170, 14, skin);
            p.FillRoundRect(cx + 70, h * 0.42f, cx + 100, h - 170, 14, skin);
            p.FillRoundRect(cx - 52, 40, cx - 10, h * 0.40f, 16, skin);
            p.FillRoundRect(cx + 10, 40, cx + 52, h * 0.40f, 16, skin);
            for (int i = 0; i < 6; i++) p.Line(cx - 40, h - 190 - i * 18, cx + 40, h - 190 - i * 18, 4, bone, 0.9f);
            p.Line(cx, h - 165, cx, h * 0.42f, 6, bone);
            p.Heart(cx - 14, h - 230, 14, organ);
            p.FillEllipse(cx + 12, h * 0.52f, 30, 18, new Color(0.65f, 0.30f, 0.25f));
            p.FakeTextLines(30, 120, h - 180, 5, 22, 5, Ink, 9, 0.6f);
            p.FakeTextLines(w - 120, w - 30, h - 260, 5, 22, 5, Ink, 13, 0.6f);
            return p;
        }

        public static TexturePainter PaintDiploma(int w, int h, string title, int seed)
        {
            var p = new TexturePainter(w, h, new Color(0.98f, 0.95f, 0.86f));
            p.Noise(0.02f, 8, 3, seed);
            Color gold = new Color(0.68f, 0.55f, 0.28f);
            p.FillRect(12, 12, w - 13, 15, gold);
            p.FillRect(12, h - 16, w - 13, h - 13, gold);
            p.FillRect(12, 12, 15, h - 13, gold);
            p.FillRect(w - 16, 12, w - 13, h - 13, gold);
            p.TextCentered("REPUBLIQUE FRANCAISE", w / 2, h - 52, 2, Ink);
            p.TextCentered("DIPLOME D'ETAT", w / 2, h - 96, 4, Ink);
            p.TextCentered(title, w / 2, h - 140, 3, new Color(0.15f, 0.22f, 0.42f));
            p.FakeTextLines(60, w - 60, h - 180, 4, 20, 4, Ink, seed, 0.55f);
            p.FillCircle(w - 90, 80, 38, new Color(0.72f, 0.12f, 0.15f));
            p.Ring(w - 90, 80, 30, 3, new Color(0.95f, 0.75f, 0.4f));
            var sig = new Vector2[12];
            for (int i = 0; i < sig.Length; i++) sig[i] = new Vector2(70 + i * 12, 70 + Mathf.Sin(i * 1.7f + seed) * 10f);
            p.Polyline(sig, 2f, new Color(0.1f, 0.15f, 0.4f));
            return p;
        }

        public static TexturePainter PaintKidsDrawing(int w, int h)
        {
            var p = new TexturePainter(w, h, Color.white);
            p.FillRect(0, 0, w - 1, 60, new Color(0.35f, 0.75f, 0.3f));
            p.FillCircle(w * 0.8f, h * 0.78f, 34, new Color(1f, 0.85f, 0.15f));
            for (int i = 0; i < 10; i++)
            {
                float a = i / 10f * Mathf.PI * 2f;
                p.Line(w * 0.8f + Mathf.Cos(a) * 42, h * 0.78f + Mathf.Sin(a) * 42, w * 0.8f + Mathf.Cos(a) * 60, h * 0.78f + Mathf.Sin(a) * 60, 4, new Color(1f, 0.8f, 0.1f));
            }
            p.FillRect((int)(w * 0.2f), 60, (int)(w * 0.48f), (int)(h * 0.52f), new Color(0.95f, 0.6f, 0.3f));
            for (int y = (int)(h * 0.52f); y < (int)(h * 0.75f); y++)
            {
                float t = (y - h * 0.52f) / (h * 0.23f);
                p.FillRect((int)(w * 0.17f + t * w * 0.14f), y, (int)(w * 0.51f - t * w * 0.14f), y, new Color(0.85f, 0.2f, 0.2f));
            }
            p.FillRect((int)(w * 0.3f), 60, (int)(w * 0.37f), 130, new Color(0.5f, 0.3f, 0.15f));
            p.FillCircle(w * 0.62f, 150, 14, new Color(0.2f, 0.2f, 0.2f));
            p.Line(w * 0.62f, 136, w * 0.62f, 90, 4, new Color(0.2f, 0.2f, 0.2f));
            p.Line(w * 0.62f, 90, w * 0.59f, 62, 4, new Color(0.2f, 0.2f, 0.2f));
            p.Line(w * 0.62f, 90, w * 0.65f, 62, 4, new Color(0.2f, 0.2f, 0.2f));
            p.Line(w * 0.57f, 118, w * 0.67f, 118, 4, new Color(0.2f, 0.2f, 0.2f));
            p.Text("MERCI DOCTEUR", 20, h - 34, 2, new Color(0.3f, 0.3f, 0.85f));
            return p;
        }

        public static TexturePainter PaintMonitorScreen(int w, int h, bool reception = false)
        {
            var p = new TexturePainter(w, h, new Color(0.06f, 0.09f, 0.15f));
            Color bar = reception ? new Color(0.25f, 0.45f, 0.95f) : Teal;
            p.FillRect(0, h - 30, w - 1, h - 1, bar);
            p.Text(reception ? "SECRETARIAT - PLANNING" : "DOSSIER MEDICAL - AGENDA", 10, h - 22, 2, Navy);
            p.FillRect(0, 0, 90, h - 31, new Color(0.09f, 0.13f, 0.21f));
            for (int i = 0; i < 6; i++) p.FillRoundRect(10, h - 60 - i * 28, 80, h - 44 - i * 28, 4, i == 1 ? bar : new Color(0.16f, 0.21f, 0.31f));
            string[] times = { "08:30", "09:00", "09:45", "10:30", "11:00", "11:30", "14:00", "14:30" };
            for (int r = 0; r < times.Length; r++)
            {
                int y = h - 62 - r * 30;
                p.FillRect(100, y - 6, w - 12, y + 18, r % 2 == 0 ? new Color(0.09f, 0.13f, 0.21f) : new Color(0.07f, 0.10f, 0.17f));
                p.Text(times[r], 108, y, 2, new Color(0.7f, 0.85f, 0.95f));
                p.FillRoundRect(180, y + 2, 180 + 60 + (r * 37 % 110), y + 10, 4, new Color(0.55f, 0.62f, 0.72f), 0.8f);
                p.FillRoundRect(w - 70, y, w - 20, y + 12, 6, r < 2 ? new Color(0.24f, 0.86f, 0.59f) : new Color(0.98f, 0.71f, 0.28f), 0.9f);
            }
            return p;
        }

        public static TexturePainter PaintTvScreen(int w, int h)
        {
            var p = new TexturePainter(w, h, Navy);
            p.DiagonalGradient(new Color(0.04f, 0.20f, 0.32f), new Color(0.05f, 0.45f, 0.50f));
            p.Heart(w * 0.2f, h * 0.55f, 46, new Color(0.95f, 0.3f, 0.35f));
            p.Text("BIENVENUE", (int)(w * 0.36f), (int)(h * 0.62f), 5, Color.white);
            p.Text("CABINET DES TILLEULS", (int)(w * 0.36f), (int)(h * 0.47f), 2, new Color(0.75f, 0.95f, 0.92f));
            p.FillRect(0, 0, w - 1, 36, new Color(0f, 0f, 0f, 1f), 0.35f);
            p.Text("PENSEZ A VOTRE CARTE VITALE", 16, 12, 2, Color.white);
            return p;
        }

        public static TexturePainter PaintClockFace(int size)
        {
            var p = new TexturePainter(size, size, new Color(0.2f, 0.22f, 0.25f));
            float c = size * 0.5f;
            p.FillCircle(c, c, size * 0.49f, new Color(0.97f, 0.97f, 0.96f));
            for (int i = 0; i < 60; i++)
            {
                float a = i / 60f * Mathf.PI * 2f;
                float r0 = i % 5 == 0 ? size * 0.36f : size * 0.42f;
                float wdt = i % 5 == 0 ? 5f : 2f;
                p.Line(c + Mathf.Sin(a) * r0, c + Mathf.Cos(a) * r0, c + Mathf.Sin(a) * size * 0.46f, c + Mathf.Cos(a) * size * 0.46f, wdt, Ink);
            }
            p.TextCentered("12", (int)c, (int)(c + size * 0.24f), 3, Ink);
            return p;
        }

        public static TexturePainter PaintCalendar(int w, int h)
        {
            var p = new TexturePainter(w, h, Color.white);
            p.FillRect(0, h - 90, w - 1, h - 1, new Color(0.85f, 0.25f, 0.3f));
            p.TextCentered("OCTOBRE 2026", w / 2, h - 58, 3, Color.white);
            string[] days = { "L", "M", "M", "J", "V", "S", "D" };
            float cw = (w - 20) / 7f;
            for (int d = 0; d < 7; d++) p.Text(days[d], (int)(10 + d * cw + cw * 0.3f), h - 120, 2, Ink);
            int day = 1;
            for (int r = 0; r < 5; r++)
                for (int c = 0; c < 7; c++)
                {
                    if (r == 0 && c < 3) continue;
                    if (day > 31) break;
                    int x = (int)(10 + c * cw + 4), y = h - 160 - r * 52;
                    p.Text(day.ToString(), x, y, 2, c >= 5 ? new Color(0.85f, 0.25f, 0.3f) : Ink);
                    day++;
                }
            return p;
        }

        public static TexturePainter PaintDoorSign(int w, int h, string title, string subtitle)
        {
            var p = new TexturePainter(w, h, new Color(0.96f, 0.97f, 0.97f));
            p.FillRect(0, 0, 18, h - 1, Teal);
            int scale = PixelFont.TextWidth(title, 6) < w - 60 ? 6 : 4;
            p.Text(title, 40, h / 2 + 4, scale, Navy);
            p.Text(subtitle, 40, 26, 2, new Color(0.4f, 0.45f, 0.52f));
            return p;
        }

        public static TexturePainter PaintClinicSign(int w, int h)
        {
            var p = new TexturePainter(w, h, Navy);
            p.FillRoundRect(26, 36, 146, 156, 18, Teal);
            p.FillRect(74, 56, 98, 136, Color.white);
            p.FillRect(46, 84, 126, 108, Color.white);
            p.Text("CABINET MEDICAL", 180, 110, 6, Color.white);
            p.Text("DES TILLEULS - MEDECINE GENERALE", 182, 52, 2, new Color(0.65f, 0.9f, 0.88f));
            return p;
        }

        public static TexturePainter PaintMagazine(int w, int h, int seed)
        {
            Color[] palette =
            {
                new Color(0.9f, 0.3f, 0.3f), new Color(0.2f, 0.5f, 0.85f), new Color(0.95f, 0.75f, 0.2f),
                new Color(0.3f, 0.7f, 0.45f), new Color(0.6f, 0.35f, 0.75f), new Color(0.95f, 0.5f, 0.2f)
            };
            string[] titles = { "SANTE", "MAISON", "SPORT", "VOYAGE", "CUISINE", "JARDIN" };
            Color bg = palette[seed % palette.Length];
            var p = new TexturePainter(w, h, Color.white);
            p.VerticalGradient(bg * 0.75f, bg);
            p.FillRoundRect(16, 30, w - 16, h - 70, 6, Color.Lerp(bg, Color.white, 0.45f));
            p.FillCircle(w * 0.5f, h * 0.48f, w * 0.22f, Color.Lerp(bg, Color.white, 0.75f));
            p.TextCentered(titles[seed % titles.Length], w / 2, h - 48, 4, Color.white);
            p.FakeTextLines(16, w - 16, 20, 1, 10, 4, Color.white, seed, 0.8f);
            return p;
        }

        public static TexturePainter PaintPaper(int w, int h, int seed)
        {
            var p = new TexturePainter(w, h, new Color(0.97f, 0.97f, 0.95f));
            p.FakeTextLines(24, w - 24, h - 40, 14, 20, 4, Ink, seed, 0.55f);
            return p;
        }

        public static TexturePainter PaintPrescription(int w, int h)
        {
            var p = new TexturePainter(w, h, new Color(0.97f, 0.98f, 1f));
            p.FillRect(0, h - 56, w - 1, h - 1, new Color(0.86f, 0.92f, 0.98f));
            p.Text("DR. MARTIN", 16, h - 30, 2, Navy);
            p.Text("MEDECINE GENERALE", 16, h - 48, 1, Navy);
            p.FakeTextLines(30, w - 30, h - 100, 6, 26, 3, new Color(0.15f, 0.25f, 0.6f), 81, 0.7f);
            return p;
        }

        public static TexturePainter PaintArt(int w, int h, int seed)
        {
            Color[] bgs = { new Color(0.93f, 0.88f, 0.80f), new Color(0.16f, 0.22f, 0.30f), new Color(0.85f, 0.90f, 0.88f) };
            Color[] inks = { new Color(0.85f, 0.45f, 0.28f), new Color(0.95f, 0.78f, 0.35f), new Color(0.20f, 0.45f, 0.50f), new Color(0.12f, 0.15f, 0.2f) };
            var p = new TexturePainter(w, h, bgs[seed % bgs.Length]);
            p.Noise(0.02f, 6, 3, seed + 3);
            var r = new System.Random(seed * 13 + 1);
            for (int i = 0; i < 5; i++)
            {
                Color c = inks[r.Next(inks.Length)];
                if (r.NextDouble() < 0.5) p.FillCircle((float)r.NextDouble() * w, (float)r.NextDouble() * h, 20 + (float)r.NextDouble() * 70, c, 0.85f);
                else p.FillRoundRect((float)r.NextDouble() * w * 0.7f, (float)r.NextDouble() * h * 0.7f, (float)r.NextDouble() * w, (float)r.NextDouble() * h, 6, c, 0.8f);
            }
            for (int i = 0; i < 3; i++) p.Line(0, (float)r.NextDouble() * h, w, (float)r.NextDouble() * h, 3, inks[3], 0.6f);
            return p;
        }

        public static TexturePainter PaintScopeScreen(int w, int h)
        {
            var p = new TexturePainter(w, h, new Color(0.01f, 0.02f, 0.03f));
            Color green = new Color(0.25f, 1f, 0.45f), cyan = new Color(0.3f, 0.9f, 1f), yellow = new Color(1f, 0.85f, 0.3f), red = new Color(1f, 0.35f, 0.35f);
            float[] rows = { h * 0.80f, h * 0.55f, h * 0.30f };
            Color[] cols = { green, cyan, yellow };
            for (int r = 0; r < 3; r++)
            {
                var pts = new Vector2[64];
                for (int i = 0; i < pts.Length; i++)
                {
                    float x = i / 63f * w * 0.7f;
                    float ph = (i % 16) / 16f;
                    float y = r == 0 ? (ph > 0.4f && ph < 0.46f ? 40f : ph > 0.46f && ph < 0.5f ? -14f : 0f) : 10f * Mathf.Sin(ph * Mathf.PI * 2f);
                    pts[i] = new Vector2(x + 8, rows[r] + y);
                }
                p.Polyline(pts, 2.5f, cols[r]);
            }
            p.Text("98", (int)(w * 0.78f), (int)(h * 0.76f), 6, green);
            p.Text("97", (int)(w * 0.78f), (int)(h * 0.5f), 6, cyan);
            p.Text("16", (int)(w * 0.78f), (int)(h * 0.25f), 6, yellow);
            p.Text("128/76", (int)(w * 0.72f), 14, 3, red);
            return p;
        }

        public static TexturePainter PaintFamilyPhoto(int w, int h)
        {
            var p = new TexturePainter(w, h, new Color(0.55f, 0.72f, 0.88f));
            p.VerticalGradient(new Color(0.45f, 0.62f, 0.35f), new Color(0.62f, 0.78f, 0.95f));
            Color[] shirts = { new Color(0.8f, 0.3f, 0.3f), new Color(0.25f, 0.4f, 0.7f), new Color(0.95f, 0.8f, 0.3f) };
            for (int i = 0; i < 3; i++)
            {
                float cx = w * (0.28f + i * 0.22f);
                float s = i == 2 ? 0.7f : 1f;
                p.FillRoundRect(cx - 24 * s, h * 0.1f, cx + 24 * s, h * (0.1f + 0.38f * s), 10, shirts[i]);
                p.FillCircle(cx, h * (0.1f + 0.38f * s) + 16 * s, 16 * s, new Color(0.93f, 0.78f, 0.66f));
            }
            return p;
        }

        public static TexturePainter PaintWallpaper(int size, int seed)
        {
            var p = new TexturePainter(size, size, new Color(0.88f, 0.83f, 0.74f), true);
            int stripes = 12;
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = x / (float)size, v = y / (float)size;
                    float stripe = Mathf.Sin(u * stripes * Mathf.PI * 2f) > 0.55f ? 1f : 0f;
                    float n = TexturePainter.Fbm(u, v, 8, 3, seed);
                    Color c = new Color(0.88f, 0.83f, 0.74f) * (0.96f + n * 0.06f);
                    if (stripe > 0f) c *= 0.93f;
                    c.a = 1f;
                    p.Px[y * size + x] = c;
                    p.Height[y * size + x] = stripe * 0.3f + n * 0.3f;
                }
            }
            return p;
        }

        public static TexturePainter PaintLeaf(int w, int h)
        {
            var p = new TexturePainter(w, h, new Color(0.2f, 0.4f, 0.15f, 1f));
            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < w; x++)
                {
                    float u = x / (float)w - 0.5f, v = y / (float)h;
                    float vein = Mathf.Exp(-Mathf.Abs(u) * 60f) * 0.25f;
                    float side = Mathf.Abs(Mathf.Sin((v * 8f - Mathf.Abs(u) * 6f) * Mathf.PI)) < 0.08f ? 0.08f : 0f;
                    float n = TexturePainter.Fbm(x / (float)w, y / (float)h, 4, 3, 5);
                    Color c = Color.Lerp(new Color(0.16f, 0.36f, 0.12f), new Color(0.32f, 0.55f, 0.20f), v * 0.6f + n * 0.4f);
                    c += new Color(vein + side, vein + side, vein * 0.5f, 0f);
                    c.a = 1f;
                    p.Px[y * w + x] = c;
                }
            }
            return p;
        }
    }
}
