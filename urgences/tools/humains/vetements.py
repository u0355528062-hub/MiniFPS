"""Vêtements, chaussures et cheveux générés à partir du maillage du corps (numpy).

Un vêtement = un sous-ensemble des faces du corps (ou d'une aide MakeHuman comme la jupe),
décalé le long des normales, lissé (on efface muscles, nombril…), avec les poids de peau du
corps. Les UV sont celles du corps : une texture de vêtement sert donc à TOUS les personnages.
"""
import heapq

import numpy as np

from mh_donnees import base, poids_peau

def _main(c):
    return (["metacarpal%d.%s" % (i, c) for i in range(1, 5)]
            + ["finger%d-%d.%s" % (i, j, c) for i in range(1, 6) for j in range(1, 4)])


def _pied(c):
    return ["toe%d-%d.%s" % (i, j, c) for i in range(1, 6) for j in range(1, 4)]


VISAGE = ["head", "jaw", "neck02", "neck03", "eye.L", "eye.R", "special04", "special05.L", "special05.R",
          "special06.L", "special06.R", "oris01", "oris02", "oris05", "oris06"] + [
    "%s%02d.%s" % (b, i, c) for b in ("levator", "orbicularis", "oculi", "risorius", "temporalis", "oris")
    for i in range(1, 8) for c in "LR"] + ["tongue%02d" % i for i in range(5)]

GROUPES_OS = {
    "bras_g": ["shoulder01.L", "upperarm01.L", "upperarm02.L", "lowerarm01.L", "lowerarm02.L", "wrist.L"] + _main("L"),
    "bras_d": ["shoulder01.R", "upperarm01.R", "upperarm02.R", "lowerarm01.R", "lowerarm02.R", "wrist.R"] + _main("R"),
    "jambe_g": ["upperleg01.L", "upperleg02.L", "lowerleg01.L", "lowerleg02.L", "foot.L"] + _pied("L"),
    "jambe_d": ["upperleg01.R", "upperleg02.R", "lowerleg01.R", "lowerleg02.R", "foot.R"] + _pied("R"),
    "tete": VISAGE,
}


def ligne_cheveux(co, art, coupe="court"):
    """Hauteur de la lisière du cuir chevelu en fonction de l'angle autour de la tête.
    Renvoie (hauteur limite par sommet, angle phi : 0 devant, ±pi derrière)."""
    tete = art["head____head"]
    oeil_y = 0.5 * (art["eye.L____head"][1] + art["eye.R____head"][1])
    phi = np.arctan2(co[:, 0] - tete[0], co[:, 2] - (tete[2] + 0.02))
    a = np.abs(phi)
    pts_a = np.array([0.0, 0.55, 0.95, 1.3, 1.6, 2.0, 2.4, np.pi])
    nuque = tete[1] - (0.035 if coupe == "long" else 0.0)
    pts_h = np.array([oeil_y + 0.072, oeil_y + 0.065, oeil_y + 0.035, oeil_y + 0.012, oeil_y + 0.008,
                      oeil_y - 0.030, nuque + 0.01, nuque])
    return np.interp(a, pts_a, pts_h), phi


def matrice_poids(n):
    """Poids de peau sous forme dense {os: (n,) array}."""
    res = {}
    for os_, liste in poids_peau().items():
        a = np.zeros(n, dtype=np.float32)
        for i, w in liste:
            if i < n:
                a[i] = w
        res[os_] = a
    return res


def appartenance(poids, groupe):
    tot = np.zeros_like(next(iter(poids.values())))
    for o in GROUPES_OS[groupe]:
        if o in poids:
            tot += poids[o]
    return tot


def param_membre(co, a, b):
    """Paramètre t de projection sur le segment a→b (0 en a, 1 en b)."""
    ab = b - a
    return ((co - a) @ ab) / (ab @ ab)


def normales(co, faces):
    n = np.zeros_like(co)
    a, b_, c, d = (co[faces[:, i]] for i in range(4))
    fn = np.cross(c - a, d - b_)
    for i in range(4):
        np.add.at(n, faces[:, i], fn)
    l = np.linalg.norm(n, axis=1, keepdims=True)
    return n / np.maximum(l, 1e-12)


def voisins(faces, n):
    """Liste d'adjacence (arêtes des quads)."""
    vois = [set() for _ in range(n)]
    for f in faces:
        for i in range(4):
            a, b_ = f[i], f[(i + 1) % 4]
            vois[a].add(b_)
            vois[b_].add(a)
    return vois


