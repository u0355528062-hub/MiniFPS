using System;
using UnityEngine;

namespace BlouseBlanche.Characters
{
    public enum Gesture { None, HoldBelly, HoldChest, HoldBack, HoldHead, Typing, ArmOut, OpenMouth, ArmsCrossed }

    /// <summary>
    /// Animation 100 % procédurale : marche (cycle complet bras/jambes/bassin), assise, gestes liés
    /// aux symptômes, toux périodique, regard, clignement, respiration, parole.
    /// </summary>
    public sealed class HumanAnimator : MonoBehaviour
    {
        public HumanRig Rig;

        /// <summary>Vitesse de déplacement actuelle (m/s), fournie par l'agent.</summary>
        public float Speed;
        /// <summary>0 = debout, 1 = assis. Piloté directement par les étapes d'assise.</summary>
        public float Sit;
        public float SeatHeight = 0.46f;
        public Gesture Gesture;
        public bool Limp;
        public bool CoughPeriodically;
        public Action OnCough;
        public Vector3? LookTarget;
        public float PainSway;

        // Patient allongé (SAMU, urgences)
        public float Lie;               // 0 debout/assis .. 1 allongé sur le dos
        public float LieHeight;         // hauteur du support (sol, matelas)
        public float LieIncline;        // relève-buste (degrés)
        public bool EyesClosed;
        public float BreathRate = 15f;  // respirations / minute
        public float BreathAmplitude = 1f;
        public float Compression;       // massage cardiaque (0..1)
        public float Jolt;              // secousse du choc électrique

        float phase;
        float gestureW;
        Gesture shownGesture;
        float coughTimer = 4f, coughT = -1f;
        float blinkTimer = 2f, blinkT = -1f;
        float talkT;
        float headYaw, headPitch;
        float breathPhase;
        Vector3 torsoBaseScale = Vector3.one;
        float seed;

        public bool IsSeated => Sit > 0.98f;

        void Start()
        {
            if (Rig != null && Rig.Torso != null) torsoBaseScale = Rig.Torso.localScale;
            seed = UnityEngine.Random.value * 100f;
            blinkTimer = UnityEngine.Random.Range(1f, 4f);
        }

        public void Talk(float seconds) => talkT = Mathf.Max(talkT, seconds);

        public void TriggerCough()
        {
            if (coughT < 0f) { coughT = 0f; OnCough?.Invoke(); }
        }

        static Quaternion E(float x, float y, float z) => Quaternion.Euler(x, y, z);
        static float Smooth(float t) => t * t * (3f - 2f * t);

