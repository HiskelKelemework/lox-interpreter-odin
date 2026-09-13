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

Expression_Kind :: enum {
	Literal,
	Grouping,
}

Expression_value :: union {
	Literal_Expr,
	Grouping_Expr,
}

Expr :: struct {
	kind:  Expression_Kind,
	value: Expression_value,
}

parse :: proc(tokens: []lexer.Token) {
	iterator := TokenIterator{tokens, 0}

	expr := parse_primary(&iterator)
	print_ast(expr)
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
		nested := parse_primary(iter)

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
	case Literal_Expr:
		print_literal(v)
	case Grouping_Expr:
		print_group(v)
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
