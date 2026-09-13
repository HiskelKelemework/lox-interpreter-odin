package parser

import "../lexer"
import "core:fmt"

LiteralType :: enum {
	TRUE,
	FALSE,
	NIL,
	NUMBER,
	STRING,
}

Literal_Expr :: struct {
	type:  LiteralType,
	value: string,
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

Expression_Kind :: enum {
	Literal,
	Grouping,
	Unary,
	Binary,
}

Expression_value :: union {
	Literal_Expr,
	Grouping_Expr,
	Unary_Expr,
	Binary_Expr,
}

Expr :: struct {
	kind:  Expression_Kind,
	value: Expression_value,
}

parse :: proc(tokens: []lexer.Token) {
	iterator := TokenIterator{tokens, 0}

	expr := parse_expression(&iterator)
	print_ast(expr)
}

parse_expression :: proc(iter: ^TokenIterator) -> ^Expr {
	return parse_factor(iter)
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
		expr^ = Expr{.Literal, Literal_Expr{.TRUE, "true"}}
	case .FALSE:
		expr^ = Expr{.Literal, Literal_Expr{.FALSE, "false"}}
	case .NIL:
		expr^ = Expr{.Literal, Literal_Expr{.NIL, "nil"}}
	case .NUMBER:
		expr^ = Expr{.Literal, Literal_Expr{.NUMBER, token.value.?}}
	case .STRING:
		expr^ = Expr{.Literal, Literal_Expr{.STRING, token.value.?}}
	case .LEFT_PAREN:
		// consume current token, parse the rest as primary again and expect a closing parenthesis
		nested := parse_expression(iter)

		closing := current(iter)
		if closing.type != .RIGHT_PAREN {
			panic("unmatched closing parenthesis")
		}

		expr^ = Expr{.Grouping, Grouping_Expr{value = nested}}
	case:
		panic("not a literal, can't be parsed")
	}

	return expr
}

print_ast :: proc(expression: ^Expr) {
	switch v in expression.value {
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
	fmt.print(literal.value)
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
