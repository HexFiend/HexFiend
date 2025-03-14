big_endian
requires 0 "46 4F 52 4D" ;# FORM
requires 8 "41 49 46 43" ;# AIFC
ascii 4 "Header Chunk ID"
uint32 "Header Chunk Size"
ascii 4 "Header Chunk Type"
while {![end]} {
    set chunk_id [ascii 4 "Chunk ID"]
    set chunk_size [uint32 "Chunk Size"]
    if {$chunk_id == "COMM"} {
        section "COMM"
            uint16 "Num Channels"
            uint32 "Num Sample Frames"
            uint16 "Sample Size"
            hex 10 "Sample Rate"
            ascii 4 "Compression Type"
            set comp_name_len [uint8 "Compression Name Length"]
            ascii $comp_name_len "Compression Name"
        endsection
    } elseif {$chunk_id == "FVER"} {
        section "FVER"
            set timestamp [uint32 "Timestamp"]
            if {$timestamp == 2726318400} {
                entry "(Version)" "AIFCVersion1"
            }
        endsection
    } else {
        move $chunk_size
    }
}