def distance_bord(co, faces, sel_v):
    """Distance géodésique (le long des arêtes) de chaque sommet sélectionné au bord de la sélection."""
    n = len(co)
    vois = voisins(faces, n)
    dist = np.full(n, np.inf)
    tas = []
    for v in np.nonzero(sel_v)[0]:
        if any(not sel_v[u] for u in vois[v]):
            dist[v] = 0.0
            tas.append((0.0, v))
    heapq.heapify(tas)
    while tas:
        d, v = heapq.heappop(tas)
        if d > dist[v]:
            continue
        for u in vois[v]:
            if not sel_v[u]:
                continue
            nd = d + np.linalg.norm(co[u] - co[v])
            if nd < dist[u]:
                dist[u] = nd
                heapq.heappush(tas, (nd, u))
    return dist


def lisser(co, faces, sel, iterations=10, facteur=0.5, fixes=None):
    """Lissage laplacien des sommets sélectionnés (efface le relief anatomique)."""
    n = len(co)
    vois = voisins(faces, n)
    idx = np.nonzero(sel)[0]
    listes = [np.array(sorted(vois[i])) for i in idx]
    co = co.copy()
    for _ in range(iterations):
        nouveau = co.copy()
        for k, i in enumerate(idx):
            if fixes is not None and fixes[i]:
                continue
            l = listes[k]
            if len(l):
                nouveau[i] = co[i] * (1 - facteur) + co[l].mean(axis=0) * facteur
        co = nouveau
    return co


class Vetement:
    """Résultat : sommets, faces (quads), uv par coin, indices des sommets du corps d'origine."""

    def __init__(self, nom, materiau, co, faces, fuv, origine, poids_src=None):
        self.nom = nom
        self.materiau = materiau
        self.co = co
        self.faces = faces
        self.fuv = fuv
        self.origine = origine          # index du sommet source (corps ou aide) pour les poids
        self.poids_src = poids_src
        self.uvs = None                 # UV par coin explicites (sinon celles de l'atlas du corps)


def extraire(co_tout, faces_src, fuv_src, sel_f, decalage, lissage=8, nom="vetement", materiau="tissu",
             plancher=0.004):
    """Crée un vêtement à partir des faces sélectionnées. decalage : (n,) en mètres par sommet."""
    faces = faces_src[sel_f]
    fuv = fuv_src[sel_f]
    used = np.unique(faces.ravel())
    remap = -np.ones(len(co_tout), dtype=np.int64)
    remap[used] = np.arange(len(used))
    co = co_tout[used]
    f2 = remap[faces]
    nrm = normales(co, f2)
    dec = decalage[used]
    g = co + nrm * dec[:, None]
    sel = np.ones(len(co), dtype=bool)
    # Bords : on lisse moins pour ne pas rétrécir les ourlets.
    g = lisser(g, f2, sel, lissage, 0.5)
    # Garantit un écart minimal au corps (évite que la peau traverse).
    ecart = ((g - co) * nrm).sum(1)
    manque = np.clip(plancher + dec * 0.5 - ecart, 0, None)
    g = g + nrm * manque[:, None]
    return Vetement(nom, materiau, g, f2, fuv, used)


