using System.Collections.Generic;
using BlouseBlanche.Core;
using UnityEngine;
using L = BlouseBlanche.World.ClinicLayout;

namespace BlouseBlanche.World
{
    public sealed partial class ClinicBuilder
    {
        // Positions des sièges d'attente (partagées avec la navigation)
        static readonly float[] RowAZ = { 1.0f, 1.62f, 2.24f, 2.86f, 3.48f, 4.10f, 4.72f };
        static readonly float[] RowBX = { 2.0f, 2.62f, 3.24f, 4.6f, 5.22f, 5.84f };
        const float RowAX = 0.5f, RowBZ = 0.5f;

        // ================================================================== Salle d'attente

        void BuildLobby()
        {
            var g = WorldKit.Group(propsRoot, "Salle_Attente", Vector3.zero);

            for (int i = 0; i < RowAZ.Length; i++)
            {
                WaitingChair(g, V(RowAX, 0f, RowAZ[i]), 90f, i % 3 == 1 ? pal.FabricMustard : pal.FabricTeal);
                world.WaitingSeats.Add(new SeatSpot { Id = "A" + i, Anchor = V(RowAX - 0.03f, 0f, RowAZ[i]), Yaw = 90f, SeatHeight = 0.465f, ApproachNode = "seatA" + i });
            }
            for (int i = 0; i < RowBX.Length; i++)
            {
                WaitingChair(g, V(RowBX[i], 0f, RowBZ), 0f, i % 3 == 2 ? pal.FabricMustard : pal.FabricTeal);
                world.WaitingSeats.Add(new SeatSpot { Id = "B" + i, Anchor = V(RowBX[i], 0f, RowBZ - 0.03f), Yaw = 0f, SeatHeight = 0.465f, ApproachNode = "seatB" + i });
            }

            // Guéridon entre les deux groupes de la rangée sud
            var side = WorldKit.Group(g, "Gueridon", V(3.92f, 0f, 0.42f));
            kit.Part(side, "Plateau", kit.RoundedCylinderMesh(0.22f, 0.03f, 0.01f), pal.Oak, V(0f, 0.5f, 0f));
            kit.Cylinder(side, "Pied", 0.02f, 0.5f, pal.BlackMetal, Vector3.zero, 12);
            kit.Part(side, "Base", kit.RoundedCylinderMesh(0.16f, 0.015f, 0.006f), pal.BlackMetal, Vector3.zero);
            Magazine(side, V(0.02f, 0.532f, 0.0f), 15f, 2);
            Magazine(side, V(-0.03f, 0.538f, 0.03f), -22f, 4);

            // Table basse + magazines
            var table = WorldKit.Group(g, "Table_Basse", V(3.6f, 0f, 3.2f));
            kit.Box(table, "Plateau", V(1.1f, 0.035f, 0.6f), pal.Oak, V(0f, 0.42f, 0f), 0.01f);
            foreach (var p in new[] { V(-0.5f, 0f, -0.25f), V(0.5f, 0f, -0.25f), V(-0.5f, 0f, 0.25f), V(0.5f, 0f, 0.25f) })
                kit.Cylinder(table, "Pied", 0.018f, 0.405f, pal.BlackMetal, p, 12);
            for (int i = 0; i < 4; i++) Magazine(table, V(-0.3f + i * 0.2f, 0.4395f + i * 0.003f, (i % 2) * 0.08f - 0.04f), i * 23f - 30f, i);
            var tc = table.gameObject.AddComponent<BoxCollider>();
            tc.center = V(0f, 0.22f, 0f);
            tc.size = V(1.1f, 0.44f, 0.6f);

            // Coin enfants
            KidsCorner(g, V(8.4f, 0f, 1.45f));

            // Télévision, panneau d'affichage, fontaine à eau, horloge
            Screen(g, "Tv", V(2.6f, 1.9f, L.PartitionZ - 0.06f - 0.046f), 180f, 1.18f, 0.66f, 1.3f);
            CorkBoard(g, V(4.35f, 1.55f, L.PartitionZ - 0.066f), 180f);
            WaterDispenser(g, V(7.45f, 0f, 6.18f), 180f);
            Clock(g, V(6.75f, 2.12f, L.PartitionZ - 0.066f), 180f, 0.16f);

            // Affiches
            Frame(g, "PosterHeart", V(3.9f, 1.55f, 0.0f), 0f, 0.46f, 0.64f, pal.PlasticWhite);
            Frame(g, "PosterVaccine", V(7.2f, 1.55f, 0.0f), 0f, 0.46f, 0.64f, pal.PlasticWhite);
            Frame(g, "PosterLungs", V(0.0f, 1.55f, 5.55f), 90f, 0.46f, 0.64f, pal.PlasticWhite);
            Frame(g, "KidsDrawing", V(9.35f, 1.4f, L.PartitionZ - 0.066f), 180f, 0.42f, 0.32f, pal.Oak);
            Poster(g, "SignWaiting", V(0.0f, 2.25f, 2.86f), 90f, 0.6f, 0.19f);

            // Plantes, porte-manteau, porte-revues
            Plant(g, V(0.45f, 0f, 6.05f), 1.45f, 3);
            Plant(g, V(10.55f, 0f, 6.05f), 1.2f, 7, true);
            Plant(g, V(14.55f, 0f, 0.45f), 1.35f, 11);
            Plant(g, V(6.6f, 0f, 0.38f), 0.85f, 13, true);
            CoatRack(g, V(10.5f, 0f, 0.42f));
            MagazineRack(g, V(0.3f, 0f, 5.35f), 90f);

            // Distributeur de gel hydro-alcoolique (interactif)
            var gel = WorldKit.Group(g, "Gel_Hydroalcoolique", V(10.62f, 1.22f, 0.0f));
            kit.Box(gel, "Corps", V(0.12f, 0.22f, 0.1f), pal.PlasticWhite, V(0f, 0f, 0.05f), 0.012f, true);
            kit.Box(gel, "Fenetre", V(0.06f, 0.08f, 0.004f), pal.Water, V(0f, 0.03f, 0.101f), 0.002f);
            kit.Box(gel, "Poussoir", V(0.09f, 0.04f, 0.03f), pal.PlasticGrey, V(0f, -0.09f, 0.09f), 0.008f);
            var gi = gel.GetChild(0).gameObject.AddComponent<SimpleInteractable>();
            gi.Verb = "Friction hydro-alcoolique";
            gi.Target = "Hygiène des mains";
            Vector3 gelPos = gel.position;
            gi.OnInteract = () => GameRoot.Instance?.WashHands(gelPos, false);

            world.Lobby = new Bounds(V(L.MaxX * 0.5f, 1.4f, L.PartitionZ * 0.5f), V(L.MaxX, 2.8f, L.PartitionZ));
        }

