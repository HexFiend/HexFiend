# ID3v2 binary template
#
# Specification can be found at:
# http://id3.org/Developer%20Information
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
# ID3v2 HexFiend template (v2.2 / v2.3 / v2.4)
# With footer support, unsynchronisation handling, frames section,
# and flag/bitfield helpers.

requires 0 "49 44 33" ;# "ID3"

big_endian

# ---------- global state ----------

set ::id3v2_unsync_tag      0   ;# tag-level unsync (header flag)
set ::id3v2_footer_flag     0   ;# v2.4 footer present
set ::id3v2_unsync_current  0   ;# active unsync for current frame's text

# ---------- helpers ----------

proc syncsafe32 {{name ""}} {
    set n [uint32]
    set v [expr \
        (($n & 0x7f000000) >> 3) | \
        (($n & 0x007f0000) >> 2) | \
        (($n & 0x00007f00) >> 1) | \
        (($n & 0x0000007f) >> 0) \
    ]
    if { $name ne "" } {
        entry $name [format "%d (%d)" $v $n] 4 [expr {[pos] - 4}]
    }
    return $v
}

proc u8_dict {name dict {default ""}} {
    set n [uint8]
    set v $default
    if { [dict exists $dict $n] } {
        set v [dict get $dict $n]
    }
    entry $name [format "%s (%d)" $v $n] 1 [expr {[pos] - 1}]
    return $n
}

proc ascii_maybe {size {name ""}} {
    if { $size <= 0 } {
        if { $name ne "" } { entry $name "" }
        return ""
    }
    if { $name ne "" } {
        return [ascii $size $name]
    }
    return [ascii $size]
}

proc bytes_maybe {size {name ""}} {
    if { $size <= 0 } {
        if { $name ne "" } { entry $name "" }
        return ""
    }
    if { $name ne "" } {
        return [bytes $size $name]
    }
    return [bytes $size]
}

# scan up to max bytes to a 1-byte null terminator
proc len_to_null8 {max} {
    set i 0
    while { $i < $max } {
        set b [uint8]
        incr i
        if { $b == 0 } { break }
    }
    return $i
}

# scan up to max bytes to a 2-byte null terminator (UTF-16)
proc len_to_null16 {max} {
    set i 0
    while { $i < $max } {
        set w [uint16]
        incr i 2
        if { $w == 0 } { break }
    }
    return $i
}

proc trim_suffix {suffix s} {
    set len [string length $suffix]
    while { [string match "*$suffix" $s] } {
        set s [string range $s 0 "end-$len"]
    }
    return $s
}

proc enc_iso8859_1 {bytes} {
    return [encoding convertfrom iso8859-1 [string trimright $bytes "\x00"]]
}

proc enc_utf8 {bytes} {
    return [encoding convertfrom utf-8 [string trimright $bytes "\x00"]]
}

proc enc_utf16 {bytes} {
    if { [string match "\xff\xfe*" $bytes] } {
        set bytes [string range $bytes 2 end]
        binary scan [trim_suffix "\x00\x00" $bytes] s* cps
    } elseif { [string match "\xfe\xff*" $bytes] } {
        set bytes [string range $bytes 2 end]
        binary scan [trim_suffix "\x00\x00" $bytes] S* cps
    } else {
        binary scan [trim_suffix "\x00\x00" $bytes] s* cps
    }
    return [format [string repeat %c [llength $cps]] {*}$cps]
}

proc enc_utf16be {bytes} {
    if { [string match "\xfe\xff*" $bytes] } {
        set bytes [string range $bytes 2 end]
    }
    binary scan [trim_suffix "\x00\x00" $bytes] S* cps
    return [format [string repeat %c [llength $cps]] {*}$cps]
}

set ::id3v2_encoding_names [dict create \
    0 "ISO-8859-1" \
    1 "UTF-16" \
    2 "UTF-16BE" \
    3 "UTF-8" \
]

set ::id3v2_encoding_null_len [dict create \
    0 1 \
    1 2 \
    2 2 \
    3 1 \
]

set ::id3v2_encoding_fns [dict create \
    0 enc_iso8859_1 \
    1 enc_utf16 \
    2 enc_utf16be \
    3 enc_utf8 \
]

# unsynchronisation: remove 0x00 after 0xFF
proc id3v2_unsync {raw} {
    set out ""
    set prev ""
    foreach c [split $raw ""] {
        if { $prev eq "\xFF" && $c eq "\x00" } {
            # stuffed 00, skip
        } else {
            append out $c
        }
        set prev $c
    }
    return $out
}

