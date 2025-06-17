module main

struct Parser {
	tokens []string
	mut:
		index        int
		indent_level int
}

// peek returns the current token without advancing
fn (mut p Parser) peek() string {
	if p.index < p.tokens.len {
		return p.tokens[p.index]
	}
	return ''
}

// advance moves to next token and returns the current one
fn (mut p Parser) advance() string {
	if p.index < p.tokens.len {
		p.index++
		return p.tokens[p.index - 1]
	}
	return ''
}

// eat checks if current token matches expected and advances
fn (mut p Parser) eat(expected string) string {
	token := p.advance()
	if token != expected {
		panic('Expected "$expected", got "$token"')
	}
	return token
}

// wrap creates XML tags around a value with proper indentation
fn (p Parser) wrap(kind string, value string) string {
	indent := '  '.repeat(p.indent_level)
	return '${indent}<$kind> $value </$kind>\n'
}

// wrap_block handles nested XML blocks with proper indentation
fn (mut p Parser) wrap_block(tag string, body fn () string) string {
	indent := '  '.repeat(p.indent_level)
	mut result := '${indent}<$tag>\n'
	p.indent_level++
	result += body()
	p.indent_level--
	result += '${indent}</$tag>\n'
	return result
}

// parse_class parses a complete Jack class definition
fn (mut p Parser) parse_class() string {
	return p.wrap_block('class', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.eat('class'))
		result += p.wrap('identifier', p.advance())
		result += p.wrap('symbol', p.eat('{'))
		for p.peek() in ['static', 'field'] {
			result += p.parse_class_var_dec()
		}
		for p.peek() in ['constructor', 'function', 'method'] {
			result += p.parse_subroutine()
		}
		result += p.wrap('symbol', p.eat('}'))
		return result
	})
}

// parse_class_var_dec parses class-level variable declarations
fn (mut p Parser) parse_class_var_dec() string {
	return p.wrap_block('classVarDec', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.advance())
		result += p.parse_type()
		result += p.wrap('identifier', p.advance())
		for p.peek() == ',' {
			result += p.wrap('symbol', p.advance())
			result += p.wrap('identifier', p.advance())
		}
		result += p.wrap('symbol', p.eat(';'))
		return result
	})
}

// parse_type handles built-in types and custom class types
fn (mut p Parser) parse_type() string {
	token := p.advance()
	if token in ['int', 'char', 'boolean'] {
		return p.wrap('keyword', token)
	}
	return p.wrap('identifier', token)
}

// parse_subroutine handles method, function and constructor declarations
fn (mut p Parser) parse_subroutine() string {
	return p.wrap_block('subroutineDec', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.advance())
		if p.peek() == 'void' {
			result += p.wrap('keyword', p.advance())
		} else {
			result += p.parse_type()
		}
		result += p.wrap('identifier', p.advance())
		result += p.wrap('symbol', p.eat('('))
		result += p.parse_parameter_list()
		result += p.wrap('symbol', p.eat(')'))
		result += p.parse_subroutine_body()
		return result
	})
}

// parse_parameter_list handles function/method parameter declarations
// Returns XML representation of parameters (empty if no parameters)
fn (mut p Parser) parse_parameter_list() string {
	return p.wrap_block('parameterList', fn [mut p] () string {
		mut result := ''
		if p.peek() != ')' {
			result += p.parse_type()
			result += p.wrap('identifier', p.advance())
			for p.peek() == ',' {
				result += p.wrap('symbol', p.advance())
				result += p.parse_type()
				result += p.wrap('identifier', p.advance())
			}
		}
		return result
	})
}

// parse_subroutine_body processes the implementation block of a subroutine
// Includes local variables and statements
fn (mut p Parser) parse_subroutine_body() string {
	return p.wrap_block('subroutineBody', fn [mut p] () string {
		mut result := ''
		result += p.wrap('symbol', p.eat('{'))
		for p.peek() == 'var' {
			result += p.parse_var_dec()
		}
		result += p.parse_statements()
		result += p.wrap('symbol', p.eat('}'))
		return result
	})
}

// parse_var_dec handles local variable declarations within a subroutine
fn (mut p Parser) parse_var_dec() string {
	return p.wrap_block('varDec', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.eat('var'))
		result += p.parse_type()
		result += p.wrap('identifier', p.advance())
		for p.peek() == ',' {
			result += p.wrap('symbol', p.advance())
			result += p.wrap('identifier', p.advance())
		}
		result += p.wrap('symbol', p.eat(';'))
		return result
	})
}

// parse_statements processes a sequence of Jack statements
// Handles let, if, while, do and return statements
fn (mut p Parser) parse_statements() string {
	return p.wrap_block('statements', fn [mut p] () string {
		mut result := ''
		for p.peek() in ['let', 'if', 'while', 'do', 'return'] {
			if p.peek() == 'let' {
				result += p.parse_let()
			} else if p.peek() == 'if' {
				result += p.parse_if()
			} else if p.peek() == 'while' {
				result += p.parse_while()
			} else if p.peek() == 'do' {
				result += p.parse_do()
			} else if p.peek() == 'return' {
				result += p.parse_return()
			}
		}
		return result
	})
}

