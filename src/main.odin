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

	reserved_keywords := make(map[string]bool, 16)
	defer delete(reserved_keywords)

	reserved_keywords["and"] = true
	reserved_keywords["class"] = true
	reserved_keywords["else"] = true
	reserved_keywords["false"] = true
	reserved_keywords["for"] = true
	reserved_keywords["fun"] = true
	reserved_keywords["if"] = true
	reserved_keywords["nil"] = true
	reserved_keywords["or"] = true
	reserved_keywords["print"] = true
	reserved_keywords["return"] = true
	reserved_keywords["super"] = true
	reserved_keywords["this"] = true
	reserved_keywords["true"] = true
	reserved_keywords["var"] = true
	reserved_keywords["while"] = true

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
				end_index := parse_number(line, i)

				numeric_string := string(line[i:end_index + 1])
				formatted := format_floating_point(numeric_string)

				fmt.printfln("NUMBER %s %s", numeric_string, formatted)

				i = end_index
			case ' ':
				continue
			case 'a' ..= 'z', 'A' ..= 'Z', '_':
				// forward until we find a non alpha, underscore char
				j := i

				for ; j < len(line); j += 1 {
					if !is_alpha_numeric(line[j]) do break
				}

				identifier := string(line[i:j])

				is_reserved_keyword := reserved_keywords[identifier] or_else false
				if is_reserved_keyword {
					fmt.printfln("%s %s null", strings.to_upper(identifier), identifier)
				} else {
					fmt.printfln("IDENTIFIER %s null", identifier)
				}

				i = j - 1
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

// we only allow small letters, capital letters, and underscore
is_alpha_numeric :: proc(char: byte) -> bool {
	is_numeric := char >= '0' && char <= '9'
	is_small_letter := char >= 'a' && char <= 'z'
	is_upper_case_letter := char >= 'A' && char <= 'Z'
	is_underscore := char == '_'

	return is_numeric || is_small_letter || is_upper_case_letter || is_underscore
}

format_floating_point :: proc(numeric_string: string) -> string {
	parts, error := strings.split(numeric_string, ".")
	if error != nil {
		panic("should never happen ")
	}

	defer delete(parts)

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

ParseNumberState :: enum {
	NUMBER_BEFORE_DOT,
	DOT,
	NUMBER_AFTER_DOT,
}

parse_number :: proc(line: []byte, current_index: int) -> (end_index: int) {
	assert(is_numeric(line[current_index]), "first character is not numeric")

	state := ParseNumberState.NUMBER_BEFORE_DOT
	j := current_index

	main_loop: for ; j < len(line); j += 1 {
		char := line[j]

		is_numeric := is_numeric(char)
		is_dot := char == '.'
		is_invalid := !is_numeric && !is_dot

		if is_invalid do break main_loop

		switch state {
		case .NUMBER_BEFORE_DOT:
			if is_dot do state = .DOT
		case .DOT:
			if is_numeric do state = .NUMBER_AFTER_DOT
			if is_dot {
				// we encountered two dots in a row. we must de-consume the dot we just processed so it can be picked up again by the top level state machine
				j -= 1
				break main_loop
			}
		case .NUMBER_AFTER_DOT:
			if !is_numeric do break main_loop
		}
	}

	// whatever index we stopped at, didn't meet the number parsing criteria. therefore the number ended one index back
	return j - 1
}

is_numeric :: proc(char: byte) -> bool {
	return char >= '0' && char <= '9'
}
