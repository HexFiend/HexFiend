# OGG encapsulation format
# Format specification can be found at:
# https://tools.ietf.org/html/rfc3533
#
# Copyright (c) 2020 Mattias Wadman
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

little_endian
# OggS
requires 0 "4f 67 67 53"

proc parse_page {} {
    ascii 4 "Sync pattern"
    uint8 "Version"
    set flags [uint8]

    set flag_names [list]
    set flags_continued 0x1
    set flags_first_page 0x2
    set flags_last_page 0x4
    if { $flags & $flags_continued } {
        lappend flag_names Continued
    }
    if { $flags & $flags_first_page } {
        lappend flag_names First
    }
    if { $flags & $flags_last_page } {
        lappend flag_names Last
    }
    entry "Flags" [format "%s (0x%x)" $flag_names $flags] 1 [expr [pos]-1]
    uint64 "Grantule"
    uint32 "Serial number"
    uint32 "Sequence number"
    hex 4 "Checksum"

    set segment_count [uint8 "Segment count"]
    set segment_table [list]
    set segments_size 0
    section  "Segment table" {
        for { set i 0 } { $i < $segment_count } { incr i } {
            set c [uint8 $i]
            lappend segment_table $c
            incr segments_size $c
        }
    }

    section "Segments" {
        set i 0
        foreach s $segment_table {
            if { $s > 0 } {
                entry $i $s $s [pos]
                move $s
            } else {
                entry $i $s
            }
            incr i
        }
    }
}

while { ![end] } {
    section "Ogg page" {
        parse_page
    }
}
