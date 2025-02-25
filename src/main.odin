package cli

import "core:fmt"
import "core:os"
import "core:c"
import "core:sys/posix"
import "core:log"
import "core:time"
import "core:encoding/ansi"
import "core:mem"
import "core:strings"
import "core:strconv"
import "base:builtin"
import "base:runtime"
import "core:io"

CANONICAL_FLAGS : posix.CLocal_Flags : {.ICANON, .ECHO}
STDIN :: posix.STDIN_FILENO
STDOUT :: posix.STDOUT_FILENO

// ANSI
CSI :: ansi.CSI   // ESC + "["


// FPS
// https://gafferongames.com/post/fix_your_timestep/
FPS :: 3
FRAME_DURATION_NS: time.Duration = auto_cast (1_000_000_000 / FPS)
CURRENT_FRAME := 0
TTY_WIDTH : u16 = 40
TTY_HEIGHT : u16 = 30
CAMERA_RATIO :: 16./9.
CAMERA_WIDTH := TTY_WIDTH
CAMERA_HEIGHT := TTY_HEIGHT
CAMERA_TTY_OFFSET_Y : u16 = 0
CAMERA_TTY_OFFSET_X : u16 = 0



main :: proc () {
  if !posix.isatty(STDIN) do panic("Not a terminal.")
  context.logger = log.create_console_logger()

  termios := get_termios()
  set_terminal_non_canonical_mode(&termios)
  defer set_terminal_canonical_mode(&termios)
  set_stdin_non_blocking()

  TTY_WIDTH, TTY_HEIGHT:= get_tty_width_and_height()
  display_home_screen()

  start: time.Tick
  for {
    key := get_key_pressed()
    if !handle_input(key) do break

    render()

    elapsed := time.tick_lap_time(&start)
    if elapsed < FRAME_DURATION_NS do time.accurate_sleep(FRAME_DURATION_NS - elapsed)
    CURRENT_FRAME += 1
  }

  exit_gracefully(&termios)
}


// SET/UNSET THE TERMINAL CANONICAL MODE

// Exemple of Noncanonical Mode in C
// https://www.gnu.org/software/libc/manual/html_node/Noncanon-Example.html
get_termios :: proc() -> posix.termios {
  termios : posix.termios
  // https://pubs.opengroup.org/onlinepubs/007904975/functions/tcgetattr.html
  res := cast(c.int) posix.tcgetattr(STDIN, &termios)
  if res != c.int(0) do panic("Failed to get termios.")
  return termios
}

set_terminal_canonical_mode :: proc(termios: ^posix.termios) {
  termios.c_lflag |= CANONICAL_FLAGS // set the flags
  res := cast(c.int) posix.tcsetattr(STDIN, posix.TC_Optional_Action.TCSANOW, termios)
  if res != c.int(0) do panic("Failed to set termios in canonical mode")
}

set_terminal_non_canonical_mode :: proc(termios: ^posix.termios) {
  termios.c_lflag &= ~CANONICAL_FLAGS // unset the flags 
  res := cast(c.int) posix.tcsetattr(STDIN, posix.TC_Optional_Action.TCSANOW, termios)
  if res != c.int(0) do panic("Failed to set termios in non canonical mode")
}

// https://stackoverflow.com/questions/5616092/non-blocking-call-for-reading-descriptor
set_stdin_non_blocking :: proc() {
  flags: i32 = posix.fcntl(STDIN, posix.FCNTL_Cmd.GETFL)
  posix.fcntl(STDIN, posix.FCNTL_Cmd.SETFL, flags | posix.O_NONBLOCK)
}

set_stdin_blocking :: proc() {
  flags: i32 = posix.fcntl(STDIN, posix.FCNTL_Cmd.GETFL)
  posix.fcntl(STDIN, posix.FCNTL_Cmd.SETFL, flags & ~i32(posix.O_NONBLOCK))
}

exit_gracefully :: proc(t: ^posix.termios) {
  set_terminal_canonical_mode(t)
  fmt.print(ansi.CSI + ansi.DECTCEM_SHOW)
  log.destroy_console_logger(context.logger)
  os.exit(0)
}


