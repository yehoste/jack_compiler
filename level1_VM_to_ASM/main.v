//yehoshua steinitz 329114573
//eliel monfort 328269121

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

    // Optional: writer.write_init()

    files := os.ls(dir_path) or {
        eprintln('Error: Failed to list contents of "$dir_path".')
        return
    }

    for file in files {
        if file.ends_with('.vm') {
            vm_path := os.join_path(dir_path, file)

            mut parser := new_parser(vm_path) or {
                eprintln('Error reading file "$vm_path". Skipping...')
                continue
            }

            // Optional: set file context for static or label handling
            // writer.set_file_name(file)

            for parser.has_more_lines() {
                parser.advance()
                ct := parser.command_type()
                if ct == .c_arithmetic {
                    writer.write_arithmetic(parser.arg1())
                } else if ct == .c_push || ct == .c_pop {
                    writer.write_push_pop(ct.str(), parser.arg1(), parser.arg2())
                }
                // Add additional command types if needed
            }
        }
    }

    writer.close()
    println("Translation complete -> $output_file")
}


