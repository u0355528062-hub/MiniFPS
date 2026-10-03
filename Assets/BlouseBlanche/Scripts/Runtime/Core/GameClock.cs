using System;
using UnityEngine;

namespace BlouseBlanche.Core
{
    /// <summary>
    /// Horloge de jeu, en minutes depuis minuit.
    /// En exploration : 1 seconde réelle = 10 secondes de jeu.
    /// En consultation l'horloge est figée et avance au rythme des actions médicales.
    /// </summary>
    public sealed class GameClock
    {
        public const float GameMinutesPerRealSecond = 1f / 6f;

        public float Minutes { get; private set; }
        public bool Running { get; set; }

        public event Action<float> Advanced; // delta minutes

        public void Set(float minutes)
        {
            Minutes = minutes;
        }

        public void Tick(float realDeltaSeconds)
        {
            if (!Running || realDeltaSeconds <= 0f) return;
            Advance(realDeltaSeconds * GameMinutesPerRealSecond);
        }

        public void Advance(float minutes)
        {
            if (minutes <= 0f) return;
            Minutes += minutes;
            Advanced?.Invoke(minutes);
        }

        public static string Format(float minutes)
        {
            int total = Mathf.FloorToInt(minutes);
            int h = (total / 60) % 24;
            int m = total % 60;
            return h.ToString("00") + ":" + m.ToString("00");
        }

        /// <summary>Format "9h05" plus naturel pour les dialogues.</summary>
        public static string FormatSpoken(float minutes)
        {
            int total = Mathf.FloorToInt(minutes);
            int h = (total / 60) % 24;
            int m = total % 60;
            return m == 0 ? h + "h" : h + "h" + m.ToString("00");
        }

        public static float At(int hours, int minutes) => hours * 60f + minutes;
    }
}
