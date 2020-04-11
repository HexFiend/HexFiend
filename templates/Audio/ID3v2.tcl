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

# TODO: footer?
# TODO: unsynchronise flag? messy todo
# TODO: redo sections? "Frames" section etc?
# TODO: flags, bit fields helper?

proc syncsafeint32 { {name ""} } {
    set n [uint32]
    # syncsafe integer is a number encoded
    # with 8th bit in each byte set to zero
    # 0aaaaaaa0bbbbbbb0ccccccc0ddddddd ->
    # 0000aaaaaaabbbbbbbcccccccddddddd
    set v [expr \
        (($n & 0x7f000000) >> 3) | \
        (($n & 0x007f0000) >> 2) | \
        (($n & 0x00007f00) >> 1) | \
        (($n & 0x0000007f) >> 0) \
    ]
    if { $name != "" } {
	    entry $name [format "%d (%d)" $v $n] 4 [expr [pos]-4]
    }
    return $v
}

proc uint8_dict { name dict {default ""} } {
    set n [uint8]
    set v $default
    if { [dict exists $dict $n] } {
        set v [dict get $dict $n]
    }
    entry $name [format "%s (%d)" $v $n] 1 [expr [pos]-1]
    return $n
}

proc len_to_uint8 { v } {
    set i 0
    while { ![end] } {
        incr i
        if { [uint8] == $v } {
            break
        }
    }
    move [expr -$i]
    return [expr $i]
}

proc len_to_uint16 { v } {
    set i 0
    while { ![end] } {
        incr i 2
        if { [uint16] == $v } {
            break
        }
    }
    move [expr -$i]
    return [expr $i]
}

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
            entry $name
        }
        return ""
    }
}

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

# $00   ISO-8859-1 [ISO-8859-1]. Terminated with $00.
# $01   UTF-16 [UTF-16] encoded Unicode [UNICODE] with BOM. All
#     strings in the same frame SHALL have the same byteorder.
#     Terminated with $00 00.
# $02   UTF-16BE [UTF-16] encoded Unicode [UNICODE] without BOM.
#     Terminated with $00 00.
# $03   UTF-8 [UTF-8] encoded Unicode [UNICODE]. Terminated with $00.
set id3v2_encoding_names [dict create \
    0 "ISO-8859-1" \
    1 "UTF-16" \
    2 "UTF-16BE" \
    3 "UTF-8" \
]

set id3v2_encoding_null_lens [dict create \
    0 1 \
    1 2 \
    2 2 \
    3 1 \
]

proc encoding_iso8859_1 { bytes } {
    return [encoding convertfrom iso8859-1 [string trimright $bytes "\x00"]]
}

proc encoding_utf8 { bytes } {
    return [encoding convertfrom utf-8 [string trimright $bytes "\x00"]]
}

proc trim_suffix { suffix s } {
    set len [string length $suffix]
    while { [string match "*$suffix" $s] } {
        set s [string range $s 0 "end-$len"]
    }
    return $s
}

# TODO: some better way of doing this?
proc encoding_utf16 { bytes } {
    # strip BOM
    if { [string match "\xff\xfe*" $bytes] } {
        set bytes [string range $bytes 2 end]
    }
    # s* scan 16bit little endian
    binary scan [trim_suffix "\x00\x00" $bytes] s* codepoints
    return [format [string repeat %c [llength $codepoints]] {*}$codepoints]
}

proc encoding_utf16be { bytes } {
    # strip BOM
    if { [string match "\xfe\xff*" $bytes] } {
        set bytes [string range $bytes 2 end]
    }
    # S* scan 16bit big endian
    binary scan [trim_suffix "\x00\x00" $bytes] S* codepoints
    return [format [string repeat %c [llength $codepoints]] {*}$codepoints]
}

set id3v2_encoding_fns [dict create \
    0 encoding_iso8859_1 \
    1 encoding_utf16 \
    2 encoding_utf16be \
    3 encoding_utf8 \
]

proc id3v2_text { enc size null_len {name ""} } {
    global id3v2_encoding_fns

    if { ![dict exists $id3v2_encoding_fns $enc] } {
        # there seems to be id3v2 tags with invalid encoding, fallback to ascii if so
        ascii [expr $size+$null_len] $name
        return
    }
    set encodeing_fn [dict get $id3v2_encoding_fns $enc]

    set v [$encodeing_fn [bytes_maybe_empty $size]]
    # dummy read null
    if { $null_len > 0 } {
        bytes $null_len
    }
    if { $name != "" } {
        set entry_size [expr $size+$null_len]
        if { $entry_size > 0 } {
            entry $name $v [expr $size+$null_len] [expr [pos]-$size-$null_len]
        } else {
            entry $name ""
        }
    }

    return $v
}

