

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

VariableStorage :: distinct map[string]Literal_Value

interpret :: proc(
	stmt: parser.Stmt,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	error: Maybe(Runtime_Error),
) {
	switch stmt.kind {
	case .VARIABLE:
		assert(stmt.expr.kind == .Variable, "variable expression must be of type literal")
		var_expr := stmt.expr^.value.(parser.Variable_Expr)
		return interpret_variable(&var_expr, env)
	case .PRINT:
		result := interpret_expr(stmt.expr, env) or_return
		fmt.println(result)
		return result, nil
	case .EXPRESSION:
		return interpret_expr(stmt.expr, env)
	}

	panic("unimplemented")
}

interpret_expr :: proc(
	expr: ^parser.Expr,
	env: ^VariableStorage,
) -> (
	Literal_Value,
	Maybe(Runtime_Error),
) {
	#partial switch &v in expr.value {
	case parser.Literal_Expr:
		return interpret_literal(&v, env)
	case parser.Grouping_Expr:
		return interpret_expr(v.value, env)
	case parser.Unary_Expr:
		return interpret_unary(&v, env)
	case parser.Binary_Expr:
		return interpret_binary(&v, env)
	case parser.Variable_Expr:
		return interpret_variable(&v, env)
	case:
		panic("unsupported expr type")
	}
}

interpret_variable :: proc(
	expr: ^parser.Variable_Expr,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	error: Maybe(Runtime_Error),
) {
	token := expr.var_name

	result = expr.initializer == nil ? nil : interpret_expr(expr.initializer.?, env) or_return

	env[token.lexeme] = result
	return result, nil
}

interpret_binary :: proc(
	expr: ^parser.Binary_Expr,
	env: ^VariableStorage,
) -> (
	result: Literal_Value,
	runtime_error: Maybe(Runtime_Error),
) {
	left := interpret_expr(expr.left, env) or_return
	right := interpret_expr(expr.right, env) or_return

	#partial switch expr.operation.type {
	case .STAR:
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) * right.(f64), nil
	case .SLASH:
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) / right.(f64), nil
	case .PLUS:
		if left_string, ok := left.(string); ok {
			if right_string, ok := right.(string); ok {
				return fmt.tprintf("%s%s", left_string, right_string), nil
			}
		}

		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) + right.(f64), nil
	case .MINUS:
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) - right.(f64), nil
	case .LESS:
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) < right.(f64), nil
	case .LESS_EQUAL:
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) <= right.(f64), nil
	case .GREATER:
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) > right.(f64), nil
	case .GREATER_EQUAL:
		assert_numeric_operands(expr.operation, left, right) or_return
		return left.(f64) >= right.(f64), nil
	case .EQUAL_EQUAL:
		same_type := type_of(left) == type_of(right)
		if !same_type do return false, nil
		return left == right, nil
	case .BANG_EQUAL:
		same_type := type_of(left) == type_of(right)
		if !same_type do return true, nil
		return left != right, nil
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
		value, ok := env[key]
		if !ok do return nil, Runtime_Error{99, "undefined variable"}

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
