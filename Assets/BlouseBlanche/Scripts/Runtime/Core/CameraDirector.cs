using System;
using UnityEngine;

namespace BlouseBlanche.Core
{
    /// <summary>
    /// Pilote unique de la caméra : vue subjective, plans fixes (consultation) et travelling de menu,
    /// avec transitions lissées entre les modes.
    /// </summary>
    public sealed class CameraDirector : MonoBehaviour
    {
        public enum Mode { FirstPerson, Shot, Cinematic }

        public Camera Cam { get; private set; }
        public Mode CurrentMode { get; private set; } = Mode.Cinematic;

        Func<Pose> firstPersonPose;
        Func<float> firstPersonFov;

        Pose shotPose;
        float shotFov = 50f;
        float shotSway = 0.004f;

        // Travelling de menu : suite de plans, enchaînés lentement.
        Pose[] cinematicKeys = Array.Empty<Pose>();
        float cinematicTime;
        const float CinematicSegment = 14f;

        // Transition
        Pose blendFrom;
        float blendFromFov;
        float blendT = 1f;
        float blendDuration = 1f;

        public void Initialize(Camera cam)
        {
            Cam = cam;
            blendFrom = new Pose(cam.transform.position, cam.transform.rotation);
            blendFromFov = cam.fieldOfView;
        }

        public void SetFirstPerson(Func<Pose> poseProvider, Func<float> fovProvider, float blend = 0.8f)
        {
            firstPersonPose = poseProvider;
            firstPersonFov = fovProvider;
            StartBlend(blend);
            CurrentMode = Mode.FirstPerson;
        }

        public void SetShot(Vector3 position, Quaternion rotation, float fov, float blend = 1.1f, float sway = 0.004f)
        {
            shotPose = new Pose(position, rotation);
            shotFov = fov;
            shotSway = sway;
            StartBlend(blend);
            CurrentMode = Mode.Shot;
        }

        public void SetShotLookAt(Vector3 position, Vector3 target, float fov, float blend = 1.1f, float sway = 0.004f)
        {
            Vector3 dir = target - position;
            if (dir.sqrMagnitude < 1e-6f) dir = Vector3.forward;
            SetShot(position, Quaternion.LookRotation(dir.normalized, Vector3.up), fov, blend, sway);
        }

        public void SetCinematic(Pose[] keys, float blend = 0f)
        {
            cinematicKeys = keys ?? Array.Empty<Pose>();
            cinematicTime = 0f;
            StartBlend(blend);
            CurrentMode = Mode.Cinematic;
        }

        void StartBlend(float duration)
        {
            if (Cam == null) return;
            blendFrom = new Pose(Cam.transform.position, Cam.transform.rotation);
            blendFromFov = Cam.fieldOfView;
            blendDuration = Mathf.Max(0.0001f, duration);
            blendT = duration <= 0f ? 1f : 0f;
        }

        public bool IsBlending => blendT < 1f;

        void LateUpdate()
        {
            if (Cam == null) return;
            float dt = Time.unscaledDeltaTime;
            Pose target;
            float fov;

            switch (CurrentMode)
            {
                case Mode.FirstPerson:
                    target = firstPersonPose != null ? firstPersonPose() : new Pose(Cam.transform.position, Cam.transform.rotation);
                    fov = firstPersonFov != null ? firstPersonFov() : 72f;
                    break;
                case Mode.Shot:
                {
                    float t = Time.unscaledTime;
                    Vector3 sway = new Vector3(Mathf.Sin(t * 0.37f), Mathf.Sin(t * 0.53f + 1.3f), 0f) * shotSway;
                    Quaternion swayRot = Quaternion.Euler(Mathf.Sin(t * 0.29f) * shotSway * 40f, Mathf.Sin(t * 0.23f + 0.7f) * shotSway * 50f, 0f);
                    target = new Pose(shotPose.position + shotPose.rotation * sway, shotPose.rotation * swayRot);
                    fov = shotFov;
                    break;
                }
                default:
                    target = EvaluateCinematic(dt, out fov);
                    break;
            }

            if (blendT < 1f)
            {
                blendT = Mathf.Min(1f, blendT + dt / blendDuration);
                float k = blendT * blendT * (3f - 2f * blendT); // smoothstep
                Cam.transform.SetPositionAndRotation(
                    Vector3.Lerp(blendFrom.position, target.position, k),
                    Quaternion.Slerp(blendFrom.rotation, target.rotation, k));
                Cam.fieldOfView = Mathf.Lerp(blendFromFov, fov, k);
            }
            else
            {
                Cam.transform.SetPositionAndRotation(target.position, target.rotation);
                Cam.fieldOfView = fov;
            }
        }

        Pose EvaluateCinematic(float dt, out float fov)
        {
            fov = 46f;
            if (cinematicKeys.Length == 0) return new Pose(Cam.transform.position, Cam.transform.rotation);
            if (cinematicKeys.Length == 1) return cinematicKeys[0];

            // Les clés vont par paires (début, fin) : chaque paire est un plan en travelling lent.
            int shots = cinematicKeys.Length / 2;
            cinematicTime += dt;
            float total = shots * CinematicSegment;
            float t = cinematicTime % total;
            int shot = Mathf.Min(shots - 1, (int)(t / CinematicSegment));
            float local = (t - shot * CinematicSegment) / CinematicSegment;
            float k = local * local * (3f - 2f * local);
            Pose a = cinematicKeys[shot * 2];
            Pose b = cinematicKeys[shot * 2 + 1];

            // Changement de plan : courte transition douce plutôt qu'un cut sec.
            if (local < 0.02f && cinematicTime > CinematicSegment * 0.5f && blendT >= 1f)
            {
                blendFrom = new Pose(Cam.transform.position, Cam.transform.rotation);
                blendFromFov = Cam.fieldOfView;
                blendDuration = 2.2f;
                blendT = 0f;
            }
            return new Pose(Vector3.Lerp(a.position, b.position, k), Quaternion.Slerp(a.rotation, b.rotation, k));
        }
    }
}
