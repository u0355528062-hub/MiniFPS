using System.Collections.Generic;
using BlouseBlanche.Characters;
using UnityEngine;

namespace BlouseBlanche.Medical
{
    public sealed class ScheduledVisit
    {
        public float Time;          // minutes depuis minuit (heure du RDV, ou d'arrivée pour un imprévu)
        public string CaseId;
        public bool WalkIn;
        public string FirstName, LastName;
        public Sex? Sex;
        public int Age = -1;
        public float ArrivalOffset; // minutes (négatif = en avance)
    }

    public sealed class DayPlan
    {
        public int Index;
        public string DateLabel, Title, Intro, SecretaryGreeting;
        public string[] Objectives;
        public float Start = 8 * 60 + 20, Open = 8 * 60 + 30, End = 12 * 60 + 30;
        public readonly List<ScheduledVisit> Visits = new List<ScheduledVisit>();
    }

    public static class NameGenerator
    {
        static readonly string[] Men = { "Thomas", "Nicolas", "Julien", "Antoine", "Mathieu", "Pierre", "Alexandre", "Hugo", "Louis", "Léo", "Gabriel", "Arthur", "Yanis", "Mehdi", "Karim", "Olivier", "Philippe", "Michel", "Alain", "Jacques", "Bernard", "Christophe", "Sébastien", "Rémi", "Bastien", "Noah", "Adam", "Jules", "Malik", "Baptiste" };
        static readonly string[] Women = { "Camille", "Léa", "Manon", "Chloé", "Sarah", "Inès", "Emma", "Jade", "Louise", "Alice", "Julie", "Claire", "Sophie", "Nathalie", "Isabelle", "Sandrine", "Catherine", "Monique", "Françoise", "Yasmine", "Fatima", "Amina", "Lucie", "Pauline", "Marion", "Élodie", "Margaux", "Lina", "Rose", "Anaïs" };
        static readonly string[] Last = { "Martin", "Bernard", "Dubois", "Durand", "Leroy", "Moreau", "Simon", "Laurent", "Lefebvre", "Michel", "Garcia", "David", "Bertrand", "Roux", "Vincent", "Fournier", "Morel", "Girard", "André", "Mercier", "Dupont", "Lambert", "Bonnet", "François", "Martinez", "Legrand", "Garnier", "Faure", "Rousseau", "Blanc", "Guérin", "Muller", "Henry", "Roussel", "Nicolas", "Perrin", "Morin", "Mathieu", "Clément", "Gauthier", "Dumont", "Lopez", "Fontaine", "Chevalier", "Robin", "Masson", "Sanchez", "Benali", "Haddad", "Nguyen" };

        public static string First(System.Random r, Sex s) => s == Sex.Homme ? Men[r.Next(Men.Length)] : Women[r.Next(Women.Length)];
        public static string LastName(System.Random r) => Last[r.Next(Last.Length)];
    }

    /// <summary>Mode histoire : journées scénarisées puis journées générées.</summary>
    public static class StoryCampaign
    {
        static readonly string[] Weekdays = { "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi" };

        public static string DateLabel(int dayIndex)
        {
            // Le jour 1 est le lundi 5 octobre 2026 ; on saute les week-ends.
            int week = dayIndex / 5, wd = dayIndex % 5;
            int dayOfMonth = 5 + week * 7 + wd;
            string[] months = { "octobre", "novembre", "décembre", "janvier" };
            int[] lengths = { 31, 30, 31, 31 };
            int m = 0;
            while (m < lengths.Length - 1 && dayOfMonth > lengths[m]) { dayOfMonth -= lengths[m]; m++; }
            return Weekdays[wd] + " " + dayOfMonth + " " + months[m];
        }

        static ScheduledVisit V(int h, int min, string caseId, string first, string last, Sex sex, int age, bool walkIn = false, float offset = -6f)
            => new ScheduledVisit { Time = h * 60 + min, CaseId = caseId, FirstName = first, LastName = last, Sex = sex, Age = age, WalkIn = walkIn, ArrivalOffset = walkIn ? 0f : offset };

