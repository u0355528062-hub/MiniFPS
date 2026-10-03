using UnityEngine;
using UnityEngine.Rendering;
using L = BlouseBlanche.World.ClinicLayout;

namespace BlouseBlanche.World
{
    public sealed partial class ClinicBuilder
    {
        // ================================================================== Navigation

        void BuildNavigation()
        {
            var n = world.Nav;
            n.Node(L.Street, V(-6f, 0f, -2.0f));
            n.Node("streetE", V(28f, 0f, -2.0f));
            n.Node(L.Sidewalk, V(12.0f, 0f, -2.0f));
            n.Node(L.Outside, V(12.0f, 0f, -1.0f));
            n.Node(L.Inside, V(12.0f, 0f, 1.0f));
            n.Node(L.Queue, V(12.6f, 0f, 1.6f));
            n.Node(L.Desk, V(12.6f, 0f, 2.45f));
            n.Node(L.LobbyE, V(10.2f, 0f, 2.4f));
            n.Node(L.LobbyS, V(4.2f, 0f, 1.9f));
            n.Node(L.LobbyC, V(6.0f, 0f, 4.2f));
            n.Node(L.LobbyW, V(2.0f, 0f, 3.9f));
            n.Node(L.ConsultOut, V(L.ConsultDoorX, 0f, 5.75f));
            n.Node(L.ConsultIn, V(L.ConsultDoorX, 0f, 7.3f));
            n.Node(L.RoomC, V(4.4f, 0f, 8.6f));
            n.Node(L.BehindChairs, V(2.0f, 0f, 8.6f));
            n.Node(L.PatientChairNode, V(1.95f, 0f, 9.6f));
            n.Node(L.ExamNode, V(5.6f, 0f, 9.55f));

            n.Link(L.Street, L.Sidewalk);
            n.Link("streetE", L.Sidewalk);
            n.Chain(L.Sidewalk, L.Outside, L.Inside);
            n.Chain(L.Inside, L.Queue, L.Desk);
            n.Link(L.Inside, L.LobbyE);
            n.Link(L.Desk, L.LobbyE);
            n.Link(L.LobbyE, L.LobbyS);
            n.Link(L.LobbyE, L.LobbyC);
            n.Link(L.LobbyS, L.LobbyC);
            n.Link(L.LobbyC, L.LobbyW);
            n.Chain(L.LobbyC, L.ConsultOut, L.ConsultIn, L.RoomC);
            n.Chain(L.RoomC, L.BehindChairs, L.PatientChairNode);
            n.Link(L.RoomC, L.ExamNode);

            for (int i = 0; i < RowAZ.Length; i++)
            {
                n.Node("seatA" + i, V(1.25f, 0f, RowAZ[i]));
                n.Link("seatA" + i, L.LobbyW);
            }
            for (int i = 0; i < RowBX.Length; i++)
            {
                n.Node("seatB" + i, V(RowBX[i], 0f, 1.3f));
                n.Link("seatB" + i, L.LobbyS);
            }

            world.PlayerSpawn = V(12.0f, 0f, 1.5f);
            world.PlayerSpawnYaw = 0f;
        }

        // ================================================================== Lumière

        void BuildLighting()
        {
            // Soleil du matin, entrant par les fenêtres sud (stores = ombres zébrées).
            var sunGo = new GameObject("Soleil");
            sunGo.transform.SetParent(lightsRoot, false);
            sunGo.transform.rotation = Quaternion.Euler(36f, -32f, 0f);
            var sun = sunGo.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.intensity = 2.15f;
            sun.color = new Color(1f, 0.94f, 0.85f);
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = 0.92f;
            sun.shadowBias = 0.05f;
            sun.shadowNormalBias = 0.35f;
            RenderSettings.sun = sun;
            world.AllLights.Add(sun);

            // Lumière ambiante (pas de GI précalculée : on utilise un éclairage tri-couleur doux).
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.60f, 0.66f, 0.76f);
            RenderSettings.ambientEquatorColor = new Color(0.48f, 0.47f, 0.45f);
            RenderSettings.ambientGroundColor = new Color(0.27f, 0.25f, 0.23f);
            RenderSettings.ambientIntensity = 1f;
            RenderSettings.reflectionIntensity = 0.9f;
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogDensity = 0.012f;
            RenderSettings.fogColor = new Color(0.74f, 0.80f, 0.87f);

