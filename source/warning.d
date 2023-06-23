module yslc.warning;

import std.stdio;
import core.stdc.stdlib;

void WarningBegin(string fname, size_t line) {
	version (Windows) {
		stderr.writef("%s:%d: warning: ", fname, line + 1);
	}
	else {
		stderr.writef("\x1b[1m%s:%d: \x1b[36merror:\x1b[0m ", fname, line + 1);
	}
}

void WarningDeprecatedKeyword(string fname, size_t line, string keyword) {
	WarningBegin(fname, line);
	stderr.writefln("Deprecated keyword: %s", keyword);
}
