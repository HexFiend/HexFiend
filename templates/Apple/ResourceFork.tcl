# WORK IN PROGRESS!

big_endian

section "Header" {
    uint32 "Data Offset"
    set map_offset [uint32 "Map Offset"]
    uint32 "Data Length"
    uint32 "Map Length"
}

move [expr {$map_offset - 16}]
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
    set total_num_resources 0
    section "Type List" {
        for {set i 0} {$i < [expr {$num_types + 1}]} {incr i} {
            section [expr $i + 1] {
                ascii 4 "Type"
                set num_resources [uint16 "Num Resources - 1"]
                uint16 "Type List Offset"
                incr total_num_resources [expr {$num_resources + 1}]
            }
        }
    }
    section "Reference Lists" {
        for {set i 0} {$i < $total_num_resources} {incr i} {
            section [expr $i + 1] {
                uint16 "Resource ID"
                uint16 "Name List Offset"
                uint8 "Attributes"
                uint24 "Data Offset"
                uint32 "Handle"
            }
        }
    }
}
