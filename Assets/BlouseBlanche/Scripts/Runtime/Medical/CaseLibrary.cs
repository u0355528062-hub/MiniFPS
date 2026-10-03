using System.Collections.Generic;
using BlouseBlanche.Characters;

namespace BlouseBlanche.Medical
{
    /// <summary>
    /// Bibliothèque de cas cliniques de médecine générale.
    /// Contenu pédagogique de jeu : ne remplace pas un avis médical.
    /// </summary>
    public static class CaseLibrary
    {
        static readonly Dictionary<string, CaseDef> cases = new Dictionary<string, CaseDef>();

        public static CaseDef Get(string id) => cases.TryGetValue(id, out var c) ? c : null;
        public static IEnumerable<CaseDef> All => cases.Values;

        /// <summary>Cas utilisables pour les journées générées (hors urgences vitales).</summary>
        public static readonly string[] RoutinePool =
        {
            "hta_suivi", "angine_strepto", "angine_virale", "gastro_enfant", "lombalgie", "cystite", "grippe",
            "migraine", "otite_enfant", "diabete_deseq", "entorse", "asthme", "pneumopathie", "conjonctivite",
            "rhino_enfant", "bronchite"
        };
        public static readonly string[] UrgentPool = { "sca", "avc" };

        static Finding F(string t, Severity s = Severity.Normal) => new Finding(t, s);
        static void Add(CaseDef c) => cases[c.Id] = c;

