using System.Collections.Generic;
using UnityEngine;

namespace BlouseBlanche.World
{
    /// <summary>
    /// Générateurs de géométrie procédurale : boîtes biseautées, révolutions (lathe), sphères,
    /// capsules effilées, tubes le long d'une courbe, plans.
    /// Les arêtes biseautées accrochent la lumière : c'est ce qui donne un rendu "produit" plutôt que "cube".
    /// </summary>
    public static class MeshFactory
    {
        const float Deg2Rad = Mathf.PI / 180f;

        // ------------------------------------------------------------------ Boîtes

        /// <summary>Boîte à arêtes nettes, centrée sur l'origine.</summary>
        public static MeshData Box(Vector3 size)
        {
            var md = new MeshData();
            Vector3 h = size * 0.5f;
            float[] cx = { -h.x, h.x }, cy = { -h.y, h.y }, cz = { -h.z, h.z };
            BuildBoxFaces(md, h, Vector3.zero, 0f, cx, cy, cz);
            return md;
        }

        /// <summary>Boîte biseautée (rayon d'arrondi en mètres), centrée sur l'origine.</summary>
        public static MeshData RoundedBox(Vector3 size, float radius, int segments = 3)
        {
            Vector3 h = size * 0.5f;
            float maxR = Mathf.Min(h.x, Mathf.Min(h.y, h.z));
            float r = Mathf.Clamp(radius, 0f, maxR * 0.999f);
            if (r < 1e-4f || segments < 1) return Box(size);
            var md = new MeshData();
            Vector3 inner = h - Vector3.one * r;
            BuildBoxFaces(md, h, inner, r, AxisCoords(h.x, r, segments), AxisCoords(h.y, r, segments), AxisCoords(h.z, r, segments));
            return md;
        }

        static float[] AxisCoords(float h, float r, int seg)
        {
            var list = new List<float>();
            float flat = h - r;
            for (int k = seg; k >= 1; k--) list.Add(-(flat + r * Mathf.Tan(k / (float)seg * 45f * Deg2Rad)));
            list.Add(-flat);
            if (flat > 1e-5f) list.Add(flat);
            for (int k = 1; k <= seg; k++) list.Add(flat + r * Mathf.Tan(k / (float)seg * 45f * Deg2Rad));
            // Bornes exactes (évite les erreurs d'arrondi de tan(45°)).
            list[0] = -h;
            list[list.Count - 1] = h;
            return list.ToArray();
        }

        static void BuildBoxFaces(MeshData md, Vector3 h, Vector3 inner, float r, float[] cx, float[] cy, float[] cz)
        {
            // (normale, axe u, axe v) avec cross(u, v) = normale, et la liste de coordonnées associée à chaque axe.
            Face(md, Vector3.right, Vector3.up, Vector3.forward, h.x, cy, cz, inner, r);
            Face(md, Vector3.left, Vector3.forward, Vector3.up, h.x, cz, cy, inner, r);
            Face(md, Vector3.up, Vector3.forward, Vector3.right, h.y, cz, cx, inner, r);
            Face(md, Vector3.down, Vector3.right, Vector3.forward, h.y, cx, cz, inner, r);
            Face(md, Vector3.forward, Vector3.right, Vector3.up, h.z, cx, cy, inner, r);
            Face(md, Vector3.back, Vector3.up, Vector3.right, h.z, cy, cx, inner, r);
        }

        static void Face(MeshData md, Vector3 n, Vector3 u, Vector3 v, float hn, float[] uc, float[] vc, Vector3 inner, float r)
        {
            int nu = uc.Length, nv = vc.Length;
            int start = md.VertexCount;
            for (int i = 0; i < nu; i++)
            {
                for (int j = 0; j < nv; j++)
                {
                    Vector3 p = n * hn + u * uc[i] + v * vc[j];
                    Vector3 pos, normal;
                    if (r > 0f)
                    {
                        Vector3 q = new Vector3(
                            Mathf.Clamp(p.x, -inner.x, inner.x),
                            Mathf.Clamp(p.y, -inner.y, inner.y),
                            Mathf.Clamp(p.z, -inner.z, inner.z));
                        Vector3 d = p - q;
                        normal = d.sqrMagnitude > 1e-12f ? d.normalized : n;
                        pos = q + normal * r;
                    }
                    else
                    {
                        pos = p;
                        normal = n;
                    }
                    md.AddVertex(pos, normal, FaceUV(p, n));
                }
            }
            for (int i = 0; i < nu - 1; i++)
            {
                for (int j = 0; j < nv - 1; j++)
                {
                    int a = start + i * nv + j;      // (i, j)
                    int b = start + (i + 1) * nv + j; // (i+1, j)
                    int c = start + i * nv + j + 1;   // (i, j+1)
                    int d = b + 1;                    // (i+1, j+1)
                    md.AddTriangle(a, d, c);
                    md.AddTriangle(a, b, d);
                }
            }
        }

