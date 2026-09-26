package parser

import "../lexer"
import "core:fmt"
import "core:os"

LiteralType :: enum {
	TRUE,
	FALSE,
	NIL,
	NUMBER,
	STRING,
	VARIABLE,
}

Literal_Expr :: struct {
	type:  LiteralType,
	token: lexer.Token,
}

Grouping_Expr :: struct {
	value: ^Expr,
}

Unary_Expr :: struct {
	operation: lexer.Token,
	right:     ^Expr,
}

Binary_Expr :: struct {
	left:      ^Expr,
	operation: lexer.Token,
	right:     ^Expr,
}

Assignment_Expr :: struct {
	variable: lexer.Token,
	value:    ^Expr,
}

Expression_Kind :: enum {
	Literal,
	Grouping,
	Unary,
	Binary,
	Variable,
	Assignment,
}

Expression_value :: union {
	Literal_Expr,
	Grouping_Expr,
	Unary_Expr,
	Binary_Expr,
	Assignment_Expr,
}

Expr :: struct {
	kind:  Expression_Kind,
	value: Expression_value,
}

Print_Stmt :: struct {
	expr: ^Expr,
}

Expression_Stmt :: struct {
	expr: ^Expr,
}

Declaration_Stmt :: struct {
	var_name:    lexer.Token,
	initializer: Maybe(^Expr),
}

Block_Stmt :: distinct [dynamic]Stmt

Stmt :: union {
	Print_Stmt,
	Expression_Stmt,
	Declaration_Stmt,
	Block_Stmt,
}

parse :: proc(tokens: []lexer.Token) -> [dynamic]Stmt {
	stmts := make([dynamic]Stmt)
	iterator := TokenIterator{tokens, 0}

	for !match(&iterator, .EOF) {
		append_elem(&stmts, parse_block(&iterator))
	}

	return stmts
}

parse_block :: proc(iter: ^TokenIterator) -> Stmt {
	if match(iter, .LEFT_BRACE) {
		consume(iter) // consume {

		statements := make(Block_Stmt)

		for !match(iter, .RIGHT_BRACE, .EOF) {
			stmt := parse_block(iter)
			append_elem(&statements, stmt)
		}

		closing := consume(iter).?
		if closing.type != .RIGHT_BRACE {
			fmt.eprintfln("[line %d] Error at end: Expect '}' .", closing.line_number)
			os.exit(65)
		}

		return statements
	}

	return parse_declaration(iter)
}

parse_declaration :: proc(iter: ^TokenIterator) -> Stmt {
	// var x = expr;
	if match(iter, .VAR) {
		consume(iter) // consumes VAR

		if !match(iter, .IDENTIFIER) {
			panic("expected identifier after VAR")
		}

		identifier := consume(iter).? // consume identifier
		if match(iter, .SEMICOLON) {
			consume(iter) // consume ;
			return Declaration_Stmt{identifier, nil}
		}

		equal_sign := match(iter, .EQUAL)
		if !equal_sign {
			panic("expected = after identifier in var declaration")
		}

		consume(iter) // consume =

		initializer := parse_expression(iter)
		semi_colon := match(iter, .SEMICOLON)
		if !semi_colon {
			panic("expected semicolon in var declaration")
		}
		consume(iter) // consume ;

		return Declaration_Stmt{identifier, initializer}
	}

	return parse_statement(iter)
}

parse_assignment :: proc(iter: ^TokenIterator) -> ^Expr {
	expr := parse_equality(iter)

	if match(iter, .EQUAL) {
		equal := consume(iter)
		assignment := parse_assignment(iter)

		expr_is_identifier := expr.kind == .Literal
		literal_expr, ok := expr.value.(Literal_Expr)

		if !ok {
			// this is invalid
			fmt.eprintln(
				"expected the left hand side of an assignment operation to be a literal expression",
			)
			os.exit(65)
		}

		variable_literal := literal_expr.type == .VARIABLE
		if !variable_literal {
			fmt.eprintln(
				"expected the left hand side of an assignment operation to be a variable literal",
			)
			os.exit(65)
		}

		assignment_expr := new(Expr)
		assignment_expr.kind = .Assignment
		assignment_expr.value = Assignment_Expr {
			variable = literal_expr.token,
			value    = assignment,
		}

		return assignment_expr
	}

	return expr
}

parse_statement :: proc(iter: ^TokenIterator) -> Stmt {
	if match(iter, .PRINT) {
		print := current(iter)

		// consume print keyword
		consume(iter)
		is_semi_colon := current(iter).type == .SEMICOLON
		if is_semi_colon {
			os.exit(65)
		}

		expression := parse_expression(iter)

		// expect a closing semicolon
		is_semi_colon = current(iter).type == .SEMICOLON
		if !is_semi_colon {
			fmt.eprintfln(
				"[line %d] Expected a semicolon after a PRINT statement",
				print.line_number,
			)
			os.exit(65)
		}

		consume(iter)
		return Print_Stmt{expression}
	}

	expr := parse_expression(iter)

	// expect a closing semicolon
	is_semi_colon := current(iter).type == .SEMICOLON
	if is_semi_colon {
		consume(iter)
	}

	return Expression_Stmt{expr}
}

