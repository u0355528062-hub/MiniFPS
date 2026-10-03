using System.Collections.Generic;
using BlouseBlanche.Characters;
using BlouseBlanche.Core;

namespace BlouseBlanche.Medical
{
    public enum Severity { Normal, Attention, Critique }
    public enum Urgency { Routine, Rapide, Vitale }
    public enum Orientation { Domicile, DomicileSuivi, Specialiste, Urgences15 }
    public enum BodyFocus { Tete, Bouche, Oreille, Yeux, Cou, Thorax, Bras, Main, Abdomen, Dos, Pied, Corps }
    public enum PatientPose { Neutre, Ventre, Poitrine, Dos, Tete, Toux, Boiterie, Fatigue, Oeil }

    public sealed class QuestionDef
    {
        public string Id, Category, Text, DefaultAnswer;
        public bool WomenOnly;
    }

    public sealed class ExamDef
    {
        public string Id, Name;
        public MedicalTool Tool;
        public int Minutes;
        public bool NeedsTable;
        public BodyFocus Focus;
        public Sfx Sound = Sfx.DeviceBeep;
        public Gesture PatientGesture = Gesture.None;
        public string DefaultFinding;
    }

    public sealed class DiagnosisDef { public string Id, Name, Category; }

    public sealed class TreatmentDef { public string Id, Name, Category, Detail; }

    public static class OrientationInfo
    {
        public static string Name(Orientation o)
        {
            switch (o)
            {
                case Orientation.Domicile: return "Retour à domicile";
                case Orientation.DomicileSuivi: return "Domicile + consultation de suivi";
                case Orientation.Specialiste: return "Adresser à un spécialiste";
                case Orientation.Urgences15: return "Urgence vitale : appel du 15 (SAMU)";
                default: return o.ToString();
            }
        }

        public static string Detail(Orientation o)
        {
            switch (o)
            {
                case Orientation.Domicile: return "Le patient rentre chez lui avec ses consignes.";
                case Orientation.DomicileSuivi: return "Réévaluation programmée au cabinet.";
                case Orientation.Specialiste: return "Courrier pour un avis spécialisé.";
                case Orientation.Urgences15: return "Le SAMU prend le patient en charge immédiatement.";
                default: return "";
            }
        }
    }

    /// <summary>Référentiel : questions d'interrogatoire, examens, diagnostics, traitements.</summary>
    public static class MedicalCatalog
    {
        public static readonly List<QuestionDef> Questions = new List<QuestionDef>
        {
            Q("q_debut", "Motif", "Depuis quand avez-vous ces symptômes ?", "Depuis un jour ou deux."),
            Q("q_localisation", "Motif", "Où avez-vous mal exactement ?", "Je n'ai pas vraiment mal quelque part."),
            Q("q_intensite", "Motif", "Quelle est l'intensité, de 0 à 10 ?", "Ce n'est pas vraiment douloureux."),
            Q("q_irradiation", "Motif", "La douleur se propage-t-elle ailleurs ?", "Non, ça ne bouge pas."),
            Q("q_evolution", "Motif", "Comment les symptômes évoluent-ils ?", "C'est à peu près stable."),
            Q("q_facteurs", "Motif", "Qu'est-ce qui aggrave ou soulage ?", "Rien de particulier."),
            Q("q_fievre", "Symptômes", "Avez-vous eu de la fièvre ou des frissons ?", "Non, pas de fièvre."),
            Q("q_respi", "Symptômes", "Toussez-vous ? Êtes-vous essoufflé(e) ?", "Non, je respire bien et je ne tousse pas."),
            Q("q_digestif", "Symptômes", "Nausées, vomissements, diarrhée ?", "Non, rien de ce côté-là."),
            Q("q_urinaire", "Symptômes", "Brûlures ou envies fréquentes d'uriner ?", "Non, aucun problème."),
            Q("q_neuro", "Symptômes", "Maux de tête, troubles de la vue, de la parole ?", "Non, rien de tout ça."),
            Q("q_general", "Symptômes", "Fatigue, perte de poids, perte d'appétit ?", "Non, ça va de ce côté-là."),
            Q("q_antecedents", "Antécédents", "Avez-vous des antécédents médicaux ou chirurgicaux ?", null),
            Q("q_traitements", "Antécédents", "Prenez-vous des médicaments actuellement ?", null),
            Q("q_allergies", "Antécédents", "Avez-vous des allergies, notamment médicamenteuses ?", null),
            Q("q_habitudes", "Contexte", "Fumez-vous ? Buvez-vous de l'alcool ?", "Non, je ne fume pas et je bois très peu."),
            Q("q_entourage", "Contexte", "Y a-t-il des malades dans votre entourage ?", "Pas que je sache."),
            Q("q_travail", "Contexte", "Quel est votre métier ? Un effort inhabituel ?", "Rien d'inhabituel ces derniers temps."),
            new QuestionDef { Id = "q_grossesse", Category = "Contexte", Text = "Une grossesse est-elle possible ?", DefaultAnswer = "Non, ce n'est pas possible.", WomenOnly = true },
        };

