# Graphical Interchange Format
# https://www.w3.org/Graphics/GIF/spec-gif89a.txt

proc sub_blocks_and_terminator {} {
    while {[set n [uint8]] > 0} {
        section "Data Sub-block" {
            entry "Size" $n 1 [expr [pos]-1]
            bytes $n "Data"
        }
    }
    move -1
    bytes 1 "Block Terminator"
}

proc color_table {n} {
    for {set i 0} {$i < $n} {incr i} {
        uint8 "Red $i"
        uint8 "Green $i"
        uint8 "Blue $i"
    }
}

requires 0 "47 49 46" ;# "GIF"
section "Header" {
    ascii 3 "Signature"
    ascii 3 "Version"
}
section "Logical Screen Descriptor" {
    uint16 "Logical Screen Width"
    uint16 "Logical Screen Height"
    set flags [uint8]
    set gct_flag [expr $flags >> 7 & 1]
    entry "Global Color Table Flag" $gct_flag 1 [expr [pos]-1]
    entry "Color Resolution" [expr ($flags >> 4 & 7) + 1] 1 [expr [pos]-1]
    entry "Sort Flag" [expr $flags >> 3 & 1] 1 [expr [pos]-1]
    if {$gct_flag} {
        set n_gct [expr 2 ** (($flags & 7) + 1)]
        entry "Global Color Table Size" $n_gct 1 [expr [pos]-1]
    }
    uint8 "Background Color Index"
    uint8 "Pixel Aspect Ratio"
}
if {$gct_flag} {
    section "Global Color Table" {
        color_table $n_gct
    }
}
while {![end]} {
    set block_type [uint8]
    move -1
    if {$block_type == 0x2c} {
        section "Image Descriptor"
            bytes 1 "Label"
            uint16 "Left Position"
            uint16 "Top Position"
            uint16 "Width"
            uint16 "Height"
            set flags [uint8]
            set lct_flag [expr $flags >> 7 & 1]
            entry "Local Color Table Flag" $lct_flag 1 [expr [pos]-1]
            entry "Interlace Flag" [expr $flags >> 6 & 1] 1 [expr [pos]-1]
            entry "Sort Flag" [expr $flags >> 5 & 1] 1 [expr [pos]-1]
            if {$lct_flag} {
                set n_lct [expr 2 ** (($flags & 7) +1)]
                entry "Local Color Table Size" $n_lct 1 [expr [pos]-1]
                endsection
                section "Local Color Table"
                color_table $n_lct
            }
        endsection
        section "Image Data"
            uint8 "LZW Minimum Code Size"
            sub_blocks_and_terminator
        endsection
    } elseif {$block_type == 0x3b} {
        section "Trailer"
            bytes 1 "Label"
        endsection
    } elseif {$block_type == 0x21} {
        # Extension block
        move 1
        set ext_type [uint8]
        move -2
        if {$ext_type == 0x01} {
            section "Plain Text Extension"
                bytes 2 "Label"
                uint8 "Size" ;# should always be 12
                uint16 "Left Position"
                uint16 "Top Position"
                uint16 "Width"
                uint16 "Height"
                uint8 "Character Cell Width"
                uint8 "Character Cell Height"
                uint8 "Foreground Color Index"
                uint8 "Background Color Index"
            endsection
            section "Plain Text Data"
                sub_blocks_and_terminator
            endsection
        } elseif {$ext_type == 0xf9} {
            section "Graphic Control Extension"
                bytes 2 "Label"
                uint8 "Size" ;# should always be 4
                set flags [uint8]
                entry "Disposal Method" [expr $flags >> 2 & 7] 1 [expr [pos]-1]
                entry "User Input Flag" [expr $flags >> 1 & 1] 1 [expr [pos]-1]
                entry "Transparent Color Flag" [expr $flags & 1] 1 [expr [pos]-1]
                uint16 "Delay Time"
                uint8 "Transparent Color Index"
                bytes 1 "Block Terminator"
            endsection
        } elseif {$ext_type == 0xfe} {
            section "Comment Extension"
                bytes 2 "Label"
                sub_blocks_and_terminator
            endsection
        } elseif {$ext_type == 0xff} {
            section "Application Extension"
                bytes 2 "Label"
                uint8 "Size" ;# should always be 11
                ascii 8 "Application Identifier"
                bytes 3 "Application Authentication Code"
                sub_blocks_and_terminator
            endsection
        } else {
            section "Unknown extension block"
                bytes 2 "Label"
                set n [uint8 "Size"]
                bytes $n "Data"
            endsection
        }
    } else {
        section "Invalid block"
            bytes 1 "Label"
        endsection
    }
}
