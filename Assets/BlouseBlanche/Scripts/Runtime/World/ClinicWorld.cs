using System.Collections.Generic;
using UnityEngine;

namespace BlouseBlanche.World
{
    /// <summary>Cotes du plan (mètres). X = est, Z = nord, Y = haut. Origine = angle sud-ouest intérieur.</summary>
    public static class ClinicLayout
    {
        public const float WallHeight = 2.8f;
        public const float ExteriorThickness = 0.25f;
        public const float InteriorThickness = 0.12f;
        public const float MaxX = 15f;
        public const float MaxZ = 12.5f;
        public const float PartitionZ = 6.5f;      // mur entre l'accueil et les pièces du fond
        public const float ConsultMaxX = 7.5f;     // cloison cabinet / salle de pause
        public const float BreakMaxX = 11.5f;      // cloison salle de pause / WC
        public const float DoorHeight = 2.1f;

        public const float ConsultDoorX = 5.6f, ConsultDoorW = 0.95f;
        public const float BreakDoorX = 9.4f, BreakDoorW = 0.9f;
        public const float WcDoorX = 13.0f, WcDoorW = 0.85f;
        public const float EntranceX0 = 11.0f, EntranceX1 = 13.0f, EntranceTop = 2.3f;

        // Nœuds du graphe de navigation
        public const string Street = "street", Sidewalk = "sidewalk", Outside = "outside", Inside = "inside";
        public const string Desk = "desk", Queue = "queue";
        public const string LobbyE = "lobbyE", LobbyC = "lobbyC", LobbyW = "lobbyW", LobbyS = "lobbyS";
        public const string ConsultOut = "consultOut", ConsultIn = "consultIn", RoomC = "roomC", BehindChairs = "behindChairs";
        public const string PatientChairNode = "pchair", ExamNode = "exam";
    }

    /// <summary>
    /// Données du monde construit : graphe, places assises, plans caméra, zones.
    /// Rempli par <see cref="ClinicBuilder"/>.
    /// </summary>
    public sealed class ClinicWorld : MonoBehaviour
    {
        public readonly NavGraph Nav = new NavGraph();
        public readonly List<SeatSpot> WaitingSeats = new List<SeatSpot>();
        public SeatSpot PatientChair;
        public SeatSpot CompanionChair;
        public SeatSpot ExamTable;
        public SeatSpot SecretaryChair;

        public Pose DeskShot;
        public Pose ExamShot;
        public Pose[] MenuShots = new Pose[0];

        public Vector3 PlayerSpawn;
        public float PlayerSpawnYaw;
        public Vector3 PlayerAfterConsult;
        public float PlayerAfterConsultYaw;

        public EmergencyLocation Salon;
        public EmergencyLocation ErBox;

        public Bounds ConsultRoom;
        public Bounds Lobby;
        public Vector3 SecretaryHead;
        public Vector3 SinkPoint;

        /// <summary>Points d'ambiance sonore extérieure (oiseaux, vent) et de "room tone" intérieur.</summary>
        public readonly List<Vector3> OutdoorSoundPoints = new List<Vector3>();
        public readonly List<Vector3> RoomTonePoints = new List<Vector3>();
        public Vector3 SecretaryTypingPoint;

        public readonly List<ReflectionProbe> Probes = new List<ReflectionProbe>();
        public readonly List<Light> ShadowedLights = new List<Light>();
        public readonly List<Light> AllLights = new List<Light>();

        public Transform Root => transform;

        public bool IsInConsultRoom(Vector3 p) => ConsultRoom.Contains(new Vector3(p.x, ConsultRoom.center.y, p.z));

        public SeatSpot FreeWaitingSeat(System.Random rng)
        {
            var free = new List<SeatSpot>();
            foreach (var s in WaitingSeats) if (s.Free) free.Add(s);
            if (free.Count == 0) return null;
            return free[rng.Next(free.Count)];
        }

        public static Pose LookPose(Vector3 position, Vector3 target)
        {
            Vector3 d = target - position;
            if (d.sqrMagnitude < 1e-6f) d = Vector3.forward;
            return new Pose(position, Quaternion.LookRotation(d.normalized, Vector3.up));
        }

        /// <summary>Rafraîchit les sondes de réflexion (après construction / changement de qualité).</summary>
        public void RefreshProbes()
        {
            foreach (var p in Probes) if (p != null) p.RenderProbe();
        }
    }
}
