# Based on:
#   https://docs.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-image_file_header
#   https://docs.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-image_section_header
#   https://docs.microsoft.com/en-us/windows/win32/debug/pe-format#other-contents-of-the-file

section "Header" {
    uint16 -hex Machine
    set sections_count [uint16 NumberOfSections]
    uint32 TimeDateStamp
    set symbols_offset [uint32 -hex PointerToSymbolTable]
    set symbols_count [uint32 NumberOfSymbols]
    uint16 SizeOfOptionalHeader
    uint16 -hex Characteristics
}

section "Section Headers" {
    for {set i 1} {$i <= $sections_count} {incr i} {
        section "Section Header $i" {
            set section_name [ascii 8 NameOrStringTableOffset]
            uint32 VirtualSize
            uint32 -hex VirtualAddress
            set section_size [uint32 SizeOfRawData]
            set section_pointer [uint32 -hex PointerToRawData]
            uint32 -hex PointerToRelocations
            uint32 -hex PointerToLineNumbers
            uint16 NumberOfRelocations
            uint16 NumberOfLineNumbers
            uint32 -hex Characteristics
        }

        set sections_array($i) [dict create name $section_name pointer $section_pointer size $section_size]
    }
}

parray sections_array

section "Sections" {
    foreach key [array names sections_array] {
        set section_name [dict get $sections_array($key) name]
        set data_start [dict get $sections_array($key) pointer]
        set data_size [dict get $sections_array($key) size]
        if {$data_size > 0} {
            section "$section_name" {
                goto $data_start
                bytes $data_size "Data"
            }
        }
    }
}

goto $symbols_offset
section "Symbol Table" {
    for {set i 1} {$i <= $symbols_count} {incr i} {
        section "Symbol $i" {
            ascii 8 NameOrStringTableOffset
            uint32 -hex Value
            uint16 SectionNumber
            uint16 Type
            uint8 StorageClass
            uint8 NumberOfAuxSymbols
        }
    }
}

section "String Table" {
    uint32 Size
    bytes eof "Strings"
}