            var sky = Resources.Load<Material>(MaterialLibrary.TemplateFolder + "Sky");
            if (sky == null)
            {
                var sh = Shader.Find("Skybox/Procedural");
                if (sh != null) sky = new Material(sh);
            }
            if (sky != null)
            {
                sky = new Material(sky);
                sky.SetFloat("_SunSize", 0.035f);
                sky.SetFloat("_SunSizeConvergence", 6f);
                sky.SetFloat("_AtmosphereThickness", 0.85f);
                sky.SetColor("_SkyTint", new Color(0.52f, 0.58f, 0.70f));
                sky.SetColor("_GroundColor", new Color(0.40f, 0.39f, 0.37f));
                sky.SetFloat("_Exposure", 1.25f);
                RenderSettings.skybox = sky;
            }

            // Plafonniers LED (quelques-uns portent des ombres douces)
            var lobby = WorldKit.Group(lightsRoot, "Accueil", Vector3.zero);
            CeilingPanel(lobby, V(2.5f, 0f, 1.8f), false);
            CeilingPanel(lobby, V(2.5f, 0f, 4.7f), false);
            CeilingPanel(lobby, V(6.0f, 0f, 1.8f), false);
            CeilingPanel(lobby, V(6.0f, 0f, 4.7f), true);
            CeilingPanel(lobby, V(9.5f, 0f, 1.8f), false);
            CeilingPanel(lobby, V(9.5f, 0f, 4.7f), false);
            CeilingPanel(lobby, V(13.0f, 0f, 1.8f), true);
            CeilingPanel(lobby, V(13.0f, 0f, 4.7f), false);
            var consult = WorldKit.Group(lightsRoot, "Cabinet", Vector3.zero);
            CeilingPanel(consult, V(3.0f, 0f, 10.0f), true, 3.8f);
            CeilingPanel(consult, V(5.9f, 0f, 9.6f), true, 3.6f);
            CeilingPanel(consult, V(2.0f, 0f, 7.6f), false, 3.0f);
            var brk = WorldKit.Group(lightsRoot, "Pause", Vector3.zero);
            CeilingPanel(brk, V(9.5f, 0f, 9.5f), true, 3.2f);

            // "Lumière de fenêtre" : lumière du ciel diffusée vers l'intérieur (fausse GI)
            var fill = WorldKit.Group(lightsRoot, "Ciel_Fenetres", Vector3.zero);
            foreach (var o in SouthOpenings) if (o.Bottom > 0f) WindowFill(fill, V((o.A0 + o.A1) * 0.5f, 2.1f, 0.35f), Vector3.forward, o.A1 - o.A0);
            foreach (var o in WestOpenings) WindowFill(fill, V(0.35f, 2.1f, (o.A0 + o.A1) * 0.5f), Vector3.right, o.A1 - o.A0);
            foreach (var o in NorthOpenings) WindowFill(fill, V((o.A0 + o.A1) * 0.5f, 2.1f, L.MaxZ - 0.35f), Vector3.back, o.A1 - o.A0);
            foreach (var o in EastOpenings) WindowFill(fill, V(L.MaxX - 0.35f, 2.1f, (o.A0 + o.A1) * 0.5f), Vector3.left, o.A1 - o.A0);

            // Sondes de réflexion (une par pièce, projection en boîte)
            Probe("Sonde_Accueil", V(L.MaxX * 0.5f, 1.4f, L.PartitionZ * 0.5f), V(L.MaxX, 2.8f, L.PartitionZ));
            Probe("Sonde_Cabinet", V(L.ConsultMaxX * 0.5f, 1.4f, (L.PartitionZ + L.MaxZ) * 0.5f), V(L.ConsultMaxX, 2.8f, L.MaxZ - L.PartitionZ));
            Probe("Sonde_Pause", V((L.ConsultMaxX + L.BreakMaxX) * 0.5f, 1.4f, (L.PartitionZ + L.MaxZ) * 0.5f), V(L.BreakMaxX - L.ConsultMaxX, 2.8f, L.MaxZ - L.PartitionZ));
            Probe("Sonde_Rue", V(7.5f, 2f, -6f), V(60f, 12f, 20f), 0.6f);

