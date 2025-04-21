//yehoshua steinitz 329114573
//eliel monfort 328269121

module main

import os

// VM command types
pub enum CommandType {
	c_arithmetic
	c_push
	c_pop
	c_none
}

pub struct Parser {
pub mut:
	lines         []string
	current_line  string
	current_index int
}

// create parser from file
pub fn new_parser(file_path string) !Parser {
	lines := os.read_lines(file_path)!
	return Parser{
		lines: lines
		current_index: -1
	}
}

// check if more lines exist
pub fn (p Parser) has_more_lines() bool {
	for i := p.current_index + 1; i < p.lines.len; i++ {
		line := p.lines[i].all_before('//').trim_space()	//chack if its a comment and remove it
		if line != '' {
			return true
		}
	}
	return false
}

// move to next valid line
pub fn (mut p Parser) advance() {
	for {
		p.current_index++
		if p.current_index >= p.lines.len {
			p.current_line = ''
			return
		}
		line := p.lines[p.current_index].all_before('//').trim_space()	//chack if its a comment and remove it
		if line != '' {
			p.current_line = line
			return
		}
	}
}

// get command type from current line
pub fn (p Parser) command_type() CommandType {
	toks := p.current_line.split(' ')
	if toks.len == 0 {
		return .c_none
	}
	match toks[0] {
		'push' { return .c_push }
		'pop'  { return .c_pop }
		'add', 'sub', 'neg', 'eq', 'gt', 'lt', 'and', 'or', 'not' {
			return .c_arithmetic
		}
		else { return .c_none }
	}
}

// get first argument
pub fn (p Parser) arg1() string {
	ct := p.command_type()
	toks := p.current_line.split(' ')
	return match ct {
		.c_arithmetic { toks[0] }
		.c_push, .c_pop { if toks.len > 1 { toks[1] } else { '' } }
		else { '' }
	}
}

// get second argument (only for push/pop)
pub fn (p Parser) arg2() int {
	ct := p.command_type()
	toks := p.current_line.split(' ')
	if (ct == .c_push || ct == .c_pop) && toks.len > 2 {
		return toks[2].int()
	}
	return 0
}

