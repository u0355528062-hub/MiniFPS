using BlouseBlanche.Core;
using UnityEngine;
using L = BlouseBlanche.World.ClinicLayout;

namespace BlouseBlanche.World
{
    public sealed partial class ClinicBuilder
    {
        // ================================================================== Portes

        void BuildDoors()
        {
            float t = L.InteriorThickness * 0.5f;
            var doors = WorldKit.Group(propsRoot, "Portes", Vector3.zero);

            // Cabinet : charnière côté est, s'ouvre vers le nord (dans la pièce)
            SwingDoor(doors, "Porte_Cabinet", L.ConsultDoorX, L.ConsultDoorW, L.PartitionZ, true, 90f, "SignConsult", false);
            // Salle de pause : charnière côté ouest
            SwingDoor(doors, "Porte_Pause", L.BreakDoorX, L.BreakDoorW, L.PartitionZ, false, -90f, "SignBreak", false);
            // WC : verrouillée (hors parcours du prototype)
            SwingDoor(doors, "Porte_WC", L.WcDoorX, L.WcDoorW, L.PartitionZ, false, -90f, "SignWc", true);

            // Encadrements des trois portes (des deux côtés de la cloison)
            DoorFrame(doors, L.ConsultDoorX, L.ConsultDoorW, L.PartitionZ, t);
            DoorFrame(doors, L.BreakDoorX, L.BreakDoorW, L.PartitionZ, t);
            DoorFrame(doors, L.WcDoorX, L.WcDoorW, L.PartitionZ, t);

            EntranceDoor(doors);
        }

        void SwingDoor(Transform parent, string name, float centerX, float width, float z, bool hingeEast, float openAngle, string sign, bool locked)
        {
            float panelW = width - 0.02f, panelH = L.DoorHeight - 0.015f, thick = 0.042f;
            float hingeX = hingeEast ? centerX + width * 0.5f - 0.01f : centerX - width * 0.5f + 0.01f;
            var group = WorldKit.Group(parent, name, V(hingeX, 0f, z));
            var hinge = WorldKit.Group(group, "Charniere", Vector3.zero);
            float dir = hingeEast ? -1f : 1f; // le battant s'étend de la charnière vers le centre
            Vector3 panelCenter = V(dir * panelW * 0.5f, panelH * 0.5f + 0.008f, 0f);
            var panel = kit.Box(hinge, "Battant", V(panelW, panelH, thick), pal.DoorWood, panelCenter, 0.006f);
            var col = panel.AddComponent<BoxCollider>();
            col.size = V(panelW, panelH, thick);

            // Poignées (béquilles inox) des deux côtés
            float hx = dir * (panelW - 0.07f);
            foreach (float side in new[] { -1f, 1f })
            {
                float zf = side * (thick * 0.5f + 0.012f);
                kit.Box(hinge, "Rosace", V(0.05f, 0.05f, 0.008f), pal.Steel, V(hx, 1.02f, side * (thick * 0.5f + 0.004f)), 0.004f);
                kit.Box(hinge, "Bequille", V(0.13f, 0.018f, 0.018f), pal.Steel, V(hx - dir * 0.055f, 1.02f, zf + side * 0.012f), 0.007f);
                kit.Cylinder(hinge, "Tige", 0.008f, 0.03f, pal.Steel, V(hx, 1.02f, zf - side * 0.012f), 12, true, Quaternion.Euler(side * 90f, 0f, 0f));
            }

            // Plaque de porte côté accueil (sud)
            if (!string.IsNullOrEmpty(sign))
            {
                var plate = kit.Quad(hinge, "Plaque", 0.32f, 0.1f, kit.Mat.Decal("Sign", sign, 0.5f), V(dir * panelW * 0.5f, 1.58f, -thick * 0.5f - 0.002f), Yaw(180f));
                plate.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            }

            var door = group.gameObject.AddComponent<AutoDoor>();
            door.Hinge = hinge;
            door.PanelCollider = col;
            door.OpenAngle = openAngle;
            door.SensorCenter = V(centerX, 0f, z);
            door.Locked = locked;

            if (locked)
            {
                var it = panel.AddComponent<SimpleInteractable>();
                it.Verb = "Porte verrouillée";
                it.Target = "WC (en travaux)";
                it.Condition = () => false;
                it.Reason = () => "Les toilettes patients sont en travaux cette semaine.";
            }
        }

