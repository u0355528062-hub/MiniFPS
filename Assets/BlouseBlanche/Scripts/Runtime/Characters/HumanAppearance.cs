using UnityEngine;

namespace BlouseBlanche.Characters
{
    public enum Sex { Homme, Femme }
    public enum HairStyle { Court, Rase, Carre, Long, Chignon, QueueDeCheval, Boucle, Degarni, Chauve }
    public enum TopStyle { TShirt, Chemise, Pull, Veste, Gilet }

    /// <summary>Apparence complète d'un personnage procédural.</summary>
    public sealed class HumanAppearance
    {
        public Sex Sex;
        public int Age;
        public float Height = 1.75f;
        public float Build = 1f;          // 0.85 mince .. 1.25 corpulent
        public Color Skin;
        public Color Hair;
        public HairStyle HairStyle;
        public TopStyle Top;
        public Color TopColor;
        public Color TopAccent;
        public Color Pants;
        public Color Shoes;
        public Color Iris;
        public bool Glasses;
        public bool Beard;
        public bool Moustache;

        public bool IsChild => Age < 13;
        public bool IsElderly => Age >= 70;

        static readonly Color[] SkinTones =
        {
            new Color(0.96f, 0.80f, 0.69f), new Color(0.92f, 0.74f, 0.60f), new Color(0.84f, 0.64f, 0.49f),
            new Color(0.72f, 0.52f, 0.38f), new Color(0.54f, 0.37f, 0.26f), new Color(0.38f, 0.25f, 0.18f)
        };
        static readonly Color[] HairColors =
        {
            new Color(0.06f, 0.05f, 0.05f), new Color(0.18f, 0.11f, 0.07f), new Color(0.33f, 0.21f, 0.12f),
            new Color(0.72f, 0.57f, 0.34f), new Color(0.52f, 0.24f, 0.11f)
        };
        static readonly Color[] ClothColors =
        {
            new Color(0.16f, 0.24f, 0.40f), new Color(0.55f, 0.12f, 0.15f), new Color(0.20f, 0.42f, 0.36f),
            new Color(0.85f, 0.85f, 0.82f), new Color(0.30f, 0.30f, 0.32f), new Color(0.80f, 0.58f, 0.22f),
            new Color(0.48f, 0.56f, 0.70f), new Color(0.62f, 0.38f, 0.55f), new Color(0.15f, 0.15f, 0.17f),
            new Color(0.70f, 0.45f, 0.35f), new Color(0.40f, 0.50f, 0.25f), new Color(0.92f, 0.78f, 0.55f)
        };
        static readonly Color[] PantsColors =
        {
            new Color(0.20f, 0.28f, 0.42f), new Color(0.14f, 0.18f, 0.28f), new Color(0.10f, 0.10f, 0.11f),
            new Color(0.62f, 0.55f, 0.42f), new Color(0.38f, 0.38f, 0.40f), new Color(0.30f, 0.24f, 0.18f)
        };
        static readonly Color[] ShoeColors =
        {
            new Color(0.08f, 0.07f, 0.07f), new Color(0.30f, 0.18f, 0.10f), new Color(0.92f, 0.92f, 0.90f), new Color(0.20f, 0.22f, 0.26f)
        };
        static readonly Color[] IrisColors =
        {
            new Color(0.25f, 0.15f, 0.08f), new Color(0.35f, 0.22f, 0.10f), new Color(0.25f, 0.42f, 0.55f), new Color(0.30f, 0.40f, 0.25f)
        };

        static T Pick<T>(System.Random r, T[] arr) => arr[r.Next(arr.Length)];
        static float Range(System.Random r, float a, float b) => a + (float)r.NextDouble() * (b - a);