        public static DayPlan Build(int dayIndex)
        {
            var plan = new DayPlan { Index = dayIndex, DateLabel = DateLabel(dayIndex) };
            switch (dayIndex)
            {
                case 0:
                    plan.Title = "Premier jour au cabinet des Tilleuls";
                    plan.Intro = "Le Dr Lemoine a pris sa retraite après 35 ans d'exercice et vous confie sa patientèle. Sophie, la secrétaire, vous attend à l'accueil. Sept patients sont prévus ce matin… et il y aura sûrement des imprévus.";
                    plan.Objectives = new[] { "Rejoindre votre cabinet de consultation", "Consulter l'agenda sur l'ordinateur (ou touche Tab)", "Soigner chaque patient au mieux" };
                    plan.SecretaryGreeting = "Bonjour Docteur, et bienvenue ! Votre premier patient, M. Lefèvre, arrive à 8h30. Votre cabinet est la porte au fond à gauche.";
                    plan.Visits.Add(V(8, 30, "hta_suivi", "Bernard", "Lefèvre", Sex.Homme, 64, false, -8f));
                    plan.Visits.Add(V(9, 0, "angine_strepto", "Camille", "Roux", Sex.Femme, 24));
                    plan.Visits.Add(V(9, 20, "gastro_enfant", "Lucas", "Fabre", Sex.Homme, 7, true));
                    plan.Visits.Add(V(9, 45, "lombalgie", "Karim", "Benali", Sex.Homme, 41, false, 4f));
                    plan.Visits.Add(V(10, 5, "sca", "Gérard", "Petit", Sex.Homme, 58, true));
                    plan.Visits.Add(V(10, 30, "cystite", "Hélène", "Garnier", Sex.Femme, 34));
                    plan.Visits.Add(V(11, 0, "grippe", "Paul", "Durand", Sex.Homme, 29));
                    break;
                case 1:
                    plan.Title = "Le bouche-à-oreille";
                    plan.Intro = "Votre première journée a fait parler d'elle : l'agenda est complet. Pensez à ouvrir le dossier de chaque patient : antécédents, traitements et allergies peuvent tout changer.";
                    plan.Objectives = new[] { "Vérifier les allergies avant de prescrire", "Ne pas laisser les patients attendre trop longtemps", "Repérer les urgences vitales" };
                    plan.SecretaryGreeting = "Bonjour Docteur ! Grosse matinée : huit rendez-vous. Mme Girard est déjà là pour 8h30.";
                    plan.Visits.Add(V(8, 30, "migraine", "Nathalie", "Girard", Sex.Femme, 45, false, -12f));
                    plan.Visits.Add(V(9, 0, "angine_allergie", "Inès", "Bouchard", Sex.Femme, 19));
                    plan.Visits.Add(V(9, 15, "otite_enfant", "Emma", "Petit", Sex.Femme, 4, true));
                    plan.Visits.Add(V(9, 45, "diabete_deseq", "Jean-Marc", "Robert", Sex.Homme, 67));
                    plan.Visits.Add(V(10, 15, "entorse", "Sofiane", "Haddad", Sex.Homme, 23, true));
                    plan.Visits.Add(V(10, 45, "asthme", "Marie", "Dubois", Sex.Femme, 31));
                    plan.Visits.Add(V(11, 10, "avc", "Raymond", "Faure", Sex.Homme, 74, true));
                    plan.Visits.Add(V(11, 45, "pneumopathie", "Claire", "Fontaine", Sex.Femme, 52));
                    break;
                default:
                    BuildGenerated(plan, dayIndex);
                    break;
            }
            return plan;
        }

