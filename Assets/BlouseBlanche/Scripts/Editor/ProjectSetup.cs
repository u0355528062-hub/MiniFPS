using System.Collections.Generic;
using System.IO;
using BlouseBlanche.Core;
using BlouseBlanche.World;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.UIElements;

namespace BlouseBlanche.EditorTools
{
    /// <summary>
    /// Configuration du projet en un clic (menu « Blouse Blanche ») : pipeline URP, matériaux modèles,
    /// PanelSettings de l'interface, scène du jeu, réglages du lecteur. Proposée automatiquement à
    /// l'ouverture d'un projet non configuré. Chaque étape est idempotente.
    /// </summary>
    [InitializeOnLoad]
    public static class ProjectSetup
    {
        const string Root = "Assets/BlouseBlanche";
        const string SettingsFolder = Root + "/Settings";
        const string ScenesFolder = Root + "/Scenes";
        const string MaterialsFolder = Root + "/Resources/" + "BlouseBlanche/Materials";
        const string UiFolder = Root + "/Resources/BlouseBlanche/UI";
        const string ScenePath = ScenesFolder + "/BlouseBlanche.unity";
        const string PipelinePath = SettingsFolder + "/BlouseBlanche_URP.asset";
        const string RendererPath = SettingsFolder + "/BlouseBlanche_Renderer.asset";
        const string LightingPath = SettingsFolder + "/BlouseBlanche_Lighting.lighting";
        const string FlatNormalPath = SettingsFolder + "/FlatNormal.png";
        const string PanelSettingsPath = UiFolder + "/PanelSettings.asset";
        const string ThemePath = UiFolder + "/BlouseBlancheTheme.tss";
        const string UrpPostProcessData = "Packages/com.unity.render-pipelines.universal/Runtime/Data/PostProcessData.asset";
        const string AskedKey = "BlouseBlanche.SetupAsked";

        static ProjectSetup()
        {
            EditorApplication.delayCall += OfferSetup;
        }

        static void OfferSetup()
        {
            if (Application.isBatchMode || SessionState.GetBool(AskedKey, false)) return;
            if (EditorApplication.isCompiling || EditorApplication.isUpdating || EditorApplication.isPlayingOrWillChangePlaymode)
            {
                EditorApplication.delayCall += OfferSetup;
                return;
            }
            SessionState.SetBool(AskedKey, true);
            if (IsConfigured()) return;
            if (EditorUtility.DisplayDialog("Blouse Blanche",
                    "Le projet n'est pas encore configuré : pipeline URP, matériaux modèles, interface et scène du jeu.\n\nConfigurer maintenant ? (menu « Blouse Blanche > Configurer le projet »)",
                    "Configurer", "Plus tard"))
                Configure();
        }

        /// <summary>Vrai si les éléments indispensables sont en place.</summary>
        public static bool IsConfigured()
        {
            return GraphicsSettings.defaultRenderPipeline is UniversalRenderPipelineAsset
                && AssetDatabase.LoadAssetAtPath<Material>(MaterialsFolder + "/Lit.mat") != null
                && AssetDatabase.LoadAssetAtPath<PanelSettings>(PanelSettingsPath) != null
                && File.Exists(ScenePath);
        }

        // ================================================================== menus

