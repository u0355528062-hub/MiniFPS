class_name Case
extends RefCounted
## Un cas clinique : le patient (identité, aspect), sa transmission à l'arrivée, ce qu'il répond à
## l'interrogatoire, sa maladie (qui fait évoluer les constantes, et répond — ou pas — aux soins),
## ses résultats d'examens, le bon diagnostic et la bonne orientation, et la grille d'évaluation.

const CATALOG := [
	{"id": "acr_fv", "name": "Arrêt cardiaque", "tag": "Il s'effondre devant vous : massage, défibrillation, adrénaline.", "level": 3, "minutes": 12},
	{"id": "sca_st", "name": "Douleur thoracique", "tag": "Douleur qui serre la poitrine depuis une heure, en sueurs.", "level": 2, "minutes": 12},
	{"id": "overdose", "name": "Inconscient, respire mal", "tag": "Trouvé sans connaissance dans des toilettes publiques.", "level": 2, "minutes": 10},
	{"id": "hypoglycemie", "name": "Coma chez un diabétique", "tag": "Diabétique sous insuline retrouvé confus puis inconscient.", "level": 1, "minutes": 8},
	{"id": "asthme", "name": "Crise d'asthme grave", "tag": "Jeune asthmatique qui n'arrive plus à respirer.", "level": 2, "minutes": 12},
	{"id": "anaphylaxie", "name": "Choc anaphylactique", "tag": "Piqué par une guêpe : plaques, gorge qui serre, malaise.", "level": 2, "minutes": 10},
]

## Diagnostics et orientations proposés à la conclusion (tous les cas)
const DIAGNOSES := ["Arrêt cardiaque sur fibrillation ventriculaire", "Syndrome coronarien aigu avec sus-décalage du ST (infarctus)",
	"Intoxication aux opiacés", "Hypoglycémie sévère", "Asthme aigu grave", "Choc anaphylactique", "Embolie pulmonaire",
	"Accident vasculaire cérébral", "Crise d'angoisse", "Choc septique", "Intoxication alcoolique"]
const ORIENTATIONS := ["Salle de coronarographie (cardiologue appelé)", "Réanimation", "Soins intensifs de cardiologie (USIC)",
	"Unité d'hospitalisation de courte durée (surveillance)", "Hospitalisation en pneumologie", "Retour à domicile", "Bloc opératoire"]

var id := ""
var name := ""
var level := 1
var minutes := 10
var profile := {"name": "Patient", "age": 50, "skin": Color(0.99, 0.95, 0.94), "hair": Color(0.05, 0.035, 0.025), "bald": 0.0, "stubble": 0.3, "collar": false}
var arrival := ""
var arrival_vitals := ""
var questions: Array = []  ## [question, réponse]
## Ce que le patient dit de lui-même de temps en temps (s'il peut parler)
var lines: Array = []
var _line_t := 12.0
var _line_i := 0
var diag_ok := ""
var orient_ok := ""
var summary_good := ""
var summary_bad := ""
var game: Node
var physio: Physio
var finished := false
var outcome := ""  ## texte du devenir


static func create(case_id: String) -> Case:
	match case_id:
		"sca_st":
			return CaseSCA.new()
		"overdose":
			return CaseOverdose.new()
		"hypoglycemie":
			return CaseHypo.new()
		"asthme":
			return CaseAsthme.new()
		"anaphylaxie":
			return CaseAnaphylaxie.new()
		_:
			return CaseACR.new()


func info() -> Dictionary:
	for e in CATALOG:
		if e["id"] == id:
			return e
	return CATALOG[0]


## Temps de référence (s) pour la note.
func reference_time() -> float:
	return float(info()["minutes"]) * 60.0


func t() -> float:
	return physio.time


func journal() -> Journal:
	return game.get("journal")


func did(kind: String) -> bool:
	return journal().has(kind)


func when(kind: String) -> float:
	return journal().first(kind)


# ---------------------------------------------------------------- À redéfinir

func setup() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func on_event(_kind: String, _data: Dictionary) -> void:
	pass


## Plaintes spontanées du patient (appelé à chaque image par le jeu).
func chatter(delta: float) -> void:
	if lines.is_empty() or not physio.speaks:
		return
	_line_t -= delta
	if _line_t <= 0.0:
		_line_t = randf_range(20.0, 32.0)
		game.call("say", lines[_line_i % lines.size()], "patient")
		_line_i += 1


## Un médicament administré : par défaut, effet générique de la physiologie.
func on_drug(drug: String, dose: float, route: String) -> void:
	physio.give(drug, dose, route)


func on_shock(_energy: int) -> void:
	pass


## Réponse du patient quand on le stimule (appel, pincement).
func stimulation_response() -> String:
	if physio.in_arrest():
		return "Aucune réaction. Il ne respire pas normalement."
	if physio.gcs >= 14:
		return "Il ouvre les yeux et vous répond."
	if physio.gcs >= 10:
		return "Il ouvre les yeux à l'appel, marmonne quelques mots."
	if physio.gcs >= 7:
		return "Il grogne et retire le bras à la douleur, sans ouvrir les yeux."
	return "Aucune ouverture des yeux, aucun son ; à peine une réaction à la douleur."


## Résultat d'un examen biologique (texte).
func lab(exam: String) -> String:
	match exam:
		"nfs":
			return "Hb 14,2 g/dL · leucocytes 8,1 G/L · plaquettes 245 G/L"
		"iono":
			return "Na 139 · K 4,1 · Cl 102 mmol/L · créatinine 82 µmol/L"
		"trop":
			return "Troponine Hs : 9 ng/L (N < 14)"
		"lact":
			return "Lactates : 1,4 mmol/L"
		"gds":
			return "pH 7,40 · PaCO2 39 mmHg · PaO2 92 mmHg · HCO3- 24 mmol/L"
		"bh":
			return "ASAT 24 · ALAT 21 UI/L · bilirubine 9 µmol/L · lipase 28 UI/L"
		"hemostase":
			return "TP 98 % · TCA 1,02"
		"crp":
			return "CRP < 4 mg/L"
		"tox":
			return "Toxiques urinaires : négatifs"
		"alcool":
			return "Alcoolémie : 0 g/L"
	return "—"


## ECG 12 dérivations : rythme, fréquence, anomalies (pour le tracé et le compte rendu).
func ecg12() -> Dictionary:
	return {"rhythm": physio.rhythm, "rate": physio.hr, "st": physio.stemi, "text": "Rythme sinusal, pas de trouble de la repolarisation."}


func xray() -> Dictionary:
	return {"tex": "", "text": "Radio du thorax : pas d'anomalie."}


## Ce qui est attendu (et noté) : [libellé, points, fait (bool), explication simple pour le bilan,
## « si besoin » (bool, facultatif : objectif conditionnel pas encore d'actualité, grisé dans la
## liste « À faire » au lieu d'être coché d'office)].
func objectives() -> Array:
	return []


## Erreurs propres au cas, ajoutées pendant la partie par le cas : [texte, points retirés].
var errors: Array = []


func fault(text: String, pts: float) -> void:
	for e in errors:
		if e[0] == text:
			return
	errors.append([text, pts])
	game.call("toast", text, false)
