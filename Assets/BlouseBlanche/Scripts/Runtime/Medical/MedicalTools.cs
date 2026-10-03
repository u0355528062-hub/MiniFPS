namespace BlouseBlanche.Medical
{
    /// <summary>Outils de la roue de consultation (12 emplacements, comme un cadran).</summary>
    public enum MedicalTool
    {
        Mains = 0,
        Stethoscope = 1,
        Tensiometre = 2,
        Thermometre = 3,
        Oxymetre = 4,
        Otoscope = 5,
        AbaisseLangue = 6,
        Marteau = 7,
        Debitmetre = 8,
        ECG = 9,
        TestsRapides = 10,
        Balance = 11,
    }

    public static class MedicalTools
    {
        public const int Count = 12;

        public static string Name(MedicalTool t)
        {
            switch (t)
            {
                case MedicalTool.Mains: return "Mains";
                case MedicalTool.Stethoscope: return "Stéthoscope";
                case MedicalTool.Tensiometre: return "Tensiomètre";
                case MedicalTool.Thermometre: return "Thermomètre";
                case MedicalTool.Oxymetre: return "Oxymètre";
                case MedicalTool.Otoscope: return "Otoscope";
                case MedicalTool.AbaisseLangue: return "Abaisse-langue & lampe";
                case MedicalTool.Marteau: return "Marteau à réflexes";
                case MedicalTool.Debitmetre: return "Débitmètre de pointe";
                case MedicalTool.ECG: return "Électrocardiographe";
                case MedicalTool.TestsRapides: return "Tests rapides";
                case MedicalTool.Balance: return "Balance & toise";
                default: return t.ToString();
            }
        }

        public static string Description(MedicalTool t)
        {
            switch (t)
            {
                case MedicalTool.Mains: return "Palpation de l'abdomen, des ganglions, du rachis, des articulations, examen de la peau.";
                case MedicalTool.Stethoscope: return "Auscultation du cœur et des poumons.";
                case MedicalTool.Tensiometre: return "Pression artérielle et fréquence cardiaque.";
                case MedicalTool.Thermometre: return "Température corporelle.";
                case MedicalTool.Oxymetre: return "Saturation en oxygène (SpO2) et pouls.";
                case MedicalTool.Otoscope: return "Examen des conduits auditifs et des tympans.";
                case MedicalTool.AbaisseLangue: return "Examen de la gorge, des amygdales, des yeux et des pupilles.";
                case MedicalTool.Marteau: return "Réflexes, force, sensibilité : examen neurologique.";
                case MedicalTool.Debitmetre: return "Débit expiratoire de pointe (asthme, BPCO).";
                case MedicalTool.ECG: return "Tracé 12 dérivations : rythme, ischémie.";
                case MedicalTool.TestsRapides: return "TROD angine, bandelette urinaire, glycémie capillaire.";
                case MedicalTool.Balance: return "Poids, taille et indice de masse corporelle.";
                default: return "";
            }
        }

        /// <summary>Raccourci clavier (1..9, 0, -, =) affiché dans la roue.</summary>
        public static string Hotkey(MedicalTool t)
        {
            int i = (int)t;
            if (i < 9) return (i + 1).ToString();
            if (i == 9) return "0";
            return i == 10 ? "-" : "=";
        }
    }
}
