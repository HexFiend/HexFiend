# Binary Template for Bitcoin Core Block content: Extended version
#   Process a single Bitcoin block contained in a Bitcoin Core blk*.dat file. 
#
#   Bitcoin Core blk*.dat files begin with 4 Magic bytes. These Magic bytes serve as a preamble to each block 
#   in the blk*.dat file. When invoked this template will align correctly on the initial block in the blk*.dat
#   file which begins with the Magic bytes. Different blocks can be examined by using the Hex Fiend 'Anchor 
#   Template at Offset' feature and anchoring on any Magic bytes in the file before invoking the Template. 
#   For each transaction ScriptSig, ScriptPubKey, and Witness data are simply labeled as Hex Fiend byte fields. 
#
#
#   In this expanded version additional processing is available as follows:
#
#     For each Transaction in the block this Template will decode the Script in ScriptSigs and ScriptPubKeys 
#     accompanying inputs and outputs, respectively. Each ScriptPubKey and non-empty ScriptSig will be displayed as
#     a Hex Fiend byte field. Following each there will be a collapsed Hex Fiend Section called 'Decode'. Expanding
#     this Section will reveal a labeled version of the respective Script content. Depending on context sometimes
#     further decoding is done on pushed data.
#
#     For Witness data there may be multiple stack items for each input. Each non-empty stack item for each input 
#     is displayed as a Hex Fiend byte field. Witness stack items are not necessarily Script. If the stack item is 
#     interpretable as Script there will be an additional 'Script' Section for that item. There will also be a 
#     'Decode' section if the stack item is interpretable as a construct such as a DER signature.
#     
#
# This Template is offered AS-IS. The 'Decode' sections are best effort. 
#
# Because of the decoding burden this template may run slowly on older machines such as my old Intel MBA (2019). The 
# execution time on both older and newer machines is reasonable for initial results where the 'TRANSACTIONS' section is 
# collapsed by default. But expanding the 'TRANSACTIONS' section leads to a noticeable delay on older machines. Even on 
# an M2 MBA there can sometimes be a noticeable delay.  
#
# To mitigate the performance delay the variables XTND_SS, XTND_SPK and XTND_WIT can be set here to control extended decoding 
# of ScriptSig, ScriptPubKey, and Witness data respectively. They are set to '1' by default to decode their data. Set them  
# to '0' to inhibit decoding. The speedup for not decoding is noticeable and can be dramatic on older machines if all three 
# are '0'. As a practical matter with all three set to '0' the performance of this Extended Template is indistinguishable 
# from the non-Extended Template version 'BTCBlock.tcl'.
#


####################################################
set XTND_SS  1  ; # extended ScriptSig decoding
set XTND_SPK 1  ; # extended ScriptPubKey decoding
set XTND_WIT 1  ; # extended Witness decoding
set extendedVersion [expr $XTND_SS | \
                    [expr ($XTND_SPK<<1)] | \
                    [expr ($XTND_WIT<<2)]]

set XTND_SS_MASK   1
set XTND_SPK_MASK  [expr 1<<1]
set XTND_WIT_MASK  [expr 1<<2]
####################################################