        /// <summary>Génère une apparence crédible et stable (même graine = même personne).</summary>
        public static HumanAppearance Generate(int seed, Sex sex, int age)
        {
            var r = new System.Random(seed);
            var a = new HumanAppearance { Sex = sex, Age = age };

            if (age < 13) a.Height = 0.85f + age * 0.06f + Range(r, -0.04f, 0.04f);
            else if (age < 18) a.Height = sex == Sex.Homme ? Range(1.55f, 1.80f, r) : Range(1.52f, 1.70f, r);
            else a.Height = sex == Sex.Homme ? Range(1.66f, 1.90f, r) : Range(1.55f, 1.76f, r);
            if (age >= 70) a.Height -= 0.04f;

            a.Build = age < 13 ? Range(r, 0.9f, 1.05f) : Range(r, 0.86f, 1.22f) + (age > 45 ? 0.05f : 0f);
            a.Skin = Pick(r, SkinTones);
            a.Iris = Pick(r, IrisColors);

            // Cheveux
            if (age >= 70) a.Hair = r.NextDouble() < 0.5 ? new Color(0.86f, 0.86f, 0.84f) : new Color(0.62f, 0.62f, 0.62f);
            else if (age >= 52 && r.NextDouble() < 0.6) a.Hair = Color.Lerp(Pick(r, HairColors), new Color(0.6f, 0.6f, 0.6f), 0.55f);
            else a.Hair = a.Skin.r < 0.6f ? HairColors[r.Next(2)] : Pick(r, HairColors);

            if (sex == Sex.Homme)
            {
                double h = r.NextDouble();
                if (age >= 55 && h < 0.35) a.HairStyle = HairStyle.Degarni;
                else if (age >= 40 && h < 0.45) a.HairStyle = HairStyle.Rase;
                else if (h < 0.15 && age >= 25) a.HairStyle = HairStyle.Chauve;
                else if (h < 0.25) a.HairStyle = HairStyle.Boucle;
                else a.HairStyle = HairStyle.Court;
                a.Beard = age >= 18 && r.NextDouble() < 0.28;
                a.Moustache = !a.Beard && age >= 30 && r.NextDouble() < 0.12;
            }
            else
            {
                HairStyle[] styles = age >= 65
                    ? new[] { HairStyle.Court, HairStyle.Carre, HairStyle.Chignon }
                    : new[] { HairStyle.Long, HairStyle.Carre, HairStyle.Chignon, HairStyle.QueueDeCheval, HairStyle.Boucle, HairStyle.Long };
                a.HairStyle = Pick(r, styles);
            }

            a.Glasses = age >= 45 ? r.NextDouble() < 0.55 : r.NextDouble() < 0.18;
            if (age < 8) a.Glasses = false;

            // Vêtements
            if (age < 13) a.Top = r.NextDouble() < 0.6 ? TopStyle.TShirt : TopStyle.Pull;
            else if (age >= 65) a.Top = r.NextDouble() < 0.6 ? TopStyle.Gilet : TopStyle.Pull;
            else a.Top = (TopStyle)r.Next(5);
            a.TopColor = Pick(r, ClothColors);
            a.TopAccent = Pick(r, ClothColors);
            if (age < 13) a.TopColor = Color.Lerp(a.TopColor, new Color(0.9f, 0.4f, 0.2f), 0.3f);
            a.Pants = Pick(r, PantsColors);
            a.Shoes = Pick(r, ShoeColors);
            return a;
        }

        static float Range(float a, float b, System.Random r) => Range(r, a, b);

        /// <summary>Tenue de la secrétaire (gilet, badge).</summary>
        public static HumanAppearance Secretary()
        {
            var a = Generate(1234, Sex.Femme, 38);
            a.HairStyle = HairStyle.Chignon;
            a.Hair = new Color(0.30f, 0.19f, 0.11f);
            a.Skin = new Color(0.88f, 0.70f, 0.56f);
            a.Top = TopStyle.Gilet;
            a.TopColor = new Color(0.18f, 0.42f, 0.46f);
            a.TopAccent = new Color(0.93f, 0.93f, 0.90f);
            a.Pants = new Color(0.14f, 0.16f, 0.22f);
            a.Glasses = true;
            a.Height = 1.66f;
            a.Build = 1f;
            return a;
        }
    }
}
