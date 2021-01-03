# JPEG Format
# Author: Simon Jentzsch

big_endian
requires 0 "FF D8 FF"

proc is x {set x}
proc secName {value} {
  return [switch -- $value {
    216 { is "Start of Image"}
    224 { is "JFIF"}
    192 { is "Baseline DCT"}
    193 { is "Extended sequential DCT"}
    194 { is "Progressive DCT"}
    195 { is "Lossless (sequential)"}
    196 { is "Def Huffman Table"}
    197 { is "Differential sequential DCT"}
    198 { is "Differential progressive DCT"}
    199 { is "Differential lossless (sequential)"}
    200 { is "JPEG extensions"}
    201 { is "Extended sequential DCT"}
    202 { is "Progressive DCT"}
    203 { is "Lossless (sequential)"}
    205 { is "Differential sequential DCT"}
    206 { is "Differential progressive DCT"}
    207 { is "Differential lossless (sequential)"}
    204 { is "Def arithmetic Codes"}
    219 { is "Def Quantization tables"}
    221 { is "Def Restart Interval"}
    225 { is "EXIF"}
    226 { is "App Data"}
    227 { is "App Data 3"}
    228 { is "App Data 4"}
    229 { is "App Data 5"}
    230 { is "App Data 6"}
    231 { is "App Data 7"}
    232 { is "App Data 8"}
    233 { is "App Data 9"}
    234 { is "App Data 10"}
    235 { is "App Data 11"}
    236 { is "App Data 12"}
    237 { is "App Data 13"}
    238 { is "Copyright"}
    254 { is "Comment"}
    218 { is "Start of Scan"}
    217 { is "End of Image"}
    default {is [format "Tag %X" $value ]}
  }]
}

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
    318 { is "WhiteColor"}
    319 { is "MainColor"}
    529 { is "YCbCr Coefficient"}
    531 { is "YCbCr Position"}
    532 { is "Black/White Reference"}
    33434 { is "Exposure time"}
    33437 { is "F-Aperture number"}
    34850 { is "F-Aperture Type"}
    34855 { is "ISO Exposure"}
    36864 { is "Exif Version"}
    36867 { is "Created"}
    36868 { is "Digitalized"}
    37121 { is "Color Order"}
    37122 { is "Compression"}
    37377 { is "Exposure APEX"}
    37378 { is "Aperture APEX"}
    37379 { is "Brightness APEX"}
    37380 { is "Brightness Compensation APEX"}
    37381 { is "Max Aperture APEX"}
    37382 { is "Distance m"}
    37383 { is "Exposure Type"}
    37384 { is "Light Source"}
    37385 { is "Flash Light"}
    37386 { is "Focal length"}
    37500 { is "Custom Data"}
    37510 { is "User Comment"}
    37520 { is "Time"}
    37521 { is "Time Series"}
    37522 { is "Time Series 2"}
    40960 { is "FlashPix Version"}
    40961 { is "Color Room"}
    40962 { is "Resolution X"}
    40963 { is "Resolution Y"}
    40964 { is "Audio Name"}
    41486 { is "Resolution CCD X"}
    41487 { is "Resolution CCD Y"}
    41488 { is "Resolution Unit CCD"}
    default {is [format "Unknown(%d)" $value ]}
  }]
}

