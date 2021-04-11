# WORK IN PROGRESS!
proc link_to_section {label offset body} {
    set saved_pos [pos]
    goto $offset
    uplevel 1 [list section $label $body]
    goto $saved_pos
}

proc decode_fork_attrs {bits offset} {
    set attrs [list]
    if {$bits & 0x8000} {
        entry "read-only" "Yes, file is read-only" 2 $offset
        lappend attrs "locked"
    }
    if {$bits & 0x4000} {
        entry "compact" "Yes, compact resources on update" 2 $offset
        lappend attrs "compact"
    }
    if {$bits & 0x2000} {
        entry "changed" "Yes, th resource fork has been changed and needs writing to disk" 2 $offset
        lappend attrs "changed"
    }
    return [join $attrs ", "]
}

proc decode_rsrc_attrs {bits offset} {
    set attrs [list]
    if {$bits & 0x40} {
        entry "inSysHeap" "Load into System heap" 1 $offset
        lappend attrs "load in sys heap"
    }
    if {$bits & 0x20} {
        entry "purge" "Yes, can be purged when memory is low" 1 $offset
        lappend attrs "purgeable"
    }
    if {$bits & 0x10} {
        entry "lock" "Yes, is locked" 1 $offset
        lappend attrs "locked"
    }
    if {$bits & 0x08} {
        entry "protect" "Yes" 1 $offset
        lappend attrs "protect"
    }
    if {$bits & 0x04} {
        entry "preload" "Yes, preload" 1 $offset
        lappend attrs "preload"
    }
    if {$bits & 0x02} {
        entry "changed" "Yes, the resource has been changed and needs writing to disk" 1 $offset
        lappend attrs "changed"
    }
    return [join $attrs ", "]
}

big_endian

section "Resource Fork" {
    section "Header" {
        set header_data_offset [uint32 "Data Offset"]
        set map_offset [uint32 "Map Offset"]
        set data_length [uint32 "Data Length"]
        uint32 "Map Length"
    }

    goto $header_data_offset
    section "Resources" {
        while {[pos] < ($header_data_offset + $data_length)} {
            set resource_data_length [uint32 "Length"]
            if {$resource_data_length > 0} {
                hex $resource_data_length "Data"
            }
        }
    }

    goto $map_offset
    section "Map" {
        section "Header Copy" {
            uint32 "Data Offset"
            uint32 "Map Offset"
            uint32 "Data Length"
            uint32 "Map Length"
        }

        uint32 "Next Resource Map"
        uint16 "File Reference"
        section "Fork Attributes" {
            set fork_offset [pos]
            set fork_attrs  [uint16 -hex "Bits"] ;# The fork attributes in hex form.
            # Decode the attributes and show one per line here and save a
            # symbolic string for placing next to the top resource fork section.
            set fork_attr_str [decode_fork_attrs $fork_attrs $fork_offset]
            sectionvalue $fork_attrs
        }
        uint16 "Type List Offset"
        set name_list_offset [uint16 "Name List Offset"]
        set num_types [uint16 "Num Types - 1"]
        set types [list]
        section "Type List" {
            for {set i 0} {$i < [expr {$num_types + 1}]} {incr i} {
                section [expr $i + 1] {
                    set type [ascii 4 "Type"]
                    set num_resources [uint16 "Num Resources - 1"]
                    uint16 "Type List Offset"
                    lappend types [dict create "type" $type "count" [expr {$num_resources + 1}]]
                }
            }
        }

        section "Reference Lists" {
            set i 1
            foreach res $types {
                set count [dict get $res "count"]
                for {set j 0} {$j < $count} {incr j} {
                    section $i {
                        uint16 "Resource ID"
                        set name_offset [int16 "Name List Offset"]
                        section "Attributes" {
                            set attrs_offset  [pos]
                            set attrs [uint8 "Bits" -hex]
                            sectionvalue [decode_rsrc_attrs $attrs $attrs_offset]
                        }
                        set data_offset [uint24 "Data Offset"]

                        if {$name_offset > -1} {
                            set name_pos [expr {$map_offset + $name_list_offset + $name_offset}]

                            # Short digression to get the name.
                            link_to_section "Name" $name_pos {
                                set name_length [uint8 "Length"]
                                set name [str $name_length "macRoman" "Name"]
                            }
                        }

                        link_to_section "Data" [expr {$header_data_offset + $data_offset}] {
                            set data_len [uint32 "Data Length"]
                            if {$data_len > 0} {
                                hex $data_len "Data" ;# TODO: region
                            }
                        }
                        uint32 "Handle"
                    }
                }
                incr i
            }
        }

        goto [expr {$map_offset + $name_list_offset}]
        section "Name List" {
            for {set i 0} {![end]} {incr i} {
                section "Name $i" {
                    set num_name_bytes [uint8 "Length"]
                    str $num_name_bytes "macRoman" "Name"
                }
            }
        }
    }

    sectionvalue $fork_attr_str
}


proc compare_dict {a b} {
    set a0 [dict get $a "type"]
    set b0 [dict get $b "type"]
    return [string compare -nocase $a0 $b0]
}
set types [lsort -command compare_dict $types]

foreach res $types {
    set type [dict get $res "type"]
    set count [dict get $res "count"]
    section "$type - $count" {
    }
}
