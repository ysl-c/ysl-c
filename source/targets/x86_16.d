module yslc.targets.x86_16;

import std.conv;
import std.stdio;
import std.format;
import std.string;
import core.stdc.stdlib;
import yslc.compiler;
import yslc.error;
import yslc.split;
import yslc.warning;

class Compiler_x86_16 : CompilerTargetModule {
	string   lastFunction;
	string   org;
	bool     comments = true;
	ulong    statements;
	ulong[]  statementIDs;
	string[] forVariables;
	bool     ifHadElse = false;

	string[] CompileParameter(CodeLine line, string part, string to) {
		if (part.isNumeric()) {
			return [
				format(
					"mov %s, %d", to, parse!int(part)
				)
			];
		}
		else if (part.startsWith("0x")) {
			int  value;
			auto hex = part[2 .. $];

			try {
				value = parse!int(hex, 16);
			}
			catch (ConvException e) {
				ErrorInvalidHex(line.file, line.line);
				success = false;
				return [];
			}

			return [
				format(
					"mov %s, %d", to, value
				)
			];
		}
		else {
			switch (part[0]) {
				case '$': {
					string    varName = part[1 .. $];
					Variable* var     = GetLocal(varName);

					if (var is null) {
						var = GetGlobal(varName);

						if (var is null) {
							ErrorUnknownVariable(line.file, line.line, varName);
							success = false;
							return [];
						}

						return [
							format("mov bx, [__gvar_%s]", var.name),
							format("mov %s, bx", to)
						];
					}

					return [
						format("mov bx, [.__var_%s]", var.name),
						format("mov %s, bx", to)
					];
				}
				case '&': {
					string    varName = part[1 .. $];
					Variable* var     = GetLocal(varName);

					if (var is null) {
						var = GetGlobal(varName);

						if (var is null) {
							ErrorUnknownVariable(
								line.file, line.line, varName
							);
							success = false;
							return [];
						}

						return [
							format("mov bx, __gvar_%s", var.name),
							format("mov %s, bx", to)
						];
					}

					return [
						format("mov bx, .__var_%s", var.name),
						format("mov %s, bx", to)
					];
				}
				case '!': {
					char ch = part[1];

					return [
						format("mov bx, %d", cast(int) ch),
						format("mov %s, bx", to)
					];
				}
				default: {
					if (part == "true") {
						return [
							"mov bx, 1",
							format("mov %s, bx", to)
						];
					}
					else if (part == "false") {
						return [
							"mov bx, 0",
							format("mov %s, bx", to)
						];
					}
					else {
						ErrorUnknownOperator(line.file, line.line, part[0]);
						success = false;
						return [];
					}
				}
			}
		}
	}

	string[] CompileFunctionCall(CodeLine line, string[] parts) {
		string[] ret;

		Function func;

		try {
			func = GetFunction(parts[0]);
		}
		catch (CompilerException) {
			ErrorUnknownFunction(line.file, line.line, parts[0]);
			success = false;
			return ret;
		}

		if (parts.length != func.parameters.length + 1) {
			ErrorWrongParameterNum(
				line.file, line.line, func.parameters.length - 1, parts.length - 1
			);
			success = false;
			return ret;
		}

		for (size_t i = 1; i < parts.length; ++ i) {
			auto   param     = func.parameters[i - 1].name;
			string paramName = format(
				"__function_%s.__param_%s", func.name, param
			);

			ret ~= CompileParameter(
				line, parts[i], format("word [%s]", paramName)
			);
		}

		ret ~= format("call __function_%s", parts[0]);

		return ret;
	}

	string[] CompileFunctionStart(CodeLine line, string[] parts) {
		AddFunction(parts[0], parts[1 .. $]);

		return [
			format("jmp __function_%s_end", parts[0]),
			format("__function_%s:", parts[0])
		];
	}

	string[] CompileFunctionEnd(CodeLine line) {
		string[] ret = [
			"ret"
		];

		foreach (ref var ; localVariables) {
			switch (var.type) {
				case VariableType.Integer: {
					ret ~= format(
						".__var_%s: dw 0",
						var.name
					);
					break;
				}
				case VariableType.Array: {
					ret ~= format(
						".__var_%s: times %d dw 0",
						var.name, var.elements
					);
					break;
				}
				case VariableType.String: {
					string dbString;

					foreach (ref ch ; var.value) {
						dbString ~= format("%d,", cast(int) ch);
					}

					ret ~= format(
						".__var_%s: db %s 0",
						var.name, dbString
					);
					break;
				}
				default: assert(0);
			}
		}

		localVariables = [];

		auto func = functions[$ - 1];

		foreach (ref param ; func.parameters) {
			ret ~= format(".__param_%s: dw 0", param.name);
		}

		ret ~= format("__function_%s_end:", func.name);

		return ret;
	}

