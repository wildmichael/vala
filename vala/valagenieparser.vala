/* valagenieparser.vala
 *
 * Copyright (C) 2008  Jamie McCracken, Jürg Billeter
 * Based on code by Jürg Billeter
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Jamie McCracken jamiemcc gnome org
 */

using GLib;
using Gee;


/**
 * Code visitor parsing all Genie source files.
 */
public class Vala.Genie.Parser : CodeVisitor {
	Scanner scanner;

	CodeContext context;

	// token buffer
	TokenInfo[] tokens;
	// index of current token in buffer
	int index;
	// number of tokens in buffer
	int size;

	string comment;
	
	string class_name;

	/* hack needed to know if any part of an expression is a lambda one */
	bool current_expr_is_lambda;

	const int BUFFER_SIZE = 32;

	struct TokenInfo {
		public TokenType type;
		public SourceLocation begin;
		public SourceLocation end;
	}

	enum ModifierFlags {
		NONE,
		ABSTRACT = 1 << 0,
		CLASS = 1 << 1,
		EXTERN = 1 << 2,
		INLINE = 1 << 3,
		OVERRIDE = 1 << 4,
		STATIC = 1 << 5,
		VIRTUAL = 1 << 6,
		PRIVATE = 1 << 7
	}

	construct {
		tokens = new TokenInfo[BUFFER_SIZE];
		class_name = null;
		current_expr_is_lambda = false;
	}

	/**
	 * Parses all .gs source files in the specified code context and
	 * builds a code tree.
	 *
	 * @param context a code context
	 */
	public void parse (CodeContext context) {
		this.context = context;
		context.accept (this);
	}

	public override void visit_source_file (SourceFile source_file) {
		if (source_file.filename.has_suffix (".gs")) {
			parse_file (source_file);
		}
	}

	inline bool next () {
		index = (index + 1) % BUFFER_SIZE;
		size--;
		if (size <= 0) {
			SourceLocation begin, end;
			TokenType type = scanner.read_token (out begin, out end);
			tokens[index].type = type;
			tokens[index].begin = begin;
			tokens[index].end = end;
			size = 1;
		}
		return (tokens[index].type != TokenType.EOF);
	}

	inline void prev () {
		index = (index - 1 + BUFFER_SIZE) % BUFFER_SIZE;
		size++;
		assert (size <= BUFFER_SIZE);
	}

	inline TokenType current () {
		return tokens[index].type;
	}

	inline bool accept (TokenType type) {
		if (current () == type) {
			next ();
			return true;
		}
		return false;
	}

	inline bool accept_terminator () {
		if (current () == TokenType.SEMICOLON || current () == TokenType.EOL) {
			next ();
			return true;
		}
		return false;
	}
	
	inline bool accept_block () {
	
		bool has_term = accept_terminator ();

		if (accept (TokenType.INDENT)) {
			prev();
			return true;
		}

		if (has_term) {
			prev ();
		}

		return false;
	}

	string get_error (string msg) {
		var begin = get_location ();
		next ();
		Report.error (get_src (begin), "syntax error, " + msg);
		return msg;
	}

	inline bool expect (TokenType type) throws ParseError {
		if (accept (type)) {
			return true;
		}

		TokenType cur = current ();
		TokenType pre =  tokens[index - 1].type;

		throw new ParseError.SYNTAX (get_error ("expected %s but got %s with previous %s".printf (type.to_string (), cur.to_string (), pre.to_string())));
	}

	inline bool expect_terminator () throws ParseError {
		if (accept_terminator ()) {
			return true;
		}

		TokenType cur = current ();

		throw new ParseError.SYNTAX (get_error ("expected line end or semicolon but got %s".printf (cur.to_string())));
	}

	inline SourceLocation get_location () {
		return tokens[index].begin;
	}

	string get_last_string () {
		int last_index = (index + BUFFER_SIZE - 1) % BUFFER_SIZE;
		return ((string) tokens[last_index].begin.pos).ndup ((tokens[last_index].end.pos - tokens[last_index].begin.pos));
	}

	SourceReference get_src (SourceLocation begin) {
		int last_index = (index + BUFFER_SIZE - 1) % BUFFER_SIZE;

		return new SourceReference (scanner.source_file, begin.line, begin.column, tokens[last_index].end.line, tokens[last_index].end.column);
	}

	SourceReference get_src_com (SourceLocation begin) {
		int last_index = (index + BUFFER_SIZE - 1) % BUFFER_SIZE;

		var src = new SourceReference.with_comment (scanner.source_file, begin.line, begin.column, tokens[last_index].end.line, tokens[last_index].end.column, comment);
		comment = null;
		return src;
	}

	SourceReference get_current_src () {
		return new SourceReference (scanner.source_file, tokens[index].begin.line, tokens[index].begin.column, tokens[index].end.line, tokens[index].end.column);
	}

	SourceReference get_last_src () {
		int last_index = (index + BUFFER_SIZE - 1) % BUFFER_SIZE;

		return new SourceReference (scanner.source_file, tokens[last_index].begin.line, tokens[last_index].begin.column, tokens[last_index].end.line, tokens[last_index].end.column);
	}

	void rollback (SourceLocation location) {
		while (tokens[index].begin.pos != location.pos) {
			prev ();
		}
	}

	inline  SymbolAccessibility get_access (string s) {
		if (s[0] == '_') {
			return SymbolAccessibility.PRIVATE;
		}

		return SymbolAccessibility.PUBLIC;
	}

	void skip_identifier () throws ParseError {
		// also accept keywords as identifiers where there is no conflict
		switch (current ()) {
		case TokenType.ABSTRACT:
		case TokenType.AS:
		case TokenType.ASSERT:
		case TokenType.BREAK:
		case TokenType.CLASS:
		case TokenType.CONST:
		case TokenType.CONTINUE:
		case TokenType.DEDENT:
		case TokenType.DEF:
		case TokenType.DEFAULT:
		case TokenType.DELEGATE:
		case TokenType.DELETE:
		case TokenType.DO:
		case TokenType.DOWNTO:
		case TokenType.DYNAMIC:
		case TokenType.ELSE:
		case TokenType.EOL:
		case TokenType.ENUM:
		case TokenType.ENSURES:
		case TokenType.ERRORDOMAIN:
		case TokenType.EVENT:
		case TokenType.EXCEPT:
		case TokenType.EXTERN:
		case TokenType.FALSE:
		case TokenType.FINAL:
		case TokenType.FINALLY:
		case TokenType.FOR:
		case TokenType.FOREACH:
		case TokenType.GET:
		case TokenType.IDENTIFIER:
		case TokenType.IF:
		case TokenType.IN:
		case TokenType.INDENT:
		case TokenType.INIT:
		case TokenType.INLINE:
		case TokenType.INTERFACE:
		case TokenType.IS:
		case TokenType.ISA:
		case TokenType.LOCK:
		case TokenType.NAMESPACE:
		case TokenType.NEW:
		case TokenType.NULL:
		case TokenType.OF:
		case TokenType.OUT:
		case TokenType.OVERRIDE:
		case TokenType.PASS:
		case TokenType.PRINT:
		case TokenType.PRIVATE:
		case TokenType.PROP:
		case TokenType.RAISE:
		case TokenType.RAISES:
		case TokenType.REF:
		case TokenType.REQUIRES:
		case TokenType.RETURN:
		case TokenType.SET:
		case TokenType.SIZEOF:
		case TokenType.STATIC:
		case TokenType.STRUCT:
		case TokenType.SUPER:
		case TokenType.THIS:
		case TokenType.TO:
		case TokenType.TRUE:
		case TokenType.TRY:
		case TokenType.TYPEOF:
		case TokenType.USES:
		case TokenType.VAR:
		case TokenType.VIRTUAL:
		case TokenType.VOID:
		case TokenType.VOLATILE:
		case TokenType.WEAK:
		case TokenType.WHEN:
		case TokenType.WHILE:
			next ();
			return;
		}

		throw new ParseError.SYNTAX (get_error ("expected identifier"));
	}

	string parse_identifier () throws ParseError {
		skip_identifier ();
		return get_last_string ();
	}

	Expression parse_literal () throws ParseError {
		var begin = get_location ();

		switch (current ()) {
		case TokenType.TRUE:
			next ();
			return new BooleanLiteral (true, get_src (begin));
		case TokenType.FALSE:
			next ();
			return new BooleanLiteral (false, get_src (begin));
		case TokenType.INTEGER_LITERAL:
			next ();
			return new IntegerLiteral (get_last_string (), get_src (begin));
		case TokenType.REAL_LITERAL:
			next ();
			return new RealLiteral (get_last_string (), get_src (begin));
		case TokenType.CHARACTER_LITERAL:
			next ();
			return new CharacterLiteral (get_last_string (), get_src (begin));
		case TokenType.STRING_LITERAL:
			next ();
			return new StringLiteral (get_last_string (), get_src (begin));
		case TokenType.NULL:
			next ();
			return new NullLiteral (get_src (begin));
		}

		throw new ParseError.SYNTAX (get_error ("expected literal"));
	}

	public void parse_file (SourceFile source_file) {
		scanner = new Scanner (source_file);

		index = -1;
		size = 0;
		
		next ();

		try {
			parse_using_directives ();
			parse_declarations (context.root, true);
		} catch (ParseError e) {
			// already reported
		}
		
		scanner = null;
	}

	void skip_symbol_name () throws ParseError {
		do {
			skip_identifier ();
		} while (accept (TokenType.DOT));
	}

	UnresolvedSymbol parse_symbol_name () throws ParseError {
		var begin = get_location ();
		UnresolvedSymbol sym = null;
		do {
			string name = parse_identifier ();
			sym = new UnresolvedSymbol (sym, name, get_src (begin));
		} while (accept (TokenType.DOT));
		return sym;
	}

	void skip_type () throws ParseError {
		if (accept (TokenType.VOID)) {
			while (accept (TokenType.STAR)) {
			}
			return;
		}
		accept (TokenType.DYNAMIC);

		accept (TokenType.WEAK);
		skip_symbol_name ();
		skip_type_argument_list ();
		while (accept (TokenType.OPEN_BRACKET)) {	
			do {
				if (current () != TokenType.COMMA && current () != TokenType.CLOSE_BRACKET) {
					parse_expression ();
				}
			} while (accept (TokenType.COMMA));
			expect (TokenType.CLOSE_BRACKET);
		}
		accept (TokenType.OP_NEG);
		accept (TokenType.INTERR);
		accept (TokenType.HASH);
	}

