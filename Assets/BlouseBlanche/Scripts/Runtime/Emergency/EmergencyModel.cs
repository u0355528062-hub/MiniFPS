using System.Collections.Generic;

namespace BlouseBlanche.Emergency
{
    public enum EmergencySetting { Samu, Urgences }

    public enum Rhythm { Sinusal, Tachycardie, Bradycardie, FibrillationAtriale, FibrillationVentriculaire, Asystolie }

    public enum Breathing { Normale, Rapide, Lente, Sifflante, Agonique, Absente }

    public enum EmergencyTool
    {
        Bilan, Scope, ECG, Defibrillateur, RCP, Oxygene, Perfusion, Medicaments, Glucometre, Immobilisation, Biologie, Imagerie
    }

    /// <summary>État physiologique vivant du patient.</summary>
    public sealed class PatientState
    {
        public float Hr = 80, Sys = 125, Dia = 75, Spo2 = 97, Rr = 15, Temp = 36.8f, Glyc = 1.0f;
        public int Gcs = 15;
        public float Pain = 0f;
        public Rhythm Rhythm = Rhythm.Sinusal;
        public Breathing Breathing = Breathing.Normale;
        public bool Alive = true;
        public float NoFlowMinutes;
        public float LowFlowMinutes;
        public bool Rosc;

        public bool Pulse => Alive && Rhythm != Rhythm.FibrillationVentriculaire && Rhythm != Rhythm.Asystolie;
        public bool Shockable => Rhythm == Rhythm.FibrillationVentriculaire;

        public string RhythmName
        {
            get
            {
                switch (Rhythm)
                {
                    case Rhythm.Sinusal: return Hr > 100 ? "Tachycardie sinusale" : Hr < 55 ? "Bradycardie sinusale" : "Rythme sinusal";
                    case Rhythm.Tachycardie: return "Tachycardie";
                    case Rhythm.Bradycardie: return "Bradycardie";
                    case Rhythm.FibrillationAtriale: return "Fibrillation atriale";
                    case Rhythm.FibrillationVentriculaire: return "FIBRILLATION VENTRICULAIRE";
                    default: return "ASYSTOLIE";
                }
            }
        }

        public string ConsciousnessLabel
        {
            get
            {
                if (!Alive) return "Décédé";
                if (Gcs >= 15) return "Conscient, orienté";
                if (Gcs >= 13) return "Confus";
                if (Gcs >= 9) return "Somnolent, réagit à la voix";
                if (Gcs >= 6) return "Réagit à la douleur";
                return "Inconscient, aréactif";
            }
        }
    }

    public enum ActionCategory { Bilan, Geste, Medicament, Examen }

    public sealed class EmergencyActionDef
    {
        public string Id, Name, Detail;
        public EmergencyTool Tool;
        public ActionCategory Category;
        public float Minutes;
        public bool NeedsIv;
        public bool Samu = true, Urgences = true;
        /// <summary>Examens différés (biologie, imagerie) : délai avant résultat.</summary>
        public float ResultDelay;
    }

    public sealed class DestinationDef
    {
        public string Id, Name, Detail;
        public bool Samu, Urgences;
    }

