class_name Lexique
## Mots simples pour un joueur qui n'est pas médecin : chaque terme technique est remplacé ou
## expliqué (le vrai terme reste entre parenthèses quand il est utile). Sert au HUD (constantes,
## objets en main, messages, aide des gestes), au chariot, au dossier et aux bilans.
## Les messages des gestes (gestures.gd) passent par simple() : on n'a pas à réécrire ce fichier.

## Constantes du scope : clé -> [nom simple, vrai terme, unité, icône]
const VITALS := {
	"FC": ["Cœur", "FC", "/min", "heart"],
	"SpO2": ["Oxygène", "SpO2", "%", "drop"],
	"PNI": ["Tension", "PNI", "mmHg", "gauge"],
	"FR": ["Respiration", "FR", "/min", "lungs"],
}

## Matériel : id -> [nom simple, à quoi ça sert]
const ITEMS := {
	"main": ["Mains", "Pouls, appeler, palper, masser"],
	"stetho": ["Stéthoscope", "Écouter le cœur et les poumons"],
	"lampe": ["Lampe stylo", "Regarder les pupilles"],
	"electrodes": ["Électrodes du scope", "3 autocollants : le cœur s'affiche sur l'écran"],
	"spo2": ["Pince à oxygène (SpO2)", "Au bout du doigt : l'oxygène dans le sang"],
	"brassard": ["Brassard à tension", "Mesure la tension toutes les 3 min (PNI)"],
	"pads": ["Électrodes du défibrillateur", "2 grands patchs pour analyser et choquer"],
	"ecg12": ["Électrodes de l'ECG (10)", "Électrocardiogramme : le cœur en détail"],
	"garrot": ["Garrot", "Serré sur le bras, il fait gonfler les veines"],
	"antiseptique": ["Désinfectant + compresses", "Nettoyer la peau avant de piquer"],
	"catheter18": ["Cathéter 18G (vert)", "Petit tuyau souple placé dans la veine"],
	"catheter20": ["Cathéter 20G (rose)", "Plus fin, pour les petites veines"],
	"tubes": ["Tubes de prise de sang", "Pour les analyses du laboratoire"],
	"perfuseur": ["Poche de sérum (NaCl 0,9 %)", "Du liquide dans la veine : remonte la tension"],
	"seringue": ["Seringue", "Médicament préparé"],
	"bavu": ["Ballon d'oxygène (BAVU)", "Masque + ballon : respirer à sa place"],
	"masque_o2": ["Masque à oxygène", "Beaucoup d'oxygène (haute concentration)"],
	"lunettes_o2": ["Lunettes à oxygène", "Un peu d'oxygène par le nez"],
	"nebuliseur": ["Masque d'aérosol", "Médicament respiré (nébulisation)"],
	"glucometre": ["Lecteur de sucre (glycémie)", "Une goutte de sang au bout du doigt"],
	"thermometre": ["Thermomètre", "Dans l'oreille"],
	"lucas": ["LUCAS (massage automatique)", "Machine qui masse à ta place"],
}

## Voies d'administration
const ROUTES := {"IV": "Dans la veine (IV)", "IM": "Dans le muscle (IM)", "NEB": "En aérosol", "PERF": "Perfusion"}

## Médicaments : à quoi ils servent, en mots simples
const DRUG_INFO := {
	"adrenaline": "Allergie grave, arrêt du cœur",
	"amiodarone": "Calme un cœur qui s'emballe (arrêt en FV)",
	"atropine": "Accélère un cœur trop lent",
	"naloxone": "Antidote de l'héroïne et de la morphine",
	"glucose30": "Sucre concentré, pour l'hypoglycémie",
	"glucagon": "Fait remonter le sucre (dans le muscle)",
	"morphine": "Contre la douleur forte",
	"paracetamol": "Contre la douleur et la fièvre",
	"aspirine": "Fluidifie le sang (infarctus)",
	"heparine": "Empêche les caillots (infarctus)",
	"salbutamol": "Ouvre les bronches (asthme)",
	"ipratropium": "Ouvre les bronches, avec le salbutamol",
	"methylpred": "Cortisone : calme l'inflammation",
	"nacl": "Sérum : remplit les vaisseaux",
	"midazolam": "Calme, endort (sédatif)",
	"furosemide": "Fait uriner (poumons pleins d'eau)",
}

## Examens : id -> nom simple
const LABS := {
	"nfs": "Globules et plaquettes (NFS)", "iono": "Sels du sang et reins (ionogramme)", "trop": "Marqueur d'infarctus (troponine)",
	"lact": "Manque d'oxygène des organes (lactates)", "gds": "Gaz du sang (oxygène, CO2)", "bh": "Foie et pancréas (bilan hépatique)",
	"hemostase": "Coagulation (TP, TCA)", "crp": "Inflammation (CRP)", "tox": "Recherche de drogues (toxiques)",
	"alcool": "Alcool dans le sang", "tryptase": "Marqueur d'allergie (tryptase)", "radio": "Radio des poumons (au lit)",
}

