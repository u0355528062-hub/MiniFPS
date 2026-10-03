// Stubs de compilation (vérification hors Unity uniquement) : sous-ensemble de l'API publique
// des paquets com.unity.render-pipelines.core / universal utilisé par le jeu.
// Jamais inclus dans le projet Unity.
using UnityEngine;

namespace UnityEngine.Rendering
{
    public abstract class VolumeParameter
    {
        public bool overrideState { get; set; }
    }

    public class VolumeParameter<T> : VolumeParameter
    {
        public virtual T value { get; set; }
        public virtual void Override(T x) { overrideState = true; value = x; }
    }

    public class BoolParameter : VolumeParameter<bool> { public BoolParameter(bool value, bool overrideState = false) { } }
    public class FloatParameter : VolumeParameter<float> { public FloatParameter(float value, bool overrideState = false) { } }
    public class MinFloatParameter : FloatParameter { public MinFloatParameter(float value, float min, bool overrideState = false) : base(value, overrideState) { } }
    public class ClampedFloatParameter : FloatParameter { public ClampedFloatParameter(float value, float min, float max, bool overrideState = false) : base(value, overrideState) { } }
    public class IntParameter : VolumeParameter<int> { public IntParameter(int value, bool overrideState = false) { } }
    public class ColorParameter : VolumeParameter<Color> { public ColorParameter(Color value, bool overrideState = false) { } }
    public class Vector2Parameter : VolumeParameter<Vector2> { public Vector2Parameter(Vector2 value, bool overrideState = false) { } }
    public class Vector4Parameter : VolumeParameter<Vector4> { public Vector4Parameter(Vector4 value, bool overrideState = false) { } }

    public class VolumeComponent : ScriptableObject
    {
        public bool active = true;
    }

    public sealed class VolumeProfile : ScriptableObject
    {
        public T Add<T>(bool overrides = false) where T : VolumeComponent => null;
        public bool TryGet<T>(out T component) where T : VolumeComponent { component = null; return false; }
        public bool Has<T>() where T : VolumeComponent => false;
        public void Remove<T>() where T : VolumeComponent { }
    }

    public class Volume : MonoBehaviour
    {
        public bool isGlobal { get; set; }
        public float priority { get; set; }
        public float weight = 1f;
        public float blendDistance;
        public VolumeProfile sharedProfile;
        public VolumeProfile profile { get; set; }
    }
}

namespace UnityEngine.Rendering.Universal
{
    public enum TonemappingMode { None, Neutral, ACES }
    public enum DepthOfFieldMode { Off, Gaussian, Bokeh }
    public enum FilmGrainLookup { Thin1, Thin2, Medium1, Medium2, Medium3, Medium4, Medium5, Medium6, Large01, Large02, Custom }
    public enum AntialiasingMode { None, FastApproximateAntialiasing, SubpixelMorphologicalAntiAliasing, TemporalAntiAliasing }
    public enum AntialiasingQuality { Low, Medium, High }

    public sealed class TonemappingModeParameter : VolumeParameter<TonemappingMode> { public TonemappingModeParameter(TonemappingMode value, bool overrideState = false) { } }
    public sealed class DepthOfFieldModeParameter : VolumeParameter<DepthOfFieldMode> { public DepthOfFieldModeParameter(DepthOfFieldMode value, bool overrideState = false) { } }
    public sealed class FilmGrainLookupParameter : VolumeParameter<FilmGrainLookup> { public FilmGrainLookupParameter(FilmGrainLookup value, bool overrideState = false) { } }

    public sealed class Tonemapping : VolumeComponent { public TonemappingModeParameter mode; }

    public sealed class Bloom : VolumeComponent
    {
        public MinFloatParameter threshold, intensity;
        public ClampedFloatParameter scatter;
        public MinFloatParameter clamp;
        public ColorParameter tint;
        public BoolParameter highQualityFiltering;
    }

    public sealed class ColorAdjustments : VolumeComponent
    {
        public FloatParameter postExposure;
        public ClampedFloatParameter contrast, hueShift, saturation;
        public ColorParameter colorFilter;
    }

    public sealed class WhiteBalance : VolumeComponent { public ClampedFloatParameter temperature, tint; }

    public sealed class ShadowsMidtonesHighlights : VolumeComponent { public Vector4Parameter shadows, midtones, highlights; }

    public sealed class Vignette : VolumeComponent
    {
        public ColorParameter color;
        public Vector2Parameter center;
        public ClampedFloatParameter intensity, smoothness;
        public BoolParameter rounded;
    }

    public sealed class FilmGrain : VolumeComponent
    {
        public FilmGrainLookupParameter type;
        public ClampedFloatParameter intensity, response;
    }

    public sealed class DepthOfField : VolumeComponent
    {
        public DepthOfFieldModeParameter mode;
        public MinFloatParameter gaussianStart, gaussianEnd;
        public ClampedFloatParameter gaussianMaxRadius;
        public BoolParameter highQualitySampling;
    }

    public sealed class UniversalAdditionalCameraData : MonoBehaviour
    {
        public bool renderPostProcessing { get; set; }
        public AntialiasingMode antialiasing { get; set; }
        public AntialiasingQuality antialiasingQuality { get; set; }
        public bool renderShadows { get; set; }
        public bool requiresDepthTexture { get; set; }
        public bool stopNaN { get; set; }
        public bool dithering { get; set; }
    }

    public static class CameraExtensions
    {
        public static UniversalAdditionalCameraData GetUniversalAdditionalCameraData(this Camera camera) => null;
    }

    public class PostProcessData : ScriptableObject { }

    public abstract class ScriptableRendererData : ScriptableObject { }

    public class UniversalRendererData : ScriptableRendererData
    {
        public PostProcessData postProcessData = null;
    }

    public class UniversalRenderPipelineAsset : RenderPipelineAsset
    {
        public override RenderPipeline CreatePipeline() => null;
        public static UniversalRenderPipelineAsset Create(ScriptableRendererData rendererData = null) => null;
        public float renderScale { get; set; }
        public int msaaSampleCount { get; set; }
        public float shadowDistance { get; set; }
        public bool supportsHDR { get; set; }
        public int shadowCascadeCount { get; set; }
        public bool supportsCameraDepthTexture { get; set; }
        public bool supportsCameraOpaqueTexture { get; set; }
    }

    public static class UniversalRenderPipeline
    {
        public static UniversalRenderPipelineAsset asset => null;
    }
}
