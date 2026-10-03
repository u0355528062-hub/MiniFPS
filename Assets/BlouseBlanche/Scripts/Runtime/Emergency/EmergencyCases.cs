using System;
using System.Collections.Generic;
using BlouseBlanche.Characters;

namespace BlouseBlanche.Emergency
{
    public enum Condition
    {
        ArretCardiaque, Hypoglycemie, Opiaces, InfarctusST, Anaphylaxie, FractureFemur,
        Appendicite, EmboliePulmonaire, ChocSeptique, ColiqueNephretique, HemorragieDigestive, Pneumothorax
    }

    public sealed class CriticalAction
    {
        public string[] AnyOf;
        public string Label;
        public float Deadline;     // minutes (0 = pas de délai)
        public int Weight = 1;
    }

    public sealed class EmergencyCase
    {
        public string Id, Title, Subtitle, Dispatch;
        public EmergencySetting Setting;
        public Condition Condition;
        public int AgeMin = 30, AgeMax = 70;
        public Sex? Sex;
        public string Witness;                 // « son épouse » (SAMU) ; null = le patient répond lui-même
        public bool PatientTalks = true;
        public int Difficulty = 2;             // 1..3
        public Func<PatientState> Initial;
        public readonly Dictionary<string, string> Answers = new Dictionary<string, string>();
        public readonly Dictionary<string, string> Findings = new Dictionary<string, string>();
        public readonly Dictionary<string, string> Results = new Dictionary<string, string>();
        public readonly HashSet<string> KeyExams = new HashSet<string>();
        public readonly List<CriticalAction> Critical = new List<CriticalAction>();
        public readonly Dictionary<string, string> Harmful = new Dictionary<string, string>();
        public readonly HashSet<string> Useful = new HashSet<string>();
        public string Diagnosis;
        public string Destination;
        public readonly HashSet<string> AcceptableDestinations = new HashSet<string>();
        public string Teaching;
        public bool Lying = true;

        public CriticalAction Need(string label, float deadline, params string[] anyOf)
        {
            var c = new CriticalAction { AnyOf = anyOf, Label = label, Deadline = deadline };
            Critical.Add(c);
            return c;
        }
    }

    public sealed class EmergencyDiagnosis { public string Id, Name; }

    public static class EmergencyCases
    {
        public static readonly List<EmergencyCase> All = new List<EmergencyCase>();

        public static readonly List<EmergencyDiagnosis> Diagnoses = new List<EmergencyDiagnosis>
        {
            D("acr", "Arrêt cardio-respiratoire (fibrillation ventriculaire)"),
            D("hypoglycemie", "Hypoglycémie sévère"),
            D("opiaces", "Intoxication aux opiacés"),
            D("sca", "Infarctus du myocarde (SCA ST+)"),
            D("anaphylaxie", "Choc anaphylactique"),
            D("fracture_femur", "Fracture du col du fémur"),
            D("appendicite", "Appendicite aiguë"),
            D("embolie", "Embolie pulmonaire"),
            D("sepsis", "Choc septique (pyélonéphrite)"),
            D("colique", "Colique néphrétique"),
            D("hemorragie", "Hémorragie digestive haute"),
            D("pneumothorax", "Pneumothorax"),
            D("avc", "Accident vasculaire cérébral"),
            D("convulsions", "Crise convulsive"),
            D("malaise_vagal", "Malaise vagal"),
            D("dissection", "Dissection aortique"),
            D("pancreatite", "Pancréatite aiguë"),
            D("pneumopathie", "Pneumopathie infectieuse"),
            D("asthme", "Asthme aigu grave"),
        };

        static EmergencyDiagnosis D(string id, string n) => new EmergencyDiagnosis { Id = id, Name = n };

        public static string DiagnosisName(string id)
        {
            foreach (var d in Diagnoses) if (d.Id == id) return d.Name;
            return id;
        }

        public static EmergencyCase Get(string id)
        {
            foreach (var c in All) if (c.Id == id) return c;
            return null;
        }

        public static List<EmergencyCase> For(EmergencySetting s)
        {
            var l = new List<EmergencyCase>();
            foreach (var c in All) if (c.Setting == s) l.Add(c);
            return l;
        }

        static EmergencyCase Add(EmergencyCase c) { All.Add(c); return c; }

