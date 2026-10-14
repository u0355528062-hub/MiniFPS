class_name Drugs
## Pharmacie du chariot d'urgence : présentations réelles (ampoules, flacons, poches), doses que l'on
## peut préparer, voies d'administration. La seringue préparée porte le nom, la dose et la voie.

## id -> {nom, présentation, unité, doses proposées, voies, couleur de l'étiquette}
const LIST := {
	"adrenaline": {"name": "Adrénaline", "pres": "ampoule 1 mg/1 mL", "unit": "mg", "doses": [0.5, 1.0], "routes": ["IV", "IM"], "col": Color(0.95, 0.35, 0.3)},
	"amiodarone": {"name": "Amiodarone", "pres": "ampoule 150 mg/3 mL", "unit": "mg", "doses": [150.0, 300.0], "routes": ["IV"], "col": Color(0.95, 0.6, 0.2)},
	"atropine": {"name": "Atropine", "pres": "ampoule 0,5 mg/1 mL", "unit": "mg", "doses": [0.5, 1.0], "routes": ["IV"], "col": Color(0.6, 0.85, 0.3)},
	"naloxone": {"name": "Naloxone", "pres": "ampoule 0,4 mg/1 mL", "unit": "mg", "doses": [0.04, 0.1, 0.4], "routes": ["IV", "IM"], "col": Color(0.4, 0.7, 0.95)},
	"glucose30": {"name": "Glucosé 30 %", "pres": "ampoule 3 g/10 mL", "unit": "g", "doses": [3.0, 6.0, 9.0], "routes": ["IV"], "col": Color(0.95, 0.9, 0.6)},
	"glucagon": {"name": "Glucagon", "pres": "kit 1 mg", "unit": "mg", "doses": [1.0], "routes": ["IM"], "col": Color(0.95, 0.75, 0.3)},
	"morphine": {"name": "Morphine", "pres": "ampoule 10 mg/1 mL (diluée)", "unit": "mg", "doses": [2.0, 3.0, 5.0], "routes": ["IV"], "col": Color(0.85, 0.85, 0.9)},
	"paracetamol": {"name": "Paracétamol", "pres": "flacon 1 g/100 mL", "unit": "g", "doses": [1.0], "routes": ["IV"], "col": Color(0.9, 0.9, 0.95)},
	"aspirine": {"name": "Aspirine (Kardégic IV)", "pres": "flacon 500 mg", "unit": "mg", "doses": [75.0, 250.0], "routes": ["IV"], "col": Color(0.95, 0.95, 0.95)},
	"heparine": {"name": "Héparine", "pres": "flacon 5000 UI/mL", "unit": "UI", "doses": [4000.0, 5000.0], "routes": ["IV"], "col": Color(0.5, 0.75, 0.95)},
	"salbutamol": {"name": "Salbutamol", "pres": "dosette nébulisation 5 mg", "unit": "mg", "doses": [2.5, 5.0], "routes": ["NEB"], "col": Color(0.3, 0.6, 0.95)},
	"ipratropium": {"name": "Ipratropium", "pres": "dosette nébulisation 0,5 mg", "unit": "mg", "doses": [0.5], "routes": ["NEB"], "col": Color(0.6, 0.6, 0.9)},
	"methylpred": {"name": "Méthylprednisolone", "pres": "flacon 40 mg", "unit": "mg", "doses": [40.0, 80.0], "routes": ["IV"], "col": Color(0.95, 0.85, 0.75)},
	"nacl": {"name": "NaCl 0,9 %", "pres": "poche 500 mL", "unit": "mL", "doses": [250.0, 500.0], "routes": ["PERF"], "col": Color(0.85, 0.92, 0.98)},
	"midazolam": {"name": "Midazolam", "pres": "ampoule 5 mg/1 mL", "unit": "mg", "doses": [1.0, 2.5, 5.0], "routes": ["IV", "IM"], "col": Color(0.95, 0.95, 0.6)},
	"furosemide": {"name": "Furosémide", "pres": "ampoule 20 mg/2 mL", "unit": "mg", "doses": [20.0, 40.0], "routes": ["IV"], "col": Color(0.75, 0.95, 0.75)},
}


static func name_of(id: String) -> String:
	return LIST[id]["name"] if LIST.has(id) else id


static func dose_text(id: String, dose: float) -> String:
	var unit: String = LIST[id]["unit"] if LIST.has(id) else ""
	var s := ("%d" % int(dose)) if absf(dose - roundf(dose)) < 0.001 else ("%.2f" % dose).rstrip("0").rstrip(".")
	return "%s %s" % [s.replace(".", ","), unit]


static func label(id: String, dose: float, route: String) -> String:
	return "%s %s %s" % [name_of(id), dose_text(id, dose), route]
