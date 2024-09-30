# PGS, formally Presentation Graphics Stream, also known as SUP files
# Binary format for Blu-ray Subtitles
#
# .types = ( sup )
#
# Specification can be found at:
# https://patents.google.com/patent/US20090185789/da
# https://blog.thescorpius.com/index.php/2017/07/15/presentation-graphic-stream-sup-files-bluray-subtitle-format/
#
# Copyright (c) 2024 Steven Huang
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

big_endian

# PGS Timestamps are expressed as 90kHz units
proc pgs_timestamp {label} {
    set raw [uint32]
    set seconds [expr $raw / 90000.0]
    set hours [expr int($seconds / (60 * 60))]
    set seconds [expr $seconds - ($hours * 60 * 60)]
    set minutes [expr int($seconds / 60)]
    set seconds [expr $seconds - ($minutes * 60)]
    
    # output as HH:MM:SS.ss
    entry $label [format "%02d:%02d:%05.2f" $hours $minutes $seconds] 4 [expr [pos] - 4]
}

proc pgs_segment_type {} {
    set raw [format "%#02X" [uint8]]
    switch $raw {
        0X14 {set type "PDS"}
        0X15 {set type "ODS"}
        0X16 {set type "PCS"}
        0X17 {set type "WDS"}
        0X80 {set type "END"}
        default {set type $raw}
    }
    entry "Segment Type" $type 1 [expr [pos] - 1]
    return $type
}

proc pds_segment {size} {
    uint8 "Palette ID"
    uint8 "Palette Version Number"
    section -collapsed "Palette Entries" {
        for {set i 2} {$i < $size} {incr i 5} {
            # to avoid wasting a row for "Palette Entry" and the id, we name the section
            # by the id, but we need to do the move/bytes dance so that the section still
            # covers the id byte
            set id [uint8]
            move -1
            section "Palette ID $id" {
                bytes 1
                uint8 "Luminance (Y)"
                uint8 "Color Difference Red (Cr)"
                uint8 "Color Difference Blue (Cb)"
                uint8 "Transparency"
            }
        }
    }
}

proc ods_segment {size} {
    uint16 "Object ID"
    uint8 "Object Version Number"
    set last_in_sequence_flag [uint8]
    if {($last_in_sequence_flag & 0x80) > 0} {
        # first in sequence
        if {($last_in_sequence_flag & 0x40) > 0} {
            entry "Last in Sequence Flag" "First and last in Sequence" 1 [expr [pos] - 1]
        } else {
            entry "Last in Sequence Flag" "First in Sequence" 1 [expr [pos] - 1]
        }
        uint24 "Object Data Length"
        uint16 "Width"
        uint16 "Height"
        bytes [expr $size - 11] "Object Data"
    } else {
        if {($last_in_sequence_flag & 0x40) > 0} {
            entry "Last in Sequence Flag" "Last in Sequence" 1 [expr [pos] - 1]
        } else {
            entry "Last in Sequence Flag" [format "%02X" $last_in_sequence_flag] 1 [expr [pos] - 1]
        }
        bytes [expr $size - 4] "Object Data"
    }
}

proc pcs_segment {} {
    uint16 "Video Width"
    uint16 "Video Height"
    uint8 "Frame Rate"
    uint16 "Composition Number"
    uint8 "Composition State"
    uint8 "Palette Update Flag"
    uint8 "Palette ID"
    set objects [uint8 "Number of Composition Objects"]
    for {set i 0} {$i < $objects} {incr i} {
        section -collapsed "Composition Object" {
            uint16 "ID"
            uint8 "Window ID"
            set cropped [uint8 "Cropped Flag"]
            uint16 "Horizontal Position"
            uint16 "Vertical Position"
            if {$cropped} {
                uint16 "Cropping Horizontal Position"
                uint16 "Cropping Vertical Position"
                uint16 "Cropping Width"
                uint16 "Cropping Height"
            }
        }
    }
}

proc wds_segment {} {
    set windows [uint8 "Number of Windows"]
    for {set i 0} {$i < $windows} {incr i} {
        section -collapsed "Window" {
            uint8 "ID"
            uint16 "Horizontal Position"
            uint16 "Vertical Position"
            uint16 "Width"
            uint16 "Height"
        }
    }
}

if [catch {
    while {![end]} {
        section "Segment" {
            requires [pos] "50 47"
            ascii 2 "Magic Number"
            pgs_timestamp "Presentation Timestamp"
            pgs_timestamp "Decoding Timestamp"
            set segment_type [pgs_segment_type]
            set segment_size [uint16 "Segment Size"]
            switch $segment_type {
                "PDS" {pds_segment $segment_size}
                "ODS" {ods_segment $segment_size}
                "PCS" {pcs_segment}
                "WDS" {wds_segment}
                default {move $segment_size}
            }
        }
    }
}] {
    puts $errorInfo
}
