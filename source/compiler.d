module yslc.compiler;

import std.stdio;
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

enum VariableType {
	Integer,
	Array,
	String
}

struct Variable {
	string       name;
	VariableType type;
	ulong        elements;
	string       value;
}

struct FunctionParameter {
	string name;
}

struct Function {
	string              name;
	FunctionParameter[] parameters;
}

class CompilerTargetModule {
	bool               success;
	Variable[]         globalVariables;
	Variable[]         localVariables;
	Function[]         functions;

	Variable* GetLocal(string name) {
		foreach (ref var ; localVariables) {
			if (var.name == name) {
				return &var;
			}
		}

		return null;
	}

	Variable* GetGlobal(string name) {
		foreach (ref var ; globalVariables) {
			if (var.name == name) {
				return &var;
			}
		}

		return null;
	}
	
	void AddFunction(string name, string[] parameters) {
		FunctionParameter[] params;

		foreach (ref param ; parameters) {
			params ~= FunctionParameter(param);
		}
		
		functions ~= Function(name, params);
	}

	Function GetFunction(string name) {
		foreach (ref func ; functions) {
			if (func.name == name) {
				return func;
			}
		}

		throw new CompilerException("no such function");
	}

	bool FunctionExists(string name) {
		foreach (ref func ; functions) {
			if (func.name == name) {
				return true;
			}
		}

		return false;
	}

	abstract string[] Compile(CodeLine[] lines);
}

class Compiler {
	string[] Compile(
		CompilerTargetModule target, string file, string[] includePaths
	) {
		string[] included;
		auto     code = RunPreprocessor(file, includePaths, included);

		auto ret = target.Compile(code);

		if (!target.FunctionExists("main")) {
			stderr.writefln("YSL-M requires that a main function is defined");
			target.success = false;
		}

		foreach (ref line ; ret) {
			if (line[$ - 1] != ':') {
				line = "    " ~ line;
			}
		}

		return ret;
	}
}