proc ifd {base_pos} {
    set entries [uint16 "Entries"]
    for {set i 0} {$i < $entries} {incr i} {
        set type [uint16]
        set dtype [uint16]
        set l [uint32]
        set label [tag2Name $type]
        if {$l > 4 } {
            set offset [uint32]
            set last_pos [pos]
            goto [expr $base_pos + $offset]
        }
        if {$type == 34665} {
            set offset [uint32]
            set last_pos [pos]
            goto [expr $base_pos + $offset]
            ifd $base_pos
            goto $last_pos
            continue
        }
        if {[end]} break
        switch $dtype {
            1 {
                uint8 $label
                move 3
            }
            2 {
                ascii $l $label
                move 1
                if {$l < 3} { move [expr 3 - $l] } 
            }
            3 {
                uint16 $label
                move 2
            }
            4 {
                uint32 $label
            }
            5 {
                if {$l < 8} { uint32 $label}
                if {$l > 7} { entry $label [format "%d/%d" [uint32] [uint32] ] }
            }
            6 {
                int8 $label
                move 3
            }
            7 {
                hex $l $label
                if {$l < 3} { move [expr 3 - $l] } 
            }
            8 {
                int16 $label
                move 2
            }
            9 {
                int32 $label
            }
            10 {
                entry $label [format "%d/%d" [int32] [int32] ]
            }
            11 {
                float $label
            }
            12 {
                double $label
            }
        }
       if {$l > 4 } {
            goto $last_pos
        }
    }
}

proc do_exif {} {
    section "EXIF" {
        ascii 6 "Exif Marker"
        set tt [uint16 -hex "TIFF Format"]
        if {$tt == 18761} {
            entry "Format" "Intel"
            little_endian
        }
        if {$tt == 19789} {
            entry "Format" "Motorola"
            big_endian
        }
        uint16 "16Bit Coding"
        uint32 "tiff offset"
        set base_pos [expr [pos] - 8]
        ifd $base_pos
        big_endian
    }
}

proc exif {len stype} {
    if { $len > 6 && $stype == 225 } {
        set marker [uint32]
        move -4
        if { $marker == 1165519206 } {
            do_exif
            return 1
        }
    }
    return 0
}
proc find_next {} {
  set st [pos]
  set last 0
  set found 0
  while {![end]} {
      set b [uint8]
      if { $last == 255 && $b > 0 } {
          set found [expr [pos] - $st - 2 ]
          break
      }
      set last $b 
  }
  goto $st
  return $found
}

proc esect {stype} {
    set start_section [pos]
    set dlen [uint16]
    set marker [exif $dlen $stype]

    if {$stype >207 && $stype < 216} {
        move -4
        section "Restart Marker" {
            uint8 -hex Marker
            uint8 -hex Counter
        }
        set dlen 0
        set marker 1
    }

    if { $marker == 0 } {
        set content [expr $dlen - 2]
        move -2
        if {[len] < $start_section + $dlen} {
            entry InvalidLen $dlen
            set content 1
        }
        switch $stype {
            225 {
                section Meta {
                   uint16 Length
                   ascii $content "Content"
                }
            }
            238 {
                section Copyright {
                    uint16 Length
                    ascii $content "Content"
                } 
            }
            default {
                section [secName $stype] {
                   uint16 Length
                   bytes $content Content
                }
            }
        }
    }

    goto [expr $start_section + $dlen]

    set next 0
    if {![end]} {
        set next [uint8]
        move -1
    }

    if {$next != 255} {
        set ll [find_next]
        if {$ll>0} {
            section ImageData {
                entry Length $ll
                bytes $ll data
            }
        }
    }
}


while {![end]} {
    set tag_start [uint8]
    set tag_type [uint8]

    if {$tag_start != 0xff} break 

    switch $tag_type {
        0 {}
        216 {}
        217 {}
        224 {
            section "JFIF" {
            	set len [uint16 "Length"]
                set jfif_type [ascii 4 "Marker"]
                move 1
                if {$jfif_type == "JFIF"} {
                    hex 2 "Version"
                    set unit_type [uint8 "Unit Type"]
                    uint16 "Width Density"
                    uint16 "Height Density"
                    set tx [uint8 "Width Thumbnail"]
                    set ty [uint8 "Height Thumbnail"]
                    if {$tx > 0} {
                        bytes [expr $tx * $ty * 3] "Thumbnail Data"
                    }
                }
                if {$jfif_type == "JFXX"} {
                    set tt [uint8 "Thumbnail Type"]
                    if {$len > 3} {
                        bytes [expr $len - 3] "Thumbnail Data"
                    }
                }
            }
        }
        default {
            esect $tag_type
        }
    }
}
