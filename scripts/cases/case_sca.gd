class_name CaseSCA
extends Case
## Infarctus antérieur (syndrome coronarien aigu avec sus-décalage du ST) : douleur thoracique
## constrictive depuis une heure. Attendu : scope, ECG 12 dérivations dans les 10 minutes
## (sus-décalage antérieur), voie veineuse, aspirine, héparine, morphine si la douleur est forte,
## pas d'oxygène si la saturation est bonne, appel du cardiologue : coronarographie en urgence.
## Si l'on tarde, le cœur fibrille (vers 7 minutes) : il faut défibriller.

const VF_AT := 420.0
var _vf_done := false
var _shocked_ok := false


func _init() -> void:
	id = "sca_st"
	name = "Douleur thoracique"
	profile = {"name": "Jean-Pierre M.", "age": 62, "skin": Color(1.0, 0.93, 0.9), "hair": Color(0.55, 0.53, 0.5), "bald": 0.3, "stubble": 0.25, "collar": false,
		"reply": "Oui docteur… j'ai très mal à la poitrine…"}
	arrival = "Jean-Pierre, 62 ans, est amené par les pompiers pour une douleur dans la poitrine apparue il y a une heure, au repos, devant la télévision. Il est en sueurs et gris.\n\nIl est installé sur le brancard du déchocage. Rien n'est encore branché."
	arrival_vitals = "Pompiers : cœur 94/min (FC) · tension 152/94 (PA) · oxygène 96 % (SpO2) · respiration 20/min (FR) · douleur 8/10"
	questions = [
		["Où avez-vous mal ?", "Là, au milieu de la poitrine… ça serre comme un étau. Ça monte dans la mâchoire et le bras gauche."],
		["Depuis quand ?", "Ça a commencé il y a une heure, d'un coup, je regardais la télé."],
		["Avez-vous déjà eu ça ?", "Un peu en montant les escaliers ces dernières semaines, mais ça passait en m'arrêtant."],
		["Quels sont vos antécédents ?", "J'ai de la tension, du cholestérol… Je fume un paquet par jour depuis quarante ans."],
		["Quels médicaments prenez-vous ?", "De l'amlodipine pour la tension. C'est tout."],
		["Avez-vous des allergies ?", "Non, aucune."],
		["La douleur change-t-elle quand vous respirez ou bougez ?", "Non, elle est là tout le temps, pareille."],
		["Avez-vous du mal à respirer ?", "Un peu… surtout j'ai mal."],
	]
	lines = ["J'ai mal… ça serre, là, au milieu…", "Ça me prend dans la mâchoire…", "Docteur, c'est grave ? J'ai jamais eu aussi mal…", "J'ai envie de vomir…"]
	diag_ok = "Syndrome coronarien aigu avec sus-décalage du ST (infarctus)"
	orient_ok = "Salle de coronarographie (cardiologue appelé)"
	summary_good = "En salle de coronarographie, l'interventriculaire antérieure est débouchée et un stent posé. La douleur disparaît, le cœur est sauvé en grande partie."
	summary_bad = "Le cœur a manqué de sang trop longtemps."


func setup() -> void:
	physio.set_rhythm("sinus")
	physio.hr = 94.0
	physio.sys = 152.0
	physio.dia = 94.0
	physio.spo2 = 96.0
	physio.rr = 20.0
	physio.temp = 36.8
	physio.glyc = 1.42
	physio.pain = 8.0
	physio.stemi = "anterieur"
	physio.heart_sound = "normal"
	physio.base = {"hr": 94.0, "sys": 152.0, "dia": 94.0, "spo2": 96.0, "rr": 20.0, "temp": 36.8, "gcs": 15, "pain": 8.0, "o2_response": 0.5}
	physio.sign_base = {"pallor": 0.45, "cyanosis": 0.0, "sweat": 0.8, "mottling": 0.0, "urticaria": 0.0, "flush": 0.0}
	physio.signs = physio.sign_base.duplicate()
	physio.pupils = {"size": 3.0, "reactive": true}


func tick(_delta: float) -> void:
	var p: Patient = game.get("patient")
	if physio.in_arrest():
		p.resp_rate = 0.0
		return
	# La morphine calme la douleur, et avec elle la tachycardie et la tension
	var pain := maxf(0.0, 8.0 - 2.0 * float(physio.totals.get("morphine", 0.0)) / 2.5)
	physio.base["pain"] = pain
	if pain < 3.5:
		lines = ["Ça va mieux… merci docteur.", "J'ai encore un peu mal, mais c'est supportable."]
	physio.base["hr"] = 80.0 + pain * 2.0
	physio.base["sys"] = 125.0 + pain * 3.5
	physio.base["dia"] = 80.0 + pain * 1.5
	physio.base["rr"] = 16.0 + pain * 0.5
	p.resp_rate = physio.rr
	p.tidal = 0.9
	p.set_eyes_open(1.0)
	if not _vf_done and t() > VF_AT and not did("orient_ok"):
		_vf_done = true
		physio.set_rhythm("fv")
		game.call("say", "Docteur… je me sens partir…", "patient")
		game.call("event", "fv", "Le patient perd connaissance : fibrillation ventriculaire")
	if physio.rosc and not physio.in_arrest():
		physio.base["gcs"] = 14
		physio.base["hr"] = 98.0
		physio.base["sys"] = 118.0


