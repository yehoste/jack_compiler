//yehoshua steinitz 329114573
//eliel monfort 328269121

module main

import os

fn main() {
	// check if exactly one argument is passed
	if os.args.len != 2 {
        eprintln('Usage: VMTranslator <file_path>')
        return
    }
    
    file_path := os.args[1]
    
    // check if file exists
    if !os.exists(file_path) {
        eprintln('Error: File "$file_path" not found.')
        return
    }

    // initialize parser
    mut parser := new_parser(file_path) or {
        eprintln('Error reading file "$file_path".')
        return
    }
    
    // prepare output file path and code writer
    output_file := file_path.replace('.vm', '.asm')
    mut writer := new_code_writer(output_file) or {
        eprintln('Error opening output file "$output_file".')
        return
    }

	// translate each VM command to assembly
	for parser.has_more_lines() {
		parser.advance()
		ct := parser.command_type()
		if ct == .c_arithmetic {
			writer.write_arithmetic(parser.arg1())
		} else if ct == .c_push || ct == .c_pop {
			writer.write_push_pop(ct.str(), parser.arg1(), parser.arg2())
		}
	}

	writer.close()
	println("Translation complete -> $output_file")
}

