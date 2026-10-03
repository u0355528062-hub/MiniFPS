using System.Collections.Generic;
using UnityEngine;

namespace BlouseBlanche.World
{
    /// <summary>Meubles et objets réutilisables. Chaque pièce fait face à +Z dans son repère local.</summary>
    public sealed partial class ClinicBuilder
    {
        // ------------------------------------------------------------------ Assises

        Transform WaitingChair(Transform parent, Vector3 pos, float yaw, Material fabric)
        {
            var g = WorldKit.Group(parent, "Chaise_Attente", pos, yaw);
            kit.Box(g, "Assise", V(0.48f, 0.07f, 0.46f), fabric, V(0f, 0.43f, 0.01f), 0.03f);
            kit.Box(g, "Dossier", V(0.48f, 0.42f, 0.06f), fabric, V(0f, 0.72f, -0.22f), 0.03f, false, Quaternion.Euler(-8f, 0f, 0f));
            kit.Box(g, "Coque", V(0.46f, 0.03f, 0.44f), pal.PlasticDark, V(0f, 0.385f, 0.01f), 0.01f);
            var sledMesh = kit.Cached("chairSled", () => MeshFactory.Tube(new List<Vector3> { V(0f, 0.012f, 0.23f), V(0f, 0.012f, -0.17f), V(0f, 0.38f, -0.24f), V(0f, 0.62f, -0.255f) }, 0.011f, 8));
            var frontMesh = kit.Cached("chairSledFront", () => MeshFactory.Tube(new List<Vector3> { V(0f, 0.012f, 0.23f), V(0f, 0.37f, 0.2f), V(0f, 0.37f, -0.18f) }, 0.011f, 8));
            foreach (float x in new[] { -0.215f, 0.215f })
            {
                kit.Part(g, "Pietement", sledMesh, pal.Chrome, V(x, 0f, 0f));
                kit.Part(g, "Pietement_Av", frontMesh, pal.Chrome, V(x, 0f, 0f));
            }
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.45f, 0f);
            col.size = V(0.5f, 0.9f, 0.5f);
            return g;
        }