        void DoorFrame(Transform parent, float centerX, float width, float z, float halfWall)
        {
            float x0 = centerX - width * 0.5f, x1 = centerX + width * 0.5f, H = L.DoorHeight;
            const float w = 0.06f, proud = 0.012f;
            float depth = halfWall * 2f + proud * 2f;
            kit.Box(parent, "Jambage", V(w, H + w, depth), pal.DoorFrame, V(x0 - w * 0.5f + 0.01f, (H + w) * 0.5f, z), 0.004f);
            kit.Box(parent, "Jambage", V(w, H + w, depth), pal.DoorFrame, V(x1 + w * 0.5f - 0.01f, (H + w) * 0.5f, z), 0.004f);
            kit.Box(parent, "Traverse", V(width + w * 2f - 0.02f, w, depth), pal.DoorFrame, V(centerX, H + w * 0.5f, z), 0.004f);
            // Seuil
            kit.Box(parent, "Seuil", V(width, 0.006f, halfWall * 2f + 0.02f), pal.Steel, V(centerX, 0.003f, z), 0.002f, false, null, false);
        }

        void EntranceDoor(Transform parent)
        {
            float cx = (L.EntranceX0 + L.EntranceX1) * 0.5f;
            float w = L.EntranceX1 - L.EntranceX0, H = L.EntranceTop;
            var group = WorldKit.Group(parent, "Entree_Coulissante", V(cx, 0f, -L.ExteriorThickness * 0.5f));
            // Bâti
            kit.Box(group, "Bati_G", V(0.08f, H, 0.2f), pal.WindowFrame, V(-w * 0.5f + 0.04f, H * 0.5f, 0f), 0.004f);
            kit.Box(group, "Bati_D", V(0.08f, H, 0.2f), pal.WindowFrame, V(w * 0.5f - 0.04f, H * 0.5f, 0f), 0.004f);
            kit.Box(group, "Caisson", V(w, 0.2f, 0.24f), pal.WindowFrame, V(0f, H - 0.1f, 0f), 0.006f);
            kit.Part(group, "Led", kit.RoundedBoxMesh(V(0.05f, 0.012f, 0.012f), 0.004f), pal.Led, V(0f, H - 0.2f, -0.12f), false);

            float leafW = w * 0.5f - 0.06f, leafH = H - 0.22f;
            Transform Leaf(string n, float x)
            {
                var leaf = WorldKit.Group(group, n, V(x, 0f, 0f));
                kit.Box(leaf, "Cadre_H", V(leafW, 0.05f, 0.05f), pal.WindowFrame, V(0f, leafH - 0.025f, 0f), 0.004f);
                kit.Box(leaf, "Cadre_B", V(leafW, 0.08f, 0.05f), pal.WindowFrame, V(0f, 0.04f, 0f), 0.004f);
                kit.Box(leaf, "Cadre_G", V(0.05f, leafH, 0.05f), pal.WindowFrame, V(-leafW * 0.5f + 0.025f, leafH * 0.5f, 0f), 0.004f);
                kit.Box(leaf, "Cadre_D", V(0.05f, leafH, 0.05f), pal.WindowFrame, V(leafW * 0.5f - 0.025f, leafH * 0.5f, 0f), 0.004f);
                var glass = kit.Box(leaf, "Vitre", V(leafW - 0.08f, leafH - 0.12f, 0.012f), pal.Glass, V(0f, leafH * 0.5f + 0.015f, 0f), 0.001f, false, null, false);
                glass.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                // Bande de vitrophanie (sécurité)
                kit.Box(leaf, "Bande", V(leafW - 0.08f, 0.06f, 0.014f), pal.GlassFrosted, V(0f, 1.05f, 0f), 0.001f, false, null, false);
                return leaf;
            }
            var left = Leaf("Vantail_G", -leafW * 0.5f - 0.005f);
            var right = Leaf("Vantail_D", leafW * 0.5f + 0.005f);

            var block = WorldKit.Collider(group, "Blocage", V(0f, H * 0.5f, 0f), V(w, H, 0.12f));
            var sd = group.gameObject.AddComponent<SlidingDoor>();
            sd.Left = left;
            sd.Right = right;
            sd.Travel = leafW * 0.92f;
            sd.BlockCollider = block;
            sd.SensorCenter = V(cx, 0f, 0f);

            // Tapis d'entrée
            kit.Box(propsRoot, "Tapis_Entree", V(1.9f, 0.012f, 1.1f), pal.Mat, V(cx, 0.006f, 0.65f), 0.004f, false, null, false);
            kit.Box(outsideRoot, "Tapis_Ext", V(1.9f, 0.012f, 0.9f), pal.Mat, V(cx, 0.006f, -0.75f), 0.004f, false, null, false);
        }