        void Magazine(Transform parent, Vector3 pos, float yaw, int index)
        {
            var g = WorldKit.Group(parent, "Magazine", pos, yaw);
            kit.Box(g, "Pages", V(0.21f, 0.006f, 0.28f), pal.ExamPaper, Vector3.zero, 0.001f, false, null, false);
            kit.Quad(g, "Couverture", 0.21f, 0.28f, kit.Mat.Decal("Mag", "Magazine" + (index % 6), 0.35f), V(0f, 0.0032f, 0f), Quaternion.Euler(-90f, 0f, 0f));
        }

        void KidsCorner(Transform parent, Vector3 c)
        {
            var g = WorldKit.Group(parent, "Coin_Enfants", c);
            kit.Box(g, "Tapis", V(1.6f, 0.012f, 1.2f), pal.FabricRug, V(0f, 0.006f, 0f), 0.004f, false, null, false);
            kit.Box(g, "Table", V(0.6f, 0.03f, 0.6f), pal.PlasticWhite, V(0f, 0.45f, 0f), 0.012f);
            Material[] cols = { pal.KidRed, pal.KidBlue, pal.KidYellow, pal.KidGreen };
            int k = 0;
            foreach (var p in new[] { V(-0.26f, 0f, -0.26f), V(0.26f, 0f, -0.26f), V(-0.26f, 0f, 0.26f), V(0.26f, 0f, 0.26f) })
                kit.Cylinder(g, "Pied", 0.02f, 0.435f, cols[k++ % 4], p, 12);
            kit.Part(g, "Tabouret", kit.RoundedCylinderMesh(0.14f, 0.28f, 0.04f), pal.KidBlue, V(-0.5f, 0f, 0.05f));
            kit.Part(g, "Tabouret", kit.RoundedCylinderMesh(0.14f, 0.28f, 0.04f), pal.KidYellow, V(0.5f, 0f, -0.05f));
            var r = new System.Random(4);
            for (int i = 0; i < 9; i++)
            {
                float s = 0.05f + (float)r.NextDouble() * 0.03f;
                Vector3 p = i < 5 ? V(-0.15f + (float)r.NextDouble() * 0.3f, 0.465f + s * 0.5f, -0.15f + (float)r.NextDouble() * 0.3f)
                                  : V(-0.6f + (float)r.NextDouble() * 1.2f, 0.012f + s * 0.5f, -0.45f + (float)r.NextDouble() * 0.9f);
                if (i == 2) p.y += s; // une petite tour
                kit.Box(g, "Cube", V(s, s, s), cols[i % 4], p, s * 0.18f, false, Quaternion.Euler(0f, (float)r.NextDouble() * 90f, 0f));
            }
            kit.Box(g, "Coffre_Jouets", V(0.5f, 0.35f, 0.34f), pal.KidYellow, V(0.65f, 0.175f, -0.95f), 0.04f, true);
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.25f, 0f);
            col.size = V(0.7f, 0.5f, 0.7f);
        }

        void CorkBoard(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Tableau_Liege", pos, yaw);
            kit.Box(g, "Cadre", V(0.92f, 0.62f, 0.025f), pal.Oak, V(0f, 0f, 0.0125f), 0.006f);
            kit.Box(g, "Liege", V(0.86f, 0.56f, 0.008f), pal.Cork, V(0f, 0f, 0.026f), 0.002f);
            kit.Quad(g, "Note1", 0.2f, 0.28f, kit.Mat.Decal("Pin", "Paper", 0.2f), V(-0.27f, 0.08f, 0.031f), Quaternion.Euler(0f, 0f, 4f));
            kit.Quad(g, "Note2", 0.17f, 0.24f, kit.Mat.Decal("Pin", "Calendar", 0.2f), V(0.02f, 0.05f, 0.031f), Quaternion.Euler(0f, 0f, -3f));
            kit.Quad(g, "Note3", 0.2f, 0.28f, kit.Mat.Decal("Pin", "PosterHands", 0.2f), V(0.28f, 0.06f, 0.031f), Quaternion.Euler(0f, 0f, 2f));
            foreach (var p in new[] { V(-0.27f, 0.2f, 0.034f), V(0.02f, 0.16f, 0.034f), V(0.28f, 0.19f, 0.034f) })
                kit.Sphere(g, "Punaise", 0.008f, pal.KidRed, p);
        }

        void WaterDispenser(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Fontaine", pos, yaw);
            kit.Box(g, "Corps", V(0.32f, 1.0f, 0.32f), pal.PlasticWhite, V(0f, 0.5f, 0f), 0.03f, true);
            kit.Box(g, "Façade", V(0.2f, 0.22f, 0.02f), pal.PlasticGrey, V(0f, 0.78f, 0.165f), 0.01f);
            kit.Box(g, "Robinet_F", V(0.035f, 0.05f, 0.04f), pal.KidBlue, V(-0.05f, 0.8f, 0.18f), 0.008f);
            kit.Box(g, "Robinet_C", V(0.035f, 0.05f, 0.04f), pal.KidRed, V(0.05f, 0.8f, 0.18f), 0.008f);
            kit.Box(g, "Grille", V(0.16f, 0.015f, 0.08f), pal.PlasticDark, V(0f, 0.66f, 0.17f), 0.004f);
            var prof = new List<Vector2> { V2(0f, 0f), V2(0.05f, 0f), V2(0.05f, 0.06f), V2(0.13f, 0.1f), V2(0.135f, 0.32f), V2(0.12f, 0.38f), V2(0f, 0.4f) };
            kit.Part(g, "Bonbonne", kit.Cached("bonbonne", () => MeshFactory.Lathe(prof, 28)), pal.Water, V(0f, 1.0f, 0f), false);
            kit.Cylinder(g, "Gobelets", 0.04f, 0.3f, pal.PlasticWhite, V(0.2f, 0.55f, 0.1f), 16);
        }

