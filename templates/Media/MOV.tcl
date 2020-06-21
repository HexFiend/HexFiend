# QT, mov, mp4
# Format specification can be found at:
# https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFPreface/qtffPreface.html
# Also these sources are useful:
# https://github.com/axiomatic-systems/Bento4
# https://wiki.multimedia.cx/index.php/QuickTime_container
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

big_endian
# ftyp
requires 4 "66 74 79 70"

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

proc hex_dict { len label dict {default ""} } {
    set k [hex $len]
    set v $default
    if { [dict exists $dict $k] } {
        set v [dict get $dict $k]
    }
    entry $label [format "%s (%s)" $v $k] $len [expr [pos]-$len]
    return $k
}

proc fixedpoint32 { {name ""} } {
    set n [uint32]
    # TODO: correct? singed?
    set v [expr ($n >> 16) | (($n && 0xffff) / 0x10000) ]
    if { $name != "" } {
        entry $name $v 4 [expr [pos]-4]
    }
    return v
}

proc fixedpoint16 { {name ""} } {
    set n [uint16]
    # TODO: correct? signed?
    set v [expr ($n >> 8) | (($n && 0xff) / 0x100) ]
    if { $name != "" } {
        entry $name $v 2 [expr [pos]-2]
    }
    return $v
}

# Protocol buffers parsing used by PSSH

proc pb_enum { label enums_var } {
    upvar #0 $enums_var enums

    lassign [pb_varint] len n
    set v $n
    if { [dict exists $enums $n ]} {
        set v [format "%s (%d)" [dict get $enums $n] $n]
    }
    entry $label $v $len [expr [pos]-$len]

    return [list $len $n]
}

proc pb_string { label _extra } {
    lassign [pb_varint] len n
    return [list [expr $len+$n] [ascii_maybe_empty $n $label]]
}

proc pb_bytes { label _extra } {
    lassign [pb_varint] len n
    return [list [expr $len+$n] [bytes_maybe_empty $n $label]]
}

proc pb_int32 { label enums_var } {
    lassign [pb_enum $label $enums_var] len n
    return [list $len $n]
}

proc pb_uint32 { label enums_var } {
    return [pb_int32 $label $enums_var]
}

proc pb_int64 { label enums_var } {
    return [pb_int32 $label $enums_var]
}

proc pb_uint64 { label enums_var } {
    return [pb_int32 $label $enums_var]
}

proc pb_bool { label enums_var } {
    return [pb_int32 $label $enums_var]
}

set pb_wire_types [dict create \
    0 varint \
    1 64bit \
    2 length_delim \
    5 32bit \
]

proc pb_varint { {label ""} {_extra ""} } {
    set n 0
    for { set i 0 } { 1 } { incr i } {
        set b [uint8]
        set n [expr $n | (($b & 0x7f) << (7*$i))]
        if { !($b & 0x80) } {
            break
        }
    }

    set len [expr $i+1]
    if { $label != "" } {
        entry $label $n $len [expr [pos]-$len]
    }

    return [list $len $n]
}

proc pb_64bit { label _extra } {
    if { $label == "" } {
        bytes 8
    } else {
        bytes 8 $label
    }
    return [list 8 ""]
}

proc pb_length_delim { label _extra } {
    lassign [pb_varint] payload_len payload_n
    if { $label == "" } {
        bytes $payload_n
    } else {
        bytes $payload_n $label
    }
    return [list [expr $payload_len+$payload_n] ""]
}

proc pb_32bit { label _extra } {
    if { $label == "" } {
        bytes 4
    } else {
        bytes 4 $label
    }
    return [list 4 ""]
}

proc pb_message { label fields_var } {
    lassign [pb_varint] len n

    section $fields_var {
        pb_fields $n $fields_var
    }

    return [list $len+$n ""]
}