        public static readonly List<ExamDef> Exams = new List<ExamDef>
        {
            // Mains
            E("ex_palp_abdo", "Palpation abdominale", MedicalTool.Mains, 3, true, BodyFocus.Abdomen, Sfx.Paper, "Abdomen souple, dépressible et indolore. Pas de défense, pas de masse."),
            E("ex_ganglions", "Palpation des ganglions du cou", MedicalTool.Mains, 1, false, BodyFocus.Cou, Sfx.Paper, "Pas d'adénopathie cervicale palpable."),
            E("ex_rachis", "Examen du rachis lombaire", MedicalTool.Mains, 3, true, BodyFocus.Dos, Sfx.Paper, "Rachis souple, indolore à la palpation. Lasègue négatif."),
            E("ex_fosses", "Percussion des fosses lombaires", MedicalTool.Mains, 1, true, BodyFocus.Dos, Sfx.Paper, "Fosses lombaires indolores à la percussion."),
            E("ex_cheville", "Examen de la cheville", MedicalTool.Mains, 2, true, BodyFocus.Pied, Sfx.Paper, "Cheville sèche, mobile et indolore. Appui normal."),
            E("ex_peau", "Examen de la peau et des pieds", MedicalTool.Mains, 2, false, BodyFocus.Main, Sfx.Paper, "Peau normale, pas de lésion. Pieds sans plaie, sensibilité conservée."),
            // Stéthoscope
            E("ex_coeur", "Auscultation cardiaque", MedicalTool.Stethoscope, 2, false, BodyFocus.Thorax, Sfx.Heartbeat, "Bruits du cœur réguliers, sans souffle."),
            E("ex_poumons", "Auscultation pulmonaire", MedicalTool.Stethoscope, 2, false, BodyFocus.Thorax, Sfx.Heartbeat, "Murmure vésiculaire symétrique, pas de bruit surajouté."),
            // Constantes
            E("ex_ta", "Tension artérielle & pouls", MedicalTool.Tensiometre, 2, false, BodyFocus.Bras, Sfx.BloodPressure, null, Gesture.ArmOut),
            E("ex_temp", "Température", MedicalTool.Thermometre, 1, false, BodyFocus.Tete, Sfx.DeviceBeep, null),
            E("ex_spo2", "Saturation en oxygène", MedicalTool.Oxymetre, 1, false, BodyFocus.Main, Sfx.DeviceBeep, null),
            // ORL, yeux
            E("ex_otoscopie", "Otoscopie", MedicalTool.Otoscope, 2, false, BodyFocus.Oreille, Sfx.Paper, "Conduits auditifs propres, tympans normaux des deux côtés."),
            E("ex_gorge", "Examen de la gorge", MedicalTool.AbaisseLangue, 1, false, BodyFocus.Bouche, Sfx.Paper, "Gorge non inflammatoire, amygdales normales.", Gesture.OpenMouth),
            E("ex_yeux", "Examen des yeux et des pupilles", MedicalTool.AbaisseLangue, 1, false, BodyFocus.Yeux, Sfx.Paper, "Conjonctives normales, pupilles égales et réactives."),
            // Neuro
            E("ex_neuro", "Examen neurologique", MedicalTool.Marteau, 4, true, BodyFocus.Tete, Sfx.Paper, "Examen neurologique normal : force, sensibilité, réflexes et paires crâniennes sans anomalie."),
            // Fonction respiratoire, ECG
            E("ex_dep", "Débit expiratoire de pointe", MedicalTool.Debitmetre, 2, false, BodyFocus.Bouche, Sfx.Paper, "DEP normal pour l'âge et la taille."),
            E("ex_ecg", "ECG 12 dérivations", MedicalTool.ECG, 5, true, BodyFocus.Thorax, Sfx.DeviceBeep, "Rythme sinusal régulier, pas de trouble de la repolarisation."),
            // Tests rapides
            E("ex_trod", "TROD streptocoque (angine)", MedicalTool.TestsRapides, 5, false, BodyFocus.Bouche, Sfx.DeviceBeep, "TROD streptocoque A : négatif.", Gesture.OpenMouth),
            E("ex_bu", "Bandelette urinaire", MedicalTool.TestsRapides, 3, false, BodyFocus.Corps, Sfx.Paper, "Bandelette urinaire négative (leucocytes et nitrites absents)."),
            E("ex_glyc", "Glycémie capillaire", MedicalTool.TestsRapides, 2, false, BodyFocus.Main, Sfx.DeviceBeep, null),
            // Mesures
            E("ex_poids", "Poids, taille, IMC", MedicalTool.Balance, 1, false, BodyFocus.Corps, Sfx.DeviceBeep, null),
        };

