using System.Collections.Generic;
using UnityEngine;
using L = BlouseBlanche.World.ClinicLayout;

namespace BlouseBlanche.World
{
    public sealed partial class ClinicBuilder
    {
        // ================================================================== Extérieur : rue, jardin, voisinage

        void BuildExterior()
        {
            var g = outsideRoot;
            float e = L.ExteriorThickness;

            // Pelouse (légèrement sous le sol intérieur)
            var lawn = MeshFactory.PlaneXZ(110f, 110f, 4, 4);
            kit.ArchMesh(pal.Grass, lawn, V(7.5f, -0.02f, 8f), Quaternion.identity);

            // Trottoir côté cabinet, bordure, chaussée, trottoir d'en face
            kit.ArchBox(pal.Paving, V(-40f, -0.15f, -3.5f), V(55f, 0.0f, -e));
            kit.ArchBox(pal.Paving, V(L.EntranceX0 - 0.6f, -0.15f, -e), V(L.EntranceX1 + 0.6f, 0.0f, 0f));
            kit.ArchBox(pal.Stone, V(-40f, -0.14f, -3.65f), V(55f, 0.0f, -3.5f));
            kit.ArchBox(pal.Asphalt, V(-40f, -0.3f, -10.5f), V(55f, -0.12f, -3.65f));
            kit.ArchBox(pal.Stone, V(-40f, -0.14f, -10.65f), V(55f, 0.0f, -10.5f));
            kit.ArchBox(pal.Paving, V(-40f, -0.15f, -13.5f), V(55f, 0.0f, -10.65f));
            for (float x = -38f; x < 54f; x += 4.5f)
                kit.ArchBox(pal.RoadPaint, V(x, -0.12f, -7.15f), V(x + 2.2f, -0.114f, -7.0f), false);
            // Passage piéton face à l'entrée
            for (int i = 0; i < 7; i++)
                kit.ArchBox(pal.RoadPaint, V(10.4f + i * 0.5f, -0.12f, -10.3f), V(10.7f + i * 0.5f, -0.114f, -3.85f), false);

            // Allée de jardin + bordures végétales autour du cabinet
            kit.ArchBox(pal.Paving, V(-e - 1.2f, -0.12f, -e), V(-e, -0.005f, L.MaxZ + e), true);
            Hedge(g, V(-4.6f, 0f, -1.6f), V(-4.6f, 0f, 16f));
            Hedge(g, V(-4.6f, 0f, 16f), V(20f, 0f, 16f));
            Hedge(g, V(20f, 0f, 16f), V(20f, 0f, -1.6f));

            // Arbres
            Tree(g, V(-3.0f, 0f, 3.5f), 1.0f, 1);
            Tree(g, V(-3.4f, 0f, 10.5f), 1.2f, 2);
            Tree(g, V(4.5f, 0f, 14.6f), 1.1f, 3);
            Tree(g, V(12.5f, 0f, 14.4f), 0.95f, 4);
            Tree(g, V(18.4f, 0f, 9.0f), 1.15f, 5);
            Tree(g, V(18.6f, 0f, 2.0f), 0.9f, 6);
            Tree(g, V(-2.0f, 0f, -12.2f), 1.0f, 7);
            Tree(g, V(15.5f, 0f, -12.3f), 1.05f, 8);
            Tree(g, V(30f, 0f, -12f), 1.1f, 9);

            // Façade : auvent, enseigne, plaque
            kit.Box(g, "Auvent", V(3.2f, 0.12f, 1.5f), pal.DeskWhite, V(12f, 2.85f, -e - 0.75f), 0.01f);
            kit.Box(g, "Auvent_Verre", V(3.0f, 0.02f, 1.35f), pal.GlassFrosted, V(12f, 2.92f, -e - 0.72f), 0.004f, false, null, false);
            kit.Quad(g, "Enseigne", 2.6f, 0.65f, kit.Mat.Decal("Sign", "ClinicSign", 0.4f, 0.6f), V(5.1f, 2.45f, -e - 0.012f), Quaternion.Euler(0f, 180f, 0f));
            kit.Box(g, "Enseigne_Fond", V(2.7f, 0.75f, 0.03f), pal.AccentNavy, V(5.1f, 2.45f, -e + 0.003f), 0.01f);
            var plate = kit.Quad(g, "Plaque_Medecin", 0.4f, 0.125f, kit.Mat.Decal("Sign", "SignConsult", 0.8f), V(10.6f, 1.55f, -e - 0.008f), Quaternion.Euler(0f, 180f, 0f));
            plate.name = "Plaque_Medecin";
            kit.Box(g, "Plaque_Support", V(0.44f, 0.16f, 0.01f), pal.Gold, V(10.6f, 1.55f, -e - 0.002f), 0.003f);

            // Mobilier urbain
            Bench(g, V(7.6f, 0f, -1.05f), 180f);
            StreetLamp(g, V(3.0f, 0f, -3.25f));
            StreetLamp(g, V(21.0f, 0f, -3.25f));
            StreetLamp(g, V(12.0f, 0f, -10.9f));
            TrashBin(g, V(9.0f, 0f, -1.1f), pal.KidGreen);
            BikeRack(g, V(16.5f, 0f, -0.9f));

            // Voitures stationnées
            Car(g, V(1.5f, -0.12f, -4.7f), 0f, pal.CarRed);
            Car(g, V(18.0f, -0.12f, -4.7f), 180f, pal.CarBlue);
            Car(g, V(27.0f, -0.12f, -9.4f), 180f, pal.PlasticWhite);

            // Immeubles de l'autre côté de la rue
            Building(g, -8f, 3.5f, -13.6f, 7.5f, pal.Plaster, 21);
            Building(g, 4.5f, 13.5f, -13.6f, 9.5f, pal.Brick, 22);
            Building(g, 14.5f, 24f, -13.6f, 6.5f, pal.Plaster, 23);
            Building(g, 25f, 35f, -13.6f, 8f, pal.Brick, 24);

            // Fond lointain (masse végétale qui ferme l'horizon)
            for (int i = 0; i < 14; i++)
                Tree(g, V(-14f + i * 3.6f, 0f, 24f + (i % 3) * 1.6f), 1.4f, 30 + i);
        }

