# based off
# http://www.delorie.com/djgpp/doc/exe/

little_endian

# The classic MS-DOS .EXE header
section "Header" {
    ascii 2 "Signature"
    set bytes_in_last_page [uint16 "Bytes in last page"]
    set pages [uint16 "Pages"]
    set relocs [uint16 "Relocations"]
    set paragraphs [uint16 "Header paragraphs"]
    uint16 "Min extra paragraphs"
    uint16 "Max extra paragraphs"
    uint16 -hex "SS (relative)"
    uint16 -hex "SP"
    uint16 -hex "Checksum"
    uint16 -hex "IP"
    uint16 -hex "CS (relative)"
    set reloc_offset [uint16 -hex "Relocation table offset"]
    uint16 "Overlay"
}

if {$relocs > 0} {
    section "Relocations" {
        goto $reloc_offset
        for {set i 0} {$i < $relocs} {incr i} {
            uint16 -hex "Reloc $i offset"
            uint16 -hex "Reloc $i segment"
        }
    }
}

section "Data" {
    set data_start [expr $paragraphs * 16]
    goto $data_start
    bytes eof "Data"
}
