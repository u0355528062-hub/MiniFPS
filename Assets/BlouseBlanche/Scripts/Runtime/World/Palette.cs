using UnityEngine;

namespace BlouseBlanche.World
{
    /// <summary>Matériaux partagés par tous les lieux (cabinet, salon, box des urgences).</summary>
    public sealed class Palette
    {
        public readonly Material Wall, AccentSage, AccentTeal, AccentNavy, Laminate, Vinyl, VinylBreak, Ceiling, Baseboard,
            DoorWood, DoorFrame, WindowFrame, Glass, GlassFrosted, Plaster, Roof, Chrome, Steel, BlackMetal,
            PlasticWhite, PlasticGrey, PlasticDark, FabricTeal, FabricCharcoal, FabricMustard, FabricNavy, FabricRug, FabricScreen,
            LeatherExam, LeatherBlack, Oak, Walnut, DeskWhite, ExamPaper, Leaf, LeafDark, Terracotta, PotWhite, Soil,
            Mirror, Ceramic, Yellow, LightPanel, Rubber, Grass, Asphalt, Paving, Brick, Stone, RoadPaint, Bark, Foliage, FoliageDark,
            CarRed, CarBlue, DarkGlass, Tiles, Cork, Gold, KidRed, KidBlue, KidYellow, KidGreen, Mat, Water, Led, LedRed;