        void CoatRack(Transform parent, Vector3 pos)
        {
            var g = WorldKit.Group(parent, "Porte_Manteau", pos);
            kit.Part(g, "Base", kit.RoundedCylinderMesh(0.2f, 0.025f, 0.01f), pal.BlackMetal, Vector3.zero);
            kit.Cylinder(g, "Mat", 0.016f, 1.75f, pal.BlackMetal, V(0f, 0.02f, 0f), 12);
            for (int i = 0; i < 4; i++)
            {
                var q = Quaternion.Euler(0f, i * 90f, 0f);
                var path = new List<Vector3> { V(0f, 1.62f, 0f), q * V(0.12f, 1.66f, 0f), q * V(0.16f, 1.72f, 0f) };
                kit.Part(g, "Crochet", kit.FromData("hook" + i, MeshFactory.Tube(path, 0.008f, 6)), pal.BlackMetal, Vector3.zero);
            }
            // Un manteau et un parapluie
            kit.Box(g, "Manteau", V(0.42f, 0.85f, 0.16f), pal.FabricNavy, V(0.12f, 1.22f, 0f), 0.06f, false, Quaternion.Euler(0f, 0f, 4f));
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.9f, 0f);
            col.size = V(0.4f, 1.8f, 0.4f);
        }

        void MagazineRack(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Porte_Revues", pos, yaw);
            kit.Box(g, "Corps", V(0.4f, 0.9f, 0.22f), pal.Oak, V(0f, 0.45f, 0f), 0.01f, true);
            for (int i = 0; i < 3; i++)
            {
                kit.Box(g, "Bac", V(0.38f, 0.02f, 0.1f), pal.Oak, V(0f, 0.3f + i * 0.25f, 0.13f), 0.004f);
                kit.Quad(g, "Revue", 0.18f, 0.22f, kit.Mat.Decal("Mag", "Magazine" + (i + 2), 0.35f), V(-0.09f, 0.42f + i * 0.25f, 0.125f), Quaternion.Euler(-12f, 0f, 0f));
                kit.Quad(g, "Revue", 0.18f, 0.22f, kit.Mat.Decal("Mag", "Magazine" + i, 0.35f), V(0.1f, 0.42f + i * 0.25f, 0.124f), Quaternion.Euler(-12f, 0f, 0f));
            }
        }

        // ================================================================== Accueil

        void BuildReception()
        {
            var g = WorldKit.Group(propsRoot, "Accueil", Vector3.zero);
            // Banque d'accueil (façade en noyer, tablette haute blanche)
            kit.Box(g, "Facade", V(3.0f, 1.08f, 0.24f), pal.Walnut, V(13.0f, 0.54f, 3.22f), 0.01f, true);
            kit.Box(g, "Retour_O", V(0.24f, 1.08f, 0.9f), pal.Walnut, V(11.62f, 0.54f, 3.75f), 0.01f, true);
            kit.Box(g, "Tablette_Haute", V(3.1f, 0.04f, 0.42f), pal.DeskWhite, V(12.98f, 1.1f, 3.2f), 0.012f);
            kit.Box(g, "Plan_Travail", V(2.75f, 0.035f, 0.68f), pal.DeskWhite, V(13.12f, 0.74f, 3.68f), 0.008f, true);
            kit.Box(g, "Socle_LED", V(2.9f, 0.02f, 0.02f), pal.LightPanel, V(13.0f, 0.06f, 3.09f), 0.004f, false, null, false);
            Poster(g, "SignReception", V(13.0f, 0.78f, 3.095f), 180f, 0.62f, 0.19f);

            // Poste de travail de la secrétaire
            Monitor(g, V(13.25f, 0.7575f, 3.6f), 160f, "MonitorReception");
            Keyboard(g, V(13.05f, 0.7575f, 3.85f), 180f);
            Phone(g, V(12.35f, 0.7575f, 3.7f), 200f);
            PaperStack(g, V(14.05f, 0.7575f, 3.62f), 10f, 6);
            kit.Box(g, "Imprimante", V(0.42f, 0.22f, 0.36f), pal.PlasticDark, V(14.2f, 0.87f, 3.95f), 0.02f, true);
            kit.Box(g, "Bac_Papier", V(0.3f, 0.02f, 0.2f), pal.PlasticGrey, V(14.2f, 0.99f, 3.95f), 0.004f);
            kit.Part(g, "Led_Imprimante", kit.RoundedBoxMesh(V(0.015f, 0.006f, 0.004f), 0.001f), pal.Led, V(14.33f, 0.92f, 3.768f), false);
            PenCup(g, V(12.6f, 0.7575f, 3.5f));
            Plant(g, V(11.95f, 0.7575f, 3.55f), 0.35f, 21, true);
            OfficeChair(g, V(13.0f, 0f, 4.62f), 180f, pal.FabricCharcoal);
            world.SecretaryChair = new SeatSpot { Id = "secretary", Anchor = V(13.0f, 0f, 4.66f), Yaw = 180f, SeatHeight = 0.53f };
            world.SecretaryHead = V(13.0f, 1.25f, 4.62f);

            FilingCabinet(g, V(14.3f, 0f, 6.18f), 180f, 4);
            FilingCabinet(g, V(14.82f, 0f, 5.55f), 270f, 3);
            Bookshelf(g, V(12.05f, 0f, 6.25f), 180f, 0.9f, 1.15f, 99);
            Frame(g, "Calendar", V(L.MaxX - 0.0f, 1.6f, 4.3f), 270f, 0.34f, 0.46f, pal.PlasticWhite);
        }

        // ================================================================== Cabinet de consultation

        void BuildConsultRoom()
        {
            var g = WorldKit.Group(propsRoot, "Cabinet", Vector3.zero);
            Desk(g, V(3.0f, 0f, 10.3f), 0f);
            OfficeChair(g, V(3.0f, 0f, 11.08f), 180f, pal.LeatherBlack);
            WoodChair(g, V(2.55f, 0f, 9.2f), 0f, pal.FabricNavy);
            WoodChair(g, V(3.45f, 0f, 9.2f), 0f, pal.FabricNavy);
            world.PatientChair = new SeatSpot { Id = "patient", Anchor = V(2.55f, 0f, 9.17f), Yaw = 0f, SeatHeight = 0.495f, ApproachNode = L.PatientChairNode };
            world.CompanionChair = new SeatSpot { Id = "companion", Anchor = V(3.45f, 0f, 9.17f), Yaw = 0f, SeatHeight = 0.495f, ApproachNode = L.PatientChairNode };

            // Poste du médecin
            Monitor(g, V(3.42f, 0.7525f, 10.48f), -25f, "Monitor");
            Keyboard(g, V(3.05f, 0.7525f, 10.66f), 0f);
            kit.Box(g, "Souris", V(0.06f, 0.03f, 0.1f), pal.PlasticWhite, V(3.45f, 0.7675f, 10.7f), 0.014f);
            kit.Box(g, "Tapis_Souris", V(0.22f, 0.003f, 0.18f), pal.PlasticDark, V(3.45f, 0.754f, 10.7f), 0.002f);
            Phone(g, V(2.3f, 0.7525f, 10.52f), -20f);
            PaperStack(g, V(2.62f, 0.7525f, 10.6f), 8f, 4);
            DeskLamp(g, V(2.25f, 0.7525f, 10.25f), 40f);
            Stethoscope(g, V(3.7f, 0.7525f, 10.15f));
            BloodPressureMonitor(g, V(2.85f, 0.7525f, 10.05f), 180f);
            PenCup(g, V(2.45f, 0.7525f, 10.7f));
            Mug(g, V(3.72f, 0.7525f, 10.55f));
            var rx = WorldKit.Group(g, "Ordonnancier", V(3.2f, 0.7545f, 10.12f), 172f);
            kit.Box(rx, "Bloc", V(0.15f, 0.004f, 0.21f), pal.ExamPaper, Vector3.zero, 0.001f, false, null, false);
            kit.Quad(rx, "Feuille", 0.148f, 0.208f, kit.Mat.Decal("Rx", "Prescription", 0.2f), V(0f, 0.0025f, 0f), Quaternion.Euler(-90f, 0f, 0f));

            // Interactif : l'ordinateur ouvre l'agenda
            var pc = WorldKit.Collider(g, "Ordinateur_Interaction", V(3.35f, 0.95f, 10.45f), V(0.65f, 0.5f, 0.35f));
            pc.isTrigger = true;
            var pci = pc.gameObject.AddComponent<SimpleInteractable>();
            pci.Verb = "Consulter l'agenda";
            pci.Target = "Logiciel médical";
            pci.OnInteract = () => GameRoot.Instance?.OpenAgenda();

            // Divan d'examen, paravent, lavabo
            ExamTable(g, V(6.75f, 0f, 9.6f), 0f);
            world.ExamTable = new SeatSpot { Id = "exam", Anchor = V(6.56f, 0f, 9.55f), Yaw = -90f, SeatHeight = 0.765f, ApproachNode = L.ExamNode };
            Paravent(g, V(5.25f, 0f, 11.45f), 35f);
            SinkUnit(g, V(6.75f, 0f, L.MaxZ - 0.25f), 180f);
            world.SinkPoint = V(6.75f, 0f, 11.65f);

            // Rangements, équipements, déco
            Vitrine(g, V(0.22f, 0f, 7.3f), 90f);
            Bookshelf(g, V(1.5f, 0f, L.PartitionZ + 0.06f + 0.17f), 0f, 1.8f, 2.0f, 42);
            Scale(g, V(3.25f, 0f, 6.86f), 0f);
            HeightGauge(g, V(L.ConsultMaxX - 0.066f, 0f, 7.95f), -90f);
            CoatRack(g, V(7.08f, 0f, 6.9f));
            TrashBin(g, V(3.98f, 0f, 10.98f), pal.PlasticGrey);
            DasriBox(g, V(L.ConsultMaxX - 0.066f, 0.95f, 8.35f), -90f);
            Radiator(g, V(3.3f, 0.15f, L.MaxZ - 0.06f), 180f, 2.2f);
            Plant(g, V(0.42f, 0f, 12.08f), 1.5f, 31);
            Frame(g, "Diploma", V(5.25f, 1.7f, L.MaxZ), 180f, 0.44f, 0.33f, pal.Gold);
            Frame(g, "Diploma2", V(5.85f, 1.7f, L.MaxZ), 180f, 0.44f, 0.33f, pal.Gold);
            Frame(g, "PosterAnatomy", V(L.ConsultMaxX - 0.066f, 1.62f, 9.6f), -90f, 0.5f, 0.7f, pal.PlasticDark);
            Frame(g, "PosterHands", V(L.ConsultMaxX - 0.066f, 1.55f, 11.55f), -90f, 0.36f, 0.5f, pal.PlasticWhite);
            Clock(g, V(3.9f, 2.12f, L.PartitionZ + 0.066f), 0f, 0.15f);

            world.ConsultRoom = new Bounds(V(L.ConsultMaxX * 0.5f, 1.4f, (L.PartitionZ + L.MaxZ) * 0.5f), V(L.ConsultMaxX, 2.8f, L.MaxZ - L.PartitionZ));
            world.PlayerAfterConsult = V(4.15f, 0f, 11.55f);
            world.PlayerAfterConsultYaw = 220f;
        }

        void Monitor(Transform parent, Vector3 pos, float yaw, string decal)
        {
            var g = WorldKit.Group(parent, "Moniteur", pos, yaw);
            kit.Box(g, "Pied", V(0.22f, 0.012f, 0.17f), pal.PlasticDark, V(0f, 0.006f, 0f), 0.005f);
            kit.Box(g, "Col", V(0.04f, 0.28f, 0.025f), pal.PlasticDark, V(0f, 0.15f, -0.04f), 0.008f);
            kit.Box(g, "Coque", V(0.56f, 0.34f, 0.025f), pal.PlasticDark, V(0f, 0.33f, -0.025f), 0.008f);
            kit.Quad(g, "Dalle", 0.535f, 0.31f, kit.Mat.Decal("Screen", decal, 0.85f, 1.5f), V(0f, 0.335f, -0.0115f), Quaternion.identity);
            kit.Part(g, "Led", kit.RoundedBoxMesh(V(0.008f, 0.004f, 0.003f), 0.001f), pal.Led, V(0.25f, 0.166f, -0.012f), false);
        }

        void Keyboard(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Clavier", pos, yaw);
            kit.Box(g, "Base", V(0.44f, 0.018f, 0.14f), pal.PlasticWhite, V(0f, 0.009f, 0f), 0.005f);
            kit.Box(g, "Touches", V(0.42f, 0.006f, 0.12f), pal.PlasticGrey, V(0f, 0.019f, 0f), 0.002f, false, null, false);
        }

        void Phone(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Telephone", pos, yaw);
            kit.Box(g, "Base", V(0.2f, 0.05f, 0.2f), pal.PlasticDark, V(0f, 0.025f, 0f), 0.015f, false, Quaternion.Euler(8f, 0f, 0f));
            kit.Box(g, "Combine", V(0.055f, 0.04f, 0.21f), pal.PlasticDark, V(-0.065f, 0.065f, 0f), 0.018f);
            kit.Box(g, "Ecran", V(0.07f, 0.004f, 0.04f), pal.Led, V(0.04f, 0.054f, 0.05f), 0.001f, false, null, false);
        }

        void PaperStack(Transform parent, Vector3 pos, float yaw, int sheets)
        {
            var g = WorldKit.Group(parent, "Papiers", pos, yaw);
            for (int i = 0; i < sheets; i++)
                kit.Box(g, "Feuille", V(0.21f, 0.0025f, 0.297f), pal.ExamPaper, V(i * 0.002f, 0.00125f + i * 0.0026f, -i * 0.003f), 0.0005f, false, Quaternion.Euler(0f, i * 1.5f, 0f), false);
            kit.Quad(g, "Texte", 0.2f, 0.285f, kit.Mat.Decal("Paper", "Paper", 0.2f), V(sheets * 0.002f, sheets * 0.0026f + 0.0002f, -sheets * 0.003f), Quaternion.Euler(-90f, sheets * 1.5f, 0f));
        }

        void PenCup(Transform parent, Vector3 pos)
        {
            var g = WorldKit.Group(parent, "Pot_Crayons", pos);
            kit.Cylinder(g, "Pot", 0.035f, 0.1f, pal.PlasticDark, Vector3.zero, 16);
            Material[] m = { pal.KidBlue, pal.PlasticDark, pal.KidRed };
            for (int i = 0; i < 3; i++)
                kit.Cylinder(g, "Stylo", 0.005f, 0.14f, m[i], V(-0.01f + i * 0.01f, 0.02f, (i - 1) * 0.008f), 8, false, Quaternion.Euler((i - 1) * 8f, 0f, (i - 1) * 10f));
        }

        void Mug(Transform parent, Vector3 pos)
        {
            var g = WorldKit.Group(parent, "Mug", pos, 30f);
            var prof = new List<Vector2> { V2(0f, 0f), V2(0.038f, 0f), V2(0.038f, 0f), V2(0.04f, 0.095f), V2(0.04f, 0.095f), V2(0.035f, 0.095f), V2(0.033f, 0.012f), V2(0f, 0.012f) };
            kit.Part(g, "Tasse", kit.Cached("mug", () => MeshFactory.Lathe(prof, 20)), pal.Ceramic, Vector3.zero);
            var handle = MeshFactory.Arc(V(0.045f, 0.05f, 0f), Vector3.up, Vector3.right, 0.026f, -80f, 80f, 10);
            kit.Part(g, "Anse", kit.Cached("mugHandle", () => MeshFactory.Tube(handle, 0.006f, 6)), pal.Ceramic, Vector3.zero);
            kit.Part(g, "Cafe", kit.CylinderMesh(0.034f, 0.002f, 16), pal.Soil, V(0f, 0.08f, 0f), false);
        }

        void DeskLamp(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Lampe_Bureau", pos, yaw);
            kit.Part(g, "Socle", kit.RoundedCylinderMesh(0.075f, 0.02f, 0.008f), pal.BlackMetal, Vector3.zero);
            var arm = new List<Vector3> { V(0f, 0.02f, 0f), V(0f, 0.3f, -0.06f), V(0f, 0.42f, 0.12f) };
            kit.Part(g, "Bras", kit.Cached("lampArm", () => MeshFactory.Tube(arm, 0.007f, 8)), pal.BlackMetal, Vector3.zero);
            var shade = new List<Vector2> { V2(0f, 0.06f), V2(0.03f, 0.06f), V2(0.03f, 0.06f), V2(0.07f, 0f), V2(0.07f, 0f), V2(0.065f, 0f), V2(0.026f, 0.055f), V2(0f, 0.055f) };
            var head = WorldKit.Group(g, "Tete", V(0f, 0.38f, 0.15f));
            head.localRotation = Quaternion.Euler(18f, 0f, 0f);
            kit.Part(head, "Abat_jour", kit.Cached("lampShade", () => MeshFactory.Lathe(shade, 24)), pal.BlackMetal, Vector3.zero);
            kit.Part(head, "Ampoule", kit.SphereMesh(0.022f), kit.Mat.Emissive("Bulb", Color.white, new Color(1f, 0.85f, 0.6f) * 6f), V(0f, 0.02f, 0f), false);
            var lgo = new GameObject("Lumiere");
            lgo.transform.SetParent(head, false);
            lgo.transform.localPosition = V(0f, 0.0f, 0f);
            lgo.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
            var l = lgo.AddComponent<Light>();
            l.type = LightType.Spot;
            l.spotAngle = 110f;
            l.innerSpotAngle = 60f;
            l.range = 1.6f;
            l.intensity = 1.1f;
            l.color = new Color(1f, 0.82f, 0.6f);
            l.shadows = LightShadows.None;
            world.AllLights.Add(l);
        }

        void Stethoscope(Transform parent, Vector3 pos)
        {
            var g = WorldKit.Group(parent, "Stethoscope", pos, 20f);
            var path = new List<Vector3>();
            for (int i = 0; i <= 40; i++)
            {
                float t = i / 40f;
                float a = t * Mathf.PI * 2.6f;
                float r = 0.07f + 0.025f * Mathf.Sin(t * 5f);
                path.Add(V(Mathf.Cos(a) * r, 0.007f + 0.004f * Mathf.Sin(a * 0.5f), Mathf.Sin(a) * r * 0.8f));
            }
            kit.Part(g, "Tubulure", kit.Cached("stethoTube", () => MeshFactory.Tube(path, 0.0055f, 8)), pal.PlasticDark, Vector3.zero);
            var lastP = path[path.Count - 1];
            var lyre = new List<Vector3> { lastP, lastP + V(0.05f, 0.002f, 0.02f), lastP + V(0.1f, 0.004f, 0.0f) };
            kit.Part(g, "Lyre", kit.Cached("stethoLyre", () => MeshFactory.Tube(lyre, 0.0035f, 6)), pal.Chrome, Vector3.zero);
            kit.Part(g, "Pavillon", kit.RoundedCylinderMesh(0.022f, 0.012f, 0.004f, 20), pal.Chrome, path[0] + V(0f, -0.006f, 0f));
            kit.Part(g, "Membrane", kit.CylinderMesh(0.018f, 0.002f, 20), pal.PlasticDark, path[0] + V(0f, 0.006f, 0f), false);
        }

        void BloodPressureMonitor(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Tensiometre", pos, yaw);
            kit.Box(g, "Boitier", V(0.12f, 0.06f, 0.15f), pal.PlasticWhite, V(0f, 0.03f, 0f), 0.015f, false, Quaternion.Euler(-10f, 0f, 0f));
            kit.Box(g, "Ecran", V(0.08f, 0.004f, 0.06f), kit.Mat.Emissive("LcdGrey", new Color(0.6f, 0.68f, 0.62f), new Color(0.35f, 0.42f, 0.38f)), V(0f, 0.062f, 0.02f), 0.001f, false, Quaternion.Euler(-10f, 0f, 0f));
            kit.Box(g, "Bouton", V(0.03f, 0.008f, 0.02f), pal.KidBlue, V(0f, 0.058f, -0.04f), 0.004f);
            kit.Box(g, "Brassard", V(0.22f, 0.035f, 0.13f), pal.FabricNavy, V(0.2f, 0.018f, 0.02f), 0.015f, false, Quaternion.Euler(0f, 15f, 0f));
            var hose = new List<Vector3> { V(0.05f, 0.03f, 0.02f), V(0.09f, 0.012f, 0.07f), V(0.15f, 0.01f, 0.05f) };
            kit.Part(g, "Tuyau", kit.Cached("bpHose", () => MeshFactory.Tube(hose, 0.004f, 6)), pal.PlasticDark, Vector3.zero);
        }

        void Paravent(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Paravent", pos, yaw);
            float[] angles = { -25f, 0f, 25f };
            float x = -0.5f;
            for (int i = 0; i < 3; i++)
            {
                var panel = WorldKit.Group(g, "Volet", V(x, 0f, 0f), angles[i]);
                kit.Box(panel, "Toile", V(0.48f, 1.45f, 0.01f), pal.FabricScreen, V(0f, 0.95f, 0f), 0.002f);
                kit.Cylinder(panel, "Montant", 0.012f, 1.75f, pal.Chrome, V(-0.25f, 0f, 0f), 10);
                kit.Cylinder(panel, "Montant", 0.012f, 1.75f, pal.Chrome, V(0.25f, 0f, 0f), 10);
                kit.Part(panel, "Roulette", kit.SphereMesh(0.02f), pal.PlasticDark, V(-0.25f, 0.02f, 0f));
                kit.Part(panel, "Roulette", kit.SphereMesh(0.02f), pal.PlasticDark, V(0.25f, 0.02f, 0f));
                x += 0.5f;
            }
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.9f, 0f);
            col.size = V(1.5f, 1.8f, 0.3f);
        }

        void SinkUnit(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Lavabo", pos, yaw);
            kit.Box(g, "Meuble", V(1.1f, 0.84f, 0.48f), pal.DeskWhite, V(0f, 0.43f, 0f), 0.01f, true);
            kit.Box(g, "Plan", V(1.12f, 0.04f, 0.5f), pal.Ceramic, V(0f, 0.87f, 0f), 0.01f);
            kit.Box(g, "Vasque", V(0.46f, 0.1f, 0.34f), pal.Ceramic, V(0f, 0.93f, 0.02f), 0.04f);
            kit.Box(g, "Fond_Vasque", V(0.38f, 0.005f, 0.26f), kit.Mat.Lit("BasinIn", new Color(0.86f, 0.88f, 0.9f), 0.9f), V(0f, 0.982f, 0.02f), 0.002f, false, null, false);
            kit.Part(g, "Bonde", kit.CylinderMesh(0.02f, 0.002f, 16), pal.Chrome, V(0f, 0.983f, 0.02f), false);
            var spout = new List<Vector3> { V(0f, 0.89f, -0.2f), V(0f, 1.15f, -0.2f), V(0f, 1.2f, -0.12f), V(0f, 1.12f, -0.04f) };
            kit.Part(g, "Robinet", kit.Cached("faucet", () => MeshFactory.Tube(spout, 0.012f, 10)), pal.Chrome, Vector3.zero);
            kit.Box(g, "Levier", V(0.02f, 0.02f, 0.12f), pal.Chrome, V(0.06f, 1.0f, -0.2f), 0.008f, false, Quaternion.Euler(-30f, 0f, 0f));
            kit.Box(g, "Credence", V(1.1f, 0.6f, 0.01f), pal.Tiles, V(0f, 1.2f, -0.24f), 0.002f);
            kit.Box(g, "Miroir", V(0.6f, 0.62f, 0.008f), pal.Mirror, V(0f, 1.62f, -0.235f), 0.004f);
            kit.Box(g, "Savon", V(0.1f, 0.18f, 0.08f), pal.PlasticWhite, V(0.45f, 1.18f, -0.2f), 0.012f);
            kit.Box(g, "Essuie_Mains", V(0.3f, 0.36f, 0.12f), pal.PlasticWhite, V(-0.48f, 1.45f, -0.18f), 0.02f);
            kit.Box(g, "Fente", V(0.22f, 0.012f, 0.02f), pal.PlasticDark, V(-0.48f, 1.28f, -0.12f), 0.004f);
            var it = g.GetChild(0).gameObject.AddComponent<SimpleInteractable>();
            it.Verb = "Se laver les mains";
            it.Target = "Lavabo";
            Vector3 p = pos + V(0f, 1f, 0f);
            it.OnInteract = () => GameRoot.Instance?.WashHands(p, true);
        }

        void Scale(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Toise_Balance", pos, yaw);
            kit.Box(g, "Plateau", V(0.36f, 0.06f, 0.4f), pal.PlasticWhite, V(0f, 0.03f, 0.05f), 0.02f, true);
            kit.Box(g, "Antiderapant", V(0.3f, 0.004f, 0.3f), pal.PlasticDark, V(0f, 0.062f, 0.06f), 0.002f);
            kit.Box(g, "Colonne", V(0.05f, 1.3f, 0.05f), pal.Steel, V(0f, 0.7f, -0.13f), 0.01f);
            kit.Box(g, "Afficheur", V(0.26f, 0.13f, 0.08f), pal.PlasticWhite, V(0f, 1.38f, -0.12f), 0.02f, false, Quaternion.Euler(-15f, 0f, 0f));
            kit.Box(g, "LCD", V(0.16f, 0.05f, 0.004f), kit.Mat.Emissive("LcdBlue", new Color(0.2f, 0.4f, 0.6f), new Color(0.25f, 0.55f, 0.9f) * 0.8f), V(0f, 1.395f, -0.078f), 0.001f, false, Quaternion.Euler(-15f, 0f, 0f));
        }

        void HeightGauge(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "Toise_Murale", pos, yaw);
            kit.Box(g, "Regle", V(0.07f, 1.9f, 0.012f), pal.PlasticWhite, V(0f, 1.05f, 0.006f), 0.003f);
            for (int i = 0; i < 19; i++)
                kit.Box(g, "Graduation", V(i % 2 == 0 ? 0.04f : 0.025f, 0.004f, 0.002f), pal.PlasticDark, V(-0.01f, 0.2f + i * 0.1f, 0.013f), 0.0005f, false, null, false);
            kit.Box(g, "Curseur", V(0.14f, 0.03f, 0.18f), pal.KidBlue, V(0f, 1.72f, 0.09f), 0.008f);
        }

        void TrashBin(Transform parent, Vector3 pos, Material m)
        {
            var g = WorldKit.Group(parent, "Poubelle", pos);
            var prof = new List<Vector2> { V2(0f, 0f), V2(0.12f, 0f), V2(0.12f, 0f), V2(0.145f, 0.34f), V2(0.145f, 0.34f), V2(0.135f, 0.34f), V2(0.11f, 0.02f), V2(0f, 0.02f) };
            kit.Part(g, "Corps", kit.Cached("bin", () => MeshFactory.Lathe(prof, 24)), m, Vector3.zero);
            var col = g.gameObject.AddComponent<BoxCollider>();
            col.center = V(0f, 0.17f, 0f);
            col.size = V(0.3f, 0.34f, 0.3f);
        }

        void DasriBox(Transform parent, Vector3 pos, float yaw)
        {
            var g = WorldKit.Group(parent, "DASRI", pos, yaw);
            kit.Box(g, "Support", V(0.3f, 0.05f, 0.04f), pal.Steel, V(0f, -0.17f, 0.02f), 0.006f);
            kit.Box(g, "Boite", V(0.26f, 0.32f, 0.2f), pal.Yellow, V(0f, 0f, 0.11f), 0.015f);
            kit.Box(g, "Couvercle", V(0.27f, 0.04f, 0.21f), pal.Yellow, V(0f, 0.17f, 0.11f), 0.012f);
            kit.Box(g, "Fente", V(0.12f, 0.006f, 0.04f), pal.PlasticDark, V(0f, 0.191f, 0.13f), 0.002f, false, null, false);
            kit.Box(g, "Etiquette", V(0.12f, 0.1f, 0.004f), pal.PlasticWhite, V(0f, 0.01f, 0.212f), 0.001f, false, null, false);
        }

        void Radiator(Transform parent, Vector3 pos, float yaw, float width)
        {
            var g = WorldKit.Group(parent, "Radiateur", pos, yaw);
            var md = new MeshData();
            var fin = MeshFactory.RoundedBox(V(0.035f, 0.55f, 0.07f), 0.012f, 2);
            int fins = Mathf.RoundToInt(width / 0.05f);
            for (int i = 0; i < fins; i++) md.Append(fin, V(-width * 0.5f + 0.025f + i * 0.05f, 0.275f, 0f));
            kit.Part(g, "Elements", kit.FromData("radiator" + fins, md), pal.PlasticWhite, Vector3.zero);
            kit.Box(g, "Collecteur_H", V(width, 0.03f, 0.04f), pal.PlasticWhite, V(0f, 0.53f, 0f), 0.01f);
            kit.Box(g, "Collecteur_B", V(width, 0.03f, 0.04f), pal.PlasticWhite, V(0f, 0.02f, 0f), 0.01f);
            kit.Cylinder(g, "Vanne", 0.02f, 0.06f, pal.Chrome, V(width * 0.5f + 0.02f, 0f, 0f), 12);
        }

        // ================================================================== Salle de pause

        void BuildBreakRoom()
        {
            var g = WorldKit.Group(propsRoot, "Salle_Pause", Vector3.zero);
            float x0 = L.ConsultMaxX + 0.06f, x1 = L.BreakMaxX - 0.06f;
            // Plan de travail le long du mur est
            kit.Box(g, "Meubles_Bas", V(0.56f, 0.86f, 3.3f), pal.DeskWhite, V(x1 - 0.28f, 0.43f, 10.75f), 0.01f, true);
            kit.Box(g, "Plan", V(0.6f, 0.04f, 3.32f), pal.Oak, V(x1 - 0.3f, 0.88f, 10.75f), 0.006f);
            for (int i = 0; i < 5; i++)
                kit.Box(g, "Porte_Meuble", V(0.01f, 0.76f, 0.64f), pal.DeskWhite, V(x1 - 0.565f, 0.43f, 9.2f + i * 0.66f + 0.33f), 0.003f);
            kit.Box(g, "Credence", V(0.01f, 0.6f, 3.3f), pal.Tiles, V(x1 - 0.005f, 1.2f, 10.75f), 0.002f);
            kit.Box(g, "Meubles_Hauts", V(0.35f, 0.7f, 2.4f), pal.DeskWhite, V(x1 - 0.175f, 1.95f, 11.0f), 0.01f);

            // Machine à café (interactive)
            var cm = WorldKit.Group(g, "Machine_Cafe", V(x1 - 0.3f, 0.9f, 10.0f), -90f);
            kit.Box(cm, "Corps", V(0.28f, 0.38f, 0.36f), pal.PlasticDark, V(0f, 0.19f, 0f), 0.03f, true);
            kit.Box(cm, "Facade", V(0.24f, 0.12f, 0.01f), pal.Chrome, V(0f, 0.3f, 0.181f), 0.004f);
            kit.Box(cm, "Bec", V(0.06f, 0.04f, 0.06f), pal.Chrome, V(0f, 0.19f, 0.16f), 0.01f);
            kit.Box(cm, "Grille", V(0.18f, 0.015f, 0.12f), pal.Chrome, V(0f, 0.02f, 0.13f), 0.004f);
            kit.Part(cm, "Voyant", kit.RoundedBoxMesh(V(0.012f, 0.012f, 0.004f), 0.002f), pal.Led, V(0.08f, 0.33f, 0.187f), false);
            Mug(cm, V(0f, 0.03f, 0.12f));
            var cmi = cm.GetChild(0).gameObject.AddComponent<SimpleInteractable>();
            cmi.Verb = "Prendre un café";
            cmi.Target = "Machine à café";
            Vector3 cmPos = cm.position + V(0f, 0.2f, 0f);
            cmi.OnInteract = () => GameRoot.Instance?.DrinkCoffee(cmPos);

            // Micro-ondes, bouilloire
            var mw = WorldKit.Group(g, "Micro_Ondes", V(x1 - 0.3f, 0.9f, 11.4f), -90f);
            kit.Box(mw, "Corps", V(0.48f, 0.28f, 0.36f), pal.PlasticWhite, V(0f, 0.14f, 0f), 0.015f);
            kit.Box(mw, "Porte", V(0.32f, 0.2f, 0.01f), pal.DarkGlass, V(-0.05f, 0.14f, 0.181f), 0.004f);
            kit.Box(mw, "Panneau", V(0.1f, 0.22f, 0.008f), pal.PlasticGrey, V(0.17f, 0.14f, 0.18f), 0.003f);

            // Réfrigérateur
            var fr = WorldKit.Group(g, "Frigo", V(x1 - 0.33f, 0f, 8.3f), -90f);
            kit.Box(fr, "Corps", V(0.6f, 1.8f, 0.64f), pal.Steel, V(0f, 0.9f, 0f), 0.02f, true);
            kit.Box(fr, "Joint", V(0.58f, 0.006f, 0.005f), pal.PlasticDark, V(0f, 1.18f, 0.322f), 0.001f, false, null, false);
            kit.Box(fr, "Poignee_H", V(0.02f, 0.3f, 0.03f), pal.Chrome, V(-0.24f, 1.45f, 0.34f), 0.008f);
            kit.Box(fr, "Poignee_B", V(0.02f, 0.4f, 0.03f), pal.Chrome, V(-0.24f, 0.85f, 0.34f), 0.008f);
            kit.Quad(fr, "Dessin", 0.18f, 0.135f, kit.Mat.Decal("Fridge", "KidsDrawing", 0.2f), V(0.08f, 1.45f, 0.322f), Quaternion.identity);

            // Table ronde + chaises
            var t = WorldKit.Group(g, "Table_Ronde", V(9.3f, 0f, 10.2f));
            kit.Part(t, "Plateau", kit.RoundedCylinderMesh(0.5f, 0.03f, 0.01f, 40), pal.DeskWhite, V(0f, 0.72f, 0f));
            kit.Cylinder(t, "Fut", 0.04f, 0.72f, pal.BlackMetal, Vector3.zero, 16);
            kit.Part(t, "Pied", kit.RoundedCylinderMesh(0.28f, 0.02f, 0.008f, 32), pal.BlackMetal, Vector3.zero);
            var tcol = t.gameObject.AddComponent<BoxCollider>();
            tcol.center = V(0f, 0.37f, 0f);
            tcol.size = V(0.9f, 0.75f, 0.9f);
            for (int i = 0; i < 3; i++)
            {
                float a = 30f + i * 120f;
                Vector3 p = V(9.3f, 0f, 10.2f) + Quaternion.Euler(0f, a, 0f) * V(0f, 0f, 0.72f);
                WoodChair(g, p, a + 180f, pal.FabricMustard);
            }
            Mug(t, V(0.15f, 0.735f, -0.1f));
            Magazine(t, V(-0.12f, 0.738f, 0.08f), 40f, 5);

            Plant(g, V(x0 + 0.38f, 0f, 12.08f), 1.1f, 51);
            Frame(g, "Calendar", V(x0, 1.6f, 9.0f), 90f, 0.34f, 0.46f, pal.PlasticWhite);
            Frame(g, "KidsDrawing", V(x0, 1.55f, 10.4f), 90f, 0.4f, 0.3f, pal.Oak);
            TrashBin(g, V(x1 - 0.3f, 0f, 8.85f), pal.KidGreen);
            Radiator(g, V(9.5f, 0.15f, L.MaxZ - 0.06f), 180f, 1.8f);
        }
    }
}
