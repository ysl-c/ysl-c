module yslc.targets.x86_16;

import std.conv;
import std.stdio;
import std.format;
import std.string;
import core.stdc.stdlib;
import yslc.compiler;
import yslc.error;
import yslc.split;

class Compiler_x86_16 : CompilerTargetModule {
	string lastFunction;
	string org;
	bool   comments = true;

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
		
			if (parts[i].isNumeric()) {
				ret ~= [
					format(
						"mov word [%s], %d", paramName, parse!int(parts[i])
					)
				];
			}
			else {
				switch (parts[i][0]) {
					case '$': {
						string   varName = parts[i][1 .. $];
						Variable* var = GetVariable(varName);
						
						if (var is null) {
							ErrorUnknownVariable(
								line.file, line.line, varName
							);
							success = false;
							return ret;
						}

						ret ~= [
							format(
								"mov bx, [.__var_%s]", var.name
							),
							format(
								"mov word [%s], bx", paramName
							)
						];
						break;
					}
					default: {
						assert(0);
					}
				}
			}
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

	string[] CompileReturn() {
		return [
			"ret"
		];
	}

	string[] CompileSet(CodeLine line, string[] parts) {
		auto var = GetVariable(parts[0]);

		if (var is null) {
			ErrorUnknownVariable(line.file, line.line, parts[0]);
			success = false;
			return [];
		}

		return [
			format("mov bx, %d", parse!int(parts[1])),
			format("mov [.__var_%s], bx", var.name)
		];
	}

	string[] CompileTo(CodeLine line, string[] parts) {
		auto var = GetVariable(parts[0]);

		if (var is null) {
			ErrorUnknownVariable(line.file, line.line, parts[0]);
			success = false;
			return [];
		}

		return [
			format("mov [.__var_%s], ax", var.name)
		];
	}

	string[] CompileAddr(CodeLine line, string[] parts) {
		auto var = GetVariable(parts[0]);

		if (var is null) {
			ErrorUnknownVariable(line.file, line.line, parts[0]);
			success = false;
			return [];
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
			"mov ds, si"
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
				case "endf": {
					ret ~= CompileFunctionEnd(line);
					break;
				}
				case "return": {
					ret ~= CompileReturn();
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
