"""Lecture des données MakeHuman (CC0) : maillage de base, morphoses, squelette, poids, proxys.

Les données viennent du dépôt github.com/makehumancommunity/makehuman (dossier makehuman/data),
publiées sous licence CC0. Chemin attendu : variable MH_DATA ou /tmp/dl/mh/makehuman/data.
Unités MakeHuman : décimètres, Y vers le haut, personnage regardant +Z.
"""
import json
import os
from functools import lru_cache

import numpy as np

MH = os.environ.get("MH_DATA", "/tmp/dl/mh/makehuman/data")


# ---------------------------------------------------------------------------------------------
class Base:
    """Maillage de base hm08 : sommets, UV, faces (quads) et groupes de faces."""

    def __init__(self):
        v, vt, faces, fuv, groupes = [], [], [], [], {}
        g = None
        for l in open(os.path.join(MH, "3dobjs", "base.obj")):
            if l.startswith("v "):
                v.append([float(x) for x in l.split()[1:4]])
            elif l.startswith("vt "):
                vt.append([float(x) for x in l.split()[1:3]])
            elif l.startswith("g "):
                g = l.split()[1]
            elif l.startswith("f "):
                t = [p.split("/") for p in l.split()[1:]]
                groupes.setdefault(g, []).append(len(faces))
                faces.append([int(a[0]) - 1 for a in t])
                fuv.append([int(a[1]) - 1 for a in t])
        self.v = np.array(v, dtype=np.float64)
        self.vt = np.array(vt, dtype=np.float64)
        self.faces = np.array(faces, dtype=np.int64)
        self.fuv = np.array(fuv, dtype=np.int64)
        self.groupes = {k: np.array(i) for k, i in groupes.items()}

    def faces_groupe(self, *noms):
        idx = np.concatenate([self.groupes[n] for n in noms])
        return np.sort(idx)


@lru_cache(maxsize=None)
def base():
    return Base()


@lru_cache(maxsize=512)
def cible(chemin):
    """Charge une morphose (.target) : (indices, déplacements). Fichier absent → None."""
    p = os.path.join(MH, "targets", chemin)
    if not p.endswith(".target"):
        p += ".target"
    if not os.path.exists(p):
        return None
    idx, d = [], []
    for l in open(p):
        if not l.strip() or l.startswith("#"):
            continue
        t = l.split()
        idx.append(int(t[0]))
        d.append([float(t[1]), float(t[2]), float(t[3])])
    if not idx:
        return None
    return np.array(idx), np.array(d)


# ---------------------------------------------------------------------------------------------
def poids_macro(p):
    """Reproduit le calcul des poids des macro-morphoses de MakeHuman (apps/human.py)."""
    g = p.get("genre", 0.5)          # 0 femme, 1 homme
    a = p.get("age", 0.5)            # 0 = 1 an, 0.1875 = 11 ans, 0.5 = 25 ans, 1 = 90 ans
    m = p.get("muscle", 0.5)
    w = p.get("poids", 0.5)
    h = p.get("taille", 0.5)
    pr = p.get("proportions", 0.5)
    v = {"male": g, "female": 1 - g}
    if a < 0.5:
        v["old"] = 0.0
        v["baby"] = max(0.0, 1 - a * 5.333)
        v["young"] = max(0.0, (a - 0.1875) * 3.2)
        v["child"] = max(0.0, min(1.0, 5.333 * a) - v["young"])
    else:
        v["child"] = v["baby"] = 0.0
        v["old"] = max(0.0, a * 2 - 1)
        v["young"] = 1 - v["old"]
    v["maxmuscle"] = max(0.0, m * 2 - 1)
    v["minmuscle"] = max(0.0, 1 - m * 2)
    v["averagemuscle"] = 1 - (v["maxmuscle"] + v["minmuscle"])
    v["maxweight"] = max(0.0, w * 2 - 1)
    v["minweight"] = max(0.0, 1 - w * 2)
    v["averageweight"] = 1 - (v["maxweight"] + v["minweight"])
    v["maxheight"] = max(0.0, h * 2 - 1)
    v["minheight"] = max(0.0, 1 - h * 2)
    v["idealproportions"] = max(0.0, pr * 2 - 1)
    v["uncommonproportions"] = max(0.0, 1 - pr * 2)
    eth = p.get("origines", {"caucasian": 1 / 3, "african": 1 / 3, "asian": 1 / 3})
    s = sum(eth.values())
    for e in ("african", "asian", "caucasian"):
        v[e] = eth.get(e, 0.0) / s
    cibles = {}
    G, A, M, W = ("female", "male"), ("baby", "child", "young", "old"), \
        ("minmuscle", "averagemuscle", "maxmuscle"), ("minweight", "averageweight", "maxweight")
    for gg in G:
        for aa in A:
            base_ga = v[gg] * v[aa]
            if base_ga <= 0:
                continue
            for e in ("african", "asian", "caucasian"):
                if v[e] > 0:
                    cibles["macrodetails/%s-%s-%s" % (e, gg, aa)] = base_ga * v[e]
            for mm in M:
                for ww in W:
                    k = base_ga * v[mm] * v[ww]
                    if k <= 0:
                        continue
                    cibles["macrodetails/universal-%s-%s-%s-%s" % (gg, aa, mm, ww)] = k
                    for hh in ("minheight", "maxheight"):
                        if v[hh] > 0:
                            cibles["macrodetails/height/%s-%s-%s-%s-%s" % (gg, aa, mm, ww, hh)] = k * v[hh]
                    for pp in ("idealproportions", "uncommonproportions"):
                        if v[pp] > 0:
                            cibles["macrodetails/proportions/%s-%s-%s-%s-%s" % (gg, aa, mm, ww, pp)] = k * v[pp]
    return cibles


