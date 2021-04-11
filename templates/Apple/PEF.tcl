# https://web.archive.org/web/20020111212254/http://developer.apple.com/techpubs/mac/runtimehtml/RTArch-95.html#MARKER-9-56

big_endian

# Report something invalid (but otherwise recoverable).
proc invalid {field message len {pos -1}} {
    entry $field $message $len [expr {$pos < 0 ? [pos] : $pos}]
}

# Read a sequence of bytes that must match (but do not invalidate the
# choice of this template for the file/region of bytes).
proc invalid_if_not {args} {
    set pos [pos]
    set n_bytes [llength $args]
    set validity "valid"
    for {set i 0} {$i < $n_bytes} {incr i} {
        if {[uint8] != [lindex $args $i]} {
            set validity "invalid"
        }
    }
    if {$validity != "valid"} {
        entry "Reserved bytes" "$validity" $n_bytes $pos
    }
}

# Read a name given a base, offset, reading function, and the arguments to pass
# to the reading function.
proc detour_to_name {base offset fn args} {
    set t [pos]
    set u [expr {$base + $offset}]
    goto $u
    if {[catch { $fn {*}$args } result]} {
        set result "(error reading name at [format "0x%x" $u])"
    }
    goto $t
    return $result
}

# There's a lot of stuff here.  Avoid polluting the global namespace with things
# that are very specific to PEF.
namespace eval PEF {
    # Decode which kind of section this is.
    variable section_kinds [list \
                                "Code" \
                                "Data" \
                                "Data, patterned" \
                                "Constant" \
                                "Loader" \
                                "reserved (debug)" \
                                "Executable, R/W" \
                                "reserved (exception)" \
                                "reserved (traceback)"]
    proc decode_kind8 {} {
        variable section_kinds
        set offset [pos]
        set kind [uint8]
        if {$kind >= [llength $section_kinds]} {
            set kind_description "(invalid)"
        } else {
            set kind_description [lindex $section_kinds $kind]
        }
        entry "Kind" $kind_description 1 $offset
        return [list $kind_description $kind]
    }

    proc decode_share8 {} {
        set offset [pos]
        set share [uint8]
        switch -exact $share {
            1 { set share "Process Only"; }
            4 { set share "Global"; }
            5 {
                # Global, but writable only when CPU is in privileged mode.
                set share "Global, protected"
            }
            default { invalid "Share" "invalid value: $share" 1 $offset; }
        }
        entry "Share?" $share 1 $offset
        return $share
    }

    proc decode_alignment8 {} {
        set offset [pos]
        set value [uint8]
        if {$value <= 32} {
            entry "Alignment" "[expr {1 << $value}] bytes" 1 $offset;
        } else {
            entry "Alignment" ">4GiB" 1 $offset;
        }
        return $value
    }

    # Patterned data decoders
    proc decode_patterned_data_argument {} {
        # Argument values are stored in big-endian fashion, with the most
        # significant bits first. Each byte holds 7 bits of the argument value. The
        # high-order bit is set for every byte except the last (that is, an unset
        # high-order bit indicates the last byte in the argument).
        set start [pos]
        set x 0
        for {set n [uint8]} {$n & 0x80} {set n [uint8]} {
            set x [expr {($x << 7) | ($n & 0x7F) }]
        }
        return [list [expr {($x << 7) | ($n & 0x7F) }] [expr {[pos] - $start}] $start]
    }

    proc decode_first_argument {count} {
        # If you need to specify a count value larger than 31, you should place 0 in
        # the count field. This indicates that the first argument following the
        # instruction byte is the count value.
        if {$count > 0} {
            return $count
        }
        lassign [decode_patterned_data_argument] value length position
        return $value
    }

