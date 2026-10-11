class_name Repliques
## Répliques parlées hors pathologies (douleur, collègues) : centralisées ici pour que
## l'outil de synthèse vocale (tools/sons/gen_voix.py) les retrouve toutes.

const NE_SAIS_PAS := "Je ne sais pas trop…"

const COLLEGUE_DEBUT := ["Je m'en occupe.", "J'y vais.", "D'accord, j'y vais tout de suite.", "Ça marche, je m'en charge."]
const COLLEGUE_FIN := ["C'est fait.", "Voilà, c'est fait.", "C'est bon, c'est fait docteur."]
const BRANCARDIER_DEBUT := ["Je l'emmène.", "J'arrive avec le brancard.", "C'est parti, je l'emmène."]


## Réponse à l'échelle de douleur (EVA) selon la note de 0 à 10.
static func eva(n: int) -> String:
	if n <= 2:
		return "Ça va, j'ai à peine mal… %d sur dix." % n
	var t := "Sur dix ? Je dirais %d." % n
	if n >= 7:
		t += " C'est vraiment très fort."
	return t


## Toutes les répliques fixes (pour la synthèse vocale).
static func toutes() -> Array:
	var r: Array = [NE_SAIS_PAS]
	r.append_array(COLLEGUE_DEBUT)
	r.append_array(COLLEGUE_FIN)
	r.append_array(BRANCARDIER_DEBUT)
	for n in 11:
		r.append(eva(n))
	return r
