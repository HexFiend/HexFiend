big_endian
requires 0 "78617221" ;# xar!
ascii 4 "Signature"
uint16 "Header Size"
uint16 "Version"
set compressed_length [uint64 "TOC Compressed Length"]
uint64 "TOC Uncompressed Length"
uint32 "Checksum"
bytes $compressed_length "TOC Compressed"
