package main

import "core:fmt"
import "core:os"
import "core:c"
import "core:sys/posix"


// Exemple of Noncanonical Mode in C
// https://www.gnu.org/software/libc/manual/html_node/Noncanon-Example.html

CANONICAL_FLAGS : posix.CLocal_Flags : {.ICANON, .ECHO}
STDIN :: posix.STDIN_FILENO

TtyKeyPressed :: [3]u8

K :: enum {
}

main :: proc () {
  if !posix.isatty(STDIN) do panic("Not a terminal.")

  termios := get_termios()
  set_terminal_non_canonical_mode(&termios)
  defer set_terminal_canonical_mode(&termios)

  display_home_screen()
  for {
    buf, nb := get_key_pressed()
    if !handle_input(buf, nb) do break
    display()
  }
}


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


handle_input :: proc(buf: [3]u8, nb: int) -> bool {
  pressed := buf[0]
  if(nb == 1) {
    fmt.printfln("Readed : %c", pressed);
    if (pressed == '\e' || pressed == 'q') do return false
  } else {
    fmt.printfln("Pressed complex key (combination of %d keys)", nb);
  }
  return true
}

display_home_screen :: proc() {
  fmt.println("esc or q for quit\n")
} 

get_key_pressed :: proc() -> (buf: TtyKeyPressed, nb: int) {
  nb , _ = os.read(os.stdin, buf[:])
  return buf, nb
}

display :: proc() {
  fmt.println("display")
}