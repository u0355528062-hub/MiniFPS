using System;
using System.Collections;
using System.Collections.Generic;
using BlouseBlanche.Core;
using BlouseBlanche.Emergency;
using BlouseBlanche.Gameplay;
using BlouseBlanche.Medical;
using BlouseBlanche.UI;
using BlouseBlanche.World;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace BlouseBlanche
{
    /// <summary>État courant de la boucle de jeu.</summary>
    public enum GameMode
    {
        Loading,       // génération des sons, textures et du monde
        Menu,          // menu principal (travelling caméra)
        Explore,       // vue subjective, déplacement libre
        Consultation,  // consultation de médecine générale (plans fixes, interface)
        Emergency,     // prise en charge SAMU / urgences
        Result,        // bilan affiché
        Screen         // écran plein du mode histoire (introduction, agenda, fin de journée)
    }

    /// <summary>
    /// Point d'entrée et boucle principale : crée la caméra, l'audio, le post-traitement et l'interface,
    /// génère le monde pendant l'écran de chargement, puis enchaîne menu, exploration, consultations
    /// et interventions. Aucun asset de scène n'est nécessaire : un objet vide suffit (créé automatiquement
    /// au lancement si la scène n'en contient pas).
    /// </summary>
    public sealed partial class GameRoot : MonoBehaviour
    {
        public static GameRoot Instance { get; private set; }

        public GameSettings Settings { get; private set; }
        public SaveData Save { get; private set; }
        public GameClock Clock { get; private set; }
        public CameraDirector CameraDirector { get; private set; }
        public AudioService Audio { get; private set; }
        public PostFX PostFX { get; private set; }
        public UIRoot UI { get; private set; }
        public ClinicWorld World { get; private set; }
        public WorldKit Kit { get; private set; }
        public PlayerController Player { get; private set; }
        public Interactor Interactor { get; private set; }
        public HeldToolView HeldTool { get; private set; }
        public ConsultationController Consult { get; private set; }
        public EmergencyController Emergency { get; private set; }
        public ConsultPrototype ConsultProto { get; private set; }

        public GameMode Mode { get; private set; } = GameMode.Loading;
        public bool Paused { get; private set; }

        TextureLibrary textures;
        MaterialLibrary materials;
        bool handsWashed;
        bool settingsOpen;
        bool wheelByHold;
        bool transitioning;

        // ================================================================== démarrage

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void ResetStatics() => Instance = null;

        /// <summary>Lance le jeu dans n'importe quelle scène qui ne contient pas déjà un GameRoot.</summary>
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void AutoBootstrap()
        {
            if (Instance != null || FindFirstObjectByType<GameRoot>() != null) return;
            new GameObject("BlouseBlanche").AddComponent<GameRoot>();
        }

        void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            Time.timeScale = 1f;
            DisableForeignSceneObjects();

            Settings = GameSettings.Load();
            Save = SaveSystem.Load();
            Clock = new GameClock();
            Clock.Set(GameClock.At(9, 10));

            BuildCamera();
            var audioGo = new GameObject("Audio");
            audioGo.transform.SetParent(transform, false);
            Audio = audioGo.AddComponent<AudioService>();
            Audio.Initialize();
            PostFX = gameObject.AddComponent<PostFX>();
            PostFX.Initialize();
            var uiGo = new GameObject("Interface");
            uiGo.transform.SetParent(transform, false);
            UI = uiGo.AddComponent<UIRoot>();
            UI.Build(this);

            ApplySettings();
            SetCursor(false);
            StartCoroutine(Boot());
        }

        /// <summary>
        /// Le jeu crée sa propre caméra, son éclairage et son écouteur audio : ceux d'une scène par défaut
        /// (Main Camera, Directional Light) sont désactivés pour ne pas faire double emploi.
        /// </summary>
        void DisableForeignSceneObjects()
        {
            foreach (var go in gameObject.scene.GetRootGameObjects())
            {
                if (go == gameObject || !go.activeSelf) continue;
                if (go.GetComponentInChildren<Camera>(true) != null || go.GetComponentInChildren<Light>(true) != null || go.GetComponentInChildren<AudioListener>(true) != null)
                {
                    go.SetActive(false);
                    Debug.Log("[BlouseBlanche] « " + go.name + " » désactivé : le jeu fournit sa caméra et son éclairage.");
                }
            }
        }

        void BuildCamera()
        {
            var camGo = new GameObject("Camera");
            camGo.transform.SetParent(transform, false);
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.nearClipPlane = 0.03f;
            cam.farClipPlane = 250f;
            cam.fieldOfView = 46f;
            cam.allowHDR = true;
            cam.clearFlags = CameraClearFlags.Skybox;
            camGo.AddComponent<AudioListener>();
            var data = cam.GetUniversalAdditionalCameraData();
            if (data != null)
            {
                data.renderPostProcessing = true;
                data.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
                data.antialiasingQuality = AntialiasingQuality.High;
                data.dithering = true;
            }
            camGo.transform.SetPositionAndRotation(new Vector3(14f, 1.8f, -7f), Quaternion.LookRotation(new Vector3(-0.6f, -0.05f, 1f)));
            CameraDirector = camGo.AddComponent<CameraDirector>();
            CameraDirector.Initialize(cam);
        }

        IEnumerator Boot()
        {
            UI.SetLoading(0.02f, "Synthèse des sons");
            yield return null;
            Audio.GenerateClips();

            UI.SetLoading(0.1f, "Textures");
            yield return null;
            textures = new TextureLibrary { QualitySize = Settings.quality >= (int)QualityPreset.Haute ? 1024 : 512 };
            int i = 0;
            foreach (var step in textures.GenerateAll())
            {
                i++;
                UI.SetLoading(Mathf.Lerp(0.1f, 0.55f, Mathf.Clamp01(i / 24f)), step);
                yield return null;
            }

            materials = new MaterialLibrary(textures);
            Kit = new WorldKit(textures, materials);
            var builder = new ClinicBuilder(Kit);
            i = 0;
            foreach (var step in builder.Build(transform, w => World = w))
            {
                i++;
                UI.SetLoading(Mathf.Lerp(0.55f, 0.92f, Mathf.Clamp01(i / 17f)), step);
                yield return null;
            }

            UI.SetLoading(0.95f, "Personnages");
            yield return null;
            BuildGameplay();
            StartAmbience();
            ApplySettings();
            yield return null;
            World.RefreshProbes();

            UI.SetLoading(1f, "Prêt");
            yield return new WaitForSecondsRealtime(0.25f);
            EnterMenu(null);
            UI.HideLoading();
        }

        void BuildGameplay()
        {
            var playerGo = new GameObject("Joueur");
            playerGo.transform.SetParent(transform, false);
            Player = playerGo.AddComponent<PlayerController>();
            Player.Initialize(Settings);
            Player.Teleport(World.PlayerSpawn, World.PlayerSpawnYaw);
            Interactor = playerGo.AddComponent<Interactor>();

            HeldTool = CameraDirector.gameObject.AddComponent<HeldToolView>();
            HeldTool.Build(Kit, CameraDirector.Cam);

            Consult = gameObject.AddComponent<ConsultationController>();
            Consult.Initialize(this, World, HeldTool);
            Consult.Changed += () => { if (UI.Consult.Visible) UI.Consult.Refresh(); };
            Consult.PatientSpoke += UI.Consult.OnSpoke;
            Consult.ExamDone += UI.Consult.OnExam;
            Consult.Finished += OnConsultationFinished;

            Emergency = gameObject.AddComponent<EmergencyController>();
            Emergency.Initialize(this, World, Kit);
            Emergency.CareStarted += OnEmergencyCareStarted;
            Emergency.Changed += () => { if (UI.Emergency.Visible) UI.Emergency.Refresh(); };
            Emergency.Logged += e => { if (UI.Emergency.Visible) UI.Emergency.AddLog(e); };
            Emergency.Finished += OnEmergencyFinished;

            ConsultProto = gameObject.AddComponent<ConsultPrototype>();
            ConsultProto.Initialize(this, World, Kit);
#if BB_STORY_MODE
            InitStory();
#endif
        }

        /// <summary>Ambiances en boucle : extérieur (oiseaux, vent) et « room tone » des pièces.</summary>
        void StartAmbience()
        {
            foreach (var p in World.OutdoorSoundPoints) Audio.CreateLoop(Sfx.Outdoor, World.Root, p, 0.35f, 2f, 18f);
            foreach (var p in World.RoomTonePoints) Audio.CreateLoop(Sfx.RoomTone, World.Root, p, 0.12f, 1f, 9f);
            if (World.Salon != null) Audio.CreateLoop(Sfx.RoomTone, World.Root, World.Salon.Bounds.center, 0.1f, 1f, 8f);
            if (World.ErBox != null) Audio.CreateLoop(Sfx.RoomTone, World.Root, World.ErBox.Bounds.center, 0.14f, 1f, 8f);
        }

        void OnDestroy()
        {
            if (Instance != this) return;
            Instance = null;
            Time.timeScale = 1f;
            AudioListener.pause = false;
            Kit?.Dispose();
            materials?.Dispose();
            textures?.Dispose();
        }

        void OnApplicationFocus(bool focus)
        {
            // Dans un build, perdre le focus met le jeu en pause (dans l'éditeur, ce serait gênant).
            if (!focus && !Application.isEditor && !Paused && IsPausable()) PauseGame();
        }

        // ================================================================== boucle

        void Update()
        {
            if (Mode == GameMode.Loading) return;
            if (Clock.Running) Clock.Tick(Time.deltaTime);

            if (GameInput.PauseDown() && !transitioning) HandleEscape();
            if (Paused || transitioning) return;

            switch (Mode)
            {
                case GameMode.Explore:
                    UpdateExplore();
                    break;
                case GameMode.Consultation:
                    UpdateWheel();
                    UpdateHotkeys();
                    UI.Consult.Tick();
                    break;
                case GameMode.Emergency:
                    UpdateWheel();
                    UpdateHotkeys();
                    UI.Emergency.Tick();
                    break;
#if BB_STORY_MODE
                case GameMode.Screen:
                    UpdateStoryScreen();
                    break;
#endif
            }
        }

        void UpdateExplore()
        {
            // Dans l'éditeur, un clic dans la vue de jeu reverrouille la souris.
            if (Cursor.lockState != CursorLockMode.Locked && GameInput.InteractDown())
            {
                SetCursor(true);
                return;
            }
            Interactor.Tick(CameraDirector.Cam);
            UI.Hud.SetPrompt(Interactor.Current);
#if BB_STORY_MODE
            if (Day != null && Day.Active)
            {
                UI.Hud.TickStory(this);
                UI.Hud.SetObjectivesVisible(Settings.showTutorialHints);
                if (GameInput.AgendaDown()) OpenAgenda();
                else if (GameInput.SkipTimeDown()) SkipTime();
                return;
            }
#endif
            UpdatePrototypeHud();
        }

        void HandleEscape()
        {
            if (UI.Wheel.IsOpen) { CloseToolWheel(false); return; }
            if (settingsOpen) { CloseSettings(); return; }
#if BB_STORY_MODE
            if (Mode == GameMode.Screen && agendaOpen) { CloseAgenda(); return; }
#endif
            if (!IsPausable()) return;
            if (Paused) Resume();
            else PauseGame();
        }

        bool IsPausable() => Mode == GameMode.Explore || Mode == GameMode.Consultation || Mode == GameMode.Emergency;

        static void SetCursor(bool locked)
        {
            Cursor.lockState = locked ? CursorLockMode.Locked : CursorLockMode.None;
            Cursor.visible = !locked;
        }

        // ================================================================== modes

        /// <summary>Vue subjective : déplacement libre, interactions (touche E).</summary>
        void EnterExplore(float blend = 0.9f)
        {
            Mode = GameMode.Explore;
            UI.SetInCare(false);
            UI.Hud.Show();
            Player.InputEnabled = true;
            Interactor.Active = true;
            SetCursor(true);
            UI.BlurFocus();
            CameraDirector.SetFirstPerson(Player.EyePose, Player.Fov, blend);
            PostFX.SetFocus(false);
            Audio.SetMusic(false);
            Clock.Running = true;
        }

        /// <summary>Contrôles de l'interface (souris libre, joueur immobile).</summary>
        void EnterInterfaceMode(GameMode mode)
        {
            Mode = mode;
            Clock.Running = false;
            Player.InputEnabled = false;
            Interactor.Active = false;
            UI.Hud.Hide();
            SetCursor(false);
            UI.BlurFocus();
        }

        void EnterMenu(PrototypeKind? openPicker)
        {
            CleanupRun();
            Mode = GameMode.Menu;
            Paused = false;
            Time.timeScale = 1f;
            AudioListener.pause = false;
            UI.Pause.Hide();
            UI.Hud.Hide();
            UI.Result.Hide();
            UI.Consult.Hide();
            UI.Emergency.Hide();
            Player.InputEnabled = false;
            Interactor.Active = false;
            SetCursor(false);

            var shots = new List<Pose>(World.MenuShots);
            if (World.Salon != null) shots.AddRange(World.Salon.MenuShots);
            if (World.ErBox != null) shots.AddRange(World.ErBox.MenuShots);
            CameraDirector.SetCinematic(shots.ToArray(), 1.2f);
            PostFX.SetFocus(true, 3f, 14f);
            Audio.SetMusic(true);
            Clock.Set(GameClock.At(9, 12));
            Clock.Running = true;
            UI.Menu.Show(openPicker);
        }

        /// <summary>Arrête proprement tout ce qui est en cours (cas, journée, roue, interface).</summary>
        void CleanupRun()
        {
            CloseToolWheel(false);
            if (Consult != null) Consult.Abort();
            if (ConsultProto != null) ConsultProto.End();
            if (Emergency != null) Emergency.End();
#if BB_STORY_MODE
            CleanupStory();
#endif
            if (HeldTool != null) HeldTool.Show(null);
            handsWashed = false;
            UI.SetInCare(false);
            UI.HideSubtitle();
        }

        /// <summary>Fondu au noir, changement d'état, retour à l'image.</summary>
        IEnumerator Transition(Action change)
        {
            transitioning = true;
            UI.Fade(true);
            yield return new WaitForSecondsRealtime(0.5f);
            if (Paused)
            {
                Paused = false;
                Time.timeScale = 1f;
                AudioListener.pause = false;
                UI.Pause.Hide();
            }
            if (settingsOpen) CloseSettings();
            change();
            yield return null;
            yield return new WaitForSecondsRealtime(0.15f);
            UI.Fade(false);
            transitioning = false;
        }

        // ================================================================== pause et réglages

        void PauseGame()
        {
            if (Paused) return;
            Paused = true;
            Time.timeScale = 0f;
            AudioListener.pause = true;
            Player.InputEnabled = false;
            Interactor.Active = false;
            UI.Hud.SetPrompt(null);
            SetCursor(false);
            if (UI.Wheel.IsOpen) CloseToolWheel(false);
            ConfigurePause();
            UI.Pause.Show();
        }

        void ConfigurePause()
        {
#if BB_STORY_MODE
            if (Day != null && Day.Active)
            {
                UI.Pause.Configure("La journée est en suspens", "La journée en cours ne sera pas sauvegardée : vous reprendrez au début de cette journée.", false);
                return;
            }
#endif
            UI.Pause.Configure(prototype.HasValue ? PrototypeCatalog.Name(prototype.Value) : "Le temps est suspendu", "Le cas en cours sera abandonné.", prototype.HasValue);
        }

        public void Resume()
        {
            if (!Paused) return;
            if (settingsOpen) CloseSettings();
            Paused = false;
            Time.timeScale = 1f;
            AudioListener.pause = false;
            UI.Pause.Hide();
            if (Mode == GameMode.Explore)
            {
                Player.InputEnabled = true;
                Interactor.Active = true;
                SetCursor(true);
                UI.BlurFocus();
            }
        }

        public void OpenSettings()
        {
            settingsOpen = true;
            UI.Settings.Show();
        }

        public void CloseSettings()
        {
            settingsOpen = false;
            UI.Settings.Hide();
            Settings.Save();
        }

        public void ApplySettings()
        {
            Settings.NotifyChanged();
            Settings.ApplyEngineSettings();
            Audio.SetMusicVolume(Settings.musicVolume);
            PostFX.SetBrightness(Settings.brightness);
            var q = (QualityPreset)Settings.quality;
            PostFX.ApplyQuality(q);
            ApplyQuality(q);
            if (UI.Hud != null) UI.Hud.SetObjectivesVisible(Settings.showTutorialHints);
        }

        /// <summary>Qualité : anticrénelage, ombres des lampes, sondes de réflexion, filtrage.</summary>
        void ApplyQuality(QualityPreset q)
        {
            var data = CameraDirector.Cam.GetUniversalAdditionalCameraData();
            if (data != null)
            {
                data.antialiasing = q == QualityPreset.Basse ? AntialiasingMode.FastApproximateAntialiasing : AntialiasingMode.SubpixelMorphologicalAntiAliasing;
                data.antialiasingQuality = q >= QualityPreset.Ultra ? AntialiasingQuality.High : q >= QualityPreset.Haute ? AntialiasingQuality.Medium : AntialiasingQuality.Low;
            }
            QualitySettings.anisotropicFiltering = q >= QualityPreset.Moyenne ? AnisotropicFiltering.ForceEnable : AnisotropicFiltering.Enable;
            if (World == null) return;
            foreach (var l in World.ShadowedLights)
                if (l != null) l.shadows = q == QualityPreset.Basse ? LightShadows.None : q == QualityPreset.Moyenne ? LightShadows.Hard : LightShadows.Soft;
            if (RenderSettings.sun != null) RenderSettings.sun.shadows = q == QualityPreset.Basse ? LightShadows.Hard : LightShadows.Soft;
            int res = q >= QualityPreset.Haute ? 256 : 128;
            bool changed = false;
            foreach (var p in World.Probes)
            {
                if (p == null || p.resolution == res) continue;
                p.resolution = res;
                changed = true;
            }
            if (changed && Mode != GameMode.Loading) World.RefreshProbes();
        }

        public void QuitGame()
        {
            Settings.Save();
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying = false;
#else
            Application.Quit();
#endif
        }

        /// <summary>Retour au menu principal (la liste des cas du prototype en cours reste ouverte).</summary>
        public void BackToMenu()
        {
            var k = prototype;
            StartCoroutine(Transition(() => EnterMenu(k)));
        }

        // ================================================================== interactions du décor

        public void WashHands(Vector3 position, bool sink)
        {
            if (Mode != GameMode.Explore) return;
            handsWashed = true;
            Audio.PlayAt(sink ? Sfx.Water : Sfx.Paper, position, sink ? 0.55f : 0.45f, 0.03f);
            UI.Toast("Hygiène des mains",
                sink ? "Lavage au savon : paumes, dos des mains, entre les doigts, pouces et ongles — 30 secondes."
                     : "Friction hydro-alcoolique : 20 à 30 secondes, jusqu'à ce que les mains soient sèches.",
                ToastKind.Success, 4f);
            ConsultProto.OnHandsWashed();
        }

        public void DrinkCoffee(Vector3 position)
        {
            if (Mode != GameMode.Explore) return;
            Audio.PlayAt(Sfx.Coffee, position, 0.6f, 0.02f);
            UI.Subtitle("Vous", "Un petit café… et on y retourne !", 2.5f);
#if BB_STORY_MODE
            if (Day != null && Day.Active) Clock.Advance(3f);
#endif
        }

        /// <summary>Ordinateur du bureau : agenda (mode histoire) ou dossier du patient (prototype).</summary>
        public void OpenAgenda()
        {
#if BB_STORY_MODE
            if (Day != null && Day.Active)
            {
                OpenStoryAgenda();
                return;
            }
#endif
            if (ConsultProto.Active) UI.Toast("Logiciel médical · dossier", ConsultProto.DossierSummary(), ToastKind.Info, 8f);
            else UI.Toast("Logiciel médical", "L'agenda complet est réservé au mode histoire.", ToastKind.Info);
        }

        // ================================================================== consultation

        /// <summary>Le joueur s'assoit au bureau face au patient : début de la consultation.</summary>
        public void BeginConsultation(VisitRuntime v)
        {
            if (Consult.Active || v == null) return;
            IVisitHost host = ConsultProto.Active && ConsultProto.Visit == v ? ConsultProto : null;
#if BB_STORY_MODE
            if (host == null) host = Day;
#endif
            EnterInterfaceMode(GameMode.Consultation);
            UI.SetInCare(true);
            Consult.Begin(v, handsWashed, host);
            UI.Consult.Begin();
        }

        void OnConsultationFinished(ConsultationResult r)
        {
            CloseToolWheel(false);
            UI.Consult.Hide();
            Mode = GameMode.Result;
            var patient = Consult.Session.Patient;
#if BB_STORY_MODE
            if (Day != null && Day.Active)
            {
                string fee = "Honoraires : +" + r.Fee + " €   ·   Réputation " + (r.ReputationDelta >= 0 ? "+" : "") + r.ReputationDelta.ToString("0.0");
                UI.Result.Set(ResultLayout.Consultation, patient.FullName, r, fee, new ResultAction("Continuer", () => FinishConsultationInPlace(r), true));
                return;
            }
#endif
            string note = "Consultation de " + Mathf.Max(1, Mathf.RoundToInt(r.Minutes)) + " min · honoraires : " + r.Fee + " €";
            UI.Result.Set(ResultLayout.Consultation, patient.FullName, r, note, PrototypeResultActions(() => Consult.Close(r), () => FinishConsultationInPlace(r)));
        }

        /// <summary>Après le bilan : le patient s'en va, le médecin se relève dans son cabinet.</summary>
        void FinishConsultationInPlace(ConsultationResult r)
        {
            UI.Result.Hide();
            Consult.Close(r);
            handsWashed = false;
            Player.Teleport(World.PlayerAfterConsult, World.PlayerAfterConsultYaw);
            Player.SetLook(Quaternion.Euler(8f, World.PlayerAfterConsultYaw, 0f));
            EnterExplore(1.2f);
        }

        // ================================================================== SAMU / urgences

        void OnEmergencyCareStarted()
        {
            EnterInterfaceMode(GameMode.Emergency);
            UI.SetInCare(true);
            var shot = Emergency.Location.CareShot;
            CameraDirector.SetShot(shot.position, shot.rotation, 50f, 1.2f);
            float d = Vector3.Distance(shot.position, Emergency.Location.PatientPelvis);
            PostFX.SetFocus(true, d + 0.8f, d + 6f);
            UI.Emergency.Begin();
        }

        void OnEmergencyFinished(ConsultationResult r)
        {
            CloseToolWheel(false);
            UI.Emergency.Hide();
            Mode = GameMode.Result;
            string who = Emergency.Case.Title + "\n" + Emergency.PatientLabel;
            string note = "Prise en charge : " + Mathf.Max(1, Mathf.RoundToInt(r.Minutes)) + " min";
            UI.Result.Set(ResultLayout.Emergency, who, r, note, PrototypeResultActions(null, null));
        }

        // ================================================================== roue des outils

        void UpdateWheel()
        {
            bool held = GameInput.WheelHeld();
            if (held && !UI.Wheel.IsOpen)
            {
                if (!transitioning && CanUseWheel())
                {
                    wheelByHold = true;
                    OpenToolWheel();
                }
            }
            else if (!held && UI.Wheel.IsOpen && wheelByHold)
            {
                wheelByHold = false;
                CloseToolWheel(true);
            }
        }

        bool CanUseWheel() => (Mode == GameMode.Consultation && Consult.Active) || (Mode == GameMode.Emergency && Emergency.InCare);

        void UpdateHotkeys()
        {
            if (UI.Wheel.IsOpen) return;
            int k = GameInput.ToolHotkeyDown();
            if (k < 0) return;
            if (Mode == GameMode.Consultation && Consult.Active && k < MedicalTools.Count)
            {
                Consult.SelectTool((MedicalTool)k);
                UI.Consult.OnToolPicked();
            }
            else if (Mode == GameMode.Emergency && Emergency.InCare && Enum.IsDefined(typeof(EmergencyTool), k))
            {
                var t = (EmergencyTool)k;
                if (!EmergencyCatalog.ToolAvailable(t, Emergency.Case.Setting)) return;
                Emergency.SelectTool(t);
                UI.Emergency.OnToolPicked();
            }
        }

        static string HotkeyLabel(int i) => i < 9 ? (i + 1).ToString() : i == 9 ? "0" : i == 10 ? "-" : "=";

        public void OpenToolWheel()
        {
            if (UI.Wheel.IsOpen) return;
            var slots = new List<WheelSlot>();
            if (Mode == GameMode.Consultation && Consult.Active)
            {
                for (int i = 0; i < MedicalTools.Count; i++)
                {
                    var t = (MedicalTool)i;
                    int n = MedicalCatalog.ExamsForTool(t).Count;
                    slots.Add(new WheelSlot
                    {
                        Name = MedicalTools.Name(t),
                        Description = MedicalTools.Description(t),
                        Hotkey = HotkeyLabel(i),
                        Icon = ToolIcons.Get(t),
                        Detail = n + (n > 1 ? " examens" : " examen")
                    });
                }
                UI.Wheel.SetSlots(slots, i => { Consult.SelectTool((MedicalTool)i); UI.Consult.OnToolPicked(); });
                UI.Wheel.SetCurrent(Consult.Tool.HasValue ? (int)Consult.Tool.Value : -1);
            }
            else if (Mode == GameMode.Emergency && Emergency.InCare)
            {
                foreach (EmergencyTool t in Enum.GetValues(typeof(EmergencyTool)))
                {
                    int n = EmergencyCatalog.ForTool(t, Emergency.Case.Setting).Count;
                    slots.Add(new WheelSlot
                    {
                        Name = EmergencyCatalog.ToolName(t),
                        Description = EmergencyCatalog.ToolDescription(t),
                        Hotkey = HotkeyLabel((int)t),
                        Icon = ToolIcons.Get(t),
                        Detail = n + (n > 1 ? " gestes" : " geste"),
                        Enabled = n > 0
                    });
                }
                UI.Wheel.SetSlots(slots, i => { Emergency.SelectTool((EmergencyTool)i); UI.Emergency.OnToolPicked(); });
                UI.Wheel.SetCurrent(Emergency.Tool.HasValue ? (int)Emergency.Tool.Value : -1);
                Emergency.SlowMotion = true;
            }
            else return;
            UI.Wheel.Open();
        }

        public void CloseToolWheel(bool pick)
        {
            if (Emergency != null) Emergency.SlowMotion = false;
            if (UI == null || UI.Wheel == null || !UI.Wheel.IsOpen) return;
            UI.Wheel.Close(pick);
        }
    }
}
