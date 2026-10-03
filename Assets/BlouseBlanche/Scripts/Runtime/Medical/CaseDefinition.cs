using System;
using System.Collections.Generic;
using BlouseBlanche.Characters;
using UnityEngine;

namespace BlouseBlanche.Medical
{
    public sealed class Finding
    {
        public string Text;
        public Severity Severity;
        public Finding(string text, Severity severity = Severity.Normal) { Text = text; Severity = severity; }
    }

    /// <summary>Constantes imposées par un cas (−1 = valeur physiologique de base).</summary>
    public sealed class VitalsSpec
    {
        public float Temp = -1f, Glyc = -1f, Weight = -1f, Height = -1f;
        public int Sys = -1, Dia = -1, Hr = -1, Spo2 = -1, Rr = -1;
        public bool Irregular;
    }

    /// <summary>Constantes réelles du patient pour la consultation.</summary>
    public sealed class Vitals
    {
        public float Temp, Glyc, Weight, Height;
        public int Sys, Dia, Hr, Spo2, Rr;
        public bool Irregular;
        public float Bmi => Height > 0.3f ? Weight / (Height * Height) : 0f;

        public static Vitals Baseline(int age, Sex sex, float height, float build, System.Random r)
        {
            bool child = age < 13;
            var v = new Vitals
            {
                Temp = 36.6f + (float)r.NextDouble() * 0.5f,
                Sys = child ? 98 + r.Next(10) : 112 + r.Next(14) + Mathf.Max(0, (age - 45) / 3),
                Dia = child ? 58 + r.Next(8) : 68 + r.Next(10),
                Hr = child ? 88 + r.Next(16) : 62 + r.Next(16),
                Spo2 = 97 + r.Next(3),
                Rr = child ? 20 + r.Next(4) : 13 + r.Next(4),
                Glyc = 0.85f + (float)r.NextDouble() * 0.2f,
                Height = height
            };
            float bmi = child ? 15.5f + (float)r.NextDouble() * 2f : 21f + (build - 0.86f) * 26f;
            v.Weight = Mathf.Round(bmi * height * height * 10f) / 10f;
            return v;
        }

        public void Apply(VitalsSpec s)
        {
            if (s == null) return;
            if (s.Temp > 0f) Temp = s.Temp;
            if (s.Sys > 0) Sys = s.Sys;
            if (s.Dia > 0) Dia = s.Dia;
            if (s.Hr > 0) Hr = s.Hr;
            if (s.Spo2 > 0) Spo2 = s.Spo2;
            if (s.Rr > 0) Rr = s.Rr;
            if (s.Glyc > 0f) Glyc = s.Glyc;
            if (s.Weight > 0f) Weight = s.Weight;
            if (s.Height > 0f) Height = s.Height;
            Irregular = s.Irregular;
        }

        public static string F1(float v) => v.ToString("0.0", System.Globalization.CultureInfo.InvariantCulture).Replace('.', ',');
        public static string F2(float v) => v.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture).Replace('.', ',');
    }

    /// <summary>
    /// Un cas clinique complet : présentation, réponses à l'interrogatoire, résultats d'examen,
    /// et la "vérité" attendue (diagnostic, traitements, orientation) pour l'évaluation.
    /// </summary>
    public sealed class CaseDef
    {
        public string Id, Title, Motif, Opening;
        public int AgeMin = 18, AgeMax = 70;
        public Sex? Sex;
        public Urgency Urgency = Urgency.Routine;
        public PatientPose Pose = PatientPose.Neutre;
        public bool Cough, Limp;
        public string Companion;              // ex. « sa mère » : répond à la place du patient
        public string[] History = Array.Empty<string>();
        public string[] Meds = Array.Empty<string>();
        public string[] Allergies = Array.Empty<string>();
        public string Notes;                  // résultats apportés, courrier…
        public VitalsSpec Vitals = new VitalsSpec();

        public readonly Dictionary<string, string> Answers = new Dictionary<string, string>();
        public readonly Dictionary<string, Finding> Findings = new Dictionary<string, Finding>();
        public readonly HashSet<string> KeyQuestions = new HashSet<string>();
        public readonly HashSet<string> KeyExams = new HashSet<string>();
        public readonly HashSet<string> UsefulExams = new HashSet<string>();

        public string Diagnosis;
        public readonly HashSet<string> PartialDiagnoses = new HashSet<string>();

        /// <summary>Chaque entrée est un groupe "l'un ou l'autre".</summary>
        public readonly List<string[]> RequiredTx = new List<string[]>();
        public readonly HashSet<string> RecommendedTx = new HashSet<string>();
        public readonly HashSet<string> AcceptableTx = new HashSet<string>();
        public readonly Dictionary<string, string> HarmfulTx = new Dictionary<string, string>();
        public readonly Dictionary<string, string> DiscouragedTx = new Dictionary<string, string>();

        public Orientation Orientation = Orientation.Domicile;
        public readonly HashSet<Orientation> AcceptableOrientations = new HashSet<Orientation>();

        public string Teaching;
        public int IdealMinutes = 12;
        public float PatienceMinutes = 55f;
        /// <summary>Urgences : délai (min de jeu) avant aggravation si personne ne s'en occupe.</summary>
        public float DeteriorationMinutes = 22f;

        public bool IsChildCase => AgeMax < 13;
    }
}
