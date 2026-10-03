using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace BlouseBlanche.World
{
    /// <summary>
    /// Fabrique et cache de matériaux URP/Lit.
    /// Les matériaux "modèles" (Resources/BlouseBlanche/Materials) créés par l'outil d'installation
    /// garantissent que les variantes de shader nécessaires sont incluses dans les builds.
    /// </summary>
    public sealed class MaterialLibrary
    {
        public const string TemplateFolder = "BlouseBlanche/Materials/";

        static readonly int BaseMap = Shader.PropertyToID("_BaseMap");
        static readonly int MainTex = Shader.PropertyToID("_MainTex");
        static readonly int BaseColor = Shader.PropertyToID("_BaseColor");
        static readonly int ColorId = Shader.PropertyToID("_Color");
        static readonly int BumpMap = Shader.PropertyToID("_BumpMap");
        static readonly int BumpScale = Shader.PropertyToID("_BumpScale");
        static readonly int Smoothness = Shader.PropertyToID("_Smoothness");
        static readonly int Glossiness = Shader.PropertyToID("_Glossiness");
        static readonly int Metallic = Shader.PropertyToID("_Metallic");
        static readonly int EmissionColor = Shader.PropertyToID("_EmissionColor");
        static readonly int EmissionMap = Shader.PropertyToID("_EmissionMap");

        readonly TextureLibrary textures;
        readonly Dictionary<string, Material> cache = new Dictionary<string, Material>();
        readonly List<Material> owned = new List<Material>();

        Material tplLit, tplLitNormal, tplEmissive, tplGlass;
        Shader litShader;
        bool urp;

        public MaterialLibrary(TextureLibrary textures)
        {
            this.textures = textures;
            tplLit = Resources.Load<Material>(TemplateFolder + "Lit");
            tplLitNormal = Resources.Load<Material>(TemplateFolder + "LitNormal");
            tplEmissive = Resources.Load<Material>(TemplateFolder + "LitEmissive");
            tplGlass = Resources.Load<Material>(TemplateFolder + "Glass");

            litShader = Shader.Find("Universal Render Pipeline/Lit");
            urp = litShader != null && GraphicsSettings.currentRenderPipeline != null;
            if (!urp) litShader = Shader.Find("Standard");
            if (tplLit == null)
                Debug.LogWarning("[BlouseBlanche] Matériaux modèles absents : lancez le menu « Blouse Blanche > Configurer le projet » pour un rendu optimal et des builds complets.");
        }

        Material NewFrom(Material template, bool needsNormal, bool emissive)
        {
            Material m;
            if (template != null) m = new Material(template);
            else
            {
                m = new Material(litShader != null ? litShader : Shader.Find("Hidden/InternalErrorShader"));
                if (needsNormal) m.EnableKeyword("_NORMALMAP");
                if (emissive) m.EnableKeyword("_EMISSION");
            }
            owned.Add(m);
            return m;
        }

        /// <summary>Matériau opaque standard.</summary>
        public Material Lit(string key, Color color, float smoothness, float metallic = 0f, string surface = null, float normalStrength = 1f, float tilingOverride = 0f)
        {
            if (cache.TryGetValue(key, out var cached)) return cached;
            SurfaceTextures s = surface != null ? textures?.Surface(surface) : null;
            bool hasNormal = s != null && s.Normal != null;
            var m = NewFrom(hasNormal ? (tplLitNormal != null ? tplLitNormal : tplLit) : tplLit, hasNormal, false);
            m.name = "BB_" + key;
            m.SetColor(BaseColor, color);
            m.SetColor(ColorId, color);
            m.SetFloat(Smoothness, smoothness);
            m.SetFloat(Glossiness, smoothness);
            m.SetFloat(Metallic, metallic);
            if (s != null)
            {
                float meters = tilingOverride > 0f ? tilingOverride : s.MetersPerTile;
                var tiling = new Vector2(1f / meters, 1f / meters);
                m.SetTexture(BaseMap, s.Albedo);
                m.SetTexture(MainTex, s.Albedo);
                m.SetTextureScale(BaseMap, tiling);
                m.SetTextureScale(MainTex, tiling);
                if (hasNormal)
                {
                    m.SetTexture(BumpMap, s.Normal);
                    m.SetFloat(BumpScale, normalStrength);
                    m.EnableKeyword("_NORMALMAP");
                }
            }
            cache[key] = m;
            return m;
        }

        /// <summary>Matériau avec une texture "décor" (affiche, écran…) en UV 0..1.</summary>
        public Material Decal(string key, string decal, float smoothness = 0.25f, float emission = 0f)
        {
            string cacheKey = key + "|" + decal;
            if (cache.TryGetValue(cacheKey, out var cached)) return cached;
            Texture2D tex = textures?.Decal(decal);
            bool emissive = emission > 0f;
            var m = NewFrom(emissive ? tplEmissive : tplLit, false, emissive);
            m.name = "BB_" + key;
            m.SetColor(BaseColor, Color.white);
            m.SetColor(ColorId, Color.white);
            m.SetFloat(Smoothness, smoothness);
            m.SetFloat(Glossiness, smoothness);
            m.SetFloat(Metallic, 0f);
            if (tex != null)
            {
                m.SetTexture(BaseMap, tex);
                m.SetTexture(MainTex, tex);
            }
            if (emissive)
            {
                m.EnableKeyword("_EMISSION");
                m.SetColor(EmissionColor, Color.white * emission);
                if (tex != null) m.SetTexture(EmissionMap, tex);
                m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
            }
            cache[cacheKey] = m;
            return m;
        }

        /// <summary>Matériau émissif uni (dalles lumineuses, voyants).</summary>
        public Material Emissive(string key, Color baseColor, Color emission)
        {
            if (cache.TryGetValue(key, out var cached)) return cached;
            var m = NewFrom(tplEmissive, false, true);
            m.name = "BB_" + key;
            m.SetColor(BaseColor, baseColor);
            m.SetColor(ColorId, baseColor);
            m.SetFloat(Smoothness, 0.5f);
            m.SetFloat(Glossiness, 0.5f);
            m.EnableKeyword("_EMISSION");
            m.SetColor(EmissionColor, emission);
            m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
            cache[key] = m;
            return m;
        }

        /// <summary>Verre transparent (fenêtres, vitrines, portes vitrées).</summary>
        public Material Glass(string key, Color tint, float smoothness = 0.95f)
        {
            if (cache.TryGetValue(key, out var cached)) return cached;
            Material m;
            if (tplGlass != null) m = NewFrom(tplGlass, false, false);
            else
            {
                m = NewFrom(null, false, false);
                ConfigureTransparent(m, urp);
            }
            m.name = "BB_" + key;
            m.SetColor(BaseColor, tint);
            m.SetColor(ColorId, tint);
            m.SetFloat(Smoothness, smoothness);
            m.SetFloat(Glossiness, smoothness);
            m.SetFloat(Metallic, 0f);
            cache[key] = m;
            return m;
        }

        /// <summary>Réglages de transparence URP/Lit (identiques à ceux de l'éditeur de matériau).</summary>
        public static void ConfigureTransparent(Material m, bool isUrp)
        {
            if (isUrp)
            {
                m.SetFloat("_Surface", 1f);
                m.SetFloat("_Blend", 0f);
                m.SetFloat("_AlphaClip", 0f);
                m.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
                m.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
                m.SetFloat("_SrcBlendAlpha", (float)BlendMode.One);
                m.SetFloat("_DstBlendAlpha", (float)BlendMode.OneMinusSrcAlpha);
                m.SetFloat("_ZWrite", 0f);
                m.SetOverrideTag("RenderType", "Transparent");
                m.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
                m.DisableKeyword("_ALPHATEST_ON");
                m.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                m.SetShaderPassEnabled("DepthOnly", false);
                m.SetShaderPassEnabled("ShadowCaster", false);
                m.renderQueue = (int)RenderQueue.Transparent;
            }
            else
            {
                m.SetFloat("_Mode", 3f);
                m.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
                m.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
                m.SetInt("_ZWrite", 0);
                m.EnableKeyword("_ALPHABLEND_ON");
                m.renderQueue = (int)RenderQueue.Transparent;
            }
        }

        public void Dispose()
        {
            foreach (var m in owned) if (m != null) Object.Destroy(m);
            owned.Clear();
            cache.Clear();
        }
    }
}