	DataType parse_type (bool owned_by_default = true) throws ParseError {
		var begin = get_location ();

		if (accept (TokenType.VOID)) {
			DataType type = new VoidType ();
			while (accept (TokenType.STAR)) {
				type = new PointerType (type);
			}
			return type;
		}

		bool is_dynamic = accept (TokenType.DYNAMIC);
		bool value_owned = owned_by_default;
		if (owned_by_default) {
			value_owned = !accept (TokenType.WEAK);
		}

		var sym = parse_symbol_name ();
		Gee.List<DataType> type_arg_list = parse_type_argument_list (false);

		DataType type = new UnresolvedType.from_symbol (sym, get_src (begin));
		if (type_arg_list != null) {
			foreach (DataType type_arg in type_arg_list) {
				type.add_type_argument (type_arg);
			}
		}

		while (accept (TokenType.STAR)) {
			 type = new PointerType (type, get_src (begin));
		}

		if (!(type is PointerType)) {
			type.nullable = accept (TokenType.INTERR);
		}

		while (accept (TokenType.OPEN_BRACKET)) {
			int array_rank = 0;
			do {
				array_rank++;
				// support for stack-allocated arrays
				// also required for decision between expression and declaration statement
				if (current () != TokenType.COMMA && current () != TokenType.CLOSE_BRACKET) {
					parse_expression ();
				}
			}
			while (accept (TokenType.COMMA));
			expect (TokenType.CLOSE_BRACKET);

			type.value_owned = true;
			type = new ArrayType (type, array_rank, get_src (begin));
			type.nullable = accept (TokenType.INTERR);
		}

		if (!owned_by_default) {
			value_owned = accept (TokenType.HASH);
		}

		type.is_dynamic = is_dynamic;
		type.value_owned = value_owned;
		return type;
	}

	Gee.List<Expression> parse_argument_list () throws ParseError {
		var list = new ArrayList<Expression> ();
		if (current () != TokenType.CLOSE_PARENS) {
			do {
				list.add (parse_expression ());
			} while (accept (TokenType.COMMA));
		}
		return list;
	}

	Expression parse_primary_expression () throws ParseError {
		var begin = get_location ();

		Expression expr;

		switch (current ()) {
		case TokenType.TRUE:
		case TokenType.FALSE:
		case TokenType.INTEGER_LITERAL:
		case TokenType.REAL_LITERAL:
		case TokenType.CHARACTER_LITERAL:
		case TokenType.STRING_LITERAL:
		case TokenType.NULL:
			expr = parse_literal ();
			break;
		case TokenType.ASSERT:
			return parse_assert_expression ();	
		case TokenType.OPEN_PARENS:
			expr = parse_tuple ();
			break;
		case TokenType.THIS:
			expr = parse_this_access ();
			break;
		case TokenType.SUPER:
			expr = parse_base_access ();
			break;
		case TokenType.NEW:
			expr = parse_object_or_array_creation_expression ();
			break;
		case TokenType.PRINT:
			return parse_print_expression ();
		case TokenType.SIZEOF:
			expr = parse_sizeof_expression ();
			break;
		case TokenType.TYPEOF:
			expr = parse_typeof_expression ();
			break;
		default:
			expr = parse_simple_name ();
			break;
		}

		if (expr == null) {
			// workaround for current limitation of exception handling
			throw new ParseError.SYNTAX ("syntax error in primary expression");
		}

		// process primary expressions that start with an inner primary expression
		bool found = true;
		while (found) {
			switch (current ()) {
			case TokenType.DOT:
				expr = parse_member_access (begin, expr);
				break;
			case TokenType.OP_PTR:
				expr = parse_pointer_member_access (begin, expr);
				break;
			case TokenType.OPEN_PARENS:
				expr = parse_invocation_expression (begin, expr);
				break;
			case TokenType.OPEN_BRACKET:
				expr = parse_element_access (begin, expr);
				break;
			case TokenType.OP_INC:
				expr = parse_post_increment_expression (begin, expr);
				break;
			case TokenType.OP_DEC:
				expr = parse_post_decrement_expression (begin, expr);
				break;
			
			default:
				found = false;
				break;
			}

			if (expr == null) {
				// workaround for current limitation of exception handling
				throw new ParseError.SYNTAX ("syntax error in primary expression");
			}
		}

		return expr;
	}

	Expression parse_simple_name () throws ParseError {
		var begin = get_location ();
		string id = parse_identifier ();
		Gee.List<DataType> type_arg_list = parse_type_argument_list (true);
		var expr = new MemberAccess (null, id, get_src (begin));
		if (type_arg_list != null) {
			foreach (DataType type_arg in type_arg_list) {
				expr.add_type_argument (type_arg);
			}
		}
		return expr;
	}

	Expression parse_tuple () throws ParseError {
		var begin = get_location ();
		expect (TokenType.OPEN_PARENS);
		var expr_list = new ArrayList<Expression> ();
		if (current () != TokenType.CLOSE_PARENS) {
			do {
				expr_list.add (parse_expression ());
			} while (accept (TokenType.COMMA));
		}
		expect (TokenType.CLOSE_PARENS);
		if (expr_list.size != 1) {
			var tuple = new Tuple ();
			foreach (Expression expr in expr_list) {
				tuple.add_expression (expr);
			}
			return tuple;
		}
		return new ParenthesizedExpression (expr_list.get (0), get_src (begin));
	}

	Expression parse_member_access (SourceLocation begin, Expression inner) throws ParseError {
		expect (TokenType.DOT);
		string id = parse_identifier ();
		Gee.List<DataType> type_arg_list = parse_type_argument_list (true);
		var expr = new MemberAccess (inner, id, get_src (begin));
		if (type_arg_list != null) {
			foreach (DataType type_arg in type_arg_list) {
				expr.add_type_argument (type_arg);
			}
		}
		return expr;
	}

	Expression parse_pointer_member_access (SourceLocation begin, Expression inner) throws ParseError {
		expect (TokenType.OP_PTR);
		string id = parse_identifier ();
		Gee.List<DataType> type_arg_list = parse_type_argument_list (true);
		var expr = new MemberAccess.pointer (inner, id, get_src (begin));
		if (type_arg_list != null) {
			foreach (DataType type_arg in type_arg_list) {
				expr.add_type_argument (type_arg);
			}
		}
		return expr;
	}


	Gee.List<Expression> parse_print_argument_list () throws ParseError {
		var list = new ArrayList<Expression> ();
		var i = 0;
		var begin = get_location ();

		if (current () != TokenType.CLOSE_PARENS) {
			do {
				var p_expr = parse_expression ();
				if (i == 0) {
					i++;
					
					if (p_expr != null) { 
						string s = "\"\\n\"";
						var rhs = new StringLiteral (s, get_src (begin));
						p_expr = new BinaryExpression (BinaryOperator.PLUS, p_expr, rhs, get_src (begin));
					}
				
				} 
				list.add (p_expr);

			} while (accept (TokenType.COMMA));
		}
		return list;
	}

	Expression parse_print_expression () throws ParseError {
		var begin = get_location ();
	
		expect (TokenType.PRINT);
		accept (TokenType.OPEN_PARENS);
	
		var expr = new MemberAccess (null, "print", get_src (begin));
		
		var arg_list = parse_print_argument_list ();
		
		accept (TokenType.CLOSE_PARENS);
		
		var print_expr = new InvocationExpression (expr, get_src (begin));
		
		foreach (Expression arg in arg_list) {
			print_expr.add_argument (arg);
		}
		
		return print_expr;
		
	}
	
	Expression parse_assert_expression () throws ParseError {
		var begin = get_location ();
	
		expect (TokenType.ASSERT);
		accept (TokenType.OPEN_PARENS);
	
		var expr = new MemberAccess (null, "assert", get_src (begin));
		
		var arg_list = parse_argument_list ();
		
		accept (TokenType.CLOSE_PARENS);
		
		var assert_expr = new InvocationExpression (expr, get_src (begin));
		
		foreach (Expression arg in arg_list) {
			assert_expr.add_argument (arg);
		}
		
		return assert_expr;
		
	}

	Expression parse_invocation_expression (SourceLocation begin, Expression inner) throws ParseError {
		expect (TokenType.OPEN_PARENS);
		var arg_list = parse_argument_list ();
		expect (TokenType.CLOSE_PARENS);
		var init_list = parse_object_initializer ();

		if (init_list.size > 0 && inner is MemberAccess) {
			// struct creation expression
			var member = (MemberAccess) inner;
			member.creation_member = true;

			var expr = new ObjectCreationExpression (member, get_src (begin));
			expr.struct_creation = true;
			foreach (Expression arg in arg_list) {
				expr.add_argument (arg);
			}
			foreach (MemberInitializer initializer in init_list) {
				expr.add_member_initializer (initializer);
			}
			return expr;
		} else {
			var expr = new InvocationExpression (inner, get_src (begin));
			foreach (Expression arg in arg_list) {
				expr.add_argument (arg);
			}
			return expr;
		}
	}

	Expression parse_element_access (SourceLocation begin, Expression inner) throws ParseError {
		expect (TokenType.OPEN_BRACKET);
		var index_list = parse_expression_list ();
		expect (TokenType.CLOSE_BRACKET);

		var expr = new ElementAccess (inner, get_src (begin));
		foreach (Expression index in index_list) {
			expr.append_index (index);
		}
		return expr;
	}

	Gee.List<Expression> parse_expression_list () throws ParseError {
		var list = new ArrayList<Expression> ();
		do {
			list.add (parse_expression ());
		} while (accept (TokenType.COMMA));
		return list;
	}

	Expression parse_this_access () throws ParseError {
		var begin = get_location ();
		expect (TokenType.THIS);
		return new MemberAccess (null, "this", get_src (begin));
	}

	Expression parse_base_access () throws ParseError {
		var begin = get_location ();
		expect (TokenType.SUPER);
		return new BaseAccess (get_src (begin));
	}

	Expression parse_post_increment_expression (SourceLocation begin, Expression inner) throws ParseError {
		expect (TokenType.OP_INC);
		return new PostfixExpression (inner, true, get_src (begin));
	}

	Expression parse_post_decrement_expression (SourceLocation begin, Expression inner) throws ParseError {
		expect (TokenType.OP_DEC);
		return new PostfixExpression (inner, false, get_src (begin));
	}

	Expression parse_object_or_array_creation_expression () throws ParseError {
		var begin = get_location ();
		expect (TokenType.NEW);
		var member = parse_member_name ();
		if (accept (TokenType.OPEN_PARENS)) {
			var expr = parse_object_creation_expression (begin, member);
			return expr;
		} else if (accept (TokenType.OPEN_BRACKET)) {
			var expr = parse_array_creation_expression (begin, member);
			return expr;
		} else {
			throw new ParseError.SYNTAX (get_error ("expected ( or ["));
		}
	}

	Expression parse_object_creation_expression (SourceLocation begin, MemberAccess member) throws ParseError {
		member.creation_member = true;
		var arg_list = parse_argument_list ();
		expect (TokenType.CLOSE_PARENS);
		var init_list = parse_object_initializer ();

		var expr = new ObjectCreationExpression (member, get_src (begin));
		foreach (Expression arg in arg_list) {
			expr.add_argument (arg);
		}
		foreach (MemberInitializer initializer in init_list) {
			expr.add_member_initializer (initializer);
		}
		return expr;
	}

	Expression parse_array_creation_expression (SourceLocation begin, MemberAccess member) throws ParseError {
		bool size_specified = false;
		Gee.List<Expression> size_specifier_list;
		bool first = true;
		DataType element_type = UnresolvedType.new_from_expression (member);
		do {
			if (!first) {
 				// array of arrays: new T[][42]
				element_type = new ArrayType (element_type, size_specifier_list.size, element_type.source_reference);
			} else {
				first = false;
			}

			size_specifier_list = new ArrayList<Expression> ();
			do {
				Expression size = null;
				if (current () != TokenType.CLOSE_BRACKET && current () != TokenType.COMMA) {
					size = parse_expression ();
					size_specified = true;
				}
				size_specifier_list.add (size);
			} while (accept (TokenType.COMMA));
			expect (TokenType.CLOSE_BRACKET);
		} while (accept (TokenType.OPEN_BRACKET));

		InitializerList initializer = null;
		if (current () == TokenType.OPEN_BRACE) {
			initializer = parse_initializer ();
		}
		var expr = new ArrayCreationExpression (element_type, size_specifier_list.size, initializer, get_src (begin));
		if (size_specified) {
			foreach (Expression size in size_specifier_list) {
				expr.append_size (size);
			}
		}
		return expr;
	}

