# Reference Documents
# TIFF Revision 6.0, Final -- Aldus Corporation -- June 3, 1992
# TIFF Tag Reference -- Aware Systems
# TIFF File Format Summary -- FileFormat.Info

# Procedures

proc stringSize {} {
  for {set size 1} {[ascii 1] != ""} {incr size} {}
  move -$size
  return $size
}

# Like `entry label value length` but the file pointer is moved backward first.
proc backwardEntry {label value length} {
  move -$length
  entry $label $value $length
  move $length
}

proc is x {set x}

proc tag2Name {value} {
  return [switch -- $value {
    254 {is NewSubfileType}
    255 {is SubfileType}
    256 {is ImageWidth}
    257 {is ImageLength}
    258 {is BitsPerSample}
    259 {is Compression}
    262 {is PhotometricInterpretation}
    266 {is FillOrder}
    269 {is DocumentName}
    270 {is ImageDescription}
    271 {is Make}
    272 {is Model}
    273 {is StripOffsets}
    274 {is Orientation}
    277 {is SamplesPerPixel}
    278 {is RowsPerStrip}
    279 {is StripByteCounts}
    282 {is XResolution}
    283 {is YResolution}
    284 {is PlanarConfiguration}
    296 {is ResolutionUnit}
    305 {is Software}
    306 {is DateTime}
    315 {is Artist}
    316 {is HostComputer}
    317 {is Predictor}
    320 {is ColorMap}
    322 {is TileWidth}
    323 {is TileLength}
    324 {is TileOffsets}
    325 {is TileByteCounts}
    338 {is ExtraSamples}
    339 {is SampleFormat}
    34377 {is Photoshop}
    33432 {is Copyright}
    default {is "Unknown Entry"}
  }]
}

proc type2Name {value} {
  return [switch -- $value {
    1 {is Byte}
    2 {is ASCII}
    3 {is Short}
    4 {is Long}
    5 {is Rational}
    6 {is SByte}
    7 {is Undefined}
    8 {is SShort}
    9 {is SLong}
    10 {is SRational}
    11 {is Float}
    12 {is Double}
    default {is "Unexpected type ($typeVal)"}
  }]
}

proc compression2Name {value} {
  return [switch -- $value {
    1 {is None}
    2 {is CCITT_RLE}
    3 {is CCITT_Fax3}
    4 {is CCITT_Fax4}
    5 {is LZW}
    6 {is Old_JPEG}
    7 {is JPEG}
    8 {is Adobe_Deflate}
    32773 {is PackBits}
    default {is "$value ?"}
  }]
}

proc photometricInterpretation2Name {value} {
  return [switch -- $value {
    0 {is WhiteIsZero}
    1 {is BlackIsZero}
    2 {is RGB}
    3 {is Palette}
    4 {is Mask}
    default {is "$value ?"}
  }]
}

proc fillOrder2Name {value} {
  return [switch -- $value {
    1 {is MSB2LSB}
    2 {is LSB2MSB}
    default {is "$value ?"}
  }]
}

proc planarConfiguration2Name {value} {
  return [switch -- $value {
    1 {is Contiguous}
    2 {is Separate}
    default {is "$value ?"}
  }]
}

proc resolutionUnit2Name {value} {
  return [switch -- $value {
    1 {is None}
    2 {is Inch}
    3 {is Centimeter}
    default {is "$value ?"}
  }]
}

proc predictor2Name {value} {
  return [switch -- $value {
    1 {is None}
    2 {is Horizontal}
    3 {is FloatingPoint}
    default {is "$value ?"}
  }]
}

proc showValue {tagVal typeVal count} {
  if {$tagVal == 259} {
    x2Name compression2Name $typeVal
  } elseif {$tagVal == 262} {
    x2Name photometricInterpretation2Name $typeVal
  } elseif {$tagVal == 266} {
    x2Name fillOrder2Name $typeVal
  } elseif {$tagVal == 284} {
    x2Name planarConfiguration2Name $typeVal
  } elseif {$tagVal == 296} {
    x2Name resolutionUnit2Name $typeVal
  } elseif {$tagVal == 317} {
    x2Name predictor2Name $typeVal
  } else {
    showTypedValue $typeVal $count
  }
}

proc x2Name {fct typeVal} {
  # count should be 1
  set command [expr {$typeVal == 1 ? "uint8" : $typeVal == 3 ? "uint16" : "uint32"}]
  set size_t [expr {$typeVal == 3 ? 2 : $typeVal}]
  set value [$command]

  backwardEntry "Value" [$fct $value] $size_t
  padding32 $size_t
}

