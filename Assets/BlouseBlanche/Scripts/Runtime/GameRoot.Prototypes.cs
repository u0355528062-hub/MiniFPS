using System;
using System.Collections.Generic;
using BlouseBlanche.Core;
using BlouseBlanche.Emergency;
using BlouseBlanche.Gameplay;
using BlouseBlanche.Medical;
using BlouseBlanche.UI;
using UnityEngine;

namespace BlouseBlanche
{
    /// <summary>Prototypes jouables : lancement d'un cas, HUD d'approche, boutons de fin de cas.</summary>
    public sealed partial class GameRoot
    {
        PrototypeKind? prototype;
        string caseId;
        int caseSeed;
        readonly System.Random rng = new System.Random();

        public PrototypeKind? CurrentPrototype => prototype;
        public string CurrentCaseId => caseId;

        /// <summary>Lance un cas (au hasard si <paramref name="id"/> est vide), avec un fondu.</summary>
        public void StartPrototype(PrototypeKind kind, string id)
        {
            if (transitioning || Mode == GameMode.Loading) return;
            if (string.IsNullOrEmpty(id)) id = PrototypeCatalog.RandomCase(kind, prototype == kind ? caseId : null, rng);
            if (string.IsNullOrEmpty(id)) return;
            int seed = rng.Next(1, 100000);
            StartCoroutine(Transition(() => LaunchCase(kind, id, seed)));
        }

        /// <summary>Reprend le cas en cours depuis le début (même patient).</summary>
        public void RestartCase()
        {
            if (!prototype.HasValue || string.IsNullOrEmpty(caseId) || transitioning) return;
            var kind = prototype.Value;
            string id = caseId;
            int seed = caseSeed;
            StartCoroutine(Transition(() => LaunchCase(kind, id, seed)));
        }

        void LaunchCase(PrototypeKind kind, string id, int seed)
        {
            CleanupRun();
            UI.Menu.Hide();
            UI.Result.Hide();
            UI.Consult.Hide();
            UI.Emergency.Hide();

            if (kind == PrototypeKind.Consultation)
            {
                var c = CaseLibrary.Get(id);
                if (c == null) { Debug.LogError("[BlouseBlanche] Cas inconnu : " + id); EnterMenu(kind); return; }
                Clock.Set(GameClock.At(8, 45) + new System.Random(seed).Next(0, 180));
                ConsultProto.Begin(c, seed);
                Player.Teleport(ConsultProto.PlayerStart, ConsultProto.PlayerStartYaw, 6f);
            }
            else
            {
                var c = EmergencyCases.Get(id);
                if (c == null) { Debug.LogError("[BlouseBlanche] Cas inconnu : " + id); EnterMenu(kind); return; }
                Clock.Set(kind == PrototypeKind.Samu ? GameClock.At(14, 20) : GameClock.At(16, 5));
                Emergency.Begin(c, seed);
                Player.Teleport(Emergency.Location.PlayerSpawn, Emergency.Location.PlayerYaw, 4f);
            }
            prototype = kind;
            caseId = id;
            caseSeed = seed;
            EnterExplore(0f);
            if (Settings.showTutorialHints)
            {
                if (kind == PrototypeKind.Consultation)
                    UI.Toast("Consultation", "Lavez-vous les mains au lavabo du cabinet, puis allez parler au patient (E).", ToastKind.Info, 7f);
                else
                    UI.Toast("Conseil", "Approchez-vous du patient et appuyez sur E pour le prendre en charge : le chronomètre démarre.", ToastKind.Info, 7f);
            }
        }

        /// <summary>HUD de l'exploration dans un prototype : patient ou intervention, objectifs.</summary>
        void UpdatePrototypeHud()
        {
            var hud = UI.Hud;
            hud.SetHints("E", "Interagir", "Maj", "Courir", "Échap", "Pause");
            hud.SetObjectivesVisible(Settings.showTutorialHints);
            if (prototype == PrototypeKind.Consultation && ConsultProto.Active)
            {
                var v = ConsultProto.Visit;
                var p = v.Patient;
                hud.SetClock("CABINET DES TILLEULS", GameClock.Format(Clock.Minutes), "Consultation de médecine générale");
                if (ConsultProto.Done)
                    hud.SetCard("CONSULTATION TERMINÉE", p.DisplayName, "Échap : recommencer, changer de cas ou revenir au menu.");
                else
                    hud.SetCard("VOTRE PATIENT", p.DisplayName + " · " + p.AgeLabel, "Motif : " + p.Case.Motif.ToLowerInvariant(),
                        handsWashed ? "Mains lavées" : "Mains non lavées", v.IsUrgent);
                hud.SetObjectives(
                    new[] { "Se laver les mains (lavabo du cabinet)", "Parler au patient (E) pour commencer", "Conclure : diagnostic, traitement, orientation" },
                    new[] { handsWashed, v.Status == VisitStatus.Consulting || ConsultProto.Done, ConsultProto.Done });
            }
            else if (Emergency.Active)
            {
                var c = Emergency.Case;
                bool samu = c.Setting == EmergencySetting.Samu;
                hud.SetClock(samu ? "SAMU · SMUR" : "URGENCES · BOX 3", GameClock.Format(Clock.Minutes), Emergency.Location.Name);
                hud.SetCard(samu ? "INTERVENTION À DOMICILE" : "PATIENT INSTALLÉ", c.Title, c.Dispatch, null, true);
                bool near = Emergency.Patient != null && Vector3.Distance(Player.Feet, Emergency.Location.PatientPelvis) < 2.4f;
                hud.SetObjectives(
                    new[] { samu ? "Rejoindre le patient" : "S'approcher du lit", "Le prendre en charge (E)" },
                    new[] { near, Emergency.InCare });
            }
        }

        /// <summary>Boutons du bilan d'un prototype.</summary>
        /// <param name="close">Clôture de la séance avant de quitter le bilan (peut être nulle).</param>
        /// <param name="stay">Si non nul : bouton « rester sur place » (consultation : le patient s'en va).</param>
        ResultAction[] PrototypeResultActions(Action close, Action stay)
        {
            var kind = prototype ?? PrototypeKind.Consultation;
            var list = new List<ResultAction>
            {
                new ResultAction("Cas suivant", () => { close?.Invoke(); StartPrototype(kind, null); }, true),
                new ResultAction("Rejouer ce cas", () => { close?.Invoke(); RestartCase(); }),
                new ResultAction("Choisir un autre cas", () => { close?.Invoke(); BackToMenu(); })
            };
            if (stay != null) list.Add(new ResultAction("Rester au cabinet", stay));
            return list.ToArray();
        }
    }
}