            // Ambiances sonores
            world.OutdoorSoundPoints.Add(V(5f, 2f, -2.5f));
            world.OutdoorSoundPoints.Add(V(-2f, 2.5f, 9f));
            world.OutdoorSoundPoints.Add(V(10f, 2.5f, 13.5f));
            world.RoomTonePoints.Add(V(7.5f, 2.6f, 3.2f));
            world.RoomTonePoints.Add(V(3.7f, 2.6f, 9.5f));
            world.SecretaryTypingPoint = V(13.05f, 0.8f, 3.85f);
        }

        void WindowFill(Transform parent, Vector3 pos, Vector3 inward, float width)
        {
            var go = new GameObject("Ciel");
            go.transform.SetParent(parent, false);
            go.transform.position = pos;
            go.transform.rotation = Quaternion.LookRotation((inward + Vector3.down * 0.55f).normalized, Vector3.up);
            var l = go.AddComponent<Light>();
            l.type = LightType.Spot;
            l.spotAngle = 125f;
            l.innerSpotAngle = 40f;
            l.range = 5.5f;
            l.intensity = 0.55f + width * 0.22f;
            l.color = new Color(0.80f, 0.88f, 1.0f);
            l.shadows = LightShadows.None;
            world.AllLights.Add(l);
        }

        void Probe(string name, Vector3 center, Vector3 size, float intensity = 1f)
        {
            var go = new GameObject(name);
            go.transform.SetParent(lightsRoot, false);
            go.transform.position = center;
            var p = go.AddComponent<ReflectionProbe>();
            p.mode = ReflectionProbeMode.Realtime;
            p.refreshMode = ReflectionProbeRefreshMode.ViaScripting;
            p.timeSlicingMode = ReflectionProbeTimeSlicingMode.NoTimeSlicing;
            p.size = size;
            p.boxProjection = true;
            p.resolution = 256;
            p.hdr = true;
            p.intensity = intensity;
            p.blendDistance = 0.5f;
            world.Probes.Add(p);
        }

        // ================================================================== Plans caméra

        void BuildCameraShots()
        {
            // Bureau : regard du médecin assis vers le patient
            world.DeskShot = ClinicWorld.LookPose(V(3.05f, 1.22f, 11.1f), V(2.6f, 1.02f, 9.2f));
            // Divan : debout à côté du patient assis sur la table
            world.ExamShot = ClinicWorld.LookPose(V(5.3f, 1.62f, 10.5f), V(6.45f, 1.18f, 9.55f));

            // Travellings du menu principal (paires début/fin)
            world.MenuShots = new[]
            {
                ClinicWorld.LookPose(V(14.3f, 1.75f, 0.7f), V(5.0f, 0.9f, 4.4f)),
                ClinicWorld.LookPose(V(13.2f, 1.6f, 1.1f), V(4.6f, 0.9f, 4.6f)),

                ClinicWorld.LookPose(V(6.9f, 1.55f, 7.05f), V(2.8f, 0.85f, 10.6f)),
                ClinicWorld.LookPose(V(6.3f, 1.45f, 7.5f), V(2.9f, 0.85f, 10.5f)),

                ClinicWorld.LookPose(V(4.4f, 1.15f, 9.25f), V(3.15f, 0.82f, 10.4f)),
                ClinicWorld.LookPose(V(4.1f, 1.1f, 9.5f), V(3.15f, 0.82f, 10.45f)),

                ClinicWorld.LookPose(V(3.5f, 1.7f, -8.2f), V(10.5f, 1.5f, 0f)),
                ClinicWorld.LookPose(V(7.5f, 1.8f, -7.8f), V(11.5f, 1.6f, 0f)),
            };
        }
    }
}
