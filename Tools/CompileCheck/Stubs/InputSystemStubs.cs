// Stubs de compilation (vérification hors Unity uniquement) : sous-ensemble de l'API publique
// du paquet com.unity.inputsystem utilisé par le jeu. Jamais inclus dans le projet Unity.
using UnityEngine;

namespace UnityEngine.InputSystem
{
    public enum Key
    {
        None, Space, Enter, Tab, Backquote, Quote, Semicolon, Comma, Period, Slash, Backslash,
        LeftBracket, RightBracket, Minus, Equals,
        A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
        Digit1, Digit2, Digit3, Digit4, Digit5, Digit6, Digit7, Digit8, Digit9, Digit0,
        LeftShift, RightShift, LeftAlt, RightAlt, LeftCtrl, RightCtrl,
        Escape, LeftArrow, RightArrow, UpArrow, DownArrow, Backspace,
        PageDown, PageUp, Home, End, Insert, Delete,
        F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12
    }

    public abstract class InputControl
    {
        public string name => "";
    }

    public abstract class InputControl<TValue> : InputControl where TValue : struct
    {
        public TValue ReadValue() => default;
    }

    public abstract class InputDevice : InputControl { }
}

namespace UnityEngine.InputSystem.Controls
{
    public class AxisControl : InputControl<float> { }

    public class ButtonControl : AxisControl
    {
        public bool isPressed => false;
        public bool wasPressedThisFrame => false;
        public bool wasReleasedThisFrame => false;
    }

    public class KeyControl : ButtonControl
    {
        public Key keyCode => Key.None;
    }

    public class AnyKeyControl : ButtonControl { }

    public class Vector2Control : InputControl<Vector2>
    {
        public AxisControl x => null;
        public AxisControl y => null;
    }

    public class DeltaControl : Vector2Control { }

    public class StickControl : Vector2Control { }
}

namespace UnityEngine.InputSystem
{
    using UnityEngine.InputSystem.Controls;

    public class Keyboard : InputDevice
    {
        public static Keyboard current => null;
        public KeyControl this[Key key] => null;
        public AnyKeyControl anyKey => null;
    }

    public class Pointer : InputDevice
    {
        public Vector2Control position => null;
        public DeltaControl delta => null;
    }

    public class Mouse : Pointer
    {
        public static Mouse current => null;
        public ButtonControl leftButton => null;
        public ButtonControl rightButton => null;
        public ButtonControl middleButton => null;
        public DeltaControl scroll => null;
    }

    public class Gamepad : InputDevice
    {
        public static Gamepad current => null;
        public StickControl leftStick => null;
        public StickControl rightStick => null;
        public ButtonControl leftStickButton => null;
        public ButtonControl rightStickButton => null;
        public ButtonControl buttonSouth => null;
        public ButtonControl buttonEast => null;
        public ButtonControl buttonWest => null;
        public ButtonControl buttonNorth => null;
        public ButtonControl startButton => null;
        public ButtonControl selectButton => null;
        public ButtonControl leftShoulder => null;
        public ButtonControl rightShoulder => null;
        public ButtonControl leftTrigger => null;
        public ButtonControl rightTrigger => null;
    }
}