proc initTemplate {} {
  global opcodeTable {}
  global SighashFlagTable {}
  
  set opcodeTable {  \
        {0 "OP_0"} \
       {76 "OP_PUSHDATA1"} \
       {77 "OP_PUSHDATA2"} \
       {78 "OP_PUSHDATA4"} \
       {79 "OP_INEGATE"} \
       {97 "OP_NOP"} \
       {99 "OP_IF"} \
      {100 "OP_NOTIF"} \
      {103 "OP_ELSE"} \
      {104 "OP_ENDIF"} \
      {105 "OP_VERIFY"} \
      {106 "OP_RETURN"} \
      {107 "OP_TOTALSTACK"} \
      {108 "OP_FROMALTSTACK"} \
      {109 "OP_2DROP"} \
      {110 "OP_2DUP"} \
      {111 "OP_3DUP"} \
      {112 "OP_2OVER"} \
      {113 "OP_2ROT"} \
      {114 "OP_2SWAP"} \
      {115 "OP_IFDUP"} \
      {116 "OP_DEPTH"} \
      {117 "OP_DROP"} \
      {118 "OP_DUP"} \
      {119 "OP_NIP"} \
      {120 "OP_OVER"} \
      {121 "OP_PICK"} \
      {122 "OP_ROLL"} \
      {123 "OP_ROT"} \
      {124 "OP_SWAP"} \
      {125 "OP_TUCK"} \
      {130 "OP_SIZE"} \
      {135 "OP_EQUAL"} \
      {136 "OP_EQUALVERIFY"} \
      {139 "OP_1ADD"} \
      {140 "OP_1SUB"} \
      {143 "OP_NEGATE"} \
      {144 "OP_ABS"} \
      {145 "OP_NOT"} \
      {146 "OP_0NOTEQUAL"} \
      {147 "OP_ADD"} \
      {148 "OP_SUB"} \
      {154 "OP_BOOLAND"} \
      {155 "OP_BOOLOR"} \
      {156 "OP_NUMEQUAL"} \
      {157 "OP_NUMEQUALVERIFY"} \
      {158 "OIP_NUMNOTEQUAL"} \
      {159 "OP_LESSTHAN"} \
      {160 "OP_GREATERTHAN"} \
      {161 "OP_LESSTHANOREQUAL"} \
      {162 "OP_GREATERTHANOREQUAL"} \
      {163 "OP_MIN"} \
      {164 "OP_MAX"} \
      {165 "OP_WITHIN"} \
      {166 "OP_RIPEMD"} \
      {167 "OP_SHA1"} \
      {168 "OP_SHA256"} \
      {169 "OP_HASH160"} \
      {170 "OP_HASH256"} \
      {171 "OP_CODESEPARATOR"} \
      {172 "OP_CHECKSIG"} \
      {173 "OP_CHKSIGVERIFY"} \
      {174 "OP_CHECKMULTISIG"} \
      {175 "OP_CHECKMULTISIGVERIFY"} \
      {176 "OP_NOP1"} \
      {177 "OP_CHECKLOCKTIMEVERIFY"} \
      {178 "OP_CHECKSEQUENCEVERIFY"} \
      {179 "OP_NOP4"} \
      {180 "OP_NOP5"} \
      {181 "OP_NOP6"} \
      {182 "OP_NOP7"} \
      {183 "OP_NOP8"} \
      {184 "OP_NOP9"} \
      {185 "OP_NOP10"} \
      {186 "OP_CHECKSIGADD"} \
  }
  
  set SighashFlagTable { \
     {1 "SIGHASH_ALL"} \
     {2 "SIGHASH_NONE"} \
     {3 "SIGHASH_SINGLE"} \
    {65 "SIGHASH_ALL"} \
    {66 "SIGHASH_NONE"} \
    {67 "SIGHASH_SINGLE"} \
   {129 "SIGHASH_ALL/ANY1PAY"} \
   {130 "SIGHASH_NONE/ANY1PAY"} \
   {131 "SIGHASH_SINGLE/ANY1PAY"} \
   {193 "SIGHASH_ALL/ANY1PAY"} \
   {194 "SIGHASH_NONE/ANY1PAY"} \
   {195 "SIGHASH_SINGLE/ANY1PAY"} \
  }

  return
}

# Return a BTC varint value. Presence of an argument causes the varint to be displayed as a Hex Fiend 
# field with the argument as the label. The file pointer is left at the first byte past the varint.
proc getVarint {{label ""}} {
    # Read the indicator byte
    set val [uint8]
    
    if {$val == 0xfd} {
      set val    [uint16]
      set type   "uint16"
      set moveit -2
    } elseif {$val == 0xfe} {
       set val    [uint32]
       set type   "uint32"
       set moveit -4
    } elseif {$val == 0xff} {
       set val    [uint64]
       set type   "uint64"
       set moveit -8
    } else {
       set moveit -1
       set type   "uint8"
    }
    
    if {$label != ""}  {
      move $moveit
      if {$type != "uint8"} {
        move -1
        uint8 -hex "Varint hint"
      }
      $type $label
    }

    return $val
}

proc isPubKey {} {
  set klen [uint8]
  set op [uint8]
  move -2
  set retval 1
  
  if {$klen == 0x21} {
    # compressed key?
    if {$op != 2 && $op != 3} {
      set retval 0
    }
  } elseif {$klen == 0x41} {
    # uncompressed key?
    if {$op != 4} {
      set retval 0
    }
  } else {
    set retval 0
  }
  
  return $retval
}

