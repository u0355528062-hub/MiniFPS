using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace BlouseBlanche.Core
{
    /// <summary>
    /// Post-traitement cinématographique (URP) : tonemapping ACES, bloom, étalonnage, vignette,
    /// grain fin et profondeur de champ pilotée (menus / consultation).
    /// </summary>
    public sealed class PostFX : MonoBehaviour
    {
        Volume volume;
        VolumeProfile profile;
        ColorAdjustments color;
        DepthOfField dof;
        Bloom bloom;
        Vignette vignette;
        FilmGrain grain;

        float dofTarget;       // 0 = net, 1 = flou de fond
        float dofAmount;
        float focusStart = 2f;
        float focusEnd = 8f;
        float exposureBase = 0.25f;
        float brightness;

        public void Initialize()
        {
            profile = ScriptableObject.CreateInstance<VolumeProfile>();
            profile.name = "BlouseBlanche_Runtime";

            var tone = profile.Add<Tonemapping>(true);
            tone.mode.Override(TonemappingMode.ACES);

            bloom = profile.Add<Bloom>(true);
            bloom.threshold.Override(1.05f);
            bloom.intensity.Override(0.45f);
            bloom.scatter.Override(0.68f);
            bloom.highQualityFiltering.Override(true);

            color = profile.Add<ColorAdjustments>(true);
            color.postExposure.Override(exposureBase);
            color.contrast.Override(9f);
            color.saturation.Override(6f);

            var wb = profile.Add<WhiteBalance>(true);
            wb.temperature.Override(4f);
            wb.tint.Override(1f);

            var smh = profile.Add<ShadowsMidtonesHighlights>(true);
            smh.shadows.Override(new Vector4(0.96f, 0.99f, 1.05f, -0.02f));
            smh.highlights.Override(new Vector4(1.03f, 1.0f, 0.97f, 0f));

            vignette = profile.Add<Vignette>(true);
            vignette.intensity.Override(0.24f);
            vignette.smoothness.Override(0.45f);
            vignette.rounded.Override(false);

            grain = profile.Add<FilmGrain>(true);
            grain.type.Override(FilmGrainLookup.Thin1);
            grain.intensity.Override(0.12f);
            grain.response.Override(0.85f);

            dof = profile.Add<DepthOfField>(true);
            dof.mode.Override(DepthOfFieldMode.Gaussian);
            dof.gaussianStart.Override(1000f);
            dof.gaussianEnd.Override(1001f);
            dof.gaussianMaxRadius.Override(1.2f);
            dof.highQualitySampling.Override(true);

            var go = new GameObject("GlobalVolume");
            go.transform.SetParent(transform, false);
            volume = go.AddComponent<Volume>();
            volume.isGlobal = true;
            volume.priority = 10f;
            volume.sharedProfile = profile;
        }

        public void SetBrightness(float b) => brightness = Mathf.Clamp(b, -1f, 1f);

        /// <summary>Qualité : coupe les effets coûteux en bas de gamme.</summary>
        public void ApplyQuality(QualityPreset q)
        {
            if (bloom == null) return;
            bloom.highQualityFiltering.Override(q >= QualityPreset.Haute);
            grain.active = q >= QualityPreset.Moyenne;
            dof.highQualitySampling.Override(q >= QualityPreset.Haute);
        }

        /// <summary>Flou d'arrière-plan : menus (fort) ou consultation (léger, mise au point sur le patient).</summary>
        public void SetFocus(bool enabled, float start = 2f, float end = 8f)
        {
            dofTarget = enabled ? 1f : 0f;
            focusStart = Mathf.Max(0.1f, start);
            focusEnd = Mathf.Max(focusStart + 0.5f, end);
        }

        /// <summary>Petit "flash" d'exposition (ex. évènement urgent).</summary>
        public void Pulse(float amount)
        {
            pulse = Mathf.Max(pulse, amount);
        }

        float pulse;

        void Update()
        {
            if (profile == null) return;
            float dt = Time.unscaledDeltaTime;
            dofAmount = Mathf.MoveTowards(dofAmount, dofTarget, dt * 1.6f);
            if (dofAmount <= 0.001f)
            {
                dof.gaussianStart.Override(1000f);
                dof.gaussianEnd.Override(1001f);
            }
            else
            {
                float k = dofAmount * dofAmount * (3f - 2f * dofAmount);
                dof.gaussianStart.Override(Mathf.Lerp(60f, focusStart, k));
                dof.gaussianEnd.Override(Mathf.Lerp(120f, focusEnd, k));
            }

            pulse = Mathf.MoveTowards(pulse, 0f, dt * 0.8f);
            color.postExposure.Override(exposureBase + brightness * 1.2f + pulse);
            vignette.intensity.Override(0.24f + pulse * 0.25f);
        }

        void OnDestroy()
        {
            if (profile != null) Destroy(profile);
        }
    }
}
