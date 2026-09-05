package main

import "core:bytes"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	if len(os.args) < 3 {
		fmt.eprintln("Usage: ./your_program.sh tokenize <filename>")
		os.exit(1)
	}

	command := os.args[1]
	filename := os.args[2]

	if command != "tokenize" {
		fmt.eprintf("Unknown command: %s\n", command)
		os.exit(1)
	}

	exit_code := 0

	file_contents, err := os.read_entire_file(filename, context.allocator)
	if err != nil {
		fmt.eprintf("Failed to read file: %s\n", filename)
		os.exit(1)
	}

	defer {
		delete(file_contents, context.allocator)
		// fmt.println("exiting with code", exit_code)
		os.exit(exit_code)
	}

	// You can use print statements as follows for debugging, they'll be visible when running tests.
	fmt.eprintln("Logs from your program will appear here!")

	lines := bytes.split(file_contents, transmute([]byte)string("\n"))

	for line, index in lines {
		line_number := index + 1

		single_line_loop: for i := 0; i < len(line); i += 1 {
			char := line[i]

			switch char {
			case '(':
				fmt.println("LEFT_PAREN ( null")
			case ')':
				fmt.println("RIGHT_PAREN ) null")
			case '}':
				fmt.println("RIGHT_BRACE } null")
			case '{':
				fmt.println("LEFT_BRACE { null")
			case ',':
				fmt.println("COMMA , null")
			case '.':
				fmt.println("DOT . null")
			case '-':
				fmt.println("MINUS - null")
			case '+':
				fmt.println("PLUS + null")
			case ';':
				fmt.println("SEMICOLON ; null")
			case '*':
				fmt.println("STAR * null")
			case '=':
				if i + 1 < len(line) && line[i + 1] == '=' {
					i += 1
					fmt.println("EQUAL_EQUAL == null")
					continue
				}

				fmt.println("EQUAL = null")
			case '!':
				if i + 1 < len(line) && line[i + 1] == '=' {
					i += 1
					fmt.println("BANG_EQUAL != null")
					continue
				}

				fmt.println("BANG ! null")
			case '<':
				if i + 1 < len(line) && line[i + 1] == '=' {
					i += 1
					fmt.println("LESS_EQUAL <= null")
					continue
				}

				fmt.println("LESS < null")
			case '>':
				if i + 1 < len(line) && line[i + 1] == '=' {
					i += 1
					fmt.println("GREATER_EQUAL >= null")
					continue
				}

				fmt.println("GREATER > null")
			case '/':
				if i + 1 < len(line) && line[i + 1] == '/' do break single_line_loop
				fmt.println("SLASH / null")
			case '\t', '\n':
				continue
			case '"':
				j := i + 1
				found := false

				for ; j < len(line); j += 1 {
					if line[j] == '"' {
						found = true
						break
					}
				}

				// skip to next line processing
				if !found {
					exit_code = 65
					fmt.eprintfln("[line %d] Error: Unterminated string.", line_number)
					break single_line_loop
				}

				string_value := string(line[i + 1:j])
				fmt.printfln("STRING \"%s\" %s", string_value, string_value)

				i = j
			case '0' ..= '9':
				j := i
				new_i := i

				found_dot := false
				digit_after_dot := false

				for ; j < len(line); j += 1 {
					current := line[j]

					if current >= '0' && current <= '9' {
						if found_dot {
							digit_after_dot = true
						}

						new_i = j
						continue
					}

					if current == '.' {
						if found_dot && digit_after_dot {
							new_i = j - 1
							// print after breaking
							break
						}

						if found_dot {
							new_i = j - 2
							// print after breaking
							break
						}

						found_dot = true
						continue
					}

					new_i = j
					break
				}

				numeric_string := string(line[i:j])
				formatted := format_floating_point(numeric_string)

				fmt.printfln("NUMBER %s %s", numeric_string, formatted)

				i = new_i
			case ' ':
				continue
			case '$', '#', '@', '%':
				exit_code = 65
				fmt.eprintfln("[line %d] Error: Unexpected character: %c", line_number, char)
			case:
				// unsupported
				exit_code = 65
			}
		}
	}

	fmt.println("EOF  null")
}

format_floating_point :: proc(numeric_string: string) -> string {
	parts, error := strings.split(numeric_string, ".")
	if error != nil {
		panic("should never happen ")
	}

	if len(parts) > 2 {
		panic("should never receive this, more than two parts to a floating point number")
	}

	if len(parts) == 1 do return fmt.tprintf("%s.0", parts[0])
	decimal_point, ok := strconv.parse_int(parts[1])

	if !ok {
		panic("parsing integer should not fail")
	}

	decimal_string :=
		decimal_point == 0 ? "0" : strings.trim_right(fmt.tprintf("%d", decimal_point), "0")

	return fmt.tprintf("%s.%s", parts[0], decimal_string)
}