proc decodePubKey {len} {
  set retval 1
  
  if {$len == 33} {
    bytes $len "Compressed PubKey"
  } elseif {$len == 65} {
    bytes $len "Uncompressed PubKey"
  } else {
    bytes $len "Unk Key"
    set retval 0
  }
  
  return $retval
}

proc decodeMultiSig {len} {
  set moved 0  ; # need to track relative position because Hex Fiend [pos] does not work for non-zero origin
  set OP_ [expr {[uint8] - 80} ]
  if {![isPubKey]} {
    move -1
    return [list 0 $len]
  }
  section -collapsed "m of n Multisig PubKeys" {
    move -1
    uint8 "m  (OP_$OP_)"
    incr moved
    set sigs 1
    while {$sigs} {
      set len [uint8]
      incr moved
      if {$len == 33 || $len == 65} {
        decodePubKey $len
        incr moved $len
      } else {
        move -1
        incr moved -1
        set sigs 0
      }
    }
    
    set OP_ [expr {[uint8] - 80} ]
    move -1
    uint8 "n  (OP_$OP_)"
    incr moved
    
    set op [uint8]
    if {$op == 0xae} {
      set type "OP_CHECKMULTISIG"
    } elseif {$op == 0xaf} {
      set type "OP_CHECKMULTISIGVERIFY"
    } elseif {$op == 0xba}  {
      set type "OP_CHECKSIGADD"
    } else {
      set type "OP_IDK"
    }
    move -1
    uint8 "$type" 
    incr moved
  }
  return [list 1 $moved]
}

proc decodeSig {} {
  set moved 0
  section -collapsed "Signature" {
    uint8 -hex "DER"
    uint8 "struct length"
    uint8 "integer marker"
    set r [uint8]
    move -1
    uint8 "r length"
    bytes $r "r"
    uint8 "integer marker"
    set s [uint8]
    move -1
    uint8 "s length"
    bytes $s "s"
    set flag [uint8]
    move -1
    uint8 [getSIGHASH_flag $flag]
    set moved [expr 7 + $r + $s]
  }
  return $moved
}

# Check DER signature for sanity. Read the bytes as if it is a correctly formed signature interpreting the bytes accordingly.
# If any consistency check fails or the resulting byte count doesn't match the anticipated length the proc fails. File 
# pointer left at the byte after the byte count field.
proc isDERSignature {len}  {
  set curpos 0
  set DER [uint8]
  incr curpos
  if {$DER != 0x30} {
    move -$curpos
    return 0
  }
  
  set slen [uint8] 
  incr curpos
  if {[expr {$slen + 3}] != $len} {
    move -$curpos
    return 0
  }
  
  for {set i 0} {$i < 2} {incr i} {
    set intmrk [uint8]
    incr curpos
    if {$intmrk != 2} {
      move -$curpos
      return 0
    }
  
    set pslen [uint8]
    incr curpos
    if {[expr {$pslen + $curpos}] > $len} {
      move -$curpos
      return 0
    }
  
    move $pslen
    incr curpos $pslen
  }
  set sighash [uint8]
  incr curpos
  move -$curpos
  
  if {$curpos != $len} {
    return 0
  }
  return 1
}


# Look for SIGHASH flag and map it to something interpretable for later display.
proc getSIGHASH_flag {flag} {
  global SighashFlagTable {}
  
  set item [lsearch -inline -index 0 $SighashFlagTable $flag]
  if {$item == ""} {
    return "SIGHASH_UNSUP"
  }
  return [lindex $item 1]
}

# Look for OpCode and map it to something interpretable for later display.
proc getOP_CODE {} {
  global opcodeTable {} 

  set retval "OP_IDK"
  set auxval1 0   ; # skip-byte parameter for push opcodes; the bad opcode value if OP_IDK
  
  set OpCode [uint8]

  # First check for opcodes that do not have a singular representation
  if {$OpCode > 0  &&  $OpCode < 76} {
    set retval "OP_PUSH"
    set auxval1 $OpCode
  } elseif {$OpCode > 80  &&  $OpCode < 97} {
    set retval "OP_1-16"
    set auxval1 [expr $OpCode - 80]
  } else {
    # OK to now search the list
    set ocitem [lsearch -index 0 -inline $opcodeTable $OpCode]
    if {$ocitem != ""} {
      set retval [lindex $ocitem 1]
    }
  }
    
  # Post processing for OP_PUSHDATAx special cases where the info after the opcode is the number of bytes 
  # to push. Similar to varint. The opcode may specify different size count objects (1, 2, or 4 bytes).
  if {$retval == "OP_PUSHDATA1"} {
    set auxval1 [uint8]
  } elseif {$retval == "OP_PUSHDATA2"} {
    set auxval1 [uint16]
  } elseif {$retval == "OP_PUSHDATA4"} {
    set auxval1 [uint32]
  }
  
  # If the Opcode hasn't been discovered save the offending Opcode.
  if {$retval == "OP_IDK"} {
    set auxval1 $OpCode
  }
  
  return [list $retval $auxval1]
}

