package main

import "core:fmt"
import "core:os"

import "./lexer"

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

	tokens, errors := lexer.lex(file_contents)
	defer {
		delete(tokens)
		delete(errors)
	}

	if len(errors) > 0 {
		exit_code = 65
		for error in errors {
			fmt.eprintfln(error)
		}
	}

	for token in tokens {
		lexer.print_token(token)
	}
}