        void Hedge(Transform parent, Vector3 a, Vector3 b)
        {
            Vector3 d = b - a;
            float len = d.magnitude;
            var g = WorldKit.Group(parent, "Haie", (a + b) * 0.5f, Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg);
            kit.Box(g, "Feuillage", V(0.7f, 0.95f, len), pal.FoliageDark, V(0f, 0.47f, 0f), 0.25f, true);
        }

        void Tree(Transform parent, Vector3 pos, float scale, int seed)
        {
            var r = new System.Random(seed);
            var g = WorldKit.Group(parent, "Arbre", pos, (float)r.NextDouble() * 360f);
            float h = 2.4f * scale;
            var trunk = new List<Vector2> { V2(0f, 0f), V2(0.22f * scale, 0f), V2(0.22f * scale, 0f), V2(0.16f * scale, 0.4f * scale), V2(0.12f * scale, h), V2(0f, h + 0.05f) };
            kit.Part(g, "Tronc", kit.Cached("trunk" + scale.ToString("F2"), () => MeshFactory.Lathe(trunk, 12)), pal.Bark, Vector3.zero);
            var crown = new MeshData();
            var crownDark = new MeshData();
            var blob = MeshFactory.Sphere(1f, 10, 16);
            int blobs = 5 + r.Next(3);
            for (int i = 0; i < blobs; i++)
            {
                float a = (float)(r.NextDouble() * Mathf.PI * 2.0);
                float rr = (float)r.NextDouble() * 0.9f * scale;
                float s = (0.9f + (float)r.NextDouble() * 0.6f) * scale;
                Vector3 c = V(Mathf.Cos(a) * rr, h + 0.6f * scale + (float)r.NextDouble() * 1.1f * scale, Mathf.Sin(a) * rr);
                (i % 2 == 0 ? crown : crownDark).Append(blob, c, Quaternion.identity, V(s, s * 0.85f, s));
            }
            kit.Part(g, "Feuillage", kit.FromData("crown" + seed, crown), pal.Foliage, Vector3.zero);
            kit.Part(g, "Feuillage2", kit.FromData("crownD" + seed, crownDark), pal.FoliageDark, Vector3.zero);
            var col = g.gameObject.AddComponent<CapsuleCollider>();
            col.center = V(0f, 1.2f, 0f);
            col.radius = 0.25f * scale;
            col.height = 2.4f;
        }