proc pb_field { fields_var } {
    global pb_wire_types
    upvar #0 $fields_var fields

    lassign [pb_varint] key_len key_n
    set field_number [expr $key_n>>3]
    set wire_type_n [expr $key_n&0x7]
    set wire_type [dict get $pb_wire_types $wire_type_n]
    set parse_fn pb_$wire_type
    set name [format "unknown %d" $field_number]
    set type "unknown"
    set extra {}

    if { [dict exists $fields $field_number] } {
        set field [dict get $fields $field_number]
        lassign $field type name extra
        set parse_fn pb_$type
    }

    section $name {
        entry "Field number" $field_number $key_len [expr [pos]-$key_len]
        entry "Wire type" [format "%s (%d)" $wire_type $wire_type_n] $key_len [expr [pos]-$key_len]
        entry "Type" $type $key_len [expr [pos]-$key_len]
        lassign [$parse_fn "Value" $extra] len n
    }

    return [expr $key_len+$len]
}

proc pb_fields { size fields_var } {
    while { $size > 0 } {
        incr size [expr -[pb_field $fields_var]]
    }
}

set atom_fullname [dict create \
    ainf "Asset information to identify, license and play" \
    assp "Alternative startup sequence properties" \
    avcn "AVC NAL Unit Storage Box" \
    bidx "Box Index" \
    bloc "Base location and purchase location for license acquisition" \
    bpcc "Bits per component" \
    buff "Buffering information" \
    bxml "Binary XML container" \
    ccid "OMA DRM Content ID" \
    cdef "Type and ordering of the components within the codestream" \
    cinf "Complete track information" \
    clip "Reserved" \
    cmap "Mapping between a palette and codestream components" \
    co64 "64-bit chunk offset" \
    coin "Content Information Box" \
    colr "Specifies the colourspace of the image" \
    crgn "Reserved" \
    crhd "Reserved for ClockReferenceStream header" \
    csgp "Compact sample to group" \
    cslg "Composition to decode timeline mapping" \
    ctab "Reserved" \
    ctts "Composition time to sample" \
    cvru "OMA DRM Cover URI" \
    dihd "Data Integrity Hash" \
    dinf "Data information box, container" \
    dint "Data Integrity" \
    dref "Data reference box, declares source(s) of media data in track" \
    dsgd "DVB Sample Group Description Box" \
    dstg "DVB Sample to Group Box" \
    edts "Edit list container" \
    elst "An edit list" \
    emsg "Event message" \
    evti "Event information" \
    etyp "Extended type and type combination" \
    fdel "File delivery information (item info extension)" \
    feci "FEC Informatiom" \
    fecr "FEC Reservoir" \
    fidx "Box File Index" \
    fiin "FD Item Information" \
    fire "File Reservoir" \
    fpar "File Partition" \
    free "Free space" \
    frma "Original format box" \
    frpa "Front Part" \
    ftyp "File type and compatibility" \
    gitn "Group ID to name" \
    grpi "OMA DRM Group ID" \
    grpl "Groups List box" \
    hdlr "Handler, declares the media (handler) type" \
    hmhd "Hint media header, overall information (hint track only)" \
    hpix "Hipix Rich Picture (user-data or meta-data)" \
    icnu "OMA DRM Icon URI" \
    ID32 "ID3 version 2 container" \
    idat "Item data" \
    ihdr "Image Header" \
    iinf "Item information" \
    iloc "Item location" \
    imap "Reserved" \
    imda "Identified media data" \
    imif "IPMP Information box" \
    infe "Item information entry" \
    infu "OMA DRM Info URL" \
    iods "Object Descriptor container box" \
    ipco "ItemPropertyContainerBox" \
    iphd "Reserved for IPMP Stream header" \
    ipma "ItemPropertyAssociation" \
    ipmc "IPMP Control Box" \
    ipro "Item protection" \
    iprp "Item Properties Box" \
    iref "Item reference" \
    "jP\x20\x20" "JPEG 2000 Signature" \
    jp2c "JPEG 2000 contiguous codestream" \
    jp2h "Header" \
    jp2i "Intellectual property information" \
    kmat "Reserved" \
    leva "Leval assignment" \
    load "Reserved" \
    loop "Looping behavior" \
    lrcu "OMA DRM Lyrics URI" \
    m7hd "Reserved for MPEG7Stream header" \
    matt "Reserved" \
    md5i "MD5IntegrityBox" \
    mdat "Media data container" \
    mdhd "Media header, overall information about the media" \
    mdia "Container for the media information in a track" \
    mdri "Mutable DRM information" \
    meco "Additional metadata container" \
    mehd "Movie extends header box" \
    mere "Metabox relation" \
    meta "Metadata container" \
    mfhd "Movie fragment header" \
    mfra "Movie fragment random access" \
    mfro "Movie fragment random access offset" \
    minf "Media information container" \
    mjhd "Reserved for MPEG-J Stream header" \
    moof "Movie fragment" \
    moov "Container for all the meta-data" \
    mstv "MVC sub track view box" \
    mvcg "Multiview group" \
    mvci "Multiview Information" \
    mvdr "MVDDepthResolutionBox" \
    mvex "Movie extends box" \
    mvhd "Movie header, overall declarations" \
    mvra "Multiview Relation Attribute" \
    nmhd "Null media header, overall information (some tracks only)" \
    ochd "Reserved for ObjectContentInfoStream header" \
    odaf "OMA DRM Access Unit Format" \
    odda "OMA DRM Content Object" \
    odhd "Reserved for ObjectDescriptorStream header" \
    odhe "OMA DRM Discrete Media Headers" \
    odrb "OMA DRM Rights Object" \
    odrm "OMA DRM Container" \
    odtt "OMA DRM Transaction Tracking" \
    ohdr "OMA DRM Common headers" \
    padb "Sample padding bits" \
    paen "Partition Entry" \
    pclr "Palette which maps a single component in index space to a multiple- component image" \
    pdat "Partial Data" \
    pdin "Progressive download information" \
    pfhd "Partial File Header" \
    pfil "Partial File" \
    pitm "Primary item reference" \
    ploc "Partial Segment Location" \
    pnot "Reserved" \
    prft "Producer reference time" \
    pseg "Partial Segment" \
    pshd "Partial Segment Header" \
    pssh "Protection system specific header" \
    ptle "Partial Top Level Entry" \
    "res\x20" "Grid resolution" \
    resc "Grid resolution at which the image was captured" \
    resd "Default grid resolution at which the image should be displayed" \
    rinf "Restricted scheme information box" \
    saio "Sample auxiliary information offsets" \
    saiz "Sample auxiliary information sizes" \
    sbgp "Sample to Group box" \
    schi "Scheme information box" \
    schm "Scheme type box" \
    sdep "Sample dependency" \
    sdhd "Reserved for SceneDescriptionStream header" \
    sdtp "Independent and Disposable Samples Box" \
    sdvp "SD Profile Box" \
    segr "File delivery session group" \
    seii "SEI information box" \
    senc "Sample specific encryption data" \
    sgpd "Sample group definition box" \
    sidx "Segment Index Box" \
    sinf "Protection scheme information box" \
    skip "Free space" \
    smhd "Sound media header, overall information (sound track only)" \
    srmb "System Renewability Message" \
    srmc "System Renewability Message container" \
    srpp "STRP Process" \
    ssix "Sub-sample index" \
    sstl "SVC sub track layer box" \
    stbl "Sample table box, container for the time/space map" \
    stco "Chunk offset, partial data-offset information" \
    stdp "Sample degradation priority" \
    sthd "Subtitle Media Header Box" \
    stmg "MVC sub track multiview group box" \
    strd "Sub-track definition" \
    stri "Sub-track information" \
    stsc "Sample-to-chunk, partial data-offset information" \
    stsd "Sample descriptions (codec types, initialization etc.)" \
    stsg "Sub-track sample grouping" \
    stsh "Shadow sync sample table" \
    stss "Sync sample table (random access points)" \
    stsz "Sample sizes (framing)" \
    stti "Sub track tier box" \
    stts "Sample time-to-sample" \
    styp "Segment Type Box" \
    stz2 "Compact sample sizes (framing)" \
    subs "Sub-sample information" \
    surl "Source URL" \
    swtc "Multiview Group Relation" \
    tenc "Track Encryption" \
    tfad "Track fragment adjustment box" \
    tfdt "Track fragment decode time" \
    tfhd "Track fragment header" \
    tfma "Track fragment media adjustment box" \
    tfra "Track fragment radom access" \
    tibr "Tier Bit rate" \
    tiri "Tier Information" \
    tkhd "Track header, overall information about the track" \
    traf "Track fragment" \
    trak "Container for an individual track or stream" \
    tref "Track reference container" \
    trep "Track extension properties" \
    trex "Track extends defaults" \
    trgr "Track grouping information" \
    trik "Facilitates random access and trick play modes" \
    trun "Track fragment run" \
    tstb "TileSubTrackGroupBox" \
    ttyp "Track type and compatibility" \
    tyco "Type and-combination" \
    udta "User-data" \
    uinf "A tool by which a vendor may provide access to additional information associated with a UUID" \
    UITS "Unique Identifier Technology Solution" \
    ulst "A list of UUID’s" \
    "url\x20" "A URL" \
    uuid "User-extension box" \
    vmhd "Video media header, overall information (video track only)" \
    vwdi "Multiview Scene Information" \
    "xml\x20" "XML container" \
    j2kH "JPEG 2000 header item property" \
    albm "Album title and track number for media" \
    alou "Album loudness base" \
    angl "Name of the camera angle through which the clip was shot" \
    auth "Author of the media" \
    clfn "Name of the clip file" \
    clid "Identifier of the clip" \
    clsf "Classification of the media" \
    cmid "Identifier of the camera" \
    cmnm "Name that identifies the camera" \
    coll "Name of the collection from which the media comes" \
    cprt "Copyright etc." \
    date "Date and time, formatted according to ISO 8601, when the content was created. For clips captured by recording devices, this is typically the date and time when the clip’s recording started." \
    dscp "Media description" \
    gnre "Media genre" \
    hinf "Hint information" \
    hnti "Hint information" \
    hpix "Hipix Rich Picture (user-data or meta-data)" \
    kind "Track kind" \
    kywd "Media keywords" \
    loci "Media location information" \
    ludt "Track loudness container" \
    manu "Manufacturer name of the camera" \
    modl "Model name of the camera" \
    orie "Orientation information" \
    perf "Media performer name" \
    reel "Name of the tape reel" \
    rtng "Media rating" \
    scen "Name of the scene for which the clip was shot" \
    shot "Name that identifies the shot" \
    slno "Serial number of the camera" \
    strk "Sub track information" \
    thmb "Thumbnail image of the media" \
    titl "Media title" \
    tlou "Track loudness base" \
    tsel "Track selection" \
    urat "User 'star' rating of the media" \
    yrrc "Year when media was recorded" \
    albm "Album title and track number (user-data)" \
    auth "Media author name (user-data)" \
    clip "Visual clipping region container" \
    clsf "Media classification (user-data)" \
    cprt "Copyright etc. (user-data)" \
    crgn "Visual clipping region definition" \
    ctab "Track color-table" \
    dcfD "Marlin DCF Duration, user-data atom type" \
    elng "Extended Language Tag" \
    imap "Track input map definition" \
    kmat "Compressed visual track matte" \
    load "Track pre-load definitions" \
    matt "Visual track matte for compositing" \
    pnot "Preview container" \
    wide "Expansion space reservation" \
]

