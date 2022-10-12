# Binary Temnplate for Bitcoin Core Block content
#   Process a single Bitcoin block contained in a Bitcoin Core blk*.dat file. 
#
#   Bitcoin Core blk*.dat files begin with 4 Magic bytes. These Magic bytes serve as a preamble to each block 
#   in the blk*.dat file. When invoked this template will align correctly on the initial block in the blk*.dat
#   file. Different blocks can be examined by using the Hex Fiend 'Anchor Template at Offset' feature and 
#   anchoring on any Magic bytes in the file.



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
      $type $label
    }

    return $val
}

# BTC Magic is 4 bytes (0xF9BEB4D9) but it is more convenient to treat the 4 bytes as a little endian uint32.
set BTCMagic 0xD9B4BEF9


# Block Magic sanity check
if {[uint32] != $BTCMagic} {
  move -4
  error "[format "Bad Magic %4X" [hex 4] ]"
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

# Get the number of transactions for the block
set blockTxnum [getVarint]

# There may be hundreds of transactions. Make a collapsed section to keep the overview initially brief.
section -collapsed "TX COUNT $blockTxnum"  {
  set Coinbase 1
  for {set tx 0} {$tx < $blockTxnum} {incr tx} {
    set iscb ""
    if $Coinbase {set iscb "(Coinbase)"}
    section -collapsed "Transaction $tx $iscb" {
      uint32 -hex "Tx version"
  
      # If next varint is 0 then we've read a (single byte) marker and it's a SegWit transaction. 
      # If the varint is non-zero it's the actual number of inputs
      set nInputs [getVarint]
      if {$nInputs == 0} {
        # It's the marker and this is a SegWit transaction. Read witness data later.
        set segwit 1
  
        # Call out marker and flag byte
        move -1
        uint8 "marker"
        uint8 "flag"
        
        # Now get the actual number of inputs
        set nInputs [getVarint]
      }  else {
        set segwit 0
      }
      
      # Process the inputs
      section -collapsed "INPUT COUNT $nInputs"  {
        for {set k 0} {$k < $nInputs} {incr k} {  
          section "Input $k" {
            bytes 32  "UTXO"
            uint32    "index"
  
            set nscriptbytes [getVarint "ScriptSig len"]
            if {$nscriptbytes > 0} {
              # Check for block height. If it's the Coinbase transaction and the first script byte 
              # is 0x3 then the next 3 bytes are the block height.
              if $Coinbase {
                set bheight [uint8]
                if {$bheight == 3} { 
                  uint24 "height"
                  move -3 
                } 
                # Move back to beginning of script.
                move -1
                set Coinbase 0
              } 
              bytes $nscriptbytes "ScriptSig"
            } 

            uint32 -hex "nSequence"
          }
        }
      }
  
      # Outputs
      set nOutputs [getVarint]
      
      # Process the outputs
      section -collapsed "OUTPUT COUNT $nOutputs"  {
        for {set k 0} {$k < $nOutputs} {incr k} {
          section "Output $k" {
            uint64 "Satoshi"
            set nscriptbytes [getVarint "ScriptPubKey len"]
            bytes $nscriptbytes "ScriptPubKey"
          }
        }
      }
  
      # If it's a Segwit transaction process the Witness data for each input
      if {$segwit} {
        section -collapsed "WITNESS DATA"  {
          # This is the witness data for each input
          for {set k 0} {$k < $nInputs} {incr k} {
            section "Witness Input $k" {
              set nwitstack [getVarint "STACK COUNT"]
              section -collapsed "Stack"  {
                for {set l 0} {$l < $nwitstack} {incr l} {
                  set nscriptbytes [getVarint]
                  if {$nscriptbytes > 0} {
                    bytes $nscriptbytes "item [expr $l + 1]: $nscriptbytes bytes"
                  } else {
                    move -1
                    bytes 1 "item [expr $l + 1]: 0 bytes"
                  }
                } ; # for each stack item
              }   ; # Section stack items   
            }     ; # Section Witness input   
          }       ; # for each input
        }         ; # Section Witness data
      }           ; # process Segwit data

      uint32 "nLockTime"

    } ; # Section single transaction
  } ; # for each transaction
} ; # Section all transactions
