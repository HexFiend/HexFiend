# 6502_Procedures.tcl: 6502 machine code disassembly. (Ref: https://masswerk.at/6502/6502_instruction_set.html)
#
# .hidden = true;

proc 6502_disassemble {code_count} {
	# The disassembler uses the "$opcodes" list order to match that of the 6502's zero-indexed instruction set.
	# Eg, the "JMP $absl" instruction opcode is hex "4C", or "76" in decimal. Therefore, it's 77th in the list.
	#
	# Fields: inst (Assembly Mnemonic), mode (Address Mode), length (Opcode+Operand Bytes), cycles (CPU Cycles)
	#
	set opcodes {
		 "BRK" "impl" 1 7
		 "ORA" "xidr" 2 6
		"_jam" "impl" 1 2
		"_slo" "xidr" 2 8
		"_nop" "zpag" 2 3
		 "ORA" "zpag" 2 3
		 "ASL" "zpag" 2 5
		"_slo" "zpag" 2 5
		 "PHP" "impl" 1 3
		 "ORA" "immd" 2 2
		 "ASL" "accu" 1 2
		"_anc" "immd" 2 2
		"_nop" "absl" 3 4
		 "ORA" "absl" 3 4
		 "ASL" "absl" 3 6
		"_slo" "absl" 3 6
		 "BPL" "rela" 2 2
		 "ORA" "idry" 2 5
		"_jam" "impl" 1 2
		"_slo" "idry" 2 8
		"_nop" "zpgx" 2 4
		 "ORA" "zpgx" 2 4
		 "ASL" "zpgx" 2 6
		"_slo" "zpgx" 2 6
		 "CLC" "impl" 1 2
		 "ORA" "absy" 3 4
		"_nop" "impl" 1 2
		"_slo" "absy" 3 7
		"_nop" "absx" 3 4
		 "ORA" "absx" 3 4
		 "ASL" "absx" 3 7
		"_slo" "absx" 3 7
		 "JSR" "absl" 3 6
		 "AND" "xidr" 2 6
		"_jam" "impl" 1 2
		"_rla" "xidr" 2 8
		 "BIT" "zpag" 2 3
		 "AND" "zpag" 2 3
		 "ROL" "zpag" 2 5
		"_rla" "zpag" 2 5
		 "PLP" "impl" 1 4
		 "AND" "immd" 2 2
		 "ROL" "accu" 1 2
		"_anc" "immd" 2 2
		 "BIT" "absl" 3 4
		 "AND" "absl" 3 4
		 "ROL" "absl" 3 6
		"_rla" "absl" 3 6
		 "BMI" "rela" 2 2
		 "AND" "idry" 2 5
		"_jam" "impl" 1 2
		"_rla" "idry" 2 8
		"_nop" "zpgx" 2 4
		 "AND" "zpgx" 2 4
		 "ROL" "zpgx" 2 6
		"_rla" "zpgx" 2 6
		 "SEC" "impl" 1 2
		 "AND" "absy" 3 4
		"_nop" "impl" 1 2
		"_rla" "absy" 3 7
		"_nop" "absx" 3 4
		 "AND" "absx" 3 4
		 "ROL" "absx" 3 7
		"_rla" "absx" 3 7
		 "RTI" "impl" 1 6
		 "EOR" "xidr" 2 6
		"_jam" "impl" 1 2
		"_sre" "xidr" 2 8
		"_nop" "zpag" 2 3
		 "EOR" "zpag" 2 3
		 "LSR" "zpag" 2 5
		"_sre" "zpag" 2 5
		 "PHA" "impl" 1 3
		 "EOR" "immd" 2 2
		 "LSR" "accu" 1 2
		"_asr" "immd" 2 2
		 "JMP" "absl" 3 3
		 "EOR" "absl" 3 4
		 "LSR" "absl" 3 6
		"_sre" "absl" 3 6
		 "BVC" "rela" 2 2
		 "EOR" "idry" 2 5
		"_jam" "impl" 1 2
		"_sre" "idry" 2 8
		"_nop" "zpgx" 2 4
		 "EOR" "zpgx" 2 4
		 "LSR" "zpgx" 2 6
		"_sre" "zpgx" 2 6
		 "CLI" "impl" 1 2
		 "EOR" "absy" 3 4
		"_nop" "impl" 1 2
		"_sre" "absy" 3 7
		"_nop" "absx" 3 4
		 "EOR" "absx" 3 4
		 "LSR" "absx" 3 7
		"_sre" "absx" 3 7
		 "RTS" "impl" 1 6
		 "ADC" "xidr" 2 6
		"_jam" "impl" 1 2
		"_rra" "xidr" 2 8
		"_nop" "zpag" 2 3
		 "ADC" "zpag" 2 3
		 "ROR" "zpag" 2 5
		"_rra" "zpag" 2 5
		 "PLA" "impl" 1 4
		 "ADC" "immd" 2 2
		 "ROR" "accu" 1 2
		"_arr" "immd" 2 2
		 "JMP" "indr" 3 5
		 "ADC" "absl" 3 4
		 "ROR" "absl" 3 6
		"_rra" "absl" 3 6
		 "BVS" "rela" 2 2
		 "ADC" "idry" 2 5
		"_jam" "impl" 1 2
		"_rra" "idry" 2 8
		"_nop" "zpgx" 2 4
		 "ADC" "zpgx" 2 4
		 "ROR" "zpgx" 2 6
		"_rra" "zpgx" 2 6
		 "SEI" "impl" 1 2
		 "ADC" "absy" 3 4
		"_nop" "impl" 1 2
		"_rra" "absy" 3 7
		"_nop" "absx" 3 4
		 "ADC" "absx" 3 4
		 "ROR" "absx" 3 7
		"_rra" "absx" 3 7
		"_nop" "immd" 2 2
		 "STA" "xidr" 2 6
		"_nop" "immd" 2 2
		"_sax" "xidr" 2 6
		 "STY" "zpag" 2 3
		 "STA" "zpag" 2 3
		 "STX" "zpag" 2 3
		"_sax" "zpag" 2 3
		 "DEY" "impl" 1 2
		"_nop" "immd" 2 2
		 "TXA" "impl" 1 2
		"_xaa" "immd" 2 2
		 "STY" "absl" 3 4
		 "STA" "absl" 3 4
		 "STX" "absl" 3 4
		"_sax" "absl" 3 4
		 "BCC" "rela" 2 2
		 "STA" "idry" 2 6
		"_jam" "impl" 1 2
		"_sha" "idry" 2 6
		 "STY" "zpgx" 2 4
		 "STA" "zpgx" 2 4
		 "STX" "zpgy" 2 4
		"_sax" "zpgy" 2 4
		 "TYA" "impl" 1 2
		 "STA" "absy" 3 5
		 "TXS" "impl" 1 2
		"_shs" "absy" 3 5
		"_shy" "absx" 3 5
		 "STA" "absx" 3 5
		"_shx" "absy" 3 5
		"_sha" "absy" 3 5
		 "LDY" "immd" 2 2
		 "LDA" "xidr" 2 6
		 "LDX" "immd" 2 2
		"_lax" "xidr" 2 6
		 "LDY" "zpag" 2 3
		 "LDA" "zpag" 2 3
		 "LDX" "zpag" 2 3
		"_lax" "zpag" 2 3
		 "TAY" "impl" 1 2
		 "LDA" "immd" 2 2
		 "TAX" "impl" 1 2
		"_lax" "immd" 2 2
		 "LDY" "absl" 3 4
		 "LDA" "absl" 3 4
		 "LDX" "absl" 3 4
		"_lax" "absl" 3 4
		 "BCS" "rela" 2 2
		 "LDA" "idry" 2 5
		"_jam" "impl" 1 2
		"_lax" "idry" 2 5
		 "LDY" "zpgx" 2 4
		 "LDA" "zpgx" 2 4
		 "LDX" "zpgy" 2 4
		"_lax" "zpgy" 2 4
		 "CLV" "impl" 1 2
		 "LDA" "absy" 3 4
		 "TSX" "impl" 1 2
		"_las" "absy" 3 4
		 "LDY" "absx" 3 4
		 "LDA" "absx" 3 4
		 "LDX" "absy" 3 4
		"_lax" "absy" 3 4
		 "CPY" "immd" 2 2
		 "CMP" "xidr" 2 6
		"_nop" "immd" 2 2
		"_dcp" "xidr" 2 8
		 "CPY" "zpag" 2 3
		 "CMP" "zpag" 2 3
		 "DEC" "zpag" 2 5
		"_dcp" "zpag" 2 5
		 "INY" "impl" 1 2
		 "CMP" "immd" 2 2
		 "DEX" "impl" 1 2
		"_sbx" "immd" 2 2
		 "CPY" "absl" 3 4
		 "CMP" "absl" 3 4
		 "DEC" "absl" 3 6
		"_dcp" "absl" 3 6
		 "BNE" "rela" 2 2
		 "CMP" "idry" 2 5
		"_jam" "impl" 1 2
		"_dcp" "idry" 2 8
		"_nop" "zpgx" 2 4
		 "CMP" "zpgx" 2 4
		 "DEC" "zpgx" 2 6
		"_dcp" "zpgx" 2 6
		 "CLD" "impl" 1 2
		 "CMP" "absy" 3 4
		"_nop" "impl" 1 2
		"_dcp" "absy" 3 7
		"_nop" "absx" 3 4
		 "CMP" "absx" 3 4
		 "DEC" "absx" 3 7
		"_dcp" "absx" 3 7
		 "CPX" "immd" 2 2
		 "SBC" "xidr" 2 6
		"_nop" "immd" 2 2
		"_isc" "xidr" 2 8
		 "CPX" "zpag" 2 3
		 "SBC" "zpag" 2 3
		 "INC" "zpag" 2 5
		"_isc" "zpag" 2 5
		 "INX" "impl" 1 2
		 "SBC" "immd" 2 2
		 "NOP" "impl" 1 2
		"_sbc" "immd" 2 2
		 "CPX" "absl" 3 4
		 "SBC" "absl" 3 4
		 "INC" "absl" 3 6
		"_isc" "absl" 3 6
		 "BEQ" "rela" 2 2
		 "SBC" "idry" 2 5
		"_jam" "impl" 1 2
		"_isc" "idry" 2 8
		"_nop" "zpgx" 2 4
		 "SBC" "zpgx" 2 4
		 "INC" "zpgx" 2 6
		"_isc" "zpgx" 2 6
		 "SED" "impl" 1 2
		 "SBC" "absy" 3 4
		"_nop" "impl" 1 2
		"_isc" "absy" 3 7
		"_nop" "absx" 3 4
		 "SBC" "absx" 3 4
		 "INC" "absx" 3 7
		"_isc" "absx" 3 7
	}

	proc addr {mode} {
		switch $mode {
			absl { return {Absolute}}
			accu { return {Accumulator}}
			absx { return {Absolute+X}}
			absy { return {Absolute+Y}}
			immd { return {Immediate}}
			impl { return {Implied}}
			indr { return {Indirect}}
			xidr { return {ZP+X Indirect}}
			idry { return {ZP Indirect+Y}}
			rela { return {Relative}}
			zpag { return {ZP Absolute}}
			zpgx { return {ZP Absolute+X}}
			zpgy { return {ZP Absolute+Y}}
		}
	}

	proc desc {inst} {
		switch $inst {
			ADC {return {Add Memory to Accumulator with Carry}}
			AND {return {AND Memory with Accumulator}}
			ASL {return {Arithmetic Shift Left}}
			BCC {return {Branch on Carry Clear}}
			BCS {return {Branch on Carry Set}}
			BEQ {return {Branch on Result Zero}}
			BIT {return {Test Bits in Memory with Accumulator}}
			BMI {return {Branch on Result Minus}}
			BNE {return {Branch on Result Not Zero}}
			BPL {return {Branch on Result Plus}}
			BRK {return {Break Command}}
			BVC {return {Branch on Overflow Clear}}
			BVS {return {Branch on Overflow Set}}
			CLC {return {Clear Carry Flag}}
			CLD {return {Clear Decimal Mode}}
			CLI {return {Clear Interrupt Disable}}
			CLV {return {Clear Overflow Flag}}
			CMP {return {Compare Memory and Accumulator}}
			CPX {return {Compare Index Register X to Memory}}
			CPY {return {Compare Index Register Y to Memory}}
			DEC {return {Decrement Memory by One}}
			DEX {return {Decrement Index Register X by One}}
			DEY {return {Decrement Index Register Y by One}}
			EOR {return {XOR Memory with Accumulator}}
			INC {return {Increment Memory by One}}
			INX {return {Increment Index Register X by One}}
			INY {return {Increment Index Register Y by One}}
			JMP {return {Jump}}
			JSR {return {Jump to Subroutine}}
			LDA {return {Load Accumulator with Memory}}
			LDX {return {Load Index Register X from Memory}}
			LDY {return {Load Index Register Y from Memory}}
			LSR {return {Logical Shift Right}}
			NOP {return {No Operation}}
			ORA {return {OR Memory with Accumulator}}
			PHA {return {Push Accumulator on Stack}}
			PHP {return {Push Processor Status on Stack}}
			PLA {return {Pull Accumulator from Stack}}
			PLP {return {Pull Processor Status from Stack}}
			ROL {return {Rotate Left}}
			ROR {return {Rotate Right}}
			RTI {return {Return from Interrupt}}
			RTS {return {Return from Subroutme}}
			SBC {return {Subtract Memory from Accumulator with Borrow}}
			SEC {return {Set Carry Flag}}
			SED {return {Set Decimal Mode}}
			SEI {return {Set Interrupt Disable}}
			STA {return {Store Accumulator in Memory}}
			STX {return {Store Index Register X in Memory}}
			STY {return {Store Index Register Y in Memory}}
			TAX {return {Transfer Accumulator to Index Register X}}
			TAY {return {Transfer Accumulator to Index Register Y}}
			TSX {return {Transfer Stack Pointer to Index Register X}}
			TXA {return {Transfer Index Register X to Accumulator}}
			TXS {return {Transfer Index Register X to Stack Pointer}}
			TYA {return {Transfer Index Register Y to Accumulator}}
			_anc {return {AND Memory with Accumulator then Move Negative Flag to Carry Flag}}
			_arr {return {AND Accumulator then Rotate Right}}
			_asr {return {AND then Logical Shift Right}}
			_dcp {return {Decrement Memory by One then Compare with Accumulator}}
			_isc {return {Increment Memory by One then SBC then Subtract Memory from Accumulator with Borrow}}
			_jam {return {Halt the CPU}}
			_las {return {AND Memory with Stack Pointer}}
			_lax {return {Load Accumulator and Index Register X from Memory}}
			_nop {return {No Operation}}
			_rla {return {Rotate Left then AND with Accumulator}}
			_rra {return {Rotate Right and Add Memory to Accumulator}}
			_sax {return {Store Accumulator AND Index Register X in Memory}}
			_sbc {return {Subtract Memory from Accumulator with Borrow}}
			_sbx {return {Subtract Memory from Accumulator AND Index Register X}}
			_sha {return {Store Accumulator AND Index Register X AND Value}}
			_shs {return {Transfer Accumulator AND Index Register X to Stack Pointer then Store Stack Pointer AND Hi-Byte in Memory}}
			_shx {return {Store Index Register X AND Value}}
			_shy {return {Store Index Register Y AND Value}}
			_slo {return {Arithmetic Shift Left then OR Memory with Accumulator}}
			_sre {return {Logical Shift Right then XOR Memory with Accumulator}}
			_xaa {return {Non-deterministic Operation of Accumulator, Index Register X, Memory and Bus Contents}}
		}
	}

	proc oper {inst} {
		# A=Accumulator, M[#]=Memory[bit#], NVDIZC=Flags, PSXY=Registers, PCL/PCH=Program Counter Low/High-Byte
		#
		switch $inst {
			ADC {return {A + M + C → A, C}}
			AND {return {A ∧ M → A}}
			ASL {return {C ← M7...M0 ← 0}}
			BCC {return {Branch on C = 0}}
			BCS {return {Branch on C = 1}}
			BEQ {return {Branch on Z = 1}}
			BIT {return {A ∧ M, M7 → N, M6 → V}}
			BMI {return {Branch on N = 1}}
			BNE {return {Branch on Z = 0}}
			BPL {return {Branch on N = 0}}
			BRK {return {PC + 2↓, [FFFE] → PCL, [FFFF] → PCH, 1 → I}}
			BVC {return {Branch on V = 0}}
			BVS {return {Branch on V = 1}}
			CLC {return {0 → C}}
			CLD {return {0 → D}}
			CLI {return {0 → I}}
			CLV {return {0 → V}}
			CMP {return {A - M}}
			CPX {return {X - M}}
			CPY {return {Y - M}}
			DEC {return {M - 1 → M}}
			DEX {return {X - 1 → X}}
			DEY {return {Y - 1 → Y}}
			EOR {return {A ⊻ M → A}}
			INC {return {M + 1 → M}}
			INX {return {X + 1 → X}}
			INY {return {Y + 1 → Y}}
			JMP {return {[PC + 1] → PCL, [PC + 2] → PCH}}
			JSR {return {PC + 2↓, [PC + 1] → PCL, [PC + 2] → PCH}}
			LDA {return {M → A}}
			LDX {return {M → X}}
			LDY {return {M → Y}}
			LSR {return {0 → M7...M0 → C}}
			NOP {return {No operation}}
			ORA {return {A ∨ M → A}}
			PHA {return {A↓}}
			PHP {return {P↓}}
			PLA {return {A↑}}
			PLP {return {P↑}}
			ROL {return {C ← M7...M0 ← C}}
			ROR {return {C → M7...M0 → C}}
			RTI {return {P↑ PC↑}}
			RTS {return {PC↑, PC + 1 → PC}}
			SBC {return {A - M - ~C → A}}
			SEC {return {1 → C}}
			SED {return {1 → D}}
			SEI {return {1 → I}}
			STA {return {A → M}}
			STX {return {X → M}}
			STY {return {Y → M}}
			TAX {return {A → X}}
			TAY {return {A → Y}}
			TSX {return {S → X}}
			TXA {return {X → A}}
			TXS {return {X → S}}
			TYA {return {Y → A}}
			_anc {return {A ∧ M → A, N → C}}
			_arr {return {(A ∧ M) / 2 → A}}
			_asr {return {(A ∧ M) / 2 → A}}
			_dcp {return {M - 1 → M, A - M}}
			_isc {return {M + 1 → M, A - M → A}}
			_jam {return {Stop execution}}
			_las {return {M ∧ S → A, X, S}}
			_lax {return {M → A, X}}
			_nop {return {No operation}}
			_rla {return {C ← M7...M0 ← C, A ∧ M → A}}
			_rra {return {C → M7...M0 → C, A + M + C → A}}
			_sax {return {A ∧ X → M}}
			_sbc {return {A - M - ~C → A}}
			_sbx {return {(A ∧ X) - M → X}}
			_sha {return {A ∧ X ∧ V → M}}
			_shs {return {A ∧ X → S, S ∧ (H + 1) → M}}
			_shx {return {X ∧ (H + 1) → M}}
			_shy {return {Y ∧ (H + 1) → M}}
			_slo {return {M * 2 → M, A ∨ M → A}}
			_sre {return {M / 2 → M, A ⊻ M → A}}
			_xaa {return {(A ∨ V) ∧ X ∧ M → A}}
		}
	}

	proc flag {inst} {
		# Negative, oVerflow, Decimal, Interrupt, Zero, Carry :: 1|0 suffix indicates explicit "set" or "reset"
		#
		switch $inst {
			ADC {return {N V - - Z C }}
			AND {return {N - - - Z - }}
			ASL {return {N - - - Z C }}
			BCC {return {- - - - - - }}
			BCS {return {- - - - - - }}
			BEQ {return {- - - - - - }}
			BIT {return {N V - - Z - }}
			BMI {return {- - - - - - }}
			BNE {return {- - - - - - }}
			BPL {return {- - - - - - }}
			BRK {return {- - - I1- - }}
			BVC {return {- - - - - - }}
			BVS {return {- - - - - - }}
			CLC {return {- - - - - C0}}
			CLD {return {- - D0- - - }}
			CLI {return {- - - I0- - }}
			CLV {return {- V0- - - - }}
			CMP {return {N - - - Z C }}
			CPX {return {N - - - Z C }}
			CPY {return {N - - - Z C }}
			DEC {return {N - - - Z - }}
			DEX {return {N - - - Z - }}
			DEY {return {N - - - Z - }}
			EOR {return {N - - - Z - }}
			INC {return {N - - - Z - }}
			INX {return {N - - - Z - }}
			INY {return {N - - - Z - }}
			JMP {return {- - - - - - }}
			JSR {return {- - - - - - }}
			LDA {return {N - - - Z - }}
			LDX {return {N - - - Z - }}
			LDY {return {N - - - Z - }}
			LSR {return {N0- - - Z C }}
			NOP {return {- - - - - - }}
			ORA {return {N - - - Z - }}
			PHA {return {- - - - - - }}
			PHP {return {- - - - - - }}
			PLA {return {N - - - Z - }}
			PLP {return {N V D I Z C }}
			ROL {return {N - - - Z C }}
			ROR {return {N - - - Z C }}
			RTI {return {N V D I Z C }}
			RTS {return {- - - - - - }}
			SBC {return {N V - - Z C }}
			SEC {return {- - - - - C1}}
			SED {return {- - D1- - - }}
			SEI {return {- - - I1- - }}
			STA {return {- - - - - - }}
			STX {return {- - - - - - }}
			STY {return {- - - - - - }}
			TAX {return {N - - - Z - }}
			TAY {return {N - - - Z - }}
			TSX {return {N - - - Z - }}
			TXA {return {N - - - Z - }}
			TXS {return {- - - - - - }}
			TYA {return {N - - - Z - }}
			_anc {return {N - - - Z C }}
			_arr {return {N V - - Z C }}
			_asr {return {N0- - - Z C }}
			_dcp {return {N - - - Z C }}
			_isc {return {N V - - Z C }}
			_jam {return {- - - - - - }}
			_las {return {N - - - Z - }}
			_lax {return {N - - - Z - }}
			_nop {return {- - - - - - }}
			_rla {return {N - - - Z C }}
			_rra {return {N V - - Z C }}
			_sax {return {- - - - - - }}
			_sbc {return {N V - - Z C }}
			_sbx {return {N - - - Z C }}
			_sha {return {- - - - - - }}
			_shs {return {- - - - - - }}
			_shx {return {- - - - - - }}
			_shy {return {- - - - - - }}
			_slo {return {N - - - Z C }}
			_sre {return {N - - - Z C }}
			_xaa {return {N - - - Z - }}
		}
	}

	section -collapsed "6502_code" {
		set _ " "
		set B " bytes"
		for { set i 0 } { $i < $code_count } { incr i } {
			section -collapsed "" {
				set opcode 		[uint8]
				set inst      	[lindex $opcodes [expr $opcode*4]]
				set mode 		[lindex $opcodes [expr $opcode*4 + 1]]
				set length     	[lindex $opcodes [expr $opcode*4 + 2]]
				set cycles     	[lindex $opcodes [expr $opcode*4 + 3]]
				set mode_text 	[addr $mode]
				set flag_text 	[flag $inst]
				set desc_text 	[desc $inst]
				set oper_text  	[oper $inst]
				switch $mode {
					accu { set operand "" 																	  }
					impl { set operand "" 																	  }
					absl { set operand [uint16]; set operand  \$[string toupper [format %04x $operand]] 	  }
					absx { set operand [uint16]; set operand  \$[string toupper [format %04x $operand]],X 	  }
					absy { set operand [uint16]; set operand  \$[string toupper [format %04x $operand]],Y 	  }
					indr { set operand [uint16]; set operand (\$[string toupper [format %04x $operand]]) 	  }
					xidr { set operand [uint8];  set operand (\$[string toupper [format %02x $operand]],X) 	  }
					idry { set operand [uint8];  set operand (\$[string toupper [format %02x $operand]]),Y 	  }
					immd { set operand [uint8];  set operand #\$[string toupper [format %02x $operand]] 	  }
					zpag { set operand [uint8];  set operand  \$[string toupper [format %02x $operand]] 	  }
					zpgx { set operand [uint8];  set operand  \$[string toupper [format %02x $operand]],X 	  }
					zpgy { set operand [uint8];  set operand  \$[string toupper [format %02x $operand]],Y 	  }
					rela { set operand [uint8];  if { $operand >= 128 } { set rel [expr $operand - 256]$B
												 } else { set rel +$operand$B }
												 set operand $rel$_\([string toupper [format %02x $operand]]) }
				}
				set i [expr $i + $length - 1]
				entry $mode_text $desc_text  		  $length [expr [pos]-$length]
				entry $flag_text $cycles:$_$oper_text $length [expr [pos]-$length]
				sectionname  $inst
				if { [string length $inst] == 3 } {
					sectionvalue $operand
				} else {
					sectionvalue _$operand
				}
			}
		}
	}
}

# Call this from a catch when binary file terminates mid-instruction (ie, ends with data). Example in: 6502.tcl
#
proc 6502_parse_error {} {
	entry "" ""  [expr [pos]-1] [expr [pos]-1]
	sectionname  "parse_error:"
	sectionvalue "6502 operand missing/incomplete"
}
