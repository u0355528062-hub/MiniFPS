using System.Collections.Generic;
using BlouseBlanche.Core;
using UnityEngine;
using L = BlouseBlanche.World.ClinicLayout;

namespace BlouseBlanche.World
{
    /// <summary>
    /// Construit tout le cabinet médical en code : architecture, mobilier, extérieur, éclairage,
    /// graphe de navigation et points d'intérêt. Aucun asset externe.
    /// </summary>
    public sealed partial class ClinicBuilder
    {
        readonly WorldKit kit;
        readonly Palette pal;
        public Palette Pal => pal;
        ClinicWorld world;
        Transform root, archRoot, propsRoot, outsideRoot, lightsRoot;
        readonly System.Random rng = new System.Random(20261005);

        public ClinicBuilder(WorldKit kit)
        {
            this.kit = kit;
            pal = new Palette(kit.Mat);
        }

        static Quaternion Yaw(float deg) => Quaternion.Euler(0f, deg, 0f);
        static Vector3 V(float x, float y, float z) => new Vector3(x, y, z);

        /// <summary>Construction par étapes (une étape par frame pendant le chargement).</summary>
        public IEnumerable<string> Build(Transform parent, System.Action<ClinicWorld> onCreated)
        {
            var go = new GameObject("Clinic");
            go.transform.SetParent(parent, false);
            world = go.AddComponent<ClinicWorld>();
            onCreated?.Invoke(world);
            root = go.transform;
            archRoot = WorldKit.Group(root, "Architecture", Vector3.zero);
            propsRoot = WorldKit.Group(root, "Mobilier", Vector3.zero);
            outsideRoot = WorldKit.Group(root, "Exterieur", Vector3.zero);
            lightsRoot = WorldKit.Group(root, "Eclairage", Vector3.zero);

            BuildFloorsAndCeilings(); yield return "Sols et plafonds";
            BuildWalls(); yield return "Murs";
            BuildDoors(); yield return "Portes";
            BuildWindows(); yield return "Fenêtres";
            kit.FlushArchitecture(archRoot); yield return "Fusion de la géométrie";
            BuildLobby(); yield return "Salle d'attente";
            BuildReception(); yield return "Accueil";
            BuildConsultRoom(); yield return "Cabinet de consultation";
            BuildBreakRoom(); yield return "Salle de pause";
            BuildExterior(); yield return "Extérieur";
            BuildSalon(); yield return "Salon (SAMU)";
            BuildErBox(); yield return "Box des urgences";
            kit.FlushArchitecture(outsideRoot); yield return "Rue";
            BuildNavigation(); yield return "Navigation";
            BuildLighting(); yield return "Éclairage";
            BuildCameraShots();
        }

        // ================================================================== Sols, plafonds

        void BuildFloorsAndCeilings()
        {
            float H = L.WallHeight;
            // Sols (le dessus est à y = 0)
            kit.ArchBox(pal.Laminate, V(0f, -0.1f, 0f), V(L.MaxX, 0f, L.PartitionZ));
            kit.ArchBox(pal.Vinyl, V(0f, -0.1f, L.PartitionZ), V(L.ConsultMaxX, 0f, L.MaxZ));
            kit.ArchBox(pal.VinylBreak, V(L.ConsultMaxX, -0.1f, L.PartitionZ), V(L.BreakMaxX, 0f, L.MaxZ));
            kit.ArchBox(pal.Vinyl, V(L.BreakMaxX, -0.1f, L.PartitionZ), V(L.MaxX, 0f, L.MaxZ));
            // Seuil d'entrée
            kit.ArchBox(pal.Steel, V(L.EntranceX0, -0.1f, -L.ExteriorThickness), V(L.EntranceX1, 0.004f, 0f));

            // Plafonds
            kit.ArchBox(pal.Ceiling, V(0f, H, 0f), V(L.MaxX, H + 0.05f, L.MaxZ));
            // Toiture + acrotère
            float e = L.ExteriorThickness;
            kit.ArchBox(pal.Roof, V(-e, H + 0.05f, -e), V(L.MaxX + e, H + 0.32f, L.MaxZ + e));
            kit.ArchBox(pal.Plaster, V(-e - 0.02f, H + 0.32f, -e - 0.02f), V(L.MaxX + e + 0.02f, H + 0.62f, -e + 0.2f));
            kit.ArchBox(pal.Plaster, V(-e - 0.02f, H + 0.32f, L.MaxZ + e - 0.2f), V(L.MaxX + e + 0.02f, H + 0.62f, L.MaxZ + e + 0.02f));
            kit.ArchBox(pal.Plaster, V(-e - 0.02f, H + 0.32f, -e), V(-e + 0.2f, H + 0.62f, L.MaxZ + e));
            kit.ArchBox(pal.Plaster, V(L.MaxX + e - 0.2f, H + 0.32f, -e), V(L.MaxX + e + 0.02f, H + 0.62f, L.MaxZ + e));

            // Sol physique global + limites invisibles du terrain
            WorldKit.Collider(archRoot, "Ground", V(7.5f, -0.5f, 5f), V(80f, 1f, 80f));
            WorldKit.Collider(archRoot, "Bound_S", V(7.5f, 2f, -9.2f), V(60f, 4f, 0.4f));
            WorldKit.Collider(archRoot, "Bound_N", V(7.5f, 2f, 21f), V(60f, 4f, 0.4f));
            WorldKit.Collider(archRoot, "Bound_W", V(-9f, 2f, 6f), V(0.4f, 4f, 40f));
            WorldKit.Collider(archRoot, "Bound_E", V(24f, 2f, 6f), V(0.4f, 4f, 40f));
        }

