using BlouseBlanche.Core;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    /// <summary>Contrôleur à la première personne (CharacterController) : marche, course, regard, bob, pas.</summary>
    public sealed class PlayerController : MonoBehaviour
    {
        public float EyeHeight = 1.66f;
        public float WalkSpeed = 2.3f;
        public float RunSpeed = 4.0f;
        public bool InputEnabled;

        CharacterController cc;
        float yaw, pitch;
        Vector3 planarVelocity;
        float verticalVelocity;
        float bobPhase, bobAmount, stepDistance;
        float fovKick;
        GameSettings settings;

        public float Yaw => yaw;
        public Vector3 Feet => transform.position;

        public void Initialize(GameSettings s)
        {
            settings = s;
            cc = gameObject.AddComponent<CharacterController>();
            cc.height = 1.78f;
            cc.radius = 0.28f;
            cc.center = new Vector3(0f, 0.89f, 0f);
            cc.stepOffset = 0.3f;
            cc.slopeLimit = 50f;
            cc.skinWidth = 0.03f;
            cc.minMoveDistance = 0f;
            DoorSensors.Register(transform);
        }

        public void Teleport(Vector3 feet, float yawDeg, float pitchDeg = 0f)
        {
            if (cc != null) cc.enabled = false;
            transform.position = feet + Vector3.up * 0.02f;
            yaw = yawDeg;
            pitch = pitchDeg;
            planarVelocity = Vector3.zero;
            verticalVelocity = 0f;
            if (cc != null) cc.enabled = true;
        }

        /// <summary>Oriente le regard vers une direction donnée (après une cinématique).</summary>
        public void SetLook(Quaternion rotation)
        {
            Vector3 e = rotation.eulerAngles;
            yaw = e.y;
            pitch = Mathf.DeltaAngle(0f, e.x);
        }

        public Pose EyePose()
        {
            float b = (settings == null || settings.headBob) ? bobAmount : 0f;
            Vector3 bob = new Vector3(Mathf.Cos(bobPhase) * 0.012f * b, Mathf.Abs(Mathf.Sin(bobPhase)) * 0.028f * b, 0f);
            Quaternion rot = Quaternion.Euler(pitch, yaw, 0f);
            Vector3 pos = transform.position + Vector3.up * EyeHeight + Quaternion.Euler(0f, yaw, 0f) * bob;
            return new Pose(pos, rot);
        }

        public float Fov() => (settings != null ? settings.fieldOfView : 72f) + fovKick;

        void Update()
        {
            if (cc == null || !cc.enabled) return;
            float dt = Time.deltaTime;
            if (dt <= 0f) return;

            Vector2 move = Vector2.zero;
            bool sprint = false;
            if (InputEnabled)
            {
                Vector2 look = GameInput.Look();
                float sens = 0.075f * (settings != null ? settings.mouseSensitivity : 1f);
                yaw += look.x * sens;
                pitch += (settings != null && settings.invertY ? 1f : -1f) * look.y * sens;
                pitch = Mathf.Clamp(pitch, -85f, 85f);
                move = GameInput.Move();
                sprint = GameInput.Sprint() && move.y > 0.1f;
            }

            Quaternion yawRot = Quaternion.Euler(0f, yaw, 0f);
            Vector3 wish = yawRot * new Vector3(move.x, 0f, move.y);
            float target = sprint ? RunSpeed : WalkSpeed;
            Vector3 desired = wish * target;
            float accel = desired.sqrMagnitude > planarVelocity.sqrMagnitude ? 12f : 10f;
            planarVelocity = Vector3.MoveTowards(planarVelocity, desired, accel * dt);

            if (cc.isGrounded) verticalVelocity = -1.5f;
            else verticalVelocity -= 18f * dt;

            Vector3 before = transform.position;
            cc.Move((planarVelocity + Vector3.up * verticalVelocity) * dt);
            Vector3 delta = transform.position - before;
            delta.y = 0f;
            float speed = delta.magnitude / dt;

            // Bob de tête et pas
            float moving = Mathf.Clamp01(speed / WalkSpeed);
            bobAmount = Mathf.MoveTowards(bobAmount, cc.isGrounded ? moving : 0f, dt * 4f);
            bobPhase += delta.magnitude * Mathf.PI / (sprint ? 0.95f : 0.75f);
            stepDistance += delta.magnitude;
            float stride = sprint ? 0.95f : 0.75f;
            if (stepDistance >= stride && cc.isGrounded)
            {
                stepDistance = 0f;
                var audio = GameRoot.Instance != null ? GameRoot.Instance.Audio : null;
                if (audio != null) audio.PlayFootstep(transform.position + Vector3.up * 0.05f, sprint ? 0.42f : 0.3f);
            }
            fovKick = Mathf.MoveTowards(fovKick, sprint && speed > WalkSpeed ? 6f : 0f, dt * 20f);
        }
    }
}
