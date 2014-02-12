module vibe.extensions.slim;

import std.performance.array : Appender;

import vibe.core.log;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;

void slimTemplate(string templateFile, ALIASES...)(HTTPServerRequest req, HTTPServerResponse res)
{
	import std.localization : localize;

	static string __slim_toString(T)(T val)
	{
		static if (is(T == string))
			return val;
		else static if(__traits(compiles, val.opCast!string()))
			return cast(string)val;
		else static if(__traits(compiles, val.toString()))
			return val.toString();
		else
			return to!string(val);
	}

	template localAliases(int i, ALIASES...)
	{
		import std.conv : to;

		static if( i < ALIASES.length )
			enum string localAliases = "alias ALIASES[" ~ to!string(i) ~ "] " ~ __traits(identifier, ALIASES[i]) ~ ";\n" ~ localAliases!(i + 1, ALIASES);
		else
			enum string localAliases = "";
	}
	mixin(localAliases!(0, ALIASES));
	Appender!string buf = Appender!string();

	pragma(msg, "Compiling template file " ~ templateFile);
	enum emissionCode = parseSlimTemplate(import(templateFile), genFileTable!templateFile);
	//pragma(msg, emissionCode);

	static struct __slim_Root
	{
		static void __slim_emptyBlock(ref Appender!string buf) { }

		mixin(emissionCode);
	}
	__slim_Root.__slim_main(buf);

	res.writeBody(buf.data, "text/html; charset=UTF-8");
}

private:

@property string[string] genFileTable(string baseFileName)()
{
	enum baseFileContents = import(baseFileName);
	enum workingContents = (baseFileContents.length >= 3 && baseFileContents[0..3] == x"EF BB BF") ? baseFileContents[3..$] : baseFileContents;
	static @property void staticEach(alias vals, alias action, params...)()
	{
		static if (vals.length == 0) { } // Do nothing
		else static if (vals.length == 1)
		{
			action!(vals[0], params)();
		}
		else
		{
			action!(vals[0], params)();
			staticEach!(vals[1..$], action, params);
		}
	}
	static string nextLine(ref string input)
	{
		if (input.length == 0)
			return "";
		auto start = input;
		while (input.length > 0 && input[0] != '\n' && input[0] != '\r')
			input = input[1..$];
		string ret = start[0..start.length - input.length];
		while (input.length > 0 && (input[0] == '\n' || input[0] == '\r'))
			input = input[1..$];
		if (ret == "")
			ret = " ";
		return ret;
	}
	static string trimStart(string input)
	{
		while (input.length > 0 && (input[0] == ' ' || input[0] == '\t'))
			input = input[1..$];
		return input;
	}
	static string firstIdentifier(string input)
	{
		auto start = input;
		while (input.length > 0)
		{
			switch (input[0])
			{
				case '_':
				case 'a': .. case 'z':
				case 'A': .. case 'Z':
					input = input[1..$];
					break;
				default:
					goto Return;
			}
		}
	Return:
		return start[0..start.length - input.length];
	}
	static string secondIdentifier(string input)
	{
		while (input.length > 0)
		{
			switch (input[0])
			{
				case '_':
				case 'a': .. case 'z':
				case 'A': .. case 'Z':
					input = input[1..$];
					break;
				default:
					goto EndOfFirst;
			}
		}
	EndOfFirst:
		input = trimStart(input);
		auto start = input;

		while (input.length > 0)
		{
			switch (input[0])
			{
				case '_':
				case 'a': .. case 'z':
				case 'A': .. case 'Z':
					input = input[1..$];
					break;
				default:
					goto Return;
			}
		}
	Return:
		return start[0..start.length - input.length];
	}
	static string[] extractDependencies(string fileContents)
	{
		string[] deps;
		auto input = fileContents;
		auto line = " ";
		while (line != "")
		{
			auto firstIdent = firstIdentifier(trimStart(line));
			if (firstIdent == "extends" || firstIdent == "mixin")
				deps ~= secondIdentifier(trimStart(line));
			line = nextLine(input);
		}
		return deps;
	}
	enum directDependencies = extractDependencies(workingContents);
	string[string] ret;
	static void addDependencies(string dep, alias ret)()
	{
		ret[dep] = import(dep ~ ".st");
		foreach (k, v; genFileTable!(dep ~ ".st"))
			ret[k] = v;
	}
	staticEach!(directDependencies, addDependencies, ret);
	return ret;
}