def morpher(params):
    """Renvoie les coordonnées (décimètres, repère MakeHuman) d'un humain paramétré.
    params : genre, age, muscle, poids, taille, proportions, origines, details {cible: poids}."""
    b = base()
    co = b.v.copy()
    cibles = poids_macro(params)
    for nom, k in params.get("details", {}).items():
        cibles[nom] = cibles.get(nom, 0.0) + k
    for nom, k in cibles.items():
        t = cible(nom)
        if t is None or abs(k) < 1e-6:
            continue
        co[t[0]] += k * t[1]
    return co


# ---------------------------------------------------------------------------------------------
@lru_cache(maxsize=None)
def squelette():
    return json.load(open(os.path.join(MH, "rigs", "default.mhskel")))


@lru_cache(maxsize=None)
def poids_peau():
    return json.load(open(os.path.join(MH, "rigs", "default_weights.mhw")))["weights"]


def articulations(co):
    """Position de chaque articulation (moyenne des sommets de référence)."""
    sq = squelette()
    return {nom: co[np.array(idx)].mean(axis=0) for nom, idx in sq["joints"].items()}


def os_squelette(co):
    """Liste ordonnée (parents d'abord) : (nom, parent, tête, queue, normale du plan de rotation)."""
    sq = squelette()
    art = articulations(co)
    os_ = sq["bones"]
    ordre, vus = [], set()

    def ajouter(n):
        if n in vus:
            return
        p = os_[n]["parent"]
        if p:
            ajouter(p)
        vus.add(n)
        ordre.append(n)

    for n in os_:
        ajouter(n)
    res = []
    for n in ordre:
        d = os_[n]
        tete = art[d["head"]]
        queue = art[d["tail"]]
        plan = sq["planes"].get(d["rotation_plane"]) if d.get("rotation_plane") else None
        normale = None
        if plan:
            a, b_, c = (art[j] for j in plan)
            normale = np.cross(b_ - a, c - b_)
            nn = np.linalg.norm(normale)
            normale = normale / nn if nn > 1e-9 else None
        res.append((n, d["parent"], tete, queue, normale))
    return res


# ---------------------------------------------------------------------------------------------
class Proxy:
    """Proxy MakeHuman (.mhclo) : maillage ajusté sur 3 sommets du corps + décalage."""

    def __init__(self, chemin):
        self.dossier = os.path.dirname(chemin)
        self.refs, self.poids, self.decal = [], [], []
        self.echelles = {}
        self.obj = None
        mode = None
        for l in open(chemin):
            t = l.split()
            if not t or t[0].startswith("#"):
                continue
            if t[0] == "obj_file":
                self.obj = os.path.join(self.dossier, t[1])
            elif t[0] in ("x_scale", "y_scale", "z_scale"):
                self.echelles[t[0][0]] = (int(t[1]), int(t[2]), float(t[3]))
            elif t[0] == "verts":
                mode = "v"
            elif mode == "v":
                if len(t) == 9:
                    self.refs.append([int(t[0]), int(t[1]), int(t[2])])
                    self.poids.append([float(t[3]), float(t[4]), float(t[5])])
                    self.decal.append([float(t[6]), float(t[7]), float(t[8])])
                elif len(t) == 1 and t[0].isdigit():
                    self.refs.append([int(t[0])] * 3)
                    self.poids.append([1.0, 0, 0])
                    self.decal.append([0, 0, 0])
                else:
                    mode = None
        self.refs = np.array(self.refs)
        self.poids = np.array(self.poids)
        self.decal = np.array(self.decal)
        # Maillage du proxy.
        v, vt, f, fuv = [], [], [], []
        for l in open(self.obj):
            if l.startswith("v "):
                v.append([float(x) for x in l.split()[1:4]])
            elif l.startswith("vt "):
                vt.append([float(x) for x in l.split()[1:3]])
            elif l.startswith("f "):
                tt = [p.split("/") for p in l.split()[1:]]
                f.append([int(a[0]) - 1 for a in tt])
                fuv.append([int(a[1]) - 1 for a in tt])
        self.vt = np.array(vt)
        self.faces = f
        self.fuv = fuv

    def ajuster(self, co):
        e = np.ones(3)
        for i, ax in enumerate("xyz"):
            if ax in self.echelles:
                a, b, den = self.echelles[ax]
                e[i] = abs(co[a][i] - co[b][i]) / den
        r = self.refs
        w = self.poids
        return (co[r[:, 0]] * w[:, 0:1] + co[r[:, 1]] * w[:, 1:2] + co[r[:, 2]] * w[:, 2:3]) + self.decal * e