proc atom_ftyp { data_size } {
    ascii 4 "Major brand"
    uint32 "Minor version"
    set num_brands [expr ($data_size-8)/4]
    section "Compatible brands" {
        for { set i 0 } { $i < $num_brands } { incr i } {
            ascii 4 $i
        }
    }
}

proc atom_moov { data_size } {
    parse_atoms $data_size
}

proc atom_mvhd { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    macdate "Creation time"
    macdate "Modification time"
    uint32 "Time scale"
    uint32 "Duration"
    fixedpoint32 "Preferred rate"
    fixedpoint16 "Preferred volume"
    bytes 10 "Reserved"
    bytes 36 "Matrix structure"
    uint32 "Preview time"
    uint32 "Preview duration"
    uint32 "Poster time"
    uint32 "Selection time"
    uint32 "Selection duration"
    uint32 "Current time"
    uint32 "Next track ID"
}

proc atom_mdhd { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    macdate "Creation time"
    macdate "Modification time"
    uint32 "Time scale"
    uint32 "Duration"
    uint16 "Language"
    uint16 "Quality"
}

proc atom_hdlr { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    ascii 4 "Component type"
    ascii 4 "Component subtype"
    ascii 4 "Component manufacturer"
    uint32 "Component flags"
    uint32 "Component flags mask"
    ascii_maybe_empty [expr $data_size-24] "Component name"
}

