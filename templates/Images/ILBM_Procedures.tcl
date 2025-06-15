# Images/ILBM_Procedures.tcl
# Procedures and Chunk Definitions
# for ILBM (Interleaved Bitmap) and PBM (Planar Bitmap) files.
#
# 2022 Jun 28 | Andreas Stahl | Initial implementation.
# 2025 Jun 06 | Andreas Stahl | Extracted IFF procedure, added documentation.
#
# Documentation referenced:
# - https://wiki.amigaos.net/wiki/ILBM_IFF_Interleaved_Bitmap
# - https://moddingwiki.shikadi.net/wiki/LBM_Format
#
# Authors:
# - Andreas Stahl https://www.github.com/nonsquarepixels
#
# .min_version_required = 2.17;
# .hidden = true;



###############################################################################
##                             COMMON PROCEDURES                             ##
###############################################################################



###############################################################################
# Value template for a 24-bit RGB value, formatted as a "W3C Style" hex number:
# "#RRGGBB", e.g. #33F052
# Setting the is_4bit to true parameter will compact the values to the upper
# nybble:
# "#RGB", e.g. #3F5
# This is useful because the ILBM spec advises to upscale a color map of 4 bit
# per channel values when reading an ILBM file by repeating each nybble.
proc color3 {label is_4bit} {
    section -collapsed $label
    set r [uint8 "Red"]
    set g [uint8 "Green"]
    set b [uint8 "Blue"]
    if {$is_4bit} {
        set r [expr $r >> 4]
        set g [expr $g >> 4]
        set b [expr $b >> 4]
        sectionvalue [format "#%01X%01X%01X" $r $g $b]
    } else {
        sectionvalue [format "#%02X%02X%02X" $r $g $b]
    }
    endsection
    return [list $r $g $b]
}

###############################################################################
# Value template for a 2-element vector (x, y) of the given element type.
# It is represented as a collapsed section.
proc vec2 { type label {xLabel "X"} {yLabel "Y"} {separator ", "}} {
    section -collapsed $label
    set xVal [$type $xLabel]
    set yVal [$type $yLabel]
    sectionvalue $xVal$separator$yVal
    endsection
    return [list $xVal $yVal]
}

###############################################################################
# Value template for a 2-element vector (x, y) of the given element type.
# It is represented as a collapsed section.
proc vec3 {
    type label {xLabel "X"} {yLabel "Y"} {zLabel "Z"} {separator ", "}} {
    section -collapsed $label
    set xVal [$type $xLabel]
    set yVal [$type $yLabel]
    set zVal [$type $zLabel]
    sectionvalue $xVal$separator$yVal$separator$zVal
    endsection
    return [list $xVal $yVal $zVal]
}

###############################################################################
# A kind of hacky-switchy way to select a string displayed in an entry
# depending on the value.
# The value has to be read in already and the pos should be directly after the
# value. The size parameter needs to be the same size as the value to work
# correctly.
#
# Examples:
#
# Read the third lsb from a 16-bit flag field and show the value:
#
#     select "Status" [uint16_bits 3] 2 {
#         0 "Inactive"
#         1 "Active"
#     }
#
# Read a byte and display a string associated with the byte's 'value:
#
#     select "Mask" [uint8] 1 {
#         0 "No Masking"
#         1 "Mask Plane"
#         2 "Transparent Color"
#         3 "Lasso"
#     } "Unknown Mask Type"
#
proc select { label value size values {fallback "Other"} } {
    move -$size
    array set valAry $values
    set name [array get valAry $value]
    if {[llength $name] == 2} {
        set name [lindex $name 1]
    } else {
        set name $fallback
    }
    entry $label "$value: $name" $size
    move $size
    return $value
}

###############################################################################
# Interprets a 32 bit integer as a 16/16 fixed point number.
# Used in the Deluxe Paint Perspective (DPPV and DPPS) chunks.
# Returns the value as a double
proc longfrac {{ title "" } {frac 0x10000}} {
    set int_val [int32]
    set value [expr [::tcl::mathfunc::double $int_val] / $frac]
    if {$title != "" } {
        move -4
        entry $title [format "%.5g" $value] 4
        move 4
    }
    return $value
}

