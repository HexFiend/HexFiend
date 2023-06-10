# Apple/Applesauce WOZ.tcl
# Binary format for Apple II disk images in the Applesauce WOZ format.
# https://applesaucefdc.com/woz/reference2/
# 2022 Aug 13 | chris-torrence | Initial implementation

requires 0 "574F5A" ;# WOZ
requires 4 "FF0A0D0A" ;# guard bytes, 0xFF/linefeed/carriage return/linefeed
set woz [ascii 4]
ascii 4
entry "Signature" $woz 4 0
entry "Guardbytes" "FF0A0D0A" 4 4
set crc32 [uint32 -hex "CRC32"]

# Return current file position minus offset
# Useful when tying data chunks to their file location.
proc shiftPosByOffset {offset} {
  return [expr [pos] - $offset]
}

proc ChunkINFO {} {
  section "INFO" {
    set chunkSize [uint32 "Size"]
    set version [uint8 "Version"]
    set diskType [uint8]
    entry "Disk Type" [expr $diskType == 1 ? "5.25" : "3.5"] 1 [shiftPosByOffset 1]
    set writeProt [uint8]
    entry "Write Protected" [expr $writeProt ? true : false] 1 [shiftPosByOffset 1]
    set sync [uint8]
    entry "Synchronized" [expr $sync ? true : false] 1 [shiftPosByOffset 1]
    set cleaned [uint8]
    entry "Cleaned MC3470" [expr $cleaned ? true : false] 1 [shiftPosByOffset 1]
    str 32 "utf8" "Creator"
    if {$version >= 2} {
      set sides [uint8 "Disk Sides"]
      set bootSector [uint8]
      switch $bootSector {
        0 { set bootSectorStr "Unknown" }
        1 { set bootSectorStr "16-sector" }
        2 { set bootSectorStr "13-sector" }
        3 { set bootSectorStr "Both 16+13 sector" }
        default { set bootSectorStr "Invalid" }
      }
      entry "Boot Sector" $bootSectorStr 1 [shiftPosByOffset 1]
      set bitTiming [uint8]
      entry "Optimal Bit Timing" $bitTiming 1 [shiftPosByOffset 1]
      set hardware [uint16 "Hardware Compatibility"]
      set ram [uint16 "Required RAM"]
      set largestTrack [uint16 "Largest Track"]
    }
    if {$version >= 3} {
      set fluxBlock [uint16 "FLUX Block"]
      set largestFluxTrack [uint16 "Largest Flux Track"]
    }
    set pad [expr 80 - [pos]]
    hex $pad "Padding"
  }
}

proc ChunkTRKS {woz} {
  section -collapsed "TRKS" {
    set chunkSize [uint32 "Size"]
    if {$woz == "WOZ1"} {
      set prevIndex -1
      for {set i 0} {$i < 160} {incr i} {
        goto [expr 88 + $i]
        set trackIndex [uint8]
        if {$trackIndex < 255 && $trackIndex != $prevIndex} {
          set start [expr 256 + 6656 * $trackIndex]
          goto $start
          set start [format %05X $start]
          set ihex [format %02X $trackIndex]
          section -collapsed "TRK $$ihex" {
            sectionvalue "0x$start"
            hex [expr 6646] "Data"
            set byteCount [uint16 "Bytes Used"]
            set bitCount [uint16 "Bit Count"]
            set splice [uint16 "Splice Point"]
            set nibble [uint8 "Splice Nibble"]
            set splicebit [uint8 "Splice Bit Count"]
          }
        }
        set prevIndex $trackIndex
      }
    } else {
      for {set i 0} {$i < 160} {incr i} {
        goto [expr 256 + 8 * $i]
        set startBlock [uint16]
        if {$startBlock > 0} {
          set ihex [format %02X $i]
          section -collapsed "TRK $$ihex" {
            entry "Start Block" $startBlock 2 [shiftPosByOffset 2]
            set blockCount [uint16 "Block Count"]
            set bitCount [uint32 "Bit Count"]
            set start [expr 512 * $startBlock]
            goto $start
            hex [expr 512 * $blockCount] "Data"
            set start [format %05X $start]
            sectionvalue "0x$start"
          }
        }
      }
    }
  }
  goto [expr 256 + $chunkSize]
}

proc ChunkWRIT {} {
  section -collapsed "WRIT" {
    set chunkSize [uint32 "Size"]
    set maxPos [expr [pos] + $chunkSize]
    while {[pos] < $maxPos} {
      section -collapsed "WTRK" {
        set trackNum [uint8 "Track Number"]
        sectionvalue "Track $trackNum"
        set commandCount [uint8 "Command Count"]
        set writeFunc [uint8 "Write Function"]
        set reserved [uint8 "Reserved"]
        set checksum [uint32 -hex "Bits Checksum"]
        for {set i 0} {$i < $commandCount} {incr i} {
          section -collapsed "WCMD" {
            set startBit [uint32 "Start Bit"]
            set bitCount [uint32 "Bit Count"]
            set ln [uint8 "Leader Nibble"]
            set lnbc [uint8 "Leader Nibble Bit Count"]
            set lcount [uint8 "Leader Count"]
            set reserved [uint8 "Reserved"]
          }
        }
      }
    }
  }
  goto $maxPos
}

# META records have the form:
#  key1\tvalue1\n\key2\t\value2\n...
proc ChunkMETA {} {
  section "META" {
    set chunkSize [uint32 "Size"]
    set curPos [pos]
    set offset [pos]
    set metadata [str $chunkSize "utf8"]
    set records [split $metadata "\n"]
    foreach rec $records {
      lassign [split $rec "\t"] key value
      set reclen [string length $rec]
      # Highlight each key/value using correct length & offset
      if {$reclen > 0} {
        entry $key $value $reclen $offset
      }
      set offset [expr $offset + $reclen + 1]
    }
  }
  goto [expr $curPos + $chunkSize]
}

while {![end]} {
  set chunkID [ascii 4]
  if {$chunkID == "INFO"} {
    ChunkINFO
  } elseif {$chunkID == "TRKS"} {
    ChunkTRKS $woz
  } elseif {$chunkID == "WRIT"} {
    ChunkWRIT
  } elseif {$chunkID == "META"} {
    ChunkMETA
  } else {
    set chunkSize [uint32]
    if {$chunkSize > 0 } {
      section $chunkID {
        entry "Size" $chunkSize 4 [shiftPosByOffset 4]
        hex $chunkSize "Data"
      }
    }
  }
}
