module main

import os

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

// Now returns !Parser so we can `?` on file errors
pub fn new_parser(file_path string) !Parser {
	lines := os.read_lines(file_path)!
	return Parser{
		lines: lines
		current_index: -1
	}
}

pub fn (p Parser) has_more_lines() bool {
	for i := p.current_index + 1; i < p.lines.len; i++ {
		line := p.lines[i].all_before('//').trim_space()
		if line != '' {
			return true
		}
	}
	return false
}

pub fn (mut p Parser) advance() {
	for {
		p.current_index++
		if p.current_index >= p.lines.len {
			p.current_line = ''
			return
		}
		line := p.lines[p.current_index].all_before('//').trim_space()
		if line != '' {
			p.current_line = line
			return
		}
	}
}

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

pub fn (p Parser) arg1() string {
	ct := p.command_type()
	toks := p.current_line.split(' ')
	return match ct {
		.c_arithmetic { toks[0] }
		.c_push, .c_pop { if toks.len > 1 { toks[1] } else { '' } }
		else { '' }
	}
}

pub fn (p Parser) arg2() int {
	ct := p.command_type()
	toks := p.current_line.split(' ')
	if (ct == .c_push || ct == .c_pop) && toks.len > 2 {
		return toks[2].int()
	}
	return 0
}