	Gee.List<MemberInitializer> parse_object_initializer () throws ParseError {
		var list = new ArrayList<MemberInitializer> ();
		if (accept (TokenType.OPEN_BRACE)) {
			do {
				list.add (parse_member_initializer ());
			} while (accept (TokenType.COMMA));
			expect (TokenType.CLOSE_BRACE);
		}
		return list;
	}

	MemberInitializer parse_member_initializer () throws ParseError {
		var begin = get_location ();
		string id = parse_identifier ();
		expect (TokenType.ASSIGN);
		var expr = parse_expression ();

		return new MemberInitializer (id, expr, get_src (begin));
	}

	Expression parse_sizeof_expression () throws ParseError {
		var begin = get_location ();
		expect (TokenType.SIZEOF);
		expect (TokenType.OPEN_PARENS);
		var type = parse_type ();
		expect (TokenType.CLOSE_PARENS);

		return new SizeofExpression (type, get_src (begin));
	}

	Expression parse_typeof_expression () throws ParseError {
		var begin = get_location ();
		expect (TokenType.TYPEOF);
		expect (TokenType.OPEN_PARENS);
		var type = parse_type ();
		expect (TokenType.CLOSE_PARENS);

		return new TypeofExpression (type, get_src (begin));
	}

	UnaryOperator get_unary_operator (TokenType token_type) {
		switch (token_type) {
		case TokenType.PLUS:   return UnaryOperator.PLUS;
		case TokenType.MINUS:  return UnaryOperator.MINUS;
		case TokenType.OP_NEG: return UnaryOperator.LOGICAL_NEGATION;
		case TokenType.TILDE:  return UnaryOperator.BITWISE_COMPLEMENT;
		case TokenType.OP_INC: return UnaryOperator.INCREMENT;
		case TokenType.OP_DEC: return UnaryOperator.DECREMENT;
		case TokenType.REF:    return UnaryOperator.REF;
		case TokenType.OUT:    return UnaryOperator.OUT;
		default:               return UnaryOperator.NONE;
		}
	}

	Expression parse_unary_expression () throws ParseError {
		var begin = get_location ();
		var operator = get_unary_operator (current ());
		if (operator != UnaryOperator.NONE) {
			next ();
			var op = parse_unary_expression ();
			return new UnaryExpression (operator, op, get_src (begin));
		}
		switch (current ()) {
		case TokenType.HASH:
			next ();
			var op = parse_unary_expression ();
			return new ReferenceTransferExpression (op, get_src (begin));
		case TokenType.OPEN_PARENS:
			next ();
			switch (current ()) {
			case TokenType.VOID:
			case TokenType.DYNAMIC:
			case TokenType.WEAK:
			case TokenType.IDENTIFIER:
				var type = parse_type ();
				if (accept (TokenType.CLOSE_PARENS)) {
					// check follower to decide whether to create cast expression
					switch (current ()) {
					case TokenType.OP_NEG:
					case TokenType.TILDE:
					case TokenType.OPEN_PARENS:
					case TokenType.TRUE:
					case TokenType.FALSE:
					case TokenType.INTEGER_LITERAL:
					case TokenType.REAL_LITERAL:
					case TokenType.CHARACTER_LITERAL:
					case TokenType.STRING_LITERAL:
					case TokenType.NULL:
					case TokenType.THIS:
					case TokenType.SUPER:
					case TokenType.NEW:
					case TokenType.SIZEOF:
					case TokenType.TYPEOF:
					case TokenType.IDENTIFIER:
						if (!type.value_owned) {
							Report.warning (get_src (begin), "obsolete syntax, weak type modifier unused in cast expressions");
						}
						var inner = parse_unary_expression ();
						return new CastExpression (inner, type, get_src (begin), false);
					}
				}
				break;
			}
			// no cast expression
			rollback (begin);
			break;
		case TokenType.STAR:
			next ();
			var op = parse_unary_expression ();
			return new PointerIndirection (op, get_src (begin));
		case TokenType.BITWISE_AND:
			next ();
			var op = parse_unary_expression ();
			return new AddressofExpression (op, get_src (begin));
		}

		var expr = parse_primary_expression ();
		return expr;
	}

	BinaryOperator get_binary_operator (TokenType token_type) {
		switch (token_type) {
		case TokenType.STAR:    return BinaryOperator.MUL;
		case TokenType.DIV:     return BinaryOperator.DIV;
		case TokenType.PERCENT: return BinaryOperator.MOD;
		case TokenType.PLUS:    return BinaryOperator.PLUS;
		case TokenType.MINUS:   return BinaryOperator.MINUS;
		case TokenType.OP_LT:   return BinaryOperator.LESS_THAN;
		case TokenType.OP_GT:   return BinaryOperator.GREATER_THAN;
		case TokenType.OP_LE:   return BinaryOperator.LESS_THAN_OR_EQUAL;
		case TokenType.OP_GE:   return BinaryOperator.GREATER_THAN_OR_EQUAL;
		case TokenType.OP_EQ:   return BinaryOperator.EQUALITY;
		case TokenType.IS:   
			next();
			if (current () == TokenType.OP_NEG) {
				prev ();
				return BinaryOperator.INEQUALITY;
			}
			prev ();
			return BinaryOperator.EQUALITY;
		case TokenType.OP_NE:   return BinaryOperator.INEQUALITY;
		default:                return BinaryOperator.NONE;
		}
	}

