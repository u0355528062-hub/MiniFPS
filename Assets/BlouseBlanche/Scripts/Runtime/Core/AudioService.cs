using System.Collections.Generic;
using UnityEngine;

namespace BlouseBlanche.Core
{
    public enum Sfx
    {
        UiHover, UiClick, UiConfirm, UiBack, Notify, Urgent, Success, Fail,
        Footstep0, Footstep1, Footstep2, Footstep3,
        DoorOpen, DoorClose, SlidingDoor, EntranceChime,
        Heartbeat, BloodPressure, DeviceBeep, Cough0, Cough1,
        Typing, Water, Coffee, Pen, Paper,
        RoomTone, Outdoor,
        ScopeBeep, Alarm, DefibCharge, DefibShock, Compression, BagValve, Siren
    }

    /// <summary>
    /// Sons générés procéduralement au démarrage + pool de sources 3D.
    /// </summary>
    public sealed class AudioService : MonoBehaviour
    {
        readonly Dictionary<Sfx, AudioClip> clips = new Dictionary<Sfx, AudioClip>();
        AudioSource uiSource;
        AudioSource musicSource;
        readonly List<AudioSource> pool = new List<AudioSource>();
        int poolCursor;
        float musicTarget;
        float musicVolumeSetting = 0.6f;
        AudioClip musicClip;

        public bool Ready { get; private set; }

        public void Initialize()
        {
            uiSource = gameObject.AddComponent<AudioSource>();
            uiSource.playOnAwake = false;
            uiSource.spatialBlend = 0f;
            uiSource.ignoreListenerPause = true;

            musicSource = gameObject.AddComponent<AudioSource>();
            musicSource.playOnAwake = false;
            musicSource.loop = true;
            musicSource.spatialBlend = 0f;
            musicSource.volume = 0f;
            musicSource.ignoreListenerPause = true;

            for (int i = 0; i < 16; i++)
            {
                var go = new GameObject("Sfx3D_" + i);
                go.transform.SetParent(transform, false);
                var src = go.AddComponent<AudioSource>();
                src.playOnAwake = false;
                src.spatialBlend = 1f;
                src.rolloffMode = AudioRolloffMode.Logarithmic;
                src.minDistance = 1.2f;
                src.maxDistance = 25f;
                src.dopplerLevel = 0f;
                pool.Add(src);
            }
        }

        /// <summary>Génère tous les sons. Appelé pendant l'écran de chargement.</summary>
        public void GenerateClips()
        {
            Make(Sfx.UiHover, Synth.UiHover());
            Make(Sfx.UiClick, Synth.UiClick());
            Make(Sfx.UiConfirm, Synth.UiConfirm());
            Make(Sfx.UiBack, Synth.UiBack());
            Make(Sfx.Notify, Synth.Notify());
            Make(Sfx.Urgent, Synth.Urgent());
            Make(Sfx.Success, Synth.StingerSuccess());
            Make(Sfx.Fail, Synth.StingerFail());
            Make(Sfx.Footstep0, Synth.Footstep(1));
            Make(Sfx.Footstep1, Synth.Footstep(2));
            Make(Sfx.Footstep2, Synth.Footstep(3));
            Make(Sfx.Footstep3, Synth.Footstep(4));
            Make(Sfx.DoorOpen, Synth.DoorOpen());
            Make(Sfx.DoorClose, Synth.DoorClose());
            Make(Sfx.SlidingDoor, Synth.SlidingDoor());
            Make(Sfx.EntranceChime, Synth.EntranceChime());
            Make(Sfx.Heartbeat, Synth.Heartbeat());
            Make(Sfx.BloodPressure, Synth.BloodPressurePump());
            Make(Sfx.DeviceBeep, Synth.DeviceBeep());
            Make(Sfx.Cough0, Synth.Cough(5));
            Make(Sfx.Cough1, Synth.Cough(9));
            Make(Sfx.Typing, Synth.Typing());
            Make(Sfx.Water, Synth.WaterRunning());
            Make(Sfx.Coffee, Synth.CoffeeMachine());
            Make(Sfx.Pen, Synth.PenScribble());
            Make(Sfx.Paper, Synth.PaperSwish());
            Make(Sfx.RoomTone, Synth.RoomTone());
            Make(Sfx.Outdoor, Synth.Outdoor());
            Make(Sfx.ScopeBeep, Synth.ScopeBeep());
            Make(Sfx.Alarm, Synth.MonitorAlarm());
            Make(Sfx.DefibCharge, Synth.DefibCharge());
            Make(Sfx.DefibShock, Synth.DefibShock());
            Make(Sfx.Compression, Synth.Compression());
            Make(Sfx.BagValve, Synth.BagValve());
            Make(Sfx.Siren, Synth.Siren());

            float[] music = Synth.MenuMusic(out int rate);
            musicClip = AudioClip.Create("MenuMusic", music.Length, 1, rate, false);
            musicClip.SetData(music, 0);
            musicSource.clip = musicClip;
            Ready = true;
        }

