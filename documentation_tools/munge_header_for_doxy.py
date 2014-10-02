#!/usr/bin/python

import sys, re

if len(sys.argv) > 1:
	file_to_read = open(sys.argv[1])
else:
	file_to_read = sys.stdin

all_text = file_to_read.read()
massaged_text = all_text

# Next, remove the ivars of every class so that Doxygen doesn't try to document them (grr...)
pattern =   r"""^@interface 		# start with @interface at the beginning of a line
				([^{]+)				# then a bunch of junk on the same line
				{\ *				# ending with an open brace, and maybe some space
			    (.+?)				# then a bunch of crap, the stuff we want to delete
			    ^}					# ending with a single brace
			    
			"""
			
	
expr = re.compile(pattern, re.MULTILINE | re.VERBOSE | re.DOTALL)
matches = list(expr.finditer(massaged_text))

# Iterate backwards so that we don't mess up prior indexes
matches.reverse()
for match in matches:
	massaged_text = massaged_text[:match.start(2)] + massaged_text[match.end(2):]

print massaged_text,
