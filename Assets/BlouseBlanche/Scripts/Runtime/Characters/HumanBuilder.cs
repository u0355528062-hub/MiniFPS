using System.Collections.Generic;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Characters
{
    /// <summary>Squelette procédural : articulations + parties visibles.</summary>
    public sealed class HumanRig : MonoBehaviour
    {
        public HumanAppearance Look;
        public Transform Hips, Spine, Chest, Neck, Head;
        public Transform ShoulderL, ShoulderR, ElbowL, ElbowR, WristL, WristR;
        public Transform HipL, HipR, KneeL, KneeR, AnkleL, AnkleR;
        public Transform Torso, EyeL, EyeR, Mouth;
        public float StandHipHeight, LegLength, ThighRadius, HeadHeight, Height, Torso_Length;

        /// <summary>Point de visée de la tête (pour les regards et la caméra).</summary>
        public Vector3 HeadCenter => Head != null ? Head.TransformPoint(new Vector3(0f, HeadHeight * 0.55f, HeadHeight * 0.1f)) : transform.position + Vector3.up * Height;
        public Vector3 ChestCenter => Chest != null ? Chest.TransformPoint(new Vector3(0f, Torso_Length * 0.2f, Torso_Length * 0.15f)) : transform.position + Vector3.up * Height * 0.7f;
        public Vector3 BellyCenter => Spine != null ? Spine.TransformPoint(new Vector3(0f, Torso_Length * 0.25f, Torso_Length * 0.18f)) : transform.position + Vector3.up * Height * 0.55f;
    }

    /// <summary>
    /// Construit un humain stylisé "mannequin haut de gamme" : volumes lissés, visage (yeux, sourcils,
    /// nez, bouche, oreilles), coiffures, barbe, lunettes et vêtements. Proportions selon l'âge et le sexe.
    /// </summary>
    public static class HumanBuilder
    {
        static Vector3 V(float x, float y, float z) => new Vector3(x, y, z);
        static Vector2 V2(float x, float y) => new Vector2(x, y);

        static string Hex(Color c) => ColorUtility.ToHtmlStringRGB(c);
        static float R3(float v) => Mathf.Round(v * 1000f) / 1000f;

        public static HumanRig Build(WorldKit kit, Transform parent, HumanAppearance a, string name)
        {
            var root = new GameObject(name);
            root.transform.SetParent(parent, false);
            var rig = root.AddComponent<HumanRig>();
            rig.Look = a;

            var m = kit.Mat;
            Material skin = m.Lit("Skin_" + Hex(a.Skin), a.Skin, 0.36f, 0f, "Leather", 0.12f, 0.08f);
            Material hair = m.Lit("Hair_" + Hex(a.Hair), a.Hair, 0.32f, 0f, "Fabric", 0.7f, 0.1f);
            Material top = m.Lit("Cloth_" + Hex(a.TopColor), a.TopColor, 0.12f, 0f, "Fabric", 0.9f, 0.25f);
            Material accent = m.Lit("Cloth_" + Hex(a.TopAccent), a.TopAccent, 0.12f, 0f, "Fabric", 0.9f, 0.25f);
            Material pants = m.Lit("Cloth_" + Hex(a.Pants), a.Pants, 0.14f, 0f, "Fabric", 1.0f, 0.2f);
            Material shoes = m.Lit("Shoe_" + Hex(a.Shoes), a.Shoes, 0.5f, 0f, "Leather", 0.5f, 0.2f);
            Material eyeWhite = m.Lit("EyeWhite", new Color(0.95f, 0.95f, 0.93f), 0.8f);
            Material iris = m.Lit("Iris_" + Hex(a.Iris), a.Iris * 0.8f, 0.92f);
            Color lipC = Color.Lerp(a.Skin * 0.78f, new Color(0.65f, 0.25f, 0.25f), 0.35f);
            Material lips = m.Lit("Lip_" + Hex(lipC), lipC, 0.45f);
            Material frame = m.Lit("GlassesFrame", new Color(0.08f, 0.08f, 0.09f), 0.6f, 0.3f);

            float H = a.Height;
            bool child = a.IsChild;
            bool female = a.Sex == Sex.Femme;
            float k = H / 1.75f;
            float b = a.Build;
            float headH = child ? H / 5.6f : H / 7.6f;
            float legLen = child ? 0.46f * H : 0.53f * H;
            float neckLen = 0.042f * H;
            float torso = H - legLen - headH - neckLen;
            float shoulderW = (female ? 0.098f : 0.112f) * H * Mathf.Lerp(1f, b, 0.5f) * (child ? 0.95f : 1f);
            float hipW = (female ? 0.06f : 0.052f) * H * Mathf.Lerp(1f, b, 0.4f);
            float upperArm = 0.172f * H, forearm = 0.15f * H;
            float thigh = legLen * 0.48f, shin = legLen * 0.45f, ankleH = legLen * 0.07f;
            float thighTop = 0.083f * k * b, thighBot = 0.055f * k * Mathf.Sqrt(b);
            float shinTop = 0.052f * k * Mathf.Sqrt(b), shinBot = 0.04f * k;
            float armTop = 0.047f * k * Mathf.Pow(b, 0.7f), armBot = 0.038f * k;
            float foreTop = 0.037f * k, foreBot = 0.029f * k;
            float depth = female ? 0.6f : 0.58f;

            rig.Height = H;
            rig.LegLength = legLen;
            rig.StandHipHeight = legLen;
            rig.ThighRadius = thighTop;
            rig.HeadHeight = headH;
            rig.Torso_Length = torso;

            bool longSleeves = a.Top != TopStyle.TShirt;

            // ---------------------------------------------------------------- articulations
            Transform J(string n, Transform p, Vector3 pos)
            {
                var t = new GameObject(n).transform;
                t.SetParent(p, false);
                t.localPosition = pos;
                return t;
            }
            rig.Hips = J("Bassin", root.transform, V(0f, legLen, 0f));
            rig.Spine = J("Colonne", rig.Hips, Vector3.zero);
            rig.Chest = J("Thorax", rig.Spine, V(0f, torso * 0.5f, 0f));
            rig.Neck = J("Cou", rig.Chest, V(0f, torso * 0.5f, 0f));
            rig.Head = J("Tete", rig.Neck, V(0f, neckLen, 0f));
            rig.ShoulderL = J("Epaule_G", rig.Chest, V(-(shoulderW + armTop * 0.35f), torso * 0.42f, 0f));
            rig.ShoulderR = J("Epaule_D", rig.Chest, V(shoulderW + armTop * 0.35f, torso * 0.42f, 0f));
            rig.ElbowL = J("Coude_G", rig.ShoulderL, V(0f, -upperArm, 0f));
            rig.ElbowR = J("Coude_D", rig.ShoulderR, V(0f, -upperArm, 0f));
            rig.WristL = J("Poignet_G", rig.ElbowL, V(0f, -forearm, 0f));
            rig.WristR = J("Poignet_D", rig.ElbowR, V(0f, -forearm, 0f));
            rig.HipL = J("Hanche_G", rig.Hips, V(-hipW, -0.02f * k, 0f));
            rig.HipR = J("Hanche_D", rig.Hips, V(hipW, -0.02f * k, 0f));
            rig.KneeL = J("Genou_G", rig.HipL, V(0f, -thigh, 0f));
            rig.KneeR = J("Genou_D", rig.HipR, V(0f, -thigh, 0f));
            rig.AnkleL = J("Cheville_G", rig.KneeL, V(0f, -shin, 0f));
            rig.AnkleR = J("Cheville_D", rig.KneeR, V(0f, -shin, 0f));

            GameObject P(Transform p, string n, Mesh mesh, Material mat, Vector3 pos, Quaternion rot, Vector3 scale)
                => kit.Part(p, n, mesh, mat, pos, rot, scale);
            GameObject Ell(Transform p, string n, Material mat, Vector3 center, Vector3 diameters)
                => kit.Part(p, n, kit.SphereMesh(0.5f, 12, 18), mat, center, Quaternion.identity, diameters);

            // ---------------------------------------------------------------- torse
            var prof = female
                ? new List<Vector2> { V2(0f, -0.07f), V2(0.74f, -0.06f), V2(0.80f, 0.0f), V2(0.76f, 0.10f), V2(0.64f, 0.30f), V2(0.74f, 0.52f), V2(0.84f, 0.70f), V2(0.86f, 0.82f), V2(0.80f, 0.90f), V2(0.58f, 0.96f), V2(0.30f, 1.0f), V2(0f, 1.02f) }
                : new List<Vector2> { V2(0f, -0.07f), V2(0.70f, -0.06f), V2(0.76f, 0.0f), V2(0.78f, 0.10f), V2(0.74f, 0.28f), V2(0.80f, 0.50f), V2(0.88f, 0.70f), V2(0.92f, 0.82f), V2(0.86f, 0.90f), V2(0.62f, 0.96f), V2(0.32f, 1.0f), V2(0f, 1.02f) };
            for (int i = 0; i < prof.Count; i++)
            {
                var p = prof[i];
                if (p.y > 0.05f && p.y < 0.6f) p.x *= 1f + (b - 1f) * 0.9f;
                prof[i] = new Vector2(p.x * shoulderW, p.y * torso);
            }
            string torsoKey = "torso_" + (female ? "f" : "m") + R3(shoulderW) + "_" + R3(torso) + "_" + R3(b);
            var torsoMesh = kit.Cached(torsoKey, () => MeshFactory.Lathe(prof, 28));
            rig.Torso = P(rig.Spine, "Torse", torsoMesh, top, Vector3.zero, Quaternion.identity, V(1f, 1f, depth)).transform;
            if (female && !child)
                Ell(rig.Torso, "Poitrine", top, V(0f, torso * 0.66f, shoulderW * 0.55f), V(shoulderW * 1.5f, torso * 0.24f, shoulderW * 0.5f / depth));
            if (b > 1.08f && !child)
                Ell(rig.Torso, "Ventre", top, V(0f, torso * 0.3f, shoulderW * 0.66f), V(shoulderW * 1.45f, torso * 0.42f, shoulderW * (b - 0.8f) / depth));

            // Détails de vêtement
            switch (a.Top)
            {
                case TopStyle.Chemise:
                    P(rig.Neck, "Col", kit.Cached("collar" + R3(k), () => MeshFactory.Torus(0.052f * k, 0.012f * k, 24, 6)), accent, V(0f, -0.005f, 0.005f), Quaternion.Euler(-12f, 0f, 0f), Vector3.one);
                    break;
                case TopStyle.Gilet:
                    kit.Part(rig.Torso, "Gilet_Ouverture", kit.RoundedBoxMesh(V(shoulderW * 0.22f, torso * 0.8f, 0.02f), 0.008f), accent, V(0f, torso * 0.45f, shoulderW * 0.8f * (1f + (b - 1f) * 0.9f)), Quaternion.identity, V(1f, 1f, 1f / depth));
                    break;
                case TopStyle.Veste:
                    foreach (float s in new[] { -1f, 1f })
                        kit.Part(rig.Torso, "Revers", kit.RoundedBoxMesh(V(shoulderW * 0.25f, torso * 0.42f, 0.02f), 0.008f), accent, V(s * shoulderW * 0.2f, torso * 0.68f, shoulderW * 0.9f), Quaternion.Euler(0f, 0f, s * 14f), V(1f, 1f, 1f / depth));
                    break;
            }

            // Bassin (pantalon)
            Ell(rig.Hips, "Bassin", pants, V(0f, -0.01f * k, 0f), V((hipW + thighTop) * 2.05f, torso * 0.28f, shoulderW * 2f * depth * (female ? 1.05f : 0.98f)));

            // ---------------------------------------------------------------- bras
            var upperMesh = kit.Cached("arm_" + R3(armTop) + R3(armBot) + R3(upperArm), () => MeshFactory.TaperedCapsule(armTop, armBot, upperArm, 14, 4));
            var foreMesh = kit.Cached("fore_" + R3(foreTop) + R3(foreBot) + R3(forearm), () => MeshFactory.TaperedCapsule(foreTop, foreBot, forearm, 14, 4));
            var sleeveMesh = kit.Cached("sleeve_" + R3(armTop) + R3(upperArm), () => MeshFactory.TaperedCapsule(armTop * 1.2f, armTop * 1.1f, upperArm * 0.42f, 14, 3));
            var handMesh = kit.RoundedBoxMesh(V(0.028f * k, 0.095f * k, 0.075f * k), 0.012f * k, 2);
            var thumbMesh = kit.Cached("thumb" + R3(k), () => MeshFactory.TaperedCapsule(0.011f * k, 0.009f * k, 0.035f * k, 8, 3));
            foreach (var side in new[] { -1f, 1f })
            {
                Transform sh = side < 0 ? rig.ShoulderL : rig.ShoulderR;
                Transform el = side < 0 ? rig.ElbowL : rig.ElbowR;
                Transform wr = side < 0 ? rig.WristL : rig.WristR;
                kit.Part(sh, "Moignon", kit.SphereMesh(armTop * 1.15f, 10, 14), top, V(side * 0.004f, 0.004f, 0f));
                kit.Part(sh, "Bras", upperMesh, longSleeves ? top : skin, Vector3.zero);
                if (!longSleeves) kit.Part(sh, "Manche", sleeveMesh, top, Vector3.zero);
                kit.Part(el, "AvantBras", foreMesh, longSleeves ? top : skin, Vector3.zero);
                if (longSleeves) kit.Part(wr, "Poignet", kit.CylinderMesh(foreBot * 1.02f, 0.03f * k, 14), skin, V(0f, -0.004f, 0f));
                kit.Part(wr, "Main", handMesh, skin, V(0f, -0.052f * k, 0.004f));
                kit.Part(wr, "Pouce", thumbMesh, skin, V(-side * 0.012f * k, -0.022f * k, 0.03f * k), Quaternion.Euler(-35f, 0f, side * 18f), Vector3.one);
            }

            // ---------------------------------------------------------------- jambes
            var thighMesh = kit.Cached("thigh_" + R3(thighTop) + R3(thighBot) + R3(thigh), () => MeshFactory.TaperedCapsule(thighTop, thighBot, thigh, 16, 4));
            var shinMesh = kit.Cached("shin_" + R3(shinTop) + R3(shinBot) + R3(shin), () => MeshFactory.TaperedCapsule(shinTop, shinBot, shin, 16, 4));
            float shoeH = 0.075f * k;
            var shoeMesh = kit.RoundedBoxMesh(V(0.095f * k, shoeH, 0.26f * k), 0.03f * k, 3);
            foreach (var side in new[] { -1f, 1f })
            {
                Transform hp = side < 0 ? rig.HipL : rig.HipR;
                Transform kn = side < 0 ? rig.KneeL : rig.KneeR;
                Transform an = side < 0 ? rig.AnkleL : rig.AnkleR;
                kit.Part(hp, "Cuisse", thighMesh, pants, Vector3.zero);
                kit.Part(kn, "Jambe", shinMesh, pants, Vector3.zero);
                kit.Part(an, "Chaussure", shoeMesh, shoes, V(0f, -ankleH + shoeH * 0.5f, 0.055f * k));
                kit.Part(an, "Semelle", kit.RoundedBoxMesh(V(0.1f * k, 0.014f * k, 0.265f * k), 0.006f * k, 2), m.Lit("Sole", new Color(0.12f, 0.12f, 0.12f), 0.3f), V(0f, -ankleH + 0.007f * k, 0.055f * k));
            }

            // ---------------------------------------------------------------- cou, tête
            kit.Part(rig.Neck, "Cou", kit.CylinderMesh(0.047f * k * (child ? 0.9f : 1f), neckLen + 0.03f * k, 16), skin, V(0f, -0.015f * k, -0.004f));
            Transform head = rig.Head;
            float h = headH;
            Ell(head, "Crane", skin, V(0f, h * 0.55f, -h * 0.03f), V(h * 0.68f, h * 0.9f, h * 0.84f));
            Ell(head, "Machoire", skin, V(0f, h * 0.28f, h * 0.07f), V(h * 0.54f, h * 0.54f, h * 0.66f));
            Ell(head, "Nez", skin, V(0f, h * 0.45f, h * 0.41f), V(h * 0.1f, h * 0.2f, h * 0.14f));
            foreach (float s in new[] { -1f, 1f })
                Ell(head, "Oreille", skin, V(s * h * 0.34f, h * 0.52f, -h * 0.02f), V(h * 0.06f, h * 0.22f, h * 0.14f));

            // Yeux (groupés pour le clignement)
            Transform Eye(float s)
            {
                var g = J(s < 0 ? "Oeil_G" : "Oeil_D", head, V(s * h * 0.14f, h * 0.56f, h * 0.37f));
                kit.Part(g, "Blanc", kit.SphereMesh(h * 0.055f, 10, 14), eyeWhite, Vector3.zero, false);
                kit.Part(g, "Iris", kit.SphereMesh(h * 0.032f, 8, 12), iris, V(0f, 0f, h * 0.038f), false);
                return g;
            }
            rig.EyeL = Eye(-1f);
            rig.EyeR = Eye(1f);
            foreach (float s in new[] { -1f, 1f })
                kit.Part(head, "Sourcil", kit.RoundedBoxMesh(V(h * 0.13f, h * 0.024f, h * 0.03f), h * 0.01f, 2), hair, V(s * h * 0.14f, h * 0.665f, h * 0.385f), Quaternion.Euler(0f, 0f, -s * 6f), Vector3.one);
            rig.Mouth = kit.Part(head, "Bouche", kit.RoundedBoxMesh(V(h * 0.16f, h * 0.026f, h * 0.04f), h * 0.012f, 2), lips, V(0f, h * 0.31f, h * 0.385f), false).transform;

            // Coiffure
            switch (a.HairStyle)
            {
                case HairStyle.Court:
                    Ell(head, "Cheveux", hair, V(0f, h * 0.66f, -h * 0.1f), V(h * 0.74f, h * 0.8f, h * 0.94f));
                    break;
                case HairStyle.Rase:
                    Ell(head, "Cheveux", hair, V(0f, h * 0.64f, -h * 0.09f), V(h * 0.71f, h * 0.76f, h * 0.9f));
                    break;
                case HairStyle.Carre:
                    Ell(head, "Cheveux", hair, V(0f, h * 0.66f, -h * 0.1f), V(h * 0.76f, h * 0.82f, h * 0.95f));
                    Ell(head, "Carre", hair, V(0f, h * 0.45f, -h * 0.13f), V(h * 0.8f, h * 0.64f, h * 0.92f));
                    break;
                case HairStyle.Long:
                    Ell(head, "Cheveux", hair, V(0f, h * 0.66f, -h * 0.1f), V(h * 0.76f, h * 0.82f, h * 0.95f));
                    kit.Part(head, "Longueurs", kit.RoundedBoxMesh(V(h * 0.66f, h * 0.85f, h * 0.16f), h * 0.07f, 3), hair, V(0f, h * 0.15f, -h * 0.3f));
                    break;
                case HairStyle.Chignon:
                    Ell(head, "Cheveux", hair, V(0f, h * 0.66f, -h * 0.1f), V(h * 0.74f, h * 0.8f, h * 0.94f));
                    kit.Part(head, "Chignon", kit.SphereMesh(h * 0.16f, 10, 14), hair, V(0f, h * 0.84f, -h * 0.42f));
                    break;
                case HairStyle.QueueDeCheval:
                    Ell(head, "Cheveux", hair, V(0f, h * 0.66f, -h * 0.1f), V(h * 0.74f, h * 0.8f, h * 0.94f));
                    kit.Part(head, "Queue", kit.Cached("pony" + R3(h), () => MeshFactory.TaperedCapsule(h * 0.08f, h * 0.045f, h * 0.8f, 10, 3)), hair, V(0f, h * 0.62f, -h * 0.47f), Quaternion.Euler(14f, 0f, 0f), Vector3.one);
                    break;
                case HairStyle.Boucle:
                    Ell(head, "Boucles", hair, V(0f, h * 0.72f, -h * 0.16f), V(h * 0.92f, h * 0.88f, h * 1.04f));
                    break;
                case HairStyle.Degarni:
                    var arc = MeshFactory.Arc(V(0f, h * 0.55f, -h * 0.06f), Vector3.right, Vector3.back, h * 0.34f, -12f, 192f, 18);
                    kit.Part(head, "Couronne", kit.Cached("fringe" + R3(h), () => MeshFactory.Tube(arc, h * 0.075f, 8)), hair, Vector3.zero);
                    break;
            }
            if (a.Beard) Ell(head, "Barbe", hair, V(0f, h * 0.22f, h * 0.14f), V(h * 0.58f, h * 0.4f, h * 0.6f));
            if (a.Moustache) kit.Part(head, "Moustache", kit.RoundedBoxMesh(V(h * 0.18f, h * 0.04f, h * 0.05f), h * 0.018f, 2), hair, V(0f, h * 0.365f, h * 0.395f));
            if (a.Glasses)
            {
                var ring = kit.Cached("glassRing" + R3(h), () => MeshFactory.Torus(h * 0.075f, h * 0.008f, 20, 5));
                foreach (float s in new[] { -1f, 1f })
                {
                    kit.Part(head, "Monture", ring, frame, V(s * h * 0.14f, h * 0.56f, h * 0.45f), Quaternion.Euler(90f, 0f, 0f), Vector3.one, false);
                    kit.Part(head, "Branche", kit.RoundedBoxMesh(V(h * 0.012f, h * 0.012f, h * 0.42f), h * 0.004f, 1), frame, V(s * h * 0.325f, h * 0.57f, h * 0.24f), false);
                }
                kit.Part(head, "Pont", kit.RoundedBoxMesh(V(h * 0.06f, h * 0.012f, h * 0.012f), h * 0.004f, 1), frame, V(0f, h * 0.58f, h * 0.45f), false);
            }

            // Collider d'interaction (déclencheur : ne bloque personne)
            var col = root.AddComponent<CapsuleCollider>();
            col.isTrigger = true;
            col.radius = 0.32f * Mathf.Max(0.7f, k);
            col.height = H * 0.85f;
            col.center = V(0f, H * 0.42f, 0f);
            return rig;
        }
    }
}