# Return a list of op codes. If the opcode pushes data the data are skipped to get to the next opcode.
# File pointer left at end of the parsed Script, i.e., 'len' bytes beyond the length spec, even on failed parse.
proc parseScript {len}  {
  set OPCList {}
  set retcode 0
  
  set i 0
  while {$i < $len}  {
    set opcode [getOP_CODE]
    incr i
    lassign $opcode cmd auxval1
    
    # Skip over the bytes pushed for OP_PUSH or OP_PUSHDATAx. The loop index increment must also account for byte count
    # fields for the OP_PUSHDATAx opcodes.
    if {$cmd == "OP_PUSH"} {
      incr i $auxval1
      move $auxval1
    } elseif {$cmd == "OP_PUSHDATA1"} {
      incr i [expr $auxval1 + 1]
      move $auxval1
    } elseif {$cmd == "OP_PUSHDATA2"} {
      incr i [expr $auxval1 + 2]
      move $auxval1
    } elseif {$cmd == "OP_PUSHDATA4"} {
      incr i [expr $auxval1 + 4]
      move $auxval1
    }
    
    if {$i > $len} {
      # The number of bytes processed in the presumed Script exceeds the length of the byte string. Probably not Script. 
      # Set the file pointer to the end of the string. We're done.
      move [expr $len - $i]
      set retcode 1
    } else {
      lappend OPCList $opcode
      if {$cmd == "OP_IDK"} {
        # Either the opcode table is missing the entry or the byte string is not Script. Set the file pointer to the end
        # of the string. We're done.
        move [expr $len - $i]
        set retcode 2
        break
      }
    }
    
  }
  # Return a list consisting of both the return code and the list of opcodes.
  return [list $retcode $OPCList] 
}

# Display Script detail for each opcode discovered in ScriptSig, ScriptPubKey, or possibly a Witness stack item.
proc decodeParse {opcodes len {sats 0}} {
  # Move the input pointer back and process ScriptSig or ScriptPubKey in parallel with the Opcode list and display info in
  # Hex Fiend fields.
  move -$len
  set done 0
  set retval 1
  set flags 0
  set llen [llength $opcodes]
  set label "Decode"

  if {[info level] == 2} {
    # We got here decoding a Witness stack item that we now know is Script. Label the item as such.
    set label "Script"
  } 
  
  section -collapsed $label {
    for {set i 0} {$i < $llen  &&  $done == 0} {incr i} {
      set cur [lindex $opcodes $i]
      lassign $cur code a1
      set ostr $code

      if {$code == "OP_1-16"} { 
        # See if this is the special case of SegWit Version 1 P2TR public key
        set type [decodeStack $a1]
        if {$type == "stOP1TRPUBK"} {
          set retval [showStack $type $a1 $flags]
          set done 1
        } else {
          uint8 [format "OP_%d" $a1]
        }
      } elseif {$code == "OP_PUSHDATA1" || $code == "OP_PUSHDATA2" || $code == "OP_PUSHDATA4"} {
        uint8 $ostr
        if {$code == "OP_PUSHDATA1"} {
          set size "uint8"
        } elseif {$code == "OP_PUSHDATA2"} {
          set size "uint16"
        } else {
          set size "uint32"
        }
        $size "push"
        section -collapsed "<decode pushed>" {
          set type [decodeStack $a1]
          set retval [showStack $type $a1 $flags]
          if {$retval == 0} {set done 1}
        }
      } elseif {$code == "OP_PUSH"} {
        uint8 $ostr
        # To avoid unnesessary formatting create a "<decode pushed>" Section only if it's not a hash as indicated by the length. 
        if {$a1 != 20  &&  $a1 != 32} {
          section -collapsed "<decode pushed>" {
            set type [decodeStack $a1]
            set retval [showStack $type $a1 $flags]
            if {$retval == 0} {set done 1}
          }
        } else {
          set type [decodeStack $a1]
          set retval [showStack $type $a1 $flags]
          if {$retval == 0} {set done 1}
        }
      } elseif {$code == "OP_IDK"} {
        entry "Decode Opcode fail" $cur
        set retval 0
        set done 1
      } else {
        uint8 $ostr
        if {$code == "OP_RETURN"} {
          if {$sats != 0} {
            entry [format "(%d Sats unspendable)" $sats]  ""
          }
          # provide context to subsequent procs that because of OP_RETURN the Script will fail 
          set flags [expr $flags | 1]
        }
      }
    }  ;  # for all opcodes
  }    ;  # Section decode
  
  return $retval
}

