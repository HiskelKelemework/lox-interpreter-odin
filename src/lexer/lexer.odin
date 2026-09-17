package lexer

import "core:bytes"
import "core:fmt"
import "core:strconv"
import "core:strings"

TokenType :: enum {
	NUMBER,
	STRING,
	WHILE,
	VAR,
	TRUE,
	THIS,
	SUPER,
	RETURN,
	PRINT,
	OR,
	NIL,
	IF,
	FUN,
	FOR,
	FALSE,
	ELSE,
	CLASS,
	AND,
	IDENTIFIER,
	EOF,
	LESS_EQUAL,
	LESS,
	GREATER,
	GREATER_EQUAL,
	BANG,
	BANG_EQUAL,
	STAR,
	EQUAL,
	EQUAL_EQUAL,
	SEMICOLON,
	PLUS,
	MINUS,
	DOT,
	COMMA,
	SLASH,
	LEFT_BRACE,
	RIGHT_BRACE,
	RIGHT_PAREN,
	LEFT_PAREN,
}

Token :: struct {
	type:        TokenType,
	line_number: int,
	lexeme:      string,
	value:       Maybe(string),
}

ReservedKeywords :: distinct map[string]bool
ReservedKeywordsEnumMap :: distinct map[string]TokenType

lex :: proc(source_code: []byte) -> (tokens: [dynamic]Token, errors: [dynamic]string) {
	tokens = make([dynamic]Token)
	errors = make([dynamic]string)

	reserved_keywords_enum_map := build_reserved_keywords_enum_map()
	defer delete(reserved_keywords_enum_map)

	lines := bytes.split(source_code, transmute([]byte)string("\n"))
	defer delete(lines)

	line_number := 1

	i := 0

	for ; i < len(source_code); i += 1 {
		char := source_code[i]

		switch char {
		case '\n':
			line_number += 1
		case '(':
			append_elem(&tokens, Token{.LEFT_PAREN, line_number, "(", nil})
		case ')':
			append_elem(&tokens, Token{.RIGHT_PAREN, line_number, ")", nil})
		case '}':
			append_elem(&tokens, Token{.RIGHT_BRACE, line_number, "}", nil})
		case '{':
			append_elem(&tokens, Token{.LEFT_BRACE, line_number, "{", nil})
		case ',':
			append_elem(&tokens, Token{.COMMA, line_number, ",", nil})
		case '.':
			append_elem(&tokens, Token{.DOT, line_number, ".", nil})
		case '-':
			append_elem(&tokens, Token{.MINUS, line_number, "-", nil})
		case '+':
			append_elem(&tokens, Token{.PLUS, line_number, "+", nil})
		case ';':
			append_elem(&tokens, Token{.SEMICOLON, line_number, ";", nil})
		case '*':
			append_elem(&tokens, Token{.STAR, line_number, "*", nil})
		case '=':
			if i + 1 < len(source_code) && source_code[i + 1] == '=' {
				i += 1
				append_elem(&tokens, Token{.EQUAL_EQUAL, line_number, "==", nil})
				continue
			}

			append_elem(&tokens, Token{.EQUAL, line_number, "=", nil})
		case '!':
			if i + 1 < len(source_code) && source_code[i + 1] == '=' {
				i += 1
				append_elem(&tokens, Token{.BANG_EQUAL, line_number, "!=", nil})
				continue
			}

			append_elem(&tokens, Token{.BANG, line_number, "!", nil})
		case '<':
			if i + 1 < len(source_code) && source_code[i + 1] == '=' {
				i += 1
				append_elem(&tokens, Token{.LESS_EQUAL, line_number, "<=", nil})
				continue
			}

			append_elem(&tokens, Token{.LESS, line_number, "<", nil})
		case '>':
			if i + 1 < len(source_code) && source_code[i + 1] == '=' {
				i += 1
				append_elem(&tokens, Token{.GREATER_EQUAL, line_number, ">=", nil})
				continue
			}

			append_elem(&tokens, Token{.GREATER, line_number, ">", nil})
		case '/':
			if i + 1 < len(source_code) && source_code[i + 1] == '/' {
				for {
					if source_code[i] == '\n' do break
					if i + 1 < len(source_code) do i += 1
					else do break
				}

				break
			}

			append_elem(&tokens, Token{.SLASH, line_number, "/", nil})
		case '\t':
			continue
		case '"':
			j := i + 1
			found := false

			for ; j < len(source_code); j += 1 {
				if source_code[j] == '"' {
					found = true
					break
				}
			}

			// skip to next line processing
			if !found {
				append_elem(
					&errors,
					fmt.tprintf("[line %d] Error: Unterminated string.", line_number),
				)

				i = j
				break
			}

			string_value := string(source_code[i + 1:j])

			append_elem(
				&tokens,
				Token{.STRING, line_number, fmt.tprintf("\"%s\"", string_value), string_value},
			)
			i = j
		case '0' ..= '9':
			end_index := parse_number(source_code, i)

			numeric_string := string(source_code[i:end_index + 1])
			formatted := format_floating_point(numeric_string)

			append_elem(&tokens, Token{.NUMBER, line_number, numeric_string, formatted})

			i = end_index
		case ' ':
			continue
		case 'a' ..= 'z', 'A' ..= 'Z', '_':
			// forward until we find a non alpha, underscore char
			j := i

			for ; j < len(source_code); j += 1 {
				if !is_alpha_numeric(source_code[j]) do break
			}

			identifier := string(source_code[i:j])

			keyword_enum, is_keyword := reserved_keywords_enum_map[identifier]
			if is_keyword {
				append_elem(&tokens, Token{keyword_enum, line_number, identifier, nil})
			} else {
				append_elem(&tokens, Token{.IDENTIFIER, line_number, identifier, nil})
			}

			i = j - 1
		case '$', '#', '@', '%':
			append_elem(
				&errors,
				fmt.tprintf(
					"[line %d] Error: Unexpected character: %s",
					line_number,
					char == '%' ? "%" : fmt.tprintf("%c", char), // % is a formatter parameter. hence the shenanigan
				),
			)
		}
	}

	// EOF on final line
	append_elem(&tokens, Token{.EOF, len(lines), "", nil})

	return
}