        static void BuildGenerated(DayPlan plan, int dayIndex)
        {
            var r = new System.Random(9000 + dayIndex * 7919);
            plan.Title = dayIndex % 5 == 4 ? "Vendredi : l'agenda déborde" : "Une matinée au cabinet";
            plan.Intro = "Votre patientèle s'installe. Rendez-vous programmés, imprévus, urgences possibles : à vous de gérer le temps et les priorités.";
            plan.Objectives = new[] { "Prendre en charge tous les patients", "Garder une note moyenne au-dessus de 70", "Identifier les urgences vitales sans délai" };
            plan.SecretaryGreeting = "Bonjour Docteur ! L'agenda de la matinée est sur votre ordinateur.";

            var pool = new List<string>(CaseLibrary.RoutinePool);
            int scheduled = 6 + r.Next(2);
            float t = 8 * 60 + 30;
            for (int i = 0; i < scheduled; i++)
            {
                string id = pool[r.Next(pool.Count)];
                pool.Remove(id);
                plan.Visits.Add(new ScheduledVisit { Time = t, CaseId = id, ArrivalOffset = -10f + r.Next(14) });
                t += 25 + 5 * r.Next(3);
            }
            int walkIns = 1 + r.Next(2);
            for (int i = 0; i < walkIns; i++)
            {
                bool urgent = r.NextDouble() < 0.35;
                string id = urgent ? CaseLibrary.UrgentPool[r.Next(CaseLibrary.UrgentPool.Length)] : pool[r.Next(pool.Count)];
                if (!urgent) pool.Remove(id);
                plan.Visits.Add(new ScheduledVisit { Time = 9 * 60 + r.Next(150), CaseId = id, WalkIn = true });
            }
            plan.Visits.Sort((a, b) => a.Time.CompareTo(b.Time));
        }

        /// <summary>Hachage stable d'une chaîne (identique d'une exécution à l'autre, contrairement à GetHashCode).</summary>
        public static int StableHash(string s)
        {
            unchecked
            {
                int h = 23;
                foreach (char ch in s) h = h * 31 + ch;
                return h & 0x7FFFFFFF;
            }
        }

        /// <summary>Crée le dossier complet d'un patient à partir d'un rendez-vous.</summary>
        public static PatientRecord CreatePatient(ScheduledVisit v, int dayIndex, int order)
        {
            var c = CaseLibrary.Get(v.CaseId);
            int seed = (dayIndex + 1) * 1000 + order * 37 + StableHash(v.CaseId) % 997;
            var r = new System.Random(seed);
            Sex sex = v.Sex ?? c.Sex ?? (r.NextDouble() < 0.5 ? Sex.Homme : Sex.Femme);
            int age = v.Age > 0 ? v.Age : c.AgeMin + r.Next(Mathf.Max(1, c.AgeMax - c.AgeMin + 1));
            var p = new PatientRecord
            {
                FirstName = string.IsNullOrEmpty(v.FirstName) ? NameGenerator.First(r, sex) : v.FirstName,
                LastName = string.IsNullOrEmpty(v.LastName) ? NameGenerator.LastName(r) : v.LastName,
                Sex = sex,
                Age = age,
                Seed = seed,
                Case = c,
                History = c.History,
                Meds = c.Meds,
                Allergies = c.Allergies,
                Notes = c.Notes
            };
            p.Look = HumanAppearance.Generate(seed, sex, age);
            p.Vitals = Vitals.Baseline(age, sex, p.Look.Height, p.Look.Build, r);
            p.Vitals.Apply(c.Vitals);
            if (c.Vitals.Height > 0f) p.Look.Height = c.Vitals.Height;
            if (!string.IsNullOrEmpty(c.Companion))
            {
                bool female = c.Companion.Contains("mère") || c.Companion.Contains("épouse");
                int cAge = c.Companion.Contains("épouse") ? Mathf.Max(60, age - 3) : 30 + r.Next(14);
                p.CompanionLook = HumanAppearance.Generate(seed + 17, female ? Sex.Femme : Sex.Homme, cAge);
            }
            return p;
        }
    }
}