proc id3v2_text_null { enc {name ""} {bytes_len_name ""} } {
    global id3v2_encoding_null_lens
    upvar $bytes_len_name bytes_len

    # there seems to be id3v2 tags with invalid encoding, fallback to ascii null len
    set null_len 1
    if { [dict exists $id3v2_encoding_null_lens $enc] } {
        set null_len [dict get $id3v2_encoding_null_lens $enc]
    }

    if { $null_len == 1} {
        set bytes_len [len_to_uint8 0]
    } else {
        set bytes_len [len_to_uint16 0]
    }
    set text_len [expr $bytes_len-$null_len]

    set v [id3v2_text $enc $text_len $null_len $name]

    return $v
}

# Attached picture   "PIC"
# Frame size         $xx xx xx
# Text encoding      $xx
# Image format       $xx xx xx
# Picture type       $xx
# Description        <textstring> $00 (00)
# Picture data       <binary data>
proc frame_PIC { size } {
    global id3v2_encoding_names
    set enc [uint8_dict "Text encoding" $id3v2_encoding_names "Invalid"]
    # 0 is iso-8869-1
    ascii 3 "Image format"
    uint8 "Picture type"
    id3v2_text_null $enc "Description" desc_len
    bytes_maybe_empty [expr $size-1-3-1-$desc_len] "Data"
}

# <Header for 'Attached picture', ID: "APIC">
# Text encoding      $xx
# MIME type          <text string> $00
# Picture type       $xx
# Description        <text string according to encoding> $00 (00)
# Picture data       <binary data>
proc frame_APIC { size } {
    global id3v2_encoding_names
    set enc [uint8_dict "Text encoding" $id3v2_encoding_names "Invalid"]
    # 0 is iso-8869-1
    id3v2_text_null 0 "MIME Type" mime_len
    uint8 "Picture type"
    id3v2_text_null $enc "Description" desc_len
    bytes_maybe_empty [expr $size-1-$mime_len-1-$desc_len] "Data"
}

# Unsynced lyrics/text "ULT"
# Frame size           $xx xx xx
# Text encoding        $xx
# Language             $xx xx xx
# Content descriptor   <textstring> $00 (00)
# Lyrics/text          <textstring>
proc frame_ULT { size } { frame_COMM $size }

# <Header for 'Unsynchronised lyrics/text transcription', ID: "USLT">
# Text encoding        $xx
# Language             $xx xx xx
# Content descriptor   <text string according to encoding> $00 (00)
# Lyrics/text          <full text string according to encoding>
proc frame_USLT { size } { frame_COMM $size }

# Comment                   "COM"
# Frame size                $xx xx xx
# Text encoding             $xx
# Language                  $xx xx xx
# Short content description <textstring> $00 (00)
# The actual text           <textstring>
proc frame_COM { size } { frame_COMM $size }

# <Header for 'Comment', ID: "COMM">
# Text encoding          $xx
# Language               $xx xx xx
# Short content descrip. <text string according to encoding> $00 (00)
# The actual text        <full text string according to encoding>
proc frame_COMM { size } {
    global id3v2_encoding_names
    set enc [uint8_dict "Text encoding" $id3v2_encoding_names "Invalid"]
    ascii 3 "Language"
    id3v2_text_null $enc "Description" desc_len
    id3v2_text $enc [expr $size-1-3-$desc_len] 0 "Text"
}

# Text information identifier  "T00" - "TZZ" , excluding "TXX",
#                             described in 4.2.2.
# Frame size                   $xx xx xx
# Text encoding                $xx
# Information                  <textstring>

# <Header for 'Text information frame', ID: "T000" - "TZZZ",
# excluding "TXXX" described in 4.2.6.>
# Text encoding                $xx
# Information                  <text string(s) according to encoding>
proc frame_T000 { size } {
    global id3v2_encoding_names
    set enc [uint8_dict "Text encoding" $id3v2_encoding_names "Invalid"]
    id3v2_text $enc [expr $size-1] 0 "Text"
}

# User defined...   "TXX"
# Frame size        $xx xx xx
# Text encoding     $xx
# Description       <textstring> $00 (00)
# Value             <textstring>

# <Header for 'User defined text information frame', ID: "TXXX">
# Text encoding     $xx
# Description       <text string according to encoding> $00 (00)
# Value             <text string according to encoding>
proc frame_TXXX { size } {
    global id3v2_encoding_names
    set enc [uint8_dict "Text encoding" $id3v2_encoding_names "Invalid"]
    id3v2_text_null $enc "Description" desc_len
    id3v2_text $enc [expr $size-1-$desc_len] 0 "Value"
}

# URL link frame   "W00" - "WZZ" , excluding "WXX"
#                                 (described in 4.3.2.)
# Frame size       $xx xx xx
# URL              <textstring>