        void Bench(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Banc", pos, yaw);
            for (int i = 0; i < 3; i++)
                kit.Box(g, "Latte", V(1.8f, 0.04f, 0.1f), pal.Oak, V(0f, 0.45f, -0.12f + i * 0.12f), 0.01f);
            for (int i = 0; i < 2; i++)
                kit.Box(g, "Dossier", V(1.8f, 0.09f, 0.035f), pal.Oak, V(0f, 0.62f + i * 0.13f, -0.24f), 0.01f, false, Quaternion.Euler(-12f, 0f, 0f));
            foreach (float x in new[] { -0.75f, 0.75f })
            {
                kit.Box(g, "Pied", V(0.06f, 0.44f, 0.4f), pal.BlackMetal, V(x, 0.22f, 0f), 0.01f);
                kit.Box(g, "Montant", V(0.05f, 0.42f, 0.04f), pal.BlackMetal, V(x, 0.65f, -0.24f), 0.01f, false, Quaternion.Euler(-12f, 0f, 0f));
            }
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.45f, 0f);
            col.size = V(1.8f, 0.9f, 0.55f);
        }

        void StreetLamp(Transform parent, Vector3 pos)
        {
            var g = WorldKit.Group(parent, "Lampadaire", pos);
            kit.Cylinder(g, "Mat", 0.06f, 4.2f, pal.BlackMetal, Vector3.zero, 12);
            kit.Box(g, "Crosse", V(0.08f, 0.06f, 0.7f), pal.BlackMetal, V(0f, 4.15f, -0.3f), 0.02f);
            kit.Box(g, "Tete", V(0.3f, 0.1f, 0.5f), pal.BlackMetal, V(0f, 4.1f, -0.6f), 0.03f);
            kit.Box(g, "Optique", V(0.24f, 0.02f, 0.42f), pal.GlassFrosted, V(0f, 4.045f, -0.6f), 0.005f, false, null, false);
            var col = g.gameObject.AddComponent<CapsuleCollider>();
            col.center = V(0f, 1.5f, 0f);
            col.radius = 0.1f;
            col.height = 3f;
        }

        void BikeRack(Transform parent, Vector3 pos)
        {
            var g = WorldKit.Group(parent, "Arceaux_Velo", pos);
            for (int i = 0; i < 3; i++)
            {
                var arc = MeshFactory.Arc(V(0f, 0.45f, 0f), Vector3.right, Vector3.up, 0.38f, 180f, 0f, 12);
                arc.Insert(0, arc[0] + V(0f, -0.45f, 0f));
                arc.Add(arc[arc.Count - 1] + V(0f, -0.45f, 0f));
                kit.Part(g, "Arceau", kit.Cached("bikeArc", () => MeshFactory.Tube(arc, 0.025f, 8)), pal.Steel, V(0f, 0f, i * 0.8f), Quaternion.Euler(0f, 90f, 0f), Vector3.one);
            }
        }

