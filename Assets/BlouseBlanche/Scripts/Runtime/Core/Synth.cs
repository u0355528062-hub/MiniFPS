using System;

namespace BlouseBlanche.Core
{
    /// <summary>
    /// Petite bibliothèque de synthèse sonore (pure C#, aucun asset).
    /// Toutes les fonctions renvoient des échantillons mono en [-1, 1].
    /// </summary>
    public static class Synth
    {
        public const int Rate = 44100;
        const float TwoPi = (float)(Math.PI * 2.0);

        static float Sin(float phase) => (float)Math.Sin(phase);
        static float Exp(float x) => (float)Math.Exp(x);

        static float[] Buffer(float seconds, int rate = Rate) => new float[Math.Max(1, (int)(seconds * rate))];

        static void Normalize(float[] b, float peak)
        {
            float max = 0f;
            for (int i = 0; i < b.Length; i++) max = Math.Max(max, Math.Abs(b[i]));
            if (max < 1e-6f) return;
            float k = peak / max;
            for (int i = 0; i < b.Length; i++) b[i] *= k;
        }

        static void FadeEdges(float[] b, float fadeIn, float fadeOut, int rate = Rate)
        {
            int fi = Math.Min(b.Length, (int)(fadeIn * rate));
            int fo = Math.Min(b.Length, (int)(fadeOut * rate));
            for (int i = 0; i < fi; i++) b[i] *= i / (float)fi;
            for (int i = 0; i < fo; i++) b[b.Length - 1 - i] *= i / (float)fo;
        }

        /// <summary>Note "cloche" avec partiels inharmoniques.</summary>
        static void AddBell(float[] b, int start, float freq, float amp, float decay, int rate = Rate)
        {
            float[] ratios = { 1f, 2.0f, 2.76f, 5.4f };
            float[] amps = { 1f, 0.35f, 0.22f, 0.08f };
            for (int i = start; i < b.Length; i++)
            {
                float t = (i - start) / (float)rate;
                float env = Exp(-t / decay) * Math.Min(1f, t * 400f);
                if (env < 0.0005f) break;
                float s = 0f;
                for (int p = 0; p < ratios.Length; p++)
                    s += amps[p] * Sin(TwoPi * freq * ratios[p] * t) * Exp(-t * p * 1.5f);
                b[i] += s * env * amp;
            }
        }

        static void AddTone(float[] b, int start, float seconds, float freq, float amp, float attack, float release, float harmonics = 0f)
        {
            int n = (int)(seconds * Rate);
            for (int k = 0; k < n && start + k < b.Length; k++)
            {
                float t = k / (float)Rate;
                float env = Math.Min(1f, t / Math.Max(attack, 1e-4f)) * Math.Min(1f, (seconds - t) / Math.Max(release, 1e-4f));
                float s = Sin(TwoPi * freq * t) + harmonics * Sin(TwoPi * freq * 3f * t) / 3f;
                b[start + k] += s * env * amp;
            }
        }

        static void AddThump(float[] b, int start, float freq, float amp, float decay)
        {
            for (int i = start; i < b.Length; i++)
            {
                float t = (i - start) / (float)Rate;
                float env = Exp(-t / decay) * Math.Min(1f, t * 600f);
                if (env < 0.0005f) break;
                float f = freq * (1f + 0.6f * Exp(-t * 40f)); // léger pitch-drop
                b[i] += Sin(TwoPi * f * t) * env * amp;
            }
        }

        static void AddNoiseBurst(float[] b, int start, float seconds, float amp, float lowpass, float attack, float decay, Random rng, float highpass = 0f)
        {
            int n = (int)(seconds * Rate);
            float lp = 0f, hpPrev = 0f, hpOut = 0f;
            float a = Clamp01(lowpass);
            for (int k = 0; k < n && start + k < b.Length; k++)
            {
                float t = k / (float)Rate;
                float env = Math.Min(1f, t / Math.Max(attack, 1e-4f)) * Exp(-t / Math.Max(decay, 1e-4f));
                float w = (float)(rng.NextDouble() * 2.0 - 1.0);
                lp += a * (w - lp);
                float s = lp;
                if (highpass > 0f)
                {
                    hpOut = highpass * (hpOut + s - hpPrev);
                    hpPrev = s;
                    s = hpOut;
                }
                b[start + k] += s * env * amp;
            }
        }

