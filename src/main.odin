#+feature dynamic-literals

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
import "base:runtime"
import "domain"


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
  tty: Tty,
  screen: CliScreen,
  current_frame: u128,
  fps: u128,
  frame_duration: time.Duration, 
  clear_refresh_rate: u128,
}

Tty :: struct {
  termios: posix.termios, 
  resolution: Resolution,
  was_resized: bool,
  log: string,
}

CliScreen :: struct {
  resolution: Resolution,
  ratio: f32,
  coordinate: Coordinate, 
  cells: Cells,
  scale_refresh_rate: u128 "in seconds"
}

Resolution :: struct {width, height: u16}
Coordinate :: struct {x, y: u16}
Cells :: [dynamic][dynamic]Cell
Cell :: struct {
  r: rune,
  color: u8, // 256 ansi colors
}


Configuration :: struct {
  FPS: u128                     "Number of frames per seconds, u128 because calculations with big numbers",
  SCREEN_RATIO: f32             "Visual ratio of width/heigth",
  SCALE_REFRESH_RATE: u128      "Number of seconds between two tty resize checks",
  CLEAR_REFRESH_RATE: u128      "Number of seconds between two (ansi) clear of tty (in case of display bug)",
  LOGGER: runtime.Logger,
  TTY_FONT_RATIO:f32            "TTY ratio between cols and lines, lines are usually 2 times taller than a column is large", 
  GAME_NAME: string,
}

DEFAULT_CONFIGURATION : Configuration = {
  FPS = 10,
  SCREEN_RATIO = 16./9.,
  SCALE_REFRESH_RATE = 1,
  CLEAR_REFRESH_RATE = 30,
  LOGGER = my_logger(),
  TTY_FONT_RATIO = 2.,
  GAME_NAME = "REMAP",
}

my_logger :: proc() -> log.Logger {
  logger := log.create_console_logger()

  logger.procedure = proc(d: rawptr, l: log.Level, text: string, o: log.Options, c := #caller_location) {
    delete(GLOBAL_STATE.cli.tty.log)

    data := cast(^log.File_Console_Logger_Data)d

    backing: [255]byte
    buf := strings.builder_from_bytes(backing[:])
    log.do_level_header(o, &buf, l)
    when time.IS_SUPPORTED do log.do_time_header(o, &buf, time.now())
    // log.do_location_header(o, &buf, c)
    if data.ident != "" do fmt.sbprintf(&buf, "[%s] ", data.ident)

    GLOBAL_STATE.cli.tty.log = fmt.aprintf("%s%s\n", strings.to_string(buf), text)
  }

  return logger
}

main :: proc () {
  conf := DEFAULT_CONFIGURATION
  context.logger = conf.LOGGER

  fmt.printf(SET_TTY_NAME_FMT, conf.GAME_NAME)

  GLOBAL_STATE = GlobalState {
    cli = init_cli(conf),
    game = init_game(),
  }
  cli := &GLOBAL_STATE.cli
  using cli

  // TODO catch SIGTERM
  defer exit_gracefully(&tty.termios)

  scale_screen_to_tty(cli)
  display_home_screen()

  start: time.Tick
  for {
    key := get_key_pressed()
    if !handle_input(key) do break

    if current_frame % (fps * screen.scale_refresh_rate) == 0 do scale_screen_to_tty(cli)
    if current_frame % (fps * clear_refresh_rate) == 0 do clear_tty()
    
    render(cli)

    elapsed := time.tick_lap_time(&start)
    if elapsed < frame_duration do time.accurate_sleep(frame_duration - elapsed)
    current_frame += 1
  }
}

init_cli :: proc(using conf: Configuration) -> Cli {
  return {
    tty = init_tty(),
    fps = FPS,
    frame_duration = auto_cast (1_000_000_000 / FPS),
    screen = {
      ratio = SCREEN_RATIO,
      scale_refresh_rate = SCALE_REFRESH_RATE,
    },
    clear_refresh_rate = CLEAR_REFRESH_RATE,
  }
}