// parse_let processes variable assignment statements
// Handles both simple assignments and array assignments
fn (mut p Parser) parse_let() string {
	return p.wrap_block('letStatement', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.eat('let'))
		result += p.wrap('identifier', p.advance())
		if p.peek() == '[' {
			result += p.wrap('symbol', p.advance())
			result += p.parse_expression()
			result += p.wrap('symbol', p.eat(']'))
		}
		result += p.wrap('symbol', p.eat('='))
		result += p.parse_expression()
		result += p.wrap('symbol', p.eat(';'))
		return result
	})
}

// parse_if handles if and if-else conditional statements
// Includes condition and both true/false statement blocks
fn (mut p Parser) parse_if() string {
	return p.wrap_block('ifStatement', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.eat('if'))
		result += p.wrap('symbol', p.eat('('))
		result += p.parse_expression()
		result += p.wrap('symbol', p.eat(')'))
		result += p.wrap('symbol', p.eat('{'))
		result += p.parse_statements()
		result += p.wrap('symbol', p.eat('}'))
		if p.peek() == 'else' {
			result += p.wrap('keyword', p.advance())
			result += p.wrap('symbol', p.eat('{'))
			result += p.parse_statements()
			result += p.wrap('symbol', p.eat('}'))
		}
		return result
	})
}

// parse_while processes while loop statements
// Includes condition and loop body
fn (mut p Parser) parse_while() string {
	return p.wrap_block('whileStatement', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.eat('while'))
		result += p.wrap('symbol', p.eat('('))
		result += p.parse_expression()
		result += p.wrap('symbol', p.eat(')'))
		result += p.wrap('symbol', p.eat('{'))
		result += p.parse_statements()
		result += p.wrap('symbol', p.eat('}'))
		return result
	})
}

// parse_do handles subroutine call statements
fn (mut p Parser) parse_do() string {
	return p.wrap_block('doStatement', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.eat('do'))
		result += p.parse_subroutine_call()
		result += p.wrap('symbol', p.eat(';'))
		return result
	})
}

// parse_return processes return statements
// Handles both void returns and returns with expressions
fn (mut p Parser) parse_return() string {
	return p.wrap_block('returnStatement', fn [mut p] () string {
		mut result := ''
		result += p.wrap('keyword', p.eat('return'))
		if p.peek() != ';' {
			result += p.parse_expression()
		}
		result += p.wrap('symbol', p.eat(';'))
		return result
	})
}

// parse_expression handles expressions including operators
// Supports arithmetic, comparison and logical operations
fn (mut p Parser) parse_expression() string {
	return p.wrap_block('expression', fn [mut p] () string {
		mut res := p.parse_term()
		for p.peek() in ['+', '-', '*', '/', '&', '|', '<', '>', '='] {
			res += p.wrap('symbol', xml_escape(p.advance()))
			res += p.parse_term()
		}
		return res
	})
}

// parse_term processes individual terms within expressions
// Handles constants, variables, array access, and nested expressions
fn (mut p Parser) parse_term() string {
	return p.wrap_block('term', fn [mut p] () string {
		mut result := ''
		token := p.peek()
		if token == '(' {
			result += p.wrap('symbol', p.advance())
			result += p.parse_expression()
			result += p.wrap('symbol', p.eat(')'))
		} else if token in ['-', '~'] {
			result += p.wrap('symbol', p.advance())
			result += p.parse_term()
		} else if classify_token(token) in ['integerConstant', 'stringConstant'] || token in ['true', 'false', 'null', 'this'] {
			result += p.wrap(classify_token(token), xml_escape(p.advance()))
		} else {
			if p.peek_ahead(1) == '(' || p.peek_ahead(1) == '.' {
				result += p.parse_subroutine_call()
			} else {
				result += p.wrap('identifier', p.advance())
				if p.peek() == '[' {
					result += p.wrap('symbol', p.advance())
					result += p.parse_expression()
					result += p.wrap('symbol', p.eat(']'))
				}
			}
		}
		return result
	})
}

// parse_expression_list handles comma-separated expressions
// Used for subroutine call arguments
fn (mut p Parser) parse_expression_list() string {
	return p.wrap_block('expressionList', fn [mut p] () string {
		mut result := ''
		if p.peek() != ')' {
			result += p.parse_expression()
			for p.peek() == ',' {
				result += p.wrap('symbol', p.advance())
				result += p.parse_expression()
			}
		}
		return result
	})
}

// parse_subroutine_call processes method and function calls
// Supports both object methods (obj.method()) and static functions
fn (mut p Parser) parse_subroutine_call() string {
	mut result := ''
	result += p.wrap('identifier', p.advance())
	if p.peek() == '.' {
		result += p.wrap('symbol', p.advance())
		result += p.wrap('identifier', p.advance())
	}
	result += p.wrap('symbol', p.eat('('))
	result += p.parse_expression_list()
	result += p.wrap('symbol', p.eat(')'))
	return result
}

// peek_ahead looks at tokens beyond the current position
// n: number of tokens to look ahead
// Returns empty string if beyond token list bounds
fn (p Parser) peek_ahead(n int) string {
	if p.index + n < p.tokens.len {
		return p.tokens[p.index + n]
	}
	return ''
}
