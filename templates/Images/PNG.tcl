big_endian
requires 0 "89 50 4E 47 0D 0A 1A 0A"
bytes 8 "Signature"

proc ChunkIHDR {} {
    set width [uint32 "Width"]
    set height [uint32 "Height"]
    set bpp [uint8 "Bit Depth"]
    set color_mode [uint8 "Color Type"]
    uint8 "Compression Method"
    uint8 "Filter Method"
    uint8 "Interlace Method"

    switch $color_mode {
        0 { set color_mode_str "Grayscale" }
        2 { set color_mode_str "RGB" }
        3 { set color_mode_str "Indexed Color" }
        4 { set color_mode_str "Grayscale + Alpha" }
        6 { set color_mode_str "RGB + Alpha" }
        default { set color_mode_str "Invalid" }
    }

    sectionvalue "${width}x$height ${bpp}-bit $color_mode_str"
}

proc ChunkPLTEEntry {count} {
    section "\[ $count \]" {
        uint8 R
        uint8 G
        uint8 B
        sectionvalue ""
    }
}

proc ChunkPLTE {length} {
    set entry_count [expr $length / 3]
    section "Palette" {
        for {set i 0} {$i < $entry_count} {incr i} {
            ChunkPLTEEntry $i
        }
        sectionvalue "$entry_count entries"
    }
    return $entry_count
}

proc ChunkpHYs {} {
    set ppux [uint32 "Pixels Per Unit X"];
    set ppuy [uint32 "Pixels Per Unit Y"];
    set ratio [expr $ppux / $ppuy]
    set unit [uint8 "Unit"];
    if {$unit == 1} {
        # unit is the meter
        set dpi [expr $ppux * 0.0254];
        sectionvalue "Aspect Ratio $ratio; $dpi DPI"
    } else {
        # unit is unknown
        sectionvalue "Aspect Ratio $ratio"
    }
}

proc ChunkiTXt {length} {
    set start [pos]
    set keyword [cstr "utf8" "Keyword"]
    uint8 "Compression Flag"
    uint8 "Compression Method"
    cstr "utf8" "Language Tag"
    cstr "utf8" "Translated Keyword"
    set leftovers [expr $length - ([pos] - $start)]
    ascii $leftovers "Text";
    sectionvalue "\'$keyword\'"
}

while {![end]} {
	section "Chunk" {
		set length [uint32 "Length"]
		set type [ascii 4 "Type"]
		if {$type == "IHDR"} {
            ChunkIHDR
        } elseif {$type == "PLTE"} {
            set entry_count [ChunkPLTE $length]
            sectionvalue "$entry_count entries"
        } elseif {$type == "IDAT"} {
            bytes $length "Datastream Segment"
            sectionvalue "Image Data"
        } elseif {$type == "iTXt"} {
            ChunkiTXt $length
        } elseif {$type == "pHYs"} {
            ChunkpHYs
        } else {
            if {$length > 0 } {
    			bytes $length "Raw Data"
            }
            sectionvalue "$length bytes"
		}
		hex 4 "CRC"
        sectionname $type
	}
}
