module yslc.app;

import std.file;
import std.array;
import std.stdio;
import std.algorithm;
import core.stdc.stdlib;
import yslc.compiler;
import yslc.optimiser;
import yslc.targets.x86_16;

void main(string[] args) {
	CompilerTargetModule target;
	Compiler             compiler = new Compiler();

	string inFile;
	string outFile = "out.asm";

	if ((args.length < 2) || (args.canFind("--help")) || (args.canFind("-h"))) {
		writefln("Usage:");
		writefln("    %s [in] [options]", args[0]);
		writefln("Options:");
		writefln("    -h / --help    : Show this info");
		writefln("    -o / --out     : Choose output file");
		writefln("    --org          : Sets org address in asm file");
		writefln("    -i / --include : Add include directory");
		return;
	}

	auto x86Target     = new Compiler_x86_16();
	x86Target.org      = "0x100";
	x86Target.comments = false;

	string[] includePaths;

	for (size_t i = 1; i < args.length; ++ i) {
		if (args[i][0] == '-') {
			switch (args[i]) {
				case "-o":
				case "--out": {
					++ i;

					outFile = args[i];
					break;
				}
				case "--org": {
					++ i;
					x86Target.org = args[i];
					break;
				}
				case "-i":
				case "--include": {
					++ i;
					includePaths ~= args[i];
					break;
				}
				default: {
					stderr.writefln("Unknown argument %s", args[i]);
					exit(1);
				}
			}
		}
		else {
			inFile = args[i];
		}
	}

	target = x86Target;
	auto res = compiler.Compile(target, inFile, includePaths);

	if (!target.success) {
		writeln("Compilation failed");
		return;
	}

	Optimise(res);

	string assembly;

	version (Windows) {
		assembly = res.join("\r\n");
	}
	else {
		assembly = res.join("\n");
	}

	std.file.write(outFile, assembly);
}