proc atom_minf { data_size } {
    parse_atoms $data_size
}

proc atom_vmhd { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    uint16 "Graphics mode"
    section "Opcolor" {
        uint16 "Red"
        uint16 "Green"
        uint16 "Blue"
    }
}

proc atom_dinf { data_size } {
    parse_atoms $data_size
}

proc atom_dref { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    set num_entries [uint32 "Number of entries"]
    section "Data references" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            section "$i" {
                set size [uint32 "Size"]
                set type [ascii 4 "Type"]
                uint8 "Version"
                bytes 3 "Flags"
                set dataref_size [expr $size-12]
                if { $dataref_size > 0 } {
                    bytes $dataref_size "Data"
                }
            }
        }
    }
}

proc atom_stbl { data_size } {
    parse_atoms $data_size
}

proc atom_stsd { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    set num_entries [uint32 "Number of entries"]
    section "Sample description table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            section "$i" {
                set size [uint32 "Sample description size"]
                ascii 4 "Data format"
                bytes 6 "Reserved"
                uint16 "Data reference index"
                set data_format_size [expr $size-16]
                if { $data_format_size > 0 } {
                    bytes $data_format_size "Data"
                }
            }
        }
    }
}

proc atom_sidx { data_size } {
    set version [uint8 "Version"]
    bytes 3 "Flags"
    uint32 "Reference ID"
    uint32 "Timescale"
    if { $version == 0 } {
        uint32 "PTS"
        uint32 "Offset"
    } else {
        uint64 "PTS"
        uint64 "Offset"
    }
    uint16 "Reserved"
    set num_entries [uint16 "Number of entries"]
    section "Index table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            section "$i" {
                uint32 "Size"
                uint32 "Duration"
                uint32 "SAP flags"
            }
        }
    }
}

