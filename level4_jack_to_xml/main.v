import os

fn main() {
    if os.args.len < 2 {
        println('Usage: ./jackc <path-to-folder>')
        return
    }

    folder := os.args[1]
    files := os.ls(folder) or {
        println('Failed to list folder')
        return
    }

    for file in files {
        if file.ends_with('.jack') {
            full_path := os.join_path(folder, file)
            println('Processing $file ...')
            content := os.read_file(full_path) or {
                println('Could not read $file')
                continue
            }

            // --- Tokenizing ---
            mut tokenizer := Tokenizer{
                source: content
            }
            tokenizer.tokenize()
            tokenized_xml := tokenizer.to_xml()
            os.write_file(os.join_path(folder, file.replace('.jack', 'T.xml')), tokenized_xml) or {
                println('Failed to write T.xml for $file')
            }

            // --- Parsing ---
            mut parser := Parser{
                tokens: tokenizer.tokens
            }
            parsed_xml := parser.parse_class()
            os.write_file(os.join_path(folder, file.replace('.jack', '.xml')), parsed_xml) or {
                println('Failed to write .xml for $file')
            }
        }
    }
}
