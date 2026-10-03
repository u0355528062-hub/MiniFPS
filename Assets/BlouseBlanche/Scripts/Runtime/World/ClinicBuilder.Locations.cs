using System.Collections.Generic;
using BlouseBlanche.Core;
using UnityEngine;
using UnityEngine.Rendering;

namespace BlouseBlanche.World
{
    /// <summary>Lieu d'intervention des prototypes SAMU / urgences.</summary>
    public sealed class EmergencyLocation
    {
        public string Name;
        public Vector3 Origin;
        public Bounds Bounds;
        public Vector3 PatientPelvis;
        public float PatientYaw;
        public float LieHeight;
        public float Incline;
        public Vector3 WitnessPos;
        public float WitnessYaw;
        public Pose CareShot;
        public Vector3 PlayerSpawn;
        public float PlayerYaw;
        public Pose[] MenuShots = new Pose[0];
        public Transform Root;
    }

    public sealed partial class ClinicBuilder
    {
        public static readonly Vector3 SalonOrigin = new Vector3(120f, 0f, 0f);
        public static readonly Vector3 ErOrigin = new Vector3(120f, 0f, 30f);

        /// <summary>Pièce fermée (sol, murs, plafond, colliders). Les ouvertures sont sur le mur nord (fenêtre) et est/sud (porte).</summary>
        void Room(Vector3 o, float sx, float sz, float h, Material floor, Material wall, Material ceiling, float winX0, float winX1, float sill, float lintel, bool doorSouth, float doorA0, float doorA1)
        {
            const float t = 0.15f;
            kit.ArchBox(floor, o + V(-t, -0.1f, -t), o + V(sx + t, 0f, sz + t));
            kit.ArchBox(ceiling, o + V(-t, h, -t), o + V(sx + t, h + 0.08f, sz + t));
            kit.ArchBox(pal.Roof, o + V(-t - 0.05f, h + 0.08f, -t - 0.05f), o + V(sx + t + 0.05f, h + 0.3f, sz + t + 0.05f));
            void Seg(Vector3 a, Vector3 b)
            {
                kit.ArchBox(wall, a, b);
                WorldKit.Collider(archRoot, "WallCol", (a + b) * 0.5f, b - a);
            }
            // Nord (fenêtre éventuelle)
            if (winX1 > winX0)
            {
                Seg(o + V(-t, 0f, sz), o + V(winX0, h, sz + t));
                Seg(o + V(winX1, 0f, sz), o + V(sx + t, h, sz + t));
                Seg(o + V(winX0, 0f, sz), o + V(winX1, sill, sz + t));
                Seg(o + V(winX0, lintel, sz), o + V(winX1, h, sz + t));
            }
            else Seg(o + V(-t, 0f, sz), o + V(sx + t, h, sz + t));
            // Ouest
            Seg(o + V(-t, 0f, 0f), o + V(0f, h, sz));
            // Sud et est (porte sur l'un des deux)
            if (doorSouth)
            {
                Seg(o + V(-t, 0f, -t), o + V(doorA0, h, 0f));
                Seg(o + V(doorA1, 0f, -t), o + V(sx + t, h, 0f));
                Seg(o + V(doorA0, 2.15f, -t), o + V(doorA1, h, 0f));
                Seg(o + V(sx, 0f, 0f), o + V(sx + t, h, sz));
            }
            else
            {
                Seg(o + V(-t, 0f, -t), o + V(sx + t, h, 0f));
                Seg(o + V(sx, 0f, 0f), o + V(sx + t, h, doorA0));
                Seg(o + V(sx, 0f, doorA1), o + V(sx + t, h, sz));
                Seg(o + V(sx, 2.1f, doorA0), o + V(sx + t, h, doorA1));
            }
            WorldKit.Collider(archRoot, "Sol", o + V(sx * 0.5f, -0.5f, sz * 0.5f), V(sx + 2f, 1f, sz + 2f));
        }

        Light PointLight(Transform parent, Vector3 pos, Color c, float intensity, float range, bool shadows)
        {
            var go = new GameObject("Lumiere");
            go.transform.SetParent(parent, false);
            go.transform.position = pos;
            var l = go.AddComponent<Light>();
            l.type = LightType.Point;
            l.color = c;
            l.intensity = intensity;
            l.range = range;
            l.shadows = shadows ? LightShadows.Soft : LightShadows.None;
            l.shadowStrength = 0.8f;
            l.shadowBias = 0.03f;
            world.AllLights.Add(l);
            if (shadows) world.ShadowedLights.Add(l);
            return l;
        }