        static float Clamp01(float v) => v < 0f ? 0f : (v > 1f ? 1f : v);

        // ------------------------------------------------------------------ UI

        public static float[] UiHover()
        {
            var b = Buffer(0.05f);
            AddTone(b, 0, 0.05f, 1900f, 0.5f, 0.002f, 0.045f);
            Normalize(b, 0.25f);
            return b;
        }

        public static float[] UiClick()
        {
            var b = Buffer(0.09f);
            AddTone(b, 0, 0.08f, 1150f, 0.6f, 0.001f, 0.075f, 0.3f);
            AddTone(b, 0, 0.03f, 2300f, 0.25f, 0.001f, 0.028f);
            Normalize(b, 0.45f);
            return b;
        }

        public static float[] UiConfirm()
        {
            var b = Buffer(0.32f);
            AddBell(b, 0, 880f, 0.5f, 0.12f);
            AddBell(b, (int)(0.08f * Rate), 1318.5f, 0.5f, 0.18f);
            Normalize(b, 0.5f);
            return b;
        }

        public static float[] UiBack()
        {
            var b = Buffer(0.25f);
            AddBell(b, 0, 1046.5f, 0.45f, 0.1f);
            AddBell(b, (int)(0.07f * Rate), 784f, 0.45f, 0.14f);
            Normalize(b, 0.4f);
            return b;
        }

        public static float[] Notify()
        {
            var b = Buffer(1.3f);
            AddBell(b, 0, 1046.5f, 0.6f, 0.35f);
            AddBell(b, (int)(0.14f * Rate), 1568f, 0.55f, 0.5f);
            Normalize(b, 0.55f);
            return b;
        }

        public static float[] Urgent()
        {
            var b = Buffer(1.25f);
            for (int r = 0; r < 2; r++)
                for (int i = 0; i < 3; i++)
                    AddTone(b, (int)((r * 0.62f + i * 0.17f) * Rate), 0.11f, 960f, 0.6f, 0.004f, 0.02f, 0.5f);
            Normalize(b, 0.6f);
            return b;
        }

        public static float[] StingerSuccess()
        {
            var b = Buffer(1.6f);
            float[] notes = { 523.25f, 659.25f, 783.99f, 1046.5f };
            for (int i = 0; i < notes.Length; i++) AddBell(b, (int)(i * 0.11f * Rate), notes[i], 0.5f, 0.55f);
            Normalize(b, 0.5f);
            return b;
        }

        public static float[] StingerFail()
        {
            var b = Buffer(1.5f);
            float[] notes = { 440f, 349.23f, 293.66f };
            for (int i = 0; i < notes.Length; i++) AddBell(b, (int)(i * 0.16f * Rate), notes[i], 0.5f, 0.5f);
            Normalize(b, 0.45f);
            return b;
        }

        // ------------------------------------------------------------------ Monde

        public static float[] Footstep(int seed)
        {
            var rng = new Random(seed);
            var b = Buffer(0.16f);
            AddNoiseBurst(b, 0, 0.14f, 0.7f, 0.22f + (float)rng.NextDouble() * 0.1f, 0.002f, 0.025f, rng);
            AddNoiseBurst(b, (int)(0.012f * Rate), 0.06f, 0.25f, 0.6f, 0.001f, 0.01f, rng, 0.8f);
            AddThump(b, 0, 85f + (float)rng.NextDouble() * 20f, 0.6f, 0.03f);
            Normalize(b, 0.5f);
            return b;
        }