	string[] CompileIf(CodeLine line, string[] parts) {
		string[] ret;

		ifHadElse = false;

		if (parts.empty()) {
			ErrorEmptyStatement(line.file, line.line);
			success = false;
			return [];
		}

		ret ~= format(".__statement_%d:", statements);
		ret ~= CompileFunctionCall(line, parts);
		ret ~= [
			"cmp ax, 0",
			format("je .__statement_%d_else", statements)
		];

		statementIDs ~= statements;
		++ statements;

		return ret;
	}

	string[] CompileElse(CodeLine line) {
		if (ifHadElse) {
			ErrorAlreadyElse(line.file, line.line);
			success = false;
			return [];
		}

		ifHadElse = true;

		return [
			format("jmp .__statement_%d_end", statementIDs[$ - 1]),
			format(".__statement_%d_else:", statementIDs[$ - 1])
		];
	}

	string[] CompileEndIf(CodeLine line) {
		string[] ret;

		if (statementIDs.length == 0) {
			ErrorNoIfToMatch(line.file, line.line);
			success = false;
			return [];
		}

		if (!ifHadElse) {
			ret ~= [
				format(".__statement_%d_else:", statementIDs[$ - 1])
			];
		}

		ret ~= [
			format(".__statement_%d_end:", statementIDs[$ - 1])
		];

		statementIDs = statementIDs[0 .. $ - 1];
		ifHadElse    = false;
		return ret;
	}

	string[] CompileWhile(CodeLine line, string[] parts) {
		string[] ret;

		if (parts.empty()) {
			ErrorEmptyStatement(line.file, line.line);
			success = false;
			return [];
		}

		ret ~= format(".__statement_%d:", statements);
		ret ~= CompileFunctionCall(line, parts);
		ret ~= [
			"cmp ax, 0",
			format("je .__statement_%d_end", statements)
		];

		statementIDs ~= statements;
		++ statements;

		return ret;
	}

	string[] CompileEndWhile(CodeLine line) {
		string[] ret;

		ret ~= [
			format("jmp .__statement_%d", statementIDs[$ - 1]),
			format(".__statement_%d_end:", statementIDs[$ - 1])
		];

		statementIDs = statementIDs[0 .. $ - 1];
		return ret;
	}

	string[] CompileFor(CodeLine line, string[] parts) {
		if (parts.length != 2) {
			ErrorWrongParameterNum(line.file, line.line, 2, parts.length);
			success = false;
			return [];
		}

		statementIDs ~= statements;
		++ statements;

		forVariables ~= parts[0];

		Variable* var = GetLocal(parts[0]);

		if (var is null) {
			var = GetGlobal(parts[0]);

			if (var is null) {
				ErrorUnknownVariable(
					line.file, line.line, parts[0]
				);
				success = false;
				return [];
			}

			return CompileParameter(line, parts[1], "ax") ~
			[
				format("mov [__gvar_%s], ax", parts[0]),
				format(".__statement_%D", statementIDs[$ - 1])
			];
		}

		return CompileParameter(line, parts[1], "ax") ~
		[
			format("mov [.__var_%s], ax", parts[0]),
			format(".__statement_%d:", statementIDs[$ - 1])
		];
	}

	string[] CompileEndFor(CodeLine line) {
		auto     varName = forVariables[$ - 1];
		auto     var     = GetLocal(varName);
		string[] ret;

		if (var is null) {
			var = GetGlobal(varName);

			if (var is null) {
				assert(0);
			}

			ret = [
				format("dec word [__gvar_%s]", var.name),
				format("jnz .__statement_%d", statementIDs[$ - 1])
			];
		}
		else {
			ret = [
				format("dec word [.__var_%s]", var.name),
				format("jnz .__statement_%d", statementIDs[$ - 1])
			];
		}

		forVariables = forVariables[0 .. $ - 1];
		statementIDs = statementIDs[0 .. $ - 1];
		return ret;
	}

	string[] CompileReturn(CodeLine line, string[] parts) {
		if (parts.length > 0) {
			return CompileParameter(line, parts[0], "ax") ~
			[
				"ret"
			];
		}
		else {
			return [
				"ret"
			];
		}
	}

