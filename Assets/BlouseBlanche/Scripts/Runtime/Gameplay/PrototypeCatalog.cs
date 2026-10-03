using System.Collections.Generic;
using BlouseBlanche.Emergency;
using BlouseBlanche.Medical;

namespace BlouseBlanche.Gameplay
{
    /// <summary>Les trois prototypes jouables.</summary>
    public enum PrototypeKind { Consultation, Samu, Urgences }

    /// <summary>Un cas tel que présenté dans le menu (sans dévoiler le diagnostic).</summary>
    public sealed class PrototypeCase
    {
        public string Id, Title, Detail;
        public int Difficulty;      // 1..3
        public bool Urgent;
    }

    /// <summary>Textes et listes de cas des prototypes (menu principal, HUD, fin de cas).</summary>
    public static class PrototypeCatalog
    {
        public static readonly PrototypeKind[] All = { PrototypeKind.Consultation, PrototypeKind.Samu, PrototypeKind.Urgences };

        public static string Name(PrototypeKind k)
        {
            switch (k)
            {
                case PrototypeKind.Consultation: return "Cabinet de médecine générale";
                case PrototypeKind.Samu: return "SAMU · intervention à domicile";
                default: return "Urgences · box de soins";
            }
        }

        public static string Caption(PrototypeKind k)
        {
            switch (k)
            {
                case PrototypeKind.Consultation: return "CONSULTATION";
                case PrototypeKind.Samu: return "SAMU · SMUR";
                default: return "URGENCES · BOX 3";
            }
        }

        public static string Description(PrototypeKind k)
        {
            switch (k)
            {
                case PrototypeKind.Consultation:
                    return "Un patient vous attend dans votre cabinet. Lavez-vous les mains, interrogez, examinez avec la roue des outils, posez un diagnostic, prescrivez et orientez.";
                case PrototypeKind.Samu:
                    return "Vous arrivez au domicile avec l'équipe du SMUR. Le temps s'écoule en continu : bilan, gestes vitaux, traitements, puis orientation vers le bon service.";
                default:
                    return "Un patient vient d'être installé dans le box. Examens biologiques et imagerie arrivent avec un délai : hiérarchisez, traitez, décidez de l'orientation.";
            }
        }

        public static List<PrototypeCase> Cases(PrototypeKind k)
        {
            var list = new List<PrototypeCase>();
            if (k == PrototypeKind.Consultation)
            {
                foreach (var c in CaseLibrary.All)
                {
                    string who = c.IsChildCase ? "Enfant" : c.AgeMin >= 60 ? "Patient âgé" : "Adulte";
                    if (!string.IsNullOrEmpty(c.Companion)) who += ", accompagné(e) de " + c.Companion;
                    list.Add(new PrototypeCase
                    {
                        Id = c.Id,
                        Title = c.Motif,
                        Detail = who + " · « " + Shorten(c.Opening, 90) + " »",
                        Difficulty = c.Urgency == Urgency.Vitale ? 3 : (c.HarmfulTx.Count > 0 || c.KeyExams.Count >= 4 || c.Allergies.Length > 0) ? 2 : 1,
                        Urgent = c.Urgency == Urgency.Vitale
                    });
                }
            }
            else
            {
                var setting = k == PrototypeKind.Samu ? EmergencySetting.Samu : EmergencySetting.Urgences;
                foreach (var c in EmergencyCases.For(setting))
                    list.Add(new PrototypeCase { Id = c.Id, Title = c.Title, Detail = c.Dispatch, Difficulty = c.Difficulty, Urgent = c.Difficulty >= 3 });
            }
            return list;
        }

        /// <summary>Cas tiré au hasard, différent du précédent quand c'est possible.</summary>
        public static string RandomCase(PrototypeKind k, string exclude, System.Random rng)
        {
            var cases = Cases(k);
            if (cases.Count == 0) return null;
            if (cases.Count > 1 && exclude != null) cases.RemoveAll(c => c.Id == exclude);
            return cases[rng.Next(cases.Count)].Id;
        }

        public static string DifficultyLabel(int d) => d >= 3 ? "Difficile" : d == 2 ? "Intermédiaire" : "Accessible";

        static string Shorten(string s, int max)
        {
            if (string.IsNullOrEmpty(s)) return "";
            s = s.Replace("\n", " ");
            return s.Length <= max ? s : s.Substring(0, max - 1).TrimEnd() + "…";
        }
    }
}