// TODO: Setup an exception system such that it is possible to output where
//       the error actually occurred.
string parseSlimTemplate(string text, string[string] fileTable)
{
	import std.performance.conv : to;

	enum MaxBlockDepth = 255;
	enum MaxTemplateParameterCount = 255;

	enum TokenType
	{
		eof,
		eol,
		equal,
		identifier,
		lParen,
		rParen,
		comma,
		question,
		cssClass,
		elementID,
		code,
		string,
		whitespace,
		docType,
		filter,
	}
	
	static struct Token
	{
		TokenType type;
		string stringValue;
		
		this(TokenType type, string strVal = "")
		{
			this.type = type;
			this.stringValue = strVal;
		}
		
		string toString()
		{
			import std.conv : to;
			
			return to!string(type) ~ ":" ~ stringValue;
		}
	}

	enum WriteState
	{
		none,
		string,
		code,
	}

	static struct WriteContext
	{
		WriteState curState = WriteState.none;
		Appender!string output;
		
		void setState(WriteState state)
		{
			if (curState != state)
			{
				final switch (curState)
				{
					case WriteState.string:
						output.put("\");\n");
						break;
					case WriteState.code:
						break;
					case WriteState.none:
						break;
				}
				final switch (state) with (WriteState)
				{
					case string:
						output.put(`buf.put("`);
						break;
					case code:
					case none:
						break;
				}
				curState = state;
			}
		}

		void writeEscapedStringContents(string str)
		{
			setState(WriteState.string);
			foreach (c; str)
			{
				switch (c)
				{
					case '\r':
						output.put("\r");
						break;
					case '\n':
						output.put("\n");
						break;
					case '"':
					case '\\':
						output.put('\\');
						goto default;
					default:
						output.put(c);
						break;
				}
			}
		}
		
		void writeCode(string str)
		{
			setState(WriteState.code);
			auto cur = str;
			while (cur.length > 0)
			{
				if (cur[0] != '$' || cur.length == 1)
				{
					output.put(cur[0]);
					cur = cur[1..$];
					continue;
				}
				// We're starting a localized string...
				cur = cur[1..$];
				bool quotedString = false;
				bool dynString = false;
				if (cur[0] == '"')
				{
					quotedString = true;
					cur = cur[1..$];
				}
				else if (cur[0] == '(')
				{
					dynString = true;
					cur = cur[1..$];
				}
				
				auto start = cur;
				while (cur.length > 0)
				{
					switch (cur[0])
					{
						case '_':
						case 'a': .. case 'z':
						case 'A': .. case 'Z':
							cur = cur[1..$];
							break;
						case '\\':
							if (!quotedString)
								goto default;
							if (cur.length < 2)
								throw new Exception("Unexpected EOF!");
							cur = cur[2..$];
							break;
						case ')':
							if (dynString)
								goto WriteLocalizedString;
							goto default;
						case '"':
							if (!quotedString)
								goto default;
							goto WriteLocalizedString;
						default:
							if (!quotedString && !dynString)
								goto WriteLocalizedString;
							else
								cur = cur[1..$];
							break;
					}
				}
				if (quotedString || dynString)
					throw new Exception("Unexpected EOF!");
			WriteLocalizedString:
				auto stringToLocalize = start[0..$ - cur.length];
				if (quotedString || dynString)
					cur = cur[1..$]; // Skip the closing quote.
				output.put(`localize(`);
				if (!dynString)
					output.put(`"`);
				output.put(stringToLocalize);
				if (!dynString)
					output.put(`"`);
				// TODO: Add a way to retrieve the language here.
				output.put(`, "")`);
			}
		}
		
		void writeEscapedRaw(string str)
		{
			setState(WriteState.string);
			auto input = str;
			while (input.length > 0)
			{
				switch (input[0])
				{
					case '#':
						if (input.length > 2 && input[1] == '{')
						{
							input = input[2..$];
							auto start = input;
							while (input.length > 0 && input[0] != '}')
								input = input[1..$];
							auto cod = start[0..start.length - input.length];
							writeCode("buf.put(__slim_toString(");
							writeCode(cod);
							writeCode("));\n");
							setState(WriteState.string);
						}
						else
							output.put('#');
						break;
					case '"':
						output.put("&quot;");
						break;
					case '\\':
						output.put(`\\`);
						break;
					default:
						output.put(input[0]);
						break;
				}
				input = input[1..$];
			}
		}
		
		void writeRaw(string str)
		{
			setState(WriteState.string);
			writeEscapedStringContents(str);
		}
	}

	enum BlockType
	{
		blockDefinition,
		code,
		element,
	}
	
	static struct Block
	{
		BlockType type;
		string name;
		Appender!string parentBuffer;
		WriteState state;
		bool inExtension;
		
		void writeClose(ref WriteContext dst, ref Appender!string rootBuffer, ref bool inExtension)
		{
			final switch (type) with (BlockType)
			{
				case blockDefinition:
					debug
					{
						dst.writeRaw("<!-- End ");
						dst.writeRaw(name);
						dst.writeRaw("-->");
					}
					dst.writeCode("}\n");
					dst.setState(WriteState.none);
					rootBuffer.put(dst.output.data);
					dst.output = parentBuffer;
					dst.curState = state;
					inExtension = this.inExtension;
					break;
				case code:
					dst.writeCode("}\n");
					break;
				case element:
					dst.writeRaw("</");
					dst.writeRaw(name);
					dst.writeRaw(">");
					break;
			}
		}
	}
	
	static struct ParseContext
	{
		string data;
		size_t indentLevel;
		string indentText;
		bool parseWhitespace = false;
		
		void consumeIndent(ref WriteContext dst, ref Appender!string rootBuffer, ref bool inExtension, ref FixedStack!(Block, MaxBlockDepth) blocks)
		{
			auto start = data;
			while (data.length > 0)
			{
				switch (data[0])
				{
					case ' ':
					case '\t':
						break;
						// If we hit either of these, then it means
						// the entire line is blank, so start again
						// on the next line.
					case '\r':
					case '\n':
						start = data[1..$];
						break;
					default:
						goto EndOfIndent;
				}
				data = data[1..$];
			}
			return;
		EndOfIndent:
			auto newLevel = countIndent(start[0..start.length - data.length]);
			if (cast(long)newLevel - cast(long)indentLevel > 1)
				throw new Exception("You can only increase indent by 1 level at a time!");
			indentLevel = newLevel;
			//			if (!__ctfe)
			//				logInfo("{%s:%s:%s}", indentLevel, start[0..start.length - data.length], blocks.count);
			while (indentLevel < blocks.count)
			{
				if (blocks.count)
					blocks.pop().writeClose(dst, rootBuffer, inExtension);
			}
		}
		
		size_t countIndent(string str)
		{
			if (str == "")
				return 0;
			if (indentText == "")
			{
				indentText = str;
				return indentText != "";
			}
			return str.length / indentText.length;
		}

		
		void skipWhitespace()
		{
			while (data.length > 0)
			{
				switch (data[0])
				{
					case ' ':
						break;
					default:
						return;
				}
				data = data[1..$];
			}
		}
		
		string readToEOL()
		{
			auto start = data;
			while (data.length > 0)
			{
				switch(data[0])
				{
					case '\r', '\n':
						goto Return;
					default:
						data = data[1..$];
						break;
				}
			}
		Return:
			return start[0..start.length - data.length];
		}
		
		@property Token expect(PossibleTypes...)()
		{
			auto tok = parseToken();
			foreach (t; PossibleTypes)
			{
				if (tok.type == t)
					return tok;
			}
			throw new Exception("Unexpected token " ~ tok.toString() ~ "!");
		}
		
		Token parseToken()
		{
		Restart:
			if (!parseWhitespace)
				skipWhitespace();
			if (data.length == 0)
				return Token(TokenType.eof);
			
			Token ret = void;
			auto start = data;
			switch (data[0])
			{
				case '/':
					if (data.length <= 1 && data[1] != '/')
						goto default;
					readToEOL();
					goto Restart; // Skip comments.
				case '!':
					if (data.length <= 2 || data[1] != '!' || data[2] != '!')
						goto default;
					data = data[3..$];
					skipWhitespace();
					ret = Token(TokenType.docType, readToEOL());
					break;
				case ' ':
				case '\t':
					skipWhitespace();
					ret = Token(TokenType.whitespace);
					break;
				case '\r':
				case '\n':
					if (data.length > 1 && (data[1] == '\r' || data[1] == '\n'))
						data = data[1..$];
					data = data[1..$];
					ret = Token(TokenType.eol);
					break;
				case '=':
					data = data[1..$];
					ret = Token(TokenType.equal);
					break;
				case '(':
					data = data[1..$];
					ret = Token(TokenType.lParen);
					break;
				case ')':
					data = data[1..$];
					ret = Token(TokenType.rParen);
					break;
				case '?':
					data = data[1..$];
					ret = Token(TokenType.question);
					break;
				case ',':
					data = data[1..$];
					ret = Token(TokenType.comma);
					break;
					
				case '\'':
					data = data[1..$];
					while (data.length > 0 && data[0] != '\'')
					{
						if (data[0] == '\\')
						{
							if (data.length == 1)
								throw new Exception("Unexpected EOF!");
							data = data[1..$];
						}
						data = data[1..$];
					}
					ret = Token(TokenType.string, start[1..start.length - data.length]);
					data = data[1..$];
					break;
				case '"':
					data = data[1..$];
					while (data.length > 0 && data[0] != '"')
					{
						if (data[0] == '\\')
						{
							if (data.length == 1)
								throw new Exception("Unexpected EOF!");
							data = data[1..$];
						}
						data = data[1..$];
					}
					ret = Token(TokenType.string, start[1..start.length - data.length]);
					data = data[1..$];
					break;
					
				case '-':
					while (data.length > 0 && data[0] != '\n')
						data = data[1..$];
					ret = Token(TokenType.code, start[1..start.length - data.length + 1]);
					break;
				case ':':
					data = data[1..$];
					while (data.length > 0)
					{
						switch (data[0])
						{
							case '_', '-':
							case 'a': .. case 'z':
							case 'A': .. case 'Z':
							case '0': .. case '9':
								data = data[1..$];
								break;
							default:
								goto ReturnFilterToken;
						}
					}
				ReturnFilterToken:
					ret = Token(TokenType.filter, start[1..start.length - data.length]);
					break;
				case '.':
					data = data[1..$];
					while (data.length > 0)
					{
						switch (data[0])
						{
							case '_', '-':
							case 'a': .. case 'z':
							case 'A': .. case 'Z':
							case '0': .. case '9':
								data = data[1..$];
								break;
							default:
								goto ReturnCSSClassToken;
						}
					}
				ReturnCSSClassToken:
					ret = Token(TokenType.cssClass, start[1..start.length - data.length]);
					break;
				case '#':
					data = data[1..$];
					while (data.length > 0)
					{
						switch (data[0])
						{
							case '_', '-':
							case 'a': .. case 'z':
							case 'A': .. case 'Z':
							case '0': .. case '9':
								data = data[1..$];
								break;
							default:
								goto ReturnElementIDToken;
						}
					}
				ReturnElementIDToken:
					ret = Token(TokenType.elementID, start[1..start.length - data.length]);
					break;
				case '_':
				case 'a': .. case 'z':
				case 'A': .. case 'Z':
					data = data[1..$];
					while (data.length > 0)
					{
						switch (data[0])
						{
							case '_':
							case 'a': .. case 'z':
							case 'A': .. case 'Z':
							case '0': .. case '9':
								data = data[1..$];
								break;
							default:
								goto ReturnIdentifierToken;
						}
					}
				ReturnIdentifierToken:
					ret = Token(TokenType.identifier, start[0..start.length - data.length]);
					break;
					
				default:
					throw new Exception("Unknown input character " ~ data[0] ~ "!");
			}
			//			if (!__ctfe)
			//				logInfo("|%s:%s|", ret.type, ret.stringValue);
			return ret;
		}
	}

	Appender!string rootBuffer = Appender!string();
	size_t[string] knownBlockDefinitions;

	string processFile(string contents)
	{
		if (contents.length >= 3 && contents[0..3] == x"EF BB BF")
			contents = contents[3..$];

		WriteContext dst;
		ParseContext ctx;
		FixedStack!(Block, MaxBlockDepth) blocks;
		ctx.data = contents;
		bool inExtension;

		void consumeIndent()
		{
			ctx.consumeIndent(dst, rootBuffer, inExtension, blocks);
		}

		consumeIndent();
		auto tok = ctx.parseToken();
		while (tok.type != TokenType.eof)
		{
			switch (tok.type)
			{
				case TokenType.elementID:
				case TokenType.identifier:
					bool isElement = false;
					bool isSingleElement = false;
					if (tok.type == TokenType.elementID)
					{
						dst.writeRaw(`<div id="`);
						dst.writeRaw(tok.stringValue);
						dst.writeRaw(`"`);
						blocks.push(Block(BlockType.element, "div"));
						isElement = true;
					}
					else
					{
						switch (tok.stringValue)
						{
							case "block":
								tok = ctx.expect!(TokenType.identifier);
								if (!inExtension)
								{
									dst.writeCode(tok.stringValue);
									dst.writeCode("(buf);\n");
								}
								blocks.push(Block(BlockType.blockDefinition, tok.stringValue, dst.output, dst.curState, inExtension));
								dst.curState = WriteState.none;
								dst.output = Appender!string();
								inExtension = false;
								dst.writeCode(`static void `);
								dst.writeCode(tok.stringValue);
								dst.writeCode("_");
								if (tok.stringValue !in knownBlockDefinitions)
									knownBlockDefinitions[tok.stringValue] = 0;
								auto id = ++knownBlockDefinitions[tok.stringValue];
								id.to!string(dst.output);
								dst.writeCode("(ref Appender!string buf)\n{\n");
								debug
								{
									dst.writeRaw("<!-- Begin Block ");
									dst.writeRaw(tok.stringValue);
									dst.writeRaw("-->");
								}
								break;
							case "template":
								tok = ctx.expect!(TokenType.identifier);
								blocks.push(Block(BlockType.blockDefinition, tok.stringValue, dst.output, dst.curState, inExtension));
								dst.curState = WriteState.none;
								dst.output = Appender!string();
								inExtension = false;
								dst.writeCode(`static void `);
								dst.writeCode(tok.stringValue);
								dst.writeCode("_");
								if (tok.stringValue !in knownBlockDefinitions)
									knownBlockDefinitions[tok.stringValue] = 0;
								auto id = ++knownBlockDefinitions[tok.stringValue];
								id.to!string(dst.output);
								dst.writeCode("(");
								ctx.expect!(TokenType.lParen);
								ctx.parseWhitespace = false;
								tok = ctx.expect!(TokenType.identifier, TokenType.rParen);
								FixedStack!(string, MaxTemplateParameterCount) params;
								size_t requiredParams;
								bool first = true;
								if (tok.type != TokenType.rParen) do
								{
									if (!first)
										tok = ctx.expect!(TokenType.identifier);
									params.push(tok.stringValue);
									tok = ctx.expect!(TokenType.question, TokenType.comma, TokenType.rParen);
									if (tok.type != TokenType.question)
									{
										requiredParams++;
										if (requiredParams != params.count)
											throw new Exception("No required parameters can be passed after an optional parameter is!");
									}
									else
										tok = ctx.expect!(TokenType.comma, TokenType.rParen);
									
									first = false;
								} while (tok.type != TokenType.rParen);
								ctx.parseWhitespace = true;
								if (params.count > 0)
								{
									dst.writeCode("ARGS...)(ref Appender!string buf)\n");
									dst.writeCode("if (ARGS.length <= ");
									params.count.to!string(dst.output);
									dst.writeCode(" && ARGS.length >= ");
									requiredParams.to!string(dst.output);
								}
								else
									dst.writeCode("ref Appender!string buf");
								dst.writeCode(")\n{\n");
								while (params.count > requiredParams)
								{
									size_t paramIdx = params.count - 1;
									string paramName = params.pop();
									dst.writeCode("static if (ARGS.length > ");
									paramIdx.to!string(dst.output);
									dst.writeCode(") { static if (__traits(compiles, { alias a = ARGS[");
									paramIdx.to!string(dst.output);
									dst.writeCode("]; })) { alias ");
									dst.writeCode(paramName);
									dst.writeCode(" = ARGS[");
									paramIdx.to!string(dst.output);
									dst.writeCode("]; } else { enum ");
									dst.writeCode(paramName);
									dst.writeCode(" = ARGS[");
									paramIdx.to!string(dst.output);
									dst.writeCode("]; } }\n");
								}
								
								while (params.count > 0)
								{
									size_t paramIdx = params.count - 1;
									string paramName = params.pop();
									dst.writeCode("static if (__traits(compiles, { alias a = ARGS[");
									paramIdx.to!string(dst.output);
									dst.writeCode("]; })) { alias ");
									dst.writeCode(paramName);
									dst.writeCode(" = ARGS[");
									paramIdx.to!string(dst.output);
									dst.writeCode("]; } else { enum ");
									dst.writeCode(paramName);
									dst.writeCode(" = ARGS[");
									paramIdx.to!string(dst.output);
									dst.writeCode("]; }\n");
								}
								
								debug
								{
									dst.writeRaw("<!-- Begin Template ");
									dst.writeRaw(tok.stringValue);
									dst.writeRaw("-->");
								}
								break;
							case "if":
								dst.writeCode("if (");
								dst.writeCode(ctx.readToEOL());
								dst.writeCode(") {\n");
								blocks.push(Block(BlockType.code));
								break;
							case "static":
								tok = ctx.expect!(TokenType.identifier);
								if (tok.stringValue != "if")
									throw new Exception("Expected 'if' after 'static'!");
								dst.writeCode("static if (");
								dst.writeCode(ctx.readToEOL());
								dst.writeCode(")\n{\n");
								blocks.push(Block(BlockType.code));
								break;
							case "mixin":
								// TODO: This needs to support directories as part of the path.
								tok = ctx.expect!(TokenType.identifier);
								dst.writeCode(processFile(fileTable[tok.stringValue]));
								break;
							case "extends":
								// TODO: This needs to support directories as part of the path.
								tok = ctx.expect!(TokenType.identifier);
								dst.writeCode(processFile(fileTable[tok.stringValue]));
								inExtension = true;
								break;
							case "include":
								tok = ctx.expect!(TokenType.identifier);
								dst.writeCode(tok.stringValue);
								if (tok.stringValue !in knownBlockDefinitions)
									knownBlockDefinitions[tok.stringValue] = 0;
								auto dat = ctx.data;
								tok = ctx.parseToken();
								if (tok.type == TokenType.lParen)
								{
									dst.writeCode("!(");
									dst.writeCode(ctx.readToEOL()); // Don't you just love D?
								}
								else
									ctx.data = dat;
								dst.writeCode("(buf);\n");
								break;
							default:
								dst.writeRaw("<");
								dst.writeRaw(tok.stringValue);
								switch (tok.stringValue)
								{
									case "area":
									case "base":
									case "basefont":
									case "br":
									case "col":
									case "embed":
									case "frame":
									case "hr":
									case "img":
									case "input":
									case "keygen":
									case "link":
									case "meta":
									case "param":
									case "source":
									case "track":
									case "wbr":
										isSingleElement = true;
										break;
									default:
										break;
								}
								if (!isSingleElement)
									blocks.push(Block(BlockType.element, tok.stringValue));
								isElement = true;
								break;
						}
					}
					
					ctx.parseWhitespace = true;
					tok = ctx.parseToken();
					bool isInCSSClass = false;
					while (tok.type != TokenType.eol && tok.type != TokenType.eof)
					{
						// TODO: We could probably generate a nice 
						//       warning here if they try to define
						//       the classes of the element again....
						if (isInCSSClass && tok.type != TokenType.cssClass)
						{
							dst.writeRaw("\"");
							isInCSSClass = false;
						}
						switch (tok.type)
						{
							case TokenType.equal:
							case TokenType.whitespace:
								goto WriteBody;
							case TokenType.elementID:
								dst.writeRaw(" id=\"");
								dst.writeRaw(tok.stringValue);
								dst.writeRaw("\"");
								break;
							case TokenType.cssClass:
								if (!isInCSSClass)
									dst.writeRaw(" class=\"");
								else
									dst.writeRaw(" ");
								dst.writeRaw(tok.stringValue);
								isInCSSClass = true;
								break;
							case TokenType.lParen:
								ctx.parseWhitespace = false;
								tok = ctx.expect!(TokenType.identifier, TokenType.rParen);
								bool first = true;
								if (tok.type != TokenType.rParen) do
								{
									if (!first)
										tok = ctx.expect!(TokenType.identifier);
									// TODO: This should really be getting built differently
									//       such that this should add the value to the classes
									//       to output if it is non-empty.
									string attribName = tok.stringValue;
									bool isOmittableEmptyAttribute = attribName == "class";
									ctx.expect!(TokenType.equal);
									tok = ctx.expect!(TokenType.string, TokenType.identifier);
									if (tok.type == TokenType.string)
									{
										dst.writeRaw(" ");
										dst.writeRaw(attribName);
										dst.writeRaw("=\"");
										dst.writeEscapedRaw(tok.stringValue);
										dst.writeRaw("\"");
									}
									else
									{
										if (isOmittableEmptyAttribute)
										{
											dst.writeCode("if (");
											dst.writeCode(tok.stringValue);
											dst.writeCode(` != "")`);
											dst.writeCode("\n{\n");
										}
										dst.writeRaw(" ");
										dst.writeRaw(attribName);
										dst.writeRaw("=\"");
										dst.writeCode("buf.put(");
										dst.writeCode(tok.stringValue);
										dst.writeCode(");\n");
										dst.writeRaw("\"");
										if (isOmittableEmptyAttribute)
										{
											dst.writeCode("}\n");
										}
									}
									first = false;
									tok = ctx.expect!(TokenType.comma, TokenType.rParen);
								} while (tok.type != TokenType.rParen);
								ctx.parseWhitespace = true;
								break;
								
							default:
								throw new Exception("Unknown token " ~ tok.toString() ~ "!");
						}
						tok = ctx.parseToken();
					}
					if (isInCSSClass)
					{
						dst.writeRaw("\"");
						isInCSSClass = false;
					}
				WriteBody:
					ctx.parseWhitespace = false;
					if (isSingleElement)
						dst.writeRaw("/");
					if (isElement)
						dst.writeRaw(">");
					if (tok.type == TokenType.equal)
					{
						dst.writeCode("buf.put(");
						dst.writeCode(ctx.readToEOL());
						dst.writeCode(");\n");
					}
					else if (isElement && tok.type != TokenType.eol)
						dst.writeEscapedRaw(ctx.readToEOL());
					break;
				case TokenType.code:
					dst.writeCode(tok.stringValue);
					dst.writeCode("{\n");
					blocks.push(Block(BlockType.code));
					break;
				case TokenType.equal:
					dst.writeCode("buf.put(");
					dst.writeCode(ctx.readToEOL());
					dst.writeCode(");\n");
					break;
				case TokenType.filter:
					switch(tok.stringValue)
					{
						// TODO: Add support for markdown filtering,
						//       This will require re-writing vibe's
						//       implementation so that it is practical
						//       to use at compile-time.
						case "css":
							dst.writeRaw("<style type=\"text/css\"><!--\n");
							auto startIndent = ctx.indentLevel;
							consumeIndent();
							while (ctx.indentLevel > startIndent && ctx.data.length > 0)
							{
								dst.writeRaw(ctx.readToEOL());
								dst.writeRaw("\r\n");
								if (ctx.parseToken().type != TokenType.eol)
									throw new Exception("Something is very wrong here!");
								consumeIndent();
							}
							dst.writeRaw("\n--></style>");
							break;
						case "javascript":
							dst.writeRaw("<script type=\"text/javascript\">\n");
							dst.writeRaw("//<![CDATA[\n");
							auto startIndent = ctx.indentLevel;
							consumeIndent();
							while (ctx.indentLevel > startIndent && ctx.data.length > 0)
							{
								dst.writeRaw(ctx.readToEOL());
								dst.writeRaw("\r\n");
								if (ctx.parseToken().type != TokenType.eol)
									throw new Exception("Something is very wrong here!");
								consumeIndent();
							}
							dst.writeRaw("//]]>\n");
							dst.writeRaw("</script>");
							break;
						default:
							throw new Exception("Unknown filter " ~ tok.stringValue ~ "!");
					}
					goto NoConsumeIndent;
				case TokenType.docType:
					switch (tok.stringValue)
					{
						case "5":
						case "default":
							dst.writeRaw(`<!DOCTYPE html>`);
							break;
						case "xml":
							dst.writeRaw(`<?xml version="1.0" encoding="utf-8" ?>`);
							break;
						case "transitional":
							dst.writeRaw(`<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">`);
							break;
						case "strict":
							dst.writeRaw(`<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">`);
							break;
						case "frameset":
							dst.writeRaw(`<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">`);
							break;
						case "1.1":
							dst.writeRaw(`<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">`);
							break;
						case "basic":
							dst.writeRaw(`<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">`);
							break;
						case "mobile":
							dst.writeRaw(`<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">`);
							break;
							
						default:
							throw new Exception("Unknown doctype '" ~ tok.stringValue ~ "'!");
					}
					break;
				case TokenType.eol:
					break;
				default:
					throw new Exception("Unexpected token " ~ tok.toString() ~ "!");
			}
			consumeIndent();
		NoConsumeIndent:
			tok = ctx.parseToken();
		}
		
		while (blocks.count)
			blocks.pop().writeClose(dst, rootBuffer, inExtension);
		
		dst.setState(WriteState.none);
		return dst.output.data;
	}

	auto mainMethod = processFile(text);
	rootBuffer.put("static void __slim_main(ref Appender!string buf)\n{\n");
	rootBuffer.put(mainMethod);
	rootBuffer.put("}\n");
	foreach (k, v; knownBlockDefinitions)
	{
		rootBuffer.put("alias ");
		rootBuffer.put(k);
		rootBuffer.put(" = ");
		if (v > 0)
		{
			rootBuffer.put(k);
			rootBuffer.put("_");
			v.to!string(rootBuffer);
		}
		else
			rootBuffer.put("__slim_emptyBlock");
		rootBuffer.put(";\n");
	}
	return rootBuffer.data;
}


struct FixedStack(T, size_t size)
{
private:
	T[size] data;
	size_t topIndex = -1;

public:
	@property size_t count() @safe pure nothrow
	{
		return topIndex + 1;
	}
	
	void push(T val) @safe pure
	{
		if (topIndex + 1 > data.length)
			throw new Exception("Attempted to push too many values to the stack!");
		data[++topIndex] = val;
	}
	
	T pop() @safe pure
	{
		if (topIndex < 0)
			throw new Exception("Attempted to pop too many values from the stack!");
		return data[topIndex--];
	}
}