	string[] CompileSet(CodeLine line, string[] parts) {
		auto var = GetLocal(parts[0]);

		if (var is null) {
			var = GetGlobal(parts[0]);

			if (var is null) {
				ErrorUnknownVariable(line.file, line.line, parts[0]);
				success = false;
				return [];
			}

			return CompileParameter(line, parts[1], "bx") ~
			[
				format("mov [__gvar_%s], bx", var.name)
			];
		}

		string[] ret;

		ret ~= CompileParameter(line, parts[1], "bx");

		ret ~= [
			format("mov [.__var_%s], bx", var.name)
		];

		return ret;
	}

	string[] CompileTo(CodeLine line, string[] parts) {
		auto var = GetLocal(parts[0]);

		if (var is null) {
			var = GetGlobal(parts[0]);

			if (var is null) {
				ErrorUnknownVariable(line.file, line.line, parts[0]);
				success = false;
				return [];
			}

			return [
				format("mov [__gvar_%s], ax", var.name)
			];
		}

		return [
			format("mov [.__var_%s], ax", var.name)
		];
	}

	string[] CompileAddr(CodeLine line, string[] parts) {
		auto var = GetLocal(parts[0]);

		if (var is null) {
			var = GetGlobal(parts[0]);

			if (var is null) {
				ErrorUnknownVariable(line.file, line.line, parts[0]);
				success = false;
				return [];
			}

			return [
				format("mov ax, __gvar_%s", var.name)
			];
		}

		return [
			format("mov ax, .__var_%s", var.name)
		];
	}

	string[] CompileParam(CodeLine line, string[] parts) {
		Variable var;

		if (parts.length != 1) {
			ErrorWrongParameterNum(
				line.file, line.line, 1, parts.length
			);
			success = false;
			return [];
		}

		var.name = parts[0];
		var.type = VariableType.Integer;

		localVariables ~= var;

		return [
			format(
				"mov bx, [.__param_%s]",
				parts[0]
			),
			format(
				"mov [.__var_%s], bx",
				var.name
			)
		];
	}

	string[] CompileImport(CodeLine line, string[] parts) {
		if (parts.length != 1) {
			ErrorWrongParameterNum(
				line.file, line.line, 1, parts.length
			);
			success = false;
			return [];
		}

		auto var = GetGlobal(parts[0]);

		if (var is null) {
			ErrorUnknownVariable(line.file, line.line, parts[0]);
			success = false;
			return [];
		}

		auto local = GetLocal(parts[0]);

		if (local is null) {
			localVariables ~= *var;
		}

		return [
			format("mov bx, [__gvar_%s]", parts[0]),
			format("mov [.__var_%s], bx", parts[0])
		];
	}

	string[] CompileExport(CodeLine line, string[] parts) {
		if (parts.length != 1) {
			ErrorWrongParameterNum(
				line.file, line.line, 1, parts.length
			);
			success = false;
			return [];
		}

		auto global = GetGlobal(parts[0]);
		auto local  = GetLocal(parts[0]);

		if ((global is null) || (local is null)) {
			ErrorUnknownVariable(line.file, line.line, parts[0]);
			success = false;
			return [];
		}

		return [
			format("mov bx, [.__var_%s]", parts[0]),
			format("mov [__gvar_%s], bx", parts[0])
		];
	}

	string[] CompileFaddr(CodeLine line, string[] parts) {
		if (parts.length != 1) {
			ErrorWrongParameterNum(
				line.file, line.line, 1, parts.length
			);
			success = false;
			return [];
		}

		Function func;

		try {
			func = GetFunction(parts[0]);
		}
		catch (CompilerException) {
			ErrorUnknownFunction(line.file, line.line, parts[0]);
			success = false;
			return [];
		}

		return [
			format("mov ax, __function_%s", func.name)
		];
	}

	Variable CreateInt(CodeLine line, string[] parts) {
		Variable var;

		if (parts.length != 1) {
			ErrorWrongParameterNum(
				line.file, line.line, 1, parts.length
			);
			success = false;
			return var;
		}

		var.name = parts[0];
		var.type = VariableType.Integer;

		return var;
	}

	Variable CreateArray(CodeLine line, string[] parts) {
		Variable var;

		if (parts.length != 2) {
			ErrorWrongParameterNum(
				line.file, line.line, 2, parts.length
			);
			success = false;
			return var;
		}

		var.name     = parts[1];
		var.type     = VariableType.Array;
		var.elements = parse!ulong(parts[0]);

		return var;
	}