        void LateUpdate()
        {
            if (Rig == null) return;
            float dt = Time.deltaTime;
            float t = Time.time + seed;
            var look = Rig.Look;
            bool elderly = look != null && look.IsElderly;
            bool child = look != null && look.IsChild;

            // ---------------------------------------------------------------- marche
            float w = Mathf.Clamp01(Speed / 0.9f) * (1f - Sit);
            float stride = Rig.LegLength * 1.45f;
            if (Speed > 0.01f) phase += dt * Speed / Mathf.Max(0.3f, stride) * Mathf.PI * 2f;
            else phase = Mathf.MoveTowards(phase, Mathf.Round(phase / Mathf.PI) * Mathf.PI, dt * 4f);
            float sp = Mathf.Sin(phase), cp = Mathf.Cos(phase);
            float ampL = 28f, ampR = Limp ? 14f : 28f;
            if (elderly) { ampL *= 0.75f; ampR *= 0.75f; }

            float hipLx = -ampL * sp * w, hipRx = ampR * sp * w;
            float kneeL = w * (6f + 48f * Mathf.Max(0f, cp));
            float kneeR = w * (6f + (Limp ? 20f : 48f) * Mathf.Max(0f, -cp));
            float shLx = 20f * sp * w, shRx = -20f * sp * w;
            float elbowX = -(10f + 10f * w);
            float bob = -0.022f * w * Mathf.Abs(sp) * (Rig.Height / 1.75f);
            float pelvisYaw = 6f * sp * w;
            float lean = 3f * w + (elderly ? 8f : 0f) + (child ? -2f : 0f);
            float limpTilt = Limp ? Mathf.Max(0f, -sp) * 5f * w : 0f;

            // ---------------------------------------------------------------- assise
            float s = Smooth(Mathf.Clamp01(Sit));
            float sitHip = SeatHeight + Rig.ThighRadius * 0.9f;
            float hipsY = Mathf.Lerp(Rig.StandHipHeight + bob, sitHip, s);
            float kneeSit = SeatHeight > 0.6f ? 80f : 90f;
            hipLx = Mathf.Lerp(hipLx, -90f, s);
            hipRx = Mathf.Lerp(hipRx, -90f, s);
            kneeL = Mathf.Lerp(kneeL, kneeSit, s);
            kneeR = Mathf.Lerp(kneeR, kneeSit - (SeatHeight > 0.6f ? 12f : 0f), s);
            float spineX = Mathf.Lerp(lean, elderly ? 2f : -5f, s);
            shLx = Mathf.Lerp(shLx, -18f, s);
            shRx = Mathf.Lerp(shRx, -18f, s);
            float elbowL = Mathf.Lerp(elbowX, -55f, s), elbowR = elbowL;
            float shLz = -6f, shRz = 6f;
            float shLy = 0f, shRy = 0f;

            // ---------------------------------------------------------------- gestes
            if (Gesture != shownGesture)
            {
                gestureW = Mathf.MoveTowards(gestureW, 0f, dt * 3f);
                if (gestureW <= 0f) shownGesture = Gesture;
            }
            else gestureW = Mathf.MoveTowards(gestureW, Gesture == Gesture.None ? 0f : 1f, dt * 2.5f);
            float g = Smooth(gestureW);
            float headExtraPitch = 0f;
            float mouthOpen = 0f;
            switch (shownGesture)
            {
                case Gesture.HoldBelly:
                    shLx = Mathf.Lerp(shLx, -30f, g); shRx = Mathf.Lerp(shRx, -30f, g);
                    shLz = Mathf.Lerp(shLz, 14f, g); shRz = Mathf.Lerp(shRz, -14f, g);
                    elbowL = Mathf.Lerp(elbowL, -100f, g); elbowR = Mathf.Lerp(elbowR, -100f, g);
                    spineX += 6f * g; headExtraPitch += 8f * g;
                    break;
                case Gesture.HoldChest:
                    shRx = Mathf.Lerp(shRx, -48f, g); shRz = Mathf.Lerp(shRz, -24f, g);
                    elbowR = Mathf.Lerp(elbowR, -122f, g);
                    spineX += 5f * g; headExtraPitch += 6f * g;
                    break;
                case Gesture.HoldBack:
                    shRx = Mathf.Lerp(shRx, 38f, g); shRz = Mathf.Lerp(shRz, 10f, g);
                    elbowR = Mathf.Lerp(elbowR, -75f, g);
                    spineX += 8f * g;
                    break;
                case Gesture.HoldHead:
                    shRx = Mathf.Lerp(shRx, -138f, g); shRz = Mathf.Lerp(shRz, -16f, g);
                    elbowR = Mathf.Lerp(elbowR, -104f, g);
                    headExtraPitch += 7f * g;
                    break;
                case Gesture.Typing:
                    shLx = Mathf.Lerp(shLx, -36f, g); shRx = Mathf.Lerp(shRx, -36f, g);
                    shLz = Mathf.Lerp(shLz, 8f, g); shRz = Mathf.Lerp(shRz, -8f, g);
                    elbowL = Mathf.Lerp(elbowL, -62f + Mathf.Sin(t * 13f) * 3f, g);
                    elbowR = Mathf.Lerp(elbowR, -62f + Mathf.Sin(t * 15f + 1.3f) * 3f, g);
                    headExtraPitch += 10f * g;
                    break;
                case Gesture.ArmOut:
                    shLx = Mathf.Lerp(shLx, -58f, g); shLz = Mathf.Lerp(shLz, -14f, g);
                    elbowL = Mathf.Lerp(elbowL, -14f, g);
                    break;
                case Gesture.OpenMouth:
                    headExtraPitch -= 16f * g; mouthOpen = g;
                    break;
                case Gesture.ArmsCrossed:
                    shLx = Mathf.Lerp(shLx, -42f, g); shRx = Mathf.Lerp(shRx, -42f, g);
                    shLz = Mathf.Lerp(shLz, 30f, g); shRz = Mathf.Lerp(shRz, -30f, g);
                    shLy = Mathf.Lerp(0f, -20f, g); shRy = Mathf.Lerp(0f, 20f, g);
                    elbowL = Mathf.Lerp(elbowL, -110f, g); elbowR = Mathf.Lerp(elbowR, -110f, g);
                    break;
            }

            // Toux périodique (main devant la bouche)
            if (CoughPeriodically && coughT < 0f)
            {
                coughTimer -= dt;
                if (coughTimer <= 0f) { coughTimer = UnityEngine.Random.Range(6f, 12f); TriggerCough(); }
            }
            if (coughT >= 0f)
            {
                coughT += dt;
                float c = coughT < 0.18f ? coughT / 0.18f : (coughT > 0.85f ? Mathf.Max(0f, 1f - (coughT - 0.85f) / 0.3f) : 1f);
                c = Smooth(c);
                shRx = Mathf.Lerp(shRx, -78f, c); shRz = Mathf.Lerp(shRz, -26f, c);
                elbowR = Mathf.Lerp(elbowR, -138f, c);
                float jolt = (coughT > 0.2f && coughT < 0.75f) ? Mathf.Abs(Mathf.Sin((coughT - 0.2f) * Mathf.PI * 3.6f)) : 0f;
                headExtraPitch += 12f * jolt;
                spineX += 7f * jolt;
                if (coughT > 1.15f) coughT = -1f;
            }

            // ---------------------------------------------------------------- allongé
            float lie = Smooth(Mathf.Clamp01(Lie));
            float hipsRotX = 0f, headRoll = 0f;
            if (lie > 0f)
            {
                hipsY = Mathf.Lerp(hipsY, LieHeight + Rig.ThighRadius * 0.95f + Jolt * 0.07f, lie);
                hipsRotX = -90f * lie;
                spineX = Mathf.Lerp(spineX, LieIncline, lie);
                hipLx = Mathf.Lerp(hipLx, 0f, lie); hipRx = Mathf.Lerp(hipRx, 0f, lie);
                kneeL = Mathf.Lerp(kneeL, 4f, lie); kneeR = Mathf.Lerp(kneeR, 4f, lie);
                shLx = Mathf.Lerp(shLx, 2f, lie); shRx = Mathf.Lerp(shRx, 2f, lie);
                shLz = Mathf.Lerp(shLz, -12f, lie); shRz = Mathf.Lerp(shRz, 12f, lie);
                elbowL = Mathf.Lerp(elbowL, -12f, lie); elbowR = Mathf.Lerp(elbowR, -12f, lie);
                if (EyesClosed) headRoll = 16f * lie;
                headExtraPitch -= 6f * lie;
            }
            Jolt = Mathf.MoveTowards(Jolt, 0f, dt * 4f);

            // ---------------------------------------------------------------- application
            Rig.Hips.localPosition = new Vector3(0f, hipsY, 0f);
            Rig.Hips.localRotation = E(hipsRotX, pelvisYaw * (1f - s) * (1f - lie), limpTilt);
            Rig.Spine.localRotation = E(spineX + Mathf.Sin(t * 0.7f) * PainSway, 0f, Mathf.Sin(t * 0.5f) * PainSway * 0.6f);
            Rig.Chest.localRotation = E(0f, -pelvisYaw * 1.6f * (1f - s), 0f);
            Rig.HipL.localRotation = E(hipLx, 0f, -2f * (1f - s));
            Rig.HipR.localRotation = E(hipRx, 0f, 2f * (1f - s));
            Rig.KneeL.localRotation = E(kneeL, 0f, 0f);
            Rig.KneeR.localRotation = E(kneeR, 0f, 0f);
            Rig.AnkleL.localRotation = E(-kneeL * 0.25f * (1f - s), 0f, 0f);
            Rig.AnkleR.localRotation = E(-kneeR * 0.25f * (1f - s), 0f, 0f);
            Rig.ShoulderL.localRotation = E(shLx, shLy, shLz);
            Rig.ShoulderR.localRotation = E(shRx, shRy, shRz);
            Rig.ElbowL.localRotation = E(elbowL, 0f, 0f);
            Rig.ElbowR.localRotation = E(elbowR, 0f, 0f);
            Rig.WristL.localRotation = E(0f, 0f, 4f);
            Rig.WristR.localRotation = E(0f, 0f, -4f);

            // Respiration
            breathPhase += dt * Mathf.PI * 2f * Mathf.Max(0f, BreathRate) / 60f;
            float breath = Mathf.Sin(breathPhase) * Mathf.Clamp01(BreathAmplitude);
            float squash = 1f - Compression * 0.07f;
            if (Rig.Torso != null)
                Rig.Torso.localScale = new Vector3(torsoBaseScale.x * (1f + 0.012f * breath), torsoBaseScale.y * (1f + 0.005f * breath), torsoBaseScale.z * (1f + 0.02f * breath) * squash);

            // Regard
            float targetYaw = 0f, targetPitch = 0f;
            if (LookTarget.HasValue && Rig.Neck != null)
            {
                Vector3 local = Rig.Chest.InverseTransformPoint(LookTarget.Value) - Rig.Neck.localPosition;
                targetYaw = Mathf.Clamp(Mathf.Atan2(local.x, local.z) * Mathf.Rad2Deg, -65f, 65f);
                float horiz = new Vector2(local.x, local.z).magnitude;
                targetPitch = Mathf.Clamp(-Mathf.Atan2(local.y - Rig.HeadHeight * 0.5f, horiz) * Mathf.Rad2Deg, -30f, 35f);
                if (Mathf.Abs(Mathf.Atan2(local.x, local.z) * Mathf.Rad2Deg) > 120f) { targetYaw = 0f; targetPitch = 0f; }
            }
            float k = 1f - Mathf.Exp(-dt * 5f);
            headYaw = Mathf.Lerp(headYaw, targetYaw, k);
            headPitch = Mathf.Lerp(headPitch, targetPitch, k);
            float talk = talkT > 0f ? 1f : 0f;
            talkT -= dt;
            float nod = talk * Mathf.Sin(t * 9f) * 2.5f;
            float neckLean = elderly ? 8f : 0f;
            Rig.Neck.localRotation = E(neckLean + headPitch * 0.3f, headYaw * 0.35f, 0f);
            if (lie > 0.5f && EyesClosed) { headYaw = Mathf.Lerp(headYaw, 0f, k); headPitch = Mathf.Lerp(headPitch, 0f, k); }
            Rig.Head.localRotation = E(headPitch * 0.7f + headExtraPitch + nod - neckLean * 0.5f, headYaw * 0.65f, Mathf.Sin(t * 0.4f) * 1.5f + headRoll);

            // Bouche et clignements
            if (Rig.Mouth != null)
            {
                float m = 1f + talk * Mathf.Abs(Mathf.Sin(t * 14f)) * 1.8f + mouthOpen * 4f;
                Rig.Mouth.localScale = new Vector3(1f - mouthOpen * 0.2f, m, 1f);
            }
            blinkTimer -= dt;
            if (blinkTimer <= 0f) { blinkT = 0f; blinkTimer = UnityEngine.Random.Range(2.2f, 5.5f); }
            float eyeY = 1f;
            if (blinkT >= 0f)
            {
                blinkT += dt;
                eyeY = blinkT < 0.07f ? 1f - blinkT / 0.07f * 0.9f : 0.1f + Mathf.Min(1f, (blinkT - 0.07f) / 0.08f) * 0.9f;
                if (blinkT > 0.15f) blinkT = -1f;
            }
            if (EyesClosed) eyeY = 0.1f;
            if (Rig.EyeL != null) Rig.EyeL.localScale = new Vector3(1f, eyeY, 1f);
            if (Rig.EyeR != null) Rig.EyeR.localScale = new Vector3(1f, eyeY, 1f);
        }
    }
}