        Light SpotDown(Transform parent, Vector3 pos, Color c, float intensity, float range, float angle, bool shadows)
        {
            var go = new GameObject("Spot");
            go.transform.SetParent(parent, false);
            go.transform.position = pos;
            go.transform.rotation = Quaternion.Euler(90f, 0f, 0f);
            var l = go.AddComponent<Light>();
            l.type = LightType.Spot;
            l.color = c;
            l.intensity = intensity;
            l.range = range;
            l.spotAngle = angle;
            l.innerSpotAngle = angle * 0.5f;
            l.shadows = shadows ? LightShadows.Soft : LightShadows.None;
            l.shadowStrength = 0.75f;
            l.shadowBias = 0.03f;
            l.shadowNormalBias = 0.4f;
            world.AllLights.Add(l);
            if (shadows) world.ShadowedLights.Add(l);
            return l;
        }

        // ================================================================== Salon (SAMU)

        void BuildSalon()
        {
            Vector3 o = SalonOrigin;
            const float sx = 6.5f, sz = 5.5f, h = 2.6f;
            var root = WorldKit.Group(propsRoot, "Salon_SAMU", o);
            var wallpaper = kit.Mat.Lit("Wallpaper", Color.white, 0.12f, 0f, "Wallpaper", 0.4f);
            var accent = kit.Mat.Lit("SalonAccent", new Color(0.28f, 0.38f, 0.32f), 0.12f, 0f, "Paint", 0.5f);
            var sofaFabric = kit.Mat.Lit("SofaFabric", new Color(0.36f, 0.42f, 0.52f), 0.1f, 0f, "Fabric", 1f, 0.3f);
            var curtain = kit.Mat.Lit("Curtain", new Color(0.80f, 0.72f, 0.58f), 0.08f, 0f, "Fabric", 0.8f, 0.4f);
            var parquet = kit.Mat.Lit("SalonParquet", new Color(0.92f, 0.86f, 0.80f), 0.5f, 0f, "Laminate", 0.9f);

            Room(o, sx, sz, h, parquet, wallpaper, pal.Ceiling, 2.2f, 4.6f, 0.85f, 2.2f, false, 0.8f, 1.7f);
            kit.ArchBox(accent, o + V(0f, 0f, 0.02f), o + V(0.006f, h, sz - 0.02f));
            // Plinthes
            kit.ArchBox(pal.Baseboard, o + V(0f, 0f, 0f), o + V(sx, 0.08f, 0.014f));
            kit.ArchBox(pal.Baseboard, o + V(0f, 0f, sz - 0.014f), o + V(sx, 0.08f, sz));
            kit.ArchBox(pal.Baseboard, o + V(0.006f, 0f, 0f), o + V(0.02f, 0.08f, sz));

            // Fenêtre + rideaux
            var win = WorldKit.Group(root, "Fenetre", V(3.4f, 1.525f, sz + 0.075f));
            kit.Box(win, "Cadre_H", V(2.4f, 0.06f, 0.08f), pal.DoorFrame, V(0f, 0.645f, 0f), 0.004f);
            kit.Box(win, "Cadre_B", V(2.4f, 0.06f, 0.08f), pal.DoorFrame, V(0f, -0.645f, 0f), 0.004f);
            kit.Box(win, "Cadre_G", V(0.06f, 1.35f, 0.08f), pal.DoorFrame, V(-1.17f, 0f, 0f), 0.004f);
            kit.Box(win, "Cadre_D", V(0.06f, 1.35f, 0.08f), pal.DoorFrame, V(1.17f, 0f, 0f), 0.004f);
            kit.Box(win, "Meneau", V(0.05f, 1.3f, 0.07f), pal.DoorFrame, V(0f, 0f, 0f), 0.004f);
            var g = kit.Box(win, "Vitre", V(2.3f, 1.25f, 0.01f), pal.Glass, Vector3.zero, 0.001f, false, null, false);
            g.GetComponent<MeshRenderer>().shadowCastingMode = ShadowCastingMode.Off;
            WorldKit.Collider(win, "Col", Vector3.zero, V(2.4f, 1.35f, 0.08f));
            for (int i = 0; i < 2; i++)
            {
                float x = i == 0 ? 1.85f : 4.95f;
                var md = new MeshData();
                for (int k = 0; k < 7; k++)
                    md.Append(MeshFactory.RoundedBox(V(0.11f, 2.35f, 0.06f), 0.03f, 2), V(-0.33f + k * 0.11f, 0f, Mathf.Sin(k * 1.7f) * 0.03f));
                kit.Part(root, "Rideau", kit.FromData("curtain" + i, md), curtain, V(x, 1.22f, sz - 0.12f));
            }
            kit.Cylinder(root, "Tringle", 0.012f, 3.8f, pal.BlackMetal, V(1.5f, 2.42f, sz - 0.1f), 10, true, Quaternion.Euler(0f, 0f, -90f));
            kit.Box(root, "Tablette", V(2.5f, 0.03f, 0.2f), pal.DoorFrame, V(3.4f, 0.835f, sz - 0.08f), 0.006f);
            Radiator(root, V(3.4f, 0.12f, sz - 0.05f), 180f, 1.8f);

            // Porte d'entrée (fermée, mur est)
            var door = WorldKit.Group(root, "Porte", V(sx, 0f, 1.25f), 90f);
            kit.Box(door, "Battant", V(0.88f, 2.06f, 0.045f), pal.DoorWood, V(0f, 1.04f, -0.02f), 0.006f, true);
            kit.Box(door, "Poignee", V(0.12f, 0.02f, 0.02f), pal.Steel, V(0.32f, 1.02f, -0.06f), 0.006f);

            // Canapé
            var sofa = WorldKit.Group(root, "Canape", V(0.55f, 0f, 2.8f), 90f);
            kit.Box(sofa, "Base", V(2.1f, 0.3f, 0.9f), sofaFabric, V(0f, 0.25f, 0f), 0.05f, true);
            for (int i = 0; i < 3; i++) kit.Box(sofa, "Coussin", V(0.66f, 0.14f, 0.7f), sofaFabric, V(-0.68f + i * 0.68f, 0.47f, 0.06f), 0.06f);
            kit.Box(sofa, "Dossier", V(2.1f, 0.5f, 0.22f), sofaFabric, V(0f, 0.62f, -0.36f), 0.08f);
            foreach (float x in new[] { -1.1f, 1.1f }) kit.Box(sofa, "Accoudoir", V(0.2f, 0.55f, 0.9f), sofaFabric, V(x, 0.42f, 0f), 0.07f);
            kit.Box(sofa, "Plaid", V(0.6f, 0.04f, 0.75f), curtain, V(0.55f, 0.56f, 0.05f), 0.02f, false, Quaternion.Euler(0f, 12f, 4f));
            foreach (var p in new[] { V(-0.95f, 0f, 0.35f), V(0.95f, 0f, 0.35f), V(-0.95f, 0f, -0.35f), V(0.95f, 0f, -0.35f) })
                kit.Cylinder(sofa, "Pied", 0.025f, 0.1f, pal.Walnut, p, 10);

            // Fauteuil, table basse, tapis, meuble TV
            var arm = WorldKit.Group(root, "Fauteuil", V(1.6f, 0f, 4.55f), 150f);
            kit.Box(arm, "Assise", V(0.8f, 0.42f, 0.8f), sofaFabric, V(0f, 0.25f, 0f), 0.06f, true);
            kit.Box(arm, "Dossier", V(0.8f, 0.5f, 0.2f), sofaFabric, V(0f, 0.65f, -0.32f), 0.07f);
            foreach (float x in new[] { -0.4f, 0.4f }) kit.Box(arm, "Accoudoir", V(0.16f, 0.5f, 0.8f), sofaFabric, V(x, 0.42f, 0f), 0.06f);
            kit.Box(root, "Tapis", V(2.8f, 0.012f, 2.0f), pal.FabricRug, V(3.0f, 0.006f, 2.6f), 0.005f, false, null, false);
            var table = WorldKit.Group(root, "Table_Basse", V(1.85f, 0f, 2.8f), 90f);
            kit.Box(table, "Plateau", V(1.0f, 0.04f, 0.55f), pal.Walnut, V(0f, 0.4f, 0f), 0.01f, true);
            kit.Box(table, "Tablette", V(0.9f, 0.02f, 0.45f), pal.Walnut, V(0f, 0.14f, 0f), 0.006f);
            foreach (var p in new[] { V(-0.45f, 0f, -0.22f), V(0.45f, 0f, -0.22f), V(-0.45f, 0f, 0.22f), V(0.45f, 0f, 0.22f) })
                kit.Box(table, "Pied", V(0.04f, 0.38f, 0.04f), pal.Walnut, p + V(0f, 0.19f, 0f), 0.006f);
            Mug(table, V(0.2f, 0.42f, 0.1f));
            Magazine(table, V(-0.2f, 0.423f, -0.05f), 20f, 1);
            var tv = WorldKit.Group(root, "Meuble_TV", V(sx - 0.3f, 0f, 3.2f), -90f);
            kit.Box(tv, "Meuble", V(1.6f, 0.45f, 0.42f), pal.Oak, V(0f, 0.225f, 0f), 0.01f, true);
            Screen(tv, "Tv", V(0f, 1.05f, -0.05f), 0f, 1.1f, 0.62f, 1.4f);
            kit.Box(tv, "Pied_TV", V(0.3f, 0.02f, 0.18f), pal.PlasticDark, V(0f, 0.46f, -0.04f), 0.006f);
            Plant(root, V(sx - 0.45f, 0f, sz - 0.5f), 1.3f, 61, true);
            Plant(root, V(0.45f, 0f, 0.45f), 0.9f, 63);
            Bookshelf(root, V(3.2f, 0f, 0.17f + 0.02f), 0f, 1.6f, 1.9f, 77);

            // Lampadaire
            var lamp = WorldKit.Group(root, "Lampadaire", V(0.45f, 0f, 4.6f));
            kit.Part(lamp, "Socle", kit.RoundedCylinderMesh(0.16f, 0.025f, 0.01f), pal.BlackMetal, Vector3.zero);
            kit.Cylinder(lamp, "Mat", 0.014f, 1.55f, pal.BlackMetal, V(0f, 0.02f, 0f), 10);
            var shade = new List<Vector2> { V2(0.13f, 0f), V2(0.13f, 0f), V2(0.2f, 0.28f), V2(0.2f, 0.28f), V2(0.19f, 0.28f), V2(0.125f, 0.005f) };
            kit.Part(lamp, "Abat_Jour", kit.Cached("floorShade", () => MeshFactory.Lathe(shade, 28)), kit.Mat.Emissive("ShadeGlow", new Color(0.95f, 0.88f, 0.75f), new Color(1f, 0.75f, 0.45f) * 0.9f), V(0f, 1.5f, 0f));
            PointLight(root, o + V(0.45f, 1.55f, 4.6f), new Color(1f, 0.78f, 0.52f), 2.2f, 5f, false);

            // Suspension centrale
            var pend = WorldKit.Group(root, "Suspension", V(3.0f, h, 2.7f));
            kit.Cylinder(pend, "Fil", 0.004f, 0.6f, pal.BlackMetal, V(0f, -0.6f, 0f), 6);
            var dome = new List<Vector2> { V2(0f, 0.18f), V2(0.05f, 0.18f), V2(0.28f, 0f), V2(0.28f, 0f), V2(0.27f, 0f), V2(0.045f, 0.17f), V2(0f, 0.17f) };
            kit.Part(pend, "Abat_Jour", kit.Cached("pendant", () => MeshFactory.Lathe(dome, 32)), pal.BlackMetal, V(0f, -0.78f, 0f));
            kit.Part(pend, "Ampoule", kit.SphereMesh(0.05f), kit.Mat.Emissive("BulbWarm", Color.white, new Color(1f, 0.82f, 0.6f) * 8f), V(0f, -0.74f, 0f), false);
            SpotDown(root, o + V(3.0f, h - 0.85f, 2.7f), new Color(1f, 0.82f, 0.62f), 4.5f, 6f, 120f, true);
            WindowFill(root, o + V(3.4f, 2.0f, sz - 0.4f), Vector3.back, 2.4f);

            // Décor : cadres, photo, horloge
            Frame(root, "Art0", V(0.02f, 1.6f, 2.8f), 90f, 0.9f, 0.68f, pal.BlackMetal);
            Frame(root, "Art1", V(5.2f, 1.55f, 0.02f), 0f, 0.6f, 0.45f, pal.Oak);
            Frame(root, "FamilyPhoto", V(sx - 0.02f, 1.55f, 4.4f), -90f, 0.34f, 0.26f, pal.Gold);
            Clock(root, V(4.4f, 2.0f, 0.02f), 0f, 0.14f);

            // Chaise renversée (le malaise) et matériel du SMUR posé au sol
            var chair = WoodChair(root, V(5.4f, 0.22f, 2.4f), 70f, pal.FabricMustard);
            chair.localRotation = Quaternion.Euler(0f, 70f, 88f);
            var bag = WorldKit.Group(root, "Sac_SMUR", V(4.45f, 0f, 1.25f), 20f);
            kit.Box(bag, "Sac", V(0.6f, 0.32f, 0.35f), kit.Mat.Lit("SamuOrange", new Color(0.92f, 0.35f, 0.12f), 0.3f, 0f, "Fabric", 0.7f, 0.2f), V(0f, 0.16f, 0f), 0.06f, true);
            kit.Box(bag, "Bande", V(0.62f, 0.04f, 0.36f), kit.Mat.Lit("Reflect", new Color(0.85f, 0.85f, 0.8f), 0.8f, 0.3f), V(0f, 0.2f, 0f), 0.01f);
            var defib = WorldKit.Group(root, "Defibrillateur", V(4.35f, 0f, 3.15f), -30f);
            kit.Box(defib, "Corps", V(0.32f, 0.26f, 0.22f), kit.Mat.Lit("DefibYellow", new Color(0.95f, 0.78f, 0.15f), 0.5f), V(0f, 0.13f, 0f), 0.03f, true);
            kit.Box(defib, "Ecran", V(0.16f, 0.1f, 0.005f), kit.Mat.Decal("DefibScreen", "ScopeScreen", 0.8f, 1.6f), V(0f, 0.17f, 0.111f), 0.002f);
            var o2 = WorldKit.Group(root, "Bouteille_O2", V(4.95f, 0f, 2.75f));
            kit.Part(o2, "Bouteille", kit.Cached("o2Bottle", () => MeshFactory.Lathe(new List<Vector2> { V2(0f, 0f), V2(0.08f, 0f), V2(0.08f, 0f), V2(0.08f, 0.5f), V2(0.05f, 0.58f), V2(0.025f, 0.62f), V2(0f, 0.62f) }, 20)), kit.Mat.Lit("O2White", new Color(0.92f, 0.93f, 0.92f), 0.6f), V(0.3f, 0.08f, 0f), Quaternion.Euler(0f, 0f, 90f), Vector3.one);

            // Extérieur visible par la fenêtre
            kit.ArchMesh(pal.Grass, MeshFactory.PlaneXZ(60f, 40f, 2, 2), o + V(3f, -0.03f, 18f), Quaternion.identity);
            Hedge(root, V(-3f, 0f, sz + 3.5f), V(10f, 0f, sz + 3.5f));
            Tree(root, V(1.0f, 0f, sz + 6f), 1.1f, 81);
            Tree(root, V(6.0f, 0f, sz + 8f), 1.3f, 82);
            Tree(root, V(-2.5f, 0f, sz + 9f), 1.0f, 83);

            Probe("Sonde_Salon", o + V(sx * 0.5f, h * 0.5f, sz * 0.5f), V(sx, h, sz));
            world.Salon = new EmergencyLocation
            {
                Name = "Salon",
                Origin = o,
                Root = root,
                Bounds = new Bounds(o + V(sx * 0.5f, h * 0.5f, sz * 0.5f), V(sx, h, sz)),
                PatientPelvis = o + V(3.25f, 0f, 2.15f),
                PatientYaw = -90f,
                LieHeight = 0.02f,
                WitnessPos = o + V(4.85f, 0f, 3.8f),
                WitnessYaw = -140f,
                CareShot = ClinicWorld.LookPose(o + V(3.7f, 1.05f, 1.2f), o + V(3.75f, 0.12f, 2.15f)),
                PlayerSpawn = o + V(sx - 0.7f, 0f, 1.25f),
                PlayerYaw = -90f,
                MenuShots = new[]
                {
                    ClinicWorld.LookPose(o + V(5.9f, 1.6f, 0.6f), o + V(2.5f, 0.4f, 3.2f)),
                    ClinicWorld.LookPose(o + V(5.4f, 1.5f, 1.0f), o + V(2.4f, 0.4f, 3.0f)),
                }
            };
        }