init_game :: proc() -> domain.Game {
  spawn := domain.Piece{
    borders={
      north=domain.Biome.Plain,
      east=domain.Biome.Plain,
      south=domain.Biome.Plain,
      west=domain.Biome.Plain,
    }
  }

  return {
    m = {
      pieces = {
        {0,0} = spawn
      }
    }
  }
}


// SET/UNSET THE TERMINAL CANONICAL MODE

CANONICAL_FLAGS : posix.CLocal_Flags : {.ICANON, .ECHO}

init_tty :: proc() -> Tty {
  termios := get_termios()
  set_terminal_non_canonical_mode(&termios)
  set_stdin_non_blocking()

  return {
    termios = termios,
  }
}

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
  fmt.print("\e[0m") // reset all modes (styles and colors)
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
  log.infof("Pressed %s (%d)", key_str, key)
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

// AINSI CODES
// https://gist.github.com/ConnerWill/d4b6c776b509add763e17f9f113fd25b

// TODO idée : natural language api for ansi string creation (ansi.clear.tty.until.end() => "\e[1J" )

ESC :: ansi.CSI                 // ESC[   escape
CUP :: ansi.CUP                 // H      cursor position
LEFT :: ansi.CUB                // D
RIGHT :: ansi.CUF               // C
FAINT :: ansi.FAINT             // 2      erase
MODE :: ansi.SGR                // m      graphic mode (style & color)
ERASE_LINE :: ansi.EL           // K      erase in line
ERASE_DISPLAY :: ansi.ED        // J      erase in dislay
FG_COLOR :: ansi.FG_COLOR       // 38     foreground color
BLINK_SLOW :: ansi.BLINK_SLOW   // 5      blinking < 150 per minute
DSR :: ansi.DSR                 // 6n     request cursor position
HIDE :: ansi.HIDE               // 8
RESET :: ansi.RESET             // 0


SET_CURSOR_FMT :: ESC + "%d;%d" + CUP                // \e[{line};{column}H
MOVE_LEFT :: ESC + "1" + LEFT                        // \e[1D
MOVE_RIGHT :: ESC + "1" + RIGHT                      // \e[1C
GET_CURSOR_POSITION :: ESC + DSR                     // \e[6n
CLEAR_LINE :: ESC + "2" + ERASE_LINE                 // \e[2K  =>  2 for the entire line
CLEAR_LINE_UNTIL_END :: ESC + "0" + ERASE_LINE       // \e[0K
CLEAR_LINE_UNTIL_CURSOR :: ESC + "1" + ERASE_LINE    // \e[1K
CLEAR_TTY :: ESC + "2" + ERASE_DISPLAY               // \e[2J  =>  2 for entire screen
CLEAR_TTY_UNTIL_END :: ESC + "0" + ERASE_DISPLAY     // \e[0J
CLEAR_TTY_UNTIL_CURSOR :: ESC + "1" + ERASE_DISPLAY  // \e[1J
FOREGROUND_COLOR_FMT :: ESC + FG_COLOR + ";" + BLINK_SLOW + ";%d" + MODE  // \e[38;5;{color}m
START_HIDE :: ESC + "8" + MODE                       // \e[8m
END_HIDE :: ESC + FAINT + HIDE + MODE                // \e[28m
HIDE_CURSOR :: ESC + ansi.DECTCEM_HIDE               // \e?25l
RESET_MODES :: ESC + RESET + MODE                    // \e0m
SET_TTY_NAME_FMT :: ansi.OSC + RESET + ";%s" + ansi.BEL     // "\e]2;REMAP\a"


display_home_screen :: proc() {
  fmt.print(HIDE_CURSOR) // hide cursor
  fmt.println("esc or q for quit\n")
  // TODO fmt.print("\e]0;this is the window title BEL")
}