###############################################################################
# A 3-vector of longfrac values.
# Used in the Deluxe Paint Perspective (DPPV and DPPS) chunks.
proc lfpoint { title {x "X"} {y "Y"} {z "Z"} {separator ", "}} {
    section -collapsed $title
    set xVal [longfrac $x]
    set yVal [longfrac $y]
    set zVal [longfrac $z]
    proc fmt {val} { return [format "% .2f" $val] }
    sectionvalue [fmt $xVal]$separator[fmt $yVal]$separator[fmt $zVal]
    endsection
    return [list $xVal $yVal $zVal]
}



###############################################################################
##                             CHUNK DEFINITIONS                             ##
###############################################################################



###############################################################################
# BMHD: Bitmap Header
proc parseIlbmBmhd {length} {
    sectionname "Header"

    global nPlanes
    set width [uint16 "Width"]
    set height [uint16 "Height"]
    vec2 int16 "Origin Point"

    set nPlanes [uint8 "Plane Count"]

    set masking [select "Mask" [uint8] 1 {
        0 "No Masking"
        1 "Mask Plane"
        2 "Transparent Color"
        3 "Lasso"
    }]

    set compression [select "Compression" [uint8] 1 {
        0 None
        1 ByteRun1
    }]

    uint8 "pad1"
    uint16 "Transparent Color Index"
    vec2 uint8 "Pixel Aspect Ratio" "X" "Y" ":"
    vec2 uint16 "Page Size" "Width" "Height"

    sectionvalue "${width}x${height} [expr 2 ** $nPlanes] colors"
}

###############################################################################
# CMAP: Color Map
# The palette of the image, defined as 24 bit RGB colors (1 byte per channel).
proc parseIlbmCmap {length} {
    sectionname "Colors"
    global nPlanes

    set entry_count [expr $length / 3]
    assert { $length % 3 == 0 }
    set is_4bit true
    for {set i 0} {$i < $length} {incr i} {
        set lower_nibble [expr 0xF & [uint8]]
        if {$lower_nibble != 0} {
            set is_4bit false
            # don't break so we can just move back by $length
        }
    }
    move [expr -$length]
    section -collapsed "Palette" {
        for {set i 0} {$i < $entry_count} {incr i} {
            color3 "\[ $i \]" $is_4bit
        }
        sectionvalue "$entry_count colors"
    }
    sectionvalue "$entry_count colors ($nPlanes bits)"
}

################################################################################
# GRAB: Hotspot
# The optional property “GRAB” locates a “handle” or “hotspot” of the image
# relative to its upper left corner, e.g., when used as a mouse cursor or a
# “paint brush”.
proc parseIlbmGrab {length} {
    sectionname "Hotspot"
    set point [vec2 int16 "Point"]
    sectionvalue [join $point ", "]
}

###############################################################################
# DEST: Destmerge
# The optional property “DEST” is a way to say how to scatter zero or more
# source bitplanes into a deeper destination image.
proc parseIlbmDest {length} {
    sectionname "Destmerge"
    # # bitplanes in the original source
    uint8 "Depth"

    # unused; for consistency put 0 here
    uint8 "Pad1"

    # how to scatter source bitplanes into destination
    uint16 "Plane Pick"

    # default bitplane data for planePick
    uint16 "Plane On Off"

    # selects which bitplanes to store into
    uint16 "Plane Mask"
}

###############################################################################
# SPRT: Sprite
# The presence of an “SPRT” chunk indicates that this image is intended as a
# sprite.
proc parseIlbmSprt {length} {
    sectionname "Sprite"
    uint16 "Sprite Precedence"
}

###############################################################################
# CAMG
# A “CAMG” chunk is specifically for Amiga ILBMs. All Amiga-based reader and
# writer software should deal with CAMG. The Amiga supports many different
# video display modes including interlace, Extra Halfbrite, hold and modify
# (HAM), plus a variety of new modes under the 2.0 operating system.
# A CAMG chunk contains a single long word (length=4) which specifies the Amiga
# display mode of the picture.
proc parseIlbmCamg {length} {
    sectionname "Amiga"
    uint32 -hex "Display Mode"
}

