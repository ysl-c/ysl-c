module yslc.preprocessor;

import std.uni;
import std.file;
import std.array;
import core.stdc.stdlib;
import yslc.compiler;
import yslc.error;
import yslc.split;

CodeLine[] RunPreprocessor(string file) {
	CodeLine[] ret;
	string[]   code    = readText(file).replace("\r\n", "\n").split("\n");
	bool       success = true;

	foreach (i, ref line ; code) {
		if (line.empty()) {
			continue;
		}
	
		if (line[0] == '%') {
			auto parts = Split(file, i, line, &success);

			switch (parts[0]) {
				case "%include": {
					if (!exists(parts[1])) {
						ErrorNoSuchFile(file, i, parts[1]);
						success = false;
						break;
					} // here

					ret ~= RunPreprocessor(parts[1]);
					break;
				}
				default: {
					ErrorUnknownDirective(file, i, parts[0]);
					success = false;
					break;
				} // and here
			}
		}
		else if (line[0] == '#') {
			// comment
			continue;
		}
		else {
			ret ~= CodeLine(
				file, // file name
				i,    // line number
				line  // line contents
			);
		}
	}

	if (!success) {
		exit(1);
	}

	return ret;
} // and here
