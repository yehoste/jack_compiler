module main

import os

fn main() {
	if os.args.len != 2 {
		eprintln('Usage: VMTranslator <directory_path>')
		return
	}

	dir_path := os.args[1]
	if !os.is_dir(dir_path) {
		eprintln('Error: "$dir_path" is not a directory.')
		return
	}

	dir_name := os.file_name(dir_path)
	output_file := os.join_path(dir_path, "${dir_name}.asm")

	mut writer := new_code_writer(output_file) or {
		eprintln('Error opening output file "$output_file".')
		return
	}

	files := os.ls(dir_path) or {
		eprintln('Error listing "$dir_path".')
		return
	}

	vm_files := files.filter(it.ends_with('.vm'))
	has_sys := vm_files.any(it == 'Sys.vm')

	if vm_files.len > 1 && has_sys {
		writer.write_init()
	}

	for file in vm_files {
		vm_path := os.join_path(dir_path, file)
		mut parser := new_parser(vm_path) or {
			eprintln('Error reading "$vm_path". Skipping...')
			continue
		}
		writer.set_file_name(file)
		for parser.has_more_lines() {
			parser.advance()
			ct := parser.command_type()
			match ct {
				.c_arithmetic {
					writer.write_arithmetic(parser.arg1())
				}
				.c_push, .c_pop {
					writer.write_push_pop(ct, parser.arg1(), parser.arg2())
				}
				.c_label {
					writer.write_label(parser.arg1())
				}
				.c_goto {
					writer.write_goto(parser.arg1())
				}
				.c_if {
					writer.write_if(parser.arg1())
				}
				.c_function {
					writer.write_function(parser.arg1(), parser.arg2())
				}
				.c_call {
					writer.write_call(parser.arg1(), parser.arg2())
				}
				.c_return {
					writer.write_return()
				}
				else {}
			}
		}
	}

	writer.close()
	println("Translation complete -> $output_file")
}