# This proc tries to interpret contents of a Witness stack item. The Witness stack items each contain data whose length is
# specified by a preceeding byte count. The data are usually not Script so we don't directly parse for opcodes as with  
# ScriptSig and ScriptPubKey. The data might represent an elemental structure like a signature or public key. 
#
# This proc is also used to suss out ScriptSig and ScriptPubKey data pushed onto the stack. Typically in this case 
# the data are elemental structures and not Script.
# 
# This proc leaves the file pointer at the byte after the length spec...at the beginning of the object.
proc decodeStack {len {context ""}} {
  if {$len == 20} {
    # Data is probably pushed hash. Don't try to interpret it. It's OK if we miss something we could have figured out.
    set type "stIDK"
  } elseif {($len == 64 || $len == 65) && $context == "W"} {
    set type "stSCHNORR"
  } else {
    # Try to guess the object. Key off the first two bytes. Could possibly interpret something we shouldn't.
    set op  [uint8]
    set op1 [uint8]
    move -2   
    
    if {$op == 0x30 && $len >= 67 &&  $len <= 73} {
      set type "stDER"
      if {![isDERSignature $len]} {
        set type "stIDK"
      }
    } elseif {$op == 81} {
      if {$op1 == 32 && $len == 34} {
        # Version 1 SegWit: Taproot. 
        set type "stOP1TRPUBK"
      } else {
        # Simple numeric value
        set type "stOP_81-96"
      }
    } elseif {$op >= 82 && $op <= 96} {
      # Simple numeric value
      set type "stOP_81-96"
    } elseif {$len == 33 && ($op == 2  ||  $op == 3)} {
      # A compressed public key
      set type "stcPK"
    } elseif {$len == 65 && $op == 4} {
      # An uncompressed public key
      set type "stuPK"
    } elseif {$op == 0 && $op1 == 20 && $len == 22} {
      # Version 0 SegWit
      set type "stOP0HASH20"
    } elseif {$op == 0 && $op1 == 32 && $len == 34} {
      # Version 0 SegWit
      set type "stOP0HASH32"
    } else {
      set type "stIDK"
    }
  }
  return $type
}

