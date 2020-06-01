# Haiku Vector Icon Format
# This isn't really documented, all I had to work from was these source files:
# https://github.com/haiku/haiku/blob/master/src/libs/icon/flat_icon/FlatIconFormat.h
# https://github.com/haiku/haiku/blob/master/src/libs/icon/flat_icon/FlatIconFormat.cpp
# https://github.com/haiku/haiku/blob/master/src/libs/icon/flat_icon/FlatIconImporter.cpp

proc uint8_dict { name dict {default ""} } {
    set n [uint8]
    set v $default
    if { [dict exists $dict $n] } {
        set v [dict get $dict $n]
    }
    entry $name [format "%s (%d)" $v $n] 1 [expr [pos]-1]
    return $n
}

set style_types [dict create \
    1 "SOLID_COLOR" \
    2 "GRADIENT" \
    3 "SOLID_COLOR_NO_ALPHA" \
    4 "SOLID_GRAY" \
    5 "SOLID_GRAY_NO_ALPHA" \
]

set transformer_types [dict create \
    20 "AFFINE" \
    21 "CONTOUR" \
    22 "PERSPECTIVE" \
    23 "STROKE" \
]

set shape_types [dict create \
    10 "PATH_SOURCE" \
]

set gradient_types [dict create \
    0 "LINEAR" \
    1 "CIRCULAR" \
    2 "DIAMOND" \
    3 "CONIC" \
    4 "XY" \
    5 "SQRT_XY" \
]

set command_names [dict create \
    0 "H_LINE" \
    1 "V_LINE" \
    2 "LINE" \
    3 "CURVE" \
]

proc hvif_coord {name} {
    # HVIF's special coordinate format can be either a 2-byte float or
    # a 1-byte int (each with offsets and such)
    set value [uint8]
    if {$value & 128} {
        set low [uint8]
        set value [expr $value & 127]
        set coord [expr ($value << 8) | $low]
        set coord [expr ($coord / 102.0) - 128.0]
        entry $name $coord 2 [expr [pos]-2]
    } else {
        set coord [expr $value - 32.0]
        entry $name $coord 1 [expr [pos]-1]
    }
    return $coord
}

proc transformable {} {
    set matrix_size 6
    bytes [expr 3 * $matrix_size] "Matrix"
    #TODO actually parse the special 24-bit floats
}

proc color {alpha gray} {
    if {$gray} {
        uint8 "White"
    } else {
        uint8 "Red"
        uint8 "Green"
        uint8 "Blue"
    }
    if {$alpha} {
        uint8 "Alpha"
    }
}

proc gradientstyle {} {
    global gradient_types
    uint8_dict "Gradient type" $gradient_types "Invalid"
    set flags [uint8 "Flags"]
    set n [uint8 "Stop count"]

    if {$flags & 2} {
        transformable
    }

    set alpha [expr !($flags & 4)]
    set gray [expr $flags & 16]

    for {set i 0} {$i < $n} {incr i} {
        section "Stop $i" {
            uint8 "Offset"
            color $alpha $gray
        }
    }
}

proc style {} {
    global style_types
    set type [uint8_dict "Type" $style_types "Invalid"]
    if {$type == 1} { ;# SOLID_COLOR
        color 1 0
    } elseif {$type == 2} { ;# GRADIENT
        gradientstyle
    } elseif {$type == 3} { ;# SOLID_COLOR_NO_ALPHA
        color 0 0
    } elseif {$type == 4} { ;# SOLID_GRAY
        color 1 1
    } elseif {$type == 5} { ;# SOLID_GRAY_NO_ALPHA
        color 0 1
    }
}

proc path_no_curves {n} {
    for {set i 0} {$i < $n} {incr i} {
        section "Point $i" {
            hvif_coord "x"
            hvif_coord "y"
        }
    }
}

