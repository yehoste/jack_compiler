module main

// Tokenizer splits Jack source code into individual tokens
// and provides functionality to convert them to XML format
struct Tokenizer {
    source string      // Input Jack source code
    mut:
        tokens []string    // Collection of extracted tokens
}

// tokenize splits the source code into individual tokens
// Handles string literals, symbols, keywords, and identifiers
fn (mut t Tokenizer) tokenize() {
    // Define valid separator characters in Jack language
    separators := ['(', ')', '{', '}', '[', ']', ';', '.', ',', '=', '+', '-', '*', '/', '&', '|', '<', '>', '~']
    mut word := ''              // Buffer for building current token
    mut in_string := false      // Flag to track string literal processing

    // Process source code character by character
    for i := 0; i < t.source.len; i++ {
        ch := t.source[i].ascii_str()

        // Handle string literals (text between double quotes)
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
        // Handle whitespace characters
        } else if ch in [' ', '\n', '\r', '\t'] {
            if word != '' {
                t.tokens << word
                word = ''
            }
        // Handle separator symbols
        } else if ch in separators {
            if word != '' {
                t.tokens << word
                word = ''
            }
            t.tokens << ch
        // Build up identifiers and keywords
        } else {
            word += ch
        }
    }

    // Add final token if present
    if word != '' {
        t.tokens << word
    }
}

// to_xml converts the tokenized code into XML format
// Returns a string containing the XML representation
fn (t Tokenizer) to_xml() string {
    mut result := '<tokens>\n'
    for token in t.tokens {
        token_type := classify_token(token)
        xml_token := xml_escape(token)
        result += '<$token_type> $xml_token </$token_type>\n'
    }
    result += '</tokens>\n'
    return result
}

// classify_token determines the token type based on Jack language rules
// Returns one of: keyword, symbol, stringConstant, integerConstant, identifier
fn classify_token(token string) string {
    // Define valid keywords and symbols according to Jack specification
    keywords := ['class', 'constructor', 'function', 'method', 'field', 'static', 'var', 'int', 'char', 'boolean', 'void',
        'true', 'false', 'null', 'this', 'let', 'do', 'if', 'else', 'while', 'return']
    symbols := ['{', '}', '(', ')', '[', ']', '.', ',', ';', '+', '-', '*', '/', '&', '|', '<', '>', '=', '~']

    // Determine token type based on content
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

// xml_escape handles special characters in XML output
// Removes quotes from string literals and escapes XML special characters
fn xml_escape(token string) string {
    if token.starts_with('"') && token.ends_with('"') {
        // Remove the surrounding quotes and trim spaces
        return token[1..token.len-1]
    }
    // Escape special XML characters
    return token.replace_each(['&', '&amp;', '<', '&lt;', '>', '&gt;'])
}

