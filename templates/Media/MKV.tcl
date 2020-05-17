# EBML, Matroska and webm binary template
#
# Specification can be found at:
# https://tools.ietf.org/html/draft-ietf-cellar-ebml-00
# https://matroska.org/technical/specs/index.html
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

# TODO:
# enums
# default value when zero length

requires 0 "1a 45 df a3"
big_endian

proc ascii_maybe_empty {size {name ""}} {
    if {$size > 0} {
        if {$name != ""} {
            return [ascii $size $name]
        } else {
            return [ascii $size]
        }
    } else {
        if {$name != ""} {
            entry $name ""
        }
        return ""
    }
}

proc bytes_maybe_empty {size {name ""}} {
    if {$size > 0} {
        if {$name != ""} {
            return [bytes $size $name]
        } else {
            return [bytes $size]
        }
    } else {
        if {$name != ""} {
            entry $name
        }
        return ""
    }
}

proc utf8 {size label} {
    set s ""
    if {$size > 0} {
        set bytes [bytes $size]
        set s [encoding convertfrom utf-8 [string trimright $bytes "\x00"]]
    }
    entry $label $s $size [expr [pos]-$size]
}

proc uint {size {name ""}} {
    set n 0
    for {set i 0} {$i < $size} {incr i} {
        set n [expr $n<<8 | [uint8]]
    }
    if {$name != ""} {
	    entry $name $n $size [expr [pos]-$size]
    }
    return $n
}

proc int {size {name ""}} {
    set n 0
    for {set i 0} {$i < $size} {incr i} {
        set n [expr $n<<8 | [uint8]]
    }
    if {$n & (1 << ($size*8-1))} {
        # 2-complement
        set n [expr -((~$n & (1<<($size*8))-1)+1)]
    }

    if {$name != ""} {
	    entry $name $n $size [expr [pos]-$size]
    }
    return $n
}

proc vint {} {
    set n [uint8]

    set width 1
    for {set i 0} {($n & (1<<(7-$i))) == 0} {incr i} {
        incr width
    }
    for {set i 1} {$i < $width} {incr i} {
        set n [expr ($n<<8) | [uint8]]
    }

    # return byte-width raw-n n
    return [list $width $n [expr ((1<<(($width-1)*8+(8-$width)))-1) & $n]]
}

proc type_string {size label _extra} {
    ascii_maybe_empty $size $label
}

proc type_binary {size label _extra} {
    bytes_maybe_empty $size $label
}

proc type_utf-8 {size label _extra} {
    utf8 $size $label
}

proc type_uinteger {size label _extra} {
    switch $size {
        0 {entry $label 0}
        1 {uint8 $label}
        2 {uint16 $label}
        4 {uint32 $label}
        8 {uint64 $label}
        3 -
        5 -
        6 -
        7 {uint $size $label}
        default {bytes $size $label}
    }
}

proc type_integer {size label _extra} {
    switch $size {
        0 {entry $label 0}
        1 {int8 $label}
        2 {int16 $label}
        4 {int32 $label}
        8 {int64 $label}
        3 -
        5 -
        6 -
        7 {int $size $label}
        default {bytes $size $label}
    }
}

proc type_float {size label _extr} {
    switch $size {
        0 {entry $label 0}
        4 {float $label}
        8 {double $label}
        default {bytes $size $label}
    }
}

proc type_date {size label _extra} {
    set s [clock scan {2001-01-01 00:00:00}]
    set frac 0
    switch $size {
        0 {}
        8 {
            set nano [int64]
            set s [clock add $s [expr $nano/1000000000] seconds]
            set frac [expr ($nano%1000000000)/1000000000.0]
        }
        default {
            bytes $size $label
            return
        }
    }

    entry $label "[clock format $s] ${frac}s" $size [expr [pos]-$size]
}

