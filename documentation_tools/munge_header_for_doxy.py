#!/usr/bin/env python

import sys, re

file_to_read = open(sys.argv[1]) if len(sys.argv) > 1 else sys.stdin
text = file_to_read.read()

# Remove the ivars of every class so that Doxygen doesn't try to document them (grr...)
pattern = r"""
^\s* @interface [^{\n]*  # Lookbehind for an interface declaration
( \{ (.*?) ^\s* \} )     # Non-greedily capture the instance variable section
.*?                      # Skip methods
^\s* @end\s              # Lookahead for the end of the interface
"""
expr = re.compile(pattern, re.MULTILINE | re.DOTALL | re.VERBOSE)
matches = list(expr.finditer(text))

# Iterate backwards so that we don't mess up prior indexes
matches.reverse()
for match in matches:
  text = text[:match.start(1)] + text[match.end(1):]

sys.stdout.write(text)
