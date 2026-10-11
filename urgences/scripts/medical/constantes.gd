class_name Constantes
extends RefCounted
## Constantes vitales d'un patient, avec une variabilité physiologique douce.
## Les « vraies » valeurs évoluent en continu ; ce que le soignant connaît, ce sont les
## MESURES (dictionnaire mesures), prises avec le matériel (brassard, oxymètre…).

signal mesure_prise(nom: String, valeur)

var fc := 78.0            # fréquence cardiaque (/min)
var tas := 128.0          # tension systolique (mmHg)
var tad := 78.0           # tension diastolique (mmHg)
var spo2 := 98.0          # saturation (%)
var fr := 16.0            # fréquence respiratoire (/min)
var temperature := 36.8   # °C
var glycemie := 1.05      # g/L
var eva := 0              # douleur (0..10)
var glasgow := 15
var rythme := "sinusal"   # sinusal, fa, tv, fv, asystolie, bav3
var sus_st := 0.0         # sus-décalage du segment ST (mV) — infarctus

## Cibles vers lesquelles les valeurs dérivent (le scénario les modifie).
var cibles := {}
## Mesures connues du soignant : nom -> {valeur, heure}.
var mesures := {}

var _t := 0.0


func _init(valeurs := {}) -> void:
	for k in valeurs:
		set(k, valeurs[k])
	for k in ["fc", "tas", "tad", "spo2", "fr", "temperature", "glycemie"]:
		cibles[k] = get(k)


func avancer(delta: float) -> void:
	_t += delta
	for k in cibles:
		var v: float = get(k)
		var c: float = cibles[k]
		set(k, lerpf(v, c, clampf(delta * 0.05, 0.0, 1.0)))
	# Petites oscillations (respiration, variabilité sinusale).
	fc = clampf(fc + sin(_t * 0.31) * 0.02 + randf_range(-0.05, 0.05), 20.0, 230.0)
	spo2 = clampf(spo2 + randf_range(-0.03, 0.03), 50.0, 100.0)


func valeur(nom: String):
	match nom:
		"fc": return int(round(fc))
		"ta": return "%d/%d" % [int(round(tas)), int(round(tad))]
		"pam": return int(round((tas + 2.0 * tad) / 3.0))
		"spo2": return int(round(spo2))
		"fr": return int(round(fr))
		"temperature": return snappedf(temperature, 0.1)
		"glycemie": return snappedf(glycemie, 0.01)
		"eva": return eva
		"glasgow": return glasgow
	return null


func mesurer(nom: String, heure: String) -> void:
	var v = valeur(nom)
	mesures[nom] = {"valeur": v, "heure": heure}
	mesure_prise.emit(nom, v)


static func texte(nom: String, v) -> String:
	match nom:
		"fc": return "%s /min" % v
		"ta": return "%s mmHg" % v
		"spo2": return "%s %%" % v
		"fr": return "%s /min" % v
		"temperature": return ("%.1f °C" % v).replace(".", ",")
		"glycemie": return ("%.2f g/L" % v).replace(".", ",")
		"eva": return "%s / 10" % v
		"glasgow": return "%s / 15" % v
	return str(v)


const NOMS := {
	"fc": "Fréquence cardiaque", "ta": "Pression artérielle", "spo2": "Saturation (SpO₂)",
	"fr": "Fréquence respiratoire", "temperature": "Température", "glycemie": "Glycémie capillaire",
	"eva": "Douleur (EVA)", "glasgow": "Score de Glasgow",
}
