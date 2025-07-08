import os

fn remove_comments(source string) string {
	mut cleaned := ''
	mut i := 0
	for i < source.len {
		// Single-line comment //
		if source[i..].starts_with('//') {
			for i < source.len && source[i] != `\n` {
				i++
			}
		}
		// Multi-line comment /* ... */
		else if source[i..].starts_with('/*') {
			i += 2
			for i + 1 < source.len && !(source[i] == `*` && source[i + 1] == `/`) {
				i++
			}
			i += 2 // skip closing */
		} else {
			c := source[i]
			cleaned += c.ascii_str()
			i++
		}
	}
	return cleaned
}

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

			// --- Remove comments ---
			clean_source := remove_comments(content)

			// --- Tokenizing ---
			mut tokenizer := Tokenizer{
				source: clean_source
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
			os.write_file(os.join_path(folder, file.replace('.jack', '.vm')), parsed_xml) or {
				println('Failed to write .xml for $file')
			}
		}
	}
}