        // ================================================================== Murs

        struct Opening
        {
            public float A0, A1, Bottom, Top;
            public Opening(float a0, float a1, float bottom, float top) { A0 = a0; A1 = a1; Bottom = bottom; Top = top; }
        }

        static readonly Opening[] None = new Opening[0];

        // Ouvertures des murs extérieurs (fenêtres : allège 0.9 m, linteau 2.35 m)
        static readonly Opening[] SouthOpenings =
        {
            new Opening(1.0f, 3.4f, 0.9f, 2.35f), new Opening(4.4f, 6.8f, 0.9f, 2.35f), new Opening(7.6f, 9.8f, 0.9f, 2.35f),
            new Opening(L.EntranceX0, L.EntranceX1, 0f, L.EntranceTop)
        };
        static readonly Opening[] WestOpenings = { new Opening(2.0f, 4.6f, 0.9f, 2.35f), new Opening(8.2f, 11.2f, 0.85f, 2.35f) };
        static readonly Opening[] NorthOpenings = { new Opening(2.0f, 4.6f, 0.85f, 2.35f), new Opening(8.4f, 10.6f, 0.95f, 2.35f) };
        static readonly Opening[] EastOpenings = { new Opening(1.0f, 2.6f, 0.9f, 2.35f) };

        void BuildWalls()
        {
            float e = L.ExteriorThickness, t = L.InteriorThickness * 0.5f;
            const float paintDepth = 0.05f;

            // --- Murs extérieurs : couche intérieure peinte + couche extérieure enduite
            // Sud (z = 0)
            WallX(-e, 0f, -e, L.MaxX + e, SouthOpenings, (min, max) =>
            {
                kit.ArchBox(pal.Plaster, min, new Vector3(max.x, max.y, -paintDepth));
                kit.ArchBox(pal.Wall, new Vector3(min.x, min.y, -paintDepth), max);
            });
            // Nord (z = MaxZ)
            WallX(L.MaxZ, L.MaxZ + e, -e, L.MaxX + e, NorthOpenings, (min, max) =>
            {
                kit.ArchBox(pal.Wall, min, new Vector3(max.x, max.y, L.MaxZ + paintDepth));
                kit.ArchBox(pal.Plaster, new Vector3(min.x, min.y, L.MaxZ + paintDepth), max);
            });
            // Ouest (x = 0)
            WallZ(-e, 0f, 0f, L.MaxZ, WestOpenings, (min, max) =>
            {
                kit.ArchBox(pal.Plaster, min, new Vector3(-paintDepth, max.y, max.z));
                kit.ArchBox(pal.Wall, new Vector3(-paintDepth, min.y, min.z), max);
            });
            // Est (x = MaxX)
            WallZ(L.MaxX, L.MaxX + e, 0f, L.MaxZ, EastOpenings, (min, max) =>
            {
                kit.ArchBox(pal.Wall, min, new Vector3(L.MaxX + paintDepth, max.y, max.z));
                kit.ArchBox(pal.Plaster, new Vector3(L.MaxX + paintDepth, min.y, min.z), max);
            });

            // --- Cloisons intérieures
            var partition = new[]
            {
                new Opening(L.ConsultDoorX - L.ConsultDoorW * 0.5f, L.ConsultDoorX + L.ConsultDoorW * 0.5f, 0f, L.DoorHeight),
                new Opening(L.BreakDoorX - L.BreakDoorW * 0.5f, L.BreakDoorX + L.BreakDoorW * 0.5f, 0f, L.DoorHeight),
                new Opening(L.WcDoorX - L.WcDoorW * 0.5f, L.WcDoorX + L.WcDoorW * 0.5f, 0f, L.DoorHeight),
            };
            WallX(L.PartitionZ - t, L.PartitionZ + t, 0f, L.MaxX, partition, (min, max) => kit.ArchBox(pal.Wall, min, max));
            WallZ(L.ConsultMaxX - t, L.ConsultMaxX + t, L.PartitionZ + t, L.MaxZ, None, (min, max) => kit.ArchBox(pal.Wall, min, max));
            WallZ(L.BreakMaxX - t, L.BreakMaxX + t, L.PartitionZ + t, L.MaxZ, None, (min, max) => kit.ArchBox(pal.Wall, min, max));

            // --- Murs d'accent (fines couches de peinture colorée, sans z-fighting)
            const float skin = 0.006f;
            // Salle d'attente : mur nord (côté accueil/attente) en vert sauge, sauf la zone accueil en bleu nuit
            AccentX(pal.AccentSage, L.PartitionZ - t - skin, L.PartitionZ - t, 0f, L.BreakDoorX - L.BreakDoorW * 0.5f, partition);
            AccentX(pal.AccentNavy, L.PartitionZ - t - skin, L.PartitionZ - t, L.BreakMaxX, L.MaxX, partition);
            // Cabinet : mur est (table d'examen) en bleu-vert doux
            AccentZ(pal.AccentTeal, L.ConsultMaxX - t - skin, L.ConsultMaxX - t, L.PartitionZ + t, L.MaxZ);

            // --- Plinthes
            Baseboards();
        }

