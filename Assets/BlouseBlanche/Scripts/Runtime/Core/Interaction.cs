using System;
using UnityEngine;

namespace BlouseBlanche.Core
{
    /// <summary>Objet avec lequel le joueur peut interagir (touche E).</summary>
    public interface IInteractable
    {
        /// <summary>Faux = affiché grisé avec la raison.</summary>
        bool CanInteract { get; }
        /// <summary>Verbe affiché (ex. « Appeler en consultation »).</summary>
        string InteractionVerb { get; }
        /// <summary>Cible affichée (ex. « Mme Roux »).</summary>
        string InteractionTarget { get; }
        /// <summary>Raison affichée quand l'action est indisponible.</summary>
        string UnavailableReason { get; }
        void Interact();
    }

    /// <summary>Interactable générique piloté par délégués.</summary>
    public sealed class SimpleInteractable : MonoBehaviour, IInteractable
    {
        public string Verb = "Utiliser";
        public string Target = "";
        public Func<bool> Condition;
        public Func<string> Reason;
        public Action OnInteract;
        public Func<string> DynamicVerb;

        public bool CanInteract => Condition == null || Condition();
        public string InteractionVerb => DynamicVerb != null ? DynamicVerb() : Verb;
        public string InteractionTarget => Target;
        public string UnavailableReason => Reason != null ? Reason() : "";
        public void Interact() => OnInteract?.Invoke();
    }
}
