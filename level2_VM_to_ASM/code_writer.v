module main

import os

struct CodeWriter {
mut:
	file        os.File
	label_cnt   int
	current_file string
}

pub fn new_code_writer(path string) !CodeWriter {
	f := os.create(path)!
	return CodeWriter{
		file: f
	}
}

pub fn (mut cw CodeWriter) set_file_name(file string) {
	cw.current_file = file.all_before_last('.')
}

pub fn (mut cw CodeWriter) write_init() {
	cw.write_lines([
		'@256', 'D=A',
		'@SP', 'M=D'
	])
	cw.write_call('Sys.init', 0)
}

pub fn (mut cw CodeWriter) write_arithmetic(command string) {
	match command {
		'add', 'sub', 'and', 'or' {
			op := match command {
				'add' { '+' }
				'sub' { '-' }
				'and' { '&' }
				'or' { '|' }
				else { '' }
			}
			cw.write_lines([
				'@SP', 'AM=M-1', 'D=M',
				'A=A-1', 'M=M${op}D'
			])
		}
		'neg', 'not' {
			op := if command == 'neg' { '-' } else { '!' }
			cw.write_lines(['@SP', 'A=M-1', 'M=${op}M'])
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
				'A=A-1', 'D=M-D',
				"@${label_true}", "D;${jmp}",
				'@SP', 'A=M-1', 'M=0',
				"@${label_end}", '0;JMP',
				"(${label_true})",
				'@SP', 'A=M-1', 'M=-1',
				"(${label_end})"
			])
		}
		else {}
	}
}

pub fn (mut cw CodeWriter) write_push_pop(command CommandType, segment string, index int) {
	match command {
		.c_push {
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
						"@${cw.current_file}.${index}", 'D=M',
						'@SP', 'A=M', 'M=D',
						'@SP', 'M=M+1'
					])
				}
				else {}
			}
		}
		.c_pop {
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
						'@R13', 'M=D',
						'@SP', 'AM=M-1', 'D=M',
						'@R13', 'A=M', 'M=D'
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
						"@${cw.current_file}.${index}", 'M=D'
					])
				}
				else {}
			}
		}
		else {}
	}
}

pub fn (mut cw CodeWriter) write_label(label string) {
	cw.write_lines(["(${cw.current_file}$${label})"])
}

pub fn (mut cw CodeWriter) write_goto(label string) {
	cw.write_lines(["@${cw.current_file}$${label}", "0;JMP"])
}

pub fn (mut cw CodeWriter) write_if(label string) {
	cw.write_lines([
		'@SP', 'AM=M-1', 'D=M',
		"@${cw.current_file}$${label}", 'D;JNE'
	])
}

pub fn (mut cw CodeWriter) write_function(name string, nlocals int) {
	cw.write_lines(["(${name})"])
	for _ in 0 .. nlocals {
		cw.write_push_pop(.c_push, 'constant', 0)
	}
}

pub fn (mut cw CodeWriter) write_call(name string, nargs int) {
	return_label := "RETURN${cw.label_cnt}"
	cw.label_cnt++
	cw.write_lines([
		"@${return_label}", 'D=A', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1',
		'@LCL', 'D=M', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1',
		'@ARG', 'D=M', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1',
		'@THIS', 'D=M', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1',
		'@THAT', 'D=M', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1',
		"@${nargs}", 'D=A', '@5', 'D=D+A', '@SP', 'D=M-D', '@ARG', 'M=D',
		'@SP', 'D=M', '@LCL', 'M=D',
		"@${name}", '0;JMP',
		"(${return_label})"
	])
}

pub fn (mut cw CodeWriter) write_return() {
	cw.write_lines([
		'@LCL', 'D=M', '@R13', 'M=D',
		'@5', 'A=D-A', 'D=M', '@R14', 'M=D',
		'@SP', 'AM=M-1', 'D=M', '@ARG', 'A=M', 'M=D',
		'@ARG', 'D=M+1', '@SP', 'M=D',
		'@R13', 'AM=M-1', 'D=M', '@THAT', 'M=D',
		'@R13', 'AM=M-1', 'D=M', '@THIS', 'M=D',
		'@R13', 'AM=M-1', 'D=M', '@ARG', 'M=D',
		'@R13', 'AM=M-1', 'D=M', '@LCL', 'M=D',
		'@R14', 'A=M', '0;JMP'
	])
}

fn (mut cw CodeWriter) write_lines(lines []string) {
	for line in lines {
		cw.file.writeln(line) or { panic(err) }
	}
}

pub fn (mut cw CodeWriter) close() {
	cw.file.close()
}
