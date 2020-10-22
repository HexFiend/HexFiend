# PCAP File Format template
# Stig Bjorlykke <stig@bjorlykke.org>

section "Header" {
    set magic [hex 4 "Magic Number"]

    if { $magic == 0xA1B2C3D4 | $magic == 0xA1B23C4D } {
        big_endian
    }

    uint16 "Version Major"
    uint16 "Version Minor"
    uint32 "This Zone"
    uint32 "Sigfigs"
    uint32 "Snapshot Length"
    uint32 "Link Type"
}

for { set i 1 } { ![end] } { incr i } {
    section "Packet $i" {
        uint32 "Timestamp sec"
        uint32 "Timestamp usec"
        set length [uint32 "Included Length"]
        uint32 "Origin Length"
        bytes $length "Data"
    }
}