	Variable CreateString(CodeLine line, string[] parts) {
		Variable var;

		if (parts.length != 2) {
			ErrorWrongParameterNum(
				line.file, line.line, 2, parts.length
			);

			success = false;
			return var;
		}

		var.name  = parts[0];
		var.type  = VariableType.String;
		var.value = parts[1];

		return var;
	}

	override string[] Compile(CodeLine[] lines) {
		string[] ret;

		success = true;

		ret ~= [
			format("org %s", org),
			"mov si, cs",
			"mov ds, si",
			"jmp __function_main"
		];

		foreach (ref line ; lines) {
			if (comments) {
				ret ~= format("; %s", line.contents);
			}

			auto parts = Split(
				line.file, line.line, line.contents,
				&success
			);

			if (parts.empty()) {
				continue;
			}

			switch (parts[0]) {
				case "asm": {
					string inline;

					for (size_t i = 1; i < parts.length; ++ i) {
						inline ~= parts[i] ~ ' ';
					}

					ret ~= inline;
					break;
				}
				case "func": {
					ret ~= CompileFunctionStart(line, parts[1 .. $]);
					break;
				}
				case "endf":
				case "endfunc": {
					if (parts[0] == "endf") {
						WarningDeprecatedKeyword(line.file, line.line, "endf");
					}

					ret ~= CompileFunctionEnd(line);
					break;
				}
				case "if": {
					ret ~= CompileIf(line, parts[1 .. $]);
					break;
				}
				case "else": {
					ret ~= CompileElse(line);
					break;
				}
				case "endif": {
					ret ~= CompileEndIf(line);
					break;
				}
				case "while": {
					ret ~= CompileWhile(line, parts[1 .. $]);
					break;
				}
				case "endwhile": {
					ret ~= CompileEndWhile(line);
					break;
				}
				case "for": {
					ret ~= CompileFor(line, parts[1 .. $]);
					break;
				}
				case "endfor": {
					ret ~= CompileEndFor(line);
					break;
				}
				case "return": {
					ret ~= CompileReturn(line, parts[1 .. $]);
					break;
				}
				case "int": {
					globalVariables  ~= CreateInt(line, parts[1 .. $]);
					break;
				}
				case "array": {
					globalVariables  ~= CreateArray(line, parts[1 .. $]);
					break;
				}
				case "string": {
					globalVariables ~= CreateString(line, parts[1 .. $]);
					break;
				}
				case "local": {
					switch (parts[1]) {
						case "int": {
							localVariables ~= CreateInt(line, parts[2 .. $]);
							break;
						}
						case "array": {
							localVariables ~= CreateArray(line, parts[2 .. $]);
							break;
						}
						case "string": {
							localVariables ~= CreateString(line, parts[2 .. $]);
							break;
						}
						default: {
							ErrorUnknownType(line.file, line.line, parts[1]);
							success = false;
							break;
						}
					}
					break;
				}
				case "set": {
					ret ~= CompileSet(line, parts[1 .. $]);
					break;
				}
				case "to": {
					ret ~= CompileTo(line, parts[1 .. $]);
					break;
				}
				case "addr": {
					ret ~= CompileAddr(line, parts[1 .. $]);
					break;
				}
				case "param": {
					ret ~= CompileParam(line, parts[1 .. $]);
					break;
				}
				case "import": {
					WarningDeprecatedKeyword(line.file, line.line, "import");
					//ret ~= CompileImport(line, parts[1 .. $]);
					break;
				}
				case "export": {
					WarningDeprecatedKeyword(line.file, line.line, "export");
					//ret ~= CompileExport(line, parts[1 .. $]);
					break;
				}
				case "faddr": {
					ret ~= CompileFaddr(line, parts[1 .. $]);
					break;
				}
				default: {
					ret ~= CompileFunctionCall(line, parts);
					break;
				}
			}
		}

		foreach (ref var ; globalVariables) {
			switch (var.type) {
				case VariableType.Integer: {
					ret ~= format(
						"__gvar_%s: dw 0",
						var.name
					);
					break;
				}
				case VariableType.Array: {
					ret ~= format(
						"__gvar_%s: times %d dw 0",
						var.name, var.elements
					);
					break;
				}
				case VariableType.String: {
					string dbString;

					foreach (ref ch ; var.value) {
						dbString ~= format("%d,", cast(int) ch);
					}

					ret ~= format(
						"__gvar_%s: db %s 0",
						var.name, dbString
					);
					break;
				}
				default: assert(0);
			}
		}

		return ret;
	}
}