proc type_master {size _label extra} {
    upvar #0 "ebml_$extra" tags
    global ebml_Global
    set garbage_size 0

    # TODO: unknown-size might not be correct handled
    while {![end] && ($size > 0 || $size == -1)} {
        lassign [vint] tag_id_width tag_idnr
        set tag_id [format "%x" $tag_idnr]
        lassign [vint] tag_size_width tag_size_raw tag_size

        set tag_name "Unknown"
        set tag_type "binary"
        set tag_extra {}
        set tag_desc ""
        if {[dict exists $tags $tag_id]} {
            lassign [dict get $tags $tag_id] tag_name tag_type tag_extra tag_desc
        } elseif {[dict exists $ebml_Global $tag_id]} {
            lassign [dict get $ebml_Global $tag_id] tag_name tag_type tag_extra tag_desc
        } elseif {$size == -1} {
            incr garbage_size
            move [expr -($tag_id_width+$tag_size_width-1)]
            continue
        }

        if {$garbage_size != 0} {
            entry "Garbage" {} $garbage_size [expr [pos]-$garbage_size-$tag_id_width-$tag_size_width]
            set garbage_size 0
        }

        set type_fn "type_$tag_type"

        section "$tag_name ($tag_type)" {
            entry "ID" $tag_id $tag_id_width [expr [pos]-$tag_id_width-$tag_size_width]
            set tag_size_str $tag_size
            if {$tag_size_raw == 0xff} {
                append tag_size_str " (unknown)"
                set tag_size -1
            }
            entry "Size" "$tag_size_str" $tag_size_width [expr [pos]-$tag_size_width]
            $type_fn $tag_size $tag_name $tag_extra
        }

        if {$size == -1} {
            continue
        }
        incr size [expr -($tag_id_width+$tag_size_width+$tag_size)]
    }
}

# generated from https://raw.githubusercontent.com/cellar-wg/matroska-specification/aa2144a58b661baf54b99bab41113d66b0f5ff62/ebml_matroska.xml
# using https://gist.github.com/wader/e15b0966dc464db5d70c2a155537ba1f
set ebml_Global [dict create \
    bf {CRC-32 binary {}} \
    ec {Void binary {}} \
]

set ebml_root [dict create \
    1a45dfa3 {EBML master Header} \
    18538067 {Segment master Segment} \
]

set ebml_Header [dict create \
    4286 {EBMLVersion uinteger {}} \
    42f7 {EBMLReadVersion uinteger {}} \
    42f2 {EBMLMaxIDLength uinteger {}} \
    42f3 {EBMLMaxSizeLength uinteger {}} \
    4282 {DocType string {}} \
    4287 {DocTypeVersion uinteger {}} \
    4285 {DocTypeReadVersion uinteger {}} \
]

set ebml_Segment [dict create \
    114d9b74 {SeekHead master SeekHead} \
    1549a966 {Info master Info} \
    1f43b675 {Cluster master Cluster} \
    1654ae6b {Tracks master Tracks} \
    1c53bb6b {Cues master Cues} \
    1941a469 {Attachments master Attachments} \
    1043a770 {Chapters master Chapters} \
    1254c367 {Tags master Tags} \
]

set ebml_SeekHead [dict create \
    4dbb {Seek master Seek} \
]

set ebml_Seek [dict create \
    53ab {SeekID binary {}} \
    53ac {SeekPosition uinteger {}} \
]

set ebml_Info [dict create \
    73a4 {SegmentUID binary {}} \
    7384 {SegmentFilename utf-8 {}} \
    3cb923 {PrevUID binary {}} \
    3c83ab {PrevFilename utf-8 {}} \
    3eb923 {NextUID binary {}} \
    3e83bb {NextFilename utf-8 {}} \
    4444 {SegmentFamily binary {}} \
    6924 {ChapterTranslate master ChapterTranslate} \
    2ad7b1 {TimestampScale uinteger {}} \
    4489 {Duration float {}} \
    4461 {DateUTC date {}} \
    7ba9 {Title utf-8 {}} \
    4d80 {MuxingApp utf-8 {}} \
    5741 {WritingApp utf-8 {}} \
]

set ebml_ChapterTranslate [dict create \
    69fc {ChapterTranslateEditionUID uinteger {}} \
    69bf {ChapterTranslateCodec uinteger {}} \
    69a5 {ChapterTranslateID binary {}} \
]

set ebml_Cluster [dict create \
    e7 {Timestamp uinteger {}} \
    5854 {SilentTracks master SilentTracks} \
    a7 {Position uinteger {}} \
    ab {PrevSize uinteger {}} \
    a3 {SimpleBlock binary {}} \
    a0 {BlockGroup master BlockGroup} \
    af {EncryptedBlock binary {}} \
]

set ebml_SilentTracks [dict create \
    58d7 {SilentTrackNumber uinteger {}} \
]

