package main

import "core:fmt"
import "core:os"
import "core:c"
import "core:sys/posix"


// Exemple of Noncanonical Mode in C
// https://www.gnu.org/software/libc/manual/html_node/Noncanon-Example.html


old_termios : posix.termios
STDIN :: posix.STDIN_FILENO

exit_gracefully :: proc(signal: c.int) {
  _ = posix.tcsetattr(STDIN, posix.TC_Optional_Action.TCSANOW, &old_termios)
}



main :: proc () {
  if !posix.isatty(STDIN) {
      panic("Not a terminal.")
  }

  ko := posix.tcgetattr(STDIN, &old_termios)
  if ko != 0 {
    panic("Failed to get terminal parameters.");
  }

  new_termios := old_termios // copy struct
  canonical_mode_flags : posix.CLocal_Flags = {.ICANON, .ECHO}
  new_termios.c_lflag &= ~canonical_mode_flags // unset the flags
  _ = posix.tcsetattr(STDIN, posix.TC_Optional_Action.TCSANOW, &new_termios)
 
  defer _ = posix.tcsetattr(STDIN, posix.TC_Optional_Action.TCSANOW, &old_termios)

  fmt.println("q for quit\n")
  for {
    buf: [1]u8
    os.read(os.stdin, buf[:])

    if(buf[0] == 'q') {
      break
    }

    fmt.printfln("Pressed %c\n", buf[0])
  }
}

