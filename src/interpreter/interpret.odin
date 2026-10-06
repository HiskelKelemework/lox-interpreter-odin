

package interpreter

import "../lexer"
import "../parser"
import "core:fmt"
import "core:strconv"
import "core:strings"

Literal_Value :: union {
	bool,
	string,
	f64,
}

Runtime_Error :: struct {
	line_number: int,
	error:       string,
}

VariableStorage :: struct {
	enclosing: ^VariableStorage,
	storage:   ^map[string]Literal_Value,
}

create_var_value :: proc(storage: ^VariableStorage, key: string, value: Literal_Value) {
	storage.storage[key] = value
}

update_var_value :: proc(
	storage: ^VariableStorage,
	key: string,
	value: Literal_Value,
) -> (
	success: bool,
) {
	current_scope := storage

	for current_scope != nil {
		_, exists := current_scope.storage[key]
		if exists {
			current_scope.storage[key] = value
			return true
		}

		current_scope = current_scope.enclosing
	}

	return false
}

get_var_value :: proc(
	storage: ^VariableStorage,
	key: string,
) -> (
	result: Literal_Value,
	found: bool,
) {
	current_scope := storage

	for current_scope != nil {
		value, exists := current_scope.storage[key]
		if exists do return value, true

		current_scope = current_scope.enclosing
	}

	return nil, false
}

interpret :: proc(
	stmt: parser.Stmt,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	error: Maybe(Runtime_Error),
) {
	switch v in stmt {
	case parser.Declaration_Stmt:
		return interpret_variable(v, env)
	case parser.Print_Stmt:
		result := interpret_expr(v.expr, env) or_return
		fmt.println(result)
		return result, nil
	case parser.Expression_Stmt:
		return interpret_expr(v.expr, env)
	case parser.Block_Stmt:
		return interpret_block(v, env)
	case parser.If_Stmt:
		return interpret_if(v, env)
	}

	panic("unimplemented")
}

interpret_if :: proc(
	stmt: parser.If_Stmt,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	error: Maybe(Runtime_Error),
) {
	condition_result := interpret_expr(stmt.condition, env) or_return
	boolean_value := literal_to_boolean(condition_result)

	if boolean_value {
		return interpret(stmt.body^, env)
	} else if else_body, ok := stmt.else_body.?; ok {
		return interpret(else_body^, env)
	}

	return nil, nil
}

interpret_block :: proc(
	block_stmt: parser.Block_Stmt,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	error: Maybe(Runtime_Error),
) {
	new_env := new(VariableStorage)
	new_storage := make(map[string]Literal_Value)
	new_env.storage = &new_storage
	new_env.enclosing = env

	defer delete(new_storage)
	defer free(new_env)

	// todo: make new env here and pass it on
	for stmt in block_stmt.stmts {
		interpret(stmt, new_env) or_return
	}

	return nil, nil
}

interpret_expr :: proc(
	expr: ^parser.Expr,
	env: ^VariableStorage,
) -> (
	Literal_Value,
	Maybe(Runtime_Error),
) {
	#partial switch &v in expr {
	case parser.Literal_Expr:
		return interpret_literal(&v, env)
	case parser.Grouping_Expr:
		return interpret_expr(v.value, env)
	case parser.Unary_Expr:
		return interpret_unary(&v, env)
	case parser.Binary_Expr:
		return interpret_binary(&v, env)
	case parser.Assignment_Expr:
		return interpret_assignment(&v, env)
	case:
		panic("unsupported expr type")
	}
}

interpret_assignment :: proc(
	expr: ^parser.Assignment_Expr,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	error: Maybe(Runtime_Error),
) {
	key := expr.variable.lexeme
	value := interpret_expr(expr.value, env) or_return

	success := update_var_value(env, key, value)

	if !success {
		return nil, Runtime_Error {
			line_number = expr.variable.line_number,
			error = "Undeclared variable",
		}
	}

	return value, nil
}

interpret_variable :: proc(
	stmt: parser.Declaration_Stmt,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	error: Maybe(Runtime_Error),
) {
	token := stmt.var_name

	result = stmt.initializer == nil ? nil : interpret_expr(stmt.initializer.?, env) or_return

	create_var_value(env, token.lexeme, result)

	return result, nil
}