###############################################################################
# CRNG: Color Cycle Range
# A tuple of indexes into the palette that cycle by rotating the color values
# between the indexes.
# This is the Deluxe Paint Cycling definition. For an alternate definition,
# see the CCRT Chunk.
proc parseIlbmCrng {length} {
    sectionname "Color Range"
    int16 "Pad1"
    set rate [int16]
    move -2
    if {$rate != 0} {
        section -collapsed "Cycle Rate" {
            set jiffies [expr 16384.0 / $rate]
            set duration [expr $jiffies / 60]
            entry "Jiffies" [format "%.2f (s / 60)" $jiffies] 2
            sectionvalue [format "0x%04X %.2fHz" $rate [expr 60 / $jiffies]]
            if {$duration < 1.0} {
                entry "Delay" [format "%.1f (ms)" [expr $duration * 1000]] 2
            } else {
                entry "Delay" [format "%.3f (s)" $duration] 2
            }
        }
    } else {
        entry "Cycle Rate" 0 2
    }
    move 2
    section -collapsed "Flags" {
        set flags [uint16]
        sectionvalue [format "0x%04X" $flags]
        # just the two least significant bits have a meaningful value, so
        # we treat it like a uint8
        move -1
        select "\[0\] Active" [uint8_bits 0] 1 {
            0 "Inactive"
            1 "Active"
        }
        move -1
        select "\[1\] Direction" [uint8_bits 1] 1 {
            0 "Ascending"
            1 "Descending"
        }
    }
    vec2 uint8 "Index Range" "Low" "High" ".."
}

###############################################################################
# CCRT: Color Cycling Range and Timing
# for Commodore Graphicraft
proc parseIlbmCcrt {length} {
    int16 "Direction"
    vec2 uint8 "Index Range" "Start" "End" ".."
    int "Seconds"
    int "Microseconds"
    int16 "pad"
}

###############################################################################
# DPPV: Deluxe Paint perspective chunk version 1.
proc parseIlbmDppv {length} {
    sectionname "Perspective"
    select "Rotation Type" [int16] 2 {
        0 "Euler"
        1 "Incr"
    }
    vec3 int16 "Rotation (deg)" "A" "B" "C"
    longfrac "Depth"
    vec2 int16 "Center" "U" "V"
    int16 "Fixed Coordinate"
    int16 "Angle Step"

    section "Grid" {
        lfpoint "Spacing"
        lfpoint "Reset"
        lfpoint "Brush Center"
    }
    lfpoint "Perm Brush Center"
    section -collapsed "Rotation Matrix" {
        lfpoint "\[0\]"
        lfpoint "\[1\]"
        lfpoint "\[2\]"
    }
}

###############################################################################
# DPPS: Deluxe Paint perspective chunk version 2.
# This is a bit speculative, since there seems to be no documentation for this
# chunk anywhere online. However, the structure seems to be similar enough to
# the DPPV chunk, with the rotation angle int16 vector replaced by longfrac.
proc parseIlbmDpps {length} {
    sectionname "Perspective"
    select "Rotation Type" [int16] 2 {
        0 "Euler"
        1 "Incr"
        2 "Screen"
        3 "Brush"
    }
    lfpoint "Rotation (rad)"

    longfrac "Depth"
    vec2 int16 "Center" "U" "V"
    int16 "Fixed Coordinate"
    int16 "Angle Step"

    section "Grid" {
        lfpoint "Spacing"
        lfpoint "Reset"
        lfpoint "Brush Center"
    }
    lfpoint "Perm Brush Center"
    section "Rotation Matrix" {
        lfpoint "\[0\]"
        lfpoint "\[1\]"
        lfpoint "\[2\]"
    }
}

###############################################################################
# TINY: Thumbnail
proc parseIlbmTiny {length} {
    sectionname "Thumbnail"
    vec2 uint16 "Size" "Width" "Height" "x"
    bytes [expr $length - 4] "Image Data"
}

###############################################################################
# BODY: Image Data
proc parseIlbmBody {length} {
    sectionname "Body"
    bytes $length "Image Data"
}

###############################################################################
# Aliases for PBM files (MS-DOS Deluxe Paint (S)VGA Files)
proc parsePbmBmhd args {parseIlbmBmhd $args}
proc parsePbmCmap args {parseIlbmCmap $args}
proc parsePbmGrab args {parseIlbmGrab $args}
proc parsePbmDest args {parseIlbmDest $args}
proc parsePbmSprt args {parseIlbmSprt $args}
proc parsePbmCrng args {parseIlbmCrng $args}
proc parsePbmDppv args {parseIlbmDppv $args}
proc parsePbmDpps args {parseIlbmDpps $args}
proc parsePbmTiny args {parseIlbmTiny $args}
# Note, the planar bitmap has a different body structure than the interleaved
# bitmap, so if it were to be decoded in the chunk handler, it would need a
# distinct implementation.
proc parsePbmBody args {parseIlbmBody $args}
