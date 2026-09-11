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

Literal :: struct {
	type:  LiteralType,
	value: string,
}

Expression :: union {
	Literal,
}

parse :: proc(tokens: []lexer.Token) {
	for token in tokens {
		if token.type == .EOF do break

		parsed := parse_literal(token)
		print_ast(parsed)
	}
}

parse_literal :: proc(token: lexer.Token) -> Expression {
	#partial switch token.type {
	case .TRUE:
		return Literal{.TRUE, "true"}
	case .FALSE:
		return Literal{.FALSE, "false"}
	case .NIL:
		return Literal{.NIL, "nil"}
	}

	panic("not a literal, can't be parsed")
}


print_ast :: proc(expression: Expression) {
	switch v in expression {
	case Literal:
		fmt.println(v.value)
	}
}
