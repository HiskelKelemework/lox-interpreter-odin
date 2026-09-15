

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
	case:
		panic("unsupported expr type")
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
