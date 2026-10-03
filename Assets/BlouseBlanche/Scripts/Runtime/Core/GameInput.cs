using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace BlouseBlanche.Core
{
    /// <summary>
    /// Couche d'entrée unique pour tout le jeu.
    /// Fonctionne avec le nouveau Input System (positions physiques des touches : ZQSD sur AZERTY = WASD sur QWERTY)
    /// et avec l'ancien Input Manager (on accepte alors les deux dispositions).
    /// </summary>
    public static class GameInput
    {
        /// <summary>Déplacement normalisé (x = droite, y = avant).</summary>
        public static Vector2 Move()
        {
            float x = 0f, y = 0f;
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            if (kb != null)
            {
                if (kb[Key.W].isPressed || kb[Key.UpArrow].isPressed) y += 1f;
                if (kb[Key.S].isPressed || kb[Key.DownArrow].isPressed) y -= 1f;
                if (kb[Key.D].isPressed || kb[Key.RightArrow].isPressed) x += 1f;
                if (kb[Key.A].isPressed || kb[Key.LeftArrow].isPressed) x -= 1f;
            }
            var pad = Gamepad.current;
            if (pad != null)
            {
                Vector2 s = pad.leftStick.ReadValue();
                if (s.sqrMagnitude > 0.04f) { x += s.x; y += s.y; }
            }
#elif ENABLE_LEGACY_INPUT_MANAGER
            if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.Z) || Input.GetKey(KeyCode.UpArrow)) y += 1f;
            if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow)) y -= 1f;
            if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow)) x += 1f;
            if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.Q) || Input.GetKey(KeyCode.LeftArrow)) x -= 1f;
#endif
            var v = new Vector2(x, y);
            return v.sqrMagnitude > 1f ? v.normalized : v;
        }

        /// <summary>Delta souris en pixels pour cette frame (ou stick droit converti).</summary>
        public static Vector2 Look()
        {
#if ENABLE_INPUT_SYSTEM
            Vector2 d = Vector2.zero;
            var mouse = Mouse.current;
            if (mouse != null) d += mouse.delta.ReadValue();
            var pad = Gamepad.current;
            if (pad != null)
            {
                Vector2 s = pad.rightStick.ReadValue();
                if (s.sqrMagnitude > 0.02f) d += s * (900f * Time.unscaledDeltaTime);
            }
            return d;
#elif ENABLE_LEGACY_INPUT_MANAGER
            // L'axe "Mouse X" de l'Input Manager vaut ~0,1 x le delta en pixels.
            return new Vector2(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y")) * 10f;
#else
            return Vector2.zero;
#endif
        }

        public static bool Sprint()
        {
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            bool k = kb != null && (kb[Key.LeftShift].isPressed || kb[Key.RightShift].isPressed);
            var pad = Gamepad.current;
            return k || (pad != null && pad.leftStickButton.isPressed);
#elif ENABLE_LEGACY_INPUT_MANAGER
            return Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift);
#else
            return false;
#endif
        }

        public static bool InteractDown()
        {
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            var mouse = Mouse.current;
            var pad = Gamepad.current;
            return (kb != null && kb[Key.E].wasPressedThisFrame)
                || (mouse != null && mouse.leftButton.wasPressedThisFrame)
                || (pad != null && pad.buttonSouth.wasPressedThisFrame);
#elif ENABLE_LEGACY_INPUT_MANAGER
            return Input.GetKeyDown(KeyCode.E) || Input.GetMouseButtonDown(0);
#else
            return false;
#endif
        }

        public static bool PauseDown()
        {
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            var pad = Gamepad.current;
            return (kb != null && kb[Key.Escape].wasPressedThisFrame)
                || (pad != null && pad.startButton.wasPressedThisFrame);
#elif ENABLE_LEGACY_INPUT_MANAGER
            return Input.GetKeyDown(KeyCode.Escape);
#else
            return false;
#endif
        }

        public static bool AgendaDown()
        {
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            var pad = Gamepad.current;
            return (kb != null && kb[Key.Tab].wasPressedThisFrame)
                || (pad != null && pad.selectButton.wasPressedThisFrame);
#elif ENABLE_LEGACY_INPUT_MANAGER
            return Input.GetKeyDown(KeyCode.Tab);
#else
            return false;
#endif
        }

        /// <summary>Touche F : avancer le temps jusqu'au prochain évènement.</summary>
        public static bool SkipTimeDown()
        {
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            return kb != null && kb[Key.F].wasPressedThisFrame;
#elif ENABLE_LEGACY_INPUT_MANAGER
            return Input.GetKeyDown(KeyCode.F);
#else
            return false;
#endif
        }

        /// <summary>Clic droit maintenu (ou gâchette gauche) : roue des outils.</summary>
        public static bool WheelHeld()
        {
#if ENABLE_INPUT_SYSTEM
            var mouse = Mouse.current;
            var pad = Gamepad.current;
            return (mouse != null && mouse.rightButton.isPressed)
                || (pad != null && pad.leftTrigger.isPressed);
#elif ENABLE_LEGACY_INPUT_MANAGER
            return Input.GetMouseButton(1);
#else
            return false;
#endif
        }

        /// <summary>Raccourcis d'outils : 1..9, 0, -, = → indice 0..11 (-1 si aucun).</summary>
        public static int ToolHotkeyDown()
        {
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            if (kb == null) return -1;
            for (int i = 0; i < HotkeyKeys.Length; i++)
                if (kb[HotkeyKeys[i]].wasPressedThisFrame) return i;
#elif ENABLE_LEGACY_INPUT_MANAGER
            for (int i = 0; i < HotkeyCodes.Length; i++)
                if (Input.GetKeyDown(HotkeyCodes[i])) return i;
#endif
            return -1;
        }

#if ENABLE_INPUT_SYSTEM
        static readonly Key[] HotkeyKeys =
        {
            Key.Digit1, Key.Digit2, Key.Digit3, Key.Digit4, Key.Digit5, Key.Digit6,
            Key.Digit7, Key.Digit8, Key.Digit9, Key.Digit0, Key.Minus, Key.Equals
        };
#elif ENABLE_LEGACY_INPUT_MANAGER
        static readonly KeyCode[] HotkeyCodes =
        {
            KeyCode.Alpha1, KeyCode.Alpha2, KeyCode.Alpha3, KeyCode.Alpha4, KeyCode.Alpha5, KeyCode.Alpha6,
            KeyCode.Alpha7, KeyCode.Alpha8, KeyCode.Alpha9, KeyCode.Alpha0, KeyCode.Minus, KeyCode.Equals
        };
#endif

        public static bool AnyKeyDown()
        {
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            var mouse = Mouse.current;
            return (kb != null && kb.anyKey.wasPressedThisFrame)
                || (mouse != null && mouse.leftButton.wasPressedThisFrame);
#elif ENABLE_LEGACY_INPUT_MANAGER
            return Input.anyKeyDown;
#else
            return false;
#endif
        }
    }
}