parse_expression :: proc(iter: ^TokenIterator) -> ^Expr {
	return parse_assignment(iter)
}

parse_equality :: proc(iter: ^TokenIterator) -> ^Expr {
	expr := parse_comparison(iter)

	for match(iter, .BANG_EQUAL, .EQUAL_EQUAL) {
		operator := consume(iter).?
		right := parse_comparison(iter)

		binary_expr := new(Expr)
		binary_expr.kind = .Binary
		binary_expr.value = Binary_Expr {
			left      = expr,
			operation = operator,
			right     = right,
		}

		expr = binary_expr
	}

	return expr
}

parse_comparison :: proc(iter: ^TokenIterator) -> ^Expr {
	expr := parse_term(iter)

	for match(iter, .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL) {
		operator := consume(iter).?
		right := parse_term(iter)

		binary_expr := new(Expr)
		binary_expr.kind = .Binary
		binary_expr.value = Binary_Expr {
			left      = expr,
			operation = operator,
			right     = right,
		}

		expr = binary_expr
	}

	return expr
}

parse_term :: proc(iter: ^TokenIterator) -> ^Expr {
	expr := parse_factor(iter)

	for match(iter, .PLUS, .MINUS) {
		operator := consume(iter).?
		right := parse_factor(iter)

		binary_expr := new(Expr)
		binary_expr.kind = .Binary
		binary_expr.value = Binary_Expr {
			left      = expr,
			operation = operator,
			right     = right,
		}

		expr = binary_expr
	}

	return expr
}

// handle * and /
parse_factor :: proc(iter: ^TokenIterator) -> ^Expr {
	expr := parse_unary(iter)

	for match(iter, .STAR, .SLASH) {
		operator := consume(iter).?
		right := parse_unary(iter)

		binary_expr := new(Expr)
		binary_expr.kind = .Binary
		binary_expr.value = Binary_Expr {
			left      = expr,
			operation = operator,
			right     = right,
		}

		expr = binary_expr
	}

	return expr
}

parse_unary :: proc(iter: ^TokenIterator) -> ^Expr {
	// need to match - and !
	if !match(iter, .MINUS, .BANG) do return parse_primary(iter)

	operation := consume(iter).?

	right := parse_unary(iter)
	expr := new(Expr)
	expr.kind = .Unary
	expr.value = Unary_Expr{operation, right}

	return expr
}

parse_primary :: proc(iter: ^TokenIterator) -> ^Expr {
	token := current(iter)
	consume(iter)

	expr := new(Expr)

	#partial switch token.type {
	case .TRUE:
		expr^ = Expr{.Literal, Literal_Expr{.TRUE, token}}
	case .FALSE:
		expr^ = Expr{.Literal, Literal_Expr{.FALSE, token}}
	case .NIL:
		expr^ = Expr{.Literal, Literal_Expr{.NIL, token}}
	case .NUMBER:
		expr^ = Expr{.Literal, Literal_Expr{.NUMBER, token}}
	case .STRING:
		expr^ = Expr{.Literal, Literal_Expr{.STRING, token}}
	case .LEFT_PAREN:
		// consume current token, parse the rest as primary again and expect a closing parenthesis
		nested := parse_expression(iter)

		closing := current(iter)
		if closing.type != .RIGHT_PAREN {
			fmt.eprintln("unmatched closing parenthesis")
			os.exit(65)
		}

		consume(iter)
		expr^ = Expr{.Grouping, Grouping_Expr{value = nested}}
	case .IDENTIFIER:
		expr^ = Expr{.Literal, Literal_Expr{.VARIABLE, token}}
	case:
		fmt.eprintfln(
			"[line %d] Error at '%s': Expect expression.",
			token.line_number,
			token.lexeme,
		)
		os.exit(65)
	// panic("not a literal, can't be parsed")
	}

	return expr
}

print_ast :: proc(expression: ^Expr) {
	#partial switch v in expression.value {
	case Binary_Expr:
		print_binary(v)
	case Literal_Expr:
		print_literal(v)
	case Grouping_Expr:
		print_group(v)
	case Unary_Expr:
		print_unary(v)
	}
}

print_literal :: proc(literal: Literal_Expr) {
	#partial switch literal.type {
	case .NUMBER:
		fallthrough
	case .STRING:
		fmt.print(literal.token.value)
	case:
		fmt.print(literal.token.lexeme)
	}
}

print_group :: proc(group: Grouping_Expr) {
	fmt.print("(group ")
	print_ast(group.value)
	fmt.print(")")
}

print_unary :: proc(unary: Unary_Expr) {
	fmt.print("(")
	fmt.print(unary.operation.lexeme)
	fmt.print(" ")
	print_ast(unary.right)
	fmt.print(")")
}

print_binary :: proc(binary: Binary_Expr) {
	fmt.print("(")
	fmt.print(binary.operation.lexeme)
	fmt.print(" ")
	print_ast(binary.left)
	fmt.print(" ")
	print_ast(binary.right)
	fmt.print(")")
}