        public static float[] DoorOpen()
        {
            var rng = new Random(11);
            var b = Buffer(0.9f);
            AddNoiseBurst(b, 0, 0.02f, 0.5f, 0.9f, 0.0005f, 0.004f, rng, 0.7f); // loquet
            for (int i = 0; i < b.Length; i++)
            {
                float t = i / (float)Rate;
                if (t < 0.05f || t > 0.8f) continue;
                float env = (float)Math.Sin(Math.PI * (t - 0.05f) / 0.75f);
                float f = 260f + 140f * t;
                b[i] += 0.06f * env * Sin(TwoPi * f * t) * (0.6f + 0.4f * Sin(TwoPi * 23f * t));
            }
            AddNoiseBurst(b, (int)(0.04f * Rate), 0.7f, 0.25f, 0.05f, 0.15f, 0.3f, rng);
            Normalize(b, 0.45f);
            return b;
        }

        public static float[] DoorClose()
        {
            var rng = new Random(12);
            var b = Buffer(0.45f);
            AddNoiseBurst(b, 0, 0.25f, 0.3f, 0.06f, 0.08f, 0.1f, rng);
            int hit = (int)(0.2f * Rate);
            AddThump(b, hit, 70f, 0.9f, 0.07f);
            AddNoiseBurst(b, hit, 0.05f, 0.5f, 0.8f, 0.0005f, 0.008f, rng, 0.6f);
            Normalize(b, 0.5f);
            return b;
        }

        public static float[] SlidingDoor()
        {
            var rng = new Random(13);
            var b = Buffer(1.1f);
            for (int i = 0; i < b.Length; i++)
            {
                float t = i / (float)Rate;
                float env = (float)Math.Sin(Math.PI * Math.Min(1.0, t / 1.05));
                b[i] += 0.05f * env * (Sin(TwoPi * 118f * t) + 0.4f * Sin(TwoPi * 236f * t));
            }
            AddNoiseBurst(b, 0, 1.05f, 0.35f, 0.04f, 0.3f, 0.6f, rng);
            Normalize(b, 0.35f);
            return b;
        }

        public static float[] EntranceChime()
        {
            var b = Buffer(2.0f);
            AddBell(b, 0, 659.25f, 0.6f, 0.6f);
            AddBell(b, (int)(0.45f * Rate), 523.25f, 0.6f, 0.75f);
            Normalize(b, 0.5f);
            return b;
        }

        public static float[] Heartbeat()
        {
            var b = Buffer(0.86f); // ~70 bpm, bouclable
            AddThump(b, (int)(0.02f * Rate), 55f, 1f, 0.06f);
            AddThump(b, (int)(0.17f * Rate), 72f, 0.7f, 0.05f);
            Normalize(b, 0.8f);
            return b;
        }

        public static float[] BloodPressurePump()
        {
            var rng = new Random(21);
            var b = Buffer(3.2f);
            for (int i = 0; i < 6; i++)
                AddNoiseBurst(b, (int)((0.05f + i * 0.28f) * Rate), 0.16f, 0.6f, 0.12f, 0.02f, 0.05f, rng);
            AddNoiseBurst(b, (int)(1.85f * Rate), 1.3f, 0.35f, 0.5f, 0.05f, 0.6f, rng, 0.9f); // dégonflage
            Normalize(b, 0.4f);
            return b;
        }

        public static float[] DeviceBeep()
        {
            var b = Buffer(0.4f);
            AddTone(b, 0, 0.09f, 2400f, 0.5f, 0.002f, 0.01f);
            AddTone(b, (int)(0.16f * Rate), 0.09f, 2400f, 0.5f, 0.002f, 0.01f);
            Normalize(b, 0.35f);
            return b;
        }

        public static float[] Cough(int seed)
        {
            var rng = new Random(seed);
            var b = Buffer(0.75f);
            for (int k = 0; k < 2; k++)
            {
                int s = (int)((k * 0.3f) * Rate);
                AddNoiseBurst(b, s, 0.25f, 0.9f, 0.25f, 0.004f, 0.06f, rng);
                AddNoiseBurst(b, s, 0.2f, 0.4f, 0.6f, 0.003f, 0.04f, rng, 0.85f);
                AddThump(b, s, 140f, 0.3f, 0.04f);
            }
            Normalize(b, 0.55f);
            return b;
        }

