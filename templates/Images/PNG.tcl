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

proc ChunkgAMA {} {
    set gamma [uint32 Gamma]
    set derived_gamma [expr 100000 / $gamma]
    sectionvalue "Gamma: $derived_gamma"
}

proc ChunksRGB {} {
    set intent [uint8 "Rendering Intent"]

    switch $intent {
        0 { set intent_str "Perceptual" }
        1 { set intent_str "Relative Colorimetric" }
        2 { set intent_str "Saturation" }
        3 { set intent_str "Absolute Colorimetric" }
        default { set intent_str "Unknown" }
    }

    sectionvalue "Intent: $intent_str"
}

proc IFDFieldByte {count} {
    ascii $count "Value"
}

proc IFDFieldWord {count} {
    uint16 "Word"
}

proc IFDFieldLong {count} {
    uint32 "Long"
}

proc IFDFieldRational {count} {
    uint32 "Numerator"
    uint32 "Denominator"
}

proc IFDFieldFloat {count} {
    float "Float"
}

proc IFDFieldDouble {count} {
    double "Double"
}

proc ChunkeXIfIFDField {header_pos field_size component_count read_proc} {
    set total_size [expr $component_count * $field_size]
    set is_remote [expr $total_size > 4]
    set read_pos 0

    if {$is_remote} {
        set offset [uint32 "Remote Offset"]
        set read_pos [pos]
        goto [expr $header_pos + $offset]
    }

    set result [$read_proc $component_count]

    if {$is_remote} {
        goto $read_pos
    } else {
        set leftovers [expr 4 - $total_size]
        if {$leftovers > 0} {
            bytes $leftovers "Extra ($leftovers bytes)"
        }
    }

    return $result
}

proc ChunkeXIfIFDEntry {header_pos count} {
    section "\[ $count \]" {
        set tag_number [uint16 "Tag Number"]
        set field_type [uint16 "Field Type"]
        set component_count [uint32 "Component Count"]
        switch $field_type {
            1  { set tag_value [ChunkeXIfIFDField $header_pos 1 $component_count IFDFieldByte] }
            2  { set tag_value [ChunkeXIfIFDField $header_pos 1 $component_count IFDFieldByte] }
            3  { set tag_value [ChunkeXIfIFDField $header_pos 2 $component_count IFDFieldWord] }
            4  { set tag_value [ChunkeXIfIFDField $header_pos 4 $component_count IFDFieldLong] }
            5  { set tag_value [ChunkeXIfIFDField $header_pos 8 $component_count IFDFieldRational] }
            6  { set tag_value [ChunkeXIfIFDField $header_pos 1 $component_count IFDFieldByte] }
            7  { set tag_value [ChunkeXIfIFDField $header_pos 1 $component_count IFDFieldByte] }
            8  { set tag_value [ChunkeXIfIFDField $header_pos 2 $component_count IFDFieldWord] }
            9  { set tag_value [ChunkeXIfIFDField $header_pos 4 $component_count IFDFieldLong] }
            10 { set tag_value [ChunkeXIfIFDField $header_pos 8 $component_count IFDFieldRational] }
            11 { set tag_value [ChunkeXIfIFDField $header_pos 4 $component_count IFDFieldFloat] }
            12 { set tag_value [ChunkeXIfIFDField $header_pos 8 $component_count IFDFieldDouble] }
        }
        sectionname $tag_number
        sectionvalue $tag_value
    }
}

proc ChunkeXIfIFD {header_pos} {
    set count [uint16 "Entry Count"]
    section "Entries" {
        for {set i 0} {$i < $count} {incr i} {
            ChunkeXIfIFDEntry $header_pos $i
            if {$i == 3} {
                # return
            }
        }
        # sectionvalue "$count entries"
    }
    set next_offset [uint32 "Next IFD Offset"]
    return
    if {$next_offset != 0} {
        set marker [pos]
        move $next_offset
        ChunkeXIfIFD $header_pos
        goto $marker
    }
}

proc ChunkeXIf {length} {
    set header_pos [pos]
    set header [uint16 Header]

    if {$header == 0x4D4D} {
        big_endian
        entry "" "(Big Endian)" 2 [expr [pos] - 2]
    } else {
        little_endian
        entry "" "(Little Endian)" 2 [expr [pos] - 2]
    }

    uint16 "Tag Mark"
    set ifd_offset [uint32 "IFD Offset"]
    if {$ifd_offset != 8} {
        entry "" "WARNING: Unsupported IFD offset (but may be well-formed)"
        return
    }
    ChunkeXIfIFD $header_pos
}

proc ChunkbKGD {length} {
    if {$length == 1} {
        uint8 "Color Index"
    } elseif {$length == 2} {
        uint16 "Gray"
    } elseif {$length == 6} {
        uint16 "Red"
        uint16 "Green"
        uint16 "Blue"
    } else {
        entry "" "WARNING: Unknown bKGD chunk length"
    }

    sectionvalue "Background Color"
}

proc ChunksBIT {length} {
    if {$length == 1} {
        uint8 "Gray"
    } elseif {$length == 3} {
        uint8 "Red"
        uint8 "Green"
        uint8 "Blue"
    } elseif {$length == 2} {
        uint8 "Gray"
        uint8 "Alpha"
    } elseif {$length == 4} {
        uint8 "Red"
        uint8 "Green"
        uint8 "Blue"
        uint8 "Alpha"
    } else {
        entry "" "WARNING: Unknown sBIT chunk length"
    }

    sectionvalue "Significant Bits"
}

proc ChunkcHRM {} {
    uint32 "White Point x"
    uint32 "White Point y"
    uint32 "Red x"
    uint32 "Red y"
    uint32 "Green x"
    uint32 "Green y"
    uint32 "Blue x"
    uint32 "Blue y"

    sectionvalue "Chromaticities"
}

proc ChunkpHYs {} {
    set ppux [uint32 "Pixels Per Unit X"]
    set ppuy [uint32 "Pixels Per Unit Y"]
    set ratio [expr $ppux / $ppuy]
    set unit [uint8 "Unit"]
    if {$unit == 1} {
        # unit is the meter
        set dpi [expr $ppux * 0.0254]
        sectionvalue "Aspect Ratio: $ratio; DPI: $dpi"
    } else {
        # unit is unknown
        sectionvalue "Aspect Ratio: $ratio"
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
    ascii $leftovers "Text"
    sectionvalue "\'$keyword\'"
}

proc ChunkzTXt {length} {
    set start [pos]
    set keyword [cstr "utf8" "Keyword"]
    uint8 "Compression Method"
    set leftovers [expr $length - ([pos] - $start)]
    set deflated [bytes $leftovers]
    set inflated [zlib_uncompress $deflated]
    entry "Inflated Text" $inflated $leftovers [expr [pos] - $leftovers] 
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
        } elseif {$type == "zTXt"} {
            ChunkzTXt $length
        } elseif {$type == "pHYs"} {
            ChunkpHYs
        } elseif {$type == "gAMA"} {
            ChunkgAMA
        } elseif {$type == "sRGB"} {
            ChunksRGB
        } elseif {$type == "cHRM"} {
            ChunkcHRM
        } elseif {$type == "sBIT"} {
            ChunksBIT $length
        } elseif {$type == "bKGD"} {
            ChunkbKGD $length
        } elseif {$type == "eXIf"} {
            ChunkeXIf $length
            return
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