        // ================================================================== Fenêtres

        void BuildWindows()
        {
            var g = WorldKit.Group(propsRoot, "Fenetres", Vector3.zero);
            float e = L.ExteriorThickness;
            foreach (var o in SouthOpenings)
                if (o.Bottom > 0f) WindowX(g, o, -e, 0f, true);
            foreach (var o in NorthOpenings) WindowX(g, o, L.MaxZ, L.MaxZ + e, false);
            foreach (var o in WestOpenings) WindowZ(g, o, -e, 0f, true);
            foreach (var o in EastOpenings) WindowZ(g, o, L.MaxX, L.MaxX + e, false);

            // Stores vénitiens à mi-hauteur sur les fenêtres sud de l'accueil : ombres zébrées au sol.
            foreach (var o in SouthOpenings)
                if (o.Bottom > 0f) Blinds(g, o.A0, o.A1, o.Top, 0.08f);
        }

        /// <summary>Fenêtre dans un mur parallèle à X. interiorAtMax = l'intérieur est du côté z max.</summary>
        void WindowX(Transform parent, Opening o, float z0, float z1, bool interiorAtMax)
        {
            float w = o.A1 - o.A0, h = o.Top - o.Bottom, cx = (o.A0 + o.A1) * 0.5f, cy = (o.Bottom + o.Top) * 0.5f, cz = (z0 + z1) * 0.5f;
            const float f = 0.055f, depth = 0.07f;
            var win = WorldKit.Group(parent, "Fenetre", V(cx, cy, cz));
            kit.Box(win, "Dormant_H", V(w, f, depth), pal.WindowFrame, V(0f, h * 0.5f - f * 0.5f, 0f), 0.004f);
            kit.Box(win, "Dormant_B", V(w, f, depth), pal.WindowFrame, V(0f, -h * 0.5f + f * 0.5f, 0f), 0.004f);
            kit.Box(win, "Dormant_G", V(f, h, depth), pal.WindowFrame, V(-w * 0.5f + f * 0.5f, 0f, 0f), 0.004f);
            kit.Box(win, "Dormant_D", V(f, h, depth), pal.WindowFrame, V(w * 0.5f - f * 0.5f, 0f, 0f), 0.004f);
            int panes = w > 1.9f ? 3 : 2;
            for (int i = 1; i < panes; i++)
                kit.Box(win, "Meneau", V(f * 0.8f, h - f, depth * 0.9f), pal.WindowFrame, V(-w * 0.5f + w * i / panes, 0f, 0f), 0.004f);
            var glass = kit.Box(win, "Vitrage", V(w - f, h - f, 0.012f), pal.Glass, Vector3.zero, 0.001f, false, null, false);
            glass.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            WorldKit.Collider(win, "Col", Vector3.zero, V(w, h, 0.05f));

            float side = interiorAtMax ? 1f : -1f;
            float inner = interiorAtMax ? z1 : z0, outer = interiorAtMax ? z0 : z1;
            // Tablette intérieure + appui extérieur
            kit.Box(parent, "Tablette", V(w + 0.08f, 0.03f, 0.2f), pal.DoorFrame, V(cx, o.Bottom - 0.015f, inner + side * 0.06f), 0.006f);
            kit.Box(parent, "Appui", V(w + 0.1f, 0.03f, 0.16f), pal.Steel, V(cx, o.Bottom - 0.02f, outer - side * 0.05f), 0.004f);
        }