# Display data previously interpreted from the stack. It is either Witness stack data or possibly data pushed in a ScriptSig or
# ScriptPubKey Script.
#
# this procedure leaves the pointer at the end of the data
proc showStack {type len {flags 0}} { 
  set retval 1
  set moved 0
                   
  switch $type {
    "stDER" {
      # Object already verified as a DER signature. Just display it.
      set moved [decodeSig]
    }
    "stOP_81-96" {
      # Might be a multisig
      set msretval [decodeMultiSig $len]
      set res [lindex $msretval 0]
      if {!$res} {
        set moved $len
        if {$len == 20} {
          bytes $len "<hash>"
        } else {
          bytes $len "<data>"
        }
      } else {
        set moved [lindex $msretval 1] 
      }
    }
    "stcPK" {
      # Might be a compressed public key
      if {![decodePubKey $len]} {
        set retval 0
      }
      set moved $len
    }  
    "stuPK" {
      # Might be an uncompressed public key
      if {![decodePubKey $len]} {
        set retval 0
      }
      set moved $len
    }
    "stOP1TRPUBK" {
      # Version 1 SegWit: Taproot
      showSpecial "OP_1" 32 "<P2TR PubKey>"
      set moved 34
    }
    "stOP0HASH20" {
      showSpecial "OP_0" 20 "<PubKey hash>"
      set moved 22
    }
    "stOP0HASH32" {
      showSpecial "OP_0" 32 "<Script hash>"
      set moved 34
    }
    "stIDK" {
      # No specific clue to data on stack. There are a few cases we can guess.
      if {$len == 20 || $len == 32} {
        # Probably a key hash or a Script hash
        bytes $len "<hash>"
        set moved $len
      } elseif {[expr $flags & 1]} {
        # Arbitrary data (sometimes printable characters) after an OP_RETURN (which guarantees Script result is not TRUE)
        bytes $len "<data>"
        set moved $len
      } else {
        # I (really) Don't Know. If this call is from Witness processing than the stack frame level will be 1. In this
        # case try and parse the unknown bytes to see if they're Script. Otherwise just display them as unknown. Checking
        # the stack frame level also prevents recursive attempts to parse unknown data. If it is unknown data from ScriptSig
        # or ScriptPubKey processing (stack frame level > 1) then display it as unknown. Those two should parse as Script 
        # so if the data are unknown then display them as such. I know. The stack frame check is a hack.
        if {[info level] == 1} {
          set parseRes [parseScript $len]
          set retval [lindex $parseRes 0]
          set moved $len
          if !$retval {
            set script [lindex $parseRes 1]
            set retval [decodeParse $script $len]
          } else {
            # Parse failed. Move back over bytes and display them as unknown.
            move -$len
            bytes $len "<data>"
          }
        } else {
          # It's not a call from the main processing level. Just display the unknown bytes.
          bytes $len "<data>"
          set moved $len
        }
      }
    }
    "stSCHNORR" {
      bytes 64 "Schnorr Sig"
      set moved $len
      if {$len == 65} {
        set flag [uint8]
        move -1
        uint8 [getSIGHASH_flag $flag] 
      }
    }
    default {
     bytes $len "Unknown stXX type"
    }
  }
  
  if {$moved < $len} {
    # There's more stuff here. Try parsing. If it fails just display the bytes as data.
    set diff [expr $len - $moved]
    set pret [parseScript $diff]
    if {![lindex $pret 0]} {
      if { ![decodeParse [lindex $pret 1] $diff] } {
      } 
    } else {
      move -$diff
      bytes $diff "<data>"
    }
  } else {
    # Something is messed up if 'moved' != 'len'. We don't know what if anything was displayed. Move 
    # file pointer to where we think the end of the data is based on the calculated 'moved' and carry on.
    # This has no effect if all is good.
    move [expr $len - $moved]
  }
  return $retval
}

proc showSpecial {type len label} {
  uint8 $type
  uint8 "OP_PUSH"
  bytes $len $label
}

proc decodeCoinbase {nscriptbytes} {
  # Special case of Coinbase Transaction. Check for block height. If the first Script byte is 0x3 
  # the next 3 bytes are the block height.
  move -$nscriptbytes
  if {$nscriptbytes > 3} {
    set bheight [uint8]
    if {$bheight == 3} { 
      # Fake the look of the  Decode section. No need to actually parse the data.
      move -1
      section -collapsed "Decode" {
        uint8 "OP_PUSH"
        uint24 "height"
        if {$nscriptbytes > 4} {
          # Display the remaining bytes
          bytes [expr $nscriptbytes - 4] "<data>" 
        }
      }
    } else {
      # No height info. Just label the bytes as data
      move -1
      section -collapsed "Decode" {
        bytes $nscriptbytes "<data>"
      }
    }
  } else {
    section -collapsed "Decode" {
      bytes $nscriptbytes "<data>"
    }
  }
  
  return
}


# ***********************************************************************************************************************
# ***********************************************************************************************************************

set nullstr ""
set exitMsgs {}
set ALLDONE 0
set szFile [len]

entry "BTCBlock-extended V 1.0" $nullstr
entry $nullstr $nullstr
entry $nullstr $nullstr

if $XTND_SS {
  entry "ON: ScriptSig extended decoding" $nullstr
} else {
  entry "OFF: ScriptSig extended decoding" $nullstr
}
if $XTND_SPK {
  entry "ON: ScriptPubKey extended decoding" $nullstr
} else {
  entry "OFF: ScriptPubKey extended decoding" $nullstr
}
if $XTND_WIT {
  entry "ON: Witness extended decoding" $nullstr
} else {
  entry "OFF: Witness extended decoding" $nullstr
}
entry $nullstr $nullstr

initTemplate