proc path_with_commands {n} {
    global command_names
    set commands_len [expr ($n + 3) / 4]
    for {set i 0} {$i < $commands_len} {incr i} {
        set cmds [uint8]
        lappend commands [expr $cmds & 3]
        lappend commands [expr $cmds >> 2 & 3]
        lappend commands [expr $cmds >> 4 & 3]
        lappend commands [expr $cmds >> 6 & 3]
    }
    move -$commands_len
    bytes $commands_len "Commands"
    for {set i 0} {$i < $n} {incr i} {
        set cmd [lindex $commands $i]
        set name "Invalid"
        if { [dict exists $command_names $cmd] } {
            set name [dict get $command_names $cmd]
        }
        section "$name ($cmd)" {
            if {$cmd == 0} { ;# H_LINE
                hvif_coord "y"
            } elseif {$cmd == 1} { ;# V_LINE
                hvif_coord "x"
            } elseif {$cmd == 2} { ;# LINE
                hvif_coord "x"
                hvif_coord "y"
            } elseif {$cmd == 3} { ;# CURVE
                hvif_coord "x"
                hvif_coord "y"
                hvif_coord "xIn"
                hvif_coord "yIn"
                hvif_coord "xOut"
                hvif_coord "yOut"
            }
        }
    }
}

proc path_with_curves {n} {
    for {set i 0} {$i < $n} {incr i} {
        section "Point $i" {
            hvif_coord "x"
            hvif_coord "y"
            hvif_coord "xIn"
            hvif_coord "yIn"
            hvif_coord "xOut"
            hvif_coord "yOut"
        }
    }
}

proc path {} {
    set flags [uint8 "Flags"]
    set n [uint8 "Size"]
    if {$flags & 8} {
        path_no_curves $n
    } elseif {$flags & 4} {
        path_with_commands $n
    } else {
        path_with_curves $n
    }
}

proc transformer {} {
    global transformer_types
    set type [uint8_dict "Type" $transformer_types "Invalid"]
    if {$type == 20} { ;# AFFINE
        for {set i 0} {$i < 7} {incr i} { int32 "matrix$i" }
    } elseif {$type == 21} { ;# CONTOUR
        entry "Width" [expr [uint8] - 128.0] 1 [expr [pos]-1]
        uint8 "Line join"
        uint8 "Miter limit"
    } elseif {$type == 22} { ;# PERSPECTIVE
        # Doesn't seem to be implemented/specified
    } elseif {$type == 23} { ;# STROKE
        entry "Width" [expr [uint8] - 128.0] 1 [expr [pos]-1]
        uint8 "Line options"
        uint8 "Miter limit"
    }
}

proc shape {} {
    global shape_types
    set type [uint8_dict "Type" $shape_types "Invalid"]
    if {$type == 10} { ;# PATH_SOURCE (there's only 1 type)
        uint8 "Style"
        set n [uint8 "Path count"]
        for {set i 0} {$i < $n} {incr i} {
            uint8 "Path $i"
        }
        set flags [uint8 "Flags"]
        if {$flags & 2} {
            transformable
        } elseif {$flags & 32} {
            hvif_coord "Translate X"
            hvif_coord "Translate Y"
        }
        if {$flags & 8} {
            entry "Min LOD" [expr [uint8] / 63.75] 1 [expr [pos]-1]
            entry "Max LOD" [expr [uint8] / 63.75] 1 [expr [pos]-1]
        }
        if {$flags & 16} {
            set n [uint8 "Transformer count"]
            for {set i 0} {$i < $n} {incr i} {
                section "Transformer $i" {
                    transformer
                }
            }
        }
    }
}

# "ncif"
requires 0 "6E 63 69 66"
ascii 4 "Magic"
section "Styles" {
    set n [uint8 "Size"]
    for {set i 0} {$i < $n} {incr i} {
        section "Style $i" {
            style
        }
    }
}
section "Paths" {
    set n [uint8 "Size"]
    for {set i 0} {$i < $n} {incr i} {
        section "Path $i" {
            path
        }
    }
}
section "Shapes" {
    set n [uint8 "Size"]
    for {set i 0} {$i < $n} {incr i} {
        section "Shape $i" {
            shape
        }
    }
}
