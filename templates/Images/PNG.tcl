big_endian
requires 0 "89 50 4E 47 0D 0A 1A 0A"
hex 8 "Signature"
while {![end]} {
    set chunk_len [uint32 "Chunk Length"]
    set chunk_type [ascii 4 "Chunk Type"]
    if {$chunk_type == "IHDR"} {
        uint32 "Width"
        uint32 "Height"
        uint8 "Bit Depth"
        uint8 "Color Type"
        uint8 "Compression Method"
        uint8 "Filter Method"
        uint8 "Interlace Method"
    } else {
        move $chunk_len
    }
    hex 4 "CRC"
}
