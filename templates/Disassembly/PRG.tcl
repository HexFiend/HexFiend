# PRG.tcl: Commodore 64 executable format & popular C64 binary distribution method.
#
# load_address [2 bytes] :: little endian address to load next two fields to memory
# exec_address [2 bytes] :: little endian address to begin code execution post-load
# 6502_code    [len - 2] :: unstructured 6502 code/data etc, including exec_address
#
include "Disassembly/6502_Procedures.tcl"

set    load_address  [uint16]
entry "load_address" [string toupper $[format %04x $load_address]] 2 [expr [pos]-2]
set    exec_address  [uint16]
entry "exec_address" [string toupper $[format %04x $exec_address]] 2 [expr [pos]-2]

# Catch the parsing error when file terminates mid-instruction (ie, ends with data)
#
if [catch {
	6502_disassemble [expr [len]-4]
}] {
	6502_parse_error
}
