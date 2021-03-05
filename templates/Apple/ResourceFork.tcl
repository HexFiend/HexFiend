# WORK IN PROGRESS!

big_endian

section "File Format" {
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
        uint16 "Attributes"
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
                        uint16 "Name List Offset"
                        uint8 "Attributes"
                        set data_offset [uint24 "Data Offset"]
                        section "Data" {
                            set save_pos [pos]
                            goto [expr {$header_data_offset + $data_offset}]
                            set data_len [uint32 "Data Length"]
                            if {$data_len > 0} {
                                hex $data_len "Data" ;# TODO: region
                            }
                            goto $save_pos
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
                    ascii $num_name_bytes "Name"
                }
            }
        }
    }
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