set ebml_BlockGroup [dict create \
    a1 {Block binary {}} \
    a2 {BlockVirtual binary {}} \
    75a1 {BlockAdditions master BlockAdditions} \
    9b {BlockDuration uinteger {}} \
    fa {ReferencePriority uinteger {}} \
    fb {ReferenceBlock integer {}} \
    fd {ReferenceVirtual integer {}} \
    a4 {CodecState binary {}} \
    75a2 {DiscardPadding integer {}} \
    8e {Slices master Slices} \
    c8 {ReferenceFrame master ReferenceFrame} \
]

set ebml_BlockAdditions [dict create \
    a6 {BlockMore master BlockMore} \
]

set ebml_BlockMore [dict create \
    ee {BlockAddID uinteger {}} \
    a5 {BlockAdditional binary {}} \
]

set ebml_Slices [dict create \
    e8 {TimeSlice master TimeSlice} \
]

set ebml_TimeSlice [dict create \
    cc {LaceNumber uinteger {}} \
    cd {FrameNumber uinteger {}} \
    cb {BlockAdditionID uinteger {}} \
    ce {Delay uinteger {}} \
    cf {SliceDuration uinteger {}} \
]

set ebml_ReferenceFrame [dict create \
    c9 {ReferenceOffset uinteger {}} \
    ca {ReferenceTimestamp uinteger {}} \
]

set ebml_Tracks [dict create \
    ae {TrackEntry master TrackEntry} \
]

set ebml_TrackEntry [dict create \
    d7 {TrackNumber uinteger {}} \
    73c5 {TrackUID uinteger {}} \
    83 {TrackType uinteger {}} \
    b9 {FlagEnabled uinteger {}} \
    88 {FlagDefault uinteger {}} \
    55aa {FlagForced uinteger {}} \
    9c {FlagLacing uinteger {}} \
    6de7 {MinCache uinteger {}} \
    6df8 {MaxCache uinteger {}} \
    23e383 {DefaultDuration uinteger {}} \
    234e7a {DefaultDecodedFieldDuration uinteger {}} \
    23314f {TrackTimestampScale float {}} \
    537f {TrackOffset integer {}} \
    55ee {MaxBlockAdditionID uinteger {}} \
    41e4 {BlockAdditionMapping master BlockAdditionMapping} \
    536e {Name utf-8 {}} \
    22b59c {Language string {}} \
    22b59d {LanguageIETF string {}} \
    86 {CodecID string {}} \
    63a2 {CodecPrivate binary {}} \
    258688 {CodecName utf-8 {}} \
    7446 {AttachmentLink uinteger {}} \
    3a9697 {CodecSettings utf-8 {}} \
    3b4040 {CodecInfoURL string {}} \
    26b240 {CodecDownloadURL string {}} \
    aa {CodecDecodeAll uinteger {}} \
    6fab {TrackOverlay uinteger {}} \
    56aa {CodecDelay uinteger {}} \
    56bb {SeekPreRoll uinteger {}} \
    6624 {TrackTranslate master TrackTranslate} \
    e0 {Video master Video} \
    e1 {Audio master Audio} \
    e2 {TrackOperation master TrackOperation} \
    c0 {TrickTrackUID uinteger {}} \
    c1 {TrickTrackSegmentUID binary {}} \
    c6 {TrickTrackFlag uinteger {}} \
    c7 {TrickMasterTrackUID uinteger {}} \
    c4 {TrickMasterTrackSegmentUID binary {}} \
    6d80 {ContentEncodings master ContentEncodings} \
]

set ebml_BlockAdditionMapping [dict create \
    41f0 {BlockAddIDValue uinteger {}} \
    41a4 {BlockAddIDName string {}} \
    41e7 {BlockAddIDType uinteger {}} \
    41ed {BlockAddIDExtraData binary {}} \
]

set ebml_TrackTranslate [dict create \
    66fc {TrackTranslateEditionUID uinteger {}} \
    66bf {TrackTranslateCodec uinteger {}} \
    66a5 {TrackTranslateTrackID binary {}} \
]