        static Vector2 FaceUV(Vector3 p, Vector3 n)
        {
            if (n.y > 0.5f) return new Vector2(p.x, p.z);
            if (n.y < -0.5f) return new Vector2(p.x, -p.z);
            if (n.x > 0.5f) return new Vector2(p.z, p.y);
            if (n.x < -0.5f) return new Vector2(-p.z, p.y);
            if (n.z > 0.5f) return new Vector2(-p.x, p.y);
            return new Vector2(p.x, p.y);
        }

        // ------------------------------------------------------------------ Plans

        /// <summary>Plan horizontal (normale +Y) centré, UV en mètres.</summary>
        public static MeshData PlaneXZ(float sizeX, float sizeZ, int divX = 1, int divZ = 1)
        {
            var md = new MeshData();
            divX = Mathf.Max(1, divX);
            divZ = Mathf.Max(1, divZ);
            // u = Z, v = X  (cross(Z, X) = Y)
            for (int i = 0; i <= divZ; i++)
            {
                for (int j = 0; j <= divX; j++)
                {
                    float z = -sizeZ * 0.5f + sizeZ * i / divZ;
                    float x = -sizeX * 0.5f + sizeX * j / divX;
                    md.AddVertex(new Vector3(x, 0f, z), Vector3.up, new Vector2(x, z));
                }
            }
            int nv = divX + 1;
            for (int i = 0; i < divZ; i++)
            {
                for (int j = 0; j < divX; j++)
                {
                    int a = i * nv + j, b = (i + 1) * nv + j, c = a + 1, d = b + 1;
                    md.AddTriangle(a, d, c);
                    md.AddTriangle(a, b, d);
                }
            }
            return md;
        }

        /// <summary>Quad vertical face à +Z (visible depuis +Z), UV 0..1. Pour affiches, écrans, panneaux.</summary>
        public static MeshData QuadFacingZ(float width, float height)
        {
            var md = new MeshData();
            float hw = width * 0.5f, hh = height * 0.5f;
            // Vu depuis +Z, la droite de l'observateur est -X.
            int a = md.AddVertex(new Vector3(hw, -hh, 0f), Vector3.forward, new Vector2(0f, 0f));
            int b = md.AddVertex(new Vector3(-hw, -hh, 0f), Vector3.forward, new Vector2(1f, 0f));
            int c = md.AddVertex(new Vector3(hw, hh, 0f), Vector3.forward, new Vector2(0f, 1f));
            int d = md.AddVertex(new Vector3(-hw, hh, 0f), Vector3.forward, new Vector2(1f, 1f));
            // u = vers le haut (c - a), v = vers -X (b - a) : cross(up, -X) = +Z
            md.AddTriangle(a, c, d);
            md.AddTriangle(a, d, b);
            return md;
        }

        // ------------------------------------------------------------------ Révolutions

        /// <summary>
        /// Solide de révolution autour de Y. Profil = points (rayon, hauteur) du bas vers le haut.
        /// Dupliquer un point du profil crée une arête vive.
        /// </summary>
        public static MeshData Lathe(IList<Vector2> profile, int segments = 24, float vScale = 1f)
        {
            var md = new MeshData();
            int n = profile.Count;
            if (n < 2) return md;
            segments = Mathf.Max(3, segments);
            var normals2 = new Vector2[n];
            var lengths = new float[n];
            for (int i = 0; i < n; i++)
            {
                Vector2 prev = profile[Mathf.Max(0, i - 1)];
                Vector2 next = profile[Mathf.Min(n - 1, i + 1)];
                if (i > 0 && i < n - 1)
                {
                    // Arête vive : si le point est dupliqué, on prend la tangente du côté "propre".
                    if ((profile[i] - profile[i - 1]).sqrMagnitude < 1e-10f) prev = profile[i];
                    else if ((profile[i + 1] - profile[i]).sqrMagnitude < 1e-10f) next = profile[i];
                }
                Vector2 t = next - prev;
                if (t.sqrMagnitude < 1e-12f) t = Vector2.up;
                t.Normalize();
                normals2[i] = new Vector2(t.y, -t.x);
                lengths[i] = i == 0 ? 0f : lengths[i - 1] + Vector2.Distance(profile[i], profile[i - 1]);
            }

            for (int i = 0; i < n; i++)
            {
                for (int j = 0; j <= segments; j++)
                {
                    float a = j / (float)segments * Mathf.PI * 2f;
                    float ca = Mathf.Cos(a), sa = Mathf.Sin(a);
                    Vector2 p = profile[i];
                    Vector2 nn = normals2[i];
                    var pos = new Vector3(p.x * ca, p.y, p.x * sa);
                    var nor = new Vector3(nn.x * ca, nn.y, nn.x * sa).normalized;
                    md.AddVertex(pos, nor, new Vector2(j / (float)segments, lengths[i] * vScale));
                }
            }
            int stride = segments + 1;
            for (int i = 0; i < n - 1; i++)
            {
                for (int j = 0; j < segments; j++)
                {
                    int a = i * stride + j;          // (i, j)
                    int b = (i + 1) * stride + j;    // (i+1, j)
                    int c = i * stride + j + 1;      // (i, j+1)
                    int d = b + 1;                   // (i+1, j+1)
                    md.AddTriangle(a, d, c);
                    md.AddTriangle(a, b, d);
                }
            }
            return md;
        }