    public static class EmergencyCatalog
    {
        public static readonly List<EmergencyActionDef> Actions = new List<EmergencyActionDef>
        {
            // ---------------------------------------------------------------- bilan
            A("conscience", "Évaluer la conscience (Glasgow)", EmergencyTool.Bilan, ActionCategory.Bilan, 0.3f, "Réponse à la voix, à la douleur, ouverture des yeux."),
            A("ventilation", "Évaluer la respiration", EmergencyTool.Bilan, ActionCategory.Bilan, 0.2f, "Regarder, écouter, sentir pendant 10 secondes."),
            A("pouls", "Rechercher un pouls carotidien", EmergencyTool.Bilan, ActionCategory.Bilan, 0.2f, "10 secondes maximum."),
            A("examen", "Examen clinique complet", EmergencyTool.Bilan, ActionCategory.Bilan, 2f, "Tête aux pieds : peau, thorax, abdomen, membres."),
            A("pupilles", "Examiner les pupilles", EmergencyTool.Bilan, ActionCategory.Bilan, 0.2f, "Taille, symétrie, réactivité."),
            A("auscultation", "Ausculter cœur et poumons", EmergencyTool.Bilan, ActionCategory.Bilan, 1f, "Stéthoscope."),
            A("abdomen", "Palper l'abdomen", EmergencyTool.Bilan, ActionCategory.Bilan, 1f, "Défense, contracture, point douloureux."),
            A("temperature", "Prendre la température", EmergencyTool.Bilan, ActionCategory.Bilan, 0.5f, "Thermomètre tympanique."),
            // ---------------------------------------------------------------- monitorage
            A("scope", "Brancher le scope multiparamétrique", EmergencyTool.Scope, ActionCategory.Bilan, 1f, "FC, SpO2, pression, fréquence respiratoire en continu."),
            A("ecg", "ECG 12 dérivations", EmergencyTool.ECG, ActionCategory.Examen, 3f, "Recherche d'un sus-décalage ST, d'un trouble du rythme."),
            A("glycemie", "Glycémie capillaire", EmergencyTool.Glucometre, ActionCategory.Examen, 0.8f, "Une goutte au bout du doigt."),
            // ---------------------------------------------------------------- gestes vitaux
            A("rcp", "Massage cardiaque (RCP) : démarrer / arrêter", EmergencyTool.RCP, ActionCategory.Geste, 0.1f, "100 à 120 compressions par minute."),
            A("choc", "Analyser et délivrer un choc électrique", EmergencyTool.Defibrillateur, ActionCategory.Geste, 0.3f, "Défibrillateur : uniquement sur un rythme choquable."),
            A("o2", "Oxygène au masque haute concentration", EmergencyTool.Oxygene, ActionCategory.Geste, 0.3f, "15 L/min."),
            A("bavu", "Ventiler au ballon (BAVU)", EmergencyTool.Oxygene, ActionCategory.Geste, 0.5f, "Quand la respiration est absente ou insuffisante."),
            A("pls", "Position latérale de sécurité", EmergencyTool.Bilan, ActionCategory.Geste, 0.5f, "Patient inconscient qui respire."),
            A("vvp", "Poser une voie veineuse", EmergencyTool.Perfusion, ActionCategory.Geste, 2f, "Indispensable avant les médicaments intraveineux."),
            A("remplissage", "Remplissage vasculaire (500 mL)", EmergencyTool.Perfusion, ActionCategory.Geste, 1f, "Sérum physiologique.", true),
            A("transfusion", "Transfusion de culots globulaires", EmergencyTool.Perfusion, ActionCategory.Geste, 3f, "Si anémie mal tolérée.", true, false),
            A("collier", "Collier cervical", EmergencyTool.Immobilisation, ActionCategory.Geste, 1f, "Suspicion de traumatisme du rachis."),
            A("matelas", "Matelas immobilisateur à dépression", EmergencyTool.Immobilisation, ActionCategory.Geste, 3f, "Immobilisation complète pour le transport.", false, true, false),
            A("attelle", "Attelle d'immobilisation", EmergencyTool.Immobilisation, ActionCategory.Geste, 2f, "Membre traumatisé."),
            A("exsufflation", "Exsufflation / drainage thoracique", EmergencyTool.Immobilisation, ActionCategory.Geste, 5f, "Évacuer un pneumothorax compressif ou mal toléré.", false, false),
            // ---------------------------------------------------------------- médicaments
            M("adrenaline_iv", "Adrénaline 1 mg IV (arrêt cardiaque)", true, "Toutes les 4 minutes pendant la réanimation."),
            M("adrenaline_im", "Adrénaline 0,5 mg IM (anaphylaxie)", false, "Face antéro-latérale de la cuisse."),
            M("amiodarone", "Amiodarone 300 mg IV", true, "Après le 3e choc inefficace."),
            M("aspirine", "Aspirine 250 mg IV", true, "Syndrome coronarien aigu."),
            M("heparine", "Héparine IV", true, "Anticoagulation."),
            M("morphine", "Morphine titrée IV", true, "Douleur intense."),
            M("ketoprofene", "Kétoprofène IV (AINS)", true, "Colique néphrétique."),
            M("paracetamol", "Paracétamol 1 g IV", true, "Douleur, fièvre."),
            M("glucose", "Glucose 30 % IV (G30)", true, "Hypoglycémie."),
            M("glucagon", "Glucagon 1 mg IM", false, "Hypoglycémie sans voie veineuse."),
            M("naloxone", "Naloxone (antidote des opiacés)", false, "IV, IM ou intranasal."),
            M("salbutamol", "Salbutamol en nébulisation", false, "Bronchospasme."),
            M("corticoide", "Méthylprednisolone IV", true, "Corticoïde."),
            M("trinitrine", "Trinitrine (spray)", false, "Vasodilatateur."),
            M("antibio", "Antibiothérapie IV (céphalosporine)", true, "Sepsis : dans l'heure."),
            M("ipp", "IPP IV (oméprazole)", true, "Hémorragie digestive haute."),
            // ---------------------------------------------------------------- examens hospitaliers
            L("bio", "Bilan sanguin complet", EmergencyTool.Biologie, 25f, "NFS, ionogramme, créatinine, CRP, troponine, D-dimères, lactates."),
            L("gaz", "Gaz du sang artériel", EmergencyTool.Biologie, 8f, "Oxygénation, acidose, lactates."),
            L("hemocultures", "Hémocultures", EmergencyTool.Biologie, 2f, "Avant les antibiotiques."),
            L("bu", "Bandelette urinaire", EmergencyTool.Biologie, 3f, "Leucocytes, nitrites, sang."),
            L("radio_thorax", "Radiographie thoracique", EmergencyTool.Imagerie, 18f, "Au lit du patient."),
            L("echo", "Échographie au lit (abdomen, FAST)", EmergencyTool.Imagerie, 8f, "Réalisée par l'urgentiste."),
            L("scanner_abdo", "Scanner abdomino-pelvien", EmergencyTool.Imagerie, 40f, "Avec injection."),
            L("angioscanner", "Angioscanner thoracique", EmergencyTool.Imagerie, 40f, "Recherche d'embolie pulmonaire."),
            L("scanner_cerebral", "Scanner cérébral", EmergencyTool.Imagerie, 30f, "Sans injection."),
        };

