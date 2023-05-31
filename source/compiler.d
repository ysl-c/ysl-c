module yslc.compiler;

import std.algorithm;
import yslc.preprocessor;

struct CodeLine {
	string file;
	size_t line;
	string contents;
}

class CompilerException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

struct Variable {
	string name;
	ulong  address;
	ulong  size;
}

struct FunctionParameter {
	string name;
	ulong  address;
}

struct Function {
	string              name;
	FunctionParameter[] parameters;
}

class CompilerTargetModule {
	Variable[] variables;
	Function[] functions;
	size_t     variableTop;
	string[][] scopes;

	Variable AllocateGlobal(string name, size_t size) {
		variables ~= Variable(
			name, variableTop, size
		);
		
		variableTop += size;

		return variables[$ - 1];
	}

	Variable AllocateLocal(string name, size_t size) {
		auto ret = AllocateGlobal(name, size);
		
		scopes[$ - 1] ~= name;

		return ret;
	}

	void DestroyScope() {
		foreach (ref var ; scopes[$ - 1]) {
			variableTop -= GetVariable(var).size;
			RemoveVariable(var);
		}
		scopes = scopes[0 .. $ - 1];
	}

	void AddScope() {
		scopes ~= cast(string[]) [];
	}

	Variable GetVariable(string name) {
		foreach_reverse (ref var ; variables) {
			if (var.name == name) {
				return var;
			}
		}

		throw new CompilerException("no such variable");
	}

	void RemoveVariable(string name) {
		foreach_reverse (i, ref var ; variables) {
			if (var.name == name) {
				variables = variables.remove(i);
				return;
			}
		}
	}

	void AddFunction(string name, string[] parameters) {
		functions ~= Function(name, parameters);
	}

	Function GetFunction(string name) {
		foreach (ref func ; functions) {
			if (func.name == name) {
				return func;
			}
		}

		throw new CompilerException("no such function");
	}

	abstract string[] Compile(CodeLine[] lines);
}

class Compiler {
	string[] Compile(CompilerTargetModule target, string file) {
		auto code = RunPreprocessor(file);

		auto ret = target.Compile(code);

		foreach (ref line ; ret) {
			if (line[$ - 1] != ':') {
				line = "    " ~ line;
			}
		}

		return ret;
	}
}
