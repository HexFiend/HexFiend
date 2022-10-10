# Quick and Dirty ZIP Format by Lemnet
# Expanded by fosterbrereton
# https://en.wikipedia.org/wiki/Zip_(file_format)

little_endian
requires 0 "50 4B 03 04"

proc host {} {
    set host [uint8]

    if {$host == 0} {
        set description "ms-dos or compatible"
    } elseif {$host == 3} {
        set description "unix"
    } else {
        set description "unknown"
    }

    entry "Host" "$description ($host)" 1 [expr [pos] - 1]
    return $description
}

proc version {name} {
    section "$name" {
        set version [uint8]
        set major [expr $version / 10]
        set minor [expr $version % 10]
        entry "Version" "$major.$minor" 1 [expr [pos] - 1]
        set host [host]
        sectionvalue "$major.$minor, $host"
    }
}

proc gp_bit_flags {} {
    section "Flags" {
        set flgs [uint16 -hex]
        if {($flgs & (1 << 0)) != 0} { entry "Encrypted" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 1)) != 0} { entry "Compression Option 1" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 2)) != 0} { entry "Compression Option 2" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 3)) != 0} { entry "Has Data Descriptor" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 4)) != 0} { entry "Enhanced Deflate" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 5)) != 0} { entry "Patch Data" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 6)) != 0} { entry "Strong Encryption" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 7)) != 0} { entry "Unused" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 8)) != 0} { entry "Unused" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 9)) != 0} { entry "Unused" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 10)) != 0} { entry "Unused" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 11)) != 0} { entry "Utf8" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 12)) != 0} { entry "Reserved" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 13)) != 0} { entry "Encrypted Central Directory" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 14)) != 0} { entry "Reserved" "" 2 [expr [pos] - 2] }
        if {($flgs & (1 << 15)) != 0} { entry "Reserved" "" 2 [expr [pos] - 2] }
        sectionvalue $flgs
    }

    return $flgs
}

proc extra_fields {sz} {
    section "Extra Fields" {
        set end [expr [pos] + $sz]
        set count 0
        while {[expr [pos]] < $end} {
            section "\[$count\]" {
                set id [uint16 -hex "Identifier"]
                set exl [uint16 "Extra field length"]
                set inner_end [expr [pos] + $exl]
                if {$id == 0x5455} {
                    set flags [uint8 "Flags"]
                    if {($flags & (1 << 0)) != 0} {
                        if {[expr [pos] + 4] <= $inner_end } {
                            unixtime32 "Mod time"
                        }
                    } else {
                        entry "" "Warning: flag bitset is incorrect"
                    }
                    if {($flags & (1 << 1)) != 0} {
                        if {[expr [pos] + 4] <= $inner_end } {
                            unixtime32 "Access time"
                        } else {
                            entry "" "Warning: flag bitset is incorrect"
                        }
                    }
                    if {($flags & (1 << 2)) != 0} {
                        if {[expr [pos] + 4] <= $inner_end } {
                            unixtime32 "Create time"
                        } else {
                            entry "" "Warning: flag bitset is incorrect"
                        }
                    }
                } else {
                    if {[expr [pos] + $exl] <= $inner_end} {
                        hex $exl "Raw bytes"
                    } else {
                        entry "" "Warning: flag bitset is incorrect"
                    }
                }
            }
            set count [expr $count + 1]
        }
        sectionvalue "$count entries"
    }
}

proc compression_method {} {
    set compression [uint16 -hex]

    if {$compression == 8} {
        set description "deflate"
    } elseif {$compression == 0} {
        set description "uncompressed"
    } else {
        set description "unknown"
    }

    entry "Compression method" "$description ($compression)" 2 [expr [pos] - 2]
}

while {![end]} {
    set sig [uint32]
    move -4
    if {$sig == 67324752} {
        section "Local file header" {
            uint32 -hex "Signature"
            version "Version needed to extract"
            set flgs [gp_bit_flags]
            compression_method
            fattime "File last modification time"
            fatdate "File last modification date"
            if {($flgs & (1 << 3)) == 0} {
                uint32 -hex "CRC-32"
                set cs [uint32 "Compressed size"]
            } else {
                entry "CRC-32" "unknow"
                entry "Compressed size" "unknow"
                move 5
                set mv 0
                while {![end]} {
                    set sig [uint32]
                    incr mv
                    if {$sig == 134695760} {
                        move 4
                        set cs [uint32]
                        incr mv 8
                        break
                    }
                    move -3
                }
                move -$mv
            }
            uint32 "Uncompressed size"
            set fnl [uint16 "File name length"]         
            set exl [uint16 "Extra field length"]
            if {$fnl > 0} {
                set file_name [ascii $fnl "File name"]
            }
            if {$exl > 0} {
                extra_fields $exl
            }
            if {$cs > 0} {	
	            bytes $cs "File data"
	        }
            if {($flgs & (1 << 3)) != 0} {
                section "Data descriptor" {
                    set sig [uint32 -hex "Signature or CRC"]                    
                    if {$sig == 134695760} {
                        uint32 -hex "CRC-32"
                    }
                    uint32 "Compressed size"
                    uint32 "Uncompressed size"
                }
            }
            sectionvalue "(header for \"$file_name\")"
        }
    } elseif {$sig == 33639248} {
        section "Central directory record" {
            uint32 -hex "Signature"
            version "Version made by"
            version "Version needed to extract"
            gp_bit_flags
            compression_method
            fattime "File last modification time"
            fatdate "File last modification date"
            uint32 -hex "CRC-32"
            uint32 "Compressed size"
            uint32 "Uncompressed size"
            set fnl [uint16 "File name length"]
            set exl [uint16 "Extra field length"]
            set fcl [uint16 "File comment length"]
            uint16 "Disk number where file starts"
            uint16 -hex "Internal file attributes"
            uint32 -hex "External file attributes"
            uint32 "Relative offset of local file header"
            if {$fnl > 0} {
                set file_name [ascii $fnl "File name"]
            }
            if {$exl > 0} {
                extra_fields $exl
            }
            if {$fcl > 0} {
                hex $fcl "File comment"
            }
            sectionvalue "(cdr for \"$file_name\")"
        }
    } elseif {$sig == 101010256} {
        section "End of central directory record" {
            uint32 -hex "Signature"
            uint16 "Number of this disk"
            uint16 "Disk where central directory starts"
            uint16 "Number of central directory records on this disk"
            uint16 "Total number of central directory records"
            uint32 "Size of central directory"
            uint32 "Offset of start of central directory"
            set cl [uint16  "Comment length"]            
            if {$cl > 0} {
                ascii $cl "Comment"
            }
            sectionvalue ""
        }
    } else {
        entry "error" "sig not recognised"
        break
    }
}
