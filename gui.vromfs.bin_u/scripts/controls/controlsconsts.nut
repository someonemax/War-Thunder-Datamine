const MAX_DEADZONE = 0.5
const MAX_NONLINEARITY = 4
const MAX_CAMERA_SMOOTH = 0.9

const MIN_CAMERA_SPEED = 0.5
const MAX_CAMERA_SPEED = 8

const MAX_SHORTCUTS = 3

enum CONTROL_TYPE {
  HEADER
  SECTION
  SHORTCUT
  AXIS_SHORTCUT
  AXIS
  SPINNER
  DROPRIGHT
  SLIDER
  SWITCH_BOX
  MOUSE_AXIS
  //for controls wizard
  MSG_BOX
  SHORTCUT_GROUP
  LISTBOX
  BUTTON
}

enum AXIS_MODIFIERS {
  NONE = 0x0,
  MIN = 0x8000,
  MAX = 0x4000,
}

//gamepad axes bitmask
enum GAMEPAD_AXIS {
  NOT_AXIS = 0

  LEFT_STICK_HORIZONTAL = 0x1
  LEFT_STICK_VERTICAL = 0x2
  RIGHT_STICK_HORIZONTAL = 0x4
  RIGHT_STICK_VERTICAL = 0x8

  LEFT_TRIGGER = 0x10
  RIGHT_TRIGGER = 0x20
  BOTH_TRIGGER_XBOX = 0x40 // axisId=6 (R+L.Trigger) on XBOX
  BOTH_TRIGGER_PS4 = 0x200 // axisId=9 (R+L.Trigger) on PS4

  LEFT_STICK = 0x3
  RIGHT_STICK = 0xC
}

//mouse axes bitmask
enum MOUSE_AXIS {
  NOT_AXIS = 0x0

  HORIZONTAL_AXIS = 0x1
  VERTICAL_AXIS = 0x2
  WHEEL_AXIS = 0x4

  MOUSE_MOVE = 0x3

  TOTAL = 3
}

enum CONTROL_HELP_PATTERN {
  NONE,
  SPECIAL_EVENT,
  MISSION,
  IMAGE,
  GAMEPAD,
  KEYBOARD_MOUSE,
  HOTAS4,
  RADAR,
  RWR,
}

enum AxisDirection {
  X,
  Y
}

enum ConflictGroups {
  PLANE_FIRE,
  HELICOPTER_FIRE,
  TANK_FIRE
}

enum optionControlType {
  LIST
  BIT_LIST
  SLIDER
  CHECKBOX
  EDITBOX
  HEADER
  BUTTON
}

enum AIR_MOUSE_USAGE {
  NOT_USED    = 0x0001
  AIM         = 0x0002
  JOYSTICK    = 0x0004
  RELATIVE    = 0x0008
  VIEW        = 0x0010
}

return {
  MAX_DEADZONE
  MAX_NONLINEARITY
  MAX_CAMERA_SMOOTH

  MIN_CAMERA_SPEED
  MAX_CAMERA_SPEED

  MAX_SHORTCUTS

  CONTROL_TYPE
  AXIS_MODIFIERS
  GAMEPAD_AXIS
  MOUSE_AXIS
  CONTROL_HELP_PATTERN
  AxisDirection
  ConflictGroups

  optionControlType
  AIR_MOUSE_USAGE
}