//yehoshua steinitz 329114573
//eliel monfort 328269121

module main

import os

// Handles writing assembly code
struct CodeWriter {
mut:
	file      os.File
	label_cnt int // counter for generating unique labels
}

// create a new CodeWriter
pub fn new_code_writer(path string) !CodeWriter {
	f := os.create(path)!
	return CodeWriter{
		file: f
	}
}

// write arithmetic operation to file
pub fn (mut cw CodeWriter) write_arithmetic(command string) {
	match command {
		'add', 'sub', 'and', 'or' {
			op := match command {
				'add' { '+' }
				'sub' { '-' }
				'and' { '&' }
				'or'  { '|' }
				else { '' }
			}
			cw.write_lines([
				'@SP', 'AM=M-1', 'D=M',       // pop top of stack into D
				'A=A-1', 'M=M${op}D'          // perform operation and store result
			])
		}
		'neg', 'not' {
			op := if command == 'neg' { '-' } else { '!' }
			cw.write_lines(['@SP', 'A=M-1', 'M=${op}M']) // apply op to top of stack
		}
		'eq', 'gt', 'lt' {
			jmp := match command {
				'eq' { 'JEQ' }
				'gt' { 'JGT' }
				'lt' { 'JLT' }
				else { '' }
			}
			label_true := 'TRUE${cw.label_cnt}'
			label_end := 'END${cw.label_cnt}'
			cw.label_cnt++
			cw.write_lines([
				'@SP', 'AM=M-1', 'D=M',
				'A=A-1', 'D=M-D',                 // compare top two values
				"@${label_true}", "D;${jmp}",     // jump if condition is true
				'@SP', 'A=M-1', 'M=0',            // false case (0)
				"@${label_end}", '0;JMP',         // jump to end
				"(${label_true})",
				'@SP', 'A=M-1', 'M=-1',           // true case (-1)
				"(${label_end})"
			])
		}
		else {}
	}
}

// write push or pop command
pub fn (mut cw CodeWriter) write_push_pop(command string, segment string, index int) {
	match command {
		'c_push' {
			match segment {
				'constant' {
					cw.write_lines([
						"@${index}", 'D=A',
						'@SP', 'A=M', 'M=D',
						'@SP', 'M=M+1'
					])
				}
				'local', 'argument', 'this', 'that' {
					base := match segment {
						'local' { 'LCL' }
						'argument' { 'ARG' }
						'this' { 'THIS' }
						'that' { 'THAT' }
						else { '' }
					}
					cw.write_lines([
						"@${index}", 'D=A',
						"@${base}", 'A=M+D', 'D=M',
						'@SP', 'A=M', 'M=D',
						'@SP', 'M=M+1'
					])
				}
				'temp' {
					addr := 5 + index
					cw.write_lines([
						"@${addr}", 'D=M',
						'@SP', 'A=M', 'M=D',
						'@SP', 'M=M+1'
					])
				}
				'pointer' {
					ptr := if index == 0 { 'THIS' } else { 'THAT' }
					cw.write_lines([
						"@${ptr}", 'D=M',
						'@SP', 'A=M', 'M=D',
						'@SP', 'M=M+1'
					])
				}
				'static' {
					cw.write_lines([
						"@Static.${index}", 'D=M',
						'@SP', 'A=M', 'M=D',
						'@SP', 'M=M+1'
					])
				}
				else {}
			}
		}
		'c_pop' {
			match segment {
				'local', 'argument', 'this', 'that' {
					base := match segment {
						'local' { 'LCL' }
						'argument' { 'ARG' }
						'this' { 'THIS' }
						'that' { 'THAT' }
						else { '' }
					}
					cw.write_lines([
						"@${index}", 'D=A',
						"@${base}", 'D=M+D',
						'@R13', 'M=D',                    // store target address in R13
						'@SP', 'AM=M-1', 'D=M',           // pop stack to D
						'@R13', 'A=M', 'M=D'              // store D into calculated address
					])
				}
				'temp' {
					addr := 5 + index
					cw.write_lines([
						'@SP', 'AM=M-1', 'D=M',
						"@${addr}", 'M=D'
					])
				}
				'pointer' {
					ptr := if index == 0 { 'THIS' } else { 'THAT' }
					cw.write_lines([
						'@SP', 'AM=M-1', 'D=M',
						"@${ptr}", 'M=D'
					])
				}
				'static' {
					cw.write_lines([
						'@SP', 'AM=M-1', 'D=M',
						"@Static.${index}", 'M=D'
					])
				}
				else {}
			}
		}
		else {}
	}
}

// helper to write multiple lines to file
fn (mut cw CodeWriter) write_lines(lines []string) {
	for line in lines {
		cw.file.writeln(line) or { panic(err) }
	}
}

// close output file
pub fn (mut cw CodeWriter) close() {
	cw.file.close()
}
