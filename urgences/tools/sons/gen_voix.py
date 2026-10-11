"""Synthèse vocale des répliques (Piper, voix françaises CC : siwis = femme, gilles = homme).

Prérequis : venv /opt/piperenv avec piper-tts ; voix dans $PIPER_VOIX (par défaut /tmp/dl/piper),
téléchargées depuis https://github.com/rhasspy/piper/releases/tag/v0.0.2.
Étapes : godot --headless --script tools/sons/extraire_repliques.gd
         /opt/piperenv/bin/python tools/sons/gen_voix.py
Sortie : assets/audio/voix/{h|f}_<md5>.ogg (Ogg Vorbis mono 22 kHz).
"""
import json
import os
import re
import subprocess
import tempfile
import wave

from piper import PiperVoice, SynthesisConfig

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.normpath(os.path.join(ICI, "..", ".."))
SORTIE = os.path.join(RACINE, "assets", "audio", "voix")
VOIX = os.environ.get("PIPER_VOIX", "/tmp/dl/piper")
MODELES = {
    "h": os.path.join(VOIX, "voice-fr-gilles-low", "fr-gilles-low.onnx"),
    "f": os.path.join(VOIX, "voice-fr-siwis-medium", "fr-siwis-medium.onnx"),
}


def nettoyer(t):
    # Les didascalies entre parenthèses ne se prononcent pas ; points de suspension → pause.
    t = re.sub(r"\([^)]*\)", "", t)
    t = t.replace("…", ", ").replace("«", "").replace("»", "")
    t = re.sub(r"\s+", " ", t).strip(" ,")
    return t or "Hmm."


def main():
    os.makedirs(SORTIE, exist_ok=True)
    repliques = json.load(open(os.path.join(ICI, "repliques.json"), encoding="utf-8"))
    attendus = set()
    for genre, modele in MODELES.items():
        voix = PiperVoice.load(modele)
        cfg = SynthesisConfig(length_scale=1.08, noise_scale=0.6, noise_w_scale=0.7)
        for r in repliques:
            nom = "%s_%s.ogg" % (genre, r["md5"])
            attendus.add(nom)
            chemin = os.path.join(SORTIE, nom)
            if os.path.exists(chemin):
                continue
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                with wave.open(tmp.name, "wb") as w:
                    voix.synthesize_wav(nettoyer(r["texte"]), w, syn_config=cfg)
                # Égalisation « téléphone de chambre » évitée : léger passe-haut + normalisation.
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-af",
                                "highpass=f=90,loudnorm=I=-18:TP=-2", "-ar", "22050", "-ac", "1",
                                "-c:a", "libvorbis", "-q:a", "3", chemin], check=True)
                os.unlink(tmp.name)
            print(nom, r["texte"][:60])
    for f in os.listdir(SORTIE):
        if f.endswith(".ogg") and f not in attendus:
            os.remove(os.path.join(SORTIE, f))


if __name__ == "__main__":
    main()
