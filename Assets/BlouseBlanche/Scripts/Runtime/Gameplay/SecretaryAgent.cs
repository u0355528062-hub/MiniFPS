using BlouseBlanche.Characters;
using BlouseBlanche.Core;
using BlouseBlanche.World;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    /// <summary>Sophie, la secrétaire : tape au clavier, accueille les patients, renseigne le médecin.</summary>
    public sealed class SecretaryAgent : MonoBehaviour, IInteractable
    {
        public HumanAgent Body;
        ClinicWorld world;
        IVisitHost director;
        AudioSource typing;
        PatientAgent attending;
        float glanceTimer;

        public static SecretaryAgent Spawn(IVisitHost director, ClinicWorld world, WorldKit kit, Transform parent)
        {
            var rig = HumanBuilder.Build(kit, parent, HumanAppearance.Secretary(), "Sophie_Secretaire");
            var anim = rig.gameObject.AddComponent<HumanAnimator>();
            anim.Rig = rig;
            var body = rig.gameObject.AddComponent<HumanAgent>();
            body.Rig = rig;
            body.Anim = anim;
            body.Nav = world.Nav;
            body.PlaceSeated(world.SecretaryChair);
            anim.Gesture = Gesture.Typing;

            // Badge
            kit.Part(rig.Chest, "Badge", kit.RoundedBoxMesh(new Vector3(0.05f, 0.07f, 0.006f), 0.004f), kit.Mat.Lit("Badge", Color.white, 0.6f),
                new Vector3(-0.06f, rig.Torso_Length * 0.25f, rig.Torso_Length * 0.27f));

            var s = rig.gameObject.AddComponent<SecretaryAgent>();
            s.Body = body;
            s.world = world;
            s.director = director;
            var audio = GameRoot.Instance != null ? GameRoot.Instance.Audio : null;
            if (audio != null) s.typing = audio.CreateLoop(Sfx.Typing, parent, world.SecretaryTypingPoint, 0.18f, 1f, 9f);
            return s;
        }

        public void Attend(PatientAgent p) { attending = p; }
        public void StopAttending(PatientAgent p) { if (attending == p) attending = null; }

        public void Speak(float seconds) => Body.Anim.Talk(seconds);

        void Update()
        {
            var anim = Body.Anim;
            var root = GameRoot.Instance;
            Vector3? player = root != null && root.CameraDirector != null && root.CameraDirector.Cam != null ? root.CameraDirector.Cam.transform.position : (Vector3?)null;
            bool playerNear = player.HasValue && Vector3.Distance(player.Value, world.SecretaryHead) < 3.2f;

            if (attending != null && attending.Rig != null)
            {
                anim.Gesture = Gesture.None;
                anim.LookTarget = attending.Rig.HeadCenter;
            }
            else if (playerNear)
            {
                anim.Gesture = Gesture.None;
                anim.LookTarget = player;
            }
            else
            {
                anim.Gesture = Gesture.Typing;
                glanceTimer -= Time.deltaTime;
                if (glanceTimer <= 0f)
                {
                    glanceTimer = Random.Range(4f, 9f);
                    anim.LookTarget = Random.value < 0.75f ? world.SecretaryTypingPoint + new Vector3(0.2f, 0.35f, -0.25f) : world.SecretaryHead + new Vector3(-3f, -0.2f, -2f);
                }
            }
            if (typing != null) typing.volume = Mathf.MoveTowards(typing.volume, anim.Gesture == Gesture.Typing ? 0.18f : 0f, Time.deltaTime);
        }

        public bool CanInteract => true;
        public string InteractionVerb => "Parler à Sophie";
        public string InteractionTarget => "Secrétaire";
        public string UnavailableReason => "";

        public void Interact()
        {
            if (director == null) return;
            string line = director.SecretaryLine();
            Speak(Mathf.Clamp(line.Length * 0.045f, 1.5f, 5f));
            GameRoot.Instance?.UI?.Subtitle("Sophie", line);
        }
    }
}