        public static float[] Typing()
        {
            var rng = new Random(31);
            var b = Buffer(3f);
            float t = 0.05f;
            while (t < 2.9f)
            {
                AddNoiseBurst(b, (int)(t * Rate), 0.03f, 0.5f, 0.7f, 0.0005f, 0.006f, rng, 0.7f);
                t += 0.07f + (float)rng.NextDouble() * 0.16f;
                if (rng.NextDouble() < 0.08) t += 0.4f;
            }
            Normalize(b, 0.3f);
            return b;
        }

        public static float[] WaterRunning()
        {
            var rng = new Random(41);
            var b = Buffer(3f);
            float lp = 0f;
            for (int i = 0; i < b.Length; i++)
            {
                float t = i / (float)Rate;
                float w = (float)(rng.NextDouble() * 2.0 - 1.0);
                lp += 0.35f * (w - lp);
                float mod = 0.75f + 0.25f * Sin(TwoPi * 7.3f * t) * Sin(TwoPi * 1.1f * t);
                b[i] = (w * 0.3f + lp * 0.7f) * mod;
            }
            FadeEdges(b, 0.15f, 0.35f);
            Normalize(b, 0.35f);
            return b;
        }

        public static float[] CoffeeMachine()
        {
            var rng = new Random(51);
            var b = Buffer(3.5f);
            for (int i = 0; i < b.Length; i++)
            {
                float t = i / (float)Rate;
                float buzz = Sin(TwoPi * 60f * t);
                buzz = buzz > 0 ? 0.6f : -0.6f;
                float env = Math.Min(1f, t * 8f) * Math.Min(1f, (3.4f - t) * 4f);
                b[i] += 0.12f * buzz * env * (t < 2.2f ? 1f : 0.3f);
            }
            AddNoiseBurst(b, (int)(1.2f * Rate), 2.1f, 0.4f, 0.15f, 0.2f, 1.2f, rng);
            Normalize(b, 0.35f);
            return b;
        }

        public static float[] PenScribble()
        {
            var rng = new Random(61);
            var b = Buffer(1.3f);
            for (int k = 0; k < 7; k++)
                AddNoiseBurst(b, (int)((0.05f + k * 0.17f) * Rate), 0.12f, 0.6f, 0.9f, 0.01f, 0.05f, rng, 0.95f);
            Normalize(b, 0.25f);
            return b;
        }

        public static float[] PaperSwish()
        {
            var rng = new Random(71);
            var b = Buffer(0.35f);
            AddNoiseBurst(b, 0, 0.32f, 0.6f, 0.5f, 0.06f, 0.08f, rng, 0.9f);
            Normalize(b, 0.25f);
            return b;
        }

        // ------------------------------------------------------------------ Ambiances (boucles)

        /// <summary>Ronronnement de pièce (ventilation) bouclable.</summary>
        public static float[] RoomTone()
        {
            var rng = new Random(81);
            var b = Buffer(6f);
            float brown = 0f;
            for (int i = 0; i < b.Length; i++)
            {
                float t = i / (float)Rate;
                float w = (float)(rng.NextDouble() * 2.0 - 1.0);
                brown = (brown + 0.02f * w) / 1.02f;
                b[i] = brown * 3.5f + 0.015f * Sin(TwoPi * 50f * t) + 0.008f * Sin(TwoPi * 100f * t);
            }
            b = MakeLoopable(b, 0.5f);
            Normalize(b, 0.25f);
            return b;
        }

        /// <summary>Extérieur : vent léger + oiseaux.</summary>
        public static float[] Outdoor()
        {
            var rng = new Random(91);
            var b = Buffer(10f);
            float lp = 0f;
            for (int i = 0; i < b.Length; i++)
            {
                float t = i / (float)Rate;
                float w = (float)(rng.NextDouble() * 2.0 - 1.0);
                lp += 0.02f * (w - lp);
                b[i] = lp * 2.2f * (0.7f + 0.3f * Sin(TwoPi * 0.13f * t));
            }
            // gazouillis
            for (int c = 0; c < 18; c++)
            {
                int start = (int)(rng.NextDouble() * (b.Length - Rate));
                float f0 = 2800f + (float)rng.NextDouble() * 2200f;
                int notes = 2 + rng.Next(4);
                for (int n = 0; n < notes; n++)
                {
                    int s = start + (int)(n * 0.11f * Rate);
                    int len = (int)(0.07f * Rate);
                    for (int k = 0; k < len && s + k < b.Length; k++)
                    {
                        float t = k / (float)Rate;
                        float env = (float)Math.Sin(Math.PI * k / len);
                        float f = f0 * (1f + 0.25f * (float)Math.Sin(TwoPi * 18f * t)) + n * 120f;
                        b[s + k] += 0.05f * env * Sin(TwoPi * f * t);
                    }
                }
            }
            b = MakeLoopable(b, 0.8f);
            Normalize(b, 0.3f);
            return b;
        }