## Diagnostics : valeur -> libellé expliqué
const DIAGNOSES := {
	"Arrêt cardiaque sur fibrillation ventriculaire": "Arrêt du cœur (fibrillation ventriculaire)",
	"Syndrome coronarien aigu avec sus-décalage du ST (infarctus)": "Infarctus : artère du cœur bouchée (SCA ST+)",
	"Intoxication aux opiacés": "Overdose d'héroïne ou de morphine (opiacés)",
	"Hypoglycémie sévère": "Manque de sucre grave (hypoglycémie sévère)",
	"Asthme aigu grave": "Crise d'asthme grave",
	"Choc anaphylactique": "Allergie grave avec chute de tension (choc anaphylactique)",
	"Embolie pulmonaire": "Caillot dans le poumon (embolie pulmonaire)",
	"Accident vasculaire cérébral": "Attaque cérébrale (AVC)",
	"Crise d'angoisse": "Crise d'angoisse",
	"Choc septique": "Infection grave avec chute de tension (choc septique)",
	"Intoxication alcoolique": "Trop d'alcool (intoxication alcoolique)",
}

const ORIENTATIONS := {
	"Salle de coronarographie (cardiologue appelé)": "Déboucher l'artère du cœur tout de suite (coronarographie)",
	"Réanimation": "Réanimation (soins les plus lourds)",
	"Soins intensifs de cardiologie (USIC)": "Soins intensifs du cœur (USIC)",
	"Unité d'hospitalisation de courte durée (surveillance)": "Surveillance quelques heures aux urgences (UHCD)",
	"Hospitalisation en pneumologie": "Hospitalisation en service des poumons (pneumologie)",
	"Retour à domicile": "Retour à la maison",
	"Bloc opératoire": "Bloc opératoire",
}

## Phrases entières des gestes à remplacer telles quelles
const PHRASES := [
	["Clic maintenu sur le deltoïde ou la cuisse : injection IM", "Clic maintenu sur l'épaule ou le côté de la cuisse : injection dans le muscle (IM)"],
	["Injection IM : face externe de la cuisse ou deltoïde", "Injection dans le muscle : sur le côté de la cuisse ou sur l'épaule (deltoïde)"],
	["Clic maintenu sur le robinet du cathéter : injecter", "Clic maintenu sur le robinet du cathéter (bouchon coloré) : injecter dans la veine"],
	["Clic : glycémie capillaire au bout du doigt", "Clic au bout du doigt : mesurer le sucre dans le sang (glycémie)"],
	["Clic : appeler et stimuler · clic maintenu sur le menton : libérer les voies aériennes et regarder s'il respire",
		"Clic sur le front : l'appeler, le secouer · clic maintenu sur le menton : basculer la tête et regarder s'il respire"],
	["Clic maintenu : ausculter ici", "Clic maintenu : écouter au stéthoscope (ausculter)"],
	["Clic : examiner les pupilles", "Clic : éclairer l'œil pour voir les pupilles"],
	["Clic : température tympanique (oreille)", "Clic : prendre la température dans l'oreille"],
	["Clic maintenu : temps de recoloration cutanée", "Clic maintenu sur l'ongle : la couleur revient-elle vite ? (circulation)"],
	["Clic : pince au bout du doigt", "Clic : pince à oxygène au bout du doigt"],
	["Clic maintenu en frottant : désinfecter la peau", "Clic maintenu en frottant : désinfecter la peau (avant de piquer)"],
	["Clic sur une veine (sous garrot), puis glisse vers le coude pour monter le cathéter",
		"Clic sur une veine gonflée (garrot serré), puis glisse vers le coude en gardant le clic"],
	["Clic sur le ballon : insuffler (1 s, le thorax doit se soulever)", "Clic sur le ballon : lui donner de l'air (la poitrine doit se soulever)"],
	["Clic sur le visage : appliquer le masque (tête basculée en arrière)", "Clic sur le visage : plaquer le masque (tête basculée en arrière)"],
	["Clic sur le visage : mettre en place (puis régler le débit d'O2 au mur)", "Clic sur le visage : mettre en place (puis ouvrir l'oxygène au mur)"],
	["Pointe le patient (ou un bouton de l'appareil) · clic droit maintenu : tourner · molette : zoom",
		"Pointe le patient avec la souris · clic droit maintenu : tourner · molette : zoom · Échap : revenir"],
	["Abdomen souple, dépressible, indolore.", "Ventre souple, pas douloureux."],
	["Abdomen douloureux à la palpation.", "Le ventre est douloureux quand on appuie."],
	["Défense abdominale.", "Ventre dur et contracté (défense) : urgence chirurgicale possible."],
	["Perfusion de NaCl 0,9 % 500 mL en débit libre", "Poche de sérum (NaCl) de 500 mL branchée : elle coule à fond"],
	["Pense à ouvrir l'oxygène au débitmètre mural", "Pense à ouvrir l'oxygène au débitmètre (au mur, à droite)"],
	["Nébulisation : il faut 6 à 8 L/min d'O2 au débitmètre", "Aérosol : ouvre l'oxygène à 6-8 L/min au débitmètre mural"],
	["Tubes partis au labo : prescris les analyses sur l'ordinateur", "Prise de sang partie au labo : choisis les analyses sur l'ordinateur (Tab)"],
	["Pouls carotidien…", "Pouls au cou…"],
	["Pouls radial…", "Pouls au poignet…"],
	["Tête basculée : regarder, écouter, sentir…", "Tête basculée : il respire ? (regarder, écouter, sentir)…"],
	["Lecture de la glycémie…", "Lecture du sucre…"],
	["Auscultation…", "Écoute au stéthoscope…"],
]