proc atom_tfdt { data_size } {
    set version [uint8 "Version"]
    bytes 3 "Flags"
    if { $version == 0 } {
        uint32 "Base media decode time"
    } else {
        uint64 "Base media decode time"
    }
}

proc atom_trun { data_size } {
    set version [uint8 "Version"]
    set flags [uint24 "Flags"]
    set num_entries [uint32 "Number of entries"]

    # from ffmpeg libavformat/isom.h
    set MOV_TRUN_DATA_OFFSET 			 0x1
    set MOV_TRUN_FIRST_SAMPLE_FLAGS 	 0x4
    set MOV_TRUN_SAMPLE_DURATION       0x100
    set MOV_TRUN_SAMPLE_SIZE           0x200
    set MOV_TRUN_SAMPLE_FLAGS          0x400
    set MOV_TRUN_SAMPLE_CTS            0x800

    if { $flags & $MOV_TRUN_DATA_OFFSET } {
        uint32 "Data offset"
    }
    if { $flags & $MOV_TRUN_FIRST_SAMPLE_FLAGS } {
        uint32 "First sample flags"
    }

    section "Sample table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            if { $flags & $MOV_TRUN_SAMPLE_DURATION } {
                uint32 "Sample duration"
            }
            if { $flags & $MOV_TRUN_SAMPLE_SIZE } {
                uint32 "Sample size"
            }
            if { $flags & $MOV_TRUN_SAMPLE_FLAGS } {
                uint32 "Sample flags"
            }
            if { $flags & $MOV_TRUN_SAMPLE_CTS } {
                uint32 "CTTS duration"
            }
        }
    }
}

proc atom_stts { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    set num_entries [uint32 "Number of entries"]
    section "Time-to-sample table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            section "$i" {
                uint32 "Sample count"
                uint32 "Sample duration"
            }
        }
    }
}

