# JPEG Format
# Author: Simon Jentzsch
# Author: Foster Brereton

hf_min_version_required 2.15

include "Metadata/Exif.tcl"
include "Utility/General.tcl"

big_endian
requires 0 "FF D8 FF"

proc marker_name {value} {
    [switch -- $value {
        0xC0 { return "Baseline DCT" }
        0xC1 { return "Extended sequential DCT, Huffman coding" }
        0xC2 { return "Progressive DCT, Huffman coding" }
        0xC3 { return "Lossless (sequential), Huffman coding" }
        0xC4 { return "Huffman table" }
        0xC5 { return "Differential sequential DCT" }
        0xC6 { return "Differential progressive DCT" }
        0xC7 { return "Differential lossless (sequential)" }
        0xC8 { return "Reserved for JPEG extensions" }
        0xC9 { return "Extended sequential DCT, arithmetic coding" }
        0xCA { return "Progressive DCT, arithmetic coding" }
        0xCB { return "Lossless (sequential), arithmetic coding" }
        0xCC { return "Arithmetic coding conditioning" }
        0xCD { return "Differential sequential DCT" }
        0xCE { return "Differential progressive DCT" }
        0xCF { return "Differential lossless (sequential)" }
        0xD0 { return "Restart with modulo 8 count "0"" }
        0xD1 { return "Restart with modulo 8 count "1"" }
        0xD2 { return "Restart with modulo 8 count "2"" }
        0xD3 { return "Restart with modulo 8 count "3"" }
        0xD4 { return "Restart with modulo 8 count "4"" }
        0xD5 { return "Restart with modulo 8 count "5"" }
        0xD6 { return "Restart with modulo 8 count "6"" }
        0xD7 { return "Restart with modulo 8 count "7"" }
        0xD8 { return "Start of image" }
        0xD9 { return "End of image" }
        0xDA { return "Start of scan" }
        0xDB { return "Quantization table" }
        0xDC { return "Number of lines" }
        0xDD { return "Restart interval" }
        0xDE { return "Hierarchical progression" }
        0xDF { return "Expand reference component" }
        0xE0 { return "App0" }
        0xE1 { return "App1" }
        0xE2 { return "App2" }
        0xE3 { return "App3" }
        0xE4 { return "App4" }
        0xE5 { return "App5" }
        0xE6 { return "App6" }
        0xE7 { return "App7" }
        0xE8 { return "App8" }
        0xE9 { return "App9" }
        0xEA { return "App10" }
        0xEB { return "App11" }
        0xEC { return "App12" }
        0xED { return "App13" }
        0xEE { return "App14" }
        0xEF { return "App15" }
        0xFE { return "JPEG Comment Extension" }
        default { return [format "Marker %X" $value ]}
    }]
}

proc find_next {} {
    set start [pos]
    while {![end]} {
        if { [uint8] != 255 } continue
        if { [uint8] > 0 } break
    }
    set result [expr [pos] - $start - 2]
    goto $start
    return $result
}

proc marker_app0 {} {
    set len [uint16 "Length"]
    set identifier [cstr "utf8" "Identifier"]
    set thumb_size 0
    if {$identifier == "JFIF"} {
        uint8 "Version (major)"
        uint8 "Version (minor)"
        uint8 "Density Unit"
        uint16 "Width Density"
        uint16 "Height Density"
        set tx [uint8 "Width Thumbnail"]
        set ty [uint8 "Height Thumbnail"]
        set thumb_size [expr $tx * $ty * 3]
        if {$thumb_size > 0} {
            bytes $thumb_size "Thumbnail Data"
        }
    } elseif {$identifier == "JFXX"} {
        set tt [uint8 "Thumbnail Type"]
        if {$len > 3} {
            set thumb_size [expr $len - 3]
            bytes $thumb_size "Thumbnail Data"
        }
    }
    sectionvalue [human_size $thumb_size]
}

proc marker_appN {} {
    set len [uint16 "Length"]
    set identifier [cstr "utf8" "Identifier"]
    # subtract three for the length size and the string null terminator
    set data_size [expr $len - [string length $identifier] - 3]
    set human_len [human_size $len]
    sectionvalue "$human_len ($identifier)"
    if {$data_size > 0} {
        if {$identifier == "Exif"} {
            set exif_end [expr [pos] + $data_size]
            # The Exif identifier is "Exif\0"? So there's an extra null-terminator?
            uint8 "Unused"
            Exif
            big_endian
            goto $exif_end
        } elseif {$identifier == "MPF"} {
            set exif_end [expr [pos] + $data_size]
            Exif
            big_endian
            goto $exif_end
        } else {
            bytes $data_size "Data"
        }
    }
}

proc marker_nonapp {} {
    set len [uint16 "Length"]
    if {$len > 2} {
        bytes [expr $len - 2] "Data"
    }
    sectionvalue [human_size $len]
}

proc marker_start_of_scan {} {
    # length of SOS, not JPEG stream length
    set len [uint16 "Length"]
    set component_count [uint8 "Component count"]
    set sos_component_size [expr $component_count * 2]
    if {$sos_component_size > 0} {
        bytes $sos_component_size "Components"
    }
    uint8 "spss"
    uint8 "spse"
    uint8 "sabp"
    set image_data_length [find_next]
    sectionvalue [human_size $image_data_length]
    if {$image_data_length > 0} {
        bytes $image_data_length "Image data"
    }
}

main_guard {
    while {![end]} {
        section "Segment" {
            set app_marker_1 [hex 1 "App marker 1"]
            assert { $app_marker_1 == 0xff } "Unexpected App marker 1"

            set app_marker_2 [hex 1 "App marker 2"]

            sectionname [marker_name $app_marker_2]

            switch $app_marker_2 {
                0xD8 { sectionname "Start of Image"; sectionvalue "" }
                0xD9 { sectionname "End of Image"; sectionvalue "" }
                0xDA { marker_start_of_scan }
                0xE0 { marker_app0 }
                0xE1 { marker_appN }
                0xE2 { marker_appN }
                0xE3 { marker_appN }
                0xE4 { marker_appN }
                0xE5 { marker_appN }
                0xE6 { marker_appN }
                0xE7 { marker_appN }
                0xE8 { marker_appN }
                0xE9 { marker_appN }
                0xEA { marker_appN }
                0xEB { marker_appN }
                0xEC { marker_appN }
                0xED { marker_appN }
                0xEE { marker_appN }
                0xEF { marker_appN }
                default { marker_nonapp }
            }

            if { $app_marker_2 == 0xD9 } break
        }
    }
}