# generic bitfield/flags entry helper
# specs: {mask1 label1 mask2 label2 ...}
proc flags_entry {name value size specs pos} {
    set names {}
    foreach {mask label} $specs {
        if { $value & $mask } {
            lappend names $label
        }
    }
    entry $name [format "%s (%d)" $names $value] $size $pos
}

# decode text of known byte length + optional terminator (unsync-aware)
proc id3v2_text {enc size null_len {name ""}} {
    set start [pos]
    set raw   [bytes_maybe $size]

    if { $::id3v2_unsync_current } {
        set raw [id3v2_unsync $raw]
    }

    set enc_fn ""
    if { [dict exists $::id3v2_encoding_fns $enc] } {
        set enc_fn [dict get $::id3v2_encoding_fns $enc]
    }

    if { $enc_fn eq "" } {
        set val [encoding convertfrom iso8859-1 $raw]
    } else {
        set val [$enc_fn $raw]
    }

    # consume null terminator bytes from stream (already accounted for in null_len)
    if { $null_len > 0 } {
        bytes_maybe $null_len
    }

    if { $name ne "" } {
        entry $name $val [expr {$size + $null_len}] $start
    }
    return $val
}

# read a null-terminated text field within max bytes; optionally return full length
proc id3v2_text_null {enc max {name ""} {len_var ""}} {
    upvar $len_var out_len

    set null_len 1
    if { [dict exists $::id3v2_encoding_null_len $enc] } {
        set null_len [dict get $::id3v2_encoding_null_len $enc]
    }

    if { $null_len == 1 } {
        set bytes_len [len_to_null8 $max]
    } else {
        set bytes_len [len_to_null16 $max]
    }

    if { $bytes_len < $null_len } {
        set bytes_len 0
        set null_len  0
    }

    if { $len_var ne "" } {
        set out_len $bytes_len
    }

    set text_len [expr {$bytes_len - $null_len}]
    if { $text_len < 0 } { set text_len 0 }

    return [id3v2_text $enc $text_len $null_len $name]
}

# ---------- frame name lookup (modern IDs only, compact) ----------