# <Header for 'URL link frame', ID: "W000" - "WZZZ", excluding "WXXX"
# described in 4.3.2.>
# URL              <text string>
proc frame_W000 { size } {
    ascii_maybe_empty $size "URL"
}

# <Header for 'User defined URL link frame', ID: "WXXX">
# Text encoding     $xx
# Description       <text string according to encoding> $00 (00)
# URL               <text string>
proc frame_WXXX { size } {
    global id3v2_encoding_names
    set enc [uint8_dict "Text encoding" $id3v2_encoding_names "Invalid"]
    id3v2_text_null $enc "Description" desc_len
    id3v2_text $enc [expr $size-1-$desc_len] 0 "URL"
}

# Unique file identifier  "UFI"
# Frame size              $xx xx xx
# Owner identifier        <textstring> $00
# Identifier              <up to 64 bytes binary data>
proc frame_UFI { size } { frame_PRIV $data_size }

# <Header for 'Private frame', ID: "PRIV">
# Owner identifier      <text string> $00
#     The private data      <binary data>
proc frame_PRIV { size } {
    # 0 enc is iso-8859-1
    id3v2_text_null 0 "Owner identifier" owner_id_len
    bytes_maybe_empty [expr $size-$owner_id_len] "Data"
}

proc parse_frame { version } {
    global id3v2_frame_names

    # poke ahead to get id for section
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
    if { [dict exists $id3v2_frame_names $id] } {
        set name [dict get $id3v2_frame_names $id]
    }

    section $id {
        sectionvalue $name

        switch $version {
            2 {
                # Frame ID   "XXX"
                # Frame size $xx xx xx
                set id [ascii 3 "ID"]
                set data_size [uint24 "Size"]
                set size [expr $data_size+6]
            }
            3 {
                # Frame ID   $xx xx xx xx  (four characters)
                # Size       $xx xx xx xx
                # Flags      $xx xx
                set id [ascii 4 "ID"]
                set data_size [uint32 "Size"]
                set flags [uint16 "Flags"]
                set size [expr $data_size+10]
            }
            4 {
                # Frame ID      $xx xx xx xx  (four characters)
                # Size      4 * %0xxxxxxx  (synchsafe integer)
                # Flags         $xx xx
                set id [ascii 4 "ID"]
                set data_size [syncsafeint32 "Size"]
                set flags [uint16]
                set header_len 10

                set flags_unsync 0x2
                set flags_data_len 0x1
                set flags_names []
                if { $flags & $flags_data_len } {
                    lappend flags_names "datalen"
                    syncsafeint32 "Data length indicator"
                    incr data_size -4
                    incr header_len 4
                }
                if { $flags & $flags_unsync } {
                    lappend flags_names "unsync"
                }
                entry "Flags" [format "%s (%d)" $flags_names $flags] 2 [expr [pos]-2]

                set size [expr $data_size+$header_len]
            }
        }

        switch -glob $id {
            TXX -
            TXXX { frame_TXXX $data_size }
            T* { frame_T000 $data_size }
            WXX -
            WXXX { frame_WXXX $data_size }
            W* { frame_W000 $data_size }
            default {
                set parse_fn "frame_$id"
                if { [info procs $parse_fn] != "" } {
                    $parse_fn $data_size
                } elseif { $data_size > 0 } {
                    bytes $data_size "Data"
                }
            }
        }
    }

    return $size
}

proc parse_frames { version size } {
	for { set left $size } { $left > 0 } {} {
        set padding [uint8]
        move -1
        if { $padding == 0 } {
            bytes $left "Padding"
            break
        }

		incr left [expr -[parse_frame $version]]
	}
}

# ID3v2/file identifier      "ID3"
# ID3v2 version              $04 00
# ID3v2 flags                %abcd0000
# ID3v2 size             4 * %0xxxxxxx (synchsafe integer)
# Optional:
# Extended header size   4 * %0xxxxxxx
# Number of flag bytes       $01
# Extended Flags             $xx
proc parse_id3v2 {} {
    big_endian

    ascii 3 "Magic"
    set version [uint8 "Version"]
    uint8 "Revision"
    set flags [uint8 "Flags"]
    # TODO: hmm range not part of section
    set size [syncsafeint32 "Size"]
    set ext_size 0

    if { $flags & 0x40 } {
        section "Extended header" {
            switch $version {
                3 {
                    set ext_size [uint32 "Size"]
                    bytes $ext_size "Data"
                }
                4 {
                    # in v24 synchsafe integer includes itself
                    set ext_size [syncsafeint32 "Size"]
                    bytes [expr $ext_size-4] "Data"
                }
            }
        }
    }

    switch $version {
        2 -
        3 -
        4 {
            parse_frames $version [expr $size-$ext_size]
        }
        default {
            bytes $size "Data"
        }
    }
}

# "ID3"
requires 0 "49 44 33"
parse_id3v2
