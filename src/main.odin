package main

import "./interpreter"
import "./parser"
import "core:fmt"
import "core:os"

import "./lexer"

main :: proc() {
	if len(os.args) < 3 {
		fmt.eprintln("Usage: ./your_program.sh <command> <filename>")
		os.exit(1)
	}

	command := os.args[1]
	filename := os.args[2]

	if command == "tokenize" {
		handle_tokenize(filename)
		return
	}

	if command == "parse" {
		handle_parse(filename)
		return
	}

	if command == "evaluate" {
		handle_interpret(filename)
		return
	}

	fmt.eprintf("Unknown command: %s\n", command)
	os.exit(1)
}

handle_tokenize :: proc(filename: string) {
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

	for token in tokens {
		lexer.print_token(token)
	}
}

handle_parse :: proc(filename: string) {
	file_contents, err := os.read_entire_file(filename, context.allocator)
	if err != nil {
		fmt.eprintf("Failed to read file: %s\n", filename)
		os.exit(1)
	}

	tokens, errors := lexer.lex(file_contents)
	defer {
		delete(tokens)
		delete(errors)
	}

	if len(errors) > 0 {
		for error in errors {
			fmt.eprintln(error)
		}

		os.exit(65)
	}

	expr := parser.parse(tokens[:])
	parser.print_ast(expr)
}

handle_interpret :: proc(filename: string) {
	file_contents, err := os.read_entire_file(filename, context.allocator)
	if err != nil {
		fmt.eprintf("Failed to read file: %s\n", filename)
		os.exit(1)
	}

	tokens, errors := lexer.lex(file_contents)
	defer {
		delete(tokens)
		delete(errors)
	}

	if len(errors) > 0 {
		for error in errors {
			fmt.eprintln(error)
		}

		os.exit(65)
	}

	expr := parser.parse(tokens[:])
	result, success := interpreter.interpret(expr)
	if !success {
		fmt.eprintln("interpret error")
		os.exit(65)
	}

	#partial switch v in result {
	case f64:
		int_version := int(v)
		is_whole_number := f64(int_version) == v
		fmt.println("is whole number", is_whole_number)

		if (is_whole_number) {
			fmt.println(int_version)
		} else {
			fmt.println(v)
		}
	case:
		fmt.println("default case")
		fmt.println(result)
	}
}