        void Car(Transform parent, Vector3 pos, float yaw, Material paint)
        {
            var g = WorldKit.Group(parent, "Voiture", pos, yaw);
            kit.Box(g, "Caisse", V(1.78f, 0.62f, 4.2f), paint, V(0f, 0.6f, 0f), 0.18f, true);
            kit.Box(g, "Habitacle", V(1.6f, 0.55f, 2.2f), paint, V(0f, 1.15f, -0.2f), 0.2f);
            kit.Box(g, "Vitres", V(1.62f, 0.4f, 2.0f), pal.DarkGlass, V(0f, 1.18f, -0.2f), 0.15f);
            kit.Box(g, "Pare_Choc_Av", V(1.7f, 0.2f, 0.12f), pal.PlasticDark, V(0f, 0.38f, 2.1f), 0.05f);
            kit.Box(g, "Pare_Choc_Ar", V(1.7f, 0.2f, 0.12f), pal.PlasticDark, V(0f, 0.38f, -2.1f), 0.05f);
            kit.Box(g, "Phare_G", V(0.35f, 0.1f, 0.04f), pal.Ceramic, V(-0.6f, 0.7f, 2.1f), 0.02f);
            kit.Box(g, "Phare_D", V(0.35f, 0.1f, 0.04f), pal.Ceramic, V(0.6f, 0.7f, 2.1f), 0.02f);
            kit.Box(g, "Feu_G", V(0.3f, 0.1f, 0.04f), pal.KidRed, V(-0.6f, 0.72f, -2.1f), 0.02f);
            kit.Box(g, "Feu_D", V(0.3f, 0.1f, 0.04f), pal.KidRed, V(0.6f, 0.72f, -2.1f), 0.02f);
            var wheel = kit.RoundedCylinderMesh(0.33f, 0.22f, 0.06f, 24);
            foreach (var p in new[] { V(-0.86f, 0.33f, 1.35f), V(0.86f, 0.33f, 1.35f), V(-0.86f, 0.33f, -1.35f), V(0.86f, 0.33f, -1.35f) })
            {
                float side = p.x < 0f ? -1f : 1f;
                kit.Part(g, "Roue", wheel, pal.Rubber, p + V(-side * 0.11f, 0f, 0f), Quaternion.Euler(0f, 0f, side * 90f), Vector3.one);
                kit.Part(g, "Jante", kit.CylinderMesh(0.2f, 0.01f, 20), pal.Steel, p + V(side * 0.115f, 0f, 0f), Quaternion.Euler(0f, 0f, -side * 90f), Vector3.one);
            }
        }

        void Building(Transform parent, float x0, float x1, float z, float height, Material facade, int seed)
        {
            float depth = 10f;
            kit.ArchBox(facade, V(x0, -0.1f, z - depth), V(x1, height, z));
            kit.ArchBox(pal.Roof, V(x0 - 0.1f, height, z - depth - 0.1f), V(x1 + 0.1f, height + 0.25f, z + 0.1f));
            var r = new System.Random(seed);
            var g = WorldKit.Group(parent, "Immeuble", Vector3.zero);
            int floors = Mathf.Max(1, Mathf.FloorToInt((height - 0.6f) / 2.8f));
            float w = x1 - x0;
            int cols = Mathf.Max(1, Mathf.FloorToInt(w / 2.2f));
            for (int f = 0; f < floors; f++)
            {
                for (int c = 0; c < cols; c++)
                {
                    float cx = x0 + (c + 0.5f) * w / cols;
                    float cy = 1.6f + f * 2.8f;
                    bool shop = f == 0 && r.NextDouble() < 0.4;
                    Vector3 size = shop ? V(1.8f, 2.2f, 0.06f) : V(1.1f, 1.4f, 0.06f);
                    float y = shop ? 1.15f : cy;
                    kit.Box(g, "Fenetre_Cadre", size + V(0.12f, 0.12f, -0.03f), pal.DeskWhite, V(cx, y, z + 0.015f), 0.01f, false, null, false);
                    kit.Box(g, "Fenetre_Vitre", size, pal.DarkGlass, V(cx, y, z + 0.03f), 0.005f, false, null, false);
                    if (!shop) kit.Box(g, "Appui", V(size.x + 0.2f, 0.05f, 0.12f), pal.Stone, V(cx, y - size.y * 0.5f - 0.04f, z + 0.06f), 0.01f, false, null, false);
                }
            }
        }
    }
}
