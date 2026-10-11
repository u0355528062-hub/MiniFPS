"""Synthèse des sons du jeu (numpy/scipy) : WAV 16 bits mono 44,1 kHz.

Bips de scope, alarmes (motifs proches de la norme IEC 60601-1-8), ambiance d'hôpital en
boucle, pas sur sol vinyle, porte coulissante, défibrillateur, sirènes (« pin-pon » des
pompiers, trois tons du SAMU), sons d'interface.
Usage : /opt/bpyenv/bin/python tools/sons/gen_sons.py   → assets/audio/*.wav
"""
import os
import wave

import numpy as np
from scipy import signal

SR = 44100
RACINE = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SORTIE = os.path.join(RACINE, "assets", "audio")
os.makedirs(SORTIE, exist_ok=True)
RNG = np.random.default_rng(3)


def t(d):
    return np.arange(int(d * SR)) / SR


def env(n, a=0.005, r=0.03):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na)
    if nr > 0:
        e[-nr:] = np.linspace(1, 0, nr)
    return e


def ecrire(nom, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = x / max(np.max(np.abs(x)), 1e-9) * gain
    with wave.open(os.path.join(SORTIE, nom + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("son", nom, "%.2f s" % (len(x) / SR))


def passe_bas(x, f, ordre=4):
    b, a = signal.butter(ordre, f / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def passe_bande(x, f1, f2, ordre=3):
    b, a = signal.butter(ordre, [f1 / (SR / 2), f2 / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def bruit_rose(n):
    b = RNG.standard_normal(n)
    F = np.fft.rfft(b)
    f = np.fft.rfftfreq(n, 1 / SR)
    F[1:] /= np.sqrt(f[1:])
    F[0] = 0
    return np.fft.irfft(F, n)


def bip(freq=980.0, duree=0.07):
    x = t(duree)
    s = np.sin(2 * np.pi * freq * x) + 0.25 * np.sin(2 * np.pi * freq * 2 * x)
    return s * env(len(x), 0.004, 0.025)


def alarme_haute():
    # Haute priorité : 2 salves de 5 impulsions (motif « 3 + 2 »), ton harmonique.
    out = []
    for salve in range(2):
        for k, f in enumerate([523, 659, 784, 659, 784]):
            out.append(bip(f, 0.12) * 1.0)
            out.append(np.zeros(int(0.06 * SR)))
            if k == 2:
                out.append(np.zeros(int(0.18 * SR)))
        out.append(np.zeros(int(0.6 * SR)))
    return np.concatenate(out)


def alarme_moyenne():
    out = []
    for f in [523, 659, 784]:
        out.append(bip(f, 0.18))
        out.append(np.zeros(int(0.1 * SR)))
    out.append(np.zeros(int(1.2 * SR)))
    return np.concatenate(out)


def ambiance(duree=40.0):
    n = int(duree * SR)
    x = t(duree)
    # Ventilation : souffle grave + ronronnement à 50/100 Hz.
    souffle = passe_bas(bruit_rose(n), 400) * 0.6
    hum = 0.05 * np.sin(2 * np.pi * 100 * x) + 0.03 * np.sin(2 * np.pi * 50 * x)
    s = souffle + hum
    # Murmures lointains : bruit filtré dans la bande de la voix, modulé en syllabes.
    for _ in range(14):
        d0 = RNG.uniform(0, duree - 4)
        d = RNG.uniform(1.5, 3.5)
        i0, i1 = int(d0 * SR), int((d0 + d) * SR)
        v = passe_bande(RNG.standard_normal(i1 - i0), 250, 1800)
        syl = 0.5 + 0.5 * np.sin(2 * np.pi * RNG.uniform(3.5, 5.5) * np.arange(i1 - i0) / SR) ** 2
        s[i0:i1] += v * syl * env(i1 - i0, 0.2, 0.4) * RNG.uniform(0.04, 0.09)
    # Bips lointains d'autres scopes et portes.
    for _ in range(10):
        p = int(RNG.uniform(0, duree - 1) * SR)
        b = bip(RNG.choice([880, 980, 1040]), 0.07) * 0.06
        s[p:p + len(b)] += passe_bas(b, 2500)
    # Fondu de boucle : début et fin raccordés.
    m = int(1.0 * SR)
    s[:m] = s[:m] * np.linspace(0, 1, m) + s[-m:] * np.linspace(1, 0, m)
    return s[:-m]


def pas(variante):
    rng = np.random.default_rng(variante)
    d = 0.16
    x = t(d)
    choc = passe_bas(rng.standard_normal(len(x)), 900) * np.exp(-x * 45)
    talon = np.sin(2 * np.pi * rng.uniform(70, 95) * x) * np.exp(-x * 60) * 0.6
    crissement = passe_bande(rng.standard_normal(len(x)), 2500, 6000) * np.exp(-((x - 0.05) / 0.02) ** 2) * 0.15
    return choc + talon + crissement


def porte():
    d = 1.6
    x = t(d)
    moteur = np.sin(2 * np.pi * (180 + 40 * np.sin(2 * np.pi * 0.6 * x)) * x) * 0.2
    glisse = passe_bande(RNG.standard_normal(len(x)), 200, 1500) * 0.5
    e = np.clip(np.minimum(x / 0.2, (d - x) / 0.3), 0, 1)
    fin = np.zeros(len(x))
    k = int(1.35 * SR)
    fin[k:] = passe_bas(RNG.standard_normal(len(x) - k), 300) * np.exp(-(x[k:] - 1.35) * 20) * 1.5
    return (moteur + glisse) * e + fin


def defib_charge():
    d = 2.6
    x = t(d)
    f = 600 + 2200 * (x / d) ** 1.4
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * 0.6 + 0.2 * signal.sawtooth(ph * 0.5)
    pret = np.zeros(len(x))
    b = np.concatenate([bip(1500, 0.08), np.zeros(int(0.06 * SR))])
    for k in range(3):
        i = int((d - 0.45) * SR) + k * len(b)
        n = min(len(b), len(x) - i)
        pret[i:i + n] += b[:n]
    return s * env(len(x), 0.05, 0.05) * (x < d - 0.5) + pret * 0.8


def defib_choc():
    d = 0.6
    x = t(d)
    claque = passe_bas(RNG.standard_normal(len(x)), 2500) * np.exp(-x * 25)
    sourd = np.sin(2 * np.pi * 55 * x) * np.exp(-x * 9)
    return claque + sourd * 1.5


def compression():
    d = 0.18
    x = t(d)
    return passe_bas(RNG.standard_normal(len(x)), 500) * np.exp(-x * 30) + np.sin(2 * np.pi * 90 * x) * np.exp(-x * 40) * 0.5


def sirene_pompiers(duree=8.0):
    # « Pin-pon » : alternance 435 / 488 Hz (timbre de trompe), 0,5 s par ton.
    x = t(duree)
    f = np.where((x % 1.0) < 0.5, 435.0, 488.0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = signal.square(ph) * 0.4 + np.sin(ph) * 0.6 + 0.3 * np.sin(2 * ph)
    return passe_bas(s, 3000)


def sirene_samu(duree=8.0):
    # Trois tons (avertisseur deux-tons modulé) : 435 / 580 / 435…
    x = t(duree)
    f = np.select([(x % 1.2) < 0.4, (x % 1.2) < 0.8], [435.0, 580.0], 488.0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return passe_bas(signal.square(ph) * 0.35 + np.sin(ph) * 0.65, 3000)


def respirateur():
    d = 4.0
    x = t(d)
    insp = passe_bande(RNG.standard_normal(len(x)), 300, 2500) * np.clip(np.sin(np.pi * x / 1.3), 0, 1) * (x < 1.3)
    clic = np.zeros(len(x))
    k = int(1.32 * SR)
    clic[k:k + 400] = np.sin(2 * np.pi * 900 * t(400 / SR)) * np.exp(-t(400 / SR) * 200)
    exp_ = passe_bande(RNG.standard_normal(len(x)), 150, 800) * np.clip(np.sin(np.pi * (x - 1.4) / 2.2), 0, 1) * (x > 1.4) * 0.5
    return insp + clic + exp_


def clic_ui():
    x = t(0.03)
    return np.sin(2 * np.pi * 2200 * x) * np.exp(-x * 200)


def notification():
    return np.concatenate([bip(880, 0.09), np.zeros(int(0.03 * SR)), bip(1320, 0.14)]) * 0.7


if __name__ == "__main__":
    for nom, f in (("bip_scope", 980.0),):
        ecrire(nom, bip(f, 0.07), 0.6)
    ecrire("alarme_haute", alarme_haute(), 0.7)
    ecrire("alarme_moyenne", alarme_moyenne(), 0.6)
    ecrire("ambiance_hopital", ambiance(), 0.5)
    for i in range(4):
        ecrire("pas_%d" % i, pas(i), 0.5)
    ecrire("porte", porte(), 0.6)
    ecrire("defib_charge", defib_charge(), 0.6)
    ecrire("defib_choc", defib_choc(), 0.9)
    ecrire("compression", compression(), 0.6)
    ecrire("sirene_pompiers", sirene_pompiers(), 0.7)
    ecrire("sirene_samu", sirene_samu(), 0.7)
    ecrire("respirateur", respirateur(), 0.4)
    ecrire("clic", clic_ui(), 0.4)
    ecrire("notification", notification(), 0.5)