        [MenuItem("Blouse Blanche/Configurer le projet", priority = 1)]
        public static void Configure()
        {
            var log = new List<string>();
            bool restart = false;
            try
            {
                EditorUtility.DisplayProgressBar("Blouse Blanche", "Dossiers", 0.05f);
                EnsureFolder(SettingsFolder);
                EnsureFolder(ScenesFolder);
                EnsureFolder(MaterialsFolder);
                EnsureFolder(UiFolder);

                EditorUtility.DisplayProgressBar("Blouse Blanche", "Pipeline URP", 0.2f);
                SetupPipeline(log);
                EditorUtility.DisplayProgressBar("Blouse Blanche", "Matériaux modèles", 0.4f);
                SetupMaterials(log);
                EditorUtility.DisplayProgressBar("Blouse Blanche", "Interface", 0.55f);
                SetupPanelSettings(log);
                EditorUtility.DisplayProgressBar("Blouse Blanche", "Réglages du lecteur", 0.7f);
                restart = SetupPlayer(log);
                EditorUtility.DisplayProgressBar("Blouse Blanche", "Scène du jeu", 0.85f);
                SetupScene(log);
                AssetDatabase.SaveAssets();
            }
            finally
            {
                EditorUtility.ClearProgressBar();
            }

            string summary = log.Count > 0 ? "• " + string.Join("\n• ", log) : "Tout était déjà en place.";
            Debug.Log("[BlouseBlanche] Configuration du projet :\n" + summary);
            EditorUtility.DisplayDialog("Blouse Blanche", summary +
                (restart ? "\n\nLa gestion des entrées a changé : Unity doit redémarrer pour l'appliquer." : "") +
                "\n\nAppuyez sur Lecture dans la scène « BlouseBlanche » pour jouer.", "OK");
            if (restart && EditorUtility.DisplayDialog("Blouse Blanche", "Redémarrer l'éditeur maintenant ?", "Redémarrer", "Plus tard"))
                EditorApplication.OpenProject(Directory.GetCurrentDirectory());
        }

        [MenuItem("Blouse Blanche/Ouvrir la scène du jeu", priority = 2)]
        public static void OpenScene()
        {
            if (!File.Exists(ScenePath))
            {
                if (EditorUtility.DisplayDialog("Blouse Blanche", "La scène n'existe pas encore. Configurer le projet ?", "Configurer", "Annuler")) Configure();
                return;
            }
            if (EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) EditorSceneManager.OpenScene(ScenePath);
        }

        [MenuItem("Blouse Blanche/Effacer sauvegarde et réglages", priority = 20)]
        public static void ResetPlayerData()
        {
            if (!EditorUtility.DisplayDialog("Blouse Blanche", "Effacer la progression du mode histoire et les réglages du joueur ?", "Effacer", "Annuler")) return;
            SaveSystem.Delete();
            PlayerPrefs.DeleteKey("BlouseBlanche.Settings.v1");
            PlayerPrefs.Save();
            Debug.Log("[BlouseBlanche] Sauvegarde et réglages effacés.");
        }