proc atom_stss { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    set num_entries [uint32 "Number of entries"]
    section "Sync sample table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            uint32 $i
        }
    }
}

proc atom_ctts { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    set num_entries [uint32 "Number of entries"]
    section "Composition-offset table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            section "$i" {
                uint32 "Sample count"
                uint32 "Composition offset"
            }
        }
    }
}

proc atom_stsc { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    set num_entries [uint32 "Number of entries"]
    section "Sample-to-chunk table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            section "$i" {
                uint32 "First chunk"
                uint32 "Samples per chunk"
                uint32 "Sample description ID"
            }
        }
    }
}

proc atom_stsz { data_size } {
    uint8 "Version"
    bytes 3 "Flags"

    set uniform_size [uint32 "Sample size"]
    set num_entries [uint32 "Number of entries"]

    if { $uniform_size == 0 } {
        section "Sample size table" {
            for { set i 0 } { $i < $num_entries } { incr i } {
                uint32 $i
            }
        }
    }
}

proc atom_stco { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    set num_entries [uint32 "Number of entries"]
    section "Chunk offset table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            uint32 $i
        }
    }
}

proc atom_mdia { data_size } {
    parse_atoms $data_size
}

proc atom_trak { data_size } {
    parse_atoms $data_size
}

proc atom_tref { data_size } {
    parse_atoms $data_size
}

proc atom_tkhd { data_size } {
    uint8 "Version"
    # TODO: values
    bytes 3 "Flags"
    macdate "Creation time"
    macdate "Modification time"
    uint32 "Track ID"
    uint32 "Reserved"
    uint32 "Duration"
    bytes 8 "Reserved"
    uint16 "Layer"
    # TODO: values
    uint16 "Alternate group"
    fixedpoint16 "Volume"
    uint16 "Reserved"
    bytes 36 "Matrix structure"
    fixedpoint32 "Track width"
    fixedpoint32 "Track height"
}

proc atom_edts { data_size } {
    parse_atoms $data_size
}

proc atom_elst { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    set num_entries [uint32 "Number of entries"]
    section "Edit list table" {
        for { set i 0 } { $i < $num_entries } { incr i } {
            section "$i" {
                uint32 "Track duration"
                uint32 "Media time"
                fixedpoint32 "Media rate"
            }
        }
    }
}

proc atom_udta { data_size } {
    parse_atoms $data_size
}

proc atom_meta { data_size } {
    set unknown [uint32]
    move -4
    # meta atom sometimes has a 4 byte unknown field (flag/version?)
    # TODO: better detection?
    if { $unknown == 0 } {
        uint32 "Unknown field"
        parse_atoms [expr $data_size-4]
    } else {
        parse_atoms $data_size
    }
}

proc atom_ilst { data_size } {
    parse_atoms $data_size
}

proc atom_hnti { data_size } {
    parse_atoms $data_size
}

proc atom_hinf { data_size } {
    parse_atoms $data_size
}

proc "atom_©too" { data_size } {
    parse_atoms $data_size
}

proc atom_moof { data_size } {
    parse_atoms $data_size
}

proc atom_mfhd { data_size } {
    bytes 4 "Flags"
    uint32 "Fragments"
}

proc atom_traf { data_size } {
    parse_atoms $data_size
}

proc atom_tfhd { data_size } {
    uint8 "Version"
    uint24 "Flags"
    uint32 "Track ID"
    bytes [expr $data_size-8] "Value"
}

set pssh_system_names [dict create \
    0x1077EFECC0B24D02ACE33C1E52E2FB4B CENC \
    0xEDEF8BA979D64ACEA3C827DCD51D21ED Widevine	\
    0x9A04F07998404286AB92E65BE0885F95 Playready \
]

set pssh_system_fns [dict create \
    0x1077EFECC0B24D02ACE33C1E52E2FB4B pssh_common \
    0xEDEF8BA979D64ACEA3C827DCD51D21ED pssh_widevine \
    0x9A04F07998404286AB92E65BE0885F95 pssh_playready \
]

proc pssh_common { data_size } {
    ascii_maybe_empty $data_size "Data"
}

