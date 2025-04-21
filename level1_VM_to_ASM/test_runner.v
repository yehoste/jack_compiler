module main

fn main() {
	input  := "EqGtLtTest.vm"
	output := "EqGtLtTest.asm"

	mut parser := new_parser(input)!      // bang on error
	mut writer := new_code_writer(output)!

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
	println("Translation complete ▶ $output")
}
