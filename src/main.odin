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
import "core:io"
import "domain"


CANONICAL_FLAGS : posix.CLocal_Flags : {.ICANON, .ECHO}
STDIN :: posix.STDIN_FILENO
STDOUT :: posix.STDOUT_FILENO

// TODO FPS
// https://gafferongames.com/post/fix_your_timestep/


GLOBAL_STATE : GlobalState

GlobalState :: struct {
  game: domain.Game,
  cli: Cli,
}

Cli :: struct {
  tty: struct {
    termios: posix.termios, 
    resolution: Resolution
  },
  screen: CliScreen,
  current_frame: u128,
  fps: u128,
  frame_duration : time.Duration, 
}

CliScreen :: struct {
  resolution: Resolution,
  ratio: f32,
  offset: ScreenOffset,
}

Resolution :: struct {width, height: u16}

ScreenOffset :: struct {horizontal, vertical : u16}

main :: proc () {
  context.logger = log.create_console_logger()

  cli := &GLOBAL_STATE.cli

  termios := get_termios()
  set_terminal_non_canonical_mode(&termios)
  defer set_terminal_canonical_mode(&termios)
  set_stdin_non_blocking()
  cli.tty.termios = termios

  cli.fps = 16
  cli.current_frame = 0
  cli.frame_duration = auto_cast (1_000_000_000 / int(GLOBAL_STATE.cli.fps))
  cli.screen.ratio = 16./9.

  update_cli_screen(&GLOBAL_STATE.cli.screen, get_tty_width_and_height().? or_else cli.tty.resolution)

  display_home_screen()

  GLOBAL_STATE.game.m.pieces[{0,0}] = {
    borders={
      north=domain.BorderKind.Plain,
      east=domain.BorderKind.Plain,
      south=domain.BorderKind.Plain,
      west=domain.BorderKind.Plain,
    }
  }

  start: time.Tick
  for {
    key := get_key_pressed()
    if !handle_input(key) do break

    scale_screen_to_tty(cli)
    render(cli)

    elapsed := time.tick_lap_time(&start)
    if elapsed < cli.frame_duration do time.accurate_sleep(cli.frame_duration - elapsed)
    cli.current_frame += 1
  }

  exit_gracefully(&cli.tty.termios)
}


// SET/UNSET THE TERMINAL CANONICAL MODE

// Exemple of Noncanonical Mode in C
// https://www.gnu.org/software/libc/manual/html_node/Noncanon-Example.html
get_termios :: proc() -> posix.termios {
  if !posix.isatty(STDIN) do panic("Not a terminal.")

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


// INPUT
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

// OUTPUT

display_home_screen :: proc() {
  fmt.print(ansi.CSI + ansi.DECTCEM_HIDE) // hide cursor
  fmt.println("esc or q for quit\n")
}

scale_screen_to_tty :: proc(cli: ^Cli) {
  // once per second
  if cli.current_frame % cli.fps != 0 do return

  tty_resolution := get_tty_width_and_height().? or_else cli.tty.resolution
  update_cli_screen(&cli.screen, tty_resolution)
}

//TODO build the entire string to print (including ANSI codes)
render :: proc(cli: ^Cli) {
  clear_tty()

  of := cli.screen.offset
  s := cli.screen
  fmt.printf("\e[%d;%dHA", of.vertical, of.horizontal)
  fmt.printf("\e[%d;%dHB", of.vertical, of.horizontal + s.resolution.width)
  fmt.printf("\e[%d;%dHC", of.vertical + s.resolution.height, of.horizontal + s.resolution.width)
  fmt.printf("\e[%d;%dHD", of.vertical + s.resolution.height, of.horizontal)
}

get_tty_width_and_height :: proc() -> Maybe(Resolution) {
  set_stdin_blocking()
  fmt.print(ansi.CSI + "9999;9999" + ansi.CUP)
  fmt.println(ansi.CSI + ansi.DSR)
  buffer : TtyKeyPressed
  nb, _ := os.read(STDIN, buffer[:])
  set_stdin_non_blocking()

  if nb < 3 { // min is '#;#'
    log.error("Failed to get ANSI DSR response")
    return nil
  }
  height_and_width_str := strings.split(string(buffer[2:nb-1]), ";")
  if len(height_and_width_str) != 2 do return nil

  height, w_ok := strconv.parse_uint(height_and_width_str[0])
  width, h_ok := strconv.parse_uint(height_and_width_str[1])
  
  if w_ok && h_ok do return Resolution{u16(width), u16(height)}
  else do return nil
}

update_cli_screen :: proc(s: ^CliScreen, tty_res: Resolution) {
  r := get_screen_width_and_height(tty_res, s.ratio)
  s.resolution.width, s.resolution.height = r.width, r.height
  s.offset = get_screen_offsets(tty_res, s.resolution)
}

clear_tty :: proc() {
  fmt.print(ansi.CSI + ansi.FAINT + ansi.ED)
}

get_screen_width_and_height :: proc(max: Resolution, ratio: f32) -> Resolution {
  scaled_max_width := max.width/2
  w, h : u16
  if ratio == 1. {
    side := min(scaled_max_width, max.height)
    w, h = side, side
  }
  tty_ratio := f32(scaled_max_width) / f32(max.height)
  if ratio > 1. { // camera width > camera height
    ratio_limit_width := min(u16(f32(max.height) * ratio), scaled_max_width)
    w, h = ratio_limit_width, u16(f32(ratio_limit_width) / ratio)
  }
  if ratio < 1. { // h > w
    ratio_limit_height := min( u16(f32(scaled_max_width) / ratio), max.height)
    w, h = u16(f32(ratio_limit_height) * ratio), ratio_limit_height
  }

  return {w*2, h}
}

// TODO take resolutions
get_screen_offsets :: proc(max: Resolution, screen: Resolution) -> ScreenOffset {
  horizontal := (max.width - screen.width) / 2 if  max.width > screen.width else 0
  vertical := (max.height - screen.height) / 2 if max.height > screen.height else 0
  return {horizontal, vertical}
}