proc padding32 {size} {
  set padding [expr {4 - $size}]
  if {$padding > 0} {
    entry "Padding" "" $padding
    move $padding
  }
}

proc showTypedValue {typeVal count} {
  if {$typeVal == 1} { # BYTE
    showSimpleValue uint8 1 $count
  } elseif {$typeVal == 2} { # ASCII
    showAsciiValue
  } elseif {$typeVal == 3} { # SHORT
    showSimpleValue uint16 2 $count
  } elseif {$typeVal == 4} { # LONG
    showSimpleValue uint32 4 $count
  } elseif {$typeVal == 5} { # RATIONAL
    showRationalValue uint32
  } elseif {$typeVal == 6} { # SBYTE
    showSimpleValue int8 1 $count
  } elseif {$typeVal == 7} { # UNDEFINED
    uint32 "Value or Offset"
  } elseif {$typeVal == 8} { # SSHORT
    showSimpleValue int16 2 $count
  } elseif {$typeVal == 9} { # SLONG
    showSimpleValue int32 4 $count
  } elseif {$typeVal == 10} { # SRATIONAL
    showRationalValue int32
  } elseif {$typeVal == 11} { # FLOAT
    showSimpleValue float 4 $count
  } elseif {$typeVal == 12} { # DOUBLE
    showSimpleValue double 8 $count
  } else { # unexpected field type
    uint32 "Value or Offset"
  }
}

proc showAsciiValue {} {
  set offset [uint32 -hex "Offset"]
  set pos [pos]
  goto $offset
  ascii [stringSize] "Value"
  goto $pos
}

# For sByte (1-6), sShort (3-8), sLong (4-9),
proc showSimpleValue {command size_t count} {
  if {$count * $size_t <= 4} {
    # Direct value(s)
    showCountValues $command $size_t $count
    padding32 [expr {$count * $size_t}]
  } else {
    # Offset value(s)
    set offset [uint32 -hex "Offset"]
    set pos [pos]
    goto $offset
    showCountValues $command $size_t $count
    goto $pos
  }
}

proc getCountValues {command count} {
  set values [list [$command]]
  for {set i 2} {$i <= $count} {incr i} {
    lappend values [$command]
  }
  return $values
}

set lastValue ""
proc showCountValues {command size_t count} {
  set values [getCountValues $command $count]
  backwardEntry "Value" [join $values ", "] [expr $count * $size_t]

  set ::lastValue $values ; # ugly bypass
}

# For sRATIONAL (5-10)
proc showRationalValue {command} {
  set offset [uint32 -hex "Offset"]
  set pos [pos]
  goto $offset
  set num [$command "Numerator"]
  set den [$command "Denominator"]
  backwardEntry "Value" [expr {$den == 0 ? "DIV BY 0" : $num / $den}] 8
  goto $pos
}

# Template

set endianness [ascii 2 "Endianness"]

if {$endianness == "MM"} {
  big_endian
  requires 2 "00 2A"
} elseif {$endianness == "II"} {
  little_endian
  requires 2 "2A 00"
} else {
  error "invalid tiff header"
}

uint16 "\"Arbitrary\" Number"

set ifdCount 1
set ifdOffset [uint32 "First IFD Offset"]

while {$ifdOffset} {
  goto $ifdOffset

  set offsets [list]
  set counts [list]

  section "Image $ifdCount File Directory" {
    set nbEntries [uint16 "Number of Entries"]

    for {set i 0} {$i < $nbEntries} {incr i} {
      set tagVal [uint16]
      move -2

      section [tag2Name $tagVal] {
        uint16 "Tag"

        set typeVal [uint16]
        backwardEntry "Type" [type2Name $typeVal] 2

        set count [uint32 "Count"]

        showValue $tagVal $typeVal $count

        if {$tagVal == 324 || $tagVal == 273} {set offsets $lastValue}
        if {$tagVal == 325 || $tagVal == 279} {set counts $lastValue}
      }
    }
  }

  section "Image $ifdCount" {
    set pos [pos]
    set strip 1
    foreach {offset} $offsets {count} $counts {
      if {$count == ""} {set count eof}
      goto $offset
      bytes $count "Strip $strip"
      incr strip
    }
    goto $pos
  }

  incr ifdCount
  set ifdOffset [uint32 "Next IFD offset"]
}