    proc decode_patterned_data_instruction {} {
        section "Instruction"
        set n_errors 0
        set offset [pos]
        set opcode [uint8]
        set first_argument [decode_first_argument [expr {$opcode & 0x1F}]]
        set opcode [expr {($opcode >> 5) & 7}]
        switch -exact $opcode {
            0 {
                sectionvalue "Repeated Zeros"
                entry "Opcode" $opcode 1 $offset
                entry "Count" $first_argument 1 $offset
            }

            1 {
                sectionvalue "Block Copy"
                set block_size $first_argument
                entry "Opcode" $opcode 1 $offset
                entry "Size" $block_size 1 $offset
                bytes $block_size "Block"
            }

            2 {
                sectionvalue "Repeat Block"
                set block_size $first_argument
                entry "Opcode" $opcode 1 $offset
                entry "Size" $block_size 1 $offset
                lassign [decode_patterned_data_argument] repeat_count arg_bytes offset
                entry "Count" [incr repeat_count] $arg_bytes $offset
                bytes $block_size "Block"
            }

            3 {
                # NOTE: When run, this "instruction" places "Common Data" before,
                # after, and between each "Custom Data" block. i.e.: A,X,A,Y,A,Z,...A
                sectionvalue "Interleave with Data Blocks"
                set common_size $first_argument
                entry "Opcode" $opcode 1 $offset
                entry "Common Size" $common_size 1 $offset

                lassign [decode_patterned_data_argument] custom_size arg_bytes offset
                entry "Custom Size" $custom_size $arg_bytes $offset

                lassign [decode_patterned_data_argument] repeat_count arg_bytes offset
                entry "Repeat Count" $repeat_count $arg_bytes $offset

                bytes $common_size "Common Data"

                section "Data Blocks" {
                    sectionvalue $repeat_count
                    for {set i 0} {$i < $repeat_count} {incr i} {
                        bytes $custom_size "Custom Data $i"
                    }
                }
            }

            4 {
                sectionvalue "Interleave zeros with Data Blocks (0b100)"
                entry "Opcode" $opcode 1 $offset
                entry "Zeros Count" $first_argument 1 $offset

                lassign [decode_patterned_data_argument] custom_size arg_bytes offset
                entry "Custom Size" $custom_size $arg_bytes $offset

                lassign [decode_patterned_data_argument] repeat_count arg_bytes offset
                entry "Repeat Count" $repeat_count $arg_bytes $offset

                section "Data Blocks" {
                    sectionvalue $repeat_count
                    for {set i 0} {$i < $repeat_count} {incr i} {
                        bytes $custom_size "Custom Data $i"
                    }
                }
            }

            default {
                incr n_errors
            }
        }

        endsection
        return $n_errors
    }

    # Import decoders
    proc decode_import_options8 {} {
        set offset [pos]
        set options [uint8]
        set values [list]
        if {$options & 0x40} {
            lappend values "weak"
        }
        if {$options & 0x80} {
            lappend values "import-before"
        }
        if {[llength $values] < 1} {
            lappend values "(none)"
        }
        entry "Options" [join $values ", "] 1 $offset
    }

    variable symbol_classes [list "Code" "Data" "Function Pointer" "Index (TOC)" \
                                 "Linker glue"]
    proc decode_symbol_class8 {} {
        variable symbol_classes
        set linkage ""
        set class [uint8]
        if {$class & 0x80} {
            set class [expr {$class & 0x7F}]
            set linkage ", weak"
        }
        if {$class >= [llength $symbol_classes]} {
            return "(invalid)"
        }
        return "[lindex $symbol_classes $class]$linkage"
    }

    # Read info about the locations of main(), runtime-init, or tear-down code
    # locations.
    proc section_number_and_offset {name} {
        section $name
        set offset [pos]
        set n [int32]
        if {$n > -1} {
            entry "Section #" $n 4 $offset
            set offset [uint32 -hex "Offset"]
            endsection
            return [list $n $offset]
        }

        invalid_if_not 0 0 0 0
        sectionvalue "(none)"
        endsection
        return [list]
    }