## Termes isolés (expressions régulières) -> texte simple ; appliqués après les phrases
const TERMS := [
	["Pouls carotidien", "Pouls au cou (carotidien)"],
	["pouls carotidien", "pouls au cou (carotidien)"],
	["Pouls radial", "Pouls au poignet (radial)"],
	["pouls radial", "pouls au poignet (radial)"],
	["bien frappé", "bien frappé (fort)"],
	["filant", "filant (faible)"],
	["Glycémie capillaire", "Sucre dans le sang (glycémie)"],
	["glycémie capillaire", "sucre au bout du doigt (glycémie)"],
	["Capteur de SpO2", "Pince à oxygène (SpO2)"],
	["Voies aériennes libérées", "Tête basculée, gorge dégagée"],
	["Voies aériennes libres", "Gorge dégagée"],
	["libérer les voies aériennes", "dégager la gorge (voies aériennes)"],
	["quelques gasps", "quelques hoquets inefficaces (gasps)"],
	["en myosis serré", "toutes petites (myosis)"],
	["en mydriase", "très dilatées (mydriase)"],
	["aréactives", "ne réagissent pas à la lumière"],
	["réactives", "réagissent à la lumière"],
	["murmure vésiculaire", "bruit de l'air (murmure vésiculaire)"],
	["sibilants \\(sifflements expiratoires\\)", "sifflements (sibilants)"],
	["crépitants", "crépitements (crépitants)"],
	["silence auscultatoire", "on n'entend plus l'air passer (silence)"],
	["Température tympanique", "Température (oreille)"],
	["Massage cardiaque externe", "Massage cardiaque"],
	["(?<![(\\w])BAVU(?!\\))", "ballon (BAVU)"],
	["(?<![(\\w])PNI(?!\\))", "tension (PNI)"],
	["\\bd'O2\\b", "d'oxygène"],
	["(?<![\\w(])O2\\b", "oxygène"],
	["(?<![(\\w])IV(?![\\w)])", "dans la veine"],
	["(?<![(\\w])IM(?![\\w)])", "dans le muscle"],
	["Glasgow", "conscience (Glasgow)"],
]

static var _rx: Array = []


## Texte d'un geste, d'un message ou du dossier, en mots simples.
static func simple(t: String) -> String:
	if t == "":
		return t
	for p in PHRASES:
		t = t.replace(p[0], p[1])
	if _rx.is_empty():
		for e in TERMS:
			var r := RegEx.new()
			r.compile(e[0])
			_rx.append([r, e[1]])
	for e in _rx:
		t = (e[0] as RegEx).sub(t, e[1], true)
	return t


static func item_name(id: String, fallback := "") -> String:
	if id == "seringue" or id == "nebuliseur":
		return simple(fallback) if fallback != "" else ITEMS[id][0]
	return ITEMS[id][0] if ITEMS.has(id) else fallback


static func item_desc(id: String) -> String:
	return ITEMS[id][1] if ITEMS.has(id) else ""


static func route(r: String) -> String:
	return ROUTES.get(r, r)


static func lab_name(id: String) -> String:
	return LABS.get(id, Labs.NAMES.get(id, id))


static func diag(d: String) -> String:
	return DIAGNOSES.get(d, d)


static func orient(o: String) -> String:
	return ORIENTATIONS.get(o, o)


## Gravité d'une constante : 0 normale, 1 à surveiller, 2 danger.
static func severity(k: String, v: float, v2 := 0.0) -> int:
	match k:
		"FC":
			return 2 if v < 40.0 or v > 140.0 else (1 if v < 50.0 or v > 110.0 else 0)
		"SpO2":
			return 2 if v < 90.0 else (1 if v < 94.0 else 0)
		"PNI":
			return 2 if v < 80.0 or v > 200.0 or v2 < 45.0 else (1 if v < 95.0 or v > 160.0 else 0)
		"FR":
			return 2 if v < 8.0 or v > 30.0 else (1 if v < 10.0 or v > 22.0 else 0)
	return 0


static func severity_color(s: int) -> Color:
	return [UIKit.OK, UIKit.WARN, UIKit.BAD][clampi(s, 0, 2)]


static func severity_text(s: int) -> String:
	return ["normal", "à surveiller", "danger"][clampi(s, 0, 2)]
