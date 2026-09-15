

package interpreter

import "../parser"
import "core:fmt"
import "core:strconv"

Literal_Value :: union {
	bool,
	string,
	f64,
}

interpret :: proc(expr: ^parser.Expr) -> (Literal_Value, bool) {
	#partial switch &v in expr.value {
	case parser.Literal_Expr:
		return interpret_literal(&v)
	case parser.Grouping_Expr:
		return interpret(v.value)
	case parser.Unary_Expr:
		return interpret_unary(&v)
	case parser.Binary_Expr:
		return interpret_binary(&v)
	case:
		panic("unsupported expr type")
	}
}

interpret_binary :: proc(expr: ^parser.Binary_Expr) -> (Literal_Value, bool) {
	left, left_success := interpret(expr.left)
	right, right_success := interpret(expr.right)

	if !left_success || !right_success {
		panic("left and right side interpreting failed")
	}

	#partial switch expr.operation.type {
	case .STAR:
		left_number := assert_number(left)
		right_number := assert_number(right)
		return left_number * right_number, true
	case .SLASH:
		left_number := assert_number(left)
		right_number := assert_number(right)
		return left_number / right_number, true
	case:
		panic("unimplemented binary operation")
	}
}

interpret_unary :: proc(expr: ^parser.Unary_Expr) -> (Literal_Value, bool) {
	value, ok := interpret(expr.right)
	if !ok do return false, false

	#partial switch expr.operation.type {
	case .MINUS:
		#partial switch v in value {
		case f64:
			return -1 * v, true
		case:
			panic("expected a number")
		}
	case .BANG:
		truthy_value, success := get_truth_value(value)
		if !success do panic("can't coerce value to boolean")
		return !truthy_value, true
	case:
		panic(fmt.tprintf("unrecognized unary operand %s", expr.operation.type))
	}
}

interpret_literal :: proc(expr: ^parser.Literal_Expr) -> (Literal_Value, bool) {
	switch expr.type {
	case .TRUE:
		return true, true
	case .FALSE:
		return false, true
	case .NIL:
		return nil, true
	case .NUMBER:
		return strconv.parse_f64(expr.value)
	case .STRING:
		return expr.value, true
	case:
		panic("unsupported literal")
	}
}

assert_number :: proc(value: Literal_Value) -> f64 {
	#partial switch v in value {
	case f64:
		return v
	case:
		panic("expected a number")
	}
}

get_truth_value :: proc(value: Literal_Value) -> (bool, bool) {
	if value == nil do return false, true

	#partial switch v in value {
	case f64:
		return true, true
	case bool:
		return v, true
	case:
		return false, false
	}
}
