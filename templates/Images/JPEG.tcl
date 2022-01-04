# JPEG Format
# Author: Simon Jentzsch

hf_min_version_required 2.14.2
big_endian
requires 0 "FF D8 FF"

include "Metadata/Exif.tcl"

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

proc do_exif {} {
    section "EXIF" {
        ascii 6 "Exif Marker"
        Exif
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
