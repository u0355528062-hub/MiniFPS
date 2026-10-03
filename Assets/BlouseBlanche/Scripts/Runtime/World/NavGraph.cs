using System.Collections.Generic;
using UnityEngine;

namespace BlouseBlanche.World
{
    /// <summary>
    /// Graphe de navigation posé à la main sur le plan du cabinet : chaque arête est un couloir
    /// vérifié sans obstacle. Plus prévisible (donc sans bug de blocage) qu'un NavMesh généré à l'exécution.
    /// </summary>
    public sealed class NavGraph
    {
        readonly Dictionary<string, Vector3> nodes = new Dictionary<string, Vector3>();
        readonly Dictionary<string, List<string>> edges = new Dictionary<string, List<string>>();

        public IEnumerable<string> NodeIds => nodes.Keys;

        public void Node(string id, Vector3 position)
        {
            nodes[id] = new Vector3(position.x, 0f, position.z);
            if (!edges.ContainsKey(id)) edges[id] = new List<string>();
        }

        public void Link(string a, string b)
        {
            if (!nodes.ContainsKey(a) || !nodes.ContainsKey(b))
            {
                Debug.LogError("[BlouseBlanche] NavGraph : nœud inconnu " + (nodes.ContainsKey(a) ? b : a));
                return;
            }
            if (!edges[a].Contains(b)) edges[a].Add(b);
            if (!edges[b].Contains(a)) edges[b].Add(a);
        }

        public void Chain(params string[] ids)
        {
            for (int i = 0; i < ids.Length - 1; i++) Link(ids[i], ids[i + 1]);
        }

        public bool Has(string id) => nodes.ContainsKey(id);

        public Vector3 Position(string id) => nodes.TryGetValue(id, out var p) ? p : Vector3.zero;

        public IReadOnlyList<string> Neighbours(string id) => edges.TryGetValue(id, out var l) ? (IReadOnlyList<string>)l : new List<string>();

        /// <summary>Nœud le plus proche d'une position (pour repartir d'où l'on se trouve).</summary>
        public string Nearest(Vector3 position)
        {
            string best = null;
            float bestD = float.MaxValue;
            foreach (var kv in nodes)
            {
                float d = (kv.Value - new Vector3(position.x, 0f, position.z)).sqrMagnitude;
                if (d < bestD) { bestD = d; best = kv.Key; }
            }
            return best;
        }

        /// <summary>Plus court chemin (Dijkstra). Renvoie la liste de nœuds, départ inclus.</summary>
        public List<string> FindPath(string from, string to)
        {
            var result = new List<string>();
            if (!nodes.ContainsKey(from) || !nodes.ContainsKey(to)) return result;
            if (from == to) { result.Add(from); return result; }

            var dist = new Dictionary<string, float>();
            var prev = new Dictionary<string, string>();
            var open = new List<string>();
            foreach (var id in nodes.Keys) dist[id] = float.MaxValue;
            dist[from] = 0f;
            open.Add(from);
            var closed = new HashSet<string>();

            while (open.Count > 0)
            {
                int bi = 0;
                for (int i = 1; i < open.Count; i++) if (dist[open[i]] < dist[open[bi]]) bi = i;
                string cur = open[bi];
                open.RemoveAt(bi);
                if (cur == to) break;
                if (!closed.Add(cur)) continue;
                foreach (var nb in edges[cur])
                {
                    if (closed.Contains(nb)) continue;
                    float nd = dist[cur] + Vector3.Distance(nodes[cur], nodes[nb]);
                    if (nd < dist[nb])
                    {
                        dist[nb] = nd;
                        prev[nb] = cur;
                        if (!open.Contains(nb)) open.Add(nb);
                    }
                }
            }
            if (!prev.ContainsKey(to)) return result;
            string n = to;
            while (n != null)
            {
                result.Add(n);
                n = prev.TryGetValue(n, out var p) ? p : null;
            }
            result.Reverse();
            return result;
        }

        public List<Vector3> FindPathPositions(string from, string to)
        {
            var ids = FindPath(from, to);
            var pts = new List<Vector3>(ids.Count);
            foreach (var id in ids) pts.Add(nodes[id]);
            return pts;
        }
    }

    /// <summary>Place assise : chaise, table d'examen, poste de la secrétaire.</summary>
    public sealed class SeatSpot
    {
        public string Id;
        /// <summary>Position au sol sous le bassin quand le personnage est assis.</summary>
        public Vector3 Anchor;
        /// <summary>Orientation du personnage assis (degrés, autour de Y).</summary>
        public float Yaw;
        /// <summary>Hauteur de l'assise.</summary>
        public float SeatHeight = 0.46f;
        /// <summary>Nœud du graphe devant la place (on y marche, puis on s'assoit).</summary>
        public string ApproachNode;
        /// <summary>Occupant actuel (ou réservation).</summary>
        public object Occupant;

        public Vector3 Forward => Quaternion.Euler(0f, Yaw, 0f) * Vector3.forward;
        public bool Free => Occupant == null;
    }
}