// INPUT / OUTPUT
TtyKeyPressed :: [16]u8

get_key_pressed :: proc() -> KeyboardKey {
  buf: TtyKeyPressed
  nb , err := os.read(os.stdin, buf[:])
  if err != nil {
    p_err, ok := os.is_platform_error(err)
    if ok && p_err == posix.EAGAIN do return KeyboardKey.KEY_NULL
    else do log.error(err, os.error_string(err))
  }
  if nb == -1 do return KeyboardKey.KEY_NULL // no input

  if nb == 1 {
    pressed: u8 = buf[0]
    switch pressed {
      // alphanumeric
      case 'A'..='Z', '0'..='9' : return KeyboardKey(pressed)
      case 'a'..='z': return KeyboardKey('A' + pressed - 'a')
      case '\e': return KeyboardKey.KEY_ESCAPE
      case ' ': return KeyboardKey.KEY_SPACE
    }    
  } else if nb == 4 {
    fmt.printfln("Pressed %d : %d %d %d %d", nb, buf[0], buf[1], buf[2], buf[3])
  } else {
    fmt.printf("%s", string(buf[1:]))
  }
  return KeyboardKey.KEY_NULL
}


handle_input :: proc(key: KeyboardKey) -> bool {
  if key == KeyboardKey.KEY_NULL do return true // no input
  key_str, _ := fmt.enum_value_to_string(key)
  fmt.printfln("Pressed %s (%d)", key_str, key)
  #partial switch key {
    case .KEY_Q, .KEY_ESCAPE : return false
    
  }
  return true
}

// Keyboard keys from Raylib
// https://github.com/raysan5/raylib/blob/99d2119dd6795205352cab41ca1ed7efd5d35c4e/src/raylib.h#L596
KeyboardKey :: enum {
  KEY_NULL            = 0,        // Key: NULL, used for no key pressed

  // Digits
  KEY_ZERO            = 48,       // Key: 0
  KEY_ONE             = 49,       // Key: 1
  KEY_TWO             = 50,       // Key: 2
  KEY_THREE           = 51,       // Key: 3
  KEY_FOUR            = 52,       // Key: 4
  KEY_FIVE            = 53,       // Key: 5
  KEY_SIX             = 54,       // Key: 6
  KEY_SEVEN           = 55,       // Key: 7
  KEY_EIGHT           = 56,       // Key: 8
  KEY_NINE            = 57,       // Key: 9
  
  // Letters
  KEY_A               = 65,       // Key: A | a
  KEY_B               = 66,       // Key: B | b
  KEY_C               = 67,       // Key: C | c
  KEY_D               = 68,       // Key: D | d
  KEY_E               = 69,       // Key: E | e
  KEY_F               = 70,       // Key: F | f
  KEY_G               = 71,       // Key: G | g
  KEY_H               = 72,       // Key: H | h
  KEY_I               = 73,       // Key: I | i
  KEY_J               = 74,       // Key: J | j
  KEY_K               = 75,       // Key: K | k
  KEY_L               = 76,       // Key: L | l
  KEY_M               = 77,       // Key: M | m
  KEY_N               = 78,       // Key: N | n
  KEY_O               = 79,       // Key: O | o
  KEY_P               = 80,       // Key: P | p
  KEY_Q               = 81,       // Key: Q | q
  KEY_R               = 82,       // Key: R | r
  KEY_S               = 83,       // Key: S | s
  KEY_T               = 84,       // Key: T | t
  KEY_U               = 85,       // Key: U | u
  KEY_V               = 86,       // Key: V | v
  KEY_W               = 87,       // Key: W | w
  KEY_X               = 88,       // Key: X | x
  KEY_Y               = 89,       // Key: Y | y
  KEY_Z               = 90,       // Key: Z | z

  // Function keys
  KEY_SPACE           = 32,       // Key: Space
  KEY_ESCAPE          = 256,      // Key: Esc
  KEY_ENTER           = 257,      // Key: Enter
  KEY_TAB             = 258,      // Key: Tab
  KEY_DELETE          = 261,      // Key: Del
  
  // Arrows
  KEY_RIGHT           = 262,      // Key: Cursor right
  KEY_LEFT            = 263,      // Key: Cursor left
  KEY_DOWN            = 264,      // Key: Cursor down
  KEY_UP              = 265,      // Key: Cursor up
}