        void WindowZ(Transform parent, Opening o, float x0, float x1, bool interiorAtMax)
        {
            float w = o.A1 - o.A0, h = o.Top - o.Bottom, cz = (o.A0 + o.A1) * 0.5f, cy = (o.Bottom + o.Top) * 0.5f, cx = (x0 + x1) * 0.5f;
            const float f = 0.055f, depth = 0.07f;
            var win = WorldKit.Group(parent, "Fenetre", V(cx, cy, cz), 90f);
            // Dans le repère local (tourné de 90°), l'axe local X suit -Z monde : même construction qu'en X.
            kit.Box(win, "Dormant_H", V(w, f, depth), pal.WindowFrame, V(0f, h * 0.5f - f * 0.5f, 0f), 0.004f);
            kit.Box(win, "Dormant_B", V(w, f, depth), pal.WindowFrame, V(0f, -h * 0.5f + f * 0.5f, 0f), 0.004f);
            kit.Box(win, "Dormant_G", V(f, h, depth), pal.WindowFrame, V(-w * 0.5f + f * 0.5f, 0f, 0f), 0.004f);
            kit.Box(win, "Dormant_D", V(f, h, depth), pal.WindowFrame, V(w * 0.5f - f * 0.5f, 0f, 0f), 0.004f);
            int panes = w > 1.9f ? 3 : 2;
            for (int i = 1; i < panes; i++)
                kit.Box(win, "Meneau", V(f * 0.8f, h - f, depth * 0.9f), pal.WindowFrame, V(-w * 0.5f + w * i / panes, 0f, 0f), 0.004f);
            var glass = kit.Box(win, "Vitrage", V(w - f, h - f, 0.012f), pal.Glass, Vector3.zero, 0.001f, false, null, false);
            glass.GetComponent<MeshRenderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            WorldKit.Collider(win, "Col", Vector3.zero, V(w, h, 0.05f));

            float side = interiorAtMax ? 1f : -1f;
            float inner = interiorAtMax ? x1 : x0, outer = interiorAtMax ? x0 : x1;
            kit.Box(parent, "Tablette", V(0.2f, 0.03f, w + 0.08f), pal.DoorFrame, V(inner + side * 0.06f, o.Bottom - 0.015f, cz), 0.006f);
            kit.Box(parent, "Appui", V(0.16f, 0.03f, w + 0.1f), pal.Steel, V(outer - side * 0.05f, o.Bottom - 0.02f, cz), 0.004f);
        }

        /// <summary>Store vénitien partiellement descendu (lames inclinées), mesh fusionné.</summary>
        void Blinds(Transform parent, float x0, float x1, float top, float zInside)
        {
            float w = x1 - x0 - 0.06f;
            var md = new MeshData();
            var slat = MeshFactory.RoundedBox(V(w, 0.0025f, 0.05f), 0.001f, 1);
            int count = 15;
            for (int i = 0; i < count; i++)
            {
                float y = top - 0.07f - i * 0.036f;
                md.Append(slat, V(0f, y, 0f), Quaternion.Euler(28f, 0f, 0f), Vector3.one);
            }
            var mesh = kit.FromData("blinds_" + w.ToString("F2"), md);
            var go = kit.Part(parent, "Store", mesh, pal.PlasticWhite, V((x0 + x1) * 0.5f, 0f, zInside), true);
            go.name = "Store";
            kit.Box(parent, "Caisson_Store", V(w + 0.04f, 0.05f, 0.07f), pal.PlasticWhite, V((x0 + x1) * 0.5f, top - 0.03f, zInside), 0.008f);
            // Cordons
            kit.Cylinder(parent, "Cordon", 0.002f, 0.6f, pal.PlasticWhite, V(x1 - 0.12f, top - 0.68f, zInside + 0.03f), 6, false);
        }
    }
}
