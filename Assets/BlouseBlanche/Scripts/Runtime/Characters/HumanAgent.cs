using System;
using System.Collections.Generic;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Characters
{
    /// <summary>
    /// Déplacement d'un personnage par une file d'étapes (marcher, s'asseoir, se lever, attendre…).
    /// Déterministe : un personnage ne peut pas se bloquer, chaque étape a une fin garantie.
    /// </summary>
    public sealed class HumanAgent : MonoBehaviour
    {
        public HumanRig Rig;
        public HumanAnimator Anim;
        public NavGraph Nav;
        public float WalkSpeed = 1.15f;
        public string CurrentNode;
        public SeatSpot Seat { get; private set; }

        readonly Queue<Step> steps = new Queue<Step>();
        Step current;
        float yaw;
        float speed;

        public bool Idle => current == null && steps.Count == 0;
        public bool IsSeated => Seat != null && Anim != null && Anim.IsSeated;
        public float Yaw => yaw;

        // ================================================================== API

        public void Teleport(Vector3 position, float yawDeg, string node)
        {
            transform.position = new Vector3(position.x, 0f, position.z);
            yaw = yawDeg;
            transform.rotation = Quaternion.Euler(0f, yaw, 0f);
            CurrentNode = node;
        }

        /// <summary>Installe directement le personnage assis (secrétaire en début de journée).</summary>
        public void PlaceSeated(SeatSpot seat)
        {
            Seat = seat;
            seat.Occupant = this;
            Teleport(seat.Anchor, seat.Yaw, seat.ApproachNode);
            if (Anim != null) { Anim.SeatHeight = seat.SeatHeight; Anim.Sit = 1f; }
        }

        public void ClearSteps()
        {
            steps.Clear();
            current = null;
            speed = 0f;
            if (pendingSeat != null && pendingSeat != Seat && pendingSeat.Occupant == (object)this) pendingSeat.Occupant = null;
            pendingSeat = null;
            if (Anim != null && Seat == null) Anim.Sit = 0f;
        }

        SeatSpot pendingSeat;

        public HumanAgent WalkTo(string node) { steps.Enqueue(new WalkPathStep(node)); return this; }
        public HumanAgent WalkToPoint(Vector3 p) { steps.Enqueue(new WalkPointStep(p)); return this; }
        public HumanAgent Face(float yawDeg) { steps.Enqueue(new FaceStep(() => yawDeg)); return this; }
        public HumanAgent FaceTowards(Vector3 p) { steps.Enqueue(new FaceStep(() => YawTowards(p))); return this; }
        public HumanAgent Wait(float seconds) { steps.Enqueue(new WaitStep(seconds)); return this; }
        public HumanAgent WaitUntil(Func<bool> cond, float timeout = 600f) { steps.Enqueue(new WaitUntilStep(cond, timeout)); return this; }
        public HumanAgent Then(Action a) { steps.Enqueue(new ActionStep(a)); return this; }

        /// <summary>Aller s'asseoir sur une place (réservation immédiate).</summary>
        public HumanAgent SitOn(SeatSpot seat)
        {
            seat.Occupant = this;
            pendingSeat = seat;
            if (!string.IsNullOrEmpty(seat.ApproachNode)) WalkTo(seat.ApproachNode);
            Vector3 stand = StandPoint(seat);
            WalkToPoint(stand);
            Face(seat.Yaw);
            steps.Enqueue(new SitStep(seat));
            return this;
        }

        /// <summary>Se lever et revenir au nœud d'approche de la place.</summary>
        public HumanAgent StandUp()
        {
            steps.Enqueue(new StandStep());
            return this;
        }

        public static Vector3 StandPoint(SeatSpot seat) => seat.Anchor + seat.Forward * 0.42f;

        float YawTowards(Vector3 p)
        {
            Vector3 d = p - transform.position;
            d.y = 0f;
            return d.sqrMagnitude < 1e-6f ? yaw : Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg;
        }

        void Awake()
        {
            yaw = transform.eulerAngles.y;
        }

        void Update()
        {
            float dt = Time.deltaTime;
            if (current == null && steps.Count > 0)
            {
                current = steps.Dequeue();
                current.Begin(this);
            }
            if (current != null && current.Tick(this, dt)) current = null;
            if (Anim != null) Anim.Speed = speed;
            transform.rotation = Quaternion.Euler(0f, yaw, 0f);
        }

        // ================================================================== mouvement de base

        /// <summary>Avance vers un point ; renvoie vrai à l'arrivée.</summary>
        bool MoveTowards(Vector3 target, float dt, bool decelerate)
        {
            Vector3 p = transform.position;
            Vector3 d = target - p;
            d.y = 0f;
            float dist = d.magnitude;
            if (dist < 0.035f)
            {
                transform.position = new Vector3(target.x, 0f, target.z);
                if (decelerate) speed = 0f;
                return true;
            }
            float desiredYaw = Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg;
            float diff = Mathf.Abs(Mathf.DeltaAngle(yaw, desiredYaw));
            yaw = Mathf.MoveTowardsAngle(yaw, desiredYaw, 300f * dt);
            float maxSpeed = WalkSpeed * (diff > 70f ? 0.25f : diff > 35f ? 0.6f : 1f);
            if (decelerate) maxSpeed = Mathf.Min(maxSpeed, Mathf.Max(0.3f, dist / 0.55f) * WalkSpeed);
            speed = Mathf.MoveTowards(speed, maxSpeed, 2.6f * dt);
            float stepLen = Mathf.Min(dist, Mathf.Max(0.05f, speed) * dt);
            transform.position = p + d / dist * stepLen;
            return false;
        }

        // ================================================================== étapes

        abstract class Step
        {
            public virtual void Begin(HumanAgent a) { }
            public abstract bool Tick(HumanAgent a, float dt);
        }

        sealed class WalkPathStep : Step
        {
            readonly string target;
            List<Vector3> pts;
            List<string> ids;
            int i;
            public WalkPathStep(string target) { this.target = target; }

            public override void Begin(HumanAgent a)
            {
                string from = a.CurrentNode;
                if (string.IsNullOrEmpty(from) || !a.Nav.Has(from)) from = a.Nav.Nearest(a.transform.position);
                ids = a.Nav.FindPath(from, target);
                pts = new List<Vector3>();
                foreach (var id in ids) pts.Add(a.Nav.Position(id));
                if (pts.Count == 0 && a.Nav.Has(target)) { pts.Add(a.Nav.Position(target)); ids = new List<string> { target }; }
                i = 0;
            }

            public override bool Tick(HumanAgent a, float dt)
            {
                if (pts == null || i >= pts.Count) { if (a.Nav.Has(target)) a.CurrentNode = target; return true; }
                bool last = i == pts.Count - 1;
                if (a.MoveTowards(pts[i], dt, last))
                {
                    a.CurrentNode = ids[i];
                    i++;
                    if (i >= pts.Count) return true;
                }
                return false;
            }
        }

        sealed class WalkPointStep : Step
        {
            readonly Vector3 p;
            public WalkPointStep(Vector3 p) { this.p = p; }
            public override bool Tick(HumanAgent a, float dt) => a.MoveTowards(p, dt, true);
        }

        sealed class FaceStep : Step
        {
            readonly Func<float> yawProvider;
            float target;
            public FaceStep(Func<float> yawProvider) { this.yawProvider = yawProvider; }
            public override void Begin(HumanAgent a) { target = yawProvider(); a.speed = 0f; }
            public override bool Tick(HumanAgent a, float dt)
            {
                a.yaw = Mathf.MoveTowardsAngle(a.yaw, target, 240f * dt);
                return Mathf.Abs(Mathf.DeltaAngle(a.yaw, target)) < 1f;
            }
        }

        sealed class WaitStep : Step
        {
            float left;
            public WaitStep(float s) { left = s; }
            public override bool Tick(HumanAgent a, float dt) { left -= dt; return left <= 0f; }
        }

        sealed class WaitUntilStep : Step
        {
            readonly Func<bool> cond;
            float left;
            public WaitUntilStep(Func<bool> cond, float timeout) { this.cond = cond; left = timeout; }
            public override bool Tick(HumanAgent a, float dt) { left -= dt; return left <= 0f || cond(); }
        }

        sealed class ActionStep : Step
        {
            readonly Action action;
            public ActionStep(Action action) { this.action = action; }
            public override bool Tick(HumanAgent a, float dt)
            {
                try { action?.Invoke(); }
                catch (Exception e) { Debug.LogException(e); }
                return true;
            }
        }

        sealed class SitStep : Step
        {
            readonly SeatSpot seat;
            Vector3 from;
            float t;
            const float Duration = 1.0f;
            public SitStep(SeatSpot seat) { this.seat = seat; }
            public override void Begin(HumanAgent a)
            {
                from = a.transform.position;
                a.speed = 0f;
                a.Seat = seat;
                seat.Occupant = a;
                if (a.Anim != null) a.Anim.SeatHeight = seat.SeatHeight;
            }
            public override bool Tick(HumanAgent a, float dt)
            {
                t = Mathf.Min(1f, t + dt / Duration);
                float k = t * t * (3f - 2f * t);
                a.transform.position = Vector3.Lerp(from, seat.Anchor, k);
                a.yaw = Mathf.LerpAngle(a.yaw, seat.Yaw, k);
                if (a.Anim != null) a.Anim.Sit = k;
                return t >= 1f;
            }
        }

        sealed class StandStep : Step
        {
            SeatSpot seat;
            Vector3 from, to;
            float sit0;
            float t;
            bool walking;
            const float Duration = 0.9f;
            public override void Begin(HumanAgent a)
            {
                seat = a.Seat;
                from = a.transform.position;
                to = seat != null ? StandPoint(seat) : a.transform.position;
                sit0 = a.Anim != null ? a.Anim.Sit : 0f;
                a.speed = 0f;
            }
            public override bool Tick(HumanAgent a, float dt)
            {
                if (seat == null) { if (a.Anim != null) a.Anim.Sit = 0f; return true; }
                if (!walking)
                {
                    t = Mathf.Min(1f, t + dt / Duration);
                    float k = t * t * (3f - 2f * t);
                    a.transform.position = Vector3.Lerp(from, to, k);
                    if (a.Anim != null) a.Anim.Sit = sit0 * (1f - k);
                    if (t >= 1f)
                    {
                        if (seat.Occupant == (object)a) seat.Occupant = null;
                        a.Seat = null;
                        walking = !string.IsNullOrEmpty(seat.ApproachNode) && a.Nav.Has(seat.ApproachNode);
                        if (!walking) return true;
                    }
                    return false;
                }
                if (a.MoveTowards(a.Nav.Position(seat.ApproachNode), dt, false))
                {
                    a.CurrentNode = seat.ApproachNode;
                    return true;
                }
                return false;
            }
        }
    }
}