set ebml_Video [dict create \
    9a {FlagInterlaced uinteger {}} \
    9d {FieldOrder uinteger {}} \
    53b8 {StereoMode uinteger {}} \
    53c0 {AlphaMode uinteger {}} \
    53b9 {OldStereoMode uinteger {}} \
    b0 {PixelWidth uinteger {}} \
    ba {PixelHeight uinteger {}} \
    54aa {PixelCropBottom uinteger {}} \
    54bb {PixelCropTop uinteger {}} \
    54cc {PixelCropLeft uinteger {}} \
    54dd {PixelCropRight uinteger {}} \
    54b0 {DisplayWidth uinteger {}} \
    54ba {DisplayHeight uinteger {}} \
    54b2 {DisplayUnit uinteger {}} \
    54b3 {AspectRatioType uinteger {}} \
    2eb524 {ColourSpace binary {}} \
    2fb523 {GammaValue float {}} \
    2383e3 {FrameRate float {}} \
    55b0 {Colour master Colour} \
    7670 {Projection master Projection} \
]

set ebml_Colour [dict create \
    55b1 {MatrixCoefficients uinteger {}} \
    55b2 {BitsPerChannel uinteger {}} \
    55b3 {ChromaSubsamplingHorz uinteger {}} \
    55b4 {ChromaSubsamplingVert uinteger {}} \
    55b5 {CbSubsamplingHorz uinteger {}} \
    55b6 {CbSubsamplingVert uinteger {}} \
    55b7 {ChromaSitingHorz uinteger {}} \
    55b8 {ChromaSitingVert uinteger {}} \
    55b9 {Range uinteger {}} \
    55ba {TransferCharacteristics uinteger {}} \
    55bb {Primaries uinteger {}} \
    55bc {MaxCLL uinteger {}} \
    55bd {MaxFALL uinteger {}} \
    55d0 {MasteringMetadata master MasteringMetadata} \
]

set ebml_MasteringMetadata [dict create \
    55d1 {PrimaryRChromaticityX float {}} \
    55d2 {PrimaryRChromaticityY float {}} \
    55d3 {PrimaryGChromaticityX float {}} \
    55d4 {PrimaryGChromaticityY float {}} \
    55d5 {PrimaryBChromaticityX float {}} \
    55d6 {PrimaryBChromaticityY float {}} \
    55d7 {WhitePointChromaticityX float {}} \
    55d8 {WhitePointChromaticityY float {}} \
    55d9 {LuminanceMax float {}} \
    55da {LuminanceMin float {}} \
]

set ebml_Projection [dict create \
    7671 {ProjectionType uinteger {}} \
    7672 {ProjectionPrivate binary {}} \
    7673 {ProjectionPoseYaw float {}} \
    7674 {ProjectionPosePitch float {}} \
    7675 {ProjectionPoseRoll float {}} \
]

set ebml_Audio [dict create \
    b5 {SamplingFrequency float {}} \
    78b5 {OutputSamplingFrequency float {}} \
    9f {Channels uinteger {}} \
    7d7b {ChannelPositions binary {}} \
    6264 {BitDepth uinteger {}} \
]

set ebml_TrackOperation [dict create \
    e3 {TrackCombinePlanes master TrackCombinePlanes} \
    e9 {TrackJoinBlocks master TrackJoinBlocks} \
]

set ebml_TrackCombinePlanes [dict create \
    e4 {TrackPlane master TrackPlane} \
]

set ebml_TrackPlane [dict create \
    e5 {TrackPlaneUID uinteger {}} \
    e6 {TrackPlaneType uinteger {}} \
]

set ebml_TrackJoinBlocks [dict create \
    ed {TrackJoinUID uinteger {}} \
]

set ebml_ContentEncodings [dict create \
    6240 {ContentEncoding master ContentEncoding} \
]

set ebml_ContentEncoding [dict create \
    5031 {ContentEncodingOrder uinteger {}} \
    5032 {ContentEncodingScope uinteger {}} \
    5033 {ContentEncodingType uinteger {}} \
    5034 {ContentCompression master ContentCompression} \
    5035 {ContentEncryption master ContentEncryption} \
]

set ebml_ContentCompression [dict create \
    4254 {ContentCompAlgo uinteger {}} \
    4255 {ContentCompSettings binary {}} \
]

set ebml_ContentEncryption [dict create \
    47e1 {ContentEncAlgo uinteger {}} \
    47e2 {ContentEncKeyID binary {}} \
    47e7 {ContentEncAESSettings master ContentEncAESSettings} \
    47e3 {ContentSignature binary {}} \
    47e4 {ContentSigKeyID binary {}} \
    47e5 {ContentSigAlgo uinteger {}} \
    47e6 {ContentSigHashAlgo uinteger {}} \
]

