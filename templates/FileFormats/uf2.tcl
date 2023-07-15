# based on UF2 specification:
# https://github.com/microsoft/uf2

while {![end]} {
    section "Block" {
        requires [pos] "55 46 32 0A 57 51 5D 9E"
        uint64 -hex "Start of Block"

        set flags [uint32 -hex "Flags"]

        if { ($flags & 0x00000001) != 0 } {
            entry "Not main flash" "yes"
        }
        if { ($flags & 0x00001000) != 0 } {
            entry "File container" "yes"
        }
        if { ($flags & 0x00002000) != 0 } {
            entry "FamilyID present" "yes"
        }
        if { ($flags & 0x00004000) != 0 } {
            entry "MD5 checksum present" "yes"
        }
        if { ($flags & 0x00008000) != 0 } {
            entry "Extension tag present" "yes"
        }

        uint32 -hex "Location"
        set length [uint32 "Length"]

        uint32 "Block ID"
        uint32 "Total Blocks"

        if { ($flags & 0x00001000) != 0 } {
            uint32 -hex "FileSize"
        } elseif { ($flags & 0x00002000) != 0 } {
            uint32 -hex "Family ID"
        } else {
            uint32 "Ignored"
        }

        bytes $length "Data"
        bytes [expr 476-$length] "Padding"

        requires [pos] "30 6F B1 0A"
        uint32 -hex "End of Block"
    }
}