        // ================================================================== étapes

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = Path.GetDirectoryName(path).Replace('\\', '/');
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, Path.GetFileName(path));
        }

        /// <summary>
        /// URP en Forward+ (pas de limite de lumières par objet : l'architecture est fusionnée en grands maillages),
        /// ombres douces pour la lumière principale et les lampes, HDR, profondeur pour le flou de profondeur de champ.
        /// </summary>
        static void SetupPipeline(List<string> log)
        {
            var current = GraphicsSettings.defaultRenderPipeline;
            var asset = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
            if (current != null && current != asset)
            {
                if (current is UniversalRenderPipelineAsset)
                {
                    log.Add("Pipeline URP existant conservé (" + current.name + ").");
                    return;
                }
                log.Add("Pipeline « " + current.name + " » remplacé par URP.");
            }

            if (asset == null)
            {
                var renderer = ScriptableObject.CreateInstance<UniversalRendererData>();
                AssetDatabase.CreateAsset(renderer, RendererPath);
                var rso = new SerializedObject(renderer);
                SetObject(rso, "postProcessData", AssetDatabase.LoadAssetAtPath<Object>(UrpPostProcessData));
                SetInt(rso, "m_RenderingMode", 2);  // Forward+
                rso.ApplyModifiedPropertiesWithoutUndo();

                asset = UniversalRenderPipelineAsset.Create(renderer);
                AssetDatabase.CreateAsset(asset, PipelinePath);
                var so = new SerializedObject(asset);
                SetBool(so, "m_SupportsHDR", true);
                SetInt(so, "m_MSAA", 2);
                SetFloat(so, "m_RenderScale", 1f);
                SetBool(so, "m_RequireDepthTexture", true);
                SetBool(so, "m_MainLightShadowsSupported", true);
                SetInt(so, "m_MainLightShadowmapResolution", 4096);
                SetInt(so, "m_AdditionalLightsRenderingMode", 1);   // par pixel
                SetInt(so, "m_AdditionalLightsPerObjectLimit", 8);
                SetBool(so, "m_AdditionalLightShadowsSupported", true);
                SetInt(so, "m_AdditionalLightsShadowmapResolution", 4096);
                SetFloat(so, "m_ShadowDistance", 40f);
                SetInt(so, "m_ShadowCascadeCount", 4);
                SetBool(so, "m_SoftShadowsSupported", true);
                so.ApplyModifiedPropertiesWithoutUndo();
                EditorUtility.SetDirty(asset);
                log.Add("Pipeline URP créé (" + PipelinePath + ").");
            }

            GraphicsSettings.defaultRenderPipeline = asset;
            int level = QualitySettings.GetQualityLevel();
            for (int i = 0; i < QualitySettings.names.Length; i++)
            {
                QualitySettings.SetQualityLevel(i, false);
                if (QualitySettings.renderPipeline != null && QualitySettings.renderPipeline != asset) QualitySettings.renderPipeline = asset;
            }
            QualitySettings.SetQualityLevel(level, false);
            log.Add("URP assigné aux réglages graphiques et de qualité.");
        }

        /// <summary>
        /// Matériaux « modèles » chargés à l'exécution par <see cref="MaterialLibrary"/> : ils garantissent que
        /// les variantes de shader nécessaires (normal map, émission, transparence) sont incluses dans les builds.
        /// </summary>
        static void SetupMaterials(List<string> log)
        {
            var lit = Shader.Find("Universal Render Pipeline/Lit");
            if (lit == null)
            {
                log.Add("ERREUR : shader « Universal Render Pipeline/Lit » introuvable (paquet URP absent ?).");
                return;
            }
            int created = 0;

            if (CreateMaterial("Lit", lit, m => m.SetFloat("_Smoothness", 0.4f))) created++;

            if (CreateMaterial("LitNormal", lit, m =>
            {
                m.SetTexture("_BumpMap", FlatNormalMap());
                m.SetFloat("_BumpScale", 1f);
                m.EnableKeyword("_NORMALMAP");
            })) created++;

            if (CreateMaterial("LitEmissive", lit, m =>
            {
                m.SetColor("_EmissionColor", Color.white);
                m.EnableKeyword("_EMISSION");
                m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
            })) created++;

            if (CreateMaterial("Glass", lit, m =>
            {
                MaterialLibrary.ConfigureTransparent(m, true);
                m.SetColor("_BaseColor", new Color(0.8f, 0.9f, 0.95f, 0.25f));
                m.SetFloat("_Smoothness", 0.95f);
            })) created++;

            var skyShader = Shader.Find("Skybox/Procedural");
            if (skyShader != null && CreateMaterial("Sky", skyShader, null)) created++;

            if (created > 0) log.Add(created + " matériau(x) modèle(s) créé(s) dans " + MaterialsFolder + ".");
        }

        static bool CreateMaterial(string name, Shader shader, System.Action<Material> setup)
        {
            string path = MaterialsFolder + "/" + name + ".mat";
            if (AssetDatabase.LoadAssetAtPath<Material>(path) != null) return false;
            var m = new Material(shader) { name = name };
            setup?.Invoke(m);
            AssetDatabase.CreateAsset(m, path);
            return true;
        }

        /// <summary>Petite normal map plate (importée comme telle) pour le modèle « LitNormal ».</summary>
        static Texture2D FlatNormalMap()
        {
            var existing = AssetDatabase.LoadAssetAtPath<Texture2D>(FlatNormalPath);
            if (existing != null) return existing;
            var tex = new Texture2D(4, 4, TextureFormat.RGBA32, false);
            var px = new Color32[16];
            for (int i = 0; i < px.Length; i++) px[i] = new Color32(128, 128, 255, 255);
            tex.SetPixels32(px);
            tex.Apply();
            File.WriteAllBytes(FlatNormalPath, tex.EncodeToPNG());
            Object.DestroyImmediate(tex);
            AssetDatabase.ImportAsset(FlatNormalPath, ImportAssetOptions.ForceSynchronousImport);
            if (AssetImporter.GetAtPath(FlatNormalPath) is TextureImporter importer)
            {
                importer.textureType = TextureImporterType.NormalMap;
                importer.mipmapEnabled = false;
                importer.SaveAndReimport();
            }
            return AssetDatabase.LoadAssetAtPath<Texture2D>(FlatNormalPath);
        }

        static void SetupPanelSettings(List<string> log)
        {
            if (AssetDatabase.LoadAssetAtPath<PanelSettings>(PanelSettingsPath) != null) return;
            var ps = ScriptableObject.CreateInstance<PanelSettings>();
            ps.themeStyleSheet = AssetDatabase.LoadAssetAtPath<ThemeStyleSheet>(ThemePath);
            ps.scaleMode = PanelScaleMode.ScaleWithScreenSize;
            ps.referenceResolution = new Vector2Int(1920, 1080);
            ps.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight;
            ps.match = 0.5f;
            ps.sortingOrder = 10;
            AssetDatabase.CreateAsset(ps, PanelSettingsPath);
            log.Add("PanelSettings de l'interface créé.");
        }

        /// <summary>Espace colorimétrique linéaire, résolution, entrées (nouvel Input System + ancien gestionnaire).</summary>
        static bool SetupPlayer(List<string> log)
        {
            if (PlayerSettings.colorSpace != ColorSpace.Linear)
            {
                PlayerSettings.colorSpace = ColorSpace.Linear;
                log.Add("Espace colorimétrique linéaire.");
            }
            if (PlayerSettings.productName != "Blouse Blanche")
            {
                PlayerSettings.productName = "Blouse Blanche";
                log.Add("Nom du produit : Blouse Blanche.");
            }
            PlayerSettings.defaultScreenWidth = 1920;
            PlayerSettings.defaultScreenHeight = 1080;
            PlayerSettings.fullScreenMode = FullScreenMode.FullScreenWindow;
            PlayerSettings.resizableWindow = true;

            // « Both » : le jeu lit le nouvel Input System ; l'interface UI Toolkit reste pilotable
            // même sans EventSystem dans la scène.
            var player = Unsupported.GetSerializedAssetInterfaceSingleton("PlayerSettings");
            if (player == null) return false;
            var so = new SerializedObject(player);
            var input = so.FindProperty("activeInputHandler");
            if (input == null || input.intValue == 2) return false;
            input.intValue = 2;
            so.ApplyModifiedPropertiesWithoutUndo();
            log.Add("Gestion des entrées : Input System et Input Manager (« Both »).");
            return true;
        }

        static void SetupScene(List<string> log)
        {
            if (File.Exists(ScenePath))
            {
                EnsureBuildScene();
                return;
            }
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
            {
                log.Add("Scène non créée (scène courante non enregistrée).");
                return;
            }
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            new GameObject("BlouseBlanche").AddComponent<GameRoot>();

            // Tout est construit à l'exécution : pas d'éclairage précalculé.
            var lighting = AssetDatabase.LoadAssetAtPath<LightingSettings>(LightingPath);
            if (lighting == null)
            {
                lighting = new LightingSettings { name = "BlouseBlanche_Lighting", bakedGI = false, realtimeGI = false };
                AssetDatabase.CreateAsset(lighting, LightingPath);
            }
            Lightmapping.lightingSettings = lighting;
            RenderSettings.skybox = null;

            EditorSceneManager.SaveScene(scene, ScenePath);
            EnsureBuildScene();
            log.Add("Scène du jeu créée et ajoutée au build (" + ScenePath + ").");
        }

        static void EnsureBuildScene()
        {
            var scenes = new List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
            scenes.RemoveAll(s => s.path == ScenePath);
            scenes.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
            EditorBuildSettings.scenes = scenes.ToArray();
        }

        // ================================================================== propriétés sérialisées

        static void SetBool(SerializedObject so, string name, bool v) { var p = Find(so, name); if (p != null) p.boolValue = v; }
        static void SetInt(SerializedObject so, string name, int v) { var p = Find(so, name); if (p != null) p.intValue = v; }
        static void SetFloat(SerializedObject so, string name, float v) { var p = Find(so, name); if (p != null) p.floatValue = v; }
        static void SetObject(SerializedObject so, string name, Object v) { var p = Find(so, name); if (p != null && p.objectReferenceValue == null) p.objectReferenceValue = v; }

        static SerializedProperty Find(SerializedObject so, string name)
        {
            var p = so.FindProperty(name);
            if (p == null) Debug.LogWarning("[BlouseBlanche] Propriété « " + name + " » introuvable sur " + so.targetObject.GetType().Name + " (version d'URP différente ?).");
            return p;
        }
    }
}
