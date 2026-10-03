using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace BlouseBlanche.Core
{
    [Serializable]
    public sealed class DayRecord
    {
        public int dayIndex;
        public int patientsSeen;
        public int patientsLost;
        public float averageScore;
        public int money;
        public float reputationDelta;
    }

    /// <summary>Progression du mode histoire.</summary>
    [Serializable]
    public sealed class SaveData
    {
        public int version = 1;
        public int dayIndex;            // 0 = Jour 1
        public float reputation = 50f;  // 0..100
        public int money;               // honoraires cumulés (€)
        public int totalPatients;
        public float totalScore;
        public int criticalErrors;
        public List<DayRecord> days = new List<DayRecord>();

        public float AverageScore => totalPatients > 0 ? totalScore / totalPatients : 0f;
    }

    public static class SaveSystem
    {
        static string FilePath => Path.Combine(Application.persistentDataPath, "blouse_blanche_save.json");

        public static bool HasSave()
        {
            try { return File.Exists(FilePath); }
            catch { return false; }
        }

        public static SaveData Load()
        {
            try
            {
                if (File.Exists(FilePath))
                {
                    var data = JsonUtility.FromJson<SaveData>(File.ReadAllText(FilePath));
                    if (data != null)
                    {
                        data.days ??= new List<DayRecord>();
                        data.reputation = Mathf.Clamp(data.reputation, 0f, 100f);
                        data.dayIndex = Mathf.Max(0, data.dayIndex);
                        return data;
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning("[BlouseBlanche] Sauvegarde illisible : " + e.Message);
            }
            return new SaveData();
        }

        public static void Write(SaveData data)
        {
            try
            {
                string tmp = FilePath + ".tmp";
                File.WriteAllText(tmp, JsonUtility.ToJson(data, true));
                if (File.Exists(FilePath)) File.Delete(FilePath);
                File.Move(tmp, FilePath);
            }
            catch (Exception e)
            {
                Debug.LogError("[BlouseBlanche] Impossible d'écrire la sauvegarde : " + e.Message);
            }
        }

        public static void Delete()
        {
            try { if (File.Exists(FilePath)) File.Delete(FilePath); }
            catch (Exception e) { Debug.LogWarning("[BlouseBlanche] Suppression sauvegarde : " + e.Message); }
        }
    }
}