        delegate void SegmentFn(Vector3 min, Vector3 max);

        /// <summary>Mur parallèle à X (épaisseur sur Z), découpé autour des ouvertures.</summary>
        void WallX(float z0, float z1, float x0, float x1, Opening[] openings, SegmentFn fn)
        {
            float H = L.WallHeight;
            var list = new List<Opening>(openings);
            list.Sort((a, b) => a.A0.CompareTo(b.A0));
            float cursor = x0;
            foreach (var o in list)
            {
                if (o.A0 > cursor) SegX(fn, cursor, o.A0, 0f, H, z0, z1);
                if (o.Bottom > 0f) SegX(fn, o.A0, o.A1, 0f, o.Bottom, z0, z1);
                if (o.Top < H) SegX(fn, o.A0, o.A1, o.Top, H, z0, z1);
                cursor = Mathf.Max(cursor, o.A1);
            }
            if (cursor < x1) SegX(fn, cursor, x1, 0f, H, z0, z1);
        }

        void SegX(SegmentFn fn, float xa, float xb, float y0, float y1, float z0, float z1)
        {
            var min = new Vector3(xa, y0, z0);
            var max = new Vector3(xb, y1, z1);
            fn(min, max);
            WorldKit.Collider(archRoot, "WallCol", (min + max) * 0.5f, max - min);
        }

        /// <summary>Mur parallèle à Z (épaisseur sur X).</summary>
        void WallZ(float x0, float x1, float z0, float z1, Opening[] openings, SegmentFn fn)
        {
            float H = L.WallHeight;
            var list = new List<Opening>(openings);
            list.Sort((a, b) => a.A0.CompareTo(b.A0));
            float cursor = z0;
            foreach (var o in list)
            {
                if (o.A0 > cursor) SegZ(fn, cursor, o.A0, 0f, H, x0, x1);
                if (o.Bottom > 0f) SegZ(fn, o.A0, o.A1, 0f, o.Bottom, x0, x1);
                if (o.Top < H) SegZ(fn, o.A0, o.A1, o.Top, H, x0, x1);
                cursor = Mathf.Max(cursor, o.A1);
            }
            if (cursor < z1) SegZ(fn, cursor, z1, 0f, H, x0, x1);
        }

