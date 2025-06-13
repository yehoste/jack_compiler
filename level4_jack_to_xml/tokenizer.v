module main

struct Tokenizer {
    source string
    mut:
        tokens []string
}

fn (mut t Tokenizer) tokenize() {
    separators := ['(', ')', '{', '}', '[', ']', ';', '.', ',', '=', '+', '-', '*', '/', '&', '|', '<', '>', '~']
    mut word := ''
    mut in_string := false

    for i := 0; i < t.source.len; i++ {
        ch := t.source[i].ascii_str()

        if ch == '"' {
            if in_string {
                word += '"'
                t.tokens << word
                word = ''
                in_string = false
            } else {
                if word != '' {
                    t.tokens << word
                    word = ''
                }
                word += '"'
                in_string = true
            }
        } else if in_string {
            word += ch
        } else if ch in [' ', '\n', '\r', '\t'] {
            if word != '' {
                t.tokens << word
                word = ''
            }
        } else if ch in separators {
            if word != '' {
                t.tokens << word
                word = ''
            }
            t.tokens << ch
        } else {
            word += ch
        }
    }

    if word != '' {
        t.tokens << word
    }
}



fn (t Tokenizer) to_xml() string {
    mut result := '<tokens>\n'
    for token in t.tokens {
        token_type := classify_token(token)
        xml_token := xml_escape(token)
        result += '  <$token_type> $xml_token </$token_type>\n'
    }
    result += '</tokens>\n'
    return result
}

fn classify_token(token string) string {
    keywords := ['class', 'constructor', 'function', 'method', 'field', 'static', 'var', 'int', 'char', 'boolean', 'void',
        'true', 'false', 'null', 'this', 'let', 'do', 'if', 'else', 'while', 'return']
    symbols := ['{', '}', '(', ')', '[', ']', '.', ',', ';', '+', '-', '*', '/', '&', '|', '<', '>', '=', '~']

    if token in keywords {
        return 'keyword'
    } else if token in symbols {
        return 'symbol'
    } else if token.starts_with('"') {
        return 'stringConstant'
    } else if token[0].is_digit() {
        return 'integerConstant'
    } else {
        return 'identifier'
    }
}

fn xml_escape(token string) string {
    return token.replace_each(['&', '&amp;', '<', '&lt;', '>', '&gt;'])
}
