using BlouseBlanche.Core;
using BlouseBlanche.UI;
using UnityEngine;

namespace BlouseBlanche.Gameplay
{
    /// <summary>Rayon depuis le centre de l'écran : trouve l'objet interactif visé et déclenche l'action.</summary>
    public sealed class Interactor : MonoBehaviour
    {
        public float Range = 2.6f;
        public bool Active;
        public IInteractable Current { get; private set; }

        readonly RaycastHit[] hits = new RaycastHit[8];

        public void Tick(Camera cam)
        {
            Current = null;
            if (!Active || cam == null) return;
            var ray = new Ray(cam.transform.position, cam.transform.forward);
            int n = Physics.RaycastNonAlloc(ray, hits, Range, ~0, QueryTriggerInteraction.Collide);
            float best = float.MaxValue;
            IInteractable found = null;
            float blocker = float.MaxValue;
            for (int i = 0; i < n; i++)
            {
                var h = hits[i];
                if (h.collider == null) continue;
                var it = h.collider.GetComponentInParent<IInteractable>();
                if (it != null && !string.IsNullOrEmpty(it.InteractionVerb))
                {
                    if (h.distance < best) { best = h.distance; found = it; }
                }
                else if (!h.collider.isTrigger && h.distance < blocker) blocker = h.distance;
            }
            // Un mur ou un meuble devant l'objet bloque l'interaction.
            if (found != null && best <= blocker + 0.05f) Current = found;

            if (Current != null && GameInput.InteractDown())
            {
                var root = GameRoot.Instance;
                if (Current.CanInteract)
                {
                    root?.Audio?.PlayUI(Sfx.UiClick, 0.6f);
                    Current.Interact();
                }
                else
                {
                    root?.Audio?.PlayUI(Sfx.UiBack, 0.6f);
                    string reason = Current.UnavailableReason;
                    if (!string.IsNullOrEmpty(reason)) root?.UI?.Toast("Action impossible", reason, ToastKind.Warning);
                }
            }
        }
    }
}