        public static readonly List<DestinationDef> Destinations = new List<DestinationDef>
        {
            Dst("sur_place", "Laisser sur place", "Soins réalisés, patient confié à l'entourage avec consignes.", true, false),
            Dst("urgences", "Transport aux urgences", "Admission au service d'accueil des urgences.", true, false),
            Dst("coronarographie", "Salle de coronarographie", "Angioplastie en urgence (cardiologie interventionnelle).", true, true),
            Dst("unv", "Unité neurovasculaire", "Thrombolyse / thrombectomie.", true, true),
            Dst("reanimation", "Réanimation", "Défaillance vitale.", true, true),
            Dst("bloc", "Chirurgie / bloc opératoire", "Intervention chirurgicale urgente.", true, true),
            Dst("hospitalisation", "Hospitalisation en médecine", "Service conventionnel.", false, true),
            Dst("uhcd", "Surveillance courte (UHCD)", "Quelques heures d'observation aux urgences.", false, true),
            Dst("domicile", "Retour à domicile", "Avec ordonnance et consignes.", false, true),
        };

        static readonly Dictionary<string, EmergencyActionDef> index = new Dictionary<string, EmergencyActionDef>();
        static EmergencyCatalog() { foreach (var a in Actions) index[a.Id] = a; }

        public static EmergencyActionDef Action(string id) => index.TryGetValue(id, out var a) ? a : null;
        public static string ActionName(string id) => Action(id)?.Name ?? id;