        public static readonly List<DiagnosisDef> Diagnoses = new List<DiagnosisDef>
        {
            D("angine_strepto", "Angine à streptocoque A", "ORL"),
            D("angine_virale", "Angine virale", "ORL"),
            D("rhino", "Rhinopharyngite virale", "ORL"),
            D("otite", "Otite moyenne aiguë", "ORL"),
            D("grippe", "Syndrome grippal", "Respiratoire"),
            D("bronchite", "Bronchite aiguë", "Respiratoire"),
            D("pneumopathie", "Pneumopathie aiguë communautaire", "Respiratoire"),
            D("asthme", "Crise d'asthme", "Respiratoire"),
            D("hta_eq", "Hypertension artérielle équilibrée", "Cardiovasculaire"),
            D("hta_deseq", "Hypertension artérielle non contrôlée", "Cardiovasculaire"),
            D("sca", "Syndrome coronarien aigu (infarctus)", "Cardiovasculaire"),
            D("douleur_parietale", "Douleur thoracique pariétale", "Cardiovasculaire"),
            D("gastro", "Gastro-entérite aiguë", "Digestif"),
            D("appendicite", "Appendicite aiguë", "Digestif"),
            D("cystite", "Cystite aiguë simple", "Urinaire"),
            D("pyelo", "Pyélonéphrite aiguë", "Urinaire"),
            D("lombalgie", "Lombalgie commune aiguë", "Appareil locomoteur"),
            D("sciatique", "Lombosciatique", "Appareil locomoteur"),
            D("entorse", "Entorse bénigne de la cheville", "Appareil locomoteur"),
            D("fracture_cheville", "Fracture de la cheville", "Appareil locomoteur"),
            D("migraine", "Migraine", "Neurologie"),
            D("cephalee_tension", "Céphalée de tension", "Neurologie"),
            D("avc", "Accident vasculaire cérébral", "Neurologie"),
            D("diabete_deseq", "Diabète de type 2 déséquilibré", "Métabolisme"),
            D("diabete_eq", "Diabète de type 2 équilibré", "Métabolisme"),
            D("conj_virale", "Conjonctivite virale", "Ophtalmologie"),
            D("conj_bact", "Conjonctivite bactérienne", "Ophtalmologie"),
            D("rhinite_allergique", "Rhinite allergique", "Allergologie"),
        };

