package cli

import "core:fmt"
import "core:os"
import "core:c"
import "core:sys/posix"
import "core:log"

// Exemple of Noncanonical Mode in C
// https://www.gnu.org/software/libc/manual/html_node/Noncanon-Example.html

CANONICAL_FLAGS : posix.CLocal_Flags : {.ICANON, .ECHO}
STDIN :: posix.STDIN_FILENO

main :: proc () {
  if !posix.isatty(STDIN) do panic("Not a terminal.")

  termios := get_termios()
  set_terminal_non_canonical_mode(&termios)
  defer set_terminal_canonical_mode(&termios)

  display_home_screen()
  for {
    key := get_key_pressed()
    if !handle_input(key) do break
    display()
  }
}


// SET/UNSET THE TERMINAL IN CANONICAL MODE
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

exit_gracefully :: proc(t: ^posix.termios) {
  set_terminal_canonical_mode(t)
}


// INPUT / OUTPUT
TtyKeyPressed :: [3]u8

get_key_pressed :: proc() -> KeyboardKey {
  buf: TtyKeyPressed
  nb , err := os.read(os.stdin, buf[:])
  if err != nil do log.error(err, os.error_string(err))
  fmt.printfln("error: %t", err == nil)
  if nb == 1 {
    pressed: u8 = buf[0]
    switch pressed {
      // alphanumeric
      case 'A'..='Z', '0'..='9' : return KeyboardKey(pressed)
      case 'a'..='z': return KeyboardKey('A' + pressed - 'a')
      case '\e': return KeyboardKey.KEY_ESCAPE
    }    
  }
  return KeyboardKey.KEY_NULL
}


handle_input :: proc(key: KeyboardKey) -> bool {
  fmt.printfln("Pressed %c (%d)", u8(key), key)
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
  fmt.println("esc or q for quit\n")
} 


display :: proc() {
  fmt.println("display")
}