        // ================================================================== Box des urgences

        void BuildErBox()
        {
            Vector3 o = ErOrigin;
            const float sx = 5.0f, sz = 5.2f, h = 2.9f;
            var root = WorldKit.Group(propsRoot, "Box_Urgences", o);
            var hospFloor = kit.Mat.Lit("HospitalFloor", new Color(0.86f, 0.92f, 0.90f), 0.5f, 0f, "Vinyl", 0.4f);
            var hospWall = kit.Mat.Lit("HospitalWall", new Color(0.92f, 0.95f, 0.95f), 0.15f, 0f, "Paint", 0.4f);
            var mattress = kit.Mat.Lit("Mattress", new Color(0.35f, 0.55f, 0.72f), 0.45f, 0f, "Leather", 0.4f);
            var sheet = kit.Mat.Lit("Sheet", new Color(0.95f, 0.96f, 0.97f), 0.12f, 0f, "Fabric", 0.5f, 0.3f);
            var curtainMat = kit.Mat.Lit("HospCurtain", new Color(0.55f, 0.75f, 0.78f), 0.08f, 0f, "Fabric", 0.8f, 0.4f);
            var red = kit.Mat.Lit("CartRed", new Color(0.75f, 0.12f, 0.12f), 0.5f);

            Room(o, sx, sz, h, hospFloor, hospWall, pal.Ceiling, 0f, 0f, 0f, 0f, true, 1.9f, 3.1f);
            // Lisse de protection murale
            kit.ArchBox(pal.PlasticGrey, o + V(0f, 0.85f, 0f), o + V(0.03f, 1.0f, sz));
            kit.ArchBox(pal.PlasticGrey, o + V(sx - 0.03f, 0.85f, 0f), o + V(sx, 1.0f, sz));
            kit.ArchBox(pal.Baseboard, o + V(0f, 0f, sz - 0.014f), o + V(sx, 0.1f, sz));

            // Porte vitrée dépolie
            var door = WorldKit.Group(root, "Porte_Vitree", V(2.5f, 0f, -0.07f));
            kit.Box(door, "Cadre", V(1.22f, 2.15f, 0.06f), pal.Steel, V(0f, 1.075f, 0f), 0.006f);
            kit.Box(door, "Vitre", V(1.1f, 2.0f, 0.03f), pal.GlassFrosted, V(0f, 1.07f, 0.01f), 0.004f, true, null, false);
            Poster(door, "SignBox", V(0f, 1.6f, 0.03f), 0f, 0.36f, 0.11f);

            // Lit d'hôpital (tête au nord)
            var bed = WorldKit.Group(root, "Lit", V(2.5f, 0f, 2.95f));
            kit.Box(bed, "Chassis", V(0.95f, 0.12f, 2.1f), pal.PlasticWhite, V(0f, 0.5f, 0f), 0.02f, true);
            kit.Box(bed, "Base", V(0.7f, 0.08f, 1.7f), pal.PlasticGrey, V(0f, 0.18f, 0f), 0.02f);
            kit.Box(bed, "Colonne", V(0.2f, 0.32f, 0.3f), pal.PlasticGrey, V(0f, 0.34f, 0f), 0.02f);
            foreach (var p in new[] { V(-0.35f, 0f, 0.8f), V(0.35f, 0f, 0.8f), V(-0.35f, 0f, -0.8f), V(0.35f, 0f, -0.8f) })
            {
                kit.Part(bed, "Roue", kit.RoundedCylinderMesh(0.06f, 0.04f, 0.015f, 16), pal.PlasticDark, p + V(-0.02f, 0.06f, 0f), Quaternion.Euler(0f, 0f, 90f), Vector3.one);
                kit.Box(bed, "Fourche", V(0.03f, 0.12f, 0.06f), pal.Chrome, p + V(0f, 0.12f, 0f), 0.006f);
            }
            kit.Box(bed, "Matelas_Bas", V(0.88f, 0.16f, 1.3f), mattress, V(0f, 0.64f, -0.38f), 0.05f);
            var back = WorldKit.Group(bed, "Dossier", V(0f, 0.64f, 0.27f));
            back.localRotation = Quaternion.Euler(-30f, 0f, 0f);
            kit.Box(back, "Matelas_Haut", V(0.88f, 0.16f, 0.8f), mattress, V(0f, 0f, 0.4f), 0.05f);
            kit.Box(back, "Oreiller", V(0.6f, 0.12f, 0.36f), sheet, V(0f, 0.12f, 0.6f), 0.05f);
            kit.Box(bed, "Drap", V(0.9f, 0.02f, 1.2f), sheet, V(0f, 0.73f, -0.42f), 0.01f);
            kit.Box(bed, "Tete", V(0.95f, 0.6f, 0.06f), pal.PlasticWhite, V(0f, 0.85f, 1.06f), 0.03f);
            kit.Box(bed, "Pied", V(0.95f, 0.45f, 0.06f), pal.PlasticWhite, V(0f, 0.75f, -1.06f), 0.03f);
            foreach (float x in new[] { -0.5f, 0.5f })
            {
                var rail = new List<Vector3> { V(x, 0.62f, 0.75f), V(x, 0.95f, 0.65f), V(x, 0.95f, -0.25f), V(x, 0.62f, -0.35f) };
                kit.Part(bed, "Barriere", kit.FromData("bedRail" + x, MeshFactory.Tube(rail, 0.014f, 8)), pal.Chrome, Vector3.zero);
            }

            // Panneau de gaz médicaux (tête de lit)
            var gas = WorldKit.Group(root, "Gaz_Medicaux", V(2.5f, 1.45f, sz - 0.05f), 180f);
            kit.Box(gas, "Rampe", V(2.4f, 0.22f, 0.08f), pal.PlasticWhite, Vector3.zero, 0.02f);
            Material[] outlets = { kit.Mat.Lit("GasO2", new Color(0.2f, 0.7f, 0.3f), 0.5f), kit.Mat.Lit("GasAir", new Color(0.12f, 0.12f, 0.12f), 0.5f), kit.Mat.Lit("GasVac", new Color(0.95f, 0.8f, 0.15f), 0.5f) };
            for (int i = 0; i < 3; i++)
                kit.Part(gas, "Prise", kit.RoundedCylinderMesh(0.035f, 0.03f, 0.008f, 16), outlets[i], V(-0.8f + i * 0.2f, 0f, 0.04f), Quaternion.Euler(90f, 0f, 0f), Vector3.one);
            for (int i = 0; i < 4; i++) kit.Box(gas, "Prise_Elec", V(0.08f, 0.08f, 0.02f), pal.PlasticWhite, V(0.35f + i * 0.14f, 0f, 0.05f), 0.01f);
            kit.Part(gas, "Debitmetre", kit.CylinderMesh(0.02f, 0.16f, 12), pal.Glass, V(-0.8f, -0.2f, 0.07f), false);
            kit.Box(gas, "Applique", V(2.2f, 0.06f, 0.1f), pal.LightPanel, V(0f, 0.55f, 0.03f), 0.01f, false, null, false);

            // Scope sur bras articulé
            var scope = WorldKit.Group(root, "Scope", V(3.75f, 1.85f, sz - 0.25f), 205f);
            kit.Box(scope, "Bras", V(0.06f, 0.06f, 0.4f), pal.PlasticGrey, V(0f, 0f, -0.15f), 0.02f);
            kit.Box(scope, "Boitier", V(0.46f, 0.34f, 0.08f), pal.PlasticDark, V(0f, 0f, 0.1f), 0.02f);
            kit.Quad(scope, "Ecran", 0.42f, 0.27f, kit.Mat.Decal("Scope", "ScopeScreen", 0.85f, 1.8f), V(0f, 0.01f, 0.141f), Quaternion.identity);

            // Pied à perfusion
            var iv = WorldKit.Group(root, "Pied_Perfusion", V(3.35f, 0f, 3.9f));
            for (int i = 0; i < 5; i++)
            {
                var q = Quaternion.Euler(0f, i * 72f, 0f);
                kit.Box(iv, "Branche", V(0.03f, 0.02f, 0.28f), pal.Chrome, q * V(0f, 0.05f, 0.14f), 0.006f, false, q);
            }
            kit.Cylinder(iv, "Mat", 0.012f, 1.9f, pal.Chrome, V(0f, 0.05f, 0f), 10);
            kit.Box(iv, "Crochet", V(0.3f, 0.015f, 0.015f), pal.Chrome, V(0f, 1.92f, 0f), 0.005f);
            kit.Box(iv, "Poche", V(0.12f, 0.2f, 0.03f), pal.Water, V(0.12f, 1.78f, 0f), 0.02f, false, null, false);
            var line = new List<Vector3> { V(0.12f, 1.66f, 0f), V(0.05f, 1.2f, -0.1f), V(-0.3f, 0.9f, -0.55f), V(-0.55f, 0.82f, -0.8f) };
            kit.Part(iv, "Tubulure", kit.Cached("ivLine", () => MeshFactory.Tube(line, 0.003f, 6)), pal.Water, Vector3.zero, false);
            var ivc = iv.gameObject.AddComponent<CapsuleCollider>();
            ivc.center = V(0f, 1f, 0f); ivc.radius = 0.15f; ivc.height = 2f;

            // Chariot d'urgence
            var cart = WorldKit.Group(root, "Chariot_Urgence", V(0.4f, 0f, 1.3f), 90f);
            kit.Box(cart, "Corps", V(0.75f, 0.95f, 0.55f), red, V(0f, 0.55f, 0f), 0.02f, true);
            for (int i = 0; i < 4; i++)
            {
                kit.Box(cart, "Tiroir", V(0.7f, 0.2f, 0.01f), red, V(0f, 0.25f + i * 0.22f, 0.28f), 0.006f);
                kit.Box(cart, "Poignee", V(0.3f, 0.02f, 0.02f), pal.Steel, V(0f, 0.32f + i * 0.22f, 0.295f), 0.006f);
            }
            kit.Box(cart, "Plateau", V(0.8f, 0.03f, 0.6f), pal.PlasticDark, V(0f, 1.04f, 0f), 0.01f);
            kit.Box(cart, "Defib", V(0.3f, 0.22f, 0.25f), kit.Mat.Lit("DefibGrey", new Color(0.3f, 0.32f, 0.35f), 0.5f), V(0.15f, 1.17f, 0f), 0.02f);
            kit.Quad(cart, "Defib_Ecran", 0.14f, 0.09f, kit.Mat.Decal("DefibScreen", "ScopeScreen", 0.8f, 1.6f), V(0.15f, 1.2f, 0.126f), Quaternion.identity);
            foreach (var p in new[] { V(-0.3f, 0f, 0.2f), V(0.3f, 0f, 0.2f), V(-0.3f, 0f, -0.2f), V(0.3f, 0f, -0.2f) })
                kit.Part(cart, "Roue", kit.SphereMesh(0.04f), pal.PlasticDark, p + V(0f, 0.04f, 0f));

            // Lavabo, distributeurs, DASRI
            var sink = WorldKit.Group(root, "Lavabo", V(0.25f, 0f, 3.9f), 90f);
            kit.Box(sink, "Vasque", V(0.6f, 0.2f, 0.45f), pal.Ceramic, V(0f, 0.85f, 0f), 0.06f, true);
            kit.Box(sink, "Credence", V(0.8f, 0.6f, 0.01f), pal.Tiles, V(0f, 1.25f, -0.22f), 0.002f);
            kit.Box(sink, "Gel", V(0.1f, 0.2f, 0.08f), pal.PlasticWhite, V(0.36f, 1.3f, -0.18f), 0.012f);
            kit.Box(sink, "Gants", V(0.25f, 0.13f, 0.1f), kit.Mat.Lit("GloveBox", new Color(0.45f, 0.55f, 0.9f), 0.4f), V(-0.3f, 1.45f, -0.17f), 0.01f);
            DasriBox(root, V(0.03f, 1.0f, 2.5f), 90f);
            TrashBin(root, V(0.5f, 0f, 4.7f), pal.Yellow);

            // Rideau de séparation
            var curt = new MeshData();
            for (int k = 0; k < 10; k++)
                curt.Append(MeshFactory.RoundedBox(V(0.13f, 2.0f, 0.04f), 0.02f, 2), V(k * 0.12f, 0f, Mathf.Sin(k * 1.9f) * 0.04f));
            kit.Part(root, "Rideau", kit.FromData("hospCurtain", curt), curtainMat, V(3.7f, 1.3f, 0.6f));
            kit.Cylinder(root, "Rail", 0.015f, 4.6f, pal.Steel, V(0.2f, 2.4f, 0.6f), 8, true, Quaternion.Euler(0f, 0f, -90f));

            // Chaise visiteur, tabouret, horloge
            WoodChair(root, V(4.4f, 0f, 1.1f), -30f, pal.FabricTeal);
            Clock(root, V(2.5f, 2.35f, 0.02f), 0f, 0.15f);
            Frame(root, "PosterHands", V(sx - 0.02f, 1.6f, 1.5f), -90f, 0.36f, 0.5f, pal.PlasticWhite);

            // Lumières froides + scialytique au-dessus du lit
            var lights = WorldKit.Group(root, "Lumieres", Vector3.zero);
            foreach (var p in new[] { V(1.4f, 0f, 1.8f), V(3.6f, 0f, 1.8f), V(2.5f, 0f, 4.2f) })
            {
                kit.Box(lights, "Dalle", V(0.62f, 0.02f, 0.62f), pal.LightPanel, V(p.x, h - 0.012f, p.z), 0.004f, false, null, false);
                SpotDown(root, o + V(p.x, h - 0.06f, p.z), new Color(0.92f, 0.96f, 1f), 3.6f, 7f, 150f, p.z > 4f);
            }
            var lamp = WorldKit.Group(root, "Scialytique", V(2.5f, h - 0.6f, 2.8f));
            kit.Cylinder(lamp, "Tige", 0.02f, 0.6f, pal.PlasticWhite, Vector3.zero, 10);
            kit.Part(lamp, "Tete", kit.RoundedCylinderMesh(0.24f, 0.08f, 0.03f, 32), pal.PlasticWhite, V(0f, -0.06f, 0f));
            kit.Part(lamp, "Optique", kit.CylinderMesh(0.2f, 0.005f, 32), kit.Mat.Emissive("ExamLight", Color.white, new Color(1f, 0.98f, 0.95f) * 2.5f), V(0f, -0.065f, 0f), false);
            SpotDown(root, o + V(2.5f, h - 0.72f, 2.8f), new Color(1f, 0.98f, 0.95f), 3.0f, 3.5f, 70f, true);

            Probe("Sonde_Box", o + V(sx * 0.5f, h * 0.5f, sz * 0.5f), V(sx, h, sz));
            world.ErBox = new EmergencyLocation
            {
                Name = "Box des urgences",
                Origin = o,
                Root = root,
                Bounds = new Bounds(o + V(sx * 0.5f, h * 0.5f, sz * 0.5f), V(sx, h, sz)),
                PatientPelvis = o + V(2.5f, 0f, 3.1f),
                PatientYaw = 180f,
                LieHeight = 0.72f,
                Incline = 30f,
                WitnessPos = o + V(4.3f, 0f, 1.6f),
                WitnessYaw = -30f,
                CareShot = ClinicWorld.LookPose(o + V(3.45f, 1.62f, 2.45f), o + V(2.5f, 1.0f, 3.45f)),
                PlayerSpawn = o + V(2.5f, 0f, 0.8f),
                PlayerYaw = 0f,
                MenuShots = new[]
                {
                    ClinicWorld.LookPose(o + V(4.5f, 1.7f, 0.5f), o + V(2.4f, 0.9f, 3.2f)),
                    ClinicWorld.LookPose(o + V(4.2f, 1.6f, 0.9f), o + V(2.4f, 0.9f, 3.0f)),
                }
            };
        }
    }
}