        Transform OfficeChair(Transform parent, Vector3 pos, float yaw, Material upholstery)
        {
            var g = WorldKit.Group(parent, "Fauteuil_Bureau", pos, yaw);
            for (int i = 0; i < 5; i++)
            {
                float a = i * 72f;
                var q = Quaternion.Euler(0f, a, 0f);
                kit.Box(g, "Branche", V(0.05f, 0.03f, 0.3f), pal.BlackMetal, q * V(0f, 0.075f, 0.15f), 0.01f, false, q);
                kit.Sphere(g, "Roulette", 0.026f, pal.PlasticDark, q * V(0f, 0.028f, 0.29f));
            }
            kit.Cylinder(g, "Verin", 0.024f, 0.34f, pal.Chrome, V(0f, 0.08f, 0f), 16);
            kit.Cylinder(g, "Gaine", 0.032f, 0.14f, pal.PlasticDark, V(0f, 0.08f, 0f), 16);
            kit.Box(g, "Mecanisme", V(0.22f, 0.05f, 0.22f), pal.PlasticDark, V(0f, 0.43f, 0f), 0.01f);
            kit.Box(g, "Assise", V(0.5f, 0.08f, 0.48f), upholstery, V(0f, 0.49f, 0.02f), 0.035f);
            kit.Box(g, "Support_Dossier", V(0.06f, 0.32f, 0.03f), pal.PlasticDark, V(0f, 0.62f, -0.24f), 0.01f, false, Quaternion.Euler(-10f, 0f, 0f));
            kit.Box(g, "Dossier", V(0.46f, 0.56f, 0.07f), upholstery, V(0f, 0.92f, -0.27f), 0.035f, false, Quaternion.Euler(-10f, 0f, 0f));
            foreach (float x in new[] { -0.27f, 0.27f })
            {
                kit.Box(g, "Accoudoir_Pied", V(0.03f, 0.2f, 0.03f), pal.PlasticDark, V(x, 0.6f, -0.02f), 0.008f);
                kit.Box(g, "Accoudoir", V(0.06f, 0.025f, 0.26f), pal.PlasticDark, V(x, 0.71f, 0.0f), 0.01f);
            }
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.55f, 0f);
            col.size = V(0.6f, 1.1f, 0.6f);
            return g;
        }

        Transform WoodChair(Transform parent, Vector3 pos, float yaw, Material fabric)
        {
            var g = WorldKit.Group(parent, "Chaise_Bois", pos, yaw);
            foreach (var p in new[] { V(-0.2f, 0f, 0.19f), V(0.2f, 0f, 0.19f), V(-0.2f, 0f, -0.19f), V(0.2f, 0f, -0.19f) })
                kit.Box(g, "Pied", V(0.04f, 0.45f, 0.04f), pal.Oak, p + V(0f, 0.225f, 0f), 0.006f);
            kit.Box(g, "Ceinture", V(0.44f, 0.06f, 0.42f), pal.Oak, V(0f, 0.42f, 0f), 0.008f);
            kit.Box(g, "Assise", V(0.46f, 0.05f, 0.44f), fabric, V(0f, 0.47f, 0.005f), 0.022f);
            foreach (float x in new[] { -0.2f, 0.2f })
                kit.Box(g, "Montant", V(0.04f, 0.45f, 0.035f), pal.Oak, V(x, 0.68f, -0.205f), 0.006f, false, Quaternion.Euler(-6f, 0f, 0f));
            kit.Box(g, "Dossier", V(0.42f, 0.24f, 0.045f), fabric, V(0f, 0.78f, -0.215f), 0.02f, false, Quaternion.Euler(-6f, 0f, 0f));
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.45f, 0f);
            col.size = V(0.48f, 0.9f, 0.46f);
            return g;
        }

        // ------------------------------------------------------------------ Tables, bureaux

        Transform Desk(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Bureau", pos, yaw);
            kit.Box(g, "Plateau", V(1.7f, 0.035f, 0.8f), pal.Walnut, V(0f, 0.7325f, 0f), 0.008f);
            foreach (float x in new[] { -0.8f, 0.8f })
                kit.Box(g, "Flanc", V(0.04f, 0.715f, 0.72f), pal.DeskWhite, V(x, 0.3575f, 0f), 0.006f);
            kit.Box(g, "Voile", V(1.56f, 0.38f, 0.02f), pal.DeskWhite, V(0f, 0.5f, -0.36f), 0.004f);
            kit.Box(g, "Caisson", V(0.42f, 0.6f, 0.55f), pal.DeskWhite, V(0.52f, 0.31f, 0.06f), 0.01f);
            for (int i = 0; i < 3; i++)
            {
                kit.Box(g, "Tiroir", V(0.4f, 0.18f, 0.01f), pal.DeskWhite, V(0.52f, 0.12f + i * 0.19f, 0.336f), 0.004f);
                kit.Box(g, "Poignee", V(0.12f, 0.012f, 0.012f), pal.Steel, V(0.52f, 0.17f + i * 0.19f, 0.345f), 0.004f);
            }
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.375f, 0f);
            col.size = V(1.7f, 0.75f, 0.8f);
            return g;
        }

        Transform ExamTable(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Divan_Examen", pos, yaw);
            kit.Box(g, "Matelas", V(0.65f, 0.08f, 1.38f), pal.LeatherExam, V(0f, 0.72f, -0.26f), 0.035f);
            kit.Box(g, "Tetiere", V(0.65f, 0.08f, 0.52f), pal.LeatherExam, V(0f, 0.75f, 0.69f), 0.035f, false, Quaternion.Euler(-14f, 0f, 0f));
            kit.Box(g, "Drap", V(0.52f, 0.004f, 1.36f), pal.ExamPaper, V(0f, 0.762f, -0.26f), 0.001f);
            kit.Box(g, "Chassis", V(0.6f, 0.06f, 1.82f), pal.PlasticWhite, V(0f, 0.65f, 0f), 0.01f);
            foreach (var p in new[] { V(-0.26f, 0f, 0.82f), V(0.26f, 0f, 0.82f), V(-0.26f, 0f, -0.82f), V(0.26f, 0f, -0.82f) })
                kit.Box(g, "Pied", V(0.05f, 0.62f, 0.05f), pal.Chrome, p + V(0f, 0.31f, 0f), 0.012f);
            kit.Box(g, "Tablette_Basse", V(0.55f, 0.02f, 1.6f), pal.PlasticWhite, V(0f, 0.18f, 0f), 0.006f);
            // Rouleau de drap d'examen
            kit.Cylinder(g, "Rouleau", 0.06f, 0.56f, pal.ExamPaper, V(-0.28f, 0.84f, 0.98f), 20, true, Quaternion.Euler(0f, 0f, -90f));
            foreach (float x in new[] { -0.31f, 0.31f })
                kit.Box(g, "Support_Rouleau", V(0.02f, 0.16f, 0.03f), pal.Chrome, V(x, 0.8f, 0.98f), 0.006f);
            // Linge plié + oreiller
            kit.Box(g, "Oreiller", V(0.42f, 0.08f, 0.26f), pal.ExamPaper, V(0f, 0.83f, 0.74f), 0.035f, false, Quaternion.Euler(-14f, 0f, 0f));
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.38f, 0f);
            col.size = V(0.65f, 0.76f, 1.92f);
            return g;
        }

        // ------------------------------------------------------------------ Plantes

        Transform Plant(Transform parent, Vector3 pos, float height, int seed, bool white = false)
        {
            var g = WorldKit.Group(parent, "Plante", pos, seed * 37f);
            var r = new System.Random(seed);
            float potR = 0.17f + height * 0.04f, potH = 0.28f + height * 0.08f;
            var potProfile = new List<Vector2>
            {
                V2(0f, 0f), V2(potR * 0.72f, 0f), V2(potR * 0.72f, 0f), V2(potR * 0.95f, potH * 0.7f), V2(potR, potH),
                V2(potR, potH), V2(potR * 0.9f, potH), V2(potR * 0.9f, potH), V2(potR * 0.88f, potH * 0.85f)
            };
            kit.Part(g, "Pot", kit.Cached("pot" + potR.ToString("F3") + potH.ToString("F3"), () => MeshFactory.Lathe(potProfile, 28)), white ? pal.PotWhite : pal.Terracotta, Vector3.zero, Quaternion.identity, Vector3.one);
            kit.Part(g, "Terre", kit.CylinderMesh(potR * 0.86f, 0.01f, 24), pal.Soil, V(0f, potH * 0.85f - 0.01f, 0f), false);

            var leaves = new MeshData();
            var leavesDark = new MeshData();
            var stems = new MeshData();
            var leaf = MeshFactory.Sphere(0.5f, 6, 10);
            int count = 14 + r.Next(6);
            for (int i = 0; i < count; i++)
            {
                float a = (float)(r.NextDouble() * 360.0);
                float lean = 18f + (float)r.NextDouble() * 48f;
                float len = height * (0.45f + (float)r.NextDouble() * 0.55f);
                var dir = Quaternion.Euler(0f, a, 0f) * Quaternion.Euler(lean, 0f, 0f) * Vector3.up;
                Vector3 baseP = V(0f, potH * 0.85f, 0f);
                Vector3 tip = baseP + dir * len;
                Vector3 mid = baseP + dir * (len * 0.55f) + Vector3.up * len * 0.12f;
                stems.Append(MeshFactory.Tube(new List<Vector3> { baseP, mid, tip }, 0.006f, 5, false), Vector3.zero);
                float size = 0.16f + (float)r.NextDouble() * 0.12f;
                var rot = Quaternion.LookRotation(dir, Vector3.up) * Quaternion.Euler(70f + (float)r.NextDouble() * 30f, 0f, (float)(r.NextDouble() * 40.0 - 20.0));
                var target = (i % 3 == 0) ? leavesDark : leaves;
                target.Append(leaf, tip + dir * size * 0.4f, rot, V(size * 0.62f, size * 1.15f, size * 0.07f));
            }
            string k = "plant" + seed + "_" + height.ToString("F2");
            kit.Part(g, "Feuilles", kit.FromData(k + "L", leaves), pal.Leaf, Vector3.zero, Quaternion.identity, Vector3.one);
            kit.Part(g, "Feuilles2", kit.FromData(k + "D", leavesDark), pal.LeafDark, Vector3.zero, Quaternion.identity, Vector3.one);
            kit.Part(g, "Tiges", kit.FromData(k + "S", stems), pal.LeafDark, Vector3.zero, Quaternion.identity, Vector3.one, false);
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, potH * 0.5f + 0.2f, 0f);
            col.size = V(potR * 2.2f, potH + 0.4f, potR * 2.2f);
            return g;
        }

        static Vector2 V2(float x, float y) => new Vector2(x, y);

        // ------------------------------------------------------------------ Rangements

        Transform Bookshelf(Transform parent, Vector3 pos, float yaw, float width, float height, int seed)
        {
            var g = WorldKit.Group(parent, "Bibliotheque", pos, yaw);
            const float depth = 0.34f, th = 0.025f;
            kit.Box(g, "Cote_G", V(th, height, depth), pal.Oak, V(-width * 0.5f + th * 0.5f, height * 0.5f, 0f), 0.004f);
            kit.Box(g, "Cote_D", V(th, height, depth), pal.Oak, V(width * 0.5f - th * 0.5f, height * 0.5f, 0f), 0.004f);
            kit.Box(g, "Fond", V(width, height, 0.01f), pal.DeskWhite, V(0f, height * 0.5f, -depth * 0.5f + 0.005f), 0.002f);
            int shelves = Mathf.Max(2, Mathf.RoundToInt(height / 0.38f));
            var r = new System.Random(seed);
            Material[] bookMats = { pal.FabricNavy, pal.KidRed, pal.PlasticWhite, pal.FabricTeal, pal.FabricMustard, pal.PlasticDark, pal.Oak };
            var byMat = new MeshData[bookMats.Length];
            for (int i = 0; i < byMat.Length; i++) byMat[i] = new MeshData();
            for (int s = 0; s <= shelves; s++)
            {
                float y = s * (height - th) / shelves + th * 0.5f;
                kit.Box(g, "Tablette", V(width - th * 2f, th, depth - 0.02f), pal.Oak, V(0f, y, 0.01f), 0.004f);
                if (s == shelves) break;
                float x = -width * 0.5f + th + 0.02f;
                float maxH = (height - th) / shelves - th - 0.04f;
                while (x < width * 0.5f - th - 0.06f)
                {
                    if (r.NextDouble() < 0.12) { x += 0.06f + (float)r.NextDouble() * 0.1f; continue; }
                    float bw = 0.022f + (float)r.NextDouble() * 0.035f;
                    float bh = Mathf.Min(maxH, 0.17f + (float)r.NextDouble() * 0.12f);
                    float bd = 0.17f + (float)r.NextDouble() * 0.07f;
                    int mi = r.Next(bookMats.Length);
                    float lean = r.NextDouble() < 0.06 ? 12f : 0f;
                    byMat[mi].Append(MeshFactory.RoundedBox(V(bw, bh, bd), 0.003f, 1), V(x + bw * 0.5f, y + th * 0.5f + bh * 0.5f, -depth * 0.5f + 0.02f + bd * 0.5f), Quaternion.Euler(0f, 0f, lean), Vector3.one);
                    x += bw + 0.002f;
                }
            }
            for (int i = 0; i < byMat.Length; i++)
                if (byMat[i].VertexCount > 0)
                    kit.Part(g, "Livres", kit.FromData("books" + seed + "_" + i, byMat[i]), bookMats[i], Vector3.zero, Quaternion.identity, Vector3.one);
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, height * 0.5f, 0f);
            col.size = V(width, height, depth);
            return g;
        }

        Transform Vitrine(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Vitrine", pos, yaw);
            const float w = 1.1f, h = 1.9f, d = 0.42f;
            kit.Box(g, "Corps_G", V(0.03f, h, d), pal.DeskWhite, V(-w * 0.5f + 0.015f, h * 0.5f, 0f), 0.004f);
            kit.Box(g, "Corps_D", V(0.03f, h, d), pal.DeskWhite, V(w * 0.5f - 0.015f, h * 0.5f, 0f), 0.004f);
            kit.Box(g, "Dessus", V(w, 0.03f, d), pal.DeskWhite, V(0f, h - 0.015f, 0f), 0.004f);
            kit.Box(g, "Socle", V(w, 0.1f, d), pal.DeskWhite, V(0f, 0.05f, 0f), 0.004f);
            kit.Box(g, "Fond", V(w, h, 0.01f), pal.AccentTeal, V(0f, h * 0.5f, -d * 0.5f + 0.005f), 0.002f);
            var r = new System.Random(5);
            Material[] boxMats = { pal.PlasticWhite, pal.KidBlue, pal.KidGreen, pal.FabricMustard, pal.KidRed };
            for (int s = 0; s < 4; s++)
            {
                float y = 0.1f + s * 0.44f;
                kit.Box(g, "Etagere", V(w - 0.06f, 0.012f, d - 0.04f), s == 0 ? pal.DeskWhite : pal.GlassFrosted, V(0f, y + 0.006f, 0f), 0.002f);
                float x = -w * 0.5f + 0.08f;
                while (x < w * 0.5f - 0.12f)
                {
                    bool bottle = r.NextDouble() < 0.35;
                    if (bottle)
                    {
                        float br = 0.025f + (float)r.NextDouble() * 0.015f, bh = 0.1f + (float)r.NextDouble() * 0.08f;
                        var prof = new List<Vector2> { V2(0f, 0f), V2(br, 0f), V2(br, 0f), V2(br, bh * 0.75f), V2(br * 0.45f, bh * 0.88f), V2(br * 0.45f, bh), V2(0f, bh) };
                        kit.Part(g, "Flacon", kit.Cached("bottle" + br.ToString("F3") + bh.ToString("F3"), () => MeshFactory.Lathe(prof, 14)), r.NextDouble() < 0.5 ? pal.Water : pal.PlasticWhite, V(x + br, y + 0.012f, (float)r.NextDouble() * 0.1f - 0.05f), Quaternion.identity, Vector3.one);
                        x += br * 2f + 0.03f;
                    }
                    else
                    {
                        float bw = 0.06f + (float)r.NextDouble() * 0.08f, bh = 0.06f + (float)r.NextDouble() * 0.12f, bd = 0.1f + (float)r.NextDouble() * 0.1f;
                        kit.Box(g, "Boite", V(bw, bh, bd), boxMats[r.Next(boxMats.Length)], V(x + bw * 0.5f, y + 0.012f + bh * 0.5f, -0.04f), 0.004f);
                        x += bw + 0.02f;
                    }
                }
            }
            // Portes vitrées
            foreach (float side in new[] { -1f, 1f })
            {
                float px = side * w * 0.25f;
                kit.Box(g, "Porte_Cadre", V(w * 0.5f - 0.01f, h - 0.14f, 0.02f), pal.DeskWhite, V(px, h * 0.5f + 0.03f, d * 0.5f - 0.01f), 0.004f);
                var glass = kit.Box(g, "Porte_Vitre", V(w * 0.5f - 0.08f, h - 0.24f, 0.022f), pal.Glass, V(px, h * 0.5f + 0.03f, d * 0.5f - 0.008f), 0.001f, false, null, false);
                glass.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                kit.Box(g, "Poignee", V(0.012f, 0.14f, 0.02f), pal.Steel, V(-side * 0.04f, 1.0f, d * 0.5f + 0.012f), 0.005f);
            }
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, h * 0.5f, 0f);
            col.size = V(w, h, d);
            return g;
        }

        Transform FilingCabinet(Transform parent, Vector3 pos, float yaw, int drawers)
        {
            float h = drawers * 0.32f + 0.04f;
            var g = WorldKit.Group(parent, "Classeur", pos, yaw);
            kit.Box(g, "Corps", V(0.5f, h, 0.46f), pal.PlasticGrey, V(0f, h * 0.5f, 0f), 0.01f);
            for (int i = 0; i < drawers; i++)
            {
                float y = 0.04f + i * 0.32f + 0.16f;
                kit.Box(g, "Tiroir", V(0.46f, 0.29f, 0.012f), pal.PlasticWhite, V(0f, y, 0.234f), 0.006f);
                kit.Box(g, "Poignee", V(0.16f, 0.02f, 0.02f), pal.Steel, V(0f, y + 0.08f, 0.248f), 0.006f);
                kit.Box(g, "Etiquette", V(0.08f, 0.04f, 0.004f), pal.ExamPaper, V(0f, y + 0.02f, 0.242f), 0.001f);
            }
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, h * 0.5f, 0f);
            col.size = V(0.5f, h, 0.46f);
            return g;
        }

        // ------------------------------------------------------------------ Mur : cadres, horloge, écrans

        /// <summary>Cadre mural avec visuel. pos = centre du cadre contre le mur ; le cadre fait face à +Z local.</summary>
        void Frame(Transform parent, string decal, Vector3 pos, float yaw, float w, float h, Material frameMat, float emission = 0f)
        {
            var g = WorldKit.Group(parent, "Cadre_" + decal, pos, yaw);
            const float border = 0.022f, depth = 0.025f;
            kit.Box(g, "Bord_H", V(w, border, depth), frameMat, V(0f, h * 0.5f - border * 0.5f, depth * 0.5f), 0.004f);
            kit.Box(g, "Bord_B", V(w, border, depth), frameMat, V(0f, -h * 0.5f + border * 0.5f, depth * 0.5f), 0.004f);
            kit.Box(g, "Bord_G", V(border, h, depth), frameMat, V(-w * 0.5f + border * 0.5f, 0f, depth * 0.5f), 0.004f);
            kit.Box(g, "Bord_D", V(border, h, depth), frameMat, V(w * 0.5f - border * 0.5f, 0f, depth * 0.5f), 0.004f);
            kit.Box(g, "Fond", V(w - border, h - border, 0.006f), pal.DeskWhite, V(0f, 0f, 0.003f), 0.001f, false, null, false);
            kit.Quad(g, "Visuel", w - border * 2.4f, h - border * 2.4f, kit.Mat.Decal("Frame", decal, 0.3f, emission), V(0f, 0f, 0.008f), Quaternion.identity);
            // Vitre de protection (reflets)
            var glass = kit.Box(g, "Verre", V(w - border * 2f, h - border * 2f, 0.003f), pal.Glass, V(0f, 0f, depth - 0.004f), 0.0005f, false, null, false);
            glass.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        }

        /// <summary>Affiche simple (sans cadre), punaisée ou collée. Fait face à +Z local.</summary>
        void Poster(Transform parent, string decal, Vector3 pos, float yaw, float w, float h)
        {
            var g = WorldKit.Group(parent, "Affiche_" + decal, pos, yaw);
            kit.Quad(g, "Affiche", w, h, kit.Mat.Decal("Poster", decal, 0.2f), V(0f, 0f, 0.003f), Quaternion.identity);
        }

        void Clock(Transform parent, Vector3 pos, float yaw, float radius)
        {
            var g = WorldKit.Group(parent, "Horloge", pos, yaw);
            kit.Part(g, "Boitier", kit.RoundedCylinderMesh(radius, 0.045f, 0.012f, 40), pal.PlasticDark, Vector3.zero, Quaternion.Euler(90f, 0f, 0f), Vector3.one);
            kit.Quad(g, "Cadran", radius * 1.86f, radius * 1.86f, kit.Mat.Decal("Clock", "ClockFace", 0.4f), V(0f, 0f, 0.047f), Quaternion.identity);
            var hands = WorldKit.Group(g, "Aiguilles", V(0f, 0f, 0.05f));
            Transform Hand(string n, float len, float width, Material m, float z)
            {
                var pivot = WorldKit.Group(hands, n, V(0f, 0f, z));
                kit.Box(pivot, "Aiguille", V(width, len, 0.003f), m, V(0f, len * 0.4f, 0f), 0.001f, false, null, false);
                return pivot;
            }
            var clock = g.gameObject.AddComponent<WallClock>();
            clock.HourHand = Hand("Heures", radius * 0.55f, 0.012f, pal.PlasticDark, 0f);
            clock.MinuteHand = Hand("Minutes", radius * 0.8f, 0.008f, pal.PlasticDark, 0.002f);
            clock.SecondHand = Hand("Secondes", radius * 0.85f, 0.003f, pal.KidRed, 0.004f);
            kit.Part(hands, "Axe", kit.CylinderMesh(0.008f, 0.01f, 12), pal.PlasticDark, V(0f, 0f, 0.002f), Quaternion.Euler(90f, 0f, 0f), Vector3.one);
        }

        void Screen(Transform parent, string decal, Vector3 pos, float yaw, float w, float h, float emission)
        {
            var g = WorldKit.Group(parent, "Ecran_" + decal, pos, yaw);
            kit.Box(g, "Coque", V(w + 0.03f, h + 0.03f, 0.04f), pal.PlasticDark, V(0f, 0f, 0.02f), 0.008f);
            kit.Quad(g, "Dalle", w, h, kit.Mat.Decal("Screen", decal, 0.85f, emission), V(0f, 0f, 0.0405f), Quaternion.identity);
        }

        // ------------------------------------------------------------------ Éclairage d'ambiance

        Light CeilingPanel(Transform parent, Vector3 xz, bool shadows, float intensity = 3.4f)
        {
            float y = ClinicLayout.WallHeight;
            var g = WorldKit.Group(parent, "Dalle_LED", V(xz.x, y, xz.z));
            kit.Box(g, "Cadre", V(0.62f, 0.02f, 0.62f), pal.PlasticWhite, V(0f, -0.01f, 0f), 0.004f, false, null, false);
            kit.Box(g, "Diffuseur", V(0.56f, 0.008f, 0.56f), pal.LightPanel, V(0f, -0.022f, 0f), 0.002f, false, null, false);
            var lgo = new GameObject("Spot");
            lgo.transform.SetParent(g, false);
            lgo.transform.localPosition = V(0f, -0.06f, 0f);
            lgo.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
            var l = lgo.AddComponent<Light>();
            l.type = LightType.Spot;
            l.spotAngle = 150f;
            l.innerSpotAngle = 80f;
            l.range = 7.5f;
            l.intensity = intensity;
            l.color = new Color(1f, 0.95f, 0.88f);
            l.shadows = shadows ? LightShadows.Soft : LightShadows.None;
            l.shadowStrength = 0.75f;
            l.shadowBias = 0.03f;
            l.shadowNormalBias = 0.4f;
            l.renderMode = LightRenderMode.ForcePixel;
            world.AllLights.Add(l);
            if (shadows) world.ShadowedLights.Add(l);
            return l;
        }
    }
}