set widevine_pssh_data [dict create \
    1 {enum algorithm widevine_pssh_data_algorithm} \
    2 {bytes key_id} \
    3 {string provider} \
    4 {bytes content_id} \
    6 {string policy} \
    7 {uint32 crypto_period_index} \
    8 {bytes grouped_license} \
    9 {uint32 protection_scheme protection_scheme_algs} \
]

set widevine_pssh_data_algorithm [dict create \
    0 UNENCRYPTED \
    1 AESCTR \
]

set protection_scheme_algs [dict create \
    1667591779 "cenc AES-CTR" \
    1667392305 "cbc1 AES-CBC" \
    1667591795 "cens AES-CTR subsample" \
    1667392371 "cbcs AES-CBC subsample" \
]

proc pssh_widevine { data_size } {
    pb_fields $data_size widevine_pssh_data
}

proc pssh_playready { data_size } {
    little_endian
    uint32 "Size"
    section "Records" {
    set count [uint16]
        for { set i 0 } { $i < $count } { incr i } {
            set type [uint16]
            move -2

            if { $type == 1 } {
                section "Rights Management Header" {
                    set type [uint16 "Type"]
                    set len [uint16 "Len"]
                    ascii_maybe_empty $len "XML"
                }
            } elseif { $type == 3 } {
                section "License Store" {
                    set type [uint16 "Type"]
                    set len [uint16 "Len"]
                    hex $len "XML"
                }
            } else {
                section "Unknown" {
                    set type [uint16 "Type"]
                    set len [uint16 "Len"]
                    ascii_maybe_empty $len "Datas"
                }
            }

        }
    }
    big_endian
}

proc atom_pssh { data_size} {
    global pssh_system_names pssh_system_fns

    set version [uint8 "Version"]
    uint24 "Flags"
    set system_id [hex_dict 16 "System ID" $pssh_system_names "Unknown"]

    if { $version == 1 } {
        set count [uint32 "Key count"]
        section "Keys" {
            for { set i 0 } { $i < $count } { incr i } {
                hex 16 $i
            }
        }
    }

    set pssh_size [uint32 "PSSH size"]
    set pssh_fn pssh_common
    if { [dict exists $pssh_system_fns $system_id] } {
        set pssh_fn [dict get $pssh_system_fns $system_id]
    }
    set pssh_name "Common"
    if { [dict exists $pssh_system_names $system_id] } {
        set pssh_name [dict get $pssh_system_names $system_id]
    }

    section $pssh_name {
        $pssh_fn $pssh_size
    }
}

proc atom_apple_annotation { data_size} {
    parse_atoms $data_size
}

proc atom_data { data_size } {
    uint8 "Version"
    bytes 3 "Flags"
    uint32 "Reserved"
    ascii [expr $data_size-8] "Data"
}

proc parse_atom {} {
    global atom_fullname
    set size [uint32]
    set type [ascii 4]
    move -8

    set fullname ""
    if { [dict exists $atom_fullname $type ]} {
        set fullname [dict get $atom_fullname $type]
    }

    section "$type" {
        sectionvalue $fullname
        switch $size {
            0 {
                # rest of file
                uint32 "Size (rest of file)"
                ascii 4 "Type"
                set size [expr [len]-[pos]+8]
            }
            1 {
                # 64 bit length
                uint32 "Size (use Size64)"
                ascii 4 "Type"
                set size [uint64 "Size64"]
            }
            default {
                uint32 "Size"
                ascii 4 "Type"
            }
        }

        set data_size [expr $size-8]

        # TODO:
        # type start with ©
        # if { [scan $type %c] == 0xa9 } {
        # 	set type "apple_annotation"
        # }

        set parse_fn "atom_$type"
        if { [info procs $parse_fn] != "" } {
            $parse_fn $data_size
        } elseif { $data_size > 0 } {
            bytes $data_size "Data"
        }
    }

    return $size
}

proc parse_atoms { data_size } {
    for { set left $data_size } { $left > 0 } {} {
        incr left [expr -[parse_atom]]
    }
}

proc parse_to_end {} {
    while {![end]} {
        parse_atom
    }
}

parse_to_end