set ebml_ContentEncAESSettings [dict create \
    47e8 {AESSettingsCipherMode uinteger {}} \
]

set ebml_Cues [dict create \
    bb {CuePoint master CuePoint} \
]

set ebml_CuePoint [dict create \
    b3 {CueTime uinteger {}} \
    b7 {CueTrackPositions master CueTrackPositions} \
]

set ebml_CueTrackPositions [dict create \
    f7 {CueTrack uinteger {}} \
    f1 {CueClusterPosition uinteger {}} \
    f0 {CueRelativePosition uinteger {}} \
    b2 {CueDuration uinteger {}} \
    5378 {CueBlockNumber uinteger {}} \
    ea {CueCodecState uinteger {}} \
    db {CueReference master CueReference} \
]

set ebml_CueReference [dict create \
    96 {CueRefTime uinteger {}} \
    97 {CueRefCluster uinteger {}} \
    535f {CueRefNumber uinteger {}} \
    eb {CueRefCodecState uinteger {}} \
]

set ebml_Attachments [dict create \
    61a7 {AttachedFile master AttachedFile} \
]

set ebml_AttachedFile [dict create \
    467e {FileDescription utf-8 {}} \
    466e {FileName utf-8 {}} \
    4660 {FileMimeType string {}} \
    465c {FileData binary {}} \
    46ae {FileUID uinteger {}} \
    4675 {FileReferral binary {}} \
    4661 {FileUsedStartTime uinteger {}} \
    4662 {FileUsedEndTime uinteger {}} \
]

set ebml_Chapters [dict create \
    45b9 {EditionEntry master EditionEntry} \
]

set ebml_EditionEntry [dict create \
    45bc {EditionUID uinteger {}} \
    45bd {EditionFlagHidden uinteger {}} \
    45db {EditionFlagDefault uinteger {}} \
    45dd {EditionFlagOrdered uinteger {}} \
    b6 {ChapterAtom master ChapterAtom} \
]

set ebml_ChapterAtom [dict create \
    73c4 {ChapterUID uinteger {}} \
    5654 {ChapterStringUID utf-8 {}} \
    91 {ChapterTimeStart uinteger {}} \
    92 {ChapterTimeEnd uinteger {}} \
    98 {ChapterFlagHidden uinteger {}} \
    4598 {ChapterFlagEnabled uinteger {}} \
    6e67 {ChapterSegmentUID binary {}} \
    6ebc {ChapterSegmentEditionUID uinteger {}} \
    63c3 {ChapterPhysicalEquiv uinteger {}} \
    8f {ChapterTrack master ChapterTrack} \
    80 {ChapterDisplay master ChapterDisplay} \
    6944 {ChapProcess master ChapProcess} \
]

set ebml_ChapterTrack [dict create \
    89 {ChapterTrackUID uinteger {}} \
]

set ebml_ChapterDisplay [dict create \
    85 {ChapString utf-8 {}} \
    437c {ChapLanguage string {}} \
    437d {ChapLanguageIETF string {}} \
    437e {ChapCountry string {}} \
]

set ebml_ChapProcess [dict create \
    6955 {ChapProcessCodecID uinteger {}} \
    450d {ChapProcessPrivate binary {}} \
    6911 {ChapProcessCommand master ChapProcessCommand} \
]

set ebml_ChapProcessCommand [dict create \
    6922 {ChapProcessTime uinteger {}} \
    6933 {ChapProcessData binary {}} \
]

set ebml_Tags [dict create \
    7373 {Tag master Tag} \
]

set ebml_Tag [dict create \
    63c0 {Targets master Targets} \
    67c8 {SimpleTag master SimpleTag} \
]

set ebml_Targets [dict create \
    68ca {TargetTypeValue uinteger {}} \
    63ca {TargetType string {}} \
    63c5 {TagTrackUID uinteger {}} \
    63c9 {TagEditionUID uinteger {}} \
    63c4 {TagChapterUID uinteger {}} \
    63c6 {TagAttachmentUID uinteger {}} \
]

set ebml_SimpleTag [dict create \
    45a3 {TagName utf-8 {}} \
    447a {TagLanguage string {}} \
    447b {TagLanguageIETF string {}} \
    4484 {TagDefault uinteger {}} \
    4487 {TagString utf-8 {}} \
    4485 {TagBinary binary {}} \
]

type_master [len] "" root
