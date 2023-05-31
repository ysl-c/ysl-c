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
	bool   success = true;
	string lastFunction;

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
			auto param = Variable(
				func.parameters[i - 1].name,
				func.parameters[i - 1].address,
				2
			);
		
			if (parts[i].isNumeric()) {
				ret ~= [
					format(
						"mov word [%d], %d", param.address, parse!int(parts[i])
					)
				];
			}
			else {
				switch (parts[i][0]) {
					case '$': {
						string   varName = parts[i][1 .. $];
						Variable var;
						
						try {
							var = GetVariable(varName);
						}
						catch (CompilerException) {
							ErrorUnknownVariable(
								line.file, line.line, varName
							);
							success = false;
							return ret;
						}

						ret ~= [
							format(
								"mov bx, [%d]", var.address
							),
							format(
								"mov word [%d], bx", param.address
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

	string[] CompileFunctionStart(string[] parts) {
		Function func;

		lastFunction = parts[0];
		func.name    = parts[0];

		AddScope();

		foreach (ref param ; parts[1 .. $]) {
			variableTop += 2;
			
		}
	
		return [
			format("jmp __function_%s_end", parts[0]),
			format("__function_%s:", parts[0])
		];
	}

	string[] CompileFunctionEnd() {
		DestroyScope();
	
		return [
			"ret",
			format("__function_%s_end:", lastFunction)
		];
	}

	string[] CompileReturn() {
		return [
			"ret"
		];
	}

	string[] CompileSet(string[] parts) {
		size_t addr = GetVariable(parts[0]).address;

		return [
			format("mov bx, %d", parse!int(parts[1])),
			format("mov [%d], bx", addr)
		];
	}

	string[] CompileTo(string[] parts) {
		size_t addr = GetVariable(parts[0]).address;

		return [
			format("mov [%d], ax", addr)
		];
	}

	string[] CompileAddr(string[] parts) {
		size_t addr = GetVariable(parts[0]).address;

		return [
			format("mov ax, %d", addr)
		];
	}
	
	override string[] Compile(CodeLine[] lines) {
		string[] ret;
		variableTop = 4096;

		AddScope(); // i hope this doesn't cause a terrible error in the future

		foreach (ref line ; lines) {
			ret ~= format("; %s", line.contents);
		
			auto parts   = Split(
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
					ret ~= CompileFunctionStart(parts[1 .. $]);
					break;
				}
				case "endf": {
					ret ~= CompileFunctionEnd();
					break;
				}
				case "return": {
					ret ~= CompileReturn();
					break;
				}
				case "int": { // TODO: write safe code
					AllocateGlobal(parts[1], 2);
					break;
				}
				case "array": {
					AllocateGlobal(parts[1], parse!size_t(parts[2]));
					break;
				}
				case "local": {
					switch (parts[1]) {
						case "int": {
							AllocateLocal(parts[2], 2);
							break;
						}
						case "array": {
							AllocateLocal(parts[2], parse!size_t(parts[3]));
							break;
						}
						default: assert(0);
					}
					break;
				}
				case "set": {
					ret ~= CompileSet(parts[1 .. $]);
					break;
				}
				case "to": {
					ret ~= CompileTo(parts[1 .. $]);
					break;
				}
				case "addr": {
					ret ~= CompileAddr(parts[1 .. $]);
					break;
				}
				default: {
					ret ~= CompileFunctionCall(line, parts);
					break;
				}
			}
		}

		if (!success) {
			exit(1);
		}

		return ret;
	}
}