        /// <summary>Musique de menu : nappe ambient douce (Cmaj9 - Am9 - Fmaj7 - G6/9), 32 s, bouclable.</summary>
        // ------------------------------------------------------------------ urgences

        /// <summary>Bip QRS du scope (un par battement).</summary>
        public static float[] ScopeBeep()
        {
            var b = Buffer(0.14f);
            AddTone(b, 0, 0.11f, 988f, 0.6f, 0.003f, 0.05f, 0.15f);
            Normalize(b, 0.3f);
            return b;
        }

        /// <summary>Alarme haute priorité du moniteur (trois notes descendantes, bouclable).</summary>
        public static float[] MonitorAlarm()
        {
            var b = Buffer(1.8f);
            float[] f = { 988f, 784f, 659f, 988f, 784f };
            float[] at = { 0f, 0.14f, 0.28f, 0.62f, 0.76f };
            for (int i = 0; i < f.Length; i++) AddTone(b, (int)(at[i] * Rate), 0.11f, f[i], 0.5f, 0.004f, 0.03f, 0.3f);
            Normalize(b, 0.32f);
            return b;
        }

        /// <summary>Charge du défibrillateur : sifflement montant puis signal « prêt ».</summary>
        public static float[] DefibCharge()
        {
            var b = Buffer(2.0f);
            float phase = 0f;
            int n = (int)(1.5f * Rate);
            for (int i = 0; i < n; i++)
            {
                float t = i / (float)Rate;
                float k = t / 1.5f;
                float f = 520f + 2900f * k * k;
                phase += TwoPi * f / Rate;
                float env = Math.Min(1f, t * 20f) * (0.35f + 0.65f * k);
                b[i] += (Sin(phase) + 0.2f * Sin(phase * 2f)) * env * 0.5f;
            }
            for (int k = 0; k < 2; k++) AddTone(b, (int)((1.55f + k * 0.22f) * Rate), 0.12f, 1568f, 0.55f, 0.003f, 0.02f);
            Normalize(b, 0.4f);
            return b;
        }

        /// <summary>Décharge électrique : claquement sourd et soubresaut.</summary>
        public static float[] DefibShock()
        {
            var rng = new Random(77);
            var b = Buffer(0.7f);
            AddNoiseBurst(b, 0, 0.12f, 1f, 0.9f, 0.0008f, 0.025f, rng, 0.6f);
            AddThump(b, 0, 48f, 1f, 0.12f);
            AddNoiseBurst(b, (int)(0.04f * Rate), 0.5f, 0.35f, 0.12f, 0.01f, 0.18f, rng);
            Normalize(b, 0.85f);
            return b;
        }

        /// <summary>Compression thoracique (bruit étouffé, tissu).</summary>
        public static float[] Compression()
        {
            var rng = new Random(91);
            var b = Buffer(0.22f);
            AddThump(b, 0, 82f, 0.8f, 0.045f);
            AddNoiseBurst(b, 0, 0.14f, 0.35f, 0.18f, 0.004f, 0.04f, rng);
            Normalize(b, 0.4f);
            return b;
        }

        /// <summary>Insufflation au ballon autoremplisseur.</summary>
        public static float[] BagValve()
        {
            var rng = new Random(57);
            var b = Buffer(1.1f);
            AddNoiseBurst(b, 0, 0.55f, 0.6f, 0.3f, 0.12f, 0.35f, rng);
            AddNoiseBurst(b, (int)(0.6f * Rate), 0.45f, 0.3f, 0.2f, 0.05f, 0.25f, rng);
            FadeEdges(b, 0.02f, 0.1f);
            Normalize(b, 0.3f);
            return b;
        }

