package main

import "./interpreter"
import "./parser"
import "core:fmt"
import "core:os"
import "core:slice"

import "./lexer"

main :: proc() {
	if len(os.args) < 3 {
		fmt.eprintln("Usage: ./your_program.sh <command> <filename>")
		os.exit(1)
	}

	command := os.args[1]
	filename := os.args[2]

	allowed_commands := []string{"tokenize", "parse", "evaluate", "run"}
	if _, found := slice.linear_search(allowed_commands, command); !found {
		fmt.eprintf("Unknown command: %s\n", command)
		os.exit(1)
	}

	file_contents, err := os.read_entire_file(filename, context.allocator)
	if err != nil {
		fmt.eprintf("Failed to read file: %s\n", filename)
		os.exit(1)
	}

	exit_code := 0

	defer {
		delete(file_contents, context.allocator)
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
			fmt.eprintln(error)
		}
	}

	// just print the tokens and exit
	if command == "tokenize" {
		for token in tokens {
			lexer.print_token(token)
		}

		return
	}


	stmt := parser.parse(tokens[:])

	// print AST and exit
	if command == "parse" {
		parser.print_ast(stmt.expr)
		return
	}

	if command == "evaluate" {
		result, runtime_error := interpreter.interpret_expr(stmt.expr)
		if runtime_error != nil {
			exit_code = 70
			error := runtime_error.(interpreter.Runtime_Error)
			fmt.eprintfln("%s\n[line %d]", error.error, error.line_number)
			return
		}

		interpreter.print_string_value(result)
		return
	}

	if command == "run" {
		fmt.println(stmt)
		result, runtime_error := interpreter.interpret(stmt)
		fmt.println("error is", runtime_error)

		if runtime_error != nil {
			exit_code = 70
			error := runtime_error.(interpreter.Runtime_Error)
			fmt.eprintfln("%s\n[line %d]", error.error, error.line_number)
			return
		}

		fmt.println(result)

		return
	}
}
