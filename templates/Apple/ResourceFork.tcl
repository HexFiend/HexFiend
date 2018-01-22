# WORK IN PROGRESS!

big_endian

section "Header" {
    set header_data_offset [uint32 "Data Offset"]
    set map_offset [uint32 "Map Offset"]
    uint32 "Data Length"
    uint32 "Map Length"
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
    uint16 "Attributes"
    uint16 "Type List Offset"
    uint16 "Name List Offset"
    set num_types [uint16 "Num Types - 1"]
    set types [list]
    section "Type List" {
        for {set i 0} {$i < [expr {$num_types + 1}]} {incr i} {
            section [expr $i + 1] {
                set type [ascii 4 "Type"]
                set num_resources [uint16 "Num Resources - 1"]
                uint16 "Type List Offset"
                for {set j 0} {$j < [expr {$num_resources + 1}]} {incr j} {
                    lappend types $type
                }
            }
        }
    }
    section "Reference Lists" {
        set i 1
        foreach type $types {
            section $i {
                uint16 "Resource ID"
                uint16 "Name List Offset"
                uint8 "Attributes"
                set data_offset [uint24 "Data Offset"]
                section "Data" {
                    set save_pos [pos]
                    goto [expr {$header_data_offset + $data_offset}]
                    set data_len [uint32 "Data Length"]
                    hex $data_len "Data"
                    goto $save_pos
                }
                uint32 "Handle"
            }
            incr i
        }
    }
}
