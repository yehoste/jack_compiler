module main

struct Parser {
	tokens []string
	mut:
		index        int
		class_name   string
		output       string
		label_index  int
}

// === Utility functions ===

fn (mut p Parser) peek() string {
	if p.index < p.tokens.len {
		return p.tokens[p.index]
	}
	return ''
}

fn (mut p Parser) advance() string {
	if p.index < p.tokens.len {
		p.index++
		return p.tokens[p.index - 1]
	}
	return ''
}

fn (mut p Parser) eat(expected string) string {
	token := p.advance()
	if token != expected {
		panic('Expected "$expected", got "$token"')
	}
	return token
}

fn (mut p Parser) write(line string) {
	p.output += line + '\n'
}

// === VM Translation functions ===

fn (mut p Parser) parse_class() string {
	p.eat('class')
	p.class_name = p.advance()
	p.eat('{')
	for p.peek() in ['static', 'field'] {
		p.parse_class_var_dec()
	}
	for p.peek() in ['constructor', 'function', 'method'] {
		p.parse_subroutine()
	}
	p.eat('}')
	return p.output
}

fn (mut p Parser) parse_class_var_dec() {
	_ = p.advance() // static or field
	_ = p.advance() // type
	_ = p.advance() // varName
	mut token := p.peek()
	for token == ',' {
		p.advance()
		_ = p.advance()
		token = p.peek()
	}
	p.eat(';')
}

fn (mut p Parser) parse_subroutine() {
	_ = p.advance() // constructor, function, method
	_ = p.advance() // return type
	subroutine_name := p.advance()
	p.eat('(')
	p.parse_parameter_list()
	p.eat(')')

	p.eat('{')
	for p.peek() == 'var' {
		p.parse_var_dec()
	}

	// Assume 0 local variables for now
	p.write('function ${p.class_name}.$subroutine_name 0')
	p.parse_statements()
	p.eat('}')
}

fn (mut p Parser) parse_parameter_list() {
	if p.peek() != ')' {
		_ = p.advance() // type
		_ = p.advance() // varName
		mut token := p.peek()
		for token == ',' {
			p.advance()
			_ = p.advance()
			_ = p.advance()
			token = p.peek()
		}
	}
}

fn (mut p Parser) parse_var_dec() {
	p.eat('var')
	_ = p.advance() // type
	_ = p.advance() // varName
	mut token := p.peek()
	for token == ',' {
		p.advance()
		_ = p.advance()
		token = p.peek()
	}
	p.eat(';')
}

fn (mut p Parser) parse_statements() {
	for p.peek() in ['let', 'if', 'while', 'do', 'return'] {
		match p.peek() {
			'let' { p.parse_let() }
			'if' { p.parse_if() }
			'while' { p.parse_while() }
			'do' { p.parse_do() }
			'return' { p.parse_return() }
			else {}
		}
	}
}

fn (mut p Parser) parse_let() {
	p.eat('let')
	var_name := p.advance()
	mut is_array := false
	if p.peek() == '[' {
		is_array = true
		p.eat('[')
		p.parse_expression()
		p.eat(']')
	}
	p.eat('=')
	p.parse_expression()
	p.eat(';')
	if is_array {
		p.write('// let ${var_name}[...] = ... (not implemented)')
	} else {
		p.write('pop local 0') // dummy, replace with actual logic
	}
}

fn (mut p Parser) parse_if() {
	p.eat('if')
	p.eat('(')
	p.parse_expression()
	p.eat(')')
	label_true := 'IF_TRUE${p.label_index}'
	label_false := 'IF_FALSE${p.label_index}'
	label_end := 'IF_END${p.label_index}'
	p.label_index++
	p.write('if-goto $label_true')
	p.write('goto $label_false')
	p.write('label $label_true')
	p.eat('{')
	p.parse_statements()
	p.eat('}')
	if p.peek() == 'else' {
		p.write('goto $label_end')
		p.write('label $label_false')
		p.eat('else')
		p.eat('{')
		p.parse_statements()
		p.eat('}')
		p.write('label $label_end')
	} else {
		p.write('label $label_false')
	}
}

fn (mut p Parser) parse_while() {
	label_exp := 'WHILE_EXP${p.label_index}'
	label_end := 'WHILE_END${p.label_index}'
	p.label_index++
	p.write('label $label_exp')
	p.eat('while')
	p.eat('(')
	p.parse_expression()
	p.eat(')')
	p.write('not')
	p.write('if-goto $label_end')
	p.eat('{')
	p.parse_statements()
	p.eat('}')
	p.write('goto $label_exp')
	p.write('label $label_end')
}

fn (mut p Parser) parse_do() {
	p.eat('do')
	p.parse_subroutine_call()
	p.eat(';')
	p.write('pop temp 0') // discard return value
}

fn (mut p Parser) parse_return() {
	p.eat('return')
	if p.peek() != ';' {
		p.parse_expression()
	} else {
		p.write('push constant 0')
	}
	p.eat(';')
	p.write('return')
}

fn (mut p Parser) parse_expression() {
	p.parse_term()
	for p.peek() in ['+', '-', '*', '/', '&', '|', '<', '>', '='] {
		op := p.advance()
		p.parse_term()
		match op {
			'+' { p.write('add') }
			'-' { p.write('sub') }
			'*' { p.write('call Math.multiply 2') }
			'/' { p.write('call Math.divide 2') }
			'&' { p.write('and') }
			'|' { p.write('or') }
			'<' { p.write('lt') }
			'>' { p.write('gt') }
			'=' { p.write('eq') }
			else {}
		}
	}
}

fn (mut p Parser) parse_term() {
	token := p.peek()
	if token == '(' {
		p.eat('(')
		p.parse_expression()
		p.eat(')')
	} else if token in ['-', '~'] {
		op := p.advance()
		p.parse_term()
		if op == '-' {
			p.write('neg')
		} else {
			p.write('not')
		}
	} else if is_integer(token) {
		val := p.advance().int()
		p.write('push constant $val')
	} else {
		// identifier: could be var or subroutine call
		identifier := p.advance()
		if p.peek() == '[' {
			p.eat('[')
			p.parse_expression()
			p.eat(']')
			p.write('// array access: $identifier[...]')
		} else if p.peek() == '(' || p.peek() == '.' {
			p.index-- // backtrack to reparse as subroutine
			p.parse_subroutine_call()
		} else {
			p.write('push local 0') // placeholder for var
		}
	}
}

fn (mut p Parser) parse_subroutine_call() {
	name := p.advance()
	mut full_name := name
	mut arg_count := 0
	if p.peek() == '.' {
		p.eat('.')
		full_name = '${name}.${p.advance()}'
	}
	p.eat('(')
	arg_count = p.parse_expression_list()
	p.eat(')')
	p.write('call $full_name $arg_count')
}

fn (mut p Parser) parse_expression_list() int {
	mut count := 0
	if p.peek() != ')' {
		p.parse_expression()
		count++
		mut token := p.peek()
		for token == ',' {
			p.advance()
			p.parse_expression()
			count++
			token = p.peek()
		}
	}
	return count
}

fn is_integer(s string) bool {
	return s.len > 0 && s[0].is_digit()
}