func on_shock(_energy: int) -> void:
	if not physio.shockable():
		fault("Choc sur un cœur qui ne fibrillait pas (rythme non choquable)", 10.0)
		return
	# Fibrillation « primaire » d'un infarctus : le premier choc bien fait la réduit
	if not game.get("flags").get("pads_bad", false):
		physio.set_rhythm("sinus")
		physio.hr = 105.0
		physio.sys = 105.0
		physio.dia = 65.0
		_shocked_ok = true
		game.call("event", "racs", "Retour en rythme sinusal après le choc")
		game.call("say", "Qu'est-ce… qu'est-ce qui s'est passé ?", "patient")


func on_drug(drug: String, dose: float, route: String) -> void:
	physio.give(drug, dose, route)
	match drug:
		"adrenaline":
			if not physio.in_arrest():
				fault("Adrénaline chez un patient qui fait un infarctus et dont le cœur bat", 10.0)
				physio.base["hr"] = 140.0
		"morphine":
			if float(physio.totals.get("morphine", 0.0)) > 10.0:
				fault("Trop de morphine d'un coup (2 à 3 mg à la fois)", 4.0)
		"midazolam":
			fault("Calmant inutile (et dangereux)", 4.0)


func on_event(kind: String, _data: Dictionary) -> void:
	if kind.begins_with("o2_") and kind != "o2_debit" and physio.spo2 >= 94.0 and not physio.in_arrest():
		fault("Oxygène inutile : il en avait assez (94 % ou plus)", 2.0)


func lab(exam: String) -> String:
	match exam:
		"trop":
			return "Troponine Hs : 64 ng/L (N < 14) — encore peu élevée à une heure"
		"iono":
			return "Na 140 · K 3,9 · Cl 101 mmol/L · créatinine 91 µmol/L"
		"lact":
			return "Lactates : 1,8 mmol/L"
		"hemostase":
			return "TP 100 % · TCA 1,0 (avant héparine)"
	return super.lab(exam)


func ecg12() -> Dictionary:
	if physio.in_arrest():
		return {"rhythm": physio.rhythm, "rate": 0, "st": "", "text": "Fibrillation ventriculaire."}
	return {"rhythm": "sinus", "rate": physio.hr, "st": "anterieur",
		"text": "Rythme sinusal %d/min. Sus-décalage du ST de 3 mm de V1 à V4, miroir en DII DIII aVF : infarctus antérieur en cours." % int(physio.hr)}


func xray() -> Dictionary:
	return {"tex": "res://assets/textures/radio_normale.png", "text": "Radio du thorax : silhouette cardiaque normale, pas d'œdème, pas de pneumothorax."}


func objectives() -> Array:
	var ecg := when("ecg12")
	var morph_needed := true
	return [
		["Brancher le scope en moins de 3 minutes", 8.0, when("scope") < 180.0, "Un infarctus peut faire fibriller le cœur à tout moment : il faut le voir."],
		["Faire l'ECG en moins de 10 minutes", 18.0, ecg < 600.0, "L'électrocardiogramme montre l'artère bouchée : c'est lui qui déclenche l'urgence."],
		["L'interroger sur sa douleur (T)", 5.0, journal().count("question") >= 3, "Depuis quand, où, comment : ça confirme l'infarctus."],
		["Poser une voie veineuse", 6.0, did("vvp"), "Pour les médicaments."],
		["Aspirine dans la veine", 12.0, did("drug:aspirine"), "Elle empêche le caillot de grossir."],
		["Héparine dans la veine", 10.0, did("drug:heparine"), "Elle fluidifie le sang autour du caillot."],
		["Soulager la douleur (morphine, petites doses)", 6.0, did("drug:morphine") or not morph_needed, "La douleur fatigue le cœur ; par petites doses de 2 à 3 mg."],
		["Prise de sang : marqueur d'infarctus (troponine)", 4.0, did("exam:trop"), "Elle confirme que le muscle du cœur souffre."],
		["Choquer si le cœur fibrille", 10.0, not _vf_done or _shocked_ok, "Si le cœur se met à trembler, seul le choc électrique le sauve."],
		["Diagnostic : infarctus", 8.0, did("diag_ok"), "Dans le dossier (Tab), onglet Conclusion."],
		["L'envoyer déboucher son artère (coronarographie)", 13.0, did("orient_ok"), "Chaque minute compte : le muscle du cœur meurt tant que l'artère est bouchée."],
	]