        void SegZ(SegmentFn fn, float za, float zb, float y0, float y1, float x0, float x1)
        {
            var min = new Vector3(x0, y0, za);
            var max = new Vector3(x1, y1, zb);
            fn(min, max);
            WorldKit.Collider(archRoot, "WallCol", (min + max) * 0.5f, max - min);
        }

        void AccentX(Material m, float z0, float z1, float x0, float x1, Opening[] openings)
        {
            float H = L.WallHeight;
            float cursor = x0;
            var list = new List<Opening>(openings);
            list.Sort((a, b) => a.A0.CompareTo(b.A0));
            foreach (var o in list)
            {
                if (o.A1 <= x0 || o.A0 >= x1) continue;
                if (o.A0 > cursor) kit.ArchBox(m, V(cursor, 0f, z0), V(o.A0, H, z1));
                if (o.Top < H) kit.ArchBox(m, V(Mathf.Max(o.A0, x0), o.Top, z0), V(Mathf.Min(o.A1, x1), H, z1));
                cursor = Mathf.Max(cursor, o.A1);
            }
            if (cursor < x1) kit.ArchBox(m, V(cursor, 0f, z0), V(x1, H, z1));
        }

        void AccentZ(Material m, float x0, float x1, float z0, float z1)
        {
            kit.ArchBox(m, V(x0, 0f, z0), V(x1, L.WallHeight, z1));
        }

        void Baseboards()
        {
            const float h = 0.08f, d = 0.014f;
            float t = L.InteriorThickness * 0.5f;
            Material b = pal.Baseboard;
            float cd0 = L.ConsultDoorX - L.ConsultDoorW * 0.5f - 0.06f, cd1 = L.ConsultDoorX + L.ConsultDoorW * 0.5f + 0.06f;
            float bd0 = L.BreakDoorX - L.BreakDoorW * 0.5f - 0.06f, bd1 = L.BreakDoorX + L.BreakDoorW * 0.5f + 0.06f;
            float wd0 = L.WcDoorX - L.WcDoorW * 0.5f - 0.06f, wd1 = L.WcDoorX + L.WcDoorW * 0.5f + 0.06f;

            // Accueil / attente
            kit.ArchBox(b, V(0f, 0f, 0f), V(L.EntranceX0, h, d));
            kit.ArchBox(b, V(L.EntranceX1, 0f, 0f), V(L.MaxX, h, d));
            kit.ArchBox(b, V(0f, 0f, 0f), V(d, h, L.PartitionZ - t));
            kit.ArchBox(b, V(L.MaxX - d, 0f, 0f), V(L.MaxX, h, L.PartitionZ - t));
            float zl = L.PartitionZ - t - 0.006f;
            kit.ArchBox(b, V(0f, 0f, zl - d), V(cd0, h, zl));
            kit.ArchBox(b, V(cd1, 0f, zl - d), V(bd0, h, zl));
            kit.ArchBox(b, V(bd1, 0f, zl - d), V(wd0, h, zl));
            kit.ArchBox(b, V(wd1, 0f, zl - d), V(L.MaxX, h, zl));

            // Cabinet
            float zc = L.PartitionZ + t;
            kit.ArchBox(b, V(0f, 0f, zc), V(cd0, h, zc + d));
            kit.ArchBox(b, V(cd1, 0f, zc), V(L.ConsultMaxX - t, h, zc + d));
            kit.ArchBox(b, V(0f, 0f, L.MaxZ - d), V(L.ConsultMaxX - t, h, L.MaxZ));
            kit.ArchBox(b, V(0f, 0f, zc), V(d, h, L.MaxZ));
            kit.ArchBox(b, V(L.ConsultMaxX - t - 0.006f - d, 0f, zc), V(L.ConsultMaxX - t - 0.006f, h, L.MaxZ));

            // Salle de pause
            kit.ArchBox(b, V(L.ConsultMaxX + t, 0f, zc), V(bd0, h, zc + d));
            kit.ArchBox(b, V(bd1, 0f, zc), V(L.BreakMaxX - t, h, zc + d));
            kit.ArchBox(b, V(L.ConsultMaxX + t, 0f, L.MaxZ - d), V(L.BreakMaxX - t, h, L.MaxZ));
            kit.ArchBox(b, V(L.ConsultMaxX + t, 0f, zc), V(L.ConsultMaxX + t + d, h, L.MaxZ));
            kit.ArchBox(b, V(L.BreakMaxX - t - d, 0f, zc), V(L.BreakMaxX - t, h, L.MaxZ));
        }
    }
}