set id3v2_frame_names [dict create \
    AENC "Audio encryption" \
    APIC "Attached picture" \
    ASPI "Audio seek point index" \
    COMM "Comments" \
    COMR "Commercial frame" \
    ENCR "Encryption method registration" \
    EQU2 "Equalisation (2)" \
    EQUA "Equalization" \
    ETCO "Event timing codes" \
    GEOB "General encapsulated object" \
    GRID "Group identification registration" \
    IPLS "Involved people list" \
    LINK "Linked information" \
    MCDI "Music CD identifier" \
    MLLT "MPEG location lookup table" \
    OWNE "Ownership frame" \
    PCNT "Play counter" \
    POPM "Popularimeter" \
    POSS "Position synchronisation frame" \
    PRIV "Private frame" \
    RBUF "Recommended buffer size" \
    RVA2 "Relative volume adjustment (2)" \
    RVAD "Relative volume adjustment" \
    RVRB "Reverb" \
    SEEK "Seek frame" \
    SIGN "Signature frame" \
    SYLT "Synchronised lyric/text" \
    SYLT "Synchronized lyric/text" \
    SYTC "Synchronised tempo codes" \
    SYTC "Synchronized tempo codes" \
    TALB "Album/Movie/Show title" \
    TBPM "BPM (beats per minute)" \
    TCOM "Composer" \
    TCON "Content type" \
    TCOP "Copyright message" \
    TDAT "Date" \
    TDEN "Encoding time" \
    TDLY "Playlist delay" \
    TDOR "Original release time" \
    TDRC "Recording time" \
    TDRL "Release time" \
    TDTG "Tagging time" \
    TENC "Encoded by" \
    TEXT "Lyricist/Text writer" \
    TFLT "File type" \
    TIME "Time" \
    TIPL "Involved people list" \
    TIT1 "Content group description" \
    TIT2 "Title/songname/content description" \
    TIT3 "Subtitle/Description refinement" \
    TKEY "Initial key" \
    TLAN "Language(s)" \
    TLEN "Length" \
    TMCL "Musician credits list" \
    TMED "Media type" \
    TMOO "Mood" \
    TOAL "Original album/movie/show title" \
    TOFN "Original filename" \
    TOLY "Original lyricist(s)/text writer(s)" \
    TOPE "Original artist(s)/performer(s)" \
    TORY "Original release year" \
    TOWN "File owner/licensee" \
    TPE1 "Lead performer(s)/Soloist(s)" \
    TPE2 "Band/orchestra/accompaniment" \
    TPE3 "Conductor/performer refinement" \
    TPE4 "Interpreted, remixed, or otherwise modified by" \
    TPOS "Part of a set" \
    TPRO "Produced notice" \
    TPUB "Publisher" \
    TRCK "Track number/Position in set" \
    TRDA "Recording dates" \
    TRSN "Internet radio station name" \
    TRSO "Internet radio station owner" \
    TSIZ "Size" \
    TSOA "Album sort order" \
    TSOP "Performer sort order" \
    TSOT "Title sort order" \
    TSRC "ISRC (international standard recording code)" \
    TSSE "Software/Hardware and settings used for encoding" \
    TSST "Set subtitle" \
    TXXX "User defined text information frame" \
    TYER "Year" \
    UFID "Unique file identifier" \
    USER "Terms of use" \
    USLT "Unsychronized lyric/text transcription" \
    USLT "Unsynchronised lyric/text transcription" \
    WCOM "Commercial information" \
    WCOP "Copyright/Legal information" \
    WOAF "Official audio file webpage" \
    WOAR "Official artist/performer webpage" \
    WOAS "Official audio source webpage" \
    WORS "Official Internet radio station homepage" \
    WORS "Official internet radio station homepage" \
    WPAY "Payment" \
    WPUB "Publishers official webpage" \
    WXXX "User defined URL link frame" \
    BUF "Recommended buffer size" \
    CNT "Play counter" \
    COM "Comments" \
    CRA "Audio encryption" \
    CRM "Encrypted meta frame" \
    ETC "Event timing codes" \
    EQU "Equalization" \
    GEO "General encapsulated object" \
    IPL "Involved people list" \
    LNK "Linked information" \
    MCI "Music CD Identifier" \
    MLL "MPEG location lookup table" \
    PIC "Attached picture" \
    POP "Popularimeter" \
    REV "Reverb" \
    RVA "Relative volume adjustment" \
    SLT "Synchronized lyric/text" \
    STC "Synced tempo codes" \
    TAL "Album/Movie/Show title" \
    TBP "BPM (Beats Per Minute)" \
    TCM "Composer" \
    TCO "Content type" \
    TCR "Copyright message" \
    TDA "Date" \
    TDY "Playlist delay" \
    TEN "Encoded by" \
    TFT "File type" \
    TIM "Time" \
    TKE "Initial key" \
    TLA "Language(s)" \
    TLE "Length" \
    TMT "Media type" \
    TOA "Original artist(s)/performer(s)" \
    TOF "Original filename" \
    TOL "Original Lyricist(s)/text writer(s)" \
    TOR "Original release year" \
    TOT "Original album/Movie/Show title" \
    TP1 "Lead artist(s)/Lead performer(s)/Soloist(s)/Performing group" \
    TP2 "Band/Orchestra/Accompaniment" \
    TP3 "Conductor/Performer refinement" \
    TP4 "Interpreted, remixed, or otherwise modified by" \
    TPA "Part of a set" \
    TPB "Publisher" \
    TRC "ISRC (International Standard Recording Code)" \
    TRD "Recording dates" \
    TRK "Track number/Position in set" \
    TSI "Size" \
    TSS "Software/hardware and settings used for encoding" \
    TT1 "Content group description" \
    TT2 "Title/Songname/Content description" \
    TT3 "Subtitle/Description refinement" \
    TXT "Lyricist/text writer" \
    TXX "User defined text information frame" \
    TYE "Year" \
    UFI "Unique file identifier" \
    ULT "Unsychronized lyric/text transcription" \
    WAF "Official audio file webpage" \
    WAR "Official artist/performer webpage" \
    WAS "Official audio source webpage" \
    WCM "Commercial information" \
    WCP "Copyright/Legal information" \
    WPB "Publishers official webpage" \
    WXX "User defined URL link frame" \
]

# ---------- frame parsers ----------

