using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace BlouseBlanche.World
{
    /// <summary>
    /// Géométrie en construction (C# pur, testable hors moteur), convertie en Mesh à la fin.
    /// Convention : triangles en sens horaire vu de face (convention Unity),
    /// soit cross(b - a, c - a) orienté comme la normale extérieure.
    /// </summary>
    public sealed class MeshData
    {
        public readonly List<Vector3> Vertices = new List<Vector3>();
        public readonly List<Vector3> Normals = new List<Vector3>();
        public readonly List<Vector2> UVs = new List<Vector2>();
        public readonly List<int> Triangles = new List<int>();

        public int VertexCount => Vertices.Count;

        public int AddVertex(Vector3 position, Vector3 normal, Vector2 uv)
        {
            Vertices.Add(position);
            Normals.Add(normal);
            UVs.Add(uv);
            return Vertices.Count - 1;
        }

        public void AddTriangle(int a, int b, int c)
        {
            Triangles.Add(a);
            Triangles.Add(b);
            Triangles.Add(c);
        }

        /// <summary>Ajoute une autre géométrie transformée (rotation, échelle, translation).</summary>
        public void Append(MeshData other, Vector3 offset, Quaternion rotation, Vector3 scale)
        {
            int baseIndex = Vertices.Count;
            Vector3 invScale = new Vector3(
                Mathf.Abs(scale.x) > 1e-6f ? 1f / scale.x : 0f,
                Mathf.Abs(scale.y) > 1e-6f ? 1f / scale.y : 0f,
                Mathf.Abs(scale.z) > 1e-6f ? 1f / scale.z : 0f);
            bool mirrored = scale.x * scale.y * scale.z < 0f;
            for (int i = 0; i < other.Vertices.Count; i++)
            {
                Vector3 p = other.Vertices[i];
                p = new Vector3(p.x * scale.x, p.y * scale.y, p.z * scale.z);
                Vertices.Add(rotation * p + offset);
                Vector3 n = other.Normals[i];
                n = new Vector3(n.x * invScale.x, n.y * invScale.y, n.z * invScale.z);
                float m = n.magnitude;
                Normals.Add(m > 1e-8f ? rotation * (n / m) : Vector3.up);
                UVs.Add(other.UVs[i]);
            }
            for (int t = 0; t < other.Triangles.Count; t += 3)
            {
                int a = other.Triangles[t] + baseIndex;
                int b = other.Triangles[t + 1] + baseIndex;
                int c = other.Triangles[t + 2] + baseIndex;
                if (mirrored) AddTriangle(a, c, b);
                else AddTriangle(a, b, c);
            }
        }

        public void Append(MeshData other, Vector3 offset) => Append(other, offset, Quaternion.identity, Vector3.one);

        /// <summary>Remplace les UV par une projection "boîte" en mètres (textures à l'échelle réelle).</summary>
        public void BoxProjectUVs(float metersPerTile, Vector3 offset)
        {
            float k = metersPerTile > 1e-5f ? 1f / metersPerTile : 1f;
            for (int i = 0; i < Vertices.Count; i++)
            {
                Vector3 p = Vertices[i] + offset;
                Vector3 n = Normals[i];
                float ax = Mathf.Abs(n.x), ay = Mathf.Abs(n.y), az = Mathf.Abs(n.z);
                Vector2 uv;
                if (ay >= ax && ay >= az) uv = new Vector2(p.x, n.y >= 0f ? p.z : -p.z);
                else if (ax >= az) uv = new Vector2(n.x >= 0f ? p.z : -p.z, p.y);
                else uv = new Vector2(n.z >= 0f ? -p.x : p.x, p.y);
                UVs[i] = uv * k;
            }
        }

        public Mesh ToMesh(string name)
        {
            var mesh = new Mesh { name = name };
            if (Vertices.Count > 65000) mesh.indexFormat = IndexFormat.UInt32;
            mesh.SetVertices(Vertices);
            mesh.SetNormals(Normals);
            mesh.SetUVs(0, UVs);
            mesh.SetTriangles(Triangles, 0, true);
            if (Vertices.Count > 0) mesh.RecalculateTangents();
            mesh.UploadMeshData(true);
            return mesh;
        }
    }
}
