using BlouseBlanche.Characters;
using BlouseBlanche.Core;
using BlouseBlanche.Emergency;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    /// <summary>
    /// Patient d'un prototype SAMU / urgences : allongé, son aspect suit son état (yeux fermés,
    /// cyanose, rythme respiratoire, compressions, secousse du choc). Accompagné d'un témoin éventuel.
    /// </summary>
    public sealed class EmergencyPatient : MonoBehaviour, IInteractable
    {
        public HumanRig Rig;
        public HumanAnimator Anim;
        public HumanRig WitnessRig;
        public HumanAnimator WitnessAnim;
        public EmergencyCase Case;
        public EmergencyLocation Location;
        public Sex Sex;
        public int Age;
        public EmergencySession Session;
        public bool InCare;
        public float CompressionVisual;
        System.Action onInteract;

        Material skinMat;
        Color skinBase;

        public static EmergencyPatient Spawn(WorldKit kit, EmergencyLocation loc, EmergencyCase c, int seed, Transform parent, System.Action onInteract)
        {
            var r = new System.Random(seed);
            Sex sex = c.Sex ?? (r.NextDouble() < 0.5 ? Sex.Homme : Sex.Femme);
            int age = c.AgeMin + r.Next(Mathf.Max(1, c.AgeMax - c.AgeMin + 1));
            var look = HumanAppearance.Generate(seed, sex, age);
            var rig = HumanBuilder.Build(kit, parent, look, "Patient_" + c.Id);
            rig.transform.SetPositionAndRotation(loc.PatientPelvis, Quaternion.Euler(0f, loc.PatientYaw, 0f));
            var anim = rig.gameObject.AddComponent<HumanAnimator>();
            anim.Rig = rig;
            anim.Lie = 1f;
            anim.LieHeight = loc.LieHeight;
            anim.LieIncline = loc.Incline;

            // Collider d'interaction couché
            var col = rig.GetComponent<CapsuleCollider>();
            if (col != null)
            {
                col.direction = 2;
                col.height = look.Height;
                col.radius = 0.35f;
                col.center = new Vector3(0f, loc.LieHeight + 0.15f, -look.Height * 0.25f);
            }

            var p = rig.gameObject.AddComponent<EmergencyPatient>();
            p.Rig = rig;
            p.Anim = anim;
            p.Case = c;
            p.Location = loc;
            p.Sex = sex;
            p.Age = age;
            p.onInteract = onInteract;
            p.InstanceSkin(look);

            if (!string.IsNullOrEmpty(c.Witness))
            {
                bool female = c.Witness.Contains("épouse") || c.Witness.Contains("fille") || c.Witness.Contains("mère");
                int wAge = c.Witness.Contains("fille") ? Mathf.Max(20, age - 28) : Mathf.Max(18, age + r.Next(7) - 3);
                var wl = HumanAppearance.Generate(seed + 99, female ? Sex.Femme : Sex.Homme, wAge);
                var wr = HumanBuilder.Build(kit, parent, wl, "Temoin");
                wr.transform.SetPositionAndRotation(loc.WitnessPos, Quaternion.Euler(0f, loc.WitnessYaw, 0f));
                var wa = wr.gameObject.AddComponent<HumanAnimator>();
                wa.Rig = wr;
                wa.Gesture = Gesture.ArmsCrossed;
                wa.PainSway = 1.2f;
                p.WitnessRig = wr;
                p.WitnessAnim = wa;
            }
            return p;
        }

        void InstanceSkin(HumanAppearance look)
        {
            string key = "Skin_" + ColorUtility.ToHtmlStringRGB(look.Skin);
            foreach (var mr in Rig.GetComponentsInChildren<MeshRenderer>())
            {
                var m = mr.sharedMaterial;
                if (m == null || !m.name.Contains(key)) continue;
                if (skinMat == null) { skinMat = new Material(m); skinBase = look.Skin; }
                mr.sharedMaterial = skinMat;
            }
        }

        public void Speak(float seconds, bool witness)
        {
            if (witness && WitnessAnim != null) WitnessAnim.Talk(seconds);
            else if (Anim != null) Anim.Talk(seconds);
        }

        public void ShockJolt() { if (Anim != null) Anim.Jolt = 1f; }

        /// <summary>Retire le patient, son témoin et le matériau de peau instancié.</summary>
        public void Despawn()
        {
            if (WitnessRig != null) Destroy(WitnessRig.gameObject);
            if (skinMat != null) Destroy(skinMat);
            Destroy(gameObject);
        }

        void Update()
        {
            var cam = GameRoot.Instance != null && GameRoot.Instance.CameraDirector != null ? GameRoot.Instance.CameraDirector.Cam : null;
            PatientState st = Session != null ? Session.S : null;

            if (st != null)
            {
                bool unconscious = st.Gcs < 9 || !st.Alive;
                Anim.EyesClosed = unconscious;
                Anim.LookTarget = !unconscious && cam != null ? cam.transform.position : (Vector3?)null;
                Anim.BreathRate = st.Rr;
                switch (st.Breathing)
                {
                    case Breathing.Absente: Anim.BreathAmplitude = 0f; break;
                    case Breathing.Agonique: Anim.BreathAmplitude = 0.5f; Anim.BreathRate = 5f; break;
                    case Breathing.Lente: Anim.BreathAmplitude = 0.5f; break;
                    case Breathing.Sifflante: case Breathing.Rapide: Anim.BreathAmplitude = 1.3f; break;
                    default: Anim.BreathAmplitude = 1f; break;
                }
                if (!st.Pulse) Anim.BreathAmplitude = Session.Bavu ? 0.6f : (st.Breathing == Breathing.Agonique ? 0.4f : 0f);
                Anim.PainSway = st.Gcs >= 13 && st.Pain > 5f ? 1.2f : 0f;

                if (skinMat != null)
                {
                    float cyan = !st.Pulse ? 0.55f : Mathf.Clamp01((90f - st.Spo2) / 25f) * 0.5f;
                    float pale = st.Sys > 0f && st.Sys < 90f ? Mathf.Clamp01((90f - st.Sys) / 40f) * 0.35f : 0f;
                    Color c = Color.Lerp(skinBase, new Color(0.55f, 0.6f, 0.72f), cyan);
                    c = Color.Lerp(c, new Color(0.85f, 0.84f, 0.8f), pale);
                    skinMat.SetColor("_BaseColor", c);
                    skinMat.SetColor("_Color", c);
                }
            }
            else
            {
                // Avant la prise en charge : aspect initial du cas
                var init = Case.Initial != null ? cachedInitial ??= Case.Initial() : null;
                if (init != null)
                {
                    Anim.EyesClosed = init.Gcs < 9;
                    Anim.BreathRate = init.Rr;
                    Anim.BreathAmplitude = init.Breathing == Breathing.Absente ? 0f : init.Breathing == Breathing.Agonique ? 0.4f : 1f;
                    if (!init.Pulse && skinMat != null) skinMat.SetColor("_BaseColor", Color.Lerp(skinBase, new Color(0.55f, 0.6f, 0.72f), 0.55f));
                    if (init.Gcs >= 13 && cam != null) Anim.LookTarget = cam.transform.position;
                }
            }

            CompressionVisual = Mathf.MoveTowards(CompressionVisual, 0f, Time.deltaTime * 6f);
            Anim.Compression = CompressionVisual;

            if (WitnessAnim != null)
            {
                WitnessAnim.LookTarget = Rig.HeadCenter;
                WitnessAnim.Gesture = Mathf.Repeat(Time.time, 14f) < 7f ? Gesture.ArmsCrossed : Gesture.HoldHead;
            }
        }

        PatientState cachedInitial;

        public bool CanInteract => !InCare;
        public string InteractionVerb => InCare ? "" : "Prendre en charge le patient";
        public string InteractionTarget => Case.Title;
        public string UnavailableReason => "";
        public void Interact() => onInteract?.Invoke();
    }
}