interpret_binary :: proc(
	expr: ^parser.Binary_Expr,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	runtime_error: Maybe(Runtime_Error),
) {

	#partial switch expr.operation.type {
	case .STAR:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) * right.(f64), nil
	case .SLASH:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) / right.(f64), nil
	case .PLUS:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		if left_string, ok := left.(string); ok {
			if right_string, ok := right.(string); ok {
				return fmt.tprintf("%s%s", left_string, right_string), nil
			}
		}

		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) + right.(f64), nil
	case .MINUS:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) - right.(f64), nil
	case .LESS:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) < right.(f64), nil
	case .LESS_EQUAL:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) <= right.(f64), nil
	case .GREATER:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) > right.(f64), nil
	case .GREATER_EQUAL:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) >= right.(f64), nil
	case .EQUAL_EQUAL:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		same_type := type_of(left) == type_of(right)
		if !same_type do return false, nil
		return left == right, nil
	case .BANG_EQUAL:
		left := interpret_expr(expr.left, env) or_return
		right := interpret_expr(expr.right, env) or_return
		same_type := type_of(left) == type_of(right)
		if !same_type do return true, nil
		return left != right, nil
	case .OR:
		left := interpret_expr(expr.left, env) or_return
		if literal_to_boolean(left) do return left, nil

		right := interpret_expr(expr.right, env) or_return
		return right, nil
	case .AND:
		left := interpret_expr(expr.left, env) or_return
		if !literal_to_boolean(left) do return left, nil

		right := interpret_expr(expr.right, env) or_return
		return right, nil
	case:
		panic("unimplemented binary operation")
	}
}

interpret_unary :: proc(
	expr: ^parser.Unary_Expr,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	runtime_error: Maybe(Runtime_Error),
) {
	value := interpret_expr(expr.right, env) or_return

	#partial switch expr.operation.type {
	case .MINUS:
		assert_numeric(expr.operation, value, "Operand must be a number.") or_return
		return value.(f64) * -1, nil
	case .BANG:
		boolean_value := coerce_to_boolean(expr.operation, value) or_return
		return !boolean_value, nil
	case:
		panic(fmt.tprintf("unrecognized unary operand %s", expr.operation.type))
	}
}

interpret_literal :: proc(
	expr: ^parser.Literal_Expr,
	env: ^VariableStorage,
) -> (
	Literal_Value,
	Maybe(Runtime_Error),
) {
	switch expr.type {
	case .TRUE:
		return true, nil
	case .FALSE:
		return false, nil
	case .NIL:
		return nil, nil
	case .NUMBER:
		parsed_number, ok := strconv.parse_f64(expr.token.value.?)
		// NOTE: this should never happen. if it does, it means our lexer isn't working properly
		if !ok do panic("should never happen: Could not parse number to f64")

		return parsed_number, nil
	case .STRING:
		return expr.token.value.?, nil
	case .VARIABLE:
		key := expr.token.lexeme

		value, found := get_var_value(env, key)
		if !found do return nil, undefined_variable_error(expr.token)

		return value, nil
	case:
		panic(fmt.tprintf("unsupported literal %s", expr.type))
	}
}

assert_numeric_operands :: proc(
	operation: lexer.Token,
	left, right: Literal_Value,
) -> Maybe(Runtime_Error) {
	_, left_numeric := left.(f64)
	_, right_numeric := right.(f64)

	if !left_numeric || !right_numeric {
		return Runtime_Error {
			line_number = operation.line_number,
			error = "Expected numbers as operands",
		}
	}

	return nil
}

assert_numeric :: proc(
	operation: lexer.Token,
	left: Literal_Value,
	error: string,
) -> Maybe(Runtime_Error) {
	if _, ok := left.(f64); !ok {
		return Runtime_Error{line_number = operation.line_number, error = error}
	}

	return nil
}

coerce_to_boolean :: proc(
	operation: lexer.Token,
	value: Literal_Value,
) -> (
	bool,
	Maybe(Runtime_Error),
) {
	if value == nil do return false, nil

	#partial switch v in value {
	case f64:
		return true, nil
	case bool:
		return v, nil
	case:
		return false, Runtime_Error {
			line_number = operation.line_number,
			error = "value can't be coerced to a boolean",
		}
	}
}

literal_to_boolean :: proc(literal: Literal_Value) -> bool {
	switch v in literal {
	case nil:
		return false
	case f64:
		return true
	case bool:
		return v
	case string:
		return true
	}

	panic("unknown literal value type")
}

print_string_value :: proc(value: Literal_Value) {
	#partial switch v in value {
	case f64:
		int_version := int(v)
		is_whole_number := f64(int_version) == v

		if (is_whole_number) {
			fmt.println(int_version)
		} else {
			fmt.println(strings.trim_right(fmt.tprintf("%.2f", v), "0"))
		}
	case:
		fmt.println(value)
	}
}

undefined_variable_error :: proc(token: lexer.Token) -> Runtime_Error {
	key := token.lexeme
	error := fmt.tprintf("Undefined vairable '%s'.", key)
	return Runtime_Error{token.line_number, error}
}

print_literal :: proc(literal: Literal_Value) {
	#partial switch v in literal {
	case f64:
		// need to do some rounding
		formatted := lexer.format_floating_point(fmt.tprintf("%d", v))
		fmt.println(formatted)
	case:
		fmt.println(v)
	}
}