build_reserved_keywords_enum_map :: proc() -> ReservedKeywordsEnumMap {
	reserved_keywords := make(ReservedKeywordsEnumMap, 16)

	reserved_keywords["and"] = .AND
	reserved_keywords["class"] = .CLASS
	reserved_keywords["else"] = .ELSE
	reserved_keywords["false"] = .FALSE
	reserved_keywords["for"] = .FOR
	reserved_keywords["fun"] = .FUN
	reserved_keywords["if"] = .IF
	reserved_keywords["nil"] = .NIL
	reserved_keywords["or"] = .OR
	reserved_keywords["print"] = .PRINT
	reserved_keywords["return"] = .RETURN
	reserved_keywords["super"] = .SUPER
	reserved_keywords["this"] = .THIS
	reserved_keywords["true"] = .TRUE
	reserved_keywords["var"] = .VAR
	reserved_keywords["while"] = .WHILE

	return reserved_keywords
}

ParseNumberState :: enum {
	NUMBER_BEFORE_DOT,
	DOT,
	NUMBER_AFTER_DOT,
}

// we only allow small letters, capital letters, and underscore
is_alpha_numeric :: proc(char: byte) -> bool {
	is_numeric := char >= '0' && char <= '9'
	is_small_letter := char >= 'a' && char <= 'z'
	is_upper_case_letter := char >= 'A' && char <= 'Z'
	is_underscore := char == '_'

	return is_numeric || is_small_letter || is_upper_case_letter || is_underscore
}

format_floating_point :: proc(numeric_string: string) -> string {
	parts, error := strings.split(numeric_string, ".")
	if error != nil {
		panic("should never happen ")
	}

	defer delete(parts)

	if len(parts) > 2 {
		panic("should never receive this, more than two parts to a floating point number")
	}

	if len(parts) == 1 do return fmt.tprintf("%s.0", parts[0])
	decimal_point, ok := strconv.parse_int(parts[1])

	if !ok {
		panic("parsing integer should not fail")
	}

	decimal_string :=
		decimal_point == 0 ? "0" : strings.trim_right(fmt.tprintf("%d", decimal_point), "0")

	return fmt.tprintf("%s.%s", parts[0], decimal_string)
}
parse_number :: proc(line: []byte, current_index: int) -> (end_index: int) {
	assert(is_numeric(line[current_index]), "first character is not numeric")

	state := ParseNumberState.NUMBER_BEFORE_DOT
	j := current_index

	main_loop: for ; j < len(line); j += 1 {
		char := line[j]

		is_numeric := is_numeric(char)
		is_dot := char == '.'
		is_invalid := !is_numeric && !is_dot

		if is_invalid do break main_loop

		switch state {
		case .NUMBER_BEFORE_DOT:
			if is_dot do state = .DOT
		case .DOT:
			if is_numeric do state = .NUMBER_AFTER_DOT
			if is_dot {
				// we encountered two dots in a row.
				// we must de-consume the dot we just processed so
				// it can be picked up again by the top level state machine
				j -= 1
				break main_loop
			}
		case .NUMBER_AFTER_DOT:
			if !is_numeric do break main_loop
		}
	}

	// whatever index we stopped at, didn't meet the number parsing criteria. therefore the number ended one index back
	return j - 1
}

is_numeric :: proc(char: byte) -> bool {
	return char >= '0' && char <= '9'
}

print_token :: proc(token: Token) {
	fmt.printfln("%s %s %s", token.type, token.lexeme, token.value == nil ? "null" : token.value.?)
}
