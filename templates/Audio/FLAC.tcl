# FLAC binary template
#
# Specification can be found at:
# https://xiph.org/flac/format.html
# Various example files can be found at:
# https://github.com/xiph/flac/tree/master/test/flac-to-flac-metadata-test-files
#
# Copyright (c) 2019 Mattias Wadman
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

# "fLaC"
requires 0 "66 4C 61 43"
big_endian

proc ascii_maybe_empty { size {name ""} } {
    if { $size > 0 } {
        if { $name != "" } {
            return [ascii $size $name]
        } else {
            return [ascii $size]
        }
    } else {
        if { $name != "" } {
            entry $name ""
        }
        return ""
    }
}

proc bytes_maybe_empty { size {name ""} } {
    if { $size > 0 } {
        if { $name != "" } {
            return [bytes $size $name]
        } else {
            return [bytes $size]
        }
    } else {
        if { $name != "" } {
            entry $name ""
        }
        return ""
    }
}

set block_type_to_string [dict create  \
    0 Streaminfo \
    1 Padding \
    2 Application \
    3 Seektable \
    4 "Vorbis comment" \
    5 Cuesheet \
    6 Picture \
]

proc parse_flac_metdata_block_streaminfo { _len } {
    uint16 "Minimum block size (samples)"
    uint16 "Maximum block size (samples)"
    uint24 "Minimum frame size (bytes)"
    uint24 "Maximum frame size (bytes)"

    set b [uint64]
    set sample_rate [expr ($b >> 44) & (0xfffff)]
    set channels [expr (($b >> 41) & (0x7))+1]
    set bits_per_sample [expr (($b >> 36) & (0x1f))+1]
    set total_samples [expr ($b >> 0) & (0xfffffffff)]
    entry "Sample rate" $sample_rate 3 [expr [pos]-3]
    entry "Channels" $channels 1 [expr [pos]-4]
    entry "Bits per sample" $bits_per_sample 2 [expr [pos]-5]
    entry "Total samples in stream" $total_samples 5 [expr [pos]-8]
    hex 16 "MD5 of unencoded audio"

    return [expr 2+2+3+3+8+16]
}

proc parse_flac_metdata_block_seektable { len } {
    set seekpoint_count [expr $len / 18]
    set seekpoint_len 0
    for { set i 0 } { $i < $seekpoint_count } { incr i } {
        section "Seekpoint" {
            set sample_number [uint64]
            if { $sample_number == 0xffffffffffffffff } {
                set sample_number "Placeholder"
            }
            entry "Sample number" $sample_number 8 [expr [pos]-8]
            uint64 "Offset"
            uint16 "Number of samples"
        }

        incr seekpoint_len 18
    }

    return $seekpoint_len
}

proc parse_flac_metdata_block_vorbis_comment { _len } {
    # vorbis comments uses little endian
    little_endian

    set vendor_length [uint32 "Vendor length"]
    ascii $vendor_length "Vendor string"
    set user_comment_list_length [uint32 "User comment list length"]
    set user_comment_bytes 0
    section "User comments" {
        for { set i 0 } { $i < $user_comment_list_length } { incr i } {
            section $i {
                set len [uint32 "Length"]
                ascii $len "String"
            }
            incr user_comment_bytes [expr 4+$len]
        }
    }

    big_endian

    return [expr 4+$vendor_length+4+$user_comment_bytes]
}

proc parse_flac_metdata_block_cuesheet { _len } {
    ascii 128 "Media catalog number"
    uint64 "Lead-in samples"
    set compact_disc_rev0 [uint8]
    set compact_disc [expr ($compact_disc_rev0 & 0x80) == 0x80]
    entry "Compact disc" $compact_disc 1 [expr [pos]-1]
    bytes 258 "Reserved"
    set track_count [uint8 "Number of tracks"]

    set 0 track_len
    set 0 index_len
    for { set i 0 } { $i < $track_count } { incr i } {
        section "Track" {
            uint64 "Track offset"
            uint8 "Track number"
            ascii 12 "ISRC"
            set track_type_pre_emphasis_rev0 [uint8]
            set track_type [expr ($track_type_pre_emphasis_rev0 & 0x80) == 0x80]
            set pre_emphasis [expr ($track_type_pre_emphasis_rev0 & 0x40) == 0x40]
            entry "Track type" $track_type 1 [expr [pos]-1]
            entry "Pre-emphasis" $pre_emphasis 1 [expr [pos]-1]
            bytes 13 "Reserved"
            set track_index_count [uint8 "Track index count"]

            incr track_len [expr 8+1+12+1+13]

            for { set j 0 } { $j < $track_index_count } { incr j } {
                section "Index" {
                    uint64 "Offset"
                    uint8 "Index number"
                    bytes 3 "Reserved"
                }

                incr index_len [expr 8+1+4]
            }
        }
    }

    return [expr 128+8+1+258+1+$track_len+$index_len]
}

proc parse_flac_metdata_block_picture { _len } {
    uint32 "The picture type"
    set mime_length [uint32 "MIME length"]
    ascii_maybe_empty $mime_length "MIME type"
    set desc_len [uint32 "Description length"]
    ascii_maybe_empty $desc_len "Description"
    uint32 "Width"
    uint32 "Height"
    uint32 "Color depth"
    uint32 "Number of indexed colors"
    set picture_len [uint32 "Picture length"]
    bytes $picture_len "Picture data"

    return [expr 4+4+$mime_length+4+$desc_len+4+4+4+4+4+$picture_len]
}

proc parse_flac_metadata_block {} {
    global block_type_to_string

    set last_block_type [uint8]
    set last_block [expr ($last_block_type & 0x80) >> 7]
    set type [expr $last_block_type & 0x7f]

    set type_name "Unknown block"
    if { [dict exists $block_type_to_string $type] } {
        set type_name [dict get $block_type_to_string $type]
    }

    section $type_name {
        section "Last-block-type" {
            entry "Last block" $last_block 1 [expr [pos]-1]
            entry "Type" $type 1 [expr [pos]-1]
        }
        set len [uint24 "Length"]

        set parsed_len [
                switch $type {
                0 { parse_flac_metdata_block_streaminfo $len }
                3 { parse_flac_metdata_block_seektable $len }
                4 { parse_flac_metdata_block_vorbis_comment $len }
                5 { parse_flac_metdata_block_cuesheet $len }
                6 { parse_flac_metdata_block_picture $len }
                default {
                    bytes_maybe_empty $len "Data"
                    expr $len
                }
            }
        ]

        # make a comment if lengths do not match
        # seems some flac encoders can do this when embedding images
        # largers than 2^24 bytes and writes an invalid block length
        set diff [expr $len-$parsed_len]
        if { $diff != 0 } {
            entry "Block/parsed len differs" $diff
        }
    }

    if { $last_block == 1 } {
        return 0
    }
    return 1
}

proc parse_frame_sync {} {
    set sync [uint16]
    move -2
    set syncok " (correct)"
    if { [expr $sync & 0xfff8] != 0xfff8} {
        set syncok " (invalid)"
    }

    section "First frame" {
        uint16 "Sync $syncok"
    }
}

proc parse_flac {} {
    ascii 4 "Magic"
    while { [parse_flac_metadata_block] } {}
    parse_frame_sync
}

parse_flac
