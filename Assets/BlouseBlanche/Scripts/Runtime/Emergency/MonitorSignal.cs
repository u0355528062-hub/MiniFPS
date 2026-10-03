using System;
using UnityEngine;

namespace BlouseBlanche.Emergency
{
    /// <summary>
    /// Générateur de tracés de scope (ECG, pléthysmographie, respiration) en balayage, comme un vrai moniteur :
    /// les échantillons sont écrits à la position du curseur, une petite zone effacée le précède.
    /// Le tracé défile en temps réel, indépendamment de l'accélération du temps de jeu.
    /// </summary>
    public sealed class MonitorSignal
    {
        public const int SampleRate = 100;
        public const int Samples = 500;            // 5 secondes affichées
        public const int Gap = 14;                 // zone effacée devant le curseur

        public readonly float[] Ecg = new float[Samples];
        public readonly float[] Pleth = new float[Samples];
        public readonly float[] Resp = new float[Samples];
        public int Cursor { get; private set; }
        public bool Connected;

        /// <summary>Battement détecté (pic R) : bip du scope.</summary>
        public event Action Beat;

        readonly System.Random rng;
        float acc;
        float t;
        float beatClock = 10f, rr = 0.8f;
        float respPhase;
        float plethClock = 10f;
        bool beatFired;
        float fvPhase1, fvPhase2, fvPhase3, fvAmp = 1f;

        public MonitorSignal(int seed)
        {
            rng = new System.Random(seed);
            for (int i = 0; i < Samples; i++) Ecg[i] = Pleth[i] = Resp[i] = float.NaN;
        }

        public bool IsGap(int i)
        {
            int d = (i - Cursor + Samples) % Samples;
            return d < Gap;
        }

        public void Tick(float realDt, PatientState s, bool cpr, bool bavu, bool stElevation)
        {
            acc += realDt * SampleRate;
            int n = Mathf.Min(SampleRate, (int)acc);
            acc -= n;
            for (int k = 0; k < n; k++) Step(s, cpr, bavu, stElevation);
        }