    proc decode_loader_section {} {
        set loader_base [pos]
        section "Loader Header" {
            section_number_and_offset "main()"
            section_number_and_offset ".init"
            section_number_and_offset ".atexit"
            set n_libraries               [uint32 "Imported Library Count"]
            set n_symbols                 [uint32 "Imported Symbol Count"]
            set n_relocs                  [uint32 "Reloc Section Count"]
            set reloc_instructions_offset [uint32 -hex "Reloc Instr Offset"]
            set loader_strings_offset     [uint32 -hex "Loader Strings Offset"]

            set names_base [expr {$loader_base + $loader_strings_offset}]
            set relocs_base [expr {$loader_base + $reloc_instructions_offset}]

            section "Exports Hash Table" {
                set hash_offset [uint32 -hex "Offset"]
                set exports_hash_table \
                    [dict create \
                         pos          [expr {$loader_base + $hash_offset}] \
                         log2chains   [uint32 "Log2(Size)"] \
                         symbol_count [uint32 "Count"]]
            }
        }

        section "Imports" {
            section "Libraries" {
                sectionvalue $n_libraries
                for {set i 0} {$i < $n_libraries} {incr i} {
                    section "Library \[$i\]:" {
                        set offset [uint32 -hex "Name Offset"]
                        sectionvalue [detour_to_name $names_base $offset cstr macRoman]
                        uint32 "Old Imp Version"
                        uint32 "Current Version"
                        uint32 "Imported Symbol Count"
                        uint32 "First Symbol Imported"
                        decode_import_options8
                        invalid_if_not 0 0 0
                    }
                }
            }

            section "Symbols" {
                sectionvalue $n_symbols
                for {set i 0} {$i < $n_symbols} {incr i} {
                    set offset      [pos]
                    set class       [decode_symbol_class8]
                    set name_offset [uint24]
                    entry [detour_to_name $names_base $name_offset cstr macRoman] $class 4 $offset
                }
            }
        }

        section "Relocations" {
            section "Headers" {
                sectionvalue $n_relocs
                for {set i 0} {$i < $n_relocs} {incr i} {
                    section "Header \[$i\]" {
                        uint16 "Section #"
                        invalid_if_not 0 0
                        uint32 "Reloc Count"            ;# number of 16-bit relocation blocks for this section
                        uint32 -hex "First Reloc Offset"        ;# byte offset from the start of the relocations area to the first relocation instruction for this section
                    }
                }
            }

            goto $relocs_base
            set n_instruction_bytes [expr {$names_base - $relocs_base}]
            if {$n_relocs > 0 && $n_instruction_bytes > 0} {
                bytes $n_instruction_bytes "Instructions"
                # //TODO// decode instructions?
                
            }
        }

        goto $names_base
        set n_string_bytes [expr {[dict get $exports_hash_table pos] - $names_base}]
        if {$n_string_bytes > 0} {
            bytes $n_string_bytes "Strings"
            # Note: contains alignment padding.
        } else {
            section "Strings" {}
        }

        goto [dict get $exports_hash_table pos]
        section "Exports" {
            section "Hash Table Chains" {
                set n_chains [dict get $exports_hash_table log2chains]
                if {$n_chains < 24} {
                    set n_chains [expr {1 << $n_chains}]
                    sectionvalue $n_chains
                } else {
                    sectionvalue "(invalid)"
                }
                #-for {set i 0} {$i < $n_chains} {incr i} {
                #-    uint32  ;# Leading 14 bits: size of chain; Trailing 18 bits: index of first chain element in the key/value table
                #-}
                
                if {$n_chains > 0} {
                    bytes [expr {4*$n_chains}] "Chains"
                }
            }

            section "Hash Key Table" {
                set n_symbols [dict get $exports_hash_table symbol_count]
                sectionvalue $n_symbols
                set symbol_name_lengths [list]
                for {set i 0} {$i < $n_symbols} {incr i} {
                    #-section "Key" {  ;# Doesn't seem useful to put all of this in the template without a `section -collapsed ...`  option.
                    lappend symbol_name_lengths [uint16]
                    uint16 ;# "Hash of name"
                    #-}
                }
            }

            section "Symbols" {
                set n_symbols [dict get $exports_hash_table symbol_count]
                sectionvalue $n_symbols
                for {set i 0} {$i < $n_symbols} {incr i} {
                    section "Symbol \[$i\]" {
                        set offset      [pos]
                        set class       [decode_symbol_class8]
                        entry "Class" $class 1 $offset
                        set name_offset [uint24 "Name Offset"]
                        sectionvalue [detour_to_name $names_base $name_offset \
                                          str [lindex $symbol_name_lengths $i] macRoman]
                        uint32 "Value"
                        int16 "Section #"
                    }
                }
            }
        }
    }
}