display_home_screen :: proc() {
  fmt.print(ansi.CSI + ansi.DECTCEM_HIDE) // hide cursor
  fmt.println("esc or q for quit\n")
} 

//TODO build the entire string to print (including ANSI codes)
render :: proc() {
  if CURRENT_FRAME % FPS == 0 { // once per second
    TTY_WIDTH, TTY_HEIGHT = get_tty_width_and_height()
    CAMERA_WIDTH, CAMERA_HEIGHT = get_camera_width_and_height(TTY_WIDTH, TTY_HEIGHT, CAMERA_RATIO)
    CAMERA_TTY_OFFSET_X, CAMERA_TTY_OFFSET_Y = get_camera_offsets(TTY_WIDTH, TTY_HEIGHT, CAMERA_WIDTH, CAMERA_HEIGHT)
  }
  clear_tty()

  fmt.printf("\e[%d;%dHA", CAMERA_TTY_OFFSET_Y, CAMERA_TTY_OFFSET_X)
  fmt.printf("\e[%d;%dHB", CAMERA_TTY_OFFSET_Y, CAMERA_TTY_OFFSET_X + CAMERA_WIDTH)
  fmt.printf("\e[%d;%dHC", CAMERA_TTY_OFFSET_Y + CAMERA_HEIGHT, CAMERA_TTY_OFFSET_X + CAMERA_WIDTH)
  fmt.printf("\e[%d;%dHD", CAMERA_TTY_OFFSET_Y + CAMERA_HEIGHT, CAMERA_TTY_OFFSET_X)
}

get_tty_width_and_height :: proc() -> (u16, u16) {
  set_stdin_blocking()
  fmt.print(ansi.CSI + "9999;9999" + ansi.CUP)
  fmt.println(ansi.CSI + ansi.DSR)
  buffer : TtyKeyPressed
  nb, _ := os.read(STDIN, buffer[:])
  set_stdin_non_blocking()

  if nb < 3 {
    log.error("Failed to get ANSI DSR response")
    return TTY_WIDTH, TTY_HEIGHT
  }
  height_and_width_str := strings.split(string(buffer[2:nb-1]), ";")
  if len(height_and_width_str) != 2 do return TTY_WIDTH, TTY_HEIGHT

  height, w_ok := strconv.parse_int(height_and_width_str[0])
  width, h_ok := strconv.parse_int(height_and_width_str[1])
  
  if w_ok && h_ok do return u16(width), u16(height)
  else do return TTY_WIDTH, TTY_HEIGHT
}

clear_tty :: proc() {
  fmt.print(ansi.CSI + ansi.FAINT + ansi.ED)
}

get_camera_width_and_height :: proc(max_width: u16, max_height: u16, ratio: f32) -> (w: u16, h: u16) {
  scaled_max_width := max_width/2

  if ratio == 1. {
    side := min(scaled_max_width, max_height)
    w, h = side, side
  }
  tty_ratio := f32(scaled_max_width) / f32(max_height)
  if ratio > 1. { // camera width > camera height
    ratio_limit_width := min(u16(f32(max_height) * ratio), scaled_max_width)
    w, h = ratio_limit_width, u16(f32(ratio_limit_width) / ratio)
  }
  if ratio < 1. { // h > w
    ratio_limit_height := min( u16(f32(scaled_max_width) / ratio), max_height)
    w, h = u16(f32(ratio_limit_height) * ratio), ratio_limit_height
  }

  return w*2, h
}

get_camera_offsets :: proc(max_w: u16, max_h: u16, c_width: u16, c_height: u16) -> (x_of: u16, y_of: u16) {
  x_of = (max_w - c_width) / 2
  y_of = (max_h - c_height) / 2
  return max(0, x_of), max(0, y_of) // ensure not negative offset
}