        public static readonly List<TreatmentDef> Treatments = new List<TreatmentDef>
        {
            T("paracetamol", "Paracétamol", "Médicaments", "Antalgique et antipyrétique de 1re intention."),
            T("ibuprofene", "Ibuprofène (AINS)", "Médicaments", "Anti-inflammatoire, courte durée."),
            T("tramadol", "Tramadol", "Médicaments", "Antalgique de palier 2."),
            T("amoxicilline", "Amoxicilline", "Médicaments", "Antibiotique (pénicilline)."),
            T("amox_clav", "Amoxicilline + acide clavulanique", "Médicaments", "Antibiotique à large spectre."),
            T("azithromycine", "Azithromycine", "Médicaments", "Antibiotique (macrolide)."),
            T("fosfomycine", "Fosfomycine-trométamol", "Médicaments", "Antibiotique urinaire en dose unique."),
            T("fluoroquinolone", "Ciprofloxacine", "Médicaments", "Antibiotique (fluoroquinolone)."),
            T("sro", "Soluté de réhydratation orale", "Médicaments", "Prévient la déshydratation."),
            T("loperamide", "Lopéramide", "Médicaments", "Antidiarrhéique."),
            T("salbutamol", "Salbutamol inhalé", "Médicaments", "Bronchodilatateur d'action rapide."),
            T("corticoide", "Prednisolone (cure courte)", "Médicaments", "Corticoïde oral."),
            T("triptan", "Triptan", "Médicaments", "Traitement de la crise migraineuse."),
            T("renouv_hta", "Renouvellement de l'antihypertenseur", "Médicaments", "Même traitement, même dose."),
            T("antidiab", "Intensification du traitement antidiabétique", "Médicaments", "Ajout d'un second antidiabétique."),
            T("aspirine", "Aspirine 250 mg (sur avis du SAMU)", "Médicaments", "Antiagrégant plaquettaire."),
            T("antihistaminique", "Antihistaminique", "Médicaments", "Traitement antiallergique."),
            T("collyre_ab", "Collyre antibiotique", "Médicaments", "Antibiotique local oculaire."),
            T("serum_phy", "Lavages au sérum physiologique", "Médicaments", "Nez ou yeux, plusieurs fois par jour."),
            T("glace", "Glace, repos, compression, élévation", "Médicaments", "Protocole de l'entorse."),
            T("attelle", "Chevillère / attelle", "Médicaments", "Contention de la cheville."),
            T("bio", "Bilan sanguin", "Examens complémentaires", "Prise de sang au laboratoire."),
            T("ecbu", "ECBU", "Examens complémentaires", "Analyse bactériologique des urines."),
            T("radio_thorax", "Radiographie thoracique", "Examens complémentaires", "Recherche d'une pneumopathie."),
            T("radio_rachis", "Radiographie du rachis lombaire", "Examens complémentaires", "Imagerie du dos."),
            T("radio_cheville", "Radiographie de la cheville", "Examens complémentaires", "Recherche de fracture."),
            T("scanner", "Scanner cérébral", "Examens complémentaires", "Imagerie du cerveau."),
            T("arret", "Arrêt de travail", "Arrêts & certificats", "Quelques jours selon l'état."),
            T("repos", "Repos et hydratation", "Conseils", "Boire régulièrement, se reposer."),
            T("hygiene", "Mesures d'hygiène", "Conseils", "Lavage des mains, masque, aération."),
            T("activite", "Maintien d'une activité adaptée", "Conseils", "Bouger plutôt que rester alité."),
            T("surveillance", "Consignes de surveillance", "Conseils", "Signes devant faire reconsulter."),
            T("hygieno_diet", "Règles hygiéno-diététiques", "Conseils", "Alimentation, sel, activité physique."),
        };

        static readonly Dictionary<string, QuestionDef> qIndex = new Dictionary<string, QuestionDef>();
        static readonly Dictionary<string, ExamDef> eIndex = new Dictionary<string, ExamDef>();
        static readonly Dictionary<string, DiagnosisDef> dIndex = new Dictionary<string, DiagnosisDef>();
        static readonly Dictionary<string, TreatmentDef> tIndex = new Dictionary<string, TreatmentDef>();

        static MedicalCatalog()
        {
            foreach (var q in Questions) qIndex[q.Id] = q;
            foreach (var e in Exams) eIndex[e.Id] = e;
            foreach (var d in Diagnoses) dIndex[d.Id] = d;
            foreach (var t in Treatments) tIndex[t.Id] = t;
        }

        public static QuestionDef Question(string id) => qIndex.TryGetValue(id, out var q) ? q : null;
        public static ExamDef Exam(string id) => eIndex.TryGetValue(id, out var e) ? e : null;
        public static DiagnosisDef Diagnosis(string id) => dIndex.TryGetValue(id, out var d) ? d : null;
        public static TreatmentDef Treatment(string id) => tIndex.TryGetValue(id, out var t) ? t : null;

        public static List<ExamDef> ExamsForTool(MedicalTool tool)
        {
            var list = new List<ExamDef>();
            foreach (var e in Exams) if (e.Tool == tool) list.Add(e);
            return list;
        }

        public static string DiagnosisName(string id) => Diagnosis(id)?.Name ?? id;
        public static string TreatmentName(string id) => Treatment(id)?.Name ?? id;
        public static string ExamName(string id) => Exam(id)?.Name ?? id;
        public static string QuestionText(string id) => Question(id)?.Text ?? id;

        static QuestionDef Q(string id, string cat, string text, string def) => new QuestionDef { Id = id, Category = cat, Text = text, DefaultAnswer = def };
        static DiagnosisDef D(string id, string name, string cat) => new DiagnosisDef { Id = id, Name = name, Category = cat };
        static TreatmentDef T(string id, string name, string cat, string detail) => new TreatmentDef { Id = id, Name = name, Category = cat, Detail = detail };
        static ExamDef E(string id, string name, MedicalTool tool, int min, bool table, BodyFocus focus, Sfx sound, string finding, Gesture gesture = Gesture.None)
            => new ExamDef { Id = id, Name = name, Tool = tool, Minutes = min, NeedsTable = table, Focus = focus, Sound = sound, DefaultFinding = finding, PatientGesture = gesture };
    }
}
