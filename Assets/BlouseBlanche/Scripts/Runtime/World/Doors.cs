using System.Collections.Generic;
using BlouseBlanche.Core;
using UnityEngine;

namespace BlouseBlanche.World
{
    /// <summary>Registre des entités qui déclenchent l'ouverture automatique des portes.</summary>
    public static class DoorSensors
    {
        static readonly List<Transform> sensors = new List<Transform>();
        public static IReadOnlyList<Transform> All => sensors;

        public static void Register(Transform t)
        {
            if (t != null && !sensors.Contains(t)) sensors.Add(t);
        }

        public static void Unregister(Transform t) => sensors.Remove(t);

        public static void Clear() => sensors.Clear();

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void ResetStatics() => sensors.Clear();

        public static bool AnyWithin(Vector3 center, float radius)
        {
            float r2 = radius * radius;
            for (int i = sensors.Count - 1; i >= 0; i--)
            {
                var s = sensors[i];
                if (s == null) { sensors.RemoveAt(i); continue; }
                Vector3 d = s.position - center;
                d.y = 0f;
                if (d.sqrMagnitude < r2) return true;
            }
            return false;
        }
    }

    /// <summary>
    /// Porte battante automatique (s'ouvre à l'approche du joueur ou d'un patient).
    /// Le collider du battant n'est actif que porte fermée : aucun risque de coincer un personnage.
    /// </summary>
    public sealed class AutoDoor : MonoBehaviour
    {
        public Transform Hinge;
        public Collider PanelCollider;
        public float OpenAngle = 90f;
        public float SensorRadius = 1.45f;
        public Vector3 SensorCenter;
        public bool Locked;
        public float Speed = 2.2f;

        float openness;      // 0 fermé .. 1 ouvert
        float closeDelay;
        bool wasOpening;
        Quaternion closedRotation;

        void Start()
        {
            if (Hinge != null) closedRotation = Hinge.localRotation;
        }

        void Update()
        {
            if (Hinge == null) return;
            bool want = !Locked && DoorSensors.AnyWithin(SensorCenter, SensorRadius);
            if (want) closeDelay = 1.2f;
            else closeDelay -= Time.deltaTime;
            bool opening = want || closeDelay > 0f;

            if (opening != wasOpening)
            {
                var audio = GameRoot.Instance != null ? GameRoot.Instance.Audio : null;
                if (audio != null) audio.PlayAt(opening ? Sfx.DoorOpen : Sfx.DoorClose, SensorCenter + Vector3.up * 1.2f, 0.55f);
                wasOpening = opening;
            }

            float target = opening ? 1f : 0f;
            openness = Mathf.MoveTowards(openness, target, Time.deltaTime * Speed);
            float k = openness * openness * (3f - 2f * openness);
            Hinge.localRotation = closedRotation * Quaternion.Euler(0f, OpenAngle * k, 0f);
            if (PanelCollider != null) PanelCollider.enabled = openness < 0.02f;
        }
    }

    /// <summary>Porte d'entrée vitrée coulissante à deux vantaux.</summary>
    public sealed class SlidingDoor : MonoBehaviour
    {
        public Transform Left;
        public Transform Right;
        public Collider BlockCollider;
        public float Travel = 0.95f;
        public float SensorRadius = 2.2f;
        public Vector3 SensorCenter;
        public float Speed = 1.4f;

        float openness;
        float closeDelay;
        bool wasOpening;
        Vector3 leftClosed, rightClosed;

        void Start()
        {
            if (Left != null) leftClosed = Left.localPosition;
            if (Right != null) rightClosed = Right.localPosition;
        }

        void Update()
        {
            bool want = DoorSensors.AnyWithin(SensorCenter, SensorRadius);
            if (want) closeDelay = 1.5f;
            else closeDelay -= Time.deltaTime;
            bool opening = want || closeDelay > 0f;
            if (opening != wasOpening)
            {
                var root = GameRoot.Instance;
                if (root != null && root.Audio != null)
                {
                    root.Audio.PlayAt(Sfx.SlidingDoor, SensorCenter + Vector3.up * 2f, 0.5f);
                    if (opening) root.Audio.PlayAt(Sfx.EntranceChime, SensorCenter + Vector3.up * 2.4f, 0.35f, 0f);
                }
                wasOpening = opening;
            }
            openness = Mathf.MoveTowards(openness, opening ? 1f : 0f, Time.deltaTime * Speed);
            float k = openness * openness * (3f - 2f * openness);
            if (Left != null) Left.localPosition = leftClosed + Vector3.left * (Travel * k);
            if (Right != null) Right.localPosition = rightClosed + Vector3.right * (Travel * k);
            if (BlockCollider != null) BlockCollider.enabled = openness < 0.6f;
        }
    }

    /// <summary>Horloge murale dont les aiguilles suivent l'heure du jeu.</summary>
    public sealed class WallClock : MonoBehaviour
    {
        public Transform HourHand;
        public Transform MinuteHand;
        public Transform SecondHand;

        void Update()
        {
            var root = GameRoot.Instance;
            float minutes = root != null && root.Clock != null ? root.Clock.Minutes : 9f * 60f;
            float h = (minutes / 60f) % 12f;
            float m = minutes % 60f;
            float s = (minutes * 60f) % 60f;
            // Les aiguilles tournent autour de l'axe local Z (le cadran fait face à +Z).
            if (HourHand != null) HourHand.localRotation = Quaternion.Euler(0f, 0f, h * 30f);
            if (MinuteHand != null) MinuteHand.localRotation = Quaternion.Euler(0f, 0f, m * 6f);
            if (SecondHand != null) SecondHand.localRotation = Quaternion.Euler(0f, 0f, s * 6f);
        }
    }
}
