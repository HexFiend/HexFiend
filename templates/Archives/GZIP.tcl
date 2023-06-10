# GZIP file
# based off https://tools.ietf.org/html/rfc1952

requires 0 "1f 8b" ; # GZIP Header

uint16 -hex "Signature"
uint8 "Compression method"

set flags [hex 1]
section "Flags" {
    sectionvalue $flags

    entry "File is ASCII text" [expr $flags & 1] 1 [expr [pos]-1]

    set header_crc [expr $flags >> 1 & 1]
    entry "Header crc16 present" $header_crc 1 [expr [pos]-1]

    set extra_fields [expr $flags >> 2 & 1]
    entry "Extra fields present" $extra_fields 1 [expr [pos]-1]

    set filename [expr $flags >> 3 & 1]
    entry "Filename present" $filename 1 [expr [pos]-1]

    set comment [expr $flags >> 4 & 1]
    entry "Comment present" $comment 1 [expr [pos]-1]

    entry "Reserved" [expr $flags >> 5 & 7] 1 [expr [pos]-1]
}

set mtime [uint32]
if {$mtime == 0} {
    entry "Modification timestamp" "---" 4 [expr [pos]-4]
} else {
    move -4
    unixtime32 "Modification timestamp"
}

set extra_flags [hex 1 "Extra flags"]
uint8 "Operating system"

if {$extra_fields} {
    set xlen [uint16]
    section "Extra fields total length" {
        sectionvalue $xlen

        set subftotal 0
        while {$subftotal < $xlen} {
            section "Subfield" {
                hex 2 "Subfield ID"
                set subflen [uint16 "Length"]
                bytes $subflen "Subfield data"
            }
            set subftotal [expr $subftotal + 4 + $subflen]
        }
    }
}

if {$filename} {
    cstr isolatin1 "Filename"
}

if {$comment} {
    cstr isolatin1 "Comment"
}

if {$header_crc} {
    hex 2 "Header CRC16"
}

bytes [expr [len]-[pos]-8] "Compressed data"

hex 4 "CRC32"
uint32 "Uncompressed data size"
