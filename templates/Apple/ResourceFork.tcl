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
    set num_types [uint16 "Num Types (Minus 1)"]
    section "Type List" {
        for {set i 0} {$i < [expr {$num_types+1}]} {incr i} {
            ascii 4 "Type"
            uint16 "Num Resources (Minus 1)"
            uint16 "Type List Offset"
        }
    }
}