        void Make(Sfx id, float[] data)
        {
            var clip = AudioClip.Create(id.ToString(), data.Length, 1, Synth.Rate, false);
            clip.SetData(data, 0);
            clips[id] = clip;
        }

        public AudioClip Clip(Sfx id) => clips.TryGetValue(id, out var c) ? c : null;

        public void PlayUI(Sfx id, float volume = 1f)
        {
            var c = Clip(id);
            if (c != null && uiSource != null) uiSource.PlayOneShot(c, volume);
        }

        public AudioSource PlayAt(Sfx id, Vector3 position, float volume = 1f, float pitchJitter = 0.05f)
        {
            var c = Clip(id);
            if (c == null || pool.Count == 0) return null;
            AudioSource src = null;
            for (int i = 0; i < pool.Count; i++)
            {
                var candidate = pool[(poolCursor + i) % pool.Count];
                if (!candidate.isPlaying) { src = candidate; poolCursor = (poolCursor + i + 1) % pool.Count; break; }
            }
            if (src == null) { src = pool[poolCursor]; poolCursor = (poolCursor + 1) % pool.Count; }
            src.transform.position = position;
            src.clip = c;
            src.volume = volume;
            src.loop = false;
            src.pitch = 1f + Random.Range(-pitchJitter, pitchJitter);
            src.Play();
            return src;
        }

        public void PlayFootstep(Vector3 position, float volume)
        {
            var id = (Sfx)((int)Sfx.Footstep0 + Random.Range(0, 4));
            PlayAt(id, position, volume, 0.08f);
        }

        /// <summary>Crée une source en boucle attachée à un objet du monde (ambiances).</summary>
        public AudioSource CreateLoop(Sfx id, Transform parent, Vector3 localPosition, float volume, float minDistance, float maxDistance, bool spatial = true)
        {
            var go = new GameObject("Loop_" + id);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPosition;
            var src = go.AddComponent<AudioSource>();
            src.clip = Clip(id);
            src.loop = true;
            src.volume = volume;
            src.spatialBlend = spatial ? 1f : 0f;
            src.rolloffMode = AudioRolloffMode.Linear;
            src.minDistance = minDistance;
            src.maxDistance = maxDistance;
            src.dopplerLevel = 0f;
            src.playOnAwake = false;
            if (src.clip != null)
            {
                src.time = Random.Range(0f, src.clip.length * 0.9f);
                src.Play();
            }
            return src;
        }

        public void SetMusic(bool on)
        {
            musicTarget = on ? 1f : 0f;
            if (on && musicSource != null && musicSource.clip != null && !musicSource.isPlaying) musicSource.Play();
        }

        public void SetMusicVolume(float v) => musicVolumeSetting = Mathf.Clamp01(v);

        void Update()
        {
            if (musicSource == null) return;
            float target = musicTarget * musicVolumeSetting * 0.55f;
            musicSource.volume = Mathf.MoveTowards(musicSource.volume, target, Time.unscaledDeltaTime * 0.35f);
            if (musicTarget <= 0f && musicSource.isPlaying && musicSource.volume <= 0.001f) musicSource.Pause();
        }
    }
}
