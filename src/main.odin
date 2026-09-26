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


	stmts := parser.parse(tokens[:])

	// print AST and exit
	if command == "parse" {
		for stmt in stmts {
			#partial switch v in stmt {
			case parser.Print_Stmt:
				parser.print_ast(v.expr)
			case parser.Expression_Stmt:
				parser.print_ast(v.expr)
			case parser.Declaration_Stmt:
				if expr_ptr, ok := v.initializer.(^parser.Expr); ok {
					parser.print_ast(expr_ptr)
				}
			case parser.Block_Stmt:
			}
		}

		return
	}

	env := new(interpreter.VariableStorage)
	storage := make(map[string]interpreter.Literal_Value)
	env.storage = &storage

	defer delete(storage)
	defer free(env)

	if command == "evaluate" {
		for stmt in stmts {
			result, runtime_error := interpreter.interpret(stmt, env)
			if runtime_error != nil {
				exit_code = 70
				error := runtime_error.(interpreter.Runtime_Error)
				fmt.eprintfln("%s\n[line %d]", error.error, error.line_number)
				return
			}

			interpreter.print_string_value(result)
		}

		return
	}


	if command == "run" {
		for stmt in stmts {
			result, runtime_error := interpreter.interpret(stmt, env)

			if runtime_error != nil {
				exit_code = 70
				error := runtime_error.(interpreter.Runtime_Error)
				fmt.eprintfln("%s\n[line %d]", error.error, error.line_number)
				return
			}

		}
	}
}
