using System;
using UnityEngine;

namespace BlouseBlanche.Core
{
    public enum QualityPreset { Basse = 0, Moyenne = 1, Haute = 2, Ultra = 3 }

    /// <summary>Paramètres joueur, persistés dans PlayerPrefs (JSON).</summary>
    [Serializable]
    public sealed class GameSettings
    {
        const string Key = "BlouseBlanche.Settings.v1";

        public float mouseSensitivity = 1f;   // 0.2 .. 3
        public bool invertY;
        public float fieldOfView = 72f;       // 60 .. 95
        public float masterVolume = 0.8f;     // 0 .. 1
        public float musicVolume = 0.6f;      // 0 .. 1
        public float brightness;              // -1 .. 1 (exposition post-process)
        public int quality = (int)QualityPreset.Haute;
        public bool headBob = true;
        public bool vSync = true;
        public bool fullscreen = true;
        public bool showTutorialHints = true;

        public event Action Changed;

        public static GameSettings Load()
        {
            GameSettings s = null;
            try
            {
                if (PlayerPrefs.HasKey(Key))
                    s = JsonUtility.FromJson<GameSettings>(PlayerPrefs.GetString(Key));
            }
            catch (Exception e)
            {
                Debug.LogWarning("[BlouseBlanche] Paramètres illisibles, valeurs par défaut utilisées : " + e.Message);
            }
            s ??= new GameSettings();
            s.Sanitize();
            return s;
        }

        public void Save()
        {
            Sanitize();
            PlayerPrefs.SetString(Key, JsonUtility.ToJson(this));
            PlayerPrefs.Save();
        }

        public void NotifyChanged()
        {
            Sanitize();
            Changed?.Invoke();
        }

        void Sanitize()
        {
            mouseSensitivity = Mathf.Clamp(float.IsNaN(mouseSensitivity) ? 1f : mouseSensitivity, 0.2f, 3f);
            fieldOfView = Mathf.Clamp(float.IsNaN(fieldOfView) ? 72f : fieldOfView, 60f, 95f);
            masterVolume = Mathf.Clamp01(float.IsNaN(masterVolume) ? 0.8f : masterVolume);
            musicVolume = Mathf.Clamp01(float.IsNaN(musicVolume) ? 0.6f : musicVolume);
            brightness = Mathf.Clamp(float.IsNaN(brightness) ? 0f : brightness, -1f, 1f);
            quality = Mathf.Clamp(quality, 0, 3);
        }

        /// <summary>Applique les réglages "moteur" (VSync, plein écran, framerate).</summary>
        public void ApplyEngineSettings()
        {
            QualitySettings.vSyncCount = vSync ? 1 : 0;
            Application.targetFrameRate = vSync ? -1 : 144;
            if (!Application.isEditor)
            {
                var mode = fullscreen ? FullScreenMode.FullScreenWindow : FullScreenMode.Windowed;
                if (Screen.fullScreenMode != mode) Screen.fullScreenMode = mode;
            }
            AudioListener.volume = masterVolume;
        }
    }
}
