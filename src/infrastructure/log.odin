package infrastructure

import "core:fmt"
import "core:log"
import "core:os"

file_logger :: proc(path: string) -> log.Logger {
	log_file, open_err := os.open(
		path,
		os.O_WRONLY | os.O_TRUNC | os.O_CREATE, // flags open write only and create if not exists
		os.S_IRUSR | os.S_IWUSR, // right for the file if created
	)
	ok := (open_err == nil)
	if ok do return log.create_file_logger(log_file)
	else do fmt.panicf("Cannot open log file : %s", os.error_string(open_err))
}
