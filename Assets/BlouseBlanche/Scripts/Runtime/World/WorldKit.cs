using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace BlouseBlanche.World
{
    /// <summary>
    /// Boîte à outils de construction : cache de meshes, création d'objets, lots d'architecture
    /// (murs/sols fusionnés par matériau, UV projetées en coordonnées monde pour des textures continues).
    /// </summary>
    public sealed class WorldKit
    {
        public readonly TextureLibrary Tex;
        public readonly MaterialLibrary Mat;
        readonly Dictionary<string, Mesh> meshes = new Dictionary<string, Mesh>();
        readonly Dictionary<Material, MeshData> batches = new Dictionary<Material, MeshData>();
        readonly Dictionary<Material, bool> batchShadows = new Dictionary<Material, bool>();
        readonly List<UnityEngine.Object> owned = new List<UnityEngine.Object>();

        public WorldKit(TextureLibrary tex, MaterialLibrary mat)
        {
            Tex = tex;
            Mat = mat;
        }

        // ------------------------------------------------------------------ meshes

        public Mesh Cached(string key, Func<MeshData> generator)
        {
            if (meshes.TryGetValue(key, out var m)) return m;
            m = generator().ToMesh(key);
            meshes[key] = m;
            owned.Add(m);
            return m;
        }

        static string K(Vector3 v) => v.x.ToString("F3") + "," + v.y.ToString("F3") + "," + v.z.ToString("F3");

        public Mesh RoundedBoxMesh(Vector3 size, float radius, int segments = 3)
        {
            if (radius <= 0.0005f) return Cached("box:" + K(size), () => MeshFactory.Box(size));
            return Cached("rbox:" + K(size) + ":" + radius.ToString("F4") + ":" + segments, () => MeshFactory.RoundedBox(size, radius, segments));
        }

        public Mesh CylinderMesh(float radius, float height, int segments = 24)
            => Cached("cyl:" + radius.ToString("F4") + ":" + height.ToString("F4") + ":" + segments, () => MeshFactory.Cylinder(radius, height, segments));

        public Mesh RoundedCylinderMesh(float radius, float height, float bevel, int segments = 28)
            => Cached("rcyl:" + radius.ToString("F4") + ":" + height.ToString("F4") + ":" + bevel.ToString("F4") + ":" + segments,
                () => MeshFactory.RoundedCylinder(radius, height, bevel, segments));

        public Mesh SphereMesh(float radius, int rings = 12, int segments = 24)
            => Cached("sph:" + radius.ToString("F4") + ":" + rings + ":" + segments, () => MeshFactory.Sphere(radius, rings, segments));

        public Mesh QuadMesh(float w, float h)
            => Cached("quad:" + w.ToString("F3") + ":" + h.ToString("F3"), () => MeshFactory.QuadFacingZ(w, h));

        public Mesh FromData(string key, MeshData data)
        {
            if (meshes.TryGetValue(key, out var m)) return m;
            m = data.ToMesh(key);
            meshes[key] = m;
            owned.Add(m);
            return m;
        }

        // ------------------------------------------------------------------ objets

        public static Transform Group(Transform parent, string name, Vector3 localPosition, float yawDegrees = 0f)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPosition;
            go.transform.localRotation = Quaternion.Euler(0f, yawDegrees, 0f);
            return go.transform;
        }

        public GameObject Part(Transform parent, string name, Mesh mesh, Material material, Vector3 localPosition, Quaternion localRotation, Vector3 localScale, bool castShadows = true)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPosition;
            go.transform.localRotation = localRotation;
            go.transform.localScale = localScale;
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = material;
            mr.shadowCastingMode = castShadows ? ShadowCastingMode.On : ShadowCastingMode.Off;
            mr.receiveShadows = true;
            return go;
        }

        public GameObject Part(Transform parent, string name, Mesh mesh, Material material, Vector3 localPosition, bool castShadows = true)
            => Part(parent, name, mesh, material, localPosition, Quaternion.identity, Vector3.one, castShadows);

        /// <summary>Boîte biseautée positionnée par son centre.</summary>
        public GameObject Box(Transform parent, string name, Vector3 size, Material material, Vector3 center, float bevel = 0.008f, bool collider = false, Quaternion? rotation = null, bool castShadows = true)
        {
            int seg = bevel > 0.02f ? 3 : 2;
            var go = Part(parent, name, RoundedBoxMesh(size, bevel, seg), material, center, rotation ?? Quaternion.identity, Vector3.one, castShadows);
            if (collider)
            {
                var bc = go.AddComponent<BoxCollider>();
                bc.size = size;
            }
            return go;
        }

        /// <summary>Cylindre posé (base au point donné).</summary>
        public GameObject Cylinder(Transform parent, string name, float radius, float height, Material material, Vector3 basePosition, int segments = 24, bool castShadows = true, Quaternion? rotation = null)
            => Part(parent, name, CylinderMesh(radius, height, segments), material, basePosition, rotation ?? Quaternion.identity, Vector3.one, castShadows);

        public GameObject Sphere(Transform parent, string name, float radius, Material material, Vector3 center, Vector3? scale = null, bool castShadows = true)
            => Part(parent, name, SphereMesh(radius), material, center, Quaternion.identity, scale ?? Vector3.one, castShadows);

        public GameObject Quad(Transform parent, string name, float w, float h, Material material, Vector3 center, Quaternion rotation, bool castShadows = false)
            => Part(parent, name, QuadMesh(w, h), material, center, rotation, Vector3.one, castShadows);

        public static BoxCollider Collider(Transform parent, string name, Vector3 center, Vector3 size)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = center;
            var bc = go.AddComponent<BoxCollider>();
            bc.size = size;
            return bc;
        }

        // ------------------------------------------------------------------ lots d'architecture

        /// <summary>Ajoute une boîte (coordonnées monde) au lot du matériau donné.</summary>
        public void ArchBox(Material material, Vector3 min, Vector3 max, bool castShadows = true)
        {
            Vector3 size = max - min;
            if (size.x <= 1e-4f || size.y <= 1e-4f || size.z <= 1e-4f) return;
            if (!batches.TryGetValue(material, out var md))
            {
                md = new MeshData();
                batches[material] = md;
                batchShadows[material] = castShadows;
            }
            md.Append(MeshFactory.Box(size), (min + max) * 0.5f);
        }

        /// <summary>Ajoute une géométrie quelconque (coordonnées monde) à un lot.</summary>
        public void ArchMesh(Material material, MeshData data, Vector3 offset, Quaternion rotation, bool castShadows = true)
        {
            if (!batches.TryGetValue(material, out var md))
            {
                md = new MeshData();
                batches[material] = md;
                batchShadows[material] = castShadows;
            }
            md.Append(data, offset, rotation, Vector3.one);
        }

        /// <summary>Matérialise les lots : un objet par matériau, UV monde en mètres.</summary>
        public void FlushArchitecture(Transform parent)
        {
            int i = 0;
            foreach (var kv in batches)
            {
                kv.Value.BoxProjectUVs(1f, Vector3.zero);
                var mesh = kv.Value.ToMesh("Arch_" + kv.Key.name + "_" + i);
                owned.Add(mesh);
                Part(parent, "Arch_" + kv.Key.name, mesh, kv.Key, Vector3.zero, Quaternion.identity, Vector3.one, batchShadows[kv.Key]);
                i++;
            }
            batches.Clear();
            batchShadows.Clear();
        }

        public void Dispose()
        {
            foreach (var o in owned) if (o != null) UnityEngine.Object.Destroy(o);
            owned.Clear();
            meshes.Clear();
        }
    }
}