scale_screen_to_tty :: proc(using cli: ^Cli) {
  tty_resolution := get_tty_width_and_height().? or_else tty.resolution

  tty_was_resized := (tty_resolution != tty.resolution)
  if tty_was_resized {
    tty.resolution = tty_resolution
    update_cli_screen(&screen, tty_resolution)
    log.debugf("TTY resized to %dx%d", tty_resolution.width, tty_resolution.height)
  }
  tty.was_resized = tty_was_resized
}

render :: proc(using cli: ^Cli) {

  for &line in screen.cells {
    for &cell in line {
      cell = {r = '.', color = 238}
    }
  }

  if tty.was_resized do clear_tty()

  go_to :: SET_CURSOR_FMT
  pos := screen.coordinate

  // clear above screen
  fmt.printf(go_to + CLEAR_TTY_UNTIL_CURSOR, pos.y, pos.x)
  
  // display screen
  for line, y in screen.cells {
    fmt.printf(go_to, pos.y + u16(y), pos.x)
    if pos.x > 0 do fmt.printf(CLEAR_LINE_UNTIL_CURSOR)
    
    for cell, x in line {
      set_color := (x < 1 || cell.color != line[x-1].color)
      color := fmt.aprintf(FOREGROUND_COLOR_FMT, cell.color) if set_color else ""
      fmt.printf("%s%c", color, cell.r)
    }
    if pos.x > 0 do fmt.printf(CLEAR_LINE_UNTIL_END)
  }

  // clear bellow screen
  bellow_screen := pos.y + screen.resolution.height
  fmt.printf(go_to + CLEAR_TTY_UNTIL_END, bellow_screen, 0)

  // log
  log := tty.log[0:min(cast(u16)len(tty.log), tty.resolution.width)]
  if log != "" && pos.y >= 1 {
    fmt.printf(go_to + "%s", bellow_screen+1, pos.x, log)
  }

  // TODO set cursor bottom to follow
}

get_tty_width_and_height :: proc() -> Maybe(Resolution) {
  set_stdin_blocking()
  fmt.printf(SET_CURSOR_FMT, 9999, 9999)
  fmt.println(GET_CURSOR_POSITION)
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

update_cli_screen :: proc(using screen: ^CliScreen, tty_res: Resolution) {
  resolution = get_screen_width_and_height(tty_res, ratio)
  coordinate = get_screen_coordinate(tty_res, resolution)

  resize(&cells, resolution.height)
  for &line in cells {
    resize(&line, resolution.width)
  }
}

clear_tty :: proc() {
  fmt.print(RESET_MODES + CLEAR_TTY)
}

get_screen_width_and_height :: proc(using max: Resolution, screen_ratio: f32) -> Resolution {
  scaled_max_width := width/2 // TTY_COLUMNS_LINES_RATIO
  w, h : u16
  if screen_ratio == 1. {
    side := min(scaled_max_width, height)
    w, h = side, side
  }
  tty_ratio := f32(scaled_max_width) / f32(height)
  if screen_ratio > 1. { // camera width > camera height
    ratio_limit_width := min(u16(f32(height) * screen_ratio), scaled_max_width)
    w, h = ratio_limit_width, u16(f32(ratio_limit_width) / screen_ratio)
  }
  if screen_ratio < 1. { // h > w
    ratio_limit_height := min( u16(f32(scaled_max_width) / screen_ratio), height)
    w, h = u16(f32(ratio_limit_height) * screen_ratio), ratio_limit_height
  }

  return {w*2, h}
}

get_screen_coordinate :: proc(max: Resolution, screen: Resolution) -> Coordinate {
  x := (max.width - screen.width) / 2 if  max.width > screen.width else 0
  y := (max.height - screen.height) / 2 if max.height > screen.height else 0
  return {x, y}
}


CellToRune :: [domain.Cell]rune {
  .Nil =    ' ',
  .Ground = '.',
  .Tree =   '^',
  .Rock =   '@',
} 