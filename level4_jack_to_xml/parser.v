module main

struct Parser {
    tokens []string
    mut:
        index int
}

fn (mut p Parser) peek() string {
    return if p.index < p.tokens.len { p.tokens[p.index] } else { '' }
}

fn (mut p Parser) advance() string {
    token := p.peek()
    p.index++
    return token
}

fn (mut p Parser) eat(expected string) string {
    token := p.advance()
    if token != expected {
        println('Error: expected "$expected" but got "$token"')
    }
    return token
}

fn (mut p Parser) parse_class() string {
    mut result := '<class>\n'
    result += p.wrap('keyword', p.eat('class'))
    result += p.wrap('identifier', p.advance()) // class name
    result += p.wrap('symbol', p.eat('{'))

    // subroutine declarations
    for p.peek() == 'function' || p.peek() == 'constructor' || p.peek() == 'method' {
        result += p.parse_subroutine()
    }

    result += p.wrap('symbol', p.eat('}'))
    result += '</class>\n'
    return result
}

fn (mut p Parser) parse_subroutine() string {
    mut result := '<subroutineDec>\n'
    result += p.wrap('keyword', p.advance()) // function / method
    result += p.wrap('keyword', p.advance()) // return type
    result += p.wrap('identifier', p.advance()) // subroutine name
    result += p.wrap('symbol', p.eat('('))
    result += p.parse_parameter_list()
    result += p.wrap('symbol', p.eat(')'))
    result += p.parse_subroutine_body()
    result += '</subroutineDec>\n'
    return result
}

fn (mut p Parser) parse_parameter_list() string {
    mut result := '<parameterList>\n'
    for p.peek() != ')' && p.peek() != '' {
        result += p.wrap('keyword', p.advance()) // type
        result += p.wrap('identifier', p.advance()) // varName
        if p.peek() == ',' {
            result += p.wrap('symbol', p.eat(','))
        }
    }
    result += '</parameterList>\n'
    return result
}

fn (mut p Parser) parse_subroutine_body() string {
    mut result := '<subroutineBody>\n'
    result += p.wrap('symbol', p.eat('{'))
    result += p.parse_statements()
    result += p.wrap('symbol', p.eat('}'))
    result += '</subroutineBody>\n'
    return result
}

fn (mut p Parser) parse_statements() string {
    mut result := '<statements>\n'
    for p.peek() in ['do', 'return'] {
        if p.peek() == 'do' {
            result += p.parse_do()
        } else if p.peek() == 'return' {
            result += p.parse_return()
        }
    }
    result += '</statements>\n'
    return result
}


fn (mut p Parser) parse_do() string {
    mut result := '<doStatement>\n'
    result += p.wrap('keyword', p.eat('do'))
    result += p.wrap('identifier', p.advance()) // e.g. Output
    result += p.wrap('symbol', p.eat('.'))
    result += p.wrap('identifier', p.advance()) // printString
    result += p.wrap('symbol', p.eat('('))
    result += p.parse_expression_list()
    result += p.wrap('symbol', p.eat(')'))
    result += p.wrap('symbol', p.eat(';'))
    result += '</doStatement>\n'
    return result
}

fn (mut p Parser) parse_return() string {
    mut result := '<returnStatement>\n'
    result += p.wrap('keyword', p.eat('return'))
    if p.peek() != ';' {
        result += p.wrap(classify_token(p.peek()), xml_escape(p.advance()))
    }
    result += p.wrap('symbol', p.eat(';'))
    result += '</returnStatement>\n'
    return result
}

fn (mut p Parser) parse_expression_list() string {
    mut result := '<expressionList>\n'
    if p.peek() != ')' {
        result += p.wrap(classify_token(p.peek()), xml_escape(p.advance()))
    }
    result += '</expressionList>\n'
    return result
}

fn (p Parser) wrap(kind string, value string) string {
    return '  <$kind> $value </$kind>\n'
}
