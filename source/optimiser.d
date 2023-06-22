module yslc.optimiser;

import std.uni;
import std.array;
import std.string;
import std.algorithm;

string GetInstruction(ref string[] assembly, size_t i) {
	return assembly[i].strip().split!isWhite()[0];
}

string ReplaceInstruction(string code, string newInstruction) {
	auto parts = code.strip().split!isWhite();

	parts[0] = newInstruction;
	return "    " ~ parts.join(" ");
}

void Optimise(ref string[] assembly) {
	for (size_t i = 0; i < assembly.length; ++ i) {
		auto instruction = GetInstruction(assembly, i);

		if ((instruction == "ret") && (i > 0)) {
			auto lastInstruction = GetInstruction(assembly, i - 1);

			if (lastInstruction == "call") {
				// tail call optimisation
				assembly[i] = ";" ~ assembly[i];

				assembly[i - 1] = ReplaceInstruction(assembly[i - 1], "jmp");
			}
			else if (lastInstruction == "ret") {
				// double ret
				assembly[i] = ";" ~ assembly[i];
			}
		}
	}
}