# PIC (ID3v2.2)
proc frame_PIC {data_size} {
    set enc [u8_dict "Text encoding" $::id3v2_encoding_names "Invalid"]
    ascii 3 "Image format"
    uint8 "Picture type"
    set remaining [expr {$data_size - 1 - 3 - 1}]
    if { $remaining < 0 } { set remaining 0 }
    id3v2_text_null $enc $remaining "Description" desc_len
    set used  $desc_len
    set left  [expr {$data_size - 1 - 3 - 1 - $used}]
    if { $left < 0 } { set left 0 }
    bytes_maybe $left "Data"
}

# APIC (ID3v2.3/2.4)
proc frame_APIC {data_size} {
    set enc [u8_dict "Text encoding" $::id3v2_encoding_names "Invalid"]
    set remaining $data_size

    # MIME: ISO-8859-1, null-terminated
    set start [pos]
    set mime_len [len_to_null8 $remaining]
    move $start
    ascii_maybe [expr {$mime_len - 1}] "MIME type"
    uint8 ;# null
    set remaining [expr {$remaining - $mime_len}]

    uint8 "Picture type"
    incr remaining -1

    if { $remaining < 0 } { set remaining 0 }
    id3v2_text_null $enc $remaining "Description" desc_len
    set remaining [expr {$remaining - $desc_len}]
    if { $remaining < 0 } { set remaining 0 }
    bytes_maybe $remaining "Data"
}

# COMM / USLT share structure
proc frame_COMM_like {data_size} {
    set enc [u8_dict "Text encoding" $::id3v2_encoding_names "Invalid"]
    ascii 3 "Language"
    set remaining [expr {$data_size - 1 - 3}]
    if { $remaining < 0 } { set remaining 0 }

    id3v2_text_null $enc $remaining "Description" desc_len
    set remaining [expr {$remaining - $desc_len}]
    if { $remaining < 0 } { set remaining 0 }

    id3v2_text $enc $remaining 0 "Text"
}

proc frame_COMM {data_size} { frame_COMM_like $data_size }
proc frame_USLT {data_size} { frame_COMM_like $data_size }

# "T***" (except TXXX)
proc frame_T000 {data_size} {
    set enc [u8_dict "Text encoding" $::id3v2_encoding_names "Invalid"]
    id3v2_text $enc [expr {$data_size - 1}] 0 "Text"
}

# TXXX
proc frame_TXXX {data_size} {
    set enc [u8_dict "Text encoding" $::id3v2_encoding_names "Invalid"]
    set remaining [expr {$data_size - 1}]
    if { $remaining < 0 } { set remaining 0 }

    id3v2_text_null $enc $remaining "Description" desc_len
    set remaining [expr {$remaining - $desc_len}]
    if { $remaining < 0 } { set remaining 0 }

    id3v2_text $enc $remaining 0 "Value"
}

# "W***" (except WXXX) – URL, ISO-8859-1
proc frame_W000 {data_size} {
    ascii_maybe $data_size "URL"
}

# WXXX – description (encoded) + URL (ISO-8859-1)
proc frame_WXXX {data_size} {
    set enc [u8_dict "Text encoding" $::id3v2_encoding_names "Invalid"]
    set remaining [expr {$data_size - 1}]
    if { $remaining < 0 } { set remaining 0 }

    id3v2_text_null $enc $remaining "Description" desc_len
    set remaining [expr {$remaining - $desc_len}]
    if { $remaining < 0 } { set remaining 0 }

    ascii_maybe $remaining "URL"
}

# PRIV – owner identifier (ISO-8859-1) + data
proc frame_PRIV {data_size} {
    set start [pos]
    set len [len_to_null8 $data_size]
    move $start
    ascii_maybe [expr {$len - 1}] "Owner identifier"
    uint8 ;# null
    set left [expr {$data_size - $len}]
    if { $left < 0 } { set left 0 }
    bytes_maybe $left "Data"
}

# UFID – same physical layout as PRIV
proc frame_UFID {data_size} {
    frame_PRIV $data_size
}

# ---------- frame parsing ----------