# ---------------------------------------------------------------------------------------------
class Habilleur:
    """Prépare les données du corps d'un personnage et fabrique ses vêtements."""

    def __init__(self, co_m, art_m):
        """co_m : coordonnées (m, repère MakeHuman Y haut) de TOUS les sommets ; art_m : articulations."""
        self.b = base()
        self.co = co_m
        self.art = art_m
        self.n = len(co_m)
        self.poids = matrice_poids(self.n)
        self.f_corps = self.b.faces_groupe("body")
        self.faces = self.b.faces
        self.fuv = self.b.fuv
        nb = 13380
        self.m = {k: appartenance(self.poids, k) for k in GROUPES_OS}
        self.est_corps = np.zeros(self.n, dtype=bool)
        self.est_corps[:nb] = True
        self.masques = []   # sommets couverts (pour masquer la peau dessous)

    def a(self, nom):
        return self.art[nom]

    def _bras(self, cote):
        s = self.a("upperarm01.%s____head" % cote)
        c = self.a("lowerarm01.%s____head" % cote)
        p = self.a("wrist.%s____head" % cote)
        t1 = param_membre(self.co, s, c)
        t2 = param_membre(self.co, c, p)
        return np.where(t1 < 1.0, t1, 1.0 + t2)  # 0 épaule, 1 coude, 2 poignet

    def _jambe(self, cote):
        h = self.a("upperleg01.%s____head" % cote)
        k = self.a("lowerleg01.%s____head" % cote)
        f = self.a("foot.%s____head" % cote)
        t1 = param_membre(self.co, h, k)
        t2 = param_membre(self.co, k, f)
        return np.where(t1 < 1.0, t1, 1.0 + t2)  # 0 hanche, 1 genou, 2 cheville

    def _faces_de(self, sel_v, faces_idx=None):
        fi = self.f_corps if faces_idx is None else faces_idx
        f = self.faces[fi]
        ok = sel_v[f].all(axis=1)
        m = np.zeros(len(self.faces), dtype=bool)
        m[fi[ok]] = True
        return m

    # --- Hauts -------------------------------------------------------------------------------
    def haut(self, materiau, manches=0.45, bas=0.09, col_v=0.10, ample=0.018, nom="haut"):
        """Haut (tunique de pyjama, tee-shirt…). manches : 0..2 (2 = jusqu'au poignet).
        bas : hauteur sous la taille (m) ; col_v : profondeur du col en V."""
        co = self.co
        y = co[:, 1]
        taille_y = self.a("spine05____head")[1]
        cou = self.a("neck01____head")
        bras_g = self.m["bras_g"] > 0.5
        bras_d = self.m["bras_d"] > 0.5
        jambes = (self.m["jambe_g"] + self.m["jambe_d"]) > 0.6
        tete = self.m["tete"] > 0.3
        sel = (~jambes) & (~tete) & self.est_corps & (y > taille_y - bas)
        sel &= np.where(bras_g, self._bras("L") < manches, True)
        sel &= np.where(bras_d, self._bras("R") < manches, True)
        # Encolure : au-dessus de la base du cou, et col en V devant.
        sel &= y < cou[1] + 0.01
        devant = co[:, 2] > cou[2]
        v = (cou[1] - y) < (col_v - np.abs(co[:, 0] - cou[0]) * 2.2)
        sel &= ~(devant & v)
        sel_f = self._faces_de(sel)
        dec = np.full(self.n, ample, dtype=np.float32)
        dec += 0.012 * np.clip((taille_y + 0.05 - y) / 0.2, 0, 1)   # plus ample en bas
        v = extraire(co, self.faces, self.fuv, sel_f, dec, 10, nom, materiau)
        self.masques.append((sel, 0.015))
        return v

    def pantalon(self, materiau, longueur=1.92, ample=0.016, nom="pantalon"):
        co = self.co
        y = co[:, 1]
        taille_y = self.a("spine05____head")[1] + 0.02
        jg = self.m["jambe_g"] > 0.5
        jd = self.m["jambe_d"] > 0.5
        sel = self.est_corps & (y < taille_y) & ~((self.m["bras_g"] + self.m["bras_d"]) > 0.2)
        sel &= np.where(jg, self._jambe("L") < longueur, True)
        sel &= np.where(jd, self._jambe("R") < longueur, True)
        sel_f = self._faces_de(sel)
        dec = np.full(self.n, ample, dtype=np.float32)
        tj = np.where(jg, self._jambe("L"), np.where(jd, self._jambe("R"), 0.0))
        dec += 0.012 * np.clip(tj - 1.0, 0, 1)  # bas de jambe plus large
        v = extraire(co, self.faces, self.fuv, sel_f, dec, 10, nom, materiau)
        self.masques.append((sel, 0.015))
        return v

    def jupe_aide(self, materiau, bas_genou=0.25, ample=0.02, nom="jupe"):
        """Partie basse d'une blouse (patient, médecin) à partir de l'aide « helper-skirt »."""
        fi = self.b.groupes["helper-skirt"]
        sel_v = np.zeros(self.n, dtype=bool)
        sel_v[np.unique(self.faces[fi].ravel())] = True
        genou = 0.5 * (self.a("lowerleg01.L____head")[1] + self.a("lowerleg01.R____head")[1])
        sel_v &= self.co[:, 1] > genou - bas_genou
        sel_f = np.zeros(len(self.faces), dtype=bool)
        f = self.faces[fi]
        sel_f[fi[sel_v[f].all(axis=1)]] = True
        dec = np.full(self.n, ample, dtype=np.float32)
        return extraire(self.co, self.faces, self.fuv, sel_f, dec, 4, nom, materiau, plancher=0.0)

    def chaussures(self, materiau, hauteur=0.09, nom="chaussures"):
        co = self.co
        sel = np.zeros(self.n, dtype=bool)
        for c in ("L", "R"):
            f = self.a("foot.%s____head" % c)
            sel |= (self.m["jambe_" + ("g" if c == "L" else "d")] > 0.3) & (co[:, 1] < f[1] + hauteur - 0.07)
        sel &= self.est_corps
        sel_f = self._faces_de(sel)
        dec = np.full(self.n, 0.008, dtype=np.float32)
        v = extraire(co, self.faces, self.fuv, sel_f, dec, 6, nom, materiau)
        # Semelle : aplatit le dessous et l'élargit un peu.
        sol = co[:, 1].min()
        bas = v.co[:, 1] < sol + 0.012
        v.co[bas, 1] = sol - 0.004
        self.masques.append((sel, 0.01))
        return v

    def cheveux(self, materiau, coupe="court", volume=0.012, nom="cheveux"):
        """Calotte de cheveux sur le cuir chevelu (sommets proches de l'aide « helper-hair »)."""
        from mh_textures import masque_cible
        co = self.co
        y = co[:, 1]
        limite, _ = ligne_cheveux(co, self.art, coupe)
        oreilles = np.maximum(masque_cible("ears/l-ear-scale-incr", 1.0, self.n), masque_cible("ears/r-ear-scale-incr", 1.0, self.n))
        # La calotte déborde de 1,5 cm sous la lisière : la texture (alpha) dessine la vraie lisière.
        sel = self.est_corps & (y > limite - 0.015) & (self.m["tete"] > 0.5)
        # Le cuir chevelu de MakeHuman est peu dense : on garde toute face qui touche la zone
        # (la texture, avec son alpha, dessine la lisière exacte), sauf le pavillon de l'oreille.
        f = self.faces[self.f_corps]
        garde = sel[f].any(axis=1) & ~(oreilles[f] > 0.6).any(axis=1)
        sel_f = np.zeros(len(self.faces), dtype=bool)
        sel_f[self.f_corps[garde]] = True
        oeil_y = 0.5 * (self.a("eye.L____head")[1] + self.a("eye.R____head")[1])
        dec = np.full(self.n, volume, dtype=np.float32)
        # Plus de volume sur le dessus, presque rien sur la lisière.
        dec += volume * 0.8 * np.clip((y - oeil_y - 0.06) / 0.06, 0, 1)
        dec *= np.clip((y - limite + 0.015) / 0.03, 0.15, 1.0)
        v = extraire(co, self.faces, self.fuv, sel_f, dec, 6, nom, materiau)
        return v

    def chignon(self, materiau, rayon=0.042, nom="Chignon"):
        """Chignon (cheveux attachés) : ellipsoïde derrière la tête, lié à l'os de la tête."""
        co = self.co
        tete = self.a("head____head")
        oeil_y = 0.5 * (self.a("eye.L____head")[1] + self.a("eye.R____head")[1])
        cy = oeil_y + 0.005
        zone = self.est_corps & (np.abs(co[:, 0] - tete[0]) < 0.02) & (np.abs(co[:, 1] - cy) < 0.025)
        idx = np.nonzero(zone)[0]
        arriere = idx[np.argmin(co[idx, 2])]
        centre = co[arriere] + np.array([0.0, 0.0, -rayon * 0.55])
        nl, nm = 10, 16
        pts, uvs_v = [], []
        b = self.b
        # UV de la zone de cuir chevelu derrière la tête (texture de cheveux opaque).
        fi = np.nonzero((b.faces[self.f_corps] == arriere).any(axis=1))[0][0]
        f = self.f_corps[fi]
        k = list(b.faces[f]).index(arriere)
        uv0 = b.vt[b.fuv[f][k]]
        for i in range(nl + 1):
            th = np.pi * i / nl
            for j in range(nm):
                ph = 2 * np.pi * j / nm
                d = np.array([np.sin(th) * np.cos(ph), np.cos(th), np.sin(th) * np.sin(ph)])
                pts.append(centre + d * rayon * np.array([1.15, 0.85, 0.9]))
                uvs_v.append(uv0 + 0.012 * np.array([np.cos(ph), np.sin(ph)]) * np.sin(th))
        faces, fuv = [], []
        for i in range(nl):
            for j in range(nm):
                a_ = i * nm + j
                b_ = i * nm + (j + 1) % nm
                c_ = (i + 1) * nm + (j + 1) % nm
                d_ = (i + 1) * nm + j
                faces.append([a_, d_, c_, b_])
        faces = np.array(faces)
        uvs = np.array(uvs_v)[faces]
        v = Vetement(nom, materiau, np.array(pts), faces, None, np.full(len(pts), arriere))
        v.uvs = uvs
        return v

    def faces_corps_visibles(self):
        """Faces du corps à garder : on retire celles entièrement couvertes (loin des bords)."""
        cache = np.zeros(self.n, dtype=bool)
        for sel, marge in self.masques:
            db = distance_bord(self.co, self.faces[self.f_corps], sel)
            cache |= sel & (db > marge)
        f = self.faces[self.f_corps]
        couvert = cache[f].all(axis=1)
        return self.f_corps[~couvert]
