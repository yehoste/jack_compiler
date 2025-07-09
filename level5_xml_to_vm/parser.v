module main

struct VarInfo {
    segment string
    index   int
}

struct Parser {
    tokens []string
    mut:
        index        int
        class_name   string
        output       string
        label_index  int
        local_count  int
        arg_count    int
        field_count  int
        static_count int
        var_map      map[string]VarInfo
}

fn (mut p Parser) peek() string {
    return if p.index < p.tokens.len { p.tokens[p.index] } else { '' }
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
    kind := p.advance() // static or field
    _ = p.advance()     // type
    name := p.advance()
    seg := if kind == 'static' { 'static' } else { 'this' }
    count := if kind == 'static' { &p.static_count } else { &p.field_count }
    p.var_map[name] = VarInfo{ segment: seg, index: *count }
    (*count)++
    for p.peek() == ',' {
        p.advance()
        name2 := p.advance()
        p.var_map[name2] = VarInfo{ segment: seg, index: *count }
        (*count)++
    }
    p.eat(';')
}

fn (mut p Parser) parse_subroutine() {
    _ = p.advance() // constructor/function/method
    _ = p.advance() // return type
    sub_name := p.advance()
    p.eat('(')

    p.arg_count = 0
    p.local_count = 0
    p.var_map.clear()

    p.parse_parameter_list()
    p.eat(')')

    p.eat('{')
    for p.peek() == 'var' {
        p.parse_var_dec()
    }

    p.write('function ${p.class_name}.$sub_name $p.local_count')
    p.parse_statements()
    p.eat('}')
}

fn (mut p Parser) parse_parameter_list() {
    if p.peek() != ')' {
        _ = p.advance() // type
        name := p.advance()
        p.var_map[name] = VarInfo{ segment: 'argument', index: p.arg_count }
        p.arg_count++
        for p.peek() == ',' {
            p.advance()
            _ = p.advance() // type
            name2 := p.advance()
            p.var_map[name2] = VarInfo{ segment: 'argument', index: p.arg_count }
            p.arg_count++
        }
    }
}

fn (mut p Parser) parse_var_dec() {
    p.eat('var')
    _ = p.advance() // type
    name := p.advance()
    p.var_map[name] = VarInfo{ segment: 'local', index: p.local_count }
    p.local_count++
    for p.peek() == ',' {
        p.advance()
        name2 := p.advance()
        p.var_map[name2] = VarInfo{ segment: 'local', index: p.local_count }
        p.local_count++
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
        vi := p.var_index(var_name)
        p.write('push ${vi.segment} ${vi.index}')
        p.write('add')
    }
    p.eat('=')
    p.parse_expression()
    p.eat(';')
    if is_array {
        p.write('pop temp 0')
        p.write('pop pointer 1')
        p.write('push temp 0')
        p.write('pop that 0')
    } else {
        vi := p.var_index(var_name)
        p.write('pop ${vi.segment} ${vi.index}')
    }
}

fn (mut p Parser) parse_if() {
    p.eat('if')
    p.eat('(')
    p.parse_expression()
    p.eat(')')
    t := 'IF_TRUE${p.label_index}'
    f := 'IF_FALSE${p.label_index}'
    end := 'IF_END${p.label_index}'
    p.label_index++
    p.write('if-goto $t')
    p.write('goto $f')
    p.write('label $t')
    p.eat('{')
    p.parse_statements()
    p.eat('}')
    if p.peek() == 'else' {
        p.write('goto $end')
        p.write('label $f')
        p.eat('else')
        p.eat('{')
        p.parse_statements()
        p.eat('}')
        p.write('label $end')
    } else {
        p.write('label $f')
    }
}

fn (mut p Parser) parse_while() {
    exp := 'WHILE_EXP${p.label_index}'
    end := 'WHILE_END${p.label_index}'
    p.label_index++
    p.write('label $exp')
    p.eat('while')
    p.eat('(')
    p.parse_expression()
    p.eat(')')
    p.write('not')
    p.write('if-goto $end')
    p.eat('{')
    p.parse_statements()
    p.eat('}')
    p.write('goto $exp')
    p.write('label $end')
}

fn (mut p Parser) parse_do() {
    p.eat('do')
    p.parse_subroutine_call()
    p.eat(';')
    p.write('pop temp 0')
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
    } else if token.len >= 2 && token[0] == `"` && token[token.len - 1] == `"` {
        str := p.advance()[1..token.len - 1]
        p.write('push constant ${str.len}')
        p.write('call String.new 1')
        for ch in str.runes() {
            p.write('push constant ${int(ch)}')
            p.write('call String.appendChar 2')
        }
    } else if token in ['true'] {
        _ = p.advance()
        p.write('push constant 0')
        p.write('not')
    } else if token in ['false', 'null'] {
        _ = p.advance()
        p.write('push constant 0')
    } else {
        name := p.advance()
        if p.peek() == '[' {
            p.eat('[')
            p.parse_expression()
            p.eat(']')
            vi := p.var_index(name)
            p.write('push ${vi.segment} ${vi.index}')
            p.write('add')
            p.write('pop pointer 1')
            p.write('push that 0')
        } else if p.peek() in ['(', '.'] {
            p.index--
            p.parse_subroutine_call()
        } else {
            vi := p.var_index(name)
            p.write('push ${vi.segment} ${vi.index}')
        }
    }
}

fn (mut p Parser) parse_subroutine_call() {
    name := p.advance()
    mut full_name := ''
    mut arg_count := 0
    if p.peek() == '.' {
        p.eat('.')
        method := p.advance()
        full_name = name + '.' + method
    } else {
        full_name = p.class_name + '.' + name
    }
    p.eat('(')
    arg_count += p.parse_expression_list()
    p.eat(')')
    p.write('call $full_name $arg_count')
}

fn (mut p Parser) parse_expression_list() int {
    mut count := 0
    if p.peek() != ')' {
        p.parse_expression()
        count++
        for p.peek() == ',' {
            p.advance()
            p.parse_expression()
            count++
        }
    }
    return count
}

fn (p Parser) var_index(name string) VarInfo {
    if name in p.var_map {
        return p.var_map[name]
    }
    println('--- CURRENT VARIABLES ---')
    for k, v in p.var_map {
        println('$k => $v')
    }
    panic('Unknown variable: $name')
}

fn is_integer(s string) bool {
    return s.len > 0 && s[0].is_digit()
}
