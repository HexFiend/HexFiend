# 6502.tcl: Disassembles any binary file to 6502 CPU assembly language.
#
# Sections under each disassembled instruction provide documentation of
# address mode, mnemonic description, CPU flags, cycles and operations.
#
# Includes so-called "illegal" opcodes, which are prefixed with "_" and
# lower-case. Typically if a segment of the disassembly includes (m)any
# such opcodes, that segment is something other than 6502 machine code.
#
# This permits at-a-glance discernment of which parts of a given binary
# are likely to be 6502 CPU instructions versus data or something else.

include "Disassembly/6502_Procedures.tcl"

# Catch error when file terminates mid-instruction (ie, ends with data)
#
if [catch {
	6502_disassemble [len]
}] {
	6502_parse_error
}
