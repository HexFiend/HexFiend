requires 510 "55 AA"
hex 446 "Bootstrap Code"
for {set i 0} {$i < 4} {incr i} {
    section "Partition $i" {
        uint8 "Status"
        hex 3 "CHS Address First Sector"
        uint8 "Type"
        hex 3 "CHS Address Last Sector"
        uint32 "LBA"
        uint32 "Num Sectors"
    }
}
hex 2 "Signature"