        /// <summary>Deux-tons d'ambulance au loin (bouclable).</summary>
        public static float[] Siren()
        {
            var b = Buffer(2.4f);
            float phase = 0f;
            for (int i = 0; i < b.Length; i++)
            {
                float t = i / (float)Rate;
                float f = (int)(t / 0.6f) % 2 == 0 ? 435f : 651f;
                phase += TwoPi * f / Rate;
                float s = Sin(phase) + 0.45f * Sin(phase * 2f) + 0.2f * Sin(phase * 3f);
                b[i] = s * 0.3f;
            }
            Normalize(b, 0.35f);
            return b;
        }

        public static float[] MenuMusic(out int sampleRate)
        {
            sampleRate = 22050;
            int rate = sampleRate;
            float chordLen = 8f;
            float[][] chords =
            {
                new[] { 130.81f, 196.00f, 246.94f, 293.66f, 329.63f },
                new[] { 110.00f, 164.81f, 196.00f, 246.94f, 261.63f },
                new[] { 87.31f, 130.81f, 164.81f, 220.00f, 246.94f },
                new[] { 98.00f, 146.83f, 220.00f, 246.94f, 329.63f },
            };
            int total = (int)(chordLen * chords.Length * rate);
            var b = new float[total];
            var rng = new Random(101);
            float[] detune = { -0.0025f, 0f, 0.0031f };

            for (int c = 0; c < chords.Length; c++)
            {
                int start = (int)(c * chordLen * rate);
                int len = (int)((chordLen + 3f) * rate); // la queue déborde sur l'accord suivant (et boucle)
                foreach (float f in chords[c])
                {
                    for (int d = 0; d < detune.Length; d++)
                    {
                        float freq = f * (1f + detune[d]);
                        float ph = (float)rng.NextDouble() * TwoPi;
                        for (int k = 0; k < len; k++)
                        {
                            float t = k / (float)rate;
                            float env = Math.Min(1f, t / 2.2f) * Math.Min(1f, Math.Max(0f, (chordLen + 3f - t) / 3.5f));
                            float s = Sin(TwoPi * freq * t + ph) * 0.8f + Sin(TwoPi * freq * 2f * t + ph) * 0.12f;
                            b[(start + k) % total] += s * env * 0.05f;
                        }
                    }
                }
                // quelques notes "cristal" sur les notes de l'accord
                for (int n = 0; n < 5; n++)
                {
                    float f = chords[c][1 + rng.Next(4)] * 4f;
                    int s = start + (int)((0.5f + rng.NextDouble() * 7f) * rate);
                    int len2 = (int)(2.5f * rate);
                    for (int k = 0; k < len2; k++)
                    {
                        float t = k / (float)rate;
                        float env = Exp(-t / 0.7f) * Math.Min(1f, t * 300f);
                        b[(s + k) % total] += 0.035f * env * (Sin(TwoPi * f * t) + 0.3f * Sin(TwoPi * f * 2.01f * t));
                    }
                }
            }
            // tremolo très léger
            for (int i = 0; i < total; i++)
            {
                float t = i / (float)rate;
                b[i] *= 0.92f + 0.08f * Sin(TwoPi * 0.125f * t);
            }
            Normalize(b, 0.45f);
            return b;
        }

        /// <summary>
        /// Rend un tampon bouclable sans clic : la fin est fondue dans le début puis retirée,
        /// de sorte que le dernier échantillon enchaîne naturellement sur le premier.
        /// </summary>
        static float[] MakeLoopable(float[] b, float crossSeconds)
        {
            int n = Math.Min(b.Length / 3, (int)(crossSeconds * Rate));
            if (n <= 0) return b;
            int len = b.Length - n;
            var o = new float[len];
            Array.Copy(b, o, len);
            for (int i = 0; i < n; i++)
            {
                float a = i / (float)n;
                o[i] = b[i] * a + b[len + i] * (1f - a);
            }
            return o;
        }
    }
}