section "PEF Container" {
    set pef_base [pos]

    section "Header" {
        requires $pef_base "4A 6F 79 21    70 65 66 66" ;# 'Joy!' 'peff'
        ascii 4 tag1    ;# 'Joy!'
        ascii 4 tag2    ;# 'peff'
        set cpu_isa [ascii 4 "CPU ISA"]
        if {$cpu_isa ni {pwpc m68k}} {
            requires $pef_base 0
        }
        uint32 "PEF version"
        macdate "Created at"

        section "Compatibility" {
            uint32 oldDefVersion
            uint32 oldImpVersion
            uint32 curVersion
        }

        set n_sections [uint16 "Section Count"]
        uint16 "Instantiated Section Count"
        invalid_if_not 0 0 0 0
    }

    section "Section Headers" {
        set sections [list]
        for {set j 1} {$j <= $n_sections} {incr j} {
            section "Section \[$j\]" {
                set pef_section [dict create n $j]
                dict set pef_section name_offset [int32 "Name Offset"]
                uint32 "Address, preferred"
                uint32 "Size, loaded"
                uint32 "Size, unpacked"
                dict set pef_section size   [uint32 "Size, packed"]
                dict set pef_section offset [uint32 -hex "Offset in container"]
                lassign [PEF::decode_kind8] kind_description kind
                dict set pef_section kind_description $kind_description
                dict set pef_section kind $kind
                PEF::decode_share8
                PEF::decode_alignment8
                invalid_if_not 0
                lappend sections $pef_section
            }
        }
    }

    set first_name [pos]
    section "Section Names" {
        foreach pef_section $sections {
            dict with pef_section {
                if {$name_offset > -1} {
                    goto [expr {$first_name + $name_offset}]
                    dict set pef_section name [cstr macRoman "Name"]
                }
            }
        }
    }

    section "Section Contents" {
        sectionvalue "[llength $sections] sections"

        foreach pef_section $sections {
            dict with pef_section {  ;# => name_offset size offset kind* name(optional)
                goto $offset
                set end_of_section [expr {$offset + $size}]
                set sectionvalue "$size bytes"

                section "$n, $kind_description" {
                    if {$kind == 4} {
                        PEF::decode_loader_section
                        if {[pos] < $end_of_section} {
                            bytes [expr {$end_of_section - [pos]}] "Padding"
                        }
                    } elseif {$kind == 2} {
                        set k 0
                        set n_errors 0
                        while {[pos] < $end_of_section && $n_errors == 0} {
                            incr n_errors [PEF::decode_patterned_data_instruction]
                            incr k
                        }
                        if {$n_errors > 0} {
                            entry "ERROR" "Error while reading patterned data instruction $k in section $n."
                        }
                        if {[pos] < $end_of_section} {
                            bytes [expr {$end_of_section - [pos]}] "Padding"
                        }
                        set sectionvalue "\[$k\] instrs ($size bytes)"
                    } else {
                        append sectionvalue ""
                        if {$size > 0} {
                            bytes $size "Bytes, raw"
                        } else {
                            entry "Zero-length section" "-"
                        }
                    }

                    if {[info exists name]} {
                        append sectionvalue ", \"$name\""
                    }
                    sectionvalue $sectionvalue
                }
                # Gaps may exist between sections to accommodate alignment needs.
            }
        }
    }
}
