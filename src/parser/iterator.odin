package parser

import "../lexer"

TokenIterator :: struct {
	tokens:  []lexer.Token,
	current: int,
}

peek :: proc(iterator: ^TokenIterator) -> Maybe(lexer.Token) {
	next_item_index := iterator.current + 1
	if next_item_index >= len(iterator.tokens) do return nil

	return iterator.tokens[next_item_index]
}

current :: proc(iterator: ^TokenIterator) -> lexer.Token {
	return iterator.tokens[iterator.current]
}

consume :: proc(iterator: ^TokenIterator) -> Maybe(lexer.Token) {
	current := iterator.current
	iterator.current += 1

	return iterator.tokens[current]
}

previous :: proc(iterator: ^TokenIterator) -> Maybe(lexer.Token) {
	prev_index := iterator.current - 1
	if prev_index < 0 do return nil

	return iterator.tokens[prev_index]
}