        static EmergencyCases()
        {
            // ================================================================== SAMU

            var c = Add(new EmergencyCase
            {
                Id = "samu_acr", Title = "Arrêt cardiaque", Subtitle = "Homme effondré dans son salon",
                Dispatch = "Homme de 60 ans, s'est effondré devant la télévision il y a 2 minutes. Son épouse dit qu'il ne respire plus.",
                Setting = EmergencySetting.Samu, Condition = Condition.ArretCardiaque, AgeMin = 55, AgeMax = 68, Sex = Characters.Sex.Homme,
                Witness = "son épouse", PatientTalks = false, Difficulty = 3,
                Initial = () => new PatientState { Hr = 0, Sys = 0, Dia = 0, Spo2 = 0, Rr = 0, Gcs = 3, Rhythm = Rhythm.FibrillationVentriculaire, Breathing = Breathing.Agonique, NoFlowMinutes = 2f },
                Diagnosis = "acr", Destination = "coronarographie",
                Teaching = "Arrêt cardiaque : chaque minute sans massage fait perdre environ 10 % de chances de survie. Inconscient + respiration absente ou anormale (gasps) = massage cardiaque immédiat. Défibrillation dès que possible sur une fibrillation ventriculaire, puis adrénaline 1 mg après le 2e choc et amiodarone après le 3e. Après reprise d'activité cardiaque, l'ECG cherche un infarctus : direction coronarographie."
            });
            c.Answers["w_quoi"] = "Il regardait la télé, il a porté la main à sa poitrine et il s'est effondré. Depuis il fait des bruits bizarres, comme des ronflements… et maintenant plus rien !";
            c.Answers["w_quand"] = "Il y a deux minutes, peut-être trois. J'ai appelé le 15 tout de suite.";
            c.Answers["w_antecedents"] = "Il a de la tension et du cholestérol. Il fume beaucoup.";
            c.Answers["w_traitements"] = "Un médicament pour la tension, je crois.";
            c.Answers["w_allergies"] = "Non, aucune.";
            c.Answers["w_avant"] = "Il se plaignait d'une douleur dans la poitrine depuis ce matin, il ne voulait pas déranger…";
            c.Findings["examen"] = "Patient inconscient, cyanosé, gasps. Aucune plaie, pas de traumatisme.";
            c.Need("Massage cardiaque débuté rapidement", 2f, "rcp").Weight = 2;
            c.Need("Défibrillation de la fibrillation ventriculaire", 5f, "choc").Weight = 2;
            c.Need("Ventilation au ballon / oxygène", 0f, "bavu", "o2");
            c.Need("Voie veineuse et adrénaline", 0f, "adrenaline_iv");
            c.Need("ECG après reprise d'activité cardiaque", 0f, "ecg");
            c.KeyExams.UnionWith(new[] { "conscience", "ventilation", "pouls", "scope" });
            c.Useful.UnionWith(new[] { "vvp", "amiodarone", "glycemie" });
            c.Harmful["adrenaline_im"] = "Ce n'est pas la bonne dose ni la bonne voie dans l'arrêt cardiaque (1 mg IV).";
            c.AcceptableDestinations.Add("reanimation");

            c = Add(new EmergencyCase
            {
                Id = "samu_hypo", Title = "Malaise chez un diabétique", Subtitle = "Inconscient sur le sol du salon",
                Dispatch = "Homme de 55 ans, diabétique sous insuline, retrouvé inconscient par sa fille, couvert de sueurs.",
                Setting = EmergencySetting.Samu, Condition = Condition.Hypoglycemie, AgeMin = 45, AgeMax = 70,
                Witness = "sa fille", PatientTalks = false, Difficulty = 1,
                Initial = () => new PatientState { Hr = 104, Sys = 138, Dia = 82, Spo2 = 96, Rr = 18, Gcs = 8, Glyc = 0.32f },
                Diagnosis = "hypoglycemie", Destination = "sur_place",
                Teaching = "Devant tout trouble de conscience : glycémie capillaire ! L'hypoglycémie sévère se corrige par du glucose 30 % IV (ou du glucagon IM si pas de voie veineuse). Le réveil est spectaculaire. Patient sous insuline réveillé, cause identifiée (repas sauté) et entourage présent : on peut le laisser sur place après resucrage oral et consignes."
            });
            c.Answers["w_quoi"] = "Je l'ai trouvé par terre en rentrant, tout transpirant. Il ne répond pas vraiment, il grogne.";
            c.Answers["w_quand"] = "Je l'ai eu au téléphone il y a une heure, il allait bien.";
            c.Answers["w_antecedents"] = "Il est diabétique depuis 20 ans, sous insuline.";
            c.Answers["w_traitements"] = "Insuline matin et soir. Il a fait son injection ce matin, je crois.";
            c.Answers["w_allergies"] = "Aucune allergie.";
            c.Answers["w_avant"] = "Il a sauté le déjeuner, il avait une réunion. Et il est allé courir ce matin.";
            c.Findings["examen"] = "Sueurs profuses, pâleur, aucun signe de traumatisme, pas de déficit moteur franc.";
            c.Findings["pupilles"] = "Pupilles intermédiaires, égales et réactives.";
            c.Need("Glycémie capillaire mesurée", 6f, "glycemie").Weight = 2;
            c.Need("Resucrage (glucose IV ou glucagon IM)", 12f, "glucose", "glucagon").Weight = 2;
            c.KeyExams.UnionWith(new[] { "conscience", "ventilation", "scope" });
            c.Useful.UnionWith(new[] { "vvp", "pupilles", "pls" });
            c.Harmful["naloxone"] = "Antidote inutile : il ne s'agit pas d'une intoxication aux opiacés.";
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée chez un patient qui a un pouls.";
            c.AcceptableDestinations.Add("urgences");

            c = Add(new EmergencyCase
            {
                Id = "samu_opiaces", Title = "Overdose", Subtitle = "Jeune adulte inconscient",
                Dispatch = "Jeune homme retrouvé inconscient par un ami dans un appartement. Respire très peu.",
                Setting = EmergencySetting.Samu, Condition = Condition.Opiaces, AgeMin = 20, AgeMax = 34, Sex = Characters.Sex.Homme,
                Witness = "son ami", PatientTalks = false, Difficulty = 2,
                Initial = () => new PatientState { Hr = 58, Sys = 105, Dia = 64, Spo2 = 76, Rr = 4, Gcs = 5, Breathing = Breathing.Lente, Glyc = 1.05f },
                Diagnosis = "opiaces", Destination = "urgences",
                Teaching = "Coma + myosis serré + bradypnée = intoxication aux opiacés. Priorité à l'oxygénation : ventilation au ballon, puis naloxone (antidote) en titration. La naloxone agit moins longtemps que l'opiacé : risque de rendormissement, donc transport et surveillance aux urgences."
            });
            c.Answers["w_quoi"] = "On était à une soirée… il est allé dans la chambre et je l'ai retrouvé comme ça. Il respire à peine !";
            c.Answers["w_quand"] = "Je ne sais pas, peut-être vingt minutes.";
            c.Answers["w_antecedents"] = "Il a déjà eu des problèmes avec… des produits.";
            c.Answers["w_traitements"] = "Je ne crois pas qu'il ait de traitement.";
            c.Answers["w_allergies"] = "Je ne sais pas.";
            c.Answers["w_avant"] = "Il y avait une seringue à côté de lui. Je ne voulais pas le dire…";
            c.Findings["pupilles"] = "Myosis serré bilatéral (pupilles en tête d'épingle).";
            c.Findings["examen"] = "Traces de piqûres aux plis des coudes, seringue au sol. Pas de traumatisme.";
            c.Need("Ventilation au ballon", 4f, "bavu").Weight = 2;
            c.Need("Naloxone", 10f, "naloxone").Weight = 2;
            c.Need("Oxygène", 0f, "o2", "bavu");
            c.KeyExams.UnionWith(new[] { "conscience", "ventilation", "pupilles", "scope" });
            c.Useful.UnionWith(new[] { "glycemie", "vvp", "pls" });
            c.Harmful["morphine"] = "Faute grave : ajouter un opiacé chez un patient en overdose d'opiacés.";
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée chez un patient qui a un pouls.";
            c.AcceptableDestinations.Add("reanimation");

            c = Add(new EmergencyCase
            {
                Id = "samu_sca", Title = "Douleur thoracique", Subtitle = "Infarctus à domicile",
                Dispatch = "Homme de 62 ans, douleur thoracique intense depuis 1 heure, sueurs, assis dans son salon.",
                Setting = EmergencySetting.Samu, Condition = Condition.InfarctusST, AgeMin = 52, AgeMax = 72, Sex = Characters.Sex.Homme,
                Witness = null, PatientTalks = true, Difficulty = 2, Lying = true,
                Initial = () => new PatientState { Hr = 96, Sys = 148, Dia = 92, Spo2 = 96, Rr = 20, Gcs = 15, Pain = 8f },
                Diagnosis = "sca", Destination = "coronarographie",
                Teaching = "Douleur thoracique typique + sus-décalage ST = infarctus : l'objectif est la reperfusion le plus vite possible. Le SMUR réalise l'ECG, pose une voie veineuse, donne aspirine et anticoagulant, soulage la douleur, et transporte directement en salle de coronarographie. Le risque majeur pendant la prise en charge est la fibrillation ventriculaire : défibrillateur et scope toujours branchés."
            });
            c.Answers["w_quoi"] = "Ça me serre dans la poitrine, comme un poids énorme… ça part dans la mâchoire.";
            c.Answers["w_quand"] = "Depuis une heure environ. Au début je pensais que c'était la digestion.";
            c.Answers["w_antecedents"] = "Du diabète, et je fume. Mon père est mort d'une crise cardiaque.";
            c.Answers["w_traitements"] = "De la metformine.";
            c.Answers["w_allergies"] = "Pas d'allergie.";
            c.Answers["w_avant"] = "Rien de spécial, j'étais assis à lire le journal.";
            c.Findings["examen"] = "Patient pâle, en sueurs, angoissé. Auscultation normale, pas de signe d'insuffisance cardiaque.";
            c.Findings["ecg"] = "Sus-décalage du segment ST en DII, DIII, aVF : infarctus inférieur.";
            c.Need("ECG 12 dérivations", 10f, "ecg").Weight = 2;
            c.Need("Aspirine IV", 0f, "aspirine");
            c.Need("Anticoagulation (héparine)", 0f, "heparine");
            c.Need("Voie veineuse", 0f, "vvp");
            c.Need("Scope branché (risque de trouble du rythme)", 5f, "scope");
            c.KeyExams.UnionWith(new[] { "conscience", "auscultation" });
            c.Useful.UnionWith(new[] { "morphine", "glycemie" });
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée chez un patient qui a un pouls.";
            c.Harmful["ketoprofene"] = "Les AINS sont contre-indiqués dans l'infarctus.";

            c = Add(new EmergencyCase
            {
                Id = "samu_anaphylaxie", Title = "Piqûre de guêpe", Subtitle = "Choc anaphylactique",
                Dispatch = "Femme de 35 ans piquée par une guêpe il y a 10 minutes, gonflement du visage, difficultés respiratoires, malaise.",
                Setting = EmergencySetting.Samu, Condition = Condition.Anaphylaxie, AgeMin = 25, AgeMax = 50, Sex = Characters.Sex.Femme,
                Witness = "son mari", PatientTalks = true, Difficulty = 2,
                Initial = () => new PatientState { Hr = 132, Sys = 78, Dia = 42, Spo2 = 90, Rr = 28, Gcs = 14, Breathing = Breathing.Sifflante },
                Diagnosis = "anaphylaxie", Destination = "urgences",
                Teaching = "Choc anaphylactique : urticaire, œdème, bronchospasme et hypotension après exposition à un allergène. Le traitement de première ligne est l'adrénaline intramusculaire (0,5 mg chez l'adulte), à répéter après 5 minutes si besoin, avec oxygène et remplissage. Les corticoïdes et antihistaminiques ne sont que des traitements d'appoint. Surveillance hospitalière (réaction biphasique)."
            });
            c.Answers["w_quoi"] = "Une guêpe l'a piquée sur la terrasse, et en quelques minutes elle a gonflé, elle a eu du mal à respirer et elle est tombée.";
            c.Answers["w_quand"] = "Il y a dix minutes.";
            c.Answers["w_antecedents"] = "Elle avait déjà fait une grosse réaction à une piqûre l'an dernier.";
            c.Answers["w_traitements"] = "Rien. Elle devait voir un allergologue…";
            c.Answers["w_allergies"] = "Les guêpes, justement !";
            c.Answers["w_avant"] = "On déjeunait dehors.";
            c.Findings["examen"] = "Urticaire géante, œdème des lèvres et des paupières, sibilants diffus, extrémités froides.";
            c.Findings["auscultation"] = "Sibilants diffus aux deux champs pulmonaires. Tachycardie régulière.";
            c.Need("Adrénaline intramusculaire", 5f, "adrenaline_im").Weight = 3;
            c.Need("Oxygène", 0f, "o2");
            c.Need("Remplissage vasculaire", 0f, "remplissage");
            c.KeyExams.UnionWith(new[] { "conscience", "auscultation", "scope" });
            c.Useful.UnionWith(new[] { "salbutamol", "corticoide", "vvp" });
            c.Harmful["adrenaline_iv"] = "Adrénaline 1 mg IV en bolus chez un patient qui a un pouls : risque d'arythmie mortelle. C'est la voie IM qui s'impose.";
            c.Harmful["morphine"] = "La morphine aggrave l'hypotension.";
            c.Harmful["trinitrine"] = "Vasodilatateur dangereux en état de choc.";
            c.AcceptableDestinations.Add("reanimation");

            c = Add(new EmergencyCase
            {
                Id = "samu_chute", Title = "Chute de la personne âgée", Subtitle = "Ne peut plus se relever",
                Dispatch = "Femme de 84 ans, a chuté dans son salon, ne peut pas se relever, douleur de hanche droite.",
                Setting = EmergencySetting.Samu, Condition = Condition.FractureFemur, AgeMin = 78, AgeMax = 90, Sex = Characters.Sex.Femme,
                Witness = null, PatientTalks = true, Difficulty = 1,
                Initial = () => new PatientState { Hr = 92, Sys = 142, Dia = 80, Spo2 = 96, Rr = 18, Gcs = 15, Pain = 8f, Glyc = 1.1f },
                Diagnosis = "fracture_femur", Destination = "urgences",
                Teaching = "Chute de la personne âgée avec membre inférieur raccourci et en rotation externe : fracture du col du fémur jusqu'à preuve du contraire. On recherche la cause de la chute (malaise ? glycémie, ECG), on soulage efficacement (morphine titrée), on immobilise (matelas à dépression) et on transporte aux urgences pour une chirurgie rapide. Penser au temps passé au sol (déshydratation, escarres)."
            });
            c.Answers["w_quoi"] = "J'ai glissé sur le tapis en allant ouvrir la fenêtre… je ne peux plus bouger la jambe.";
            c.Answers["w_quand"] = "Ce matin vers 9 heures. J'ai mis du temps à atteindre le téléphone.";
            c.Answers["w_antecedents"] = "De l'ostéoporose, de la tension.";
            c.Answers["w_traitements"] = "Un comprimé pour la tension, et du calcium.";
            c.Answers["w_allergies"] = "Je ne supporte pas la codéine, ça me fait vomir.";
            c.Answers["w_avant"] = "Non, je n'ai pas eu de malaise, j'ai vraiment glissé.";
            c.Findings["examen"] = "Membre inférieur droit raccourci, en rotation externe, très douloureux à la mobilisation. Pas de plaie. Pas d'autre lésion.";
            c.Need("Antalgie efficace (morphine)", 0f, "morphine").Weight = 2;
            c.Need("Immobilisation (matelas à dépression)", 0f, "matelas").Weight = 2;
            c.Need("Recherche d'une cause médicale (glycémie ou ECG)", 0f, "glycemie", "ecg");
            c.KeyExams.UnionWith(new[] { "examen", "conscience" });
            c.Useful.UnionWith(new[] { "vvp", "paracetamol", "scope" });
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée chez un patient qui a un pouls.";
            c.AcceptableDestinations.Add("bloc");

            // ================================================================== URGENCES

            c = Add(new EmergencyCase
            {
                Id = "urg_appendicite", Title = "Douleur abdominale", Subtitle = "Fosse iliaque droite",
                Dispatch = "Box 3 : homme de 24 ans, douleur abdominale depuis hier, fièvre. Adressé par son médecin traitant.",
                Setting = EmergencySetting.Urgences, Condition = Condition.Appendicite, AgeMin = 18, AgeMax = 35,
                Witness = null, PatientTalks = true, Difficulty = 1,
                Initial = () => new PatientState { Hr = 98, Sys = 128, Dia = 76, Spo2 = 98, Rr = 18, Temp = 38.4f, Gcs = 15, Pain = 7f },
                Diagnosis = "appendicite", Destination = "bloc",
                Teaching = "Douleur migrant de l'épigastre vers la fosse iliaque droite, fièvre modérée, défense : appendicite aiguë. Le bilan montre un syndrome inflammatoire ; l'imagerie (échographie ou scanner) confirme. On laisse à jeun, on soulage, et l'avis chirurgical mène au bloc opératoire."
            });
            c.Answers["w_quoi"] = "J'ai mal au ventre depuis hier, d'abord autour du nombril, maintenant en bas à droite.";
            c.Answers["w_quand"] = "Depuis hier midi, ça empire.";
            c.Answers["w_antecedents"] = "Rien du tout.";
            c.Answers["w_traitements"] = "Aucun.";
            c.Answers["w_allergies"] = "Non.";
            c.Answers["w_avant"] = "J'ai vomi une fois ce matin. Je n'ai rien mangé depuis hier.";
            c.Findings["abdomen"] = "Douleur et défense en fosse iliaque droite (point de McBurney), douleur à la décompression.";
            c.Findings["examen"] = "Patient fébrile, fatigué. Abdomen : défense en fosse iliaque droite.";
            c.Results["bio"] = "Leucocytes 15,8 G/L, CRP 92 mg/L. Ionogramme et créatinine normaux. Lipase normale.";
            c.Results["echo"] = "Appendice de 9 mm, non compressible, infiltration de la graisse : appendicite aiguë.";
            c.Results["scanner_abdo"] = "Appendicite aiguë non compliquée, pas de perforation.";
            c.Results["bu"] = "Bandelette urinaire négative.";
            c.Need("Palpation abdominale", 0f, "abdomen", "examen").Weight = 2;
            c.Need("Bilan sanguin", 0f, "bio");
            c.Need("Imagerie de confirmation", 0f, "echo", "scanner_abdo").Weight = 2;
            c.Need("Antalgie", 0f, "paracetamol", "morphine");
            c.KeyExams.UnionWith(new[] { "temperature", "scope" });
            c.Useful.UnionWith(new[] { "vvp", "bu", "antibio" });
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée.";

            c = Add(new EmergencyCase
            {
                Id = "urg_embolie", Title = "Essoufflement brutal", Subtitle = "Après un long voyage",
                Dispatch = "Box 1 : femme de 42 ans, essoufflement brutal et douleur thoracique, de retour d'un vol de 12 heures.",
                Setting = EmergencySetting.Urgences, Condition = Condition.EmboliePulmonaire, AgeMin = 30, AgeMax = 60, Sex = Characters.Sex.Femme,
                Witness = null, PatientTalks = true, Difficulty = 2,
                Initial = () => new PatientState { Hr = 118, Sys = 112, Dia = 70, Spo2 = 89, Rr = 26, Gcs = 15, Pain = 5f },
                Diagnosis = "embolie", Destination = "hospitalisation",
                Teaching = "Dyspnée brutale, tachycardie, hypoxémie après un long voyage : embolie pulmonaire. Oxygène, D-dimères puis angioscanner thoracique pour confirmer, et anticoagulation. Sans état de choc, hospitalisation en médecine ; avec choc, réanimation et thrombolyse."
            });
            c.Answers["w_quoi"] = "J'ai d'un coup eu du mal à respirer, avec un point de côté à droite quand j'inspire.";
            c.Answers["w_quand"] = "Il y a deux heures, en sortant du taxi.";
            c.Answers["w_antecedents"] = "Rien, à part la pilule. Je fume un peu.";
            c.Answers["w_traitements"] = "Pilule contraceptive.";
            c.Answers["w_allergies"] = "Non.";
            c.Answers["w_avant"] = "Je rentre d'un vol de douze heures. Mon mollet gauche me fait mal depuis hier.";
            c.Findings["examen"] = "Polypnée, mollet gauche chaud et douloureux. Auscultation pulmonaire normale.";
            c.Findings["auscultation"] = "Auscultation pulmonaire normale, tachycardie régulière.";
            c.Findings["ecg"] = "Tachycardie sinusale à 118/min, aspect S1Q3.";
            c.Results["bio"] = "D-dimères 3 200 µg/L (très élevés), troponine légèrement augmentée, créatinine normale.";
            c.Results["gaz"] = "Hypoxémie (PaO2 58 mmHg) et hypocapnie.";
            c.Results["angioscanner"] = "Embolie pulmonaire bilatérale proximale, dilatation modérée du ventricule droit.";
            c.Results["radio_thorax"] = "Radiographie thoracique sans anomalie franche.";
            c.Need("Oxygène", 5f, "o2").Weight = 2;
            c.Need("Angioscanner thoracique", 0f, "angioscanner").Weight = 2;
            c.Need("Anticoagulation (héparine)", 0f, "heparine").Weight = 2;
            c.KeyExams.UnionWith(new[] { "scope", "ecg", "examen" });
            c.Useful.UnionWith(new[] { "bio", "gaz", "vvp" });
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée.";
            c.AcceptableDestinations.Add("reanimation");

            c = Add(new EmergencyCase
            {
                Id = "urg_sepsis", Title = "Fièvre et confusion", Subtitle = "Choc septique",
                Dispatch = "Box 2 : femme de 78 ans amenée par les pompiers, fièvre à 39,6 °C, confuse, tension basse.",
                Setting = EmergencySetting.Urgences, Condition = Condition.ChocSeptique, AgeMin = 70, AgeMax = 88, Sex = Characters.Sex.Femme,
                Witness = "sa fille", PatientTalks = false, Difficulty = 3,
                Initial = () => new PatientState { Hr = 124, Sys = 82, Dia = 44, Spo2 = 93, Rr = 25, Temp = 39.6f, Gcs = 13 },
                Diagnosis = "sepsis", Destination = "reanimation",
                Teaching = "Sepsis grave d'origine urinaire : hypotension, tachycardie, confusion, lactates élevés. Dans la première heure : hémocultures, antibiothérapie IV, remplissage de 30 mL/kg, mesure des lactates. Hypotension persistante = choc septique : réanimation."
            });
            c.Answers["w_quoi"] = "Elle délire depuis ce matin, elle brûle de fièvre et elle se plaignait de brûlures en urinant depuis trois jours.";
            c.Answers["w_quand"] = "La fièvre depuis hier soir.";
            c.Answers["w_antecedents"] = "Du diabète et des infections urinaires à répétition.";
            c.Answers["w_traitements"] = "Metformine et un médicament pour la tension.";
            c.Answers["w_allergies"] = "Pénicilline ? Non, aucune, je crois.";
            c.Answers["w_avant"] = "Elle ne buvait plus beaucoup.";
            c.Findings["examen"] = "Marbrures des genoux, extrémités froides, fosse lombaire droite douloureuse à la percussion.";
            c.Results["bio"] = "Leucocytes 22 G/L, CRP 310 mg/L, créatinine 168 µmol/L, lactates 4,2 mmol/L.";
            c.Results["gaz"] = "Acidose métabolique, lactates 4,2 mmol/L.";
            c.Results["bu"] = "Leucocytes +++, nitrites +.";
            c.Results["hemocultures"] = "Hémocultures prélevées (résultat dans 24 à 48 h).";
            c.Results["echo"] = "Rein droit discrètement dilaté, pas d'obstacle franc.";
            c.Need("Hémocultures avant antibiotiques", 0f, "hemocultures");
            c.Need("Antibiothérapie IV dans l'heure", 60f, "antibio").Weight = 3;
            c.Need("Remplissage vasculaire", 20f, "remplissage").Weight = 2;
            c.Need("Lactates (bilan ou gaz du sang)", 0f, "bio", "gaz");
            c.KeyExams.UnionWith(new[] { "scope", "temperature", "examen" });
            c.Useful.UnionWith(new[] { "bu", "o2", "vvp" });
            c.Harmful["morphine"] = "Aggrave l'hypotension sans indication.";
            c.Harmful["trinitrine"] = "Vasodilatateur dangereux en état de choc.";
            c.Harmful["adrenaline_iv"] = "Adrénaline en bolus injustifiée.";

            c = Add(new EmergencyCase
            {
                Id = "urg_colique", Title = "Douleur lombaire atroce", Subtitle = "Agité, ne tient pas en place",
                Dispatch = "Box 4 : homme de 38 ans, douleur lombaire gauche brutale et intense depuis 2 heures.",
                Setting = EmergencySetting.Urgences, Condition = Condition.ColiqueNephretique, AgeMin = 25, AgeMax = 55, Sex = Characters.Sex.Homme,
                Witness = null, PatientTalks = true, Difficulty = 1,
                Initial = () => new PatientState { Hr = 102, Sys = 152, Dia = 90, Spo2 = 98, Rr = 20, Temp = 36.9f, Gcs = 15, Pain = 9f },
                Diagnosis = "colique", Destination = "domicile",
                Teaching = "Colique néphrétique simple : douleur lombaire brutale irradiant vers les organes génitaux, agitation, hématurie, sans fièvre. Traitement : AINS (kétoprofène) en première intention, morphine si besoin. Imagerie pour confirmer. Sans fièvre ni insuffisance rénale, retour à domicile avec antalgiques et filtration des urines. Fièvre = colique compliquée, urgence urologique."
            });
            c.Answers["w_quoi"] = "Une douleur atroce dans le bas du dos à gauche, qui descend vers l'aine. Je n'arrive pas à rester en place !";
            c.Answers["w_quand"] = "Depuis deux heures, d'un coup.";
            c.Answers["w_antecedents"] = "Mon père fait des calculs. Moi, rien.";
            c.Answers["w_traitements"] = "Aucun.";
            c.Answers["w_allergies"] = "Non.";
            c.Answers["w_avant"] = "Il fait chaud, je ne bois pas assez au travail.";
            c.Findings["examen"] = "Patient agité, fosse lombaire gauche sensible, abdomen souple, pas de fièvre.";
            c.Findings["abdomen"] = "Abdomen souple, sensibilité du flanc gauche.";
            c.Results["bu"] = "Hématurie ++, leucocytes et nitrites négatifs.";
            c.Results["bio"] = "Créatinine normale, pas de syndrome inflammatoire.";
            c.Results["scanner_abdo"] = "Calcul de 4 mm de l'uretère gauche, dilatation modérée des cavités, pas de complication.";
            c.Results["echo"] = "Dilatation modérée des cavités rénales gauches.";
            c.Need("AINS IV (kétoprofène)", 0f, "ketoprofene").Weight = 2;
            c.Need("Bandelette urinaire", 0f, "bu");
            c.Need("Imagerie (scanner ou échographie)", 0f, "scanner_abdo", "echo");
            c.KeyExams.UnionWith(new[] { "temperature", "examen" });
            c.Useful.UnionWith(new[] { "morphine", "bio", "vvp" });
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée.";
            c.AcceptableDestinations.Add("uhcd");

            c = Add(new EmergencyCase
            {
                Id = "urg_hemorragie", Title = "Vomissements de sang", Subtitle = "Pâle et tachycarde",
                Dispatch = "Box 5 : homme de 64 ans, a vomi du sang rouge deux fois, selles noires depuis hier.",
                Setting = EmergencySetting.Urgences, Condition = Condition.HemorragieDigestive, AgeMin = 50, AgeMax = 75, Sex = Characters.Sex.Homme,
                Witness = null, PatientTalks = true, Difficulty = 3,
                Initial = () => new PatientState { Hr = 118, Sys = 92, Dia = 58, Spo2 = 97, Rr = 22, Gcs = 15 },
                Diagnosis = "hemorragie", Destination = "reanimation",
                Teaching = "Hémorragie digestive haute (hématémèse, méléna) avec tachycardie et hypotension : deux voies veineuses, remplissage, transfusion si l'hémoglobine est basse et mal tolérée, IPP IV, et endoscopie en urgence. Instabilité hémodynamique = réanimation. Les AINS et anticoagulants sont à proscrire."
            });
            c.Answers["w_quoi"] = "J'ai vomi du sang rouge, deux fois. Et mes selles sont noires depuis hier.";
            c.Answers["w_quand"] = "Depuis hier, et ce matin les vomissements.";
            c.Answers["w_antecedents"] = "Un ulcère il y a dix ans. Je bois pas mal, je l'avoue.";
            c.Answers["w_traitements"] = "Je prends de l'ibuprofène pour mon genou, tous les jours depuis un mois.";
            c.Answers["w_allergies"] = "Non.";
            c.Answers["w_avant"] = "J'avais des brûlures d'estomac.";
            c.Findings["examen"] = "Pâleur cutanéo-muqueuse, extrémités froides. Toucher rectal : méléna.";
            c.Findings["abdomen"] = "Abdomen souple, sensibilité épigastrique.";
            c.Results["bio"] = "Hémoglobine 6,8 g/dL, urée élevée, plaquettes normales, TP normal.";
            c.Results["gaz"] = "Lactates 2,6 mmol/L.";
            c.Results["echo"] = "Pas d'épanchement abdominal.";
            c.Need("Voie veineuse et remplissage", 15f, "remplissage").Weight = 2;
            c.Need("Bilan sanguin (hémoglobine)", 0f, "bio");
            c.Need("Transfusion", 0f, "transfusion").Weight = 2;
            c.Need("IPP IV", 0f, "ipp");
            c.KeyExams.UnionWith(new[] { "scope", "examen" });
            c.Useful.UnionWith(new[] { "gaz", "o2" });
            c.Harmful["aspirine"] = "Faute grave : antiagrégant au cours d'une hémorragie.";
            c.Harmful["heparine"] = "Faute grave : anticoagulant au cours d'une hémorragie.";
            c.Harmful["ketoprofene"] = "Les AINS aggravent le saignement digestif.";
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée.";
            c.AcceptableDestinations.Add("hospitalisation");

            c = Add(new EmergencyCase
            {
                Id = "urg_pneumothorax", Title = "Point de côté brutal", Subtitle = "Jeune homme grand et mince",
                Dispatch = "Box 6 : homme de 22 ans, douleur thoracique droite brutale et essoufflement depuis ce matin.",
                Setting = EmergencySetting.Urgences, Condition = Condition.Pneumothorax, AgeMin = 18, AgeMax = 30, Sex = Characters.Sex.Homme,
                Witness = null, PatientTalks = true, Difficulty = 2,
                Initial = () => new PatientState { Hr = 108, Sys = 124, Dia = 74, Spo2 = 92, Rr = 25, Gcs = 15, Pain = 6f },
                Diagnosis = "pneumothorax", Destination = "hospitalisation",
                Teaching = "Pneumothorax spontané du sujet jeune, grand, mince et fumeur : douleur brutale, dyspnée, abolition du murmure vésiculaire et tympanisme d'un côté. Radiographie de thorax, oxygène, antalgie ; un pneumothorax complet ou mal toléré est exsufflé ou drainé, puis hospitalisation."
            });
            c.Answers["w_quoi"] = "J'ai eu une douleur d'un coup sur le côté droit, comme un coup de couteau, et depuis je suis essoufflé.";
            c.Answers["w_quand"] = "Ce matin en me réveillant.";
            c.Answers["w_antecedents"] = "Rien. Je fume un paquet par jour.";
            c.Answers["w_traitements"] = "Aucun.";
            c.Answers["w_allergies"] = "Non.";
            c.Answers["w_avant"] = "Rien de spécial, je dormais.";
            c.Findings["auscultation"] = "Abolition du murmure vésiculaire à droite, tympanisme à la percussion.";
            c.Findings["examen"] = "Patient longiligne, polypnéique. Hémithorax droit moins mobile.";
            c.Results["radio_thorax"] = "Pneumothorax complet droit, sans déviation médiastinale.";
            c.Results["gaz"] = "Hypoxémie modérée.";
            c.Results["bio"] = "Bilan normal.";
            c.Results["echo"] = "Absence de glissement pleural à droite.";
            c.Need("Auscultation pulmonaire", 0f, "auscultation").Weight = 2;
            c.Need("Radiographie thoracique", 0f, "radio_thorax").Weight = 2;
            c.Need("Exsufflation / drainage", 0f, "exsufflation").Weight = 2;
            c.Need("Oxygène", 0f, "o2");
            c.KeyExams.UnionWith(new[] { "scope" });
            c.Useful.UnionWith(new[] { "paracetamol", "morphine", "echo" });
            c.Harmful["adrenaline_iv"] = "Adrénaline injustifiée.";
            c.AcceptableDestinations.Add("uhcd");
        }
    }
}
