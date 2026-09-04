package main

import "core:bytes"
import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	exit_code := 0

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

	file_contents, err := os.read_entire_file(filename, context.allocator)
	if err != nil {
		fmt.eprintf("Failed to read file: %s\n", filename)
		os.exit(1)
	}

	defer {
		delete(file_contents, context.allocator)
		os.exit(exit_code)
	}

	// You can use print statements as follows for debugging, they'll be visible when running tests.
	fmt.eprintln("Logs from your program will appear here!")

	lines := bytes.split(file_contents, transmute([]byte)string("\n"))
	defer delete(lines)

	for line, index in lines {
		line_number := index + 1
		for char in line {
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
			case '$', '#':
				exit_code = 65
				fmt.eprintfln("[line %d] Error: Unexpected character: %c", line_number, char)
			}
		}
	}

	fmt.println("EOF  null")
}