        public static MeshData Sphere(float radius, int rings = 12, int segments = 24)
        {
            var prof = new List<Vector2>();
            rings = Mathf.Max(3, rings);
            for (int i = 0; i <= rings; i++)
            {
                float phi = -90f + 180f * i / rings;
                prof.Add(new Vector2(radius * Mathf.Cos(phi * Deg2Rad), radius * Mathf.Sin(phi * Deg2Rad)));
            }
            prof[0] = new Vector2(0f, -radius);
            prof[prof.Count - 1] = new Vector2(0f, radius);
            return Lathe(prof, segments);
        }

        /// <summary>Cylindre plein à bouchons plats, base à y=0.</summary>
        public static MeshData Cylinder(float radius, float height, int segments = 24, bool caps = true)
        {
            var prof = new List<Vector2>();
            if (caps) { prof.Add(new Vector2(0f, 0f)); prof.Add(new Vector2(radius, 0f)); }
            prof.Add(new Vector2(radius, 0f));
            prof.Add(new Vector2(radius, height));
            if (caps) { prof.Add(new Vector2(radius, height)); prof.Add(new Vector2(0f, height)); }
            return Lathe(prof, segments);
        }

        /// <summary>Cylindre aux bords arrondis (galets, assises, boutons…), base à y=0.</summary>
        public static MeshData RoundedCylinder(float radius, float height, float bevel, int segments = 28)
        {
            bevel = Mathf.Clamp(bevel, 0.0005f, Mathf.Min(radius, height * 0.5f) * 0.99f);
            var prof = new List<Vector2> { new Vector2(0f, 0f) };
            for (int i = 0; i <= 4; i++)
            {
                float a = -90f + 90f * i / 4f;
                prof.Add(new Vector2(radius - bevel + bevel * Mathf.Cos(a * Deg2Rad), bevel + bevel * Mathf.Sin(a * Deg2Rad)));
            }
            for (int i = 0; i <= 4; i++)
            {
                float a = 90f * i / 4f;
                prof.Add(new Vector2(radius - bevel + bevel * Mathf.Cos(a * Deg2Rad), height - bevel + bevel * Mathf.Sin(a * Deg2Rad)));
            }
            prof.Add(new Vector2(0f, height));
            return Lathe(prof, segments);
        }

        /// <summary>
        /// Capsule effilée suspendue sous son pivot : l'extrémité haute (rayon rTop) est centrée en y=0,
        /// l'extrémité basse (rayon rBottom) en y=-length. Idéal pour les membres.
        /// </summary>
        public static MeshData TaperedCapsule(float rTop, float rBottom, float length, int segments = 16, int capRings = 5)
        {
            var prof = new List<Vector2>();
            for (int i = 0; i <= capRings; i++)
            {
                float a = -90f + 90f * i / capRings;
                prof.Add(new Vector2(rBottom * Mathf.Cos(a * Deg2Rad), -length + rBottom * Mathf.Sin(a * Deg2Rad)));
            }
            for (int i = 0; i <= capRings; i++)
            {
                float a = 90f * i / capRings;
                prof.Add(new Vector2(rTop * Mathf.Cos(a * Deg2Rad), rTop * Mathf.Sin(a * Deg2Rad)));
            }
            prof[0] = new Vector2(0f, -length - rBottom);
            prof[prof.Count - 1] = new Vector2(0f, rTop);
            return Lathe(prof, segments);
        }

        // ------------------------------------------------------------------ Tubes