        static CaseLibrary()
        {
            // ---------------------------------------------------------------- HTA
            var c = new CaseDef
            {
                Id = "hta_suivi", Title = "Suivi d'hypertension", Motif = "Renouvellement d'ordonnance",
                Opening = "Bonjour docteur ! Je viens pour renouveler mon traitement pour la tension, comme tous les trois mois.",
                AgeMin = 55, AgeMax = 78, Pose = PatientPose.Neutre,
                History = new[] { "Hypertension artérielle depuis 8 ans", "Ancien fumeur (sevré depuis 10 ans)" },
                Meds = new[] { "Amlodipine 5 mg, 1 cp le matin" },
                Vitals = new VitalsSpec { Sys = 132, Dia = 82, Hr = 68, Temp = 36.7f },
                Diagnosis = "hta_eq", Orientation = Orientation.DomicileSuivi, IdealMinutes = 10,
                Teaching = "L'hypertension est considérée comme contrôlée si la pression mesurée au cabinet est inférieure à 140/90 mmHg (à confirmer par automesure). On renouvelle le traitement bien toléré, on prévoit un bilan biologique annuel (créatinine, kaliémie, glycémie, lipides) et on entretient les règles hygiéno-diététiques. Attention aux AINS, qui font monter la tension et abîment les reins."
            };
            c.Answers["q_debut"] = "Je suis traité depuis huit ans. Je n'ai rien de nouveau, je viens surtout pour l'ordonnance.";
            c.Answers["q_general"] = "Je me sens bien, pas de fatigue particulière. Le médicament ne me gêne pas.";
            c.Answers["q_neuro"] = "Non, pas de maux de tête, pas de vertiges.";
            c.Answers["q_respi"] = "Non, je monte mes deux étages sans problème.";
            c.Answers["q_habitudes"] = "J'ai arrêté de fumer il y a dix ans. Un verre de vin le dimanche, pas plus.";
            c.Answers["q_localisation"] = "Je n'ai mal nulle part, docteur.";
            c.Answers["q_facteurs"] = "Je fais attention au sel, ma femme y veille !";
            c.Findings["ex_coeur"] = F("Bruits du cœur réguliers, sans souffle.");
            c.KeyQuestions.UnionWith(new[] { "q_traitements", "q_general" });
            c.KeyExams.UnionWith(new[] { "ex_ta" });
            c.UsefulExams.UnionWith(new[] { "ex_coeur", "ex_poids" });
            c.RequiredTx.Add(new[] { "renouv_hta" });
            c.RecommendedTx.UnionWith(new[] { "bio", "hygieno_diet" });
            c.AcceptableTx.UnionWith(new[] { "activite", "surveillance" });
            c.HarmfulTx["ibuprofene"] = "Les AINS augmentent la tension artérielle et peuvent abîmer les reins.";
            c.AcceptableOrientations.Add(Orientation.Domicile);
            Add(c);

            // ---------------------------------------------------------------- Angine à streptocoque
            c = new CaseDef
            {
                Id = "angine_strepto", Title = "Angine à streptocoque", Motif = "Mal de gorge, fièvre",
                Opening = "Bonjour… J'ai très mal à la gorge depuis deux jours, j'ai du mal à avaler.",
                AgeMin = 16, AgeMax = 40, Pose = PatientPose.Fatigue,
                Vitals = new VitalsSpec { Temp = 38.6f, Hr = 96, Sys = 118, Dia = 72 },
                Diagnosis = "angine_strepto", Orientation = Orientation.Domicile, IdealMinutes = 12,
                Teaching = "Devant une angine de l'adulte, on calcule le score de McIsaac : fièvre > 38 °C, absence de toux, ganglions cervicaux sensibles, amygdales augmentées ou exsudat, âge. Score ≥ 2 → TROD. TROD positif = angine à streptocoque A, traitée par amoxicilline pendant 6 jours (après avoir vérifié l'absence d'allergie). TROD négatif = angine virale, pas d'antibiotique."
            };
            c.Answers["q_debut"] = "Depuis avant-hier, c'est venu assez vite.";
            c.Answers["q_fievre"] = "Oui, j'avais 38,8 hier soir, avec des frissons.";
            c.Answers["q_respi"] = "Non, je ne tousse pas du tout, et je n'ai pas le nez qui coule.";
            c.Answers["q_localisation"] = "La gorge, surtout quand j'avale.";
            c.Answers["q_intensite"] = "Je dirais 6 sur 10, et 8 quand je déglutis.";
            c.Answers["q_entourage"] = "Ma collègue a eu une angine la semaine dernière.";
            c.Answers["q_travail"] = "Je suis serveuse dans un restaurant.";
            c.Findings["ex_gorge"] = F("Amygdales augmentées de volume, très rouges, avec un exsudat blanchâtre.", Severity.Attention);
            c.Findings["ex_ganglions"] = F("Ganglions cervicaux antérieurs augmentés de volume et sensibles.", Severity.Attention);
            c.Findings["ex_trod"] = F("TROD streptocoque A : POSITIF.", Severity.Attention);
            c.KeyQuestions.UnionWith(new[] { "q_fievre", "q_respi", "q_allergies" });
            c.KeyExams.UnionWith(new[] { "ex_gorge", "ex_trod" });
            c.UsefulExams.UnionWith(new[] { "ex_temp", "ex_ganglions", "ex_otoscopie" });
            c.RequiredTx.Add(new[] { "amoxicilline" });
            c.RecommendedTx.UnionWith(new[] { "paracetamol" });
            c.AcceptableTx.UnionWith(new[] { "arret", "repos", "surveillance" });
            c.HarmfulTx["ibuprofene"] = "Les AINS sont déconseillés dans les infections ORL bactériennes (risque de complications).";
            c.DiscouragedTx["azithromycine"] = "Les macrolides sont réservés aux patients allergiques à la pénicilline.";
            c.DiscouragedTx["amox_clav"] = "Spectre trop large : l'amoxicilline seule suffit contre le streptocoque.";
            Add(c);

            // ---------------------------------------------------------------- Angine virale
            c = new CaseDef
            {
                Id = "angine_virale", Title = "Angine virale", Motif = "Mal de gorge",
                Opening = "Bonjour docteur, j'ai mal à la gorge depuis hier et le nez qui coule.",
                AgeMin = 16, AgeMax = 50, Pose = PatientPose.Fatigue,
                Vitals = new VitalsSpec { Temp = 37.9f },
                Diagnosis = "angine_virale", Orientation = Orientation.Domicile, IdealMinutes = 10,
                Teaching = "Toux, rhinorrhée et TROD négatif orientent vers une angine virale : c'est le cas de la grande majorité des angines. Aucun antibiotique n'est utile ; on soulage par du paracétamol. Prescrire un antibiotique inutile expose aux effets indésirables et favorise l'antibiorésistance."
            };
            c.Answers["q_debut"] = "Depuis hier matin.";
            c.Answers["q_fievre"] = "Un peu, 37,9 hier soir.";
            c.Answers["q_respi"] = "Oui, je tousse un peu et j'ai le nez bouché.";
            c.Answers["q_localisation"] = "La gorge, ça gratte.";
            c.Answers["q_entourage"] = "Mes enfants sont enrhumés.";
            c.Findings["ex_gorge"] = F("Gorge rouge de façon diffuse, sans exsudat.");
            c.Findings["ex_trod"] = F("TROD streptocoque A : négatif.");
            c.KeyQuestions.UnionWith(new[] { "q_fievre", "q_respi" });
            c.KeyExams.UnionWith(new[] { "ex_gorge", "ex_trod" });
            c.UsefulExams.UnionWith(new[] { "ex_temp", "ex_ganglions" });
            c.PartialDiagnoses.Add("rhino");
            c.RequiredTx.Add(new[] { "paracetamol" });
            c.AcceptableTx.UnionWith(new[] { "repos", "surveillance", "serum_phy", "hygiene" });
            c.HarmfulTx["amoxicilline"] = "Antibiotique inutile : le TROD est négatif, l'angine est virale (antibiorésistance).";
            c.HarmfulTx["azithromycine"] = "Antibiotique inutile : l'angine est virale.";
            c.HarmfulTx["amox_clav"] = "Antibiotique inutile : l'angine est virale.";
            Add(c);

            // ---------------------------------------------------------------- Angine + allergie pénicilline
            c = new CaseDef
            {
                Id = "angine_allergie", Title = "Angine à streptocoque chez une allergique", Motif = "Mal de gorge intense",
                Opening = "Bonjour docteur. J'ai la gorge en feu et de la fièvre depuis hier.",
                AgeMin = 17, AgeMax = 30, Sex = Characters.Sex.Femme, Pose = PatientPose.Fatigue,
                Allergies = new[] { "Pénicilline (urticaire géante en 2019)" },
                Vitals = new VitalsSpec { Temp = 38.9f, Hr = 100 },
                Diagnosis = "angine_strepto", Orientation = Orientation.Domicile, IdealMinutes = 12,
                Teaching = "Toujours vérifier les allergies avant de prescrire ! En cas d'allergie immédiate à la pénicilline (urticaire, œdème), les bêtalactamines sont contre-indiquées : on traite l'angine à streptocoque par un macrolide comme l'azithromycine (3 jours)."
            };
            c.Answers["q_debut"] = "Depuis hier, c'est arrivé brutalement.";
            c.Answers["q_fievre"] = "39 ce matin, avec des frissons.";
            c.Answers["q_respi"] = "Non, aucune toux.";
            c.Answers["q_localisation"] = "Toute la gorge, et ça tire jusqu'aux oreilles quand j'avale.";
            c.Answers["q_allergies"] = "Oui ! Je suis allergique à la pénicilline : j'avais fait une énorme crise d'urticaire.";
            c.Findings["ex_gorge"] = F("Amygdales rouges et augmentées de volume, recouvertes d'un enduit blanchâtre.", Severity.Attention);
            c.Findings["ex_ganglions"] = F("Adénopathies cervicales sensibles des deux côtés.", Severity.Attention);
            c.Findings["ex_trod"] = F("TROD streptocoque A : POSITIF.", Severity.Attention);
            c.KeyQuestions.UnionWith(new[] { "q_allergies", "q_respi", "q_fievre" });
            c.KeyExams.UnionWith(new[] { "ex_gorge", "ex_trod" });
            c.UsefulExams.UnionWith(new[] { "ex_temp", "ex_ganglions" });
            c.RequiredTx.Add(new[] { "azithromycine" });
            c.RecommendedTx.Add("paracetamol");
            c.AcceptableTx.UnionWith(new[] { "repos", "arret", "surveillance" });
            c.HarmfulTx["amoxicilline"] = "FAUTE GRAVE : la patiente est allergique à la pénicilline (risque de choc anaphylactique).";
            c.HarmfulTx["amox_clav"] = "FAUTE GRAVE : contient de l'amoxicilline, la patiente est allergique.";
            c.HarmfulTx["ibuprofene"] = "Les AINS sont déconseillés dans les angines bactériennes.";
            Add(c);

            // ---------------------------------------------------------------- Gastro-entérite de l'enfant
            c = new CaseDef
            {
                Id = "gastro_enfant", Title = "Gastro-entérite de l'enfant", Motif = "Vomissements, diarrhée",
                Opening = "Bonjour docteur. Il vomit depuis cette nuit et il a la diarrhée depuis ce matin.",
                AgeMin = 4, AgeMax = 9, Companion = "sa mère", Pose = PatientPose.Ventre,
                Vitals = new VitalsSpec { Temp = 38.1f, Hr = 104 },
                Diagnosis = "gastro", Orientation = Orientation.DomicileSuivi, IdealMinutes = 12,
                Teaching = "La gastro-entérite de l'enfant est presque toujours virale. Le danger, c'est la déshydratation : on la recherche (poids, muqueuses, comportement). Le traitement repose sur le soluté de réhydratation orale, en petites quantités très fréquentes. Pas d'antibiotique, pas d'antidiarrhéique. Reconsulter si refus de boire, somnolence, sang dans les selles ou perte de poids."
            };
            c.Answers["q_debut"] = "Depuis cette nuit, vers 3 heures. Il a vomi quatre fois, puis trois selles liquides ce matin.";
            c.Answers["q_fievre"] = "Il avait 38,2 ce matin.";
            c.Answers["q_localisation"] = "Il dit qu'il a mal autour du nombril, par moments.";
            c.Answers["q_digestif"] = "Vomissements et diarrhée liquide. Pas de sang dans les selles.";
            c.Answers["q_entourage"] = "Plusieurs enfants de sa classe ont eu la même chose cette semaine.";
            c.Answers["q_general"] = "Il est fatigué mais il joue un peu. Il boit par petites gorgées.";
            c.Answers["q_urinaire"] = "Il a fait pipi ce matin, normalement.";
            c.Findings["ex_palp_abdo"] = F("Abdomen souple, légèrement sensible autour du nombril, sans défense. Bruits intestinaux augmentés.");
            c.Findings["ex_peau"] = F("Pas de pli cutané persistant. Muqueuses discrètement sèches.", Severity.Attention);
            c.Findings["ex_poids"] = F("Poids 23,0 kg : identique à la dernière pesée du carnet de santé (pas de perte de poids).");
            c.KeyQuestions.UnionWith(new[] { "q_digestif", "q_general", "q_urinaire" });
            c.KeyExams.UnionWith(new[] { "ex_palp_abdo", "ex_poids" });
            c.UsefulExams.UnionWith(new[] { "ex_temp", "ex_peau" });
            c.RequiredTx.Add(new[] { "sro" });
            c.RecommendedTx.UnionWith(new[] { "paracetamol", "surveillance", "hygiene" });
            c.AcceptableTx.Add("repos");
            c.HarmfulTx["loperamide"] = "Les antidiarrhéiques comme le lopéramide ne sont pas recommandés chez l'enfant.";
            c.HarmfulTx["amoxicilline"] = "Antibiotique inutile : la gastro-entérite est virale.";
            c.DiscouragedTx["ibuprofene"] = "AINS déconseillés en cas de risque de déshydratation (risque pour les reins).";
            c.AcceptableOrientations.Add(Orientation.Domicile);
            Add(c);

            // ---------------------------------------------------------------- Lombalgie
            c = new CaseDef
            {
                Id = "lombalgie", Title = "Lombalgie aiguë", Motif = "Mal de dos",
                Opening = "Docteur, j'ai un mal de dos terrible depuis que j'ai porté des cartons ce week-end.",
                AgeMin = 25, AgeMax = 55, Sex = Characters.Sex.Homme, Pose = PatientPose.Dos,
                Diagnosis = "lombalgie", Orientation = Orientation.Domicile, IdealMinutes = 12,
                Teaching = "La lombalgie commune aiguë guérit en quelques semaines dans 90 % des cas. On recherche les drapeaux rouges : fièvre, déficit neurologique, troubles urinaires, traumatisme violent, antécédent de cancer, amaigrissement. En leur absence : pas d'imagerie, antalgiques simples, et surtout maintien des activités (le repos au lit retarde la guérison)."
            };
            c.Answers["q_debut"] = "Samedi, en portant des cartons pour un déménagement. C'est arrivé d'un coup.";
            c.Answers["q_localisation"] = "En bas du dos, au milieu.";
            c.Answers["q_irradiation"] = "Non, ça ne descend pas dans les jambes.";
            c.Answers["q_intensite"] = "6 sur 10. 8 quand je me penche.";
            c.Answers["q_facteurs"] = "Ça va mieux allongé, c'est pire quand je me baisse.";
            c.Answers["q_urinaire"] = "Non, aucun problème pour uriner.";
            c.Answers["q_neuro"] = "Non, pas de fourmillements, pas de faiblesse dans les jambes.";
            c.Answers["q_travail"] = "Je suis magasinier, je porte des charges toute la journée.";
            c.Answers["q_general"] = "Non, pas de perte de poids, je mange bien.";
            c.Findings["ex_rachis"] = F("Contracture des muscles lombaires, raideur à la flexion. Lasègue négatif des deux côtés.", Severity.Attention);
            c.Findings["ex_neuro"] = F("Force, sensibilité et réflexes normaux aux membres inférieurs.");
            c.KeyQuestions.UnionWith(new[] { "q_irradiation", "q_urinaire", "q_neuro", "q_fievre" });
            c.KeyExams.UnionWith(new[] { "ex_rachis", "ex_neuro" });
            c.UsefulExams.Add("ex_temp");
            c.RequiredTx.Add(new[] { "paracetamol", "ibuprofene" });
            c.RecommendedTx.UnionWith(new[] { "activite" });
            c.AcceptableTx.UnionWith(new[] { "paracetamol", "ibuprofene", "arret", "surveillance" });
            c.DiscouragedTx["radio_rachis"] = "Pas d'imagerie dans une lombalgie aiguë sans drapeau rouge.";
            c.DiscouragedTx["repos"] = "Le repos au lit retarde la guérison : il faut maintenir l'activité.";
            c.DiscouragedTx["tramadol"] = "Les opioïdes ne sont pas recommandés en première intention.";
            c.PartialDiagnoses.Add("sciatique");
            Add(c);

            // ---------------------------------------------------------------- Syndrome coronarien aigu
            c = new CaseDef
            {
                Id = "sca", Title = "Infarctus du myocarde", Motif = "Douleur thoracique",
                Opening = "Docteur… j'ai une douleur dans la poitrine, ça serre très fort… depuis 40 minutes…",
                AgeMin = 52, AgeMax = 68, Sex = Characters.Sex.Homme, Urgency = Urgency.Vitale, Pose = PatientPose.Poitrine,
                History = new[] { "Diabète de type 2", "Hypercholestérolémie", "Tabagisme actif (30 paquets-années)" },
                Meds = new[] { "Metformine 1000 mg matin et soir" },
                Vitals = new VitalsSpec { Sys = 150, Dia = 95, Hr = 98, Spo2 = 95 },
                Diagnosis = "sca", Orientation = Orientation.Urgences15, IdealMinutes = 8, DeteriorationMinutes = 20f, PatienceMinutes = 200f,
                Teaching = "Douleur thoracique constrictive de plus de 20 minutes, irradiant au bras gauche ou à la mâchoire, chez un patient à risque : c'est un syndrome coronarien aigu jusqu'à preuve du contraire. Appel immédiat du 15 ; l'ECG (sus-décalage du segment ST) ne doit pas retarder l'appel. Le SAMU organise l'angioplastie en urgence : « time is muscle »."
            };
            c.Answers["q_debut"] = "Ça a commencé il y a 40 minutes, au repos, en buvant mon café.";
            c.Answers["q_localisation"] = "Au milieu de la poitrine, comme un étau.";
            c.Answers["q_irradiation"] = "Ça part dans le bras gauche… et dans la mâchoire.";
            c.Answers["q_intensite"] = "8 sur 10. Je n'ai jamais eu aussi mal.";
            c.Answers["q_respi"] = "J'ai un peu de mal à respirer.";
            c.Answers["q_facteurs"] = "Rien ne soulage, même immobile.";
            c.Answers["q_habitudes"] = "Je fume un paquet par jour depuis trente ans.";
            c.Answers["q_general"] = "J'ai des sueurs et je me sens très mal.";
            c.Findings["ex_ecg"] = F("Sus-décalage du segment ST en DII, DIII et aVF (territoire inférieur), avec image en miroir en antérieur.", Severity.Critique);
            c.Findings["ex_coeur"] = F("Bruits du cœur réguliers et rapides, sans souffle.");
            c.Findings["ex_poumons"] = F("Auscultation pulmonaire normale.");
            c.KeyQuestions.UnionWith(new[] { "q_debut", "q_irradiation" });
            c.KeyExams.UnionWith(new[] { "ex_ecg" });
            c.UsefulExams.UnionWith(new[] { "ex_ta", "ex_spo2" });
            c.RecommendedTx.Add("aspirine");
            c.HarmfulTx["ibuprofene"] = "Les AINS sont dangereux en cas d'infarctus.";
            c.HarmfulTx["tramadol"] = "Un antalgique ne traite pas l'infarctus et retarde la prise en charge.";
            Add(c);

            // ---------------------------------------------------------------- Cystite
            c = new CaseDef
            {
                Id = "cystite", Title = "Cystite aiguë simple", Motif = "Brûlures urinaires",
                Opening = "Bonjour docteur, ça me brûle quand je fais pipi depuis hier, et j'ai envie tout le temps.",
                AgeMin = 20, AgeMax = 45, Sex = Characters.Sex.Femme, Pose = PatientPose.Ventre,
                Vitals = new VitalsSpec { Temp = 36.9f },
                Diagnosis = "cystite", Orientation = Orientation.Domicile, IdealMinutes = 10,
                Teaching = "Cystite simple : femme sans facteur de risque de complication, sans fièvre ni douleur lombaire. La bandelette urinaire (leucocytes + nitrites) suffit : traitement par fosfomycine-trométamol en dose unique, sans ECBU. Les fluoroquinolones ne sont plus recommandées en première intention. Reconsulter en cas de fièvre ou de douleur dans le dos (pyélonéphrite)."
            };
            c.Answers["q_debut"] = "Depuis hier matin.";
            c.Answers["q_urinaire"] = "Oui, ça brûle, et je vais aux toilettes toutes les heures pour quelques gouttes.";
            c.Answers["q_fievre"] = "Non, pas de fièvre.";
            c.Answers["q_localisation"] = "Un peu en bas du ventre.";
            c.Answers["q_irradiation"] = "Non, je n'ai pas mal dans le dos.";
            c.Answers["q_grossesse"] = "Non, je prends la pilule.";
            c.Answers["q_antecedents"] = "J'ai eu une cystite il y a deux ans, c'est tout.";
            c.Findings["ex_bu"] = F("Bandelette urinaire : leucocytes +++, nitrites +.", Severity.Attention);
            c.Findings["ex_fosses"] = F("Fosses lombaires indolores à la percussion.");
            c.Findings["ex_palp_abdo"] = F("Légère sensibilité sus-pubienne, abdomen souple.");
            c.KeyQuestions.UnionWith(new[] { "q_urinaire", "q_fievre", "q_grossesse" });
            c.KeyExams.UnionWith(new[] { "ex_bu" });
            c.UsefulExams.UnionWith(new[] { "ex_temp", "ex_fosses", "ex_palp_abdo" });
            c.RequiredTx.Add(new[] { "fosfomycine" });
            c.RecommendedTx.Add("surveillance");
            c.AcceptableTx.UnionWith(new[] { "paracetamol", "repos" });
            c.HarmfulTx["fluoroquinolone"] = "Fluoroquinolones déconseillées dans la cystite simple (effets indésirables, résistances).";
            c.DiscouragedTx["ecbu"] = "Pas d'ECBU dans une cystite simple : la bandelette suffit.";
            c.DiscouragedTx["amoxicilline"] = "L'amoxicilline est inadaptée (E. coli souvent résistant).";
            c.PartialDiagnoses.Add("pyelo");
            Add(c);

            // ---------------------------------------------------------------- Grippe
            c = new CaseDef
            {
                Id = "grippe", Title = "Syndrome grippal", Motif = "Fièvre, courbatures",
                Opening = "Bonjour… J'ai de la fièvre depuis hier, des courbatures partout, je suis complètement K.O.",
                AgeMin = 20, AgeMax = 55, Pose = PatientPose.Toux, Cough = true,
                Vitals = new VitalsSpec { Temp = 39.1f, Hr = 102 },
                Diagnosis = "grippe", Orientation = Orientation.Domicile, IdealMinutes = 10,
                Teaching = "Le syndrome grippal associe fièvre brutale, courbatures, maux de tête et toux sèche, en contexte épidémique. Le traitement est symptomatique : paracétamol, repos, hydratation, arrêt de travail si besoin. Les antibiotiques sont inutiles. On surveille les signes de gravité : essoufflement, douleur thoracique, confusion."
            };
            c.Answers["q_debut"] = "Hier après-midi, d'un coup.";
            c.Answers["q_fievre"] = "39,4 cette nuit, avec des frissons.";
            c.Answers["q_respi"] = "Une toux sèche, mais je respire bien.";
            c.Answers["q_localisation"] = "J'ai mal partout : les muscles, le dos, la tête.";
            c.Answers["q_entourage"] = "La moitié du bureau est malade en ce moment.";
            c.Answers["q_travail"] = "Je suis comptable.";
            c.Answers["q_neuro"] = "Mal à la tête, mais je vois bien et je parle normalement.";
            c.Findings["ex_poumons"] = F("Murmure vésiculaire symétrique, pas de crépitants.");
            c.Findings["ex_gorge"] = F("Gorge discrètement rouge, sans exsudat.");
            c.KeyQuestions.UnionWith(new[] { "q_fievre", "q_respi", "q_entourage" });
            c.KeyExams.UnionWith(new[] { "ex_temp", "ex_poumons" });
            c.UsefulExams.UnionWith(new[] { "ex_spo2", "ex_gorge" });
            c.RequiredTx.Add(new[] { "paracetamol" });
            c.RecommendedTx.UnionWith(new[] { "repos", "arret", "hygiene" });
            c.AcceptableTx.Add("surveillance");
            c.HarmfulTx["amoxicilline"] = "Antibiotique inutile : la grippe est virale.";
            c.HarmfulTx["azithromycine"] = "Antibiotique inutile : la grippe est virale.";
            c.HarmfulTx["amox_clav"] = "Antibiotique inutile : la grippe est virale.";
            c.DiscouragedTx["radio_thorax"] = "Pas de radiographie si l'auscultation et la saturation sont normales.";
            c.DiscouragedTx["corticoide"] = "Les corticoïdes n'ont pas leur place dans la grippe.";
            c.AcceptableOrientations.Add(Orientation.DomicileSuivi);
            Add(c);

            // ---------------------------------------------------------------- Migraine
            c = new CaseDef
            {
                Id = "migraine", Title = "Crise de migraine", Motif = "Maux de tête",
                Opening = "Bonjour docteur. J'ai encore une de mes crises de migraine, ça cogne d'un côté.",
                AgeMin = 20, AgeMax = 55, Sex = Characters.Sex.Femme, Pose = PatientPose.Tete,
                History = new[] { "Migraines depuis l'adolescence (2 à 3 crises par mois)" },
                Vitals = new VitalsSpec { Sys = 128, Dia = 80 },
                Diagnosis = "migraine", Orientation = Orientation.Domicile, IdealMinutes = 10,
                Teaching = "Migraine avec aura typique, identique aux crises habituelles, et examen neurologique normal : aucune imagerie n'est nécessaire. Traitement de crise par AINS et/ou triptan, pris le plus tôt possible. Une céphalée brutale, inhabituelle, fébrile ou avec un déficit neurologique impose au contraire une prise en charge urgente."
            };
            c.Answers["q_debut"] = "Ce matin au réveil. J'en ai deux ou trois par mois depuis l'adolescence.";
            c.Answers["q_localisation"] = "À droite, derrière l'œil.";
            c.Answers["q_intensite"] = "7 sur 10, ça pulse.";
            c.Answers["q_facteurs"] = "La lumière et le bruit me gênent, j'ai envie de rester dans le noir.";
            c.Answers["q_digestif"] = "J'ai des nausées, mais je n'ai pas vomi.";
            c.Answers["q_neuro"] = "J'ai vu des zigzags lumineux avant le mal de tête, pendant 20 minutes, puis c'est parti.";
            c.Answers["q_evolution"] = "C'est exactement comme mes crises habituelles.";
            c.Answers["q_fievre"] = "Non, pas de fièvre.";
            c.Findings["ex_neuro"] = F("Examen neurologique normal, pas de raideur de nuque.");
            c.Findings["ex_yeux"] = F("Pupilles égales et réactives, photophobie.");
            c.KeyQuestions.UnionWith(new[] { "q_evolution", "q_neuro", "q_fievre" });
            c.KeyExams.UnionWith(new[] { "ex_neuro" });
            c.UsefulExams.UnionWith(new[] { "ex_ta", "ex_yeux", "ex_temp" });
            c.RequiredTx.Add(new[] { "triptan", "ibuprofene" });
            c.RecommendedTx.UnionWith(new[] { "triptan", "ibuprofene" });
            c.AcceptableTx.UnionWith(new[] { "paracetamol", "repos", "surveillance" });
            c.DiscouragedTx["scanner"] = "Imagerie inutile : céphalée habituelle, examen normal, aucun signe d'alerte.";
            c.DiscouragedTx["tramadol"] = "Opioïdes déconseillés dans la migraine (risque de céphalées par abus médicamenteux).";
            c.PartialDiagnoses.Add("cephalee_tension");
            Add(c);

            // ---------------------------------------------------------------- Otite de l'enfant
            c = new CaseDef
            {
                Id = "otite_enfant", Title = "Otite moyenne aiguë", Motif = "Mal à l'oreille, fièvre",
                Opening = "Bonjour docteur. Elle a mal à l'oreille depuis cette nuit, elle a pleuré pendant des heures.",
                AgeMin = 2, AgeMax = 6, Companion = "son père", Pose = PatientPose.Tete,
                Vitals = new VitalsSpec { Temp = 38.7f, Hr = 118 },
                Diagnosis = "otite", Orientation = Orientation.DomicileSuivi, IdealMinutes = 10,
                Teaching = "Otite moyenne aiguë purulente : tympan rouge et bombé chez un enfant fébrile et douloureux. Traitement par amoxicilline (80 à 90 mg/kg/j), après avoir vérifié l'absence d'allergie, et paracétamol adapté au poids. Les fluoroquinolones sont contre-indiquées chez l'enfant."
            };
            c.Answers["q_debut"] = "Depuis cette nuit. Elle a un gros rhume depuis trois jours.";
            c.Answers["q_fievre"] = "38,9 ce matin.";
            c.Answers["q_localisation"] = "L'oreille droite, elle se la tient tout le temps.";
            c.Answers["q_respi"] = "Le nez coule, elle tousse un peu.";
            c.Answers["q_entourage"] = "À la crèche, beaucoup d'enfants sont enrhumés.";
            c.Findings["ex_otoscopie"] = F("Tympan droit rouge et bombé, reliefs effacés : otite moyenne aiguë purulente. Tympan gauche normal.", Severity.Attention);
            c.Findings["ex_gorge"] = F("Gorge un peu rouge, sans exsudat.");
            c.Findings["ex_poids"] = F("Poids 16,5 kg.");
            c.KeyQuestions.UnionWith(new[] { "q_allergies", "q_fievre" });
            c.KeyExams.UnionWith(new[] { "ex_otoscopie" });
            c.UsefulExams.UnionWith(new[] { "ex_temp", "ex_gorge", "ex_poids" });
            c.RequiredTx.Add(new[] { "amoxicilline" });
            c.RecommendedTx.UnionWith(new[] { "paracetamol", "serum_phy" });
            c.AcceptableTx.Add("surveillance");
            c.HarmfulTx["fluoroquinolone"] = "Les fluoroquinolones sont contre-indiquées chez l'enfant.";
            c.DiscouragedTx["azithromycine"] = "Pas en première intention en l'absence d'allergie.";
            c.AcceptableOrientations.Add(Orientation.Domicile);
            Add(c);

            // ---------------------------------------------------------------- Diabète déséquilibré
            c = new CaseDef
            {
                Id = "diabete_deseq", Title = "Diabète de type 2 déséquilibré", Motif = "Résultats de prise de sang",
                Opening = "Bonjour docteur. Je viens vous montrer mes résultats de prise de sang, pour le diabète.",
                AgeMin = 55, AgeMax = 75, Sex = Characters.Sex.Homme, Pose = PatientPose.Neutre,
                History = new[] { "Diabète de type 2 depuis 12 ans", "Hypertension artérielle", "Surpoids" },
                Meds = new[] { "Metformine 1000 mg matin et soir", "Ramipril 5 mg le matin" },
                Notes = "Résultats apportés (il y a 3 jours) : HbA1c 8,6 % (objectif ≈ 7 %), créatinine normale, LDL 1,1 g/L.",
                Vitals = new VitalsSpec { Sys = 136, Dia = 84, Glyc = 2.1f, Weight = 96f, Height = 1.74f },
                Diagnosis = "diabete_deseq", Orientation = Orientation.DomicileSuivi, IdealMinutes = 14,
                Teaching = "Diabète de type 2 non équilibré (HbA1c 8,6 % pour un objectif autour de 7 %). On renforce les règles hygiéno-diététiques et l'activité physique, puis on intensifie le traitement (ajout d'un second antidiabétique choisi selon le profil). On examine les pieds à chaque consultation et on planifie le suivi : fond d'œil, bilan rénal, cardiologique."
            };
            c.Answers["q_debut"] = "Depuis quelques mois, je me sens moins en forme.";
            c.Answers["q_general"] = "Je suis plus fatigué, et j'ai souvent soif.";
            c.Answers["q_urinaire"] = "Je me lève deux ou trois fois la nuit pour uriner.";
            c.Answers["q_habitudes"] = "J'ai pris quelques kilos… je mange pas mal de gâteaux, je l'avoue. Je ne fume pas.";
            c.Answers["q_travail"] = "Je suis retraité, je bouge peu.";
            c.Findings["ex_glyc"] = F("Glycémie capillaire : 2,10 g/L (non à jeun).", Severity.Attention);
            c.Findings["ex_peau"] = F("Examen des pieds : pas de plaie, pouls perçus, sensibilité au monofilament conservée.");
            c.KeyQuestions.UnionWith(new[] { "q_traitements", "q_habitudes", "q_general" });
            c.KeyExams.UnionWith(new[] { "ex_peau", "ex_ta" });
            c.UsefulExams.UnionWith(new[] { "ex_poids", "ex_glyc", "ex_coeur" });
            c.RequiredTx.Add(new[] { "antidiab" });
            c.RecommendedTx.UnionWith(new[] { "hygieno_diet", "activite", "bio" });
            c.AcceptableTx.Add("surveillance");
            c.HarmfulTx["corticoide"] = "Les corticoïdes aggravent le diabète.";
            c.AcceptableOrientations.Add(Orientation.Specialiste);
            Add(c);

            // ---------------------------------------------------------------- Entorse de cheville
            c = new CaseDef
            {
                Id = "entorse", Title = "Entorse de cheville", Motif = "Cheville gonflée",
                Opening = "Bonjour docteur, je me suis tordu la cheville au foot hier soir, ça a gonflé.",
                AgeMin = 17, AgeMax = 35, Pose = PatientPose.Boiterie, Limp = true,
                Diagnosis = "entorse", Orientation = Orientation.Domicile, IdealMinutes = 10,
                Teaching = "Les règles d'Ottawa évitent les radiographies inutiles : on ne radiographie que s'il existe une douleur osseuse à la palpation (bord postérieur des malléoles, base du 5e métatarsien, os naviculaire) ou une impossibilité de faire 4 pas. Entorse bénigne : glace, repos relatif, compression, élévation, chevillère et remise en charge précoce."
            };
            c.Answers["q_debut"] = "Hier soir au foot. Mon pied est parti vers l'intérieur.";
            c.Answers["q_localisation"] = "Sur l'extérieur de la cheville, devant l'os.";
            c.Answers["q_intensite"] = "5 sur 10. J'arrive à marcher, en boitant.";
            c.Answers["q_facteurs"] = "Ça fait mal quand je pose le pied, moins au repos.";
            c.Answers["q_travail"] = "Je suis étudiant.";
            c.Findings["ex_cheville"] = F("Œdème et ecchymose en avant de la malléole externe. Pas de douleur osseuse (malléoles, 5e métatarsien, naviculaire) ; 4 pas possibles. Règles d'Ottawa négatives.", Severity.Attention);
            c.KeyQuestions.UnionWith(new[] { "q_debut", "q_intensite" });
            c.KeyExams.UnionWith(new[] { "ex_cheville" });
            c.RequiredTx.Add(new[] { "glace" });
            c.RecommendedTx.UnionWith(new[] { "attelle", "paracetamol" });
            c.AcceptableTx.UnionWith(new[] { "ibuprofene", "surveillance", "activite" });
            c.DiscouragedTx["radio_cheville"] = "Radiographie inutile : les règles d'Ottawa sont négatives.";
            c.PartialDiagnoses.Add("fracture_cheville");
            Add(c);

            // ---------------------------------------------------------------- Asthme
            c = new CaseDef
            {
                Id = "asthme", Title = "Crise d'asthme modérée", Motif = "Gêne respiratoire",
                Opening = "Bonjour docteur… j'ai du mal à respirer depuis hier soir, ça siffle.",
                AgeMin = 18, AgeMax = 40, Pose = PatientPose.Toux, Cough = true,
                History = new[] { "Asthme depuis l'enfance" },
                Meds = new[] { "Salbutamol (Ventoline) à la demande" },
                Allergies = new[] { "Pollens", "Poils de chat" },
                Vitals = new VitalsSpec { Hr = 104, Spo2 = 95, Rr = 22 },
                Diagnosis = "asthme", Orientation = Orientation.DomicileSuivi, IdealMinutes = 12,
                Teaching = "Crise d'asthme modérée (DEP entre 50 et 70 %, SpO2 ≥ 94 %, parole normale) : bronchodilatateur d'action rapide répété et corticothérapie orale courte (prednisolone 5 jours), réévaluation sous 48 h. Signes de gravité (DEP < 50 %, SpO2 < 92 %, difficulté à parler, épuisement) = appel du 15."
            };
            c.Answers["q_debut"] = "Depuis hier soir, après être allée chez une amie qui a deux chats.";
            c.Answers["q_respi"] = "Oui, ça siffle, je suis essoufflée et je tousse la nuit.";
            c.Answers["q_traitements"] = "J'ai pris ma Ventoline quatre fois depuis hier, ça soulage un peu mais ça revient.";
            c.Answers["q_fievre"] = "Non, pas de fièvre.";
            c.Answers["q_facteurs"] = "Le chat de mon amie, je pense.";
            c.Answers["q_general"] = "Je parle normalement mais je suis gênée dans l'escalier.";
            c.Findings["ex_poumons"] = F("Sibilants diffus aux deux poumons, expiration prolongée.", Severity.Attention);
            c.Findings["ex_dep"] = F("DEP 280 L/min, soit environ 60 % de sa valeur habituelle (460 L/min).", Severity.Attention);
            c.KeyQuestions.UnionWith(new[] { "q_respi", "q_traitements" });
            c.KeyExams.UnionWith(new[] { "ex_poumons", "ex_dep", "ex_spo2" });
            c.UsefulExams.UnionWith(new[] { "ex_temp", "ex_coeur" });
            c.RequiredTx.Add(new[] { "salbutamol" });
            c.RequiredTx.Add(new[] { "corticoide" });
            c.RecommendedTx.Add("surveillance");
            c.AcceptableTx.Add("antihistaminique");
            c.DiscouragedTx["amoxicilline"] = "Pas d'antibiotique : rien n'évoque une infection bactérienne.";
            c.DiscouragedTx["radio_thorax"] = "Radiographie non nécessaire dans une crise d'asthme simple.";
            c.DiscouragedTx["ibuprofene"] = "Les AINS peuvent aggraver certains asthmes.";
            c.AcceptableOrientations.Add(Orientation.Domicile);
            Add(c);

            // ---------------------------------------------------------------- AVC
            c = new CaseDef
            {
                Id = "avc", Title = "Accident vasculaire cérébral", Motif = "Troubles de la parole",
                Opening = "Docteur, il parle bizarrement depuis une demi-heure, et son bras droit ne répond plus !",
                AgeMin = 68, AgeMax = 82, Sex = Characters.Sex.Homme, Urgency = Urgency.Vitale, Companion = "son épouse", Pose = PatientPose.Fatigue,
                History = new[] { "Hypertension artérielle", "Fibrillation atriale" },
                Meds = new[] { "Amlodipine 10 mg", "Apixaban : arrêté par le patient le mois dernier" },
                Vitals = new VitalsSpec { Sys = 172, Dia = 98, Hr = 92, Irregular = true, Glyc = 1.1f },
                Diagnosis = "avc", Orientation = Orientation.Urgences15, IdealMinutes = 8, DeteriorationMinutes = 18f, PatienceMinutes = 200f,
                Teaching = "Déficit neurologique brutal (visage, bras, parole : score FAST) = AVC jusqu'à preuve du contraire. Appel immédiat du 15 en notant l'heure de début : la thrombolyse est possible jusqu'à 4 h 30 et la thrombectomie parfois au-delà. On vérifie la glycémie (une hypoglycémie peut imiter un AVC). Jamais d'aspirine avant l'imagerie : l'AVC peut être hémorragique."
            };
            c.Answers["q_debut"] = "Ça a commencé il y a 35 minutes, d'un coup, au petit-déjeuner. Il allait très bien juste avant.";
            c.Answers["q_neuro"] = "Il ne trouve plus ses mots et sa bouche tombe du côté droit.";
            c.Answers["q_traitements"] = "Il a arrêté son anticoagulant le mois dernier, sans en parler à personne.";
            c.Answers["q_localisation"] = "Il ne dit pas avoir mal.";
            c.Findings["ex_neuro"] = F("Paralysie faciale droite, déficit moteur du bras droit, troubles de la parole (aphasie). Score FAST positif.", Severity.Critique);
            c.Findings["ex_glyc"] = F("Glycémie capillaire 1,10 g/L : pas d'hypoglycémie.");
            c.Findings["ex_ecg"] = F("Fibrillation atriale à 92/min.", Severity.Attention);
            c.KeyQuestions.UnionWith(new[] { "q_debut", "q_traitements" });
            c.KeyExams.UnionWith(new[] { "ex_neuro", "ex_glyc" });
            c.UsefulExams.UnionWith(new[] { "ex_ta", "ex_ecg" });
            c.HarmfulTx["aspirine"] = "Jamais d'aspirine avant l'imagerie : l'AVC peut être hémorragique.";
            c.HarmfulTx["tramadol"] = "Aucun intérêt et retarde la prise en charge.";
            Add(c);

            // ---------------------------------------------------------------- Pneumopathie
            c = new CaseDef
            {
                Id = "pneumopathie", Title = "Pneumopathie aiguë", Motif = "Toux, fièvre",
                Opening = "Bonjour docteur. Je tousse depuis une semaine, et depuis deux jours j'ai de la fièvre et mal sur le côté quand je respire.",
                AgeMin = 35, AgeMax = 62, Pose = PatientPose.Toux, Cough = true,
                Vitals = new VitalsSpec { Temp = 38.9f, Hr = 104, Rr = 24, Spo2 = 94, Sys = 118, Dia = 70 },
                Diagnosis = "pneumopathie", Orientation = Orientation.DomicileSuivi, IdealMinutes = 14,
                Teaching = "Pneumopathie aiguë communautaire : fièvre, toux, douleur thoracique et foyer de crépitants. Le score CRB-65 (confusion, fréquence respiratoire ≥ 30, pression basse, âge ≥ 65 ans) est à 0 : traitement ambulatoire par amoxicilline 1 g trois fois par jour, radiographie de thorax et réévaluation à 48-72 h."
            };
            c.Answers["q_debut"] = "La toux depuis une semaine, la fièvre depuis deux jours.";
            c.Answers["q_fievre"] = "39 hier soir, avec de gros frissons.";
            c.Answers["q_respi"] = "Je tousse gras, je crache un peu jaune, et je suis essoufflée à l'effort.";
            c.Answers["q_localisation"] = "À droite, en bas des côtes, quand j'inspire fort.";
            c.Answers["q_habitudes"] = "Je fume dix cigarettes par jour.";
            c.Answers["q_neuro"] = "Non, j'ai les idées claires.";
            c.Findings["ex_poumons"] = F("Foyer de crépitants à la base droite, diminution du murmure vésiculaire.", Severity.Attention);
            c.KeyQuestions.UnionWith(new[] { "q_respi", "q_fievre" });
            c.KeyExams.UnionWith(new[] { "ex_poumons", "ex_temp", "ex_spo2" });
            c.UsefulExams.UnionWith(new[] { "ex_ta", "ex_coeur" });
            c.RequiredTx.Add(new[] { "amoxicilline" });
            c.RecommendedTx.UnionWith(new[] { "radio_thorax", "paracetamol", "surveillance" });
            c.AcceptableTx.UnionWith(new[] { "arret", "repos", "amox_clav" });
            c.HarmfulTx["corticoide"] = "Pas de corticoïdes dans une pneumopathie infectieuse.";
            c.DiscouragedTx["azithromycine"] = "Les macrolides couvrent mal le pneumocoque, germe principal.";
            c.AcceptableOrientations.Add(Orientation.Domicile);
            c.PartialDiagnoses.Add("bronchite");
            Add(c);

            // ---------------------------------------------------------------- Conjonctivite virale
            c = new CaseDef
            {
                Id = "conjonctivite", Title = "Conjonctivite virale", Motif = "Œil rouge",
                Opening = "Bonjour docteur, j'ai l'œil rouge depuis hier, et ça colle un peu le matin.",
                AgeMin = 18, AgeMax = 60, Pose = PatientPose.Oeil,
                Diagnosis = "conj_virale", Orientation = Orientation.Domicile, IdealMinutes = 8,
                Teaching = "Œil rouge sans douleur ni baisse de vision, sécrétions claires, contexte de rhume : conjonctivite virale. Lavages au sérum physiologique et hygiène stricte des mains (très contagieux). Le collyre antibiotique est inutile. Un œil rouge douloureux avec baisse de vision doit faire consulter un ophtalmologue en urgence."
            };
            c.Answers["q_debut"] = "Depuis hier matin. J'ai un rhume depuis quelques jours.";
            c.Answers["q_localisation"] = "L'œil droit. Ça gratte, mais ça ne fait pas vraiment mal.";
            c.Answers["q_neuro"] = "Non, je vois très bien.";
            c.Answers["q_entourage"] = "Mon fils a eu la même chose la semaine dernière.";
            c.Findings["ex_yeux"] = F("Rougeur conjonctivale diffuse de l'œil droit, sécrétions claires, vision et pupilles normales.", Severity.Attention);
            c.Findings["ex_ganglions"] = F("Petit ganglion pré-auriculaire droit.");
            c.KeyQuestions.UnionWith(new[] { "q_neuro", "q_localisation" });
            c.KeyExams.UnionWith(new[] { "ex_yeux" });
            c.UsefulExams.Add("ex_ganglions");
            c.RequiredTx.Add(new[] { "serum_phy" });
            c.RecommendedTx.Add("hygiene");
            c.AcceptableTx.Add("surveillance");
            c.DiscouragedTx["collyre_ab"] = "Collyre antibiotique inutile dans une conjonctivite virale.";
            c.PartialDiagnoses.Add("conj_bact");
            Add(c);

            // ---------------------------------------------------------------- Rhinopharyngite de l'enfant
            c = new CaseDef
            {
                Id = "rhino_enfant", Title = "Rhinopharyngite", Motif = "Nez qui coule, toux",
                Opening = "Bonjour docteur, il a le nez qui coule et il tousse depuis trois jours.",
                AgeMin = 2, AgeMax = 8, Companion = "sa mère", Pose = PatientPose.Toux, Cough = true,
                Vitals = new VitalsSpec { Temp = 38.0f },
                Diagnosis = "rhino", Orientation = Orientation.Domicile, IdealMinutes = 8,
                Teaching = "La rhinopharyngite est virale et guérit seule en 7 à 10 jours. On vérifie l'absence d'otite et de signe de gravité respiratoire. Traitement : lavages de nez au sérum physiologique, paracétamol si fièvre mal tolérée. Pas d'antibiotique."
            };
            c.Answers["q_debut"] = "Depuis trois jours.";
            c.Answers["q_fievre"] = "Un peu, 38 hier soir.";
            c.Answers["q_respi"] = "Il tousse et il a le nez bouché, mais il respire bien.";
            c.Answers["q_localisation"] = "Il ne se plaint pas des oreilles.";
            c.Answers["q_entourage"] = "Toute la classe est enrhumée.";
            c.Findings["ex_otoscopie"] = F("Tympans normaux des deux côtés.");
            c.Findings["ex_gorge"] = F("Gorge un peu rouge, écoulement nasal clair.");
            c.Findings["ex_poumons"] = F("Auscultation normale.");
            c.KeyQuestions.UnionWith(new[] { "q_respi", "q_fievre" });
            c.KeyExams.UnionWith(new[] { "ex_otoscopie", "ex_poumons" });
            c.UsefulExams.UnionWith(new[] { "ex_gorge", "ex_temp" });
            c.RequiredTx.Add(new[] { "serum_phy" });
            c.RecommendedTx.UnionWith(new[] { "paracetamol", "surveillance" });
            c.AcceptableTx.Add("hygiene");
            c.HarmfulTx["amoxicilline"] = "Antibiotique inutile : la rhinopharyngite est virale.";
            c.HarmfulTx["amox_clav"] = "Antibiotique inutile : la rhinopharyngite est virale.";
            Add(c);

            // ---------------------------------------------------------------- Bronchite aiguë
            c = new CaseDef
            {
                Id = "bronchite", Title = "Bronchite aiguë", Motif = "Toux",
                Opening = "Bonjour docteur. Je tousse depuis cinq jours, ça ne passe pas.",
                AgeMin = 25, AgeMax = 60, Pose = PatientPose.Toux, Cough = true,
                Vitals = new VitalsSpec { Temp = 37.6f },
                Diagnosis = "bronchite", Orientation = Orientation.Domicile, IdealMinutes = 9,
                Teaching = "La bronchite aiguë de l'adulte sain est virale : la toux peut durer deux à trois semaines. Auscultation et saturation normales : pas de radiographie, pas d'antibiotique. On explique l'évolution et les signes qui doivent faire reconsulter (fièvre persistante, essoufflement)."
            };
            c.Answers["q_debut"] = "Depuis cinq jours, après un rhume.";
            c.Answers["q_fievre"] = "Un peu au début, plus maintenant.";
            c.Answers["q_respi"] = "Une toux grasse, mais je ne suis pas essoufflé.";
            c.Answers["q_habitudes"] = "Je ne fume pas.";
            c.Findings["ex_poumons"] = F("Quelques ronchi qui se modifient à la toux, pas de crépitants.");
            c.KeyQuestions.UnionWith(new[] { "q_respi", "q_fievre", "q_habitudes" });
            c.KeyExams.UnionWith(new[] { "ex_poumons" });
            c.UsefulExams.UnionWith(new[] { "ex_temp", "ex_spo2" });
            c.RequiredTx.Add(new[] { "surveillance" });
            c.RecommendedTx.UnionWith(new[] { "paracetamol", "repos" });
            c.HarmfulTx["amoxicilline"] = "Antibiotique inutile : la bronchite aiguë est virale.";
            c.HarmfulTx["amox_clav"] = "Antibiotique inutile : la bronchite aiguë est virale.";
            c.HarmfulTx["azithromycine"] = "Antibiotique inutile : la bronchite aiguë est virale.";
            c.DiscouragedTx["radio_thorax"] = "Radiographie inutile : auscultation et saturation normales.";
            c.PartialDiagnoses.Add("pneumopathie");
            Add(c);
        }
    }
}