	Expression parse_multiplicative_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_unary_expression ();
		bool found = true;
		while (found) {
			var operator = get_binary_operator (current ());
			switch (operator) {
			case BinaryOperator.MUL:
			case BinaryOperator.DIV:
			case BinaryOperator.MOD:
				next ();
				var right = parse_unary_expression ();
				left = new BinaryExpression (operator, left, right, get_src (begin));
				break;
			default:
				found = false;
				break;
			}
		}
		return left;
	}

	Expression parse_additive_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_multiplicative_expression ();
		bool found = true;
		while (found) {
			var operator = get_binary_operator (current ());
			switch (operator) {
			case BinaryOperator.PLUS:
			case BinaryOperator.MINUS:
				next ();
				var right = parse_multiplicative_expression ();
				left = new BinaryExpression (operator, left, right, get_src (begin));
				break;
			default:
				found = false;
				break;
			}
		}
		return left;
	}

	Expression parse_shift_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_additive_expression ();
		bool found = true;
		while (found) {
			switch (current ()) {
			case TokenType.OP_SHIFT_LEFT:
				next ();
				var right = parse_additive_expression ();
				left = new BinaryExpression (BinaryOperator.SHIFT_LEFT, left, right, get_src (begin));
				break;
			// don't use OP_SHIFT_RIGHT to support >> for nested generics
			case TokenType.OP_GT:
				char* first_gt_pos = tokens[index].begin.pos;
				next ();
				// only accept >> when there is no space between the two > signs
				if (current () == TokenType.OP_GT && tokens[index].begin.pos == first_gt_pos + 1) {
					next ();
					var right = parse_additive_expression ();
					left = new BinaryExpression (BinaryOperator.SHIFT_RIGHT, left, right, get_src (begin));
				} else {
					prev ();
					found = false;
				}
				break;
			default:
				found = false;
				break;
			}
		}
		return left;
	}

	Expression parse_relational_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_shift_expression ();
		bool found = true;
		while (found) {
			var operator = get_binary_operator (current ());
			switch (operator) {
			case BinaryOperator.LESS_THAN:
			case BinaryOperator.LESS_THAN_OR_EQUAL:
			case BinaryOperator.GREATER_THAN_OR_EQUAL:
				next ();
				var right = parse_shift_expression ();
				left = new BinaryExpression (operator, left, right, get_src (begin));
				break;
			case BinaryOperator.GREATER_THAN:
				next ();
				// ignore >> and >>= (two tokens due to generics)
				if (current () != TokenType.OP_GT && current () != TokenType.OP_GE) {
					var right = parse_shift_expression ();
					left = new BinaryExpression (operator, left, right, get_src (begin));
				} else {
					prev ();
					found = false;
				}
				break;
			default:
				switch (current ()) {
				case TokenType.ISA:
					next ();
					var type = parse_type ();
					left = new TypeCheck (left, type, get_src (begin));
					break;
				case TokenType.AS:
					next ();
					var type = parse_type ();
					left = new CastExpression (left, type, get_src (begin), true);
					break;
				default:
					found = false;
					break;
				}
				break;
			}
		}
		return left;
	}

	Expression parse_equality_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_relational_expression ();
		bool found = true;
		while (found) {
			var operator = get_binary_operator (current ());
			switch (operator) {
			case BinaryOperator.INEQUALITY:
			case BinaryOperator.EQUALITY:
				if ((operator == BinaryOperator.INEQUALITY) && (current () == TokenType.IS)) {
					next ();
				}
				next ();
				var right = parse_relational_expression ();
				left = new BinaryExpression (operator, left, right, get_src (begin));
				break;
			default:
				found = false;
				break;
			}
		}
		return left;
	}

	Expression parse_and_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_equality_expression ();
		while (accept (TokenType.BITWISE_AND)) {
			var right = parse_equality_expression ();
			left = new BinaryExpression (BinaryOperator.BITWISE_AND, left, right, get_src (begin));
		}
		return left;
	}

	Expression parse_exclusive_or_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_and_expression ();
		while (accept (TokenType.CARRET)) {
			var right = parse_and_expression ();
			left = new BinaryExpression (BinaryOperator.BITWISE_XOR, left, right, get_src (begin));
		}
		return left;
	}

	Expression parse_inclusive_or_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_exclusive_or_expression ();
		while (accept (TokenType.BITWISE_OR)) {
			var right = parse_exclusive_or_expression ();
			left = new BinaryExpression (BinaryOperator.BITWISE_OR, left, right, get_src (begin));
		}
		return left;
	}

	Expression parse_in_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_inclusive_or_expression ();
		while (accept (TokenType.IN)) {
			var right = parse_inclusive_or_expression ();
			left = new BinaryExpression (BinaryOperator.IN, left, right, get_src (begin));
		}
		return left;
	}

	Expression parse_conditional_and_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_in_expression ();
		while (accept (TokenType.OP_AND)) {
			var right = parse_in_expression ();
			left = new BinaryExpression (BinaryOperator.AND, left, right, get_src (begin));
		}
		return left;
	}

	Expression parse_conditional_or_expression () throws ParseError {
		var begin = get_location ();
		var left = parse_conditional_and_expression ();
		while (accept (TokenType.OP_OR)) {
			var right = parse_conditional_and_expression ();
			left = new BinaryExpression (BinaryOperator.OR, left, right, get_src (begin));
		}
		return left;
	}

	Expression parse_conditional_expression () throws ParseError {
		var begin = get_location ();
		var condition = parse_conditional_or_expression ();
		if (accept (TokenType.INTERR)) {
			var true_expr = parse_expression ();
			expect (TokenType.COLON);
			var false_expr = parse_expression ();
			return new ConditionalExpression (condition, true_expr, false_expr, get_src (begin));
		} else {
			return condition;
		}
	}

	Expression parse_lambda_expression () throws ParseError {
		var begin = get_location ();
		Gee.List<string> params = new ArrayList<string> ();
		
		expect (TokenType.DEF);
		
		if (accept (TokenType.OPEN_PARENS)) {
			if (current () != TokenType.CLOSE_PARENS) {
				do {
					params.add (parse_identifier ());
				} while (accept (TokenType.COMMA));
			}
			expect (TokenType.CLOSE_PARENS);
		} else {
			params.add (parse_identifier ());
		}


		LambdaExpression lambda;
		if (accept_block ()) {
			var block = parse_block ();
			lambda = new LambdaExpression.with_statement_body (block, get_src (begin));
		} else {
			var expr = parse_expression ();
			lambda = new LambdaExpression (expr, get_src (begin));
			expect_terminator ();
			
		}


		foreach (string param in params) {
			lambda.add_parameter (param);
		}
		return lambda;
	}

	AssignmentOperator get_assignment_operator (TokenType token_type) {
		switch (token_type) {
		case TokenType.ASSIGN:             return AssignmentOperator.SIMPLE;
		case TokenType.ASSIGN_ADD:         return AssignmentOperator.ADD;
		case TokenType.ASSIGN_SUB:         return AssignmentOperator.SUB;
		case TokenType.ASSIGN_BITWISE_OR:  return AssignmentOperator.BITWISE_OR;
		case TokenType.ASSIGN_BITWISE_AND: return AssignmentOperator.BITWISE_AND;
		case TokenType.ASSIGN_BITWISE_XOR: return AssignmentOperator.BITWISE_XOR;
		case TokenType.ASSIGN_DIV:         return AssignmentOperator.DIV;
		case TokenType.ASSIGN_MUL:         return AssignmentOperator.MUL;
		case TokenType.ASSIGN_PERCENT:     return AssignmentOperator.PERCENT;
		case TokenType.ASSIGN_SHIFT_LEFT:  return AssignmentOperator.SHIFT_LEFT;
		default:                           return AssignmentOperator.NONE;
		}
	}

	Expression parse_expression () throws ParseError {
		if (current () == TokenType.DEF) {
			var lambda = parse_lambda_expression ();
			current_expr_is_lambda = true;
			return lambda;
		}

		var begin = get_location ();
		Expression expr = parse_conditional_expression ();

		while (true) {
			var operator = get_assignment_operator (current ());
			if (operator != AssignmentOperator.NONE) {
				next ();
				var rhs = parse_expression ();
				expr = new Assignment (expr, rhs, operator, get_src (begin));
				if (expr == null) {
					// workaround for current limitation of exception handling
					throw new ParseError.SYNTAX ("syntax error in assignment");
				}
			} else if (current () == TokenType.OP_GT) { // >>=
				char* first_gt_pos = tokens[index].begin.pos;
				next ();
				// only accept >>= when there is no space between the two > signs
				if (current () == TokenType.OP_GE && tokens[index].begin.pos == first_gt_pos + 1) {
					next ();
					var rhs = parse_expression ();
					expr = new Assignment (expr, rhs, AssignmentOperator.SHIFT_RIGHT, get_src (begin));
					if (expr == null) {
						// workaround for current limitation of exception handling
						throw new ParseError.SYNTAX ("syntax error in assignment");
					}
				} else {
					prev ();
					break;
				}
			} else {
				break;
			}
		}

		return expr;
	}

	void parse_statements (Block block) throws ParseError {
		while (current () != TokenType.DEDENT
		       && current () != TokenType.WHEN
		       && current () != TokenType.DEFAULT) {
			try {
				Statement stmt;
				bool is_decl = false;
				comment = scanner.pop_comment ();
				switch (current ()) {

				/* skip over requires and ensures as we handled them in method declaration */	
				case TokenType.REQUIRES:
				case TokenType.ENSURES:
					var begin = get_location ();	
					next ();

					if (accept (TokenType.EOL) && accept (TokenType.INDENT)) {
						while (current () != TokenType.DEDENT) {
							next();
						}

						expect (TokenType.DEDENT);
					} else {
						while (current () != TokenType.EOL) {
							next();
						}

						expect (TokenType.EOL);
					}
		
					stmt =  new EmptyStatement (get_src_com (begin));
					break;				


				case TokenType.INDENT:
					stmt = parse_block ();
					break;
				case TokenType.SEMICOLON:
				case TokenType.PASS:
					stmt = parse_empty_statement ();
					break;
				case TokenType.PRINT:
				case TokenType.ASSERT:
					stmt = parse_expression_statement ();	
					break;
				case TokenType.IF:
					stmt = parse_if_statement ();
					break;
				case TokenType.CASE:
					stmt = parse_switch_statement ();
					break;
				case TokenType.WHILE:
					stmt = parse_while_statement ();
					break;
				case TokenType.DO:
					stmt = parse_do_statement ();
					break;
				case TokenType.FOR:
					stmt = parse_for_statement ();
					break;
				case TokenType.FOREACH:
					stmt = parse_foreach_statement ();
					break;
				case TokenType.BREAK:
					stmt = parse_break_statement ();
					break;
				case TokenType.CONTINUE:
					stmt = parse_continue_statement ();
					break;
				case TokenType.RETURN:
					stmt = parse_return_statement ();
					break;
				case TokenType.RAISE:
					stmt = parse_throw_statement ();
					break;
				case TokenType.TRY:
					stmt = parse_try_statement ();
					break;
				case TokenType.LOCK:
					stmt = parse_lock_statement ();
					break;
				case TokenType.DELETE:
					stmt = parse_delete_statement ();
					break;
				case TokenType.VAR:
					is_decl = true;
					parse_local_variable_declarations (block);
					break;


				case TokenType.OP_INC:
				case TokenType.OP_DEC:
				case TokenType.SUPER:
				case TokenType.THIS:
				case TokenType.OPEN_PARENS:
				case TokenType.STAR:
				case TokenType.NEW:
					stmt = parse_expression_statement ();
					break;
				default:
					bool is_expr = is_expression ();
					if (is_expr) {
						stmt = parse_expression_statement ();
					} else {
						is_decl = true;
						parse_local_variable_declarations (block);
					}
					break;
				}

				if (!is_decl) {
					if (stmt == null) {
						// workaround for current limitation of exception handling
						throw new ParseError.SYNTAX ("syntax error in statement");
					}
					block.add_statement (stmt);
				}
			} catch (ParseError e) {
				if (recover () != RecoveryState.STATEMENT_BEGIN) {
					// beginning of next declaration or end of file reached
					// return what we have so far
					break;
				}
			}
		}
	}

	bool is_expression () throws ParseError {
		var begin = get_location ();

		// decide between declaration and expression statement
		skip_type ();
		switch (current ()) {
		// invocation expression
		case TokenType.OPEN_PARENS:
		// postfix increment
		case TokenType.OP_INC:
		// postfix decrement
		case TokenType.OP_DEC:
		// assignments
		case TokenType.ASSIGN:
		case TokenType.ASSIGN_ADD:
		case TokenType.ASSIGN_BITWISE_AND:
		case TokenType.ASSIGN_BITWISE_OR:
		case TokenType.ASSIGN_BITWISE_XOR:
		case TokenType.ASSIGN_DIV:
		case TokenType.ASSIGN_MUL:
		case TokenType.ASSIGN_PERCENT:
		case TokenType.ASSIGN_SHIFT_LEFT:
		case TokenType.ASSIGN_SUB:
		case TokenType.OP_GT: // >>=
		// member access
		case TokenType.DOT:
		// pointer member access
		case TokenType.OP_PTR:
			rollback (begin);
			return true;
		}

		rollback (begin);
		return false;
	}

	Block parse_embedded_statement () throws ParseError {
		if (current () == TokenType.INDENT) {
			var block = parse_block ();
			return block;
		}

		comment = scanner.pop_comment ();

		var block = new Block ();
		var stmt = parse_embedded_statement_without_block ();
		if (stmt == null) {
			// workaround for current limitation of exception handling
			throw new ParseError.SYNTAX ("syntax error in embedded statement");
		}
		block.add_statement (stmt);
		return block;

	}

	Statement parse_embedded_statement_without_block () throws ParseError {
		switch (current ()) {
		case TokenType.PASS:
		case TokenType.SEMICOLON: return parse_empty_statement ();
		case TokenType.IF:        return parse_if_statement ();
		case TokenType.CASE:      return parse_switch_statement ();
		case TokenType.WHILE:     return parse_while_statement ();
		case TokenType.DO:        return parse_do_statement ();
		case TokenType.FOR:       return parse_for_statement ();
		case TokenType.FOREACH:   return parse_foreach_statement ();
		case TokenType.BREAK:     return parse_break_statement ();
		case TokenType.CONTINUE:  return parse_continue_statement ();
		case TokenType.RETURN:    return parse_return_statement ();
		case TokenType.RAISE:     return parse_throw_statement ();
		case TokenType.TRY:       return parse_try_statement ();
		case TokenType.LOCK:      return parse_lock_statement ();
		case TokenType.DELETE:    return parse_delete_statement ();
		default:                  return parse_expression_statement ();
		}
	}

	Block parse_block () throws ParseError {
		var begin = get_location ();
		Gee.List<Statement> list = new ArrayList<Statement> ();
		expect (TokenType.INDENT);
		var block = new Block (get_src_com (begin));
		parse_statements (block);
		if (!accept (TokenType.DEDENT)) {
			// only report error if it's not a secondary error
			if (Report.get_errors () == 0) {
				Report.error (get_current_src (), "tab indentation is incorrect");
			}
		}

		return block;
	}

	Statement parse_empty_statement () throws ParseError {
		var begin = get_location ();

		accept (TokenType.PASS);
		accept (TokenType.SEMICOLON);
		expect_terminator ();

		return new EmptyStatement (get_src_com (begin));
	}

	void add_local_var_variable (Block block, string id)  throws ParseError {
		DataType type_copy = null;
		var local = parse_local_variable (type_copy, id);
		block.add_statement (new DeclarationStatement (local, local.source_reference));
	}

	void parse_local_variable_declarations (Block block) throws ParseError {
		var begin = get_location ();

		if (accept (TokenType.VAR)) {
			/* support block vars */
			if (accept (TokenType.EOL) && accept (TokenType.INDENT)) {
				while (current () != TokenType.DEDENT) {
					var s = parse_identifier ();
					add_local_var_variable (block, s);
					accept (TokenType.EOL);
					accept (TokenType.SEMICOLON);
				}
			
				expect (TokenType.DEDENT);
			} else {
				var s = parse_identifier ();
				add_local_var_variable (block, s);
				expect_terminator ();
			}
			
			return;
		}

		var id_list = new ArrayList<string> ();
		DataType variable_type = null;

		do {
			id_list.add (parse_identifier ());
		} while (accept (TokenType.COMMA));

		expect (TokenType.COLON);

		variable_type = parse_type ();

		foreach (string id in id_list) {
			DataType type_copy = null;
			if (variable_type != null) {
				type_copy = variable_type.copy ();
			}
			var local = parse_local_variable (type_copy, id);
			block.add_statement (new DeclarationStatement (local, local.source_reference));
		}

		expect_terminator ();
	}

	LocalVariable parse_local_variable (DataType? variable_type, string id) throws ParseError {
		var begin = get_location ();
		Expression initializer = null;
		if (accept (TokenType.ASSIGN)) {
			initializer = parse_variable_initializer ();
		}
		return new LocalVariable (variable_type, id, initializer, get_src_com (begin));
	}

	Statement parse_expression_statement () throws ParseError {
		var begin = get_location ();
		var expr = parse_statement_expression ();

		if (current_expr_is_lambda) {
			current_expr_is_lambda = false;
		} else {
			expect_terminator ();
		}

		return new ExpressionStatement (expr, get_src_com (begin));
	}

	Expression parse_statement_expression () throws ParseError {
		// invocation expression, assignment,
		// or pre/post increment/decrement expression
		var expr = parse_expression ();
		return expr;
	}

	Statement parse_if_statement () throws ParseError {
		var begin = get_location ();

		expect (TokenType.IF);

		var condition = parse_expression ();

		if (!accept (TokenType.DO)) {
			expect (TokenType.EOL);
		} else {
			accept (TokenType.EOL);
		}

		var src = get_src_com (begin);
		var true_stmt = parse_embedded_statement ();
		Block false_stmt = null;
		if (accept (TokenType.ELSE)) {
			false_stmt = parse_embedded_statement ();
		}
		return new IfStatement (condition, true_stmt, false_stmt, src);
	}

	Statement parse_switch_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.CASE);
		var condition = parse_expression ();

		expect (TokenType.EOL);

		var stmt = new SwitchStatement (condition, get_src_com (begin));
		expect (TokenType.INDENT);
		while (current () != TokenType.DEDENT) {
			var section = new SwitchSection (get_src_com (begin));
			
			if (accept (TokenType.WHEN)) {
				do {
					section.add_label (new SwitchLabel (parse_expression (), get_src_com (begin)));
				}
				while (accept (TokenType.COMMA));
			} else {
				expect (TokenType.DEFAULT);
				section.add_label (new SwitchLabel.with_default (get_src_com (begin)));
			}

			if (!accept (TokenType.EOL)) {
				expect (TokenType.DO);
			}

			parse_statements (section);

			/* add break statement for each block */
			var break_stmt =  new BreakStatement (get_src_com (begin));
			section.add_statement (break_stmt);

			stmt.add_section (section);
		}
		expect (TokenType.DEDENT);
		return stmt;
	}

	Statement parse_while_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.WHILE);
		var condition = parse_expression ();

		if (!accept (TokenType.DO)) {
			expect (TokenType.EOL);
		} else {
			accept (TokenType.EOL);
		}

		var body = parse_embedded_statement ();
		return new WhileStatement (condition, body, get_src_com (begin));
	}

	Statement parse_do_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.DO);
		expect (TokenType.EOL);
		var body = parse_embedded_statement ();
		expect (TokenType.WHILE);

		var condition = parse_expression ();

		expect_terminator ();
		
		return new DoStatement (body, condition, get_src_com (begin));
	}


	Statement parse_for_statement () throws ParseError {
		var begin = get_location ();
		Block block = null;
		Expression initializer = null;
		Expression condition = null;
		Expression iterator = null;
		bool is_expr;
		string id;

		expect (TokenType.FOR);

		switch (current ()) {
		case TokenType.VAR:
			is_expr = false;
			break;
		default:
			
			bool local_is_expr = is_expression ();
			is_expr = local_is_expr;
			break;
		}

		if (is_expr) {
			initializer = parse_statement_expression ();
		} else {
			block = new Block (get_src (begin));
			DataType variable_type;
			if (accept (TokenType.VAR)) {
				variable_type = null;
				id = parse_identifier ();
			} else {
				id = parse_identifier ();
				expect (TokenType.COLON);
				variable_type = parse_type ();
			}
			
			DataType type_copy = null;
			if (variable_type != null) {
				type_copy = variable_type.copy ();
			}
			var local = parse_local_variable (type_copy, id);

			block.add_statement (new DeclarationStatement (local, local.source_reference));
		}
		
		
		
		if (accept (TokenType.TO)) {
			/* create expression for condition and incrementing iterator */		
			var to_begin = get_location ();
			var to_src = get_src (to_begin);
			var left = new MemberAccess (null, id, to_src);
			var right = parse_primary_expression ();

			condition = new BinaryExpression (BinaryOperator.LESS_THAN_OR_EQUAL, left, right, to_src);
			
			iterator = new PostfixExpression (left, true, to_src);
		} else {
			expect (TokenType.DOWNTO);
			var downto_begin = get_location ();
			var downto_src = get_src (downto_begin);
			/* create expression for condition and decrementing iterator */
			var left = new MemberAccess (null, id, downto_src);
			var right = parse_primary_expression ();

			condition = new BinaryExpression (BinaryOperator.GREATER_THAN_OR_EQUAL, left, right, downto_src);

			iterator = new PostfixExpression (left, false, downto_src);
		}

		expect (TokenType.EOL);

		var src = get_src_com (begin);
		var body = parse_embedded_statement ();
		var stmt = new ForStatement (condition, body, src);

		if (initializer != null) stmt.add_initializer (initializer);

		stmt.add_iterator (iterator);


		if (block != null) {
			block.add_statement (stmt);
			return block;
		} else {
			return stmt;
		}
	}

	Statement parse_foreach_statement () throws ParseError {
		var begin = get_location ();
		DataType type = null;
		string id = null;

		expect (TokenType.FOREACH);

		if (accept (TokenType.VAR)) {
			 id = parse_identifier ();
		} else {
			id = parse_identifier ();
			expect (TokenType.COLON);
			type = parse_type ();
		}

		expect (TokenType.IN);
		var collection = parse_expression ();
		expect (TokenType.EOL);
		var src = get_src_com (begin);
		var body = parse_embedded_statement ();
		return new ForeachStatement (type, id, collection, body, src);
	}

	Statement parse_break_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.BREAK);
		expect_terminator ();
		return new BreakStatement (get_src_com (begin));
	}

	Statement parse_continue_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.CONTINUE);
		expect_terminator ();
		return new ContinueStatement (get_src_com (begin));
	}

	Statement parse_return_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.RETURN);
		Expression expr = null;
		if (current () != TokenType.SEMICOLON && current () != TokenType.EOL) {
			expr = parse_expression ();
		}
		expect_terminator ();
		return new ReturnStatement (expr, get_src_com (begin));
	}

	Statement parse_throw_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.RAISE);
		var expr = parse_expression ();
		expect_terminator ();
		return new ThrowStatement (expr, get_src_com (begin));
	}

	Statement parse_try_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.TRY);
		expect (TokenType.EOL);
		var try_block = parse_block ();
		Block finally_clause = null;
		var catch_clauses = new ArrayList<CatchClause> ();
		if (current () == TokenType.EXCEPT) {
			parse_catch_clauses (catch_clauses);
			if (current () == TokenType.FINALLY) {
				finally_clause = parse_finally_clause ();
			}
		} else {
			finally_clause = parse_finally_clause ();
		}
		var stmt = new TryStatement (try_block, finally_clause, get_src_com (begin));
		foreach (CatchClause clause in catch_clauses) {
			stmt.add_catch_clause (clause);
		}
		return stmt;
	}

	void parse_catch_clauses (Gee.List<CatchClause> catch_clauses) throws ParseError {
		while (accept (TokenType.EXCEPT)) {
			var begin = get_location ();
			DataType type = null;
			string id = null;
			if (!accept (TokenType.EOL)) {
				id = parse_identifier ();
				expect (TokenType.COLON);
				type = parse_type ();
				expect (TokenType.EOL);
				
			}
			var block = parse_block ();
			catch_clauses.add (new CatchClause (type, id, block, get_src (begin)));
		}
	}

	Block parse_finally_clause () throws ParseError {
		expect (TokenType.FINALLY);
		accept_block ();
		var block = parse_block ();
		return block;
	}

	Statement parse_lock_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.LOCK);
		expect (TokenType.OPEN_PARENS);
		var expr = parse_expression ();
		expect (TokenType.CLOSE_PARENS);
		var stmt = parse_embedded_statement ();
		return new LockStatement (expr, stmt, get_src_com (begin));
	}

	Statement parse_delete_statement () throws ParseError {
		var begin = get_location ();
		expect (TokenType.DELETE);
		var expr = parse_expression ();
		expect_terminator ();
		return new DeleteStatement (expr, get_src_com (begin));
	}

	Gee.List<Attribute>? parse_attributes () throws ParseError {
		if (current () != TokenType.OPEN_BRACKET) {
			return null;
		}
		var attrs = new ArrayList<Attribute> ();
		while (accept (TokenType.OPEN_BRACKET)) {
			do {
				var begin = get_location ();
				string id = parse_identifier ();
				var attr = new Attribute (id, get_src (begin));
				if (accept (TokenType.OPEN_PARENS)) {
					if (current () != TokenType.CLOSE_PARENS) {
						do {
							begin = get_location ();
							string id = parse_identifier ();
							expect (TokenType.ASSIGN);
							var expr = parse_expression ();
							attr.add_argument (new NamedArgument (id, expr, get_src (begin)));
						} while (accept (TokenType.COMMA));
					}
					expect (TokenType.CLOSE_PARENS);
				}
				attrs.add (attr);
			} while (accept (TokenType.COMMA));
			expect (TokenType.CLOSE_BRACKET);
		}
		return attrs;
	}

	void set_attributes (CodeNode node, Gee.List<Attribute>? attributes) {
		if (attributes != null) {
			foreach (Attribute attr in (Gee.List<Attribute>) attributes) {
				node.attributes.append (attr);
			}
		}
	}

	Symbol parse_declaration () throws ParseError {
		comment = scanner.pop_comment ();
		var attrs = parse_attributes ();
		
		switch (current ()) {
		case TokenType.CONST:
			return parse_constant_declaration (attrs);	
		case TokenType.CONSTRUCT:
			return parse_creation_method_declaration (attrs);
		case TokenType.CLASS:
			return parse_class_declaration (attrs);
		case TokenType.INIT:
			return parse_constructor_declaration (attrs);
		case TokenType.DELEGATE:	
			return parse_delegate_declaration (attrs);	
		case TokenType.DEF:
			return parse_method_declaration (attrs);
		case TokenType.ENUM:
			return parse_enum_declaration (attrs);
		case TokenType.ERRORDOMAIN:
			return parse_errordomain_declaration (attrs);
		case TokenType.FINAL:
			return parse_destructor_declaration (attrs);
		case TokenType.INTERFACE:	
			return parse_interface_declaration (attrs);		
		case TokenType.NAMESPACE:	
			return parse_namespace_declaration (attrs);	
		case TokenType.PROP:	
			return parse_property_declaration (attrs);
		case TokenType.EVENT:	
			return parse_signal_declaration (attrs);
		case TokenType.STRUCT:	
			return parse_struct_declaration (attrs);
		default: 
			var begin = get_location ();
			while (current () != TokenType.EOL && current () != TokenType.SEMICOLON && current () != TokenType.EOF) {
				if (current () == TokenType.COLON) {
					rollback (begin);
					return parse_field_declaration (attrs);
				} else {
					next ();
				}
			}
			rollback (begin);
			
			break;	
		}
		
		TokenType cur = current ();
		TokenType pre =  tokens[index-1].type;

		throw new ParseError.SYNTAX (get_error ("expected declaration  but got %s with previous %s".printf (cur.to_string (), pre.to_string())));
	}

	void parse_declarations (Symbol parent, bool root = false) throws ParseError {
		if (!root) {
			expect (TokenType.INDENT);
		}
		while (current () != TokenType.DEDENT && current () != TokenType.EOF) {
			try {
				if (parent is Namespace) {
					parse_namespace_member ((Namespace) parent);
				} else if (parent is Class) {
					parse_class_member ((Class) parent);
				} else if (parent is Struct) {
					parse_struct_member ((Struct) parent);
				} else if (parent is Interface) {
					parse_interface_member ((Interface) parent);
				}
			} catch (ParseError e) {
				int r;
				while (true) {
					r = recover ();
					if (r == RecoveryState.STATEMENT_BEGIN) {
						next ();
					} else {
						break;
					}
				}
				if (r == RecoveryState.EOF) {
					return;
				}
			}
		}
		if (!root) {
			if (!accept (TokenType.DEDENT)) {
				// only report error if it's not a secondary error
				if (Report.get_errors () == 0) {
					Report.error (get_current_src (), "expected dedent");
				}
			}
		}
	}

	enum RecoveryState {
		EOF,
		DECLARATION_BEGIN,
		STATEMENT_BEGIN
	}

	RecoveryState recover () {
		while (current () != TokenType.EOF) {
			switch (current ()) {
			case TokenType.CLASS:
			case TokenType.CONST:
			case TokenType.CONSTRUCT:
			case TokenType.INIT:
			case TokenType.DEF:
			case TokenType.DELEGATE:
			case TokenType.ENUM:
			case TokenType.ERRORDOMAIN:
			case TokenType.FINAL:
			case TokenType.INTERFACE:
			case TokenType.NAMESPACE:
			case TokenType.PROP:
			case TokenType.EVENT:
			case TokenType.STRUCT:
				return RecoveryState.DECLARATION_BEGIN;
			case TokenType.BREAK:
			case TokenType.CASE:
			case TokenType.CONTINUE:
			case TokenType.DELETE:
			case TokenType.DO:
			case TokenType.FOR:
			case TokenType.FOREACH:
			case TokenType.IF:
			case TokenType.LOCK:
			case TokenType.RETURN:
			case TokenType.RAISE:
			case TokenType.TRY:
			case TokenType.VAR:
			case TokenType.WHILE:
				return RecoveryState.STATEMENT_BEGIN;
			default:
				next ();
				break;
			}
		}
		return RecoveryState.EOF;
	}

	Namespace parse_namespace_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		expect (TokenType.NAMESPACE);
		var sym = parse_symbol_name ();
		var ns = new Namespace (sym.name, get_src_com (begin));
		set_attributes (ns, attrs);
		expect (TokenType.EOL);
		parse_declarations (ns);
		return ns;
	}

	void parse_namespace_member (Namespace ns) throws ParseError {
		var sym = parse_declaration ();
		if (sym is Namespace) {
			ns.add_namespace ((Namespace) sym);
		} else if (sym is Class) {
			ns.add_class ((Class) sym);
		} else if (sym is Interface) {
			ns.add_interface ((Interface) sym);
		} else if (sym is Struct) {
			ns.add_struct ((Struct) sym);
		} else if (sym is Enum) {
			ns.add_enum ((Enum) sym);
		} else if (sym is ErrorDomain) {
			ns.add_error_domain ((ErrorDomain) sym);
		} else if (sym is Delegate) {
			ns.add_delegate ((Delegate) sym);
		} else if (sym is Method) {
			var method = (Method) sym;
			method.binding = MemberBinding.STATIC;
			ns.add_method (method);
		} else if (sym is Field) {
			var field = (Field) sym;
			field.binding = MemberBinding.STATIC;
			ns.add_field (field);
		} else if (sym is Constant) {
			ns.add_constant ((Constant) sym);
		} else if (sym == null) {
			// workaround for current limitation of exception handling
			throw new ParseError.SYNTAX ("syntax error in declaration");
		} else {
			Report.error (sym.source_reference, "unexpected declaration in namespace");
		}
		scanner.source_file.add_node (sym);
	}


	void add_uses_clause () throws ParseError {
		var begin = get_location ();
		var sym = parse_symbol_name ();
		var ns_ref = new NamespaceReference (sym.name, get_src (begin));

		scanner.source_file.add_using_directive (ns_ref);
	}

	void parse_using_directives () throws ParseError {
		while (accept (TokenType.USES)) {
			var begin = get_location ();

			if (accept_block ()) {
				expect (TokenType.INDENT);

				while (current () != TokenType.DEDENT && current () != TokenType.EOF) {
					add_uses_clause ();
					expect (TokenType.EOL);	
				}

				expect (TokenType.DEDENT);
			} else {
				do {
					add_uses_clause ();	
				} while (accept (TokenType.COMMA));

				expect_terminator ();
			}
		}
	}

	Symbol parse_class_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		expect (TokenType.CLASS);

		var flags = parse_type_declaration_modifiers ();

		var sym = parse_symbol_name ();
		var type_param_list = parse_type_parameter_list ();
		var base_types = new ArrayList<DataType> ();
		if (accept (TokenType.COLON)) {
			do {
				base_types.add (parse_type ());
			} while (accept (TokenType.COMMA));
		}

		accept (TokenType.EOL);

		var cl = new Class (sym.name, get_src_com (begin));

		if (ModifierFlags.PRIVATE in flags) {
			cl.access = SymbolAccessibility.PRIVATE;
		} else {
			/* class must always be Public unless its name starts wtih underscore */
			if (sym.name[0] == '_') {
				cl.access = SymbolAccessibility.PRIVATE;
			} else {
				cl.access = SymbolAccessibility.PUBLIC;
			}
		}

		if (ModifierFlags.ABSTRACT in flags) {
			cl.is_abstract = true;
		}
		if (ModifierFlags.STATIC in flags) {
			cl.is_static = true;
		}
		set_attributes (cl, attrs);
		foreach (TypeParameter type_param in type_param_list) {
			cl.add_type_parameter (type_param);
		}
		foreach (DataType base_type in base_types) {
			cl.add_base_type (base_type);
		}

		class_name = cl.name;

		parse_declarations (cl);

		// ensure there is always a default construction method
		if (!scanner.source_file.external_package
		    && !cl.is_static
		    && cl.default_construction_method == null) {
			var m = new CreationMethod (cl.name, null, cl.source_reference);
			m.binding = MemberBinding.STATIC;
			m.access = SymbolAccessibility.PUBLIC;
			m.body = new Block (cl.source_reference);
			cl.add_method (m);
		}

		Symbol result = cl;
		while (sym.inner != null) {
			sym = sym.inner;
			var ns = new Namespace (sym.name, cl.source_reference);
			if (result is Namespace) {
				ns.add_namespace ((Namespace) result);
			} else {
				ns.add_class ((Class) result);
				scanner.source_file.add_node (result);
			}
			result = ns;
		}
		return result;
	}

	void parse_class_member (Class cl) throws ParseError {
		var sym = parse_declaration ();
		if (sym is Class) {
			cl.add_class ((Class) sym);
		} else if (sym is Struct) {
			cl.add_struct ((Struct) sym);
		} else if (sym is Enum) {
			cl.add_enum ((Enum) sym);
		} else if (sym is Delegate) {
			cl.add_delegate ((Delegate) sym);
		} else if (sym is Method) {
			cl.add_method ((Method) sym);
		} else if (sym is Vala.Signal) {
			cl.add_signal ((Vala.Signal) sym);
		} else if (sym is Field) {
			cl.add_field ((Field) sym);
		} else if (sym is Constant) {
			cl.add_constant ((Constant) sym);
		} else if (sym is Property) {
			cl.add_property ((Property) sym);
		} else if (sym is Constructor) {
			var c = (Constructor) sym;
			if (c.binding == MemberBinding.INSTANCE) {
				cl.constructor = c;
			 } else if (c.binding == MemberBinding.CLASS) {
				cl.class_constructor = c;
			 } else {
			 	cl.static_constructor = c;
			 }
		} else if (sym is Destructor) {
			cl.destructor = (Destructor) sym;
		} else if (sym == null) {
			// workaround for current limitation of exception handling
			throw new ParseError.SYNTAX ("syntax error in declaration");
		} else {
			Report.error (sym.source_reference, "unexpected declaration in class");
		}
	}

	Constant parse_constant_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();

		expect (TokenType.CONST);

		parse_member_declaration_modifiers ();

		string id = parse_identifier ();
		expect (TokenType.COLON);
		var type = parse_type (false);

		Expression initializer = null;
		if (accept (TokenType.ASSIGN)) {
			initializer = parse_variable_initializer ();
		}
		expect_terminator ();

		var c = new Constant (id, type, initializer, get_src_com (begin));
		c.access = get_access (id);
		set_attributes (c, attrs);
		return c;
	}

	Field parse_field_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		string id = parse_identifier ();
		expect (TokenType.COLON);

		var flags = parse_member_declaration_modifiers ();

		var type = parse_type ();

		var f = new Field (id, type, null, get_src_com (begin));

		if (ModifierFlags.PRIVATE in flags) {
			f.access = SymbolAccessibility.PRIVATE;
		} else {
			f.access = get_access (id);
		}

		set_attributes (f, attrs);

		if (accept (TokenType.ASSIGN)) {
			f.initializer = parse_expression ();
		}


		if (ModifierFlags.STATIC in flags) {
			f.binding = MemberBinding.STATIC;
		} else if (ModifierFlags.CLASS in flags) {
			f.binding = MemberBinding.CLASS;
		}

		expect_terminator ();

		return f;
	}

	InitializerList parse_initializer () throws ParseError {
		var begin = get_location ();
		expect (TokenType.OPEN_BRACE);
		var initializer = new InitializerList (get_src (begin));
		if (current () != TokenType.DEDENT) {
			do {
				initializer.append (parse_variable_initializer ());
			} while (accept (TokenType.COMMA));
		}
		expect (TokenType.CLOSE_BRACE);
		return initializer;
	}

	Expression parse_variable_initializer () throws ParseError {
		if (current () == TokenType.OPEN_BRACE) {
			var expr = parse_initializer ();
			return expr;
		} else {
			var expr = parse_expression ();
			return expr;
		}
	}

	Method parse_method_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		DataType type = new VoidType ();
		expect (TokenType.DEF);
		var flags = parse_member_declaration_modifiers ();

		string id = parse_identifier ();

		var params = new ArrayList<FormalParameter> ();
		expect (TokenType.OPEN_PARENS);

		if (current () != TokenType.CLOSE_PARENS) {
			do {
				var param = parse_parameter ();
				params.add (param);
			} while (accept (TokenType.COMMA));
		}

		expect (TokenType.CLOSE_PARENS);


		/* deal with return value */
		if (accept (TokenType.COLON)) {
			type = parse_type ();
			parse_type_parameter_list ();
		}


		var method = new Method (id, type, get_src_com (begin));
		if (ModifierFlags.PRIVATE in flags) {
			method.access = SymbolAccessibility.PRIVATE;
		} else {
			method.access = get_access (id);
		}


		set_attributes (method, attrs);

		foreach (FormalParameter param in params) {
			method.add_parameter (param);
		}

		if (accept (TokenType.RAISES)) {
			do {
				method.add_error_type (parse_type ());
			} while (accept (TokenType.COMMA));
		}


		if (ModifierFlags.STATIC in flags || id == "main") {
			method.binding = MemberBinding.STATIC;
		}
		if (ModifierFlags.ABSTRACT in flags) {
			method.is_abstract = true;
		}
		if (ModifierFlags.VIRTUAL in flags) {
			method.is_virtual = true;
		}
		if (ModifierFlags.OVERRIDE in flags) {
			method.overrides = true;
		}
		if (ModifierFlags.INLINE in flags) {
			method.is_inline = true;
		}

		expect (TokenType.EOL);

		var body_location = get_location ();


		/* "requires" and "ensures" if present will be at  start of the method body */
		if (accept (TokenType.INDENT)) {		
			if (accept (TokenType.REQUIRES)) {
			
				if (accept (TokenType.EOL) && accept (TokenType.INDENT)) {
					while (current() != TokenType.DEDENT) {
						method.add_precondition (parse_expression ());
						expect (TokenType.EOL);
					}
					
					expect (TokenType.DEDENT);
					accept_terminator ();
				} else {
				
					method.add_precondition (parse_expression ());
					expect_terminator ();
				
				}
				
			}

			if (accept (TokenType.ENSURES)) {
				if (accept (TokenType.EOL) && accept (TokenType.INDENT)) {
					while (current() != TokenType.DEDENT) {
						method.add_postcondition (parse_expression ());
						expect (TokenType.EOL);
					}

					expect (TokenType.DEDENT);
					accept_terminator ();
				} else {
					method.add_postcondition (parse_expression ());
					expect_terminator ();
				}
			}
		}

		rollback (body_location);


		if (accept_block ()) {
			method.body = parse_block ();
		}
		return method;
	}

	Property parse_property_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		var readonly = false;

		expect (TokenType.PROP);

		var flags = parse_member_declaration_modifiers ();

		readonly =  accept (TokenType.READONLY);

		string id = parse_identifier ();
		expect (TokenType.COLON);

		bool is_weak = accept (TokenType.WEAK);
		var type = parse_type (false);

		var prop = new Property (id, type, null, null, get_src_com (begin));
		if (ModifierFlags.PRIVATE in flags) {
			prop.access = SymbolAccessibility.PRIVATE;
		} else {
			prop.access = get_access (id);
		}

		set_attributes (prop, attrs);
		if (ModifierFlags.ABSTRACT in flags) {
			prop.is_abstract = true;
		}
		if (ModifierFlags.VIRTUAL in flags) {
			prop.is_virtual = true;
		}
		if (ModifierFlags.OVERRIDE in flags) {
			prop.overrides = true;
		}

		if (accept (TokenType.ASSIGN)) {
			prop.default_expression = parse_expression ();
		}


		if (accept_block ()) {
			expect (TokenType.INDENT);
			while (current () != TokenType.DEDENT) {
				var accessor_begin = get_location ();
				parse_attributes ();
				var accessor_access = SymbolAccessibility.PUBLIC;
				if (accept (TokenType.GET)) {
					if (prop.get_accessor != null) {
						throw new ParseError.SYNTAX (get_error ("property get accessor already defined"));
					}
					Block block = null;
					if (accept_block ()) {
						block = parse_block ();
					}
					prop.get_accessor = new PropertyAccessor (true, false, false, block, get_src (accessor_begin));
					prop.get_accessor.access = SymbolAccessibility.PUBLIC;
				} else {
					bool _construct;
					if (accept (TokenType.SET)) {
						if (readonly) {
							throw new ParseError.SYNTAX (get_error ("set block not allowed for a read only property"));
						}
						_construct = accept (TokenType.CONSTRUCT);
					} else if (accept (TokenType.CONSTRUCT)) {
						_construct = true;
					} else if (!accept (TokenType.EOL)) {
						throw new ParseError.SYNTAX (get_error ("expected get, set, or construct"));
					}

					if (prop.set_accessor != null) {
						throw new ParseError.SYNTAX (get_error ("property set accessor already defined"));
					}

					Block block = null;
					if (accept_block ()) {
						block = parse_block ();
					}
					prop.set_accessor = new PropertyAccessor (false, !readonly, _construct, block, get_src (accessor_begin));
					prop.set_accessor.access = SymbolAccessibility.PUBLIC;
				}
			}
			accept (TokenType.EOL);
			expect (TokenType.DEDENT);
		} else {
			prop.get_accessor = new PropertyAccessor (true, false, false, null, get_src (begin));
			prop.get_accessor.access = SymbolAccessibility.PUBLIC;

			if (!readonly) {
				prop.set_accessor = new PropertyAccessor (false, true, false, null, get_src (begin));
				prop.set_accessor.access = SymbolAccessibility.PUBLIC;
			
			}

			expect_terminator ();
		}

		if (!prop.is_abstract && !scanner.source_file.external_package) {
			var needs_var = (readonly && (prop.get_accessor != null && prop.get_accessor.body == null));

			if (!needs_var) {
				needs_var = (prop.get_accessor != null && prop.get_accessor.body == null) || (prop.set_accessor != null && prop.set_accessor.body == null);	
			}

			if (needs_var) {
				/* automatic property accessor body generation */
				var field_type = prop.property_type.copy ();
				field_type.value_owned = !is_weak;
				prop.field = new Field ("_%s".printf (prop.name), field_type, prop.default_expression, prop.source_reference);
				prop.field.access = SymbolAccessibility.PRIVATE;
			}
		}

		return prop;
	}

	Vala.Signal parse_signal_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		DataType type;

		expect (TokenType.EVENT);
		var flags = parse_member_declaration_modifiers ();
		string id = parse_identifier ();


		var params = new ArrayList<FormalParameter> ();

		expect (TokenType.OPEN_PARENS);
		if (current () != TokenType.CLOSE_PARENS) {
			do {
				var param = parse_parameter ();
				params.add (param);
			} while (accept (TokenType.COMMA));
		}
		expect (TokenType.CLOSE_PARENS);

		if (accept (TokenType.COLON)) {
			type = parse_type ();
		} else {
			type = new VoidType ();
		}

		var sig = new Vala.Signal (id, type, get_src_com (begin));
		if (ModifierFlags.PRIVATE in flags) {
			sig.access = SymbolAccessibility.PRIVATE;
		} else {
			sig.access = get_access (id);
		}

		set_attributes (sig, attrs);
		
		foreach (FormalParameter formal_param in params) {
			sig.add_parameter (formal_param);
		}

		expect_terminator ();
		return sig;
	}

	Constructor parse_constructor_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();

		expect (TokenType.INIT);
		var flags = parse_member_declaration_modifiers ();

		var c = new Constructor (get_src_com (begin));
		if (ModifierFlags.STATIC in flags) {
			c.binding = MemberBinding.STATIC;
		} else if (ModifierFlags.CLASS in flags) {
			c.binding = MemberBinding.CLASS;
		}

		accept_block ();
		c.body = parse_block ();
		return c;
	}

	Destructor parse_destructor_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		expect (TokenType.FINAL);
		var d = new Destructor (get_src_com (begin));
		accept_block ();
		d.body = parse_block ();
		return d;
	}

	Symbol parse_struct_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();

		expect (TokenType.STRUCT);
		var flags = parse_type_declaration_modifiers ();
		var sym = parse_symbol_name ();
		var type_param_list = parse_type_parameter_list ();
		var base_types = new ArrayList<DataType> ();
		if (accept (TokenType.COLON)) {
			do {
				base_types.add (parse_type ());
			} while (accept (TokenType.COMMA));
		}
		var st = new Struct (sym.name, get_src_com (begin));
		if (ModifierFlags.PRIVATE in flags) {
			st.access = SymbolAccessibility.PRIVATE;
		} else {
			st.access = get_access (sym.name);
		}
		set_attributes (st, attrs);
		foreach (TypeParameter type_param in type_param_list) {
			st.add_type_parameter (type_param);
		}
		foreach (DataType base_type in base_types) {
			st.add_base_type (base_type);
		}

		expect (TokenType.EOL);

		parse_declarations (st);

		Symbol result = st;
		while (sym.inner != null) {
			sym = sym.inner;
			var ns = new Namespace (sym.name, st.source_reference);
			if (result is Namespace) {
				ns.add_namespace ((Namespace) result);
			} else {
				ns.add_struct ((Struct) result);
				scanner.source_file.add_node (result);
			}
			result = ns;
		}
		return result;
	}

	void parse_struct_member (Struct st) throws ParseError {
		var sym = parse_declaration ();
		if (sym is Method) {
			st.add_method ((Method) sym);
		} else if (sym is Field) {
			st.add_field ((Field) sym);
		} else if (sym is Constant) {
			st.add_constant ((Constant) sym);
		} else if (sym == null) {
			// workaround for current limitation of exception handling
			throw new ParseError.SYNTAX ("syntax error in declaration");
		} else {
			Report.error (sym.source_reference, "unexpected declaration in struct");
		}
	}

	Symbol parse_interface_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();

		expect (TokenType.INTERFACE);
		var flags = parse_type_declaration_modifiers ();
		var sym = parse_symbol_name ();
		var type_param_list = parse_type_parameter_list ();
		var base_types = new ArrayList<DataType> ();
		if (accept (TokenType.COLON)) {
			do {
				base_types.add (parse_type ());
			} while (accept (TokenType.COMMA));
		}
		var iface = new Interface (sym.name, get_src_com (begin));
		if (ModifierFlags.PRIVATE in flags) {
			iface.access = SymbolAccessibility.PRIVATE;
		} else {
			iface.access = get_access (sym.name);
		}
		
		set_attributes (iface, attrs);
		foreach (TypeParameter type_param in type_param_list) {
			iface.add_type_parameter (type_param);
		}
		foreach (DataType base_type in base_types) {
			iface.add_prerequisite (base_type);
		}


		expect (TokenType.EOL);
		
		parse_declarations (iface);
		

		Symbol result = iface;
		while (sym.inner != null) {
			sym = sym.inner;
			var ns = new Namespace (sym.name, iface.source_reference);
			if (result is Namespace) {
				ns.add_namespace ((Namespace) result);
			} else {
				ns.add_interface ((Interface) result);
				scanner.source_file.add_node (result);
			}
			result = ns;
		}
		return result;
	}

	void parse_interface_member (Interface iface) throws ParseError {
		var sym = parse_declaration ();
		if (sym is Class) {
			iface.add_class ((Class) sym);
		} else if (sym is Struct) {
			iface.add_struct ((Struct) sym);
		} else if (sym is Enum) {
			iface.add_enum ((Enum) sym);
		} else if (sym is Delegate) {
			iface.add_delegate ((Delegate) sym);
		} else if (sym is Method) {
			iface.add_method ((Method) sym);
		} else if (sym is Vala.Signal) {
			iface.add_signal ((Vala.Signal) sym);
		} else if (sym is Field) {
			iface.add_field ((Field) sym);
		} else if (sym is Property) {
			iface.add_property ((Property) sym);
		} else if (sym == null) {
			// workaround for current limitation of exception handling
			throw new ParseError.SYNTAX ("syntax error in declaration");
		} else {
			Report.error (sym.source_reference, "unexpected declaration in interface");
		}
	}

	Symbol parse_enum_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		expect (TokenType.ENUM);
		var flags = parse_type_declaration_modifiers ();

		var sym = parse_symbol_name (); 
		var en = new Enum (sym.name, get_src_com (begin));
		if (ModifierFlags.PRIVATE in flags) {
			en.access = SymbolAccessibility.PRIVATE;
		} else {
			en.access = get_access (sym.name);
		}
		set_attributes (en, attrs);

		expect (TokenType.EOL);
		expect (TokenType.INDENT);
		do {
			if (current () == TokenType.DEDENT) {
				// allow trailing comma
				break;
			}
			var value_attrs = parse_attributes ();
			var value_begin = get_location (); 
			string id = parse_identifier ();
			
			var ev = new EnumValue (id, get_src (value_begin));
			set_attributes (ev, value_attrs);
			
			if (accept (TokenType.ASSIGN)) {
				ev.value = parse_expression ();
			}
			en.add_value (ev);
			expect (TokenType.EOL);
		} while (true);
		
		expect (TokenType.DEDENT);

		Symbol result = en;
		while (sym.inner != null) {
			sym = sym.inner;
			var ns = new Namespace (sym.name, en.source_reference);
			if (result is Namespace) {
				ns.add_namespace ((Namespace) result);
			} else {
				ns.add_enum ((Enum) result);
				scanner.source_file.add_node (result);
			}
			result = ns;
		}
		return result;
	}

	Symbol parse_errordomain_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		expect (TokenType.ERRORDOMAIN);
		var flags = parse_type_declaration_modifiers ();

		var sym = parse_symbol_name ();
		var ed = new ErrorDomain (sym.name, get_src_com (begin));
		if (ModifierFlags.PRIVATE in flags) {
			ed.access = SymbolAccessibility.PRIVATE;
		} else {
			ed.access = get_access (sym.name);
		}

		set_attributes (ed, attrs);

		expect (TokenType.EOL);
		expect (TokenType.INDENT);

		do {
			if (current () == TokenType.DEDENT) {
				// allow trailing comma
				break;
			}
			var code_attrs = parse_attributes ();
			string id = parse_identifier ();

			var ec = new ErrorCode (id);
			set_attributes (ec, code_attrs);
			if (accept (TokenType.ASSIGN)) {
				ec.value = parse_expression ();
			}
			ed.add_code (ec);
			accept (TokenType.EOL);
		} while (true);
		
		
		expect (TokenType.DEDENT);

		Symbol result = ed;
		while (sym.inner != null) {
			sym = sym.inner;
			var ns = new Namespace (sym.name, ed.source_reference);
			
			if (result is Namespace) {
				ns.add_namespace ((Namespace) result);
			} else {
				ns.add_error_domain ((ErrorDomain) result);
				scanner.source_file.add_node (result);
			}
			result = ns;
		}
		return result;
	}

	ModifierFlags parse_type_declaration_modifiers () {
		ModifierFlags flags = 0;
		while (true) {
			switch (current ()) {
			case TokenType.ABSTRACT:
				next ();
				flags |= ModifierFlags.ABSTRACT;
				break;

			case TokenType.EXTERN:
				next ();
				flags |= ModifierFlags.EXTERN;
				break;

			case TokenType.STATIC:
				next ();
				flags |= ModifierFlags.STATIC;
				break;

			case TokenType.PRIVATE:
				next ();
				flags |= ModifierFlags.PRIVATE;
				break;

			default:
				return flags;
			}
		}
		return flags;
	}

	ModifierFlags parse_member_declaration_modifiers () {
		ModifierFlags flags = 0;
		while (true) {
			switch (current ()) {
			case TokenType.ABSTRACT:
				next ();
				flags |= ModifierFlags.ABSTRACT;
				break;
			case TokenType.CLASS:
				next ();
				flags |= ModifierFlags.CLASS;
				break;
			case TokenType.EXTERN:
				next ();
				flags |= ModifierFlags.EXTERN;
				break;
			case TokenType.INLINE:
				next ();
				flags |= ModifierFlags.INLINE;
				break;
			case TokenType.OVERRIDE:
				next ();
				flags |= ModifierFlags.OVERRIDE;
				break;
			case TokenType.STATIC:
				next ();
				flags |= ModifierFlags.STATIC;
				break;
			case TokenType.VIRTUAL:
				next ();
				flags |= ModifierFlags.VIRTUAL;
				break;
			case TokenType.PRIVATE:
				next ();
				flags |= ModifierFlags.PRIVATE;
				break;
			default:
				return flags;
			}
		}
		return flags;
	}

	FormalParameter parse_parameter () throws ParseError {
		var attrs = parse_attributes ();
		var begin = get_location ();
		if (accept (TokenType.ELLIPSIS)) {
			// varargs
			return new FormalParameter.with_ellipsis (get_src (begin));
		}

		var direction = ParameterDirection.IN;
		if (accept (TokenType.OUT)) {
			direction = ParameterDirection.OUT;
		} else if (accept (TokenType.REF)) {
			direction = ParameterDirection.REF;
		}

		string id = parse_identifier ();

		expect (TokenType.COLON);

		DataType type;
		if (direction == ParameterDirection.IN) {
			 type = parse_type (false);
		} else {
			 type = parse_type (true);
		}

		var param = new FormalParameter (id, type, get_src (begin));
		set_attributes (param, attrs);
		param.direction = direction;
		param.construct_parameter = false;
		if (accept (TokenType.ASSIGN)) {
			param.default_expression = parse_expression ();
		}
		return param;
	}

	CreationMethod parse_creation_method_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		CreationMethod method;

		expect (TokenType.CONSTRUCT);

		var flags = parse_member_declaration_modifiers ();


		if (accept (TokenType.OPEN_PARENS)) {
			/* create default name using class name */
			method = new CreationMethod (class_name, null, get_src_com (begin));
		} else {
			var sym = parse_symbol_name ();
			if (sym.inner == null) {
			
				if (sym.name != class_name) {
					method = new CreationMethod (class_name, sym.name, get_src_com (begin));
				} else {
					method = new CreationMethod (sym.name, null, get_src_com (begin));
				}
			} else {
				method = new CreationMethod (sym.inner.name, sym.name, get_src_com (begin));
			}
			expect (TokenType.OPEN_PARENS);
		}


		if (current () != TokenType.CLOSE_PARENS) {
			do {
				var param = parse_parameter ();
				method.add_parameter (param);
			} while (accept (TokenType.COMMA));
		}
		expect (TokenType.CLOSE_PARENS);
		if (accept (TokenType.RAISES)) {
			do {
				method.add_error_type (parse_type ());
			} while (accept (TokenType.COMMA));
		}
		method.access = SymbolAccessibility.PUBLIC;
		set_attributes (method, attrs);
		method.binding = MemberBinding.STATIC;

		if (accept_block ()) {
			method.body = parse_block ();
		}
		
		return method;
	}

	Symbol parse_delegate_declaration (Gee.List<Attribute>? attrs) throws ParseError {
		var begin = get_location ();
		DataType type;

		expect (TokenType.DELEGATE);

		var flags = parse_member_declaration_modifiers ();

		var sym = parse_symbol_name ();

		var type_param_list = parse_type_parameter_list ();


		var params = new ArrayList<FormalParameter> ();

		expect (TokenType.OPEN_PARENS);
		if (current () != TokenType.CLOSE_PARENS) {
			do {
				var param = parse_parameter ();
				params.add (param);
			} while (accept (TokenType.COMMA));
		}
		expect (TokenType.CLOSE_PARENS);

		if (accept (TokenType.COLON)) {
			type = parse_type ();
			
		} else {
			type = new VoidType ();
		}

		if (accept (TokenType.RAISES)) {
			do {
				parse_type ();
			} while (accept (TokenType.COMMA));
		}

		expect_terminator ();

		var d = new Delegate (sym.name, type, get_src_com (begin));
		if (ModifierFlags.PRIVATE in flags) {
			d.access = SymbolAccessibility.PRIVATE;
		} else {
			d.access = get_access (sym.name);
		}

		set_attributes (d, attrs);

		foreach (TypeParameter type_param in type_param_list) {
			d.add_type_parameter (type_param);
		}

		foreach (FormalParameter formal_param in params) {
			d.add_parameter (formal_param);
		}

		if (!(ModifierFlags.STATIC in flags)) {
			d.has_target = true;
		}


		Symbol result = d;
		while (sym.inner != null) {
			sym = sym.inner;
			var ns = new Namespace (sym.name, d.source_reference);

			if (result is Namespace) {
				ns.add_namespace ((Namespace) result);
			} else {
				ns.add_delegate ((Delegate) result);
				scanner.source_file.add_node (result);
			}
			result = ns;
		}
		return result;
	}

	Gee.List<TypeParameter> parse_type_parameter_list () throws ParseError {
		var list = new ArrayList<TypeParameter> ();
		if (accept (TokenType.OF)) {
			do {
				var begin = get_location ();
				string id = parse_identifier ();
				list.add (new TypeParameter (id, get_src (begin)));
			} while (accept (TokenType.COMMA));

		}
		return list;
	}

	void skip_type_argument_list () throws ParseError {
		if (accept (TokenType.OF)) {
			do {
				skip_type ();
			} while (accept (TokenType.COMMA));
		}
	}

	// try to parse type argument list
	Gee.List<DataType>? parse_type_argument_list (bool maybe_expression) throws ParseError {
		var begin = get_location ();
		if (accept (TokenType.OF)) {
			var list = new ArrayList<DataType> ();
			do {
				switch (current ()) {
				case TokenType.VOID:
				case TokenType.DYNAMIC:
				case TokenType.WEAK:
				case TokenType.IDENTIFIER:
					var type = parse_type ();

					list.add (type);
					break;
				default:
					rollback (begin);
					return null;
				}
			} while (accept (TokenType.COMMA));

			return list;
		}
		return null;
	}

	MemberAccess parse_member_name () throws ParseError {
		var begin = get_location ();
		MemberAccess expr = null;
		do {
			string id = parse_identifier ();
			Gee.List<DataType> type_arg_list = parse_type_argument_list (false);
			expr = new MemberAccess (expr, id, get_src (begin));
			if (type_arg_list != null) {
				foreach (DataType type_arg in type_arg_list) {
					expr.add_type_argument (type_arg);
				}
			}
		} while (accept (TokenType.DOT));
		return expr;
	}

	bool is_declaration_keyword (TokenType type) {
		switch (type) {
		case TokenType.CLASS:
		case TokenType.CONST:
		case TokenType.DEF:
		case TokenType.DELEGATE:
		case TokenType.ENUM:
		case TokenType.ERRORDOMAIN:
		case TokenType.EVENT:
		case TokenType.FINAL:
		case TokenType.INIT:
		case TokenType.INTERFACE:
		case TokenType.NAMESPACE:
		case TokenType.OVERRIDE:
		case TokenType.PROP:
		case TokenType.STRUCT:
			return true;
		default:
			return false;
		}
	}
}