        public static string DestinationName(string id)
        {
            foreach (var d in Destinations) if (d.Id == id) return d.Name;
            return id;
        }

        public static List<EmergencyActionDef> ForTool(EmergencyTool tool, EmergencySetting setting)
        {
            var l = new List<EmergencyActionDef>();
            foreach (var a in Actions)
                if (a.Tool == tool && (setting == EmergencySetting.Samu ? a.Samu : a.Urgences)) l.Add(a);
            return l;
        }

        public static bool ToolAvailable(EmergencyTool t, EmergencySetting s) => ForTool(t, s).Count > 0;

        public static string ToolName(EmergencyTool t)
        {
            switch (t)
            {
                case EmergencyTool.Bilan: return "Bilan clinique";
                case EmergencyTool.Scope: return "Scope";
                case EmergencyTool.ECG: return "ECG 12 dérivations";
                case EmergencyTool.Defibrillateur: return "Défibrillateur";
                case EmergencyTool.RCP: return "Massage cardiaque";
                case EmergencyTool.Oxygene: return "Oxygène & ventilation";
                case EmergencyTool.Perfusion: return "Perfusion";
                case EmergencyTool.Medicaments: return "Médicaments";
                case EmergencyTool.Glucometre: return "Glucomètre";
                case EmergencyTool.Immobilisation: return "Gestes techniques";
                case EmergencyTool.Biologie: return "Biologie";
                default: return "Imagerie";
            }
        }

        public static string ToolDescription(EmergencyTool t)
        {
            switch (t)
            {
                case EmergencyTool.Bilan: return "Conscience, respiration, pouls, examen clinique, PLS.";
                case EmergencyTool.Scope: return "Surveillance continue des constantes et du rythme.";
                case EmergencyTool.ECG: return "Tracé 12 dérivations interprété.";
                case EmergencyTool.Defibrillateur: return "Analyse du rythme et choc électrique externe.";
                case EmergencyTool.RCP: return "Compressions thoraciques à 100-120/min.";
                case EmergencyTool.Oxygene: return "Masque haute concentration, ballon autoremplisseur.";
                case EmergencyTool.Perfusion: return "Voie veineuse, remplissage, transfusion.";
                case EmergencyTool.Medicaments: return "Pharmacie d'urgence (adrénaline, antidotes, antalgiques…).";
                case EmergencyTool.Glucometre: return "Glycémie capillaire en une minute.";
                case EmergencyTool.Immobilisation: return "Collier cervical, attelle, matelas, exsufflation.";
                case EmergencyTool.Biologie: return "Prise de sang, gaz du sang, bandelette : résultats différés.";
                default: return "Radiographie, échographie, scanner : résultats différés.";
            }
        }

        static EmergencyActionDef A(string id, string name, EmergencyTool tool, ActionCategory cat, float min, string detail, bool iv = false, bool samu = true, bool urg = true)
            => new EmergencyActionDef { Id = id, Name = name, Tool = tool, Category = cat, Minutes = min, Detail = detail, NeedsIv = iv, Samu = samu, Urgences = urg };
        static EmergencyActionDef M(string id, string name, bool iv, string detail)
            => new EmergencyActionDef { Id = id, Name = name, Tool = EmergencyTool.Medicaments, Category = ActionCategory.Medicament, Minutes = 0.5f, NeedsIv = iv, Detail = detail };
        static EmergencyActionDef L(string id, string name, EmergencyTool tool, float delay, string detail)
            => new EmergencyActionDef { Id = id, Name = name, Tool = tool, Category = ActionCategory.Examen, Minutes = 1f, ResultDelay = delay, Detail = detail, Samu = false, Urgences = true };
        static DestinationDef Dst(string id, string name, string detail, bool samu, bool urg)
            => new DestinationDef { Id = id, Name = name, Detail = detail, Samu = samu, Urgences = urg };
    }
}
