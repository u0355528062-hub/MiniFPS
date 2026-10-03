using System.Collections.Generic;
using BlouseBlanche.Medical;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    /// <summary>
    /// Main du médecin (manche de blouse) tenant l'outil sélectionné, attachée à la caméra.
    /// Animation : balancement léger, geste vers le patient pendant un examen.
    /// </summary>
    public sealed class HeldToolView : MonoBehaviour
    {
        Transform pivot;
        readonly Dictionary<MedicalTool, GameObject> models = new Dictionary<MedicalTool, GameObject>();
        GameObject hand;
        MedicalTool? current;
        float show;          // 0 caché .. 1 visible
        float reach;         // 0 repos .. 1 tendu vers la cible
        float reachTarget;
        float swap;

        static readonly Vector3 RestPos = new Vector3(0.2f, -0.19f, 0.42f);
        static readonly Vector3 HiddenPos = new Vector3(0.26f, -0.5f, 0.36f);
        static readonly Vector3 ReachPos = new Vector3(0.07f, -0.1f, 0.5f);

        public void Build(WorldKit kit, Camera cam)
        {
            pivot = WorldKit.Group(cam.transform, "Main_Medecin", RestPos);
            var m = kit.Mat;
            Material coat = m.Lit("Blouse", new Color(0.95f, 0.96f, 0.97f), 0.2f, 0f, "Fabric", 0.6f, 0.2f);
            Material skin = m.Lit("SkinDoctor", new Color(0.90f, 0.72f, 0.58f), 0.36f, 0f, "Leather", 0.12f, 0.08f);
            Material chrome = m.Lit("ToolChrome", new Color(0.86f, 0.87f, 0.89f), 0.88f, 1f, "Metal", 0.2f);
            Material dark = m.Lit("ToolDark", new Color(0.08f, 0.09f, 0.1f), 0.55f);
            Material white = m.Lit("ToolWhite", new Color(0.93f, 0.94f, 0.95f), 0.6f);
            Material navy = m.Lit("ToolNavy", new Color(0.12f, 0.2f, 0.36f), 0.3f, 0f, "Fabric", 0.6f, 0.2f);
            Material red = m.Lit("ToolRed", new Color(0.75f, 0.12f, 0.12f), 0.4f);
            Material wood = m.Lit("ToolWood", new Color(0.86f, 0.74f, 0.55f), 0.25f);
            Material lcd = m.Emissive("ToolLcd", new Color(0.2f, 0.5f, 0.6f), new Color(0.3f, 0.9f, 1.0f) * 1.6f);
            Material light = m.Emissive("ToolLight", Color.white, new Color(1f, 0.95f, 0.85f) * 5f);

            // Main + manche (orientés pour tenir l'outil devant la caméra)
            hand = new GameObject("Main");
            hand.transform.SetParent(pivot, false);
            hand.transform.localRotation = Quaternion.Euler(-8f, -12f, 8f);
            kit.Part(hand.transform, "Manche", kit.Cached("sleeve", () => MeshFactory.TaperedCapsule(0.05f, 0.045f, 0.32f, 16, 4)), coat, new Vector3(0.02f, -0.02f, -0.12f), Quaternion.Euler(-80f, 0f, 0f), Vector3.one, false);
            kit.Part(hand.transform, "Poignet", kit.CylinderMesh(0.034f, 0.06f, 14), skin, new Vector3(0.02f, -0.02f, -0.02f), Quaternion.Euler(90f, 0f, 0f), Vector3.one, false);
            kit.Part(hand.transform, "Paume", kit.RoundedBoxMesh(new Vector3(0.085f, 0.03f, 0.09f), 0.014f, 2), skin, new Vector3(0.02f, -0.02f, 0.05f), Quaternion.identity, Vector3.one, false);
            for (int i = 0; i < 4; i++)
                kit.Part(hand.transform, "Doigt", kit.Cached("finger", () => MeshFactory.TaperedCapsule(0.0095f, 0.008f, 0.055f, 8, 3)), skin, new Vector3(-0.012f + i * 0.019f, -0.018f, 0.095f), Quaternion.Euler(-70f, 0f, 0f), Vector3.one, false);
            kit.Part(hand.transform, "Pouce", kit.Cached("thumbD", () => MeshFactory.TaperedCapsule(0.011f, 0.009f, 0.05f, 8, 3)), skin, new Vector3(-0.03f, -0.005f, 0.04f), Quaternion.Euler(-60f, 0f, 50f), Vector3.one, false);

            Transform T(MedicalTool t)
            {
                var g = new GameObject("Outil_" + t);
                g.transform.SetParent(pivot, false);
                g.transform.localPosition = new Vector3(0.0f, 0.0f, 0.1f);
                g.SetActive(false);
                models[t] = g;
                return g.transform;
            }

            var st = T(MedicalTool.Stethoscope);
            kit.Part(st, "Pavillon", kit.RoundedCylinderMesh(0.024f, 0.014f, 0.005f, 24), chrome, Vector3.zero, Quaternion.Euler(90f, 0f, 0f), Vector3.one, false);
            kit.Part(st, "Membrane", kit.CylinderMesh(0.02f, 0.002f, 20), dark, new Vector3(0f, 0f, 0.015f), Quaternion.Euler(90f, 0f, 0f), Vector3.one, false);
            var tube = new List<Vector3> { new Vector3(0f, 0.01f, -0.005f), new Vector3(0.01f, 0.06f, -0.05f), new Vector3(0.05f, 0.1f, -0.2f), new Vector3(0.12f, 0.08f, -0.45f) };
            kit.Part(st, "Tubulure", kit.Cached("stethoHeld", () => MeshFactory.Tube(tube, 0.005f, 8)), dark, Vector3.zero, Quaternion.identity, Vector3.one, false);

            var bp = T(MedicalTool.Tensiometre);
            kit.Part(bp, "Brassard", kit.RoundedBoxMesh(new Vector3(0.16f, 0.03f, 0.09f), 0.012f, 2), navy, new Vector3(0f, 0.01f, 0.02f), Quaternion.identity, Vector3.one, false);
            kit.Part(bp, "Poire", kit.SphereMesh(0.025f), dark, new Vector3(0.05f, -0.02f, -0.02f), Quaternion.identity, new Vector3(1f, 1.3f, 1f), false);
            kit.Part(bp, "Manometre", kit.RoundedCylinderMesh(0.03f, 0.015f, 0.005f, 24), chrome, new Vector3(-0.04f, 0.04f, 0.0f), Quaternion.Euler(70f, 0f, 0f), Vector3.one, false);

            var th = T(MedicalTool.Thermometre);
            kit.Part(th, "Corps", kit.RoundedBoxMesh(new Vector3(0.03f, 0.02f, 0.14f), 0.009f, 2), white, new Vector3(0f, 0f, 0.03f), Quaternion.identity, Vector3.one, false);
            kit.Part(th, "Embout", kit.RoundedBoxMesh(new Vector3(0.012f, 0.012f, 0.03f), 0.005f, 1), m.Lit("ToolGrey", new Color(0.6f, 0.62f, 0.65f), 0.6f), new Vector3(0f, 0f, 0.11f), Quaternion.identity, Vector3.one, false);
            kit.Part(th, "Ecran", kit.RoundedBoxMesh(new Vector3(0.018f, 0.002f, 0.03f), 0.001f, 1), lcd, new Vector3(0f, 0.011f, 0.0f), Quaternion.identity, Vector3.one, false);

            var ox = T(MedicalTool.Oxymetre);
            kit.Part(ox, "Pince", kit.RoundedBoxMesh(new Vector3(0.045f, 0.035f, 0.06f), 0.014f, 2), white, Vector3.zero, Quaternion.identity, Vector3.one, false);
            kit.Part(ox, "Ecran", kit.RoundedBoxMesh(new Vector3(0.03f, 0.002f, 0.022f), 0.001f, 1), lcd, new Vector3(0f, 0.018f, 0f), Quaternion.identity, Vector3.one, false);

            var ot = T(MedicalTool.Otoscope);
            kit.Part(ot, "Manche", kit.CylinderMesh(0.014f, 0.1f, 16), dark, new Vector3(0f, -0.1f, 0f), Quaternion.identity, Vector3.one, false);
            kit.Part(ot, "Tete", kit.RoundedBoxMesh(new Vector3(0.035f, 0.035f, 0.04f), 0.01f, 2), dark, new Vector3(0f, 0.015f, 0f), Quaternion.identity, Vector3.one, false);
            var cone = new List<Vector2> { new Vector2(0f, 0f), new Vector2(0.012f, 0f), new Vector2(0.004f, 0.045f), new Vector2(0f, 0.045f) };
            kit.Part(ot, "Speculum", kit.Cached("speculum", () => MeshFactory.Lathe(cone, 16)), white, new Vector3(0f, 0.015f, 0.02f), Quaternion.Euler(90f, 0f, 0f), Vector3.one, false);
            kit.Part(ot, "Lumiere", kit.SphereMesh(0.004f), light, new Vector3(0f, 0.015f, 0.066f), Quaternion.identity, Vector3.one, false);

            var ab = T(MedicalTool.AbaisseLangue);
            kit.Part(ab, "Abaisse", kit.RoundedBoxMesh(new Vector3(0.018f, 0.002f, 0.15f), 0.0009f, 1), wood, new Vector3(-0.02f, 0f, 0.05f), Quaternion.identity, Vector3.one, false);
            kit.Part(ab, "Lampe", kit.CylinderMesh(0.006f, 0.12f, 12), chrome, new Vector3(0.025f, 0.01f, -0.02f), Quaternion.Euler(90f, 0f, 0f), Vector3.one, false);
            kit.Part(ab, "Ampoule", kit.SphereMesh(0.0055f), light, new Vector3(0.025f, 0.01f, 0.1f), Quaternion.identity, Vector3.one, false);

            var ha = T(MedicalTool.Marteau);
            kit.Part(ha, "Manche", kit.CylinderMesh(0.005f, 0.2f, 10), chrome, new Vector3(0f, -0.08f, 0f), Quaternion.Euler(-20f, 0f, 0f), Vector3.one, false);
            kit.Part(ha, "Tete", kit.RoundedBoxMesh(new Vector3(0.012f, 0.03f, 0.08f), 0.006f, 2), red, new Vector3(0f, 0.11f, 0.04f), Quaternion.Euler(-20f, 0f, 0f), Vector3.one, false);

            var pf = T(MedicalTool.Debitmetre);
            kit.Part(pf, "Tube", kit.CylinderMesh(0.022f, 0.15f, 18), white, new Vector3(0f, 0f, -0.05f), Quaternion.Euler(90f, 0f, 0f), Vector3.one, false);
            kit.Part(pf, "Embout", kit.CylinderMesh(0.014f, 0.04f, 14), m.Lit("ToolBlue", new Color(0.3f, 0.55f, 0.85f), 0.6f), new Vector3(0f, 0f, 0.1f), Quaternion.Euler(90f, 0f, 0f), Vector3.one, false);
            kit.Part(pf, "Curseur", kit.RoundedBoxMesh(new Vector3(0.012f, 0.012f, 0.012f), 0.003f, 1), red, new Vector3(0f, 0.022f, 0.0f), Quaternion.identity, Vector3.one, false);

            var ecg = T(MedicalTool.ECG);
            kit.Part(ecg, "Appareil", kit.RoundedBoxMesh(new Vector3(0.16f, 0.025f, 0.11f), 0.01f, 2), white, Vector3.zero, Quaternion.Euler(-35f, 0f, 0f), Vector3.one, false);
            kit.Part(ecg, "Ecran", kit.RoundedBoxMesh(new Vector3(0.12f, 0.002f, 0.07f), 0.001f, 1), m.Decal("EcgScreen", "Monitor", 0.8f, 1.4f), new Vector3(0f, 0.014f, 0f), Quaternion.Euler(-35f, 0f, 0f), Vector3.one, false);

            var tr = T(MedicalTool.TestsRapides);
            kit.Part(tr, "Cassette", kit.RoundedBoxMesh(new Vector3(0.025f, 0.006f, 0.08f), 0.003f, 1), white, Vector3.zero, Quaternion.identity, Vector3.one, false);
            kit.Part(tr, "Fenetre", kit.RoundedBoxMesh(new Vector3(0.01f, 0.001f, 0.025f), 0.0005f, 1), m.Lit("ToolPink", new Color(0.95f, 0.85f, 0.88f), 0.4f), new Vector3(0f, 0.0035f, 0.01f), Quaternion.identity, Vector3.one, false);
            kit.Part(tr, "Trait", kit.RoundedBoxMesh(new Vector3(0.008f, 0.0012f, 0.0015f), 0.0004f, 1), red, new Vector3(0f, 0.0042f, 0.005f), Quaternion.identity, Vector3.one, false);

            var cb = T(MedicalTool.Balance);
            kit.Part(cb, "Planchette", kit.RoundedBoxMesh(new Vector3(0.16f, 0.006f, 0.22f), 0.004f, 1), m.Lit("Clipboard", new Color(0.35f, 0.24f, 0.16f), 0.4f), Vector3.zero, Quaternion.Euler(-40f, 0f, 0f), Vector3.one, false);
            kit.Part(cb, "Feuille", kit.QuadMesh(0.14f, 0.19f), m.Decal("ClipPaper", "Paper", 0.2f), new Vector3(0f, 0.002f, 0.0f), Quaternion.Euler(-130f, 0f, 0f), Vector3.one, false);

            models[MedicalTool.Mains] = null;
            pivot.localPosition = HiddenPos;
            pivot.gameObject.SetActive(false);
        }

        public void Show(MedicalTool? tool)
        {
            if (pivot == null) return;
            if (tool == current && pivot.gameObject.activeSelf) return;
            current = tool;
            swap = 1f;
            foreach (var kv in models) if (kv.Value != null) kv.Value.SetActive(tool.HasValue && kv.Key == tool.Value);
            if (tool.HasValue) pivot.gameObject.SetActive(true);
        }

        public void Hide()
        {
            current = null;
        }

        public void Reach(bool on) => reachTarget = on ? 1f : 0f;

        void LateUpdate()
        {
            if (pivot == null) return;
            float dt = Time.unscaledDeltaTime;
            float target = current.HasValue ? 1f : 0f;
            swap = Mathf.MoveTowards(swap, 0f, dt * 4f);
            show = Mathf.MoveTowards(show, target * (1f - swap * 0.6f), dt * 3.5f);
            reach = Mathf.MoveTowards(reach, reachTarget, dt * 2.5f);
            float s = show * show * (3f - 2f * show);
            float r = reach * reach * (3f - 2f * reach);
            float t = Time.unscaledTime;
            Vector3 sway = new Vector3(Mathf.Sin(t * 1.1f) * 0.004f, Mathf.Sin(t * 1.7f) * 0.003f, 0f);
            Vector3 rest = Vector3.Lerp(RestPos, ReachPos, r) + sway;
            pivot.localPosition = Vector3.Lerp(HiddenPos, rest, s);
            pivot.localRotation = Quaternion.Euler(Mathf.Lerp(18f, 0f, s) - r * 10f, -r * 12f, 0f);
            if (show <= 0.001f && !current.HasValue && pivot.gameObject.activeSelf) pivot.gameObject.SetActive(false);
        }
    }
}