proc parse_frame {version} {
    # look ahead ID
    switch $version {
        2 {
            set id [ascii 3]
            move -3
        }
        3 -
        4 {
            set id [ascii 4]
            move -4
        }
    }

    set name ""
    if { [dict exists $::id3v2_frame_names $id] } {
        set name [dict get $::id3v2_frame_names $id]
    }

    section $id {
        sectionvalue $name

        set header_size 0
        set frame_unsync 0

        switch $version {
            2 {
                set id [ascii 3 "ID"]
                set data_size [uint24 "Size"]
                set header_size 6
            }
            3 {
                set id [ascii 4 "ID"]
                set data_size [uint32 "Size"]
                uint16 "Flags"
                set header_size 10
            }
            4 {
                set id [ascii 4 "ID"]
                set data_size [syncsafe32 "Size"]
                set flags_start [pos]
                set flags_raw [uint16 "Flags raw"]
                set header_size 10

                # v2.4 frame flag bits
                set frame_flag_specs {
                    0x8000 tag_alter_discard
                    0x4000 file_alter_discard
                    0x2000 read_only
                    0x0040 grouping
                    0x0008 compressed
                    0x0004 encrypted
                    0x0002 unsync
                    0x0001 datalen
                }
                flags_entry "Flags" $flags_raw 2 $frame_flag_specs [expr {$flags_start - 2}]

                if { $flags_raw & 0x0001 } {
                    # data length indicator present, counted in data_size
                    syncsafe32 "Data length indicator"
                    incr data_size -4
                    incr header_size 4
                }
                if { $flags_raw & 0x0002 } {
                    set frame_unsync 1
                }
            }
        }

        # decide if unsync should be applied to this frame's text
        set ::id3v2_unsync_current 0
        if { $::id3v2_unsync_tag } {
            set ::id3v2_unsync_current 1
        }
        if { $version == 4 && $frame_unsync } {
            set ::id3v2_unsync_current 1
        }

        switch -glob $id {
            PIC  { frame_PIC  $data_size }
            APIC { frame_APIC $data_size }
            COMM { frame_COMM $data_size }
            USLT { frame_USLT $data_size }
            TXXX { frame_TXXX $data_size }
            T*   { frame_T000 $data_size }
            WXXX { frame_WXXX $data_size }
            W*   { frame_W000 $data_size }
            PRIV { frame_PRIV $data_size }
            UFID { frame_UFID $data_size }
            default {
                if { $data_size > 0 } {
                    bytes $data_size "Data"
                }
            }
        }
    }

    return [expr {$data_size + $header_size}]
}

proc parse_frames {version size} {
    set left $size
    while { $left > 0 } {
        if { $left <= 0 } { break }
        set b [uint8]
        move -1
        if { $b == 0 } {
            bytes $left "Padding"
            break
        }
        incr left -[parse_frame $version]
    }
}

# ---------- footer parsing (ID3v2.4) ----------

proc parse_footer {} {
    section "Footer" {
        ascii 3 "Magic"   ;# usually "3DI"
        uint8 "Version"
        uint8 "Revision"

        set flags_start [pos]
        set flags [uint8 "Flags raw"]
        set header_flag_specs {
            0x80 unsync
            0x40 ext_header
            0x20 experimental
            0x10 footer
        }
        flags_entry "Flags" $flags 1 $header_flag_specs [expr {$flags_start - 1}]

        syncsafe32 "Tag size"
    }
}

# ---------- top-level ID3v2 parser ----------

proc parse_id3v2 {} {
    ascii 3 "Magic"
    set version [uint8 "Version"]
    uint8 "Revision"

    set flags_start [pos]
    set flags [uint8 "Flags raw"]

    set header_flag_specs {
        0x80 unsync
        0x40 ext_header
        0x20 experimental
    }
    if { $version == 4 } {
        lappend header_flag_specs 0x10 footer
    }
    flags_entry "Flags" $flags 1 $header_flag_specs [expr {$flags_start - 1}]

    set ::id3v2_unsync_tag  [expr {($flags & 0x80) != 0}]
    set ::id3v2_footer_flag [expr {$version == 4 && ($flags & 0x10)}]

    set tag_size [syncsafe32 "Tag size"] ;# bytes after header

    set ext_total 0
    if { $flags & 0x40 } {
        section "Extended header" {
            switch $version {
                3 {
                    set ext_data_size [uint32 "Size"]
                    bytes $ext_data_size "Data"
                    set ext_total [expr {4 + $ext_data_size}]
                }
                4 {
                    set ext_size [syncsafe32 "Size"]
                    bytes [expr {$ext_size - 4}] "Data"
                    set ext_total $ext_size
                }
            }
        }
    }

    switch $version {
        2 -
        3 -
        4 {
            section "Frames" {
                parse_frames $version [expr {$tag_size - $ext_total}]
            }

            if { $version == 4 && $::id3v2_footer_flag } {
                parse_footer
            }
        }
        default {
            bytes $tag_size "Data"
        }
    }
}

parse_id3v2