        /// <summary>Tube de section circulaire le long d'une polyligne (câbles, stéthoscope, cadres).</summary>
        public static MeshData Tube(IList<Vector3> path, float radius, int sides = 10, bool capEnds = true)
        {
            var md = new MeshData();
            int n = path.Count;
            if (n < 2) return md;
            sides = Mathf.Max(3, sides);

            Vector3 prevT = (path[1] - path[0]).normalized;
            Vector3 normal = Vector3.Cross(prevT, Mathf.Abs(prevT.y) < 0.95f ? Vector3.up : Vector3.right).normalized;
            float len = 0f;
            for (int i = 0; i < n; i++)
            {
                Vector3 t;
                if (i == 0) t = (path[1] - path[0]).normalized;
                else if (i == n - 1) t = (path[n - 1] - path[n - 2]).normalized;
                else t = ((path[i + 1] - path[i]).normalized + (path[i] - path[i - 1]).normalized).normalized;
                if (t.sqrMagnitude < 1e-8f) t = prevT;

                // Transport parallèle du repère : pas de torsion.
                Vector3 axis = Vector3.Cross(prevT, t);
                if (axis.sqrMagnitude > 1e-10f)
                {
                    float ang = Mathf.Acos(Mathf.Clamp(Vector3.Dot(prevT, t), -1f, 1f));
                    normal = RotateAround(normal, axis.normalized, ang);
                }
                normal = (normal - t * Vector3.Dot(normal, t)).normalized;
                Vector3 binormal = Vector3.Cross(normal, t);
                prevT = t;
                if (i > 0) len += Vector3.Distance(path[i], path[i - 1]);

                for (int j = 0; j <= sides; j++)
                {
                    float a = j / (float)sides * Mathf.PI * 2f;
                    Vector3 dir = normal * Mathf.Cos(a) + binormal * Mathf.Sin(a);
                    md.AddVertex(path[i] + dir * radius, dir, new Vector2(j / (float)sides, len));
                }
            }
            int stride = sides + 1;
            for (int i = 0; i < n - 1; i++)
            {
                for (int j = 0; j < sides; j++)
                {
                    int a = i * stride + j, b = (i + 1) * stride + j, c = a + 1, d = b + 1;
                    md.AddTriangle(a, d, c);
                    md.AddTriangle(a, b, d);
                }
            }
            if (capEnds)
            {
                CapTube(md, path[0], -(path[1] - path[0]).normalized, 0, stride, sides, false);
                CapTube(md, path[n - 1], (path[n - 1] - path[n - 2]).normalized, (n - 1) * stride, stride, sides, true);
            }
            return md;
        }

        static void CapTube(MeshData md, Vector3 center, Vector3 outward, int ringStart, int stride, int sides, bool end)
        {
            int c = md.AddVertex(center, outward, new Vector2(0.5f, 0.5f));
            int first = md.VertexCount;
            for (int j = 0; j <= sides; j++)
                md.AddVertex(md.Vertices[ringStart + j], outward, new Vector2(0.5f, 0.5f));
            for (int j = 0; j < sides; j++)
            {
                int a = first + j, b = first + j + 1;
                // Orientation choisie pour que la normale géométrique corresponde à "outward".
                Vector3 geo = Vector3.Cross(md.Vertices[a] - md.Vertices[c], md.Vertices[b] - md.Vertices[c]);
                if (Vector3.Dot(geo, outward) >= 0f) md.AddTriangle(c, a, b);
                else md.AddTriangle(c, b, a);
            }
        }

        /// <summary>Rotation de Rodrigues (C# pur, sans appel natif).</summary>
        public static Vector3 RotateAround(Vector3 v, Vector3 axis, float angleRad)
        {
            float c = Mathf.Cos(angleRad), s = Mathf.Sin(angleRad);
            return v * c + Vector3.Cross(axis, v) * s + axis * (Vector3.Dot(axis, v) * (1f - c));
        }

        /// <summary>Anneau (tore) dans le plan XZ.</summary>
        public static MeshData Torus(float majorRadius, float minorRadius, int majorSegments = 32, int minorSides = 10)
        {
            var path = new List<Vector3>();
            for (int i = 0; i <= majorSegments; i++)
            {
                float a = i / (float)majorSegments * Mathf.PI * 2f;
                path.Add(new Vector3(Mathf.Cos(a) * majorRadius, 0f, Mathf.Sin(a) * majorRadius));
            }
            return Tube(path, minorRadius, minorSides, false);
        }

        /// <summary>Arc de cercle échantillonné (utile pour construire des chemins de tubes).</summary>
        public static List<Vector3> Arc(Vector3 center, Vector3 axisA, Vector3 axisB, float radius, float fromDeg, float toDeg, int steps)
        {
            var pts = new List<Vector3>();
            for (int i = 0; i <= steps; i++)
            {
                float a = Mathf.Lerp(fromDeg, toDeg, i / (float)steps) * Deg2Rad;
                pts.Add(center + (axisA * Mathf.Cos(a) + axisB * Mathf.Sin(a)) * radius);
            }
            return pts;
        }
    }
}