        public Palette(MaterialLibrary m)
        {
            Wall = m.Lit("Wall", Color.white, 0.12f, 0f, "Paint", 0.5f);
            AccentSage = m.Lit("AccentSage", new Color(0.74f, 0.80f, 0.70f), 0.12f, 0f, "Paint", 0.5f);
            AccentTeal = m.Lit("AccentTeal", new Color(0.62f, 0.78f, 0.80f), 0.12f, 0f, "Paint", 0.5f);
            AccentNavy = m.Lit("AccentNavy", new Color(0.26f, 0.33f, 0.46f), 0.15f, 0f, "Paint", 0.5f);
            Laminate = m.Lit("Laminate", Color.white, 0.48f, 0f, "Laminate", 0.9f);
            Vinyl = m.Lit("Vinyl", Color.white, 0.42f, 0f, "Vinyl", 0.4f);
            VinylBreak = m.Lit("VinylBreak", Color.white, 0.38f, 0f, "VinylBreak", 0.4f);
            Ceiling = m.Lit("Ceiling", Color.white, 0.05f, 0f, "Ceiling", 0.8f);
            Baseboard = m.Lit("Baseboard", new Color(0.94f, 0.94f, 0.93f), 0.45f);
            DoorWood = m.Lit("DoorWood", Color.white, 0.4f, 0f, "Oak", 0.6f, 1.2f);
            DoorFrame = m.Lit("DoorFrame", new Color(0.93f, 0.93f, 0.92f), 0.6f);
            WindowFrame = m.Lit("WindowFrame", new Color(0.17f, 0.18f, 0.20f), 0.55f, 0.6f);
            Glass = m.Glass("Glass", new Color(0.82f, 0.90f, 0.94f, 0.14f));
            GlassFrosted = m.Glass("GlassFrosted", new Color(0.93f, 0.96f, 0.98f, 0.55f), 0.6f);
            Plaster = m.Lit("Plaster", Color.white, 0.08f, 0f, "Plaster", 1f);
            Roof = m.Lit("Roof", new Color(0.30f, 0.31f, 0.32f), 0.15f);
            Chrome = m.Lit("Chrome", new Color(0.86f, 0.87f, 0.89f), 0.88f, 1f, "Metal", 0.2f);
            Steel = m.Lit("Steel", new Color(0.74f, 0.75f, 0.77f), 0.62f, 0.9f, "Metal", 0.4f);
            BlackMetal = m.Lit("BlackMetal", new Color(0.07f, 0.07f, 0.08f), 0.45f, 0.6f);
            PlasticWhite = m.Lit("PlasticWhite", new Color(0.92f, 0.93f, 0.94f), 0.6f);
            PlasticGrey = m.Lit("PlasticGrey", new Color(0.55f, 0.58f, 0.62f), 0.45f);
            PlasticDark = m.Lit("PlasticDark", new Color(0.10f, 0.11f, 0.12f), 0.55f);
            FabricTeal = m.Lit("FabricTeal", new Color(0.16f, 0.46f, 0.50f), 0.12f, 0f, "Fabric", 0.8f);
            FabricCharcoal = m.Lit("FabricCharcoal", new Color(0.24f, 0.26f, 0.29f), 0.12f, 0f, "Fabric", 0.8f);
            FabricMustard = m.Lit("FabricMustard", new Color(0.86f, 0.62f, 0.22f), 0.12f, 0f, "Fabric", 0.8f);
            FabricNavy = m.Lit("FabricNavy", new Color(0.16f, 0.22f, 0.36f), 0.12f, 0f, "Fabric", 0.8f);
            FabricRug = m.Lit("FabricRug", new Color(0.58f, 0.42f, 0.38f), 0.05f, 0f, "Fabric", 1.2f, 0.25f);
            FabricScreen = m.Lit("FabricScreen", new Color(0.86f, 0.90f, 0.92f), 0.1f, 0f, "Fabric", 0.5f);
            LeatherExam = m.Lit("LeatherExam", new Color(0.20f, 0.29f, 0.38f), 0.5f, 0f, "Leather", 0.6f);
            LeatherBlack = m.Lit("LeatherBlack", new Color(0.08f, 0.08f, 0.09f), 0.45f, 0f, "Leather", 0.7f);
            Oak = m.Lit("Oak", Color.white, 0.45f, 0f, "Oak", 0.6f);
            Walnut = m.Lit("Walnut", Color.white, 0.55f, 0f, "Walnut", 0.6f);
            DeskWhite = m.Lit("DeskWhite", new Color(0.93f, 0.93f, 0.92f), 0.55f);
            ExamPaper = m.Lit("ExamPaper", new Color(0.97f, 0.97f, 0.96f), 0.15f, 0f, "Fabric", 0.15f);
            Leaf = m.Lit("Leaf", new Color(0.22f, 0.46f, 0.20f), 0.45f);
            LeafDark = m.Lit("LeafDark", new Color(0.12f, 0.30f, 0.13f), 0.45f);
            Terracotta = m.Lit("Terracotta", new Color(0.72f, 0.40f, 0.28f), 0.25f);
            PotWhite = m.Lit("PotWhite", new Color(0.90f, 0.89f, 0.86f), 0.5f);
            Soil = m.Lit("Soil", new Color(0.16f, 0.11f, 0.08f), 0.05f);
            Mirror = m.Lit("Mirror", new Color(0.92f, 0.94f, 0.96f), 0.98f, 1f);
            Ceramic = m.Lit("Ceramic", new Color(0.97f, 0.97f, 0.98f), 0.85f);
            Yellow = m.Lit("DasriYellow", new Color(0.96f, 0.78f, 0.10f), 0.5f);
            LightPanel = m.Emissive("LightPanel", Color.white, new Color(1.0f, 0.96f, 0.90f) * 3.2f);
            Rubber = m.Lit("Rubber", new Color(0.05f, 0.05f, 0.05f), 0.2f);
            Grass = m.Lit("Grass", Color.white, 0.12f, 0f, "Grass", 1f);
            Asphalt = m.Lit("Asphalt", Color.white, 0.25f, 0f, "Asphalt", 0.8f);
            Paving = m.Lit("Paving", Color.white, 0.2f, 0f, "Paving", 0.8f);
            Brick = m.Lit("Brick", Color.white, 0.15f, 0f, "Brick", 1f);
            Stone = m.Lit("Stone", new Color(0.70f, 0.69f, 0.66f), 0.2f, 0f, "Paving", 0.5f, 2f);
            RoadPaint = m.Lit("RoadPaint", new Color(0.93f, 0.93f, 0.90f), 0.3f);
            Bark = m.Lit("Bark", new Color(0.30f, 0.23f, 0.17f), 0.1f, 0f, "Leather", 1.5f, 0.3f);
            Foliage = m.Lit("Foliage", new Color(0.62f, 0.85f, 0.55f), 0.25f, 0f, "Grass", 1.5f, 1.2f);
            FoliageDark = m.Lit("FoliageDark", new Color(0.45f, 0.65f, 0.42f), 0.25f, 0f, "Grass", 1.5f, 1.2f);
            CarRed = m.Lit("CarRed", new Color(0.55f, 0.06f, 0.07f), 0.85f, 0.5f);
            CarBlue = m.Lit("CarBlue", new Color(0.16f, 0.24f, 0.36f), 0.85f, 0.5f);
            DarkGlass = m.Lit("DarkGlass", new Color(0.05f, 0.07f, 0.09f), 0.93f, 0.2f);
            Tiles = m.Lit("Tiles", Color.white, 0.8f, 0f, "Tiles", 0.8f);
            Cork = m.Lit("Cork", new Color(0.70f, 0.52f, 0.36f), 0.05f, 0f, "Leather", 1.5f, 0.2f);
            Gold = m.Lit("Gold", new Color(0.83f, 0.68f, 0.38f), 0.7f, 1f);
            KidRed = m.Lit("KidRed", new Color(0.88f, 0.22f, 0.22f), 0.55f);
            KidBlue = m.Lit("KidBlue", new Color(0.18f, 0.45f, 0.88f), 0.55f);
            KidYellow = m.Lit("KidYellow", new Color(0.98f, 0.78f, 0.18f), 0.55f);
            KidGreen = m.Lit("KidGreen", new Color(0.24f, 0.72f, 0.36f), 0.55f);
            Mat = m.Lit("Mat", Color.white, 0.05f, 0f, "Mat", 1f);
            Water = m.Glass("Water", new Color(0.55f, 0.75f, 0.95f, 0.35f), 0.95f);
            Led = m.Emissive("LedGreen", new Color(0.2f, 0.9f, 0.5f), new Color(0.2f, 1.0f, 0.5f) * 4f);
            LedRed = m.Emissive("LedRed", new Color(0.9f, 0.2f, 0.2f), new Color(1.0f, 0.2f, 0.15f) * 4f);
        }
    }
}