        void Step(PatientState s, bool cpr, bool bavu, bool st)
        {
            const float dt = 1f / SampleRate;
            t += dt;
            float ecg, pleth, resp;

            if (!Connected)
            {
                ecg = pleth = resp = float.NaN;
            }
            else
            {
                bool beats = s.Alive && s.Pulse && s.Hr > 1f;
                // ------------------------------------------------ ECG
                if (beats)
                {
                    beatClock += dt;
                    if (beatClock >= rr)
                    {
                        beatClock -= rr;
                        float baseRr = 60f / Mathf.Max(20f, s.Hr);
                        rr = s.Rhythm == Rhythm.FibrillationAtriale ? baseRr * (0.7f + (float)rng.NextDouble() * 0.6f) : baseRr * (0.97f + (float)rng.NextDouble() * 0.06f);
                        beatFired = false;
                        plethClock = 0f;
                    }
                    ecg = Pqrst(beatClock, rr, s.Rhythm != Rhythm.FibrillationAtriale, st);
                    if (s.Rhythm == Rhythm.FibrillationAtriale) ecg += 0.05f * Mathf.Sin(t * 37f) + 0.03f * Mathf.Sin(t * 53f + 1f);
                    if (!beatFired && beatClock >= 0.18f) { beatFired = true; Beat?.Invoke(); }
                }
                else if (s.Rhythm == Rhythm.FibrillationVentriculaire && s.Alive)
                {
                    fvPhase1 += dt * 2f * Mathf.PI * 4.6f;
                    fvPhase2 += dt * 2f * Mathf.PI * 6.1f;
                    fvPhase3 += dt * 2f * Mathf.PI * 2.9f;
                    fvAmp = Mathf.Clamp(fvAmp + ((float)rng.NextDouble() - 0.5f) * 0.08f, 0.35f, 1f);
                    float coarse = Mathf.Clamp01(1f - s.NoFlowMinutes / 9f) * 0.6f + 0.25f;
                    ecg = coarse * fvAmp * (0.55f * Mathf.Sin(fvPhase1) + 0.3f * Mathf.Sin(fvPhase2) + 0.25f * Mathf.Sin(fvPhase3));
                }
                else
                {
                    ecg = 0.02f * Mathf.Sin(t * 1.3f) + ((float)rng.NextDouble() - 0.5f) * 0.015f;
                }

                // Artefact de massage cardiaque
                if (cpr)
                {
                    float c = Mathf.Repeat(t * 1.85f, 1f);
                    ecg += c < 0.45f ? Mathf.Sin(c / 0.45f * Mathf.PI) * 0.75f : -0.12f * Mathf.Sin((c - 0.45f) / 0.55f * Mathf.PI);
                }

                // ------------------------------------------------ pléthysmographie (SpO2)
                if (beats && s.Spo2 > 50f)
                {
                    plethClock += dt;
                    float perf = Mathf.Clamp01((s.Sys - 40f) / 80f) * 0.8f + 0.2f;
                    pleth = PlethShape(plethClock - 0.22f, rr) * perf;
                }
                else if (cpr)
                {
                    float c = Mathf.Repeat(t * 1.85f - 0.2f, 1f);
                    pleth = c < 0.5f ? Mathf.Sin(c / 0.5f * Mathf.PI) * 0.3f : 0f;
                }
                else pleth = ((float)rng.NextDouble() - 0.5f) * 0.02f;

                // ------------------------------------------------ respiration
                float rate = s.Rr;
                if (bavu && (s.Breathing == Breathing.Absente || !s.Pulse || s.Rr < 6f)) rate = 10f;
                if (rate > 0.5f && s.Breathing != Breathing.Absente || bavu)
                {
                    respPhase += dt * Mathf.Max(rate, 0.1f) / 60f;
                    resp = Mathf.Sin(respPhase * 2f * Mathf.PI) * (s.Breathing == Breathing.Lente || s.Breathing == Breathing.Agonique ? 0.4f : 0.8f);
                }
                else resp = 0f;
            }

            Ecg[Cursor] = ecg;
            Pleth[Cursor] = pleth;
            Resp[Cursor] = resp;
            Cursor = (Cursor + 1) % Samples;
        }

        static float G(float x, float mu, float sigma, float amp)
        {
            float d = (x - mu) / sigma;
            return amp * Mathf.Exp(-0.5f * d * d);
        }

        /// <summary>Complexe P-QRS-T (temps depuis le début du battement, en secondes).</summary>
        static float Pqrst(float x, float rr, bool pWave, bool st)
        {
            // À fréquence élevée, l'onde T se rapproche du QRS.
            float k = Mathf.Clamp(rr / 0.8f, 0.55f, 1.2f);
            float v = 0f;
            if (pWave) v += G(x, 0.08f, 0.022f, 0.12f);
            v += G(x, 0.165f, 0.008f, -0.12f);
            v += G(x, 0.18f, 0.009f, 1.0f);
            v += G(x, 0.197f, 0.009f, -0.28f);
            if (st)
            {
                float a = 0.21f, b = 0.18f + 0.2f * k;
                if (x > a && x < b) v += 0.22f * Mathf.SmoothStep(0f, 1f, Mathf.Min(1f, (x - a) / 0.02f));
                v += G(x, 0.18f + 0.22f * k, 0.05f * k, 0.32f);
            }
            else v += G(x, 0.18f + 0.2f * k, 0.045f * k, 0.24f);
            return v;
        }

        static float PlethShape(float x, float rr)
        {
            if (x < 0f) x += rr;
            float k = x / Mathf.Max(0.3f, rr);
            if (k < 0.18f) return Mathf.Sin(k / 0.18f * Mathf.PI * 0.5f);
            float fall = (k - 0.18f) / 0.82f;
            return Mathf.Max(0f, 1f - fall * 1.15f) * (1f + 0.12f * Mathf.Sin(fall * Mathf.PI * 3f));
        }
    }
}
