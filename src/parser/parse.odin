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

Expr :: union {
	Literal_Expr,
	Grouping_Expr,
	Unary_Expr,
	Binary_Expr,
	Assignment_Expr,
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

If_Stmt :: struct {
	condition: ^Expr,
	body:      ^Stmt,
	else_body: Maybe(^Stmt),
}

While_Stmt :: struct {
	condition: ^Expr,
	body:      ^Stmt,
}

For_Stmt :: struct {
	initializer: Maybe(^Stmt),
	condition:   Maybe(^Expr),
	increment:   Maybe(^Expr),
	body:        ^Stmt,
}

Block_Stmt :: struct {
	stmts: [dynamic]Stmt,
}

Stmt :: union {
	Print_Stmt,
	Expression_Stmt,
	Declaration_Stmt,
	Block_Stmt,
	If_Stmt,
	While_Stmt,
	For_Stmt,
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
	if match(iter, .IF) {
		consume(iter)
		return parse_if(iter)
	}

	if match(iter, .WHILE) {
		consume(iter)
		return parse_while(iter)
	}

	if match(iter, .FOR) {
		consume(iter)
		return parse_for(iter)
	}

	if match(iter, .LEFT_BRACE) {
		consume(iter) // consume {

		statements := make([dynamic]Stmt)

		for !match(iter, .RIGHT_BRACE, .EOF) {
			stmt := parse_block(iter)
			append_elem(&statements, stmt)
		}

		closing := consume(iter).?
		if closing.type != .RIGHT_BRACE {
			fmt.eprintfln("[line %d] Error at end: Expect '}' .", closing.line_number)
			os.exit(65)
		}

		return Block_Stmt{statements}
	}

	return parse_declaration(iter)
}

parse_while :: proc(iter: ^TokenIterator) -> Stmt {
	if !match(iter, .LEFT_PAREN) {
		fmt.eprint("expected opening parenthesis after while keyword")
		os.exit(65)
	}

	consume(iter) // consume (

	expr := parse_expression(iter) // the condition the if runs on

	if !match(iter, .RIGHT_PAREN) {
		fmt.eprint("expected closing parenthesis after while condition expression")
		os.exit(65)
	}
	consume(iter) // consume )
	while_body := parse_block(iter)
	// need to clone and move to heap b/c while_body is a struct allocated on the stack
	while_body_clone := new_clone(while_body)

	while_stmt := new(Stmt)
	while_stmt^ = While_Stmt {
		condition = expr,
		body      = while_body_clone,
	}

	return while_stmt^
}

parse_for :: proc(iter: ^TokenIterator) -> Stmt {
	if !match(iter, .LEFT_PAREN) {
		fmt.eprint("expected opening parenthesis after for keyword")
		os.exit(65)
	}

	consume(iter) // consume (

	initializer: ^Stmt
	if !match(iter, .SEMICOLON) {
		initializer = new_clone(parse_declaration(iter)) // the initializer
	} else {
		// got this: for (;)
		consume(iter) // consume ;
	}

	condition: ^Expr
	if !match(iter, .SEMICOLON) {
		condition = parse_expression(iter) // the initializer

		if consume(iter).?.type != .SEMICOLON {
			fmt.eprintln("expected semicolon after for loop condition block")
			os.exit(65)
		}
	} else {
		// got this: for(;;)
		consume(iter) // consume ;
	}

	increment: ^Expr
	if !match(iter, .RIGHT_PAREN) {
		increment = parse_assignment(iter) // the initializer

		if consume(iter).?.type != .RIGHT_PAREN {
			fmt.eprintln("expected closing parenthesis after for loop increment block")
			os.exit(65)
		}
	} else {
		consume(iter) // consume )
	}

	for_body := parse_block(iter)
	// need to clone and move to heap b/c for_body is a struct allocated on the stack
	for_body_clone := new_clone(for_body)

	for_stmt := new(Stmt)
	for_stmt^ = For_Stmt {
		initializer = initializer,
		condition   = condition,
		increment   = increment,
		body        = for_body_clone,
	}

	return for_stmt^
}

parse_if :: proc(iter: ^TokenIterator) -> Stmt {
	if !match(iter, .LEFT_PAREN) {
		fmt.eprint("expected opening parenthesis after if keyword")
		os.exit(65)
	}

	consume(iter) // consume (

	expr := parse_expression(iter) // the condition the if runs on

	if !match(iter, .RIGHT_PAREN) {
		fmt.eprint("expected closing parenthesis after if condition expression")
		os.exit(65)
	}
	consume(iter) // consume )

	if_body := parse_block(iter)
	// need to clone and move to heap b/c if_body is a struct allocated on the stack
	if_body_clone := new_clone(if_body)

	else_body: ^Stmt

	if match(iter, .ELSE) {
		consume(iter) // consume else
		else_stmt := parse_block(iter)
		else_body = new_clone(else_stmt)

	}

	return If_Stmt{expr, if_body_clone, else_body}
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

		literal_expr, expr_is_identifier := expr.(Literal_Expr)
		if !expr_is_identifier {
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

		assignment_expr^ = Assignment_Expr {
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
	return parse_or(iter)
}

parse_or :: proc(iter: ^TokenIterator) -> ^Expr {
	expr := parse_and(iter)

	for match(iter, .OR) {
		operator := consume(iter).?
		right := parse_and(iter)

		binary_expr := new(Expr)
		binary_expr^ = Binary_Expr {
			left      = expr,
			operation = operator,
			right     = right,
		}

		expr = binary_expr
	}

	return expr
}

parse_and :: proc(iter: ^TokenIterator) -> ^Expr {
	expr := parse_assignment(iter)

	for match(iter, .AND) {
		operator := consume(iter).?
		right := parse_assignment(iter)

		binary_expr := new(Expr)
		binary_expr^ = Binary_Expr {
			left      = expr,
			operation = operator,
			right     = right,
		}

		expr = binary_expr
	}

	return expr
}

parse_equality :: proc(iter: ^TokenIterator) -> ^Expr {
	expr := parse_comparison(iter)

	for match(iter, .BANG_EQUAL, .EQUAL_EQUAL) {
		operator := consume(iter).?
		right := parse_comparison(iter)

		binary_expr := new(Expr)
		binary_expr^ = Binary_Expr {
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
		binary_expr^ = Binary_Expr {
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
		binary_expr^ = Binary_Expr {
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
		binary_expr^ = Binary_Expr {
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
	expr^ = Unary_Expr{operation, right}

	return expr
}

parse_primary :: proc(iter: ^TokenIterator) -> ^Expr {
	token := current(iter)
	consume(iter)

	expr := new(Expr)

	#partial switch token.type {
	case .TRUE:
		expr^ = Literal_Expr{.TRUE, token}
	case .FALSE:
		expr^ = Literal_Expr{.FALSE, token}
	case .NIL:
		expr^ = Literal_Expr{.NIL, token}
	case .NUMBER:
		expr^ = Literal_Expr{.NUMBER, token}
	case .STRING:
		expr^ = Literal_Expr{.STRING, token}
	case .LEFT_PAREN:
		// consume current token, parse the rest as primary again and expect a closing parenthesis
		nested := parse_expression(iter)

		closing := current(iter)
		if closing.type != .RIGHT_PAREN {
			fmt.eprintln("unmatched closing parenthesis")
			os.exit(65)
		}

		consume(iter)
		expr^ = Grouping_Expr {
			value = nested,
		}
	case .IDENTIFIER:
		expr^ = Literal_Expr{.VARIABLE, token}
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
	#partial switch v in expression {
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