# BTC Magic is 4 bytes (0xF9BEB4D9) but it is more convenient to treat the 4 bytes as a little endian uint32.
set BTCMagic 0xD9B4BEF9

# Block Magic sanity check
if {[uint32] != $BTCMagic} {
  move -4
  entry $nullstr $nullstr
  entry [format "Exit: Bad Magic %4X" [hex 4] ] $nullstr
  entry $nullstr $nullstr
  return
}

# Display the block metadata
move  -4
bytes  4 "Magic"
uint32   "Block length"

# Process actual block data
section "Block header" {
  uint32 -hex "version"
  bytes 32    "prev blk hash"
  bytes 32    "Merkle root"
  unixtime32  "time"
  uint32      "bits"
  uint32      "nonce"
}

# get the number of transactions for the block
set blockTxnum [getVarint "Transaction count"] 

# There may be thousands of transactions. Make a collapsed section to keep the overview initially brief.
section -collapsed "TRANSACTIONS"  {
  set Coinbase 1
  set iscb "(Coinbase)"
  for {set curTx 0} {$curTx < $blockTxnum && $ALLDONE == 0} {incr curTx} {
    section -collapsed "Transaction $curTx $iscb" {     
      uint32 -hex "Tx version"

      # SegWit transaction probe. Read a byte. If it's 0 then it's a marker and it's a SegWit transaction. 
      # If it's non-zero it's a varint indicator byte heading the actual number of inputs.
      set nInputs [uint8]
      if {$nInputs == 0} {
        # It's the marker and this is a SegWit transaction. Read witness data later.
        set segwit 1

        # call out marker and flag byte
        move -1
        uint8 "marker"
        # flag must be non-zero (initally 1 -- see BIP 0141)
        uint8 "flag" 
      
        # Now get the actual number of inputs
        set nInputs [getVarint "Input count"]
      }  else {
        # Not SegWit. Move back and re-read as a varint.
        set segwit 0
        move -1
        set nInputs [getVarint "Input count"]
      }
    
      # process the inputs.
      section -collapsed "INPUTS"  {
        for {set kcnt 0} {$kcnt < $nInputs && $ALLDONE == 0} {incr kcnt} {  
          section "Input $kcnt" {
            bytes 32  "UTXO"
            uint32    "index"
            set nscriptbytes [getVarint "ScriptSig len"]
            if {$nscriptbytes < 0  ||  $nscriptbytes > $szFile} {
              lappend exitMsgs [format "Exit: Bogus ScriptSig nscriptbytes=%d  Tx=%d input=%d" $nscriptbytes $curTx $kcnt]
              set ALLDONE 1
              continue
            }
            if {$nscriptbytes > 0} {
              bytes $nscriptbytes "ScriptSig"
              if {$extendedVersion & $XTND_SS_MASK} {
                # Process the Script if it's not the Coinbase input.
                if !$Coinbase {
                  move -$nscriptbytes
                  set parseRes [parseScript $nscriptbytes]
                  set parseFail [lindex $parseRes 0]
                  set opcode [lindex $parseRes 1]
                  if !$parseFail {               
                    if { ![decodeParse $opcode $nscriptbytes] } {
                      lappend exitMsgs [format "Exit: ScriptSig decodeParse fail Tx: %d  input %d " $curTx $kcnt]
                      set ALLDONE 1
                      continue
                    } 
                  } else {
                    if {$parseFail == 1} {
                      set reason "Out of bounds"
                    } elseif {$parseFail == 2} {
                      set bad [lindex [lindex $opcode [expr [llength $opcode] - 1]] 1]
                      set reason [format "Bad opcode %d (0x%x)" $bad $bad]
                    } else {
                      set reason ""
                    }
                    lappend exitMsgs [format "Opcode parse fail (%d): %s  Tx=%d input=%d" $parseFail $reason $curTx $kcnt]
                  }
                } else {
                  # This code only gets executed only once. Move it out of mainline code.
                  decodeCoinbase $nscriptbytes
                  set Coinbase 0
                  set iscb ""
                }
              } else {   ;  # (extendedVersion & XTND_SS_MASK) != 0
                set Coinbase 0
                set iscb ""
              }  ;  # (extendedVersion & XTND_SS_MASK)  ==  0
            } 
            uint32 -hex "nSequence"
          } ;  # Section Input
        }   ;  # for each input
      }     ;  # Section for all inputs  
      
      # outputs
      set nOutputs [getVarint "Output count"]
    
      # process the outputs
      section -collapsed "OUTPUTS"  {
        for {set kcnt 0} {$kcnt < $nOutputs && $ALLDONE == 0} {incr kcnt} {
          section "Output $kcnt" {
            set sats [uint64]
            move -8
            uint64 "Satoshi"
            set nscriptbytes [getVarint "ScriptPubKey len"]
            if {$nscriptbytes <= 0  ||  $nscriptbytes > $szFile} {
              lappend exitMsgs [format "Exit: Bogus ScriptPubKey nscriptbytes=%d Tx=%d output=%d" $nscriptbytes $curTx $kcnt]
              set ALLDONE 1
              continue
            }
            bytes $nscriptbytes "ScriptPubKey"
            if {$extendedVersion & $XTND_SPK_MASK} {
              move -$nscriptbytes
              set parseRes [parseScript $nscriptbytes]
              set parseFail [lindex $parseRes 0]
              set opcode [lindex $parseRes 1]
              if !$parseFail {
                if { ![decodeParse $opcode $nscriptbytes $sats] } {
                  lappend exitMsgs [format "Exit: ScriptPubKey decodeParse fail Tx: %d  output %d " $curTx $kcnt]
                  set ALLDONE 1
                  continue
                }
              } else  {
                if {$parseFail == 1} {
                  set reason "Out of bounds"
                } elseif {$parseFail == 2} {
                  set bad [lindex [lindex $opcode [expr [llength $opcode] - 1]] 1]
                  set reason [format "Bad opcode %d (0x%x)" $bad $bad]
                } else {
                  set reason ""
                }
                lappend exitMsgs [format "Opcode parse fail (%d): %s  Tx=%d output=%d" $parseFail $reason $curTx $kcnt]
              }
            }   ;  # (extendedVersion & XTND_SPK_MASK) != 0 
          }     ;  # Section Output
        }       ;  # for each output
      }         ;  # Section all outputs

      #if it's a Segwit transaction process the witness data for each input
      if {$segwit} {
        section -collapsed "WITNESS DATA"  {
          # this is the witness data for each input
          for {set kcnt 0} {$kcnt < $nInputs && $ALLDONE == 0} {incr kcnt} {
            section "Witness Input $kcnt" {
              set nwitstack [getVarint "STACK COUNT"]
              section -collapsed "Stack"  {
                for {set l 0} {$l < $nwitstack} {incr l} {  
                  set ilabel [format "Item %d length" [expr $l + 1]]
                  set nscriptbytes [getVarint $ilabel] 
                  if {$nscriptbytes < 0  ||  $nscriptbytes > $szFile} {
                    lappend exitMsgs [format "Exit: Bogus Witness stack nscriptbytes=%d Tx=%d input=%d item=%d" $nscriptbytes $curTx $kcnt [expr $l + 1]]
                    set ALLDONE 1
                    continue
                  }
                  if {$nscriptbytes > 0 } {
                    set ilabel [format "Item %d" [expr $l + 1]]
                    bytes $nscriptbytes $ilabel
                    
                    if {$extendedVersion & $XTND_WIT_MASK} {
                      move -$nscriptbytes
                      section -collapsed "Decode" {
                        set wType [decodeStack $nscriptbytes "W"]
                        set retval [showStack $wType $nscriptbytes]
                        if {!$retval} { 
                          lappend exitMsgs [format "Exit: Witness showStack fail Tx=%d  input=%d item=%d" $curTx $kcnt [expr $l + 1]]
                          set ALLDONE 1
                          continue
                        }
                      }
                    }  ; # (extendedVersion & XTND_WIT_MASK) != 0
                  }    ; # nscriptbytes > 0
                }      ; # for each stack item
              }        ; # Section stack items   
            }          ; # Section Witness input   
          }            ; # for each input
        }              ; # Section Witness data
      }                ; # process Segwit data

      if {$ALLDONE == 0} {
        uint32 "nLockTime"
      } 
    } ; # Section single transaction
  }   ; # for each transaction
}     ; # Section all transactions


entry " " $nullstr
lappend exitMsgs "Done"
for {set i 0} {$i < [llength $exitMsgs]} {incr i} {
  set label [lindex $exitMsgs $i]
  entry $label $nullstr 
}
entry " " $nullstr

