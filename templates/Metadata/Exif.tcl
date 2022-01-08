# Metadata/Exif.tcl
# 2021 Jul 13 | fosterbrereton | Initial implementation

hf_min_version_required 2.15

include "Utility/General.tcl"

proc ExifIFDTagName {tag_number} {
    # Tags 0 - 30 are for the GPS IFD. There's one collision between GPSIFD and the ExifIFD
    # names - number 11 - which I think is acceptable.
    # 11 in the ExifIFD is "ProcessingSoftware"
    switch $tag_number {
        0 { return "GPSVersionID" }
        1 { return "GPSLatitudeRef" }
        2 { return "GPSLatitude" }
        3 { return "GPSLongitudeRef" }
        4 { return "GPSLongitude" }
        5 { return "GPSAltitudeRef" }
        6 { return "GPSAltitude" }
        7 { return "GPSTimeStamp" }
        8 { return "GPSSatellites" }
        9 { return "GPSStatus" }
        10 { return "GPSMeasureMode" }
        11 { return "GPSDOP" } 
        12 { return "GPSSpeedRef" }
        13 { return "GPSSpeed" }
        14 { return "GPSTrackRef" }
        15 { return "GPSTrack" }
        16 { return "GPSImgDirectionRef" }
        17 { return "GPSImgDirection" }
        18 { return "GPSMapDatum" }
        19 { return "GPSDestLatitudeRef" }
        20 { return "GPSDestLatitude" }
        21 { return "GPSDestLongitudeRef" }
        22 { return "GPSDestLongitude" }
        23 { return "GPSDestBearingRef" }
        24 { return "GPSDestBearing" }
        25 { return "GPSDestDistanceRef" }
        26 { return "GPSDestDistance" }
        27 { return "GPSProcessingMethod" }
        28 { return "GPSAreaInformation" }
        29 { return "GPSDateStamp" }
        30 { return "GPSDifferential" }
        31 { return "GPSHPositioningError" }
        254 { return "NewSubfileType" }
        255 { return "SubfileType" }
        256 { return "ImageWidth" }
        257 { return "ImageLength" }
        258 { return "BitsPerSample" }
        259 { return "Compression" }
        262 { return "PhotometricInterpretation" }
        263 { return "Thresholding" }
        264 { return "CellWidth" }
        265 { return "CellLength" }
        266 { return "FillOrder" }
        269 { return "DocumentName" }
        270 { return "ImageDescription" }
        271 { return "Make" }
        272 { return "Model" }
        273 { return "StripOffsets" }
        274 { return "Orientation" }
        277 { return "SamplesPerPixel" }
        278 { return "RowsPerStrip" }
        279 { return "StripByteCounts" }
        282 { return "XResolution" }
        283 { return "YResolution" }
        284 { return "PlanarConfiguration" }
        290 { return "GrayResponseUnit" }
        291 { return "GrayResponseCurve" }
        292 { return "T4Options" }
        293 { return "T6Options" }
        296 { return "ResolutionUnit" }
        297 { return "PageNumber" }
        301 { return "TransferFunction" }
        305 { return "Software" }
        306 { return "DateTime" }
        315 { return "Artist" }
        316 { return "HostComputer" }
        317 { return "Predictor" }
        318 { return "WhitePoint" }
        319 { return "PrimaryChromaticities" }
        320 { return "ColorMap" }
        321 { return "HalftoneHints" }
        322 { return "TileWidth" }
        323 { return "TileLength" }
        324 { return "TileOffsets" }
        325 { return "TileByteCounts" }
        330 { return "SubIFDs" }
        332 { return "InkSet" }
        333 { return "InkNames" }
        334 { return "NumberOfInks" }
        336 { return "DotRange" }
        337 { return "TargetPrinter" }
        338 { return "ExtraSamples" }
        339 { return "SampleFormat" }
        340 { return "SMinSampleValue" }
        341 { return "SMaxSampleValue" }
        342 { return "TransferRange" }
        343 { return "ClipPath" }
        344 { return "XClipPathUnits" }
        345 { return "YClipPathUnits" }
        346 { return "Indexed" }
        347 { return "JPEGTables" }
        351 { return "OPIProxy" }
        512 { return "JPEGProc" }
        513 { return "JPEGInterchangeFormat" }
        514 { return "JPEGInterchangeFormatLength" }
        515 { return "JPEGRestartInterval" }
        517 { return "JPEGLosslessPredictors" }
        518 { return "JPEGPointTransforms" }
        519 { return "JPEGQTables" }
        520 { return "JPEGDCTables" }
        521 { return "JPEGACTables" }
        529 { return "YCbCrCoefficients" }
        530 { return "YCbCrSubSampling" }
        531 { return "YCbCrPositioning" }
        532 { return "ReferenceBlackWhite" }
        700 { return "XMLPacket" }
        18246 { return "Rating" }
        18249 { return "RatingPercent" }
        28722 { return "VignettingCorrParams" }
        28725 { return "ChromaticAberrationCorrParams" }
        28727 { return "DistortionCorrParams" }
        32781 { return "ImageID" }
        33421 { return "CFARepeatPatternDim" }
        33422 { return "CFAPattern" }
        33423 { return "BatteryLevel" }
        33432 { return "Copyright" }
        33434 { return "ExposureTime" }
        33437 { return "FNumber" }
        33723 { return "IPTCNAA" }
        34377 { return "ImageResources" }
        34665 { return "ExifTag" }
        34675 { return "InterColorProfile" }
        34850 { return "ExposureProgram" }
        34852 { return "SpectralSensitivity" }
        34853 { return "GPSTag" }
        34855 { return "ISOSpeedRatings" }
        34856 { return "OECF" }
        34857 { return "Interlace" }
        34858 { return "TimeZoneOffset" }
        34859 { return "SelfTimerMode" }
        34864 { return "SensitivityType" }
        34865 { return "StandardOutputSensitivity" }
        34866 { return "RecommendedExposureIndex" }
        34867 { return "ISOSpeed" }
        34868 { return "ISOSpeedLatitudeyyy" }
        34869 { return "ISOSpeedLatitudezzz" }
        36864 { return "ExifVersion" }
        36867 { return "DateTimeOriginal" }
        36868 { return "DateTimeDigitized" }
        36880 { return "OffsetTime" }
        36881 { return "OffsetTimeOriginal" }
        36882 { return "OffsetTimeDigitized" }
        37121 { return "ComponentsConfiguration" }
        37122 { return "CompressedBitsPerPixel" }
        37377 { return "ShutterSpeedValue" }
        37378 { return "ApertureValue" }
        37379 { return "BrightnessValue" }
        37380 { return "ExposureBiasValue" }
        37381 { return "MaxApertureValue" }
        37382 { return "SubjectDistance" }
        37383 { return "MeteringMode" }
        37384 { return "LightSource" }
        37385 { return "Flash" }
        37386 { return "FocalLength" }
        37387 { return "FlashEnergy" }
        37388 { return "SpatialFrequencyResponse" }
        37389 { return "Noise" }
        37390 { return "FocalPlaneXResolution" }
        37391 { return "FocalPlaneYResolution" }
        37392 { return "FocalPlaneResolutionUnit" }
        37393 { return "ImageNumber" }
        37394 { return "SecurityClassification" }
        37395 { return "ImageHistory" }
        37396 { return "SubjectArea" }
        37396 { return "SubjectLocation" }
        37397 { return "ExposureIndex" }
        37398 { return "TIFFEPStandardID" }
        37399 { return "SensingMethod" }
        37500 { return "MakerNote" }
        37510 { return "UserComment" }
        37520 { return "SubSecTime" }
        37521 { return "SubSecTimeOriginal" }
        37522 { return "SubSecTimeDigitized" }
        37888 { return "Temperature" }
        37889 { return "Humidity" }
        37890 { return "Pressure" }
        37891 { return "WaterDepth" }
        37892 { return "Acceleration" }
        37893 { return "CameraElevationAngle" }
        40091 { return "XPTitle" }
        40092 { return "XPComment" }
        40093 { return "XPAuthor" }
        40094 { return "XPKeywords" }
        40095 { return "XPSubject" }
        40960 { return "FlashpixVersion" }
        40961 { return "ColorSpace" }
        40962 { return "PixelXDimension" }
        40963 { return "PixelYDimension" }
        40964 { return "RelatedSoundFile" }
        40965 { return "InteroperabilityTag" }
        41483 { return "FlashEnergy" }
        41484 { return "SpatialFrequencyResponse" }
        41486 { return "FocalPlaneXResolution" }
        41487 { return "FocalPlaneYResolution" }
        41488 { return "FocalPlaneResolutionUnit" }
        41492 { return "SubjectLocation" }
        41493 { return "ExposureIndex" }
        41495 { return "SensingMethod" }
        41728 { return "FileSource" }
        41729 { return "SceneType" }
        41730 { return "CFAPattern" }
        41985 { return "CustomRendered" }
        41986 { return "ExposureMode" }
        41987 { return "WhiteBalance" }
        41988 { return "DigitalZoomRatio" }
        41989 { return "FocalLengthIn35mmFilm" }
        41990 { return "SceneCaptureType" }
        41991 { return "GainControl" }
        41992 { return "Contrast" }
        41993 { return "Saturation" }
        41994 { return "Sharpness" }
        41995 { return "DeviceSettingDescription" }
        41996 { return "SubjectDistanceRange" }
        42016 { return "ImageUniqueID" }
        42032 { return "CameraOwnerName" }
        42033 { return "BodySerialNumber" }
        42034 { return "LensSpecification" }
        42035 { return "LensMake" }
        42036 { return "LensModel" }
        42037 { return "LensSerialNumber" }
        42080 { return "CompositeImage" }
        42081 { return "SourceImageNumberOfCompositeImage" }
        42082 { return "SourceExposureTimesOfCompositeImage" }
        50341 { return "PrintImageMatching" }
        50706 { return "DNGVersion" }
        50707 { return "DNGBackwardVersion" }
        50708 { return "UniqueCameraModel" }
        50709 { return "LocalizedCameraModel" }
        50710 { return "CFAPlaneColor" }
        50711 { return "CFALayout" }
        50712 { return "LinearizationTable" }
        50713 { return "BlackLevelRepeatDim" }
        50714 { return "BlackLevel" }
        50715 { return "BlackLevelDeltaH" }
        50716 { return "BlackLevelDeltaV" }
        50717 { return "WhiteLevel" }
        50718 { return "DefaultScale" }
        50719 { return "DefaultCropOrigin" }
        50720 { return "DefaultCropSize" }
        50721 { return "ColorMatrix1" }
        50722 { return "ColorMatrix2" }
        50723 { return "CameraCalibration1" }
        50724 { return "CameraCalibration2" }
        50725 { return "ReductionMatrix1" }
        50726 { return "ReductionMatrix2" }
        50727 { return "AnalogBalance" }
        50728 { return "AsShotNeutral" }
        50729 { return "AsShotWhiteXY" }
        50730 { return "BaselineExposure" }
        50731 { return "BaselineNoise" }
        50732 { return "BaselineSharpness" }
        50733 { return "BayerGreenSplit" }
        50734 { return "LinearResponseLimit" }
        50735 { return "CameraSerialNumber" }
        50736 { return "LensInfo" }
        50737 { return "ChromaBlurRadius" }
        50738 { return "AntiAliasStrength" }
        50739 { return "ShadowScale" }
        50740 { return "DNGPrivateData" }
        50741 { return "MakerNoteSafety" }
        50778 { return "CalibrationIlluminant1" }
        50779 { return "CalibrationIlluminant2" }
        50780 { return "BestQualityScale" }
        50781 { return "RawDataUniqueID" }
        50827 { return "OriginalRawFileName" }
        50828 { return "OriginalRawFileData" }
        50829 { return "ActiveArea" }
        50830 { return "MaskedAreas" }
        50831 { return "AsShotICCProfile" }
        50832 { return "AsShotPreProfileMatrix" }
        50833 { return "CurrentICCProfile" }
        50834 { return "CurrentPreProfileMatrix" }
        50879 { return "ColorimetricReference" }
        50931 { return "CameraCalibrationSignature" }
        50932 { return "ProfileCalibrationSignature" }
        50933 { return "ExtraCameraProfiles" }
        50934 { return "AsShotProfileName" }
        50935 { return "NoiseReductionApplied" }
        50936 { return "ProfileName" }
        50937 { return "ProfileHueSatMapDims" }
        50938 { return "ProfileHueSatMapData1" }
        50939 { return "ProfileHueSatMapData2" }
        50940 { return "ProfileToneCurve" }
        50941 { return "ProfileEmbedPolicy" }
        50942 { return "ProfileCopyright" }
        50964 { return "ForwardMatrix1" }
        50965 { return "ForwardMatrix2" }
        50966 { return "PreviewApplicationName" }
        50967 { return "PreviewApplicationVersion" }
        50968 { return "PreviewSettingsName" }
        50969 { return "PreviewSettingsDigest" }
        50970 { return "PreviewColorSpace" }
        50971 { return "PreviewDateTime" }
        50972 { return "RawImageDigest" }
        50973 { return "OriginalRawFileDigest" }
        50974 { return "SubTileBlockSize" }
        50975 { return "RowInterleaveFactor" }
        50981 { return "ProfileLookTableDims" }
        50982 { return "ProfileLookTableData" }
        51008 { return "OpcodeList1" }
        51009 { return "OpcodeList2" }
        51022 { return "OpcodeList3" }
        51041 { return "NoiseProfile" }
        51043 { return "TimeCodes" }
        51044 { return "FrameRate" }
        51058 { return "TStop" }
        51081 { return "ReelName" }
        51089 { return "OriginalDefaultFinalSize" }
        51090 { return "OriginalBestQualityFinalSize" }
        51091 { return "OriginalDefaultCropSize" }
        51105 { return "CameraLabel" }
        51107 { return "ProfileHueSatMapEncoding" }
        51108 { return "ProfileLookTableEncoding" }
        51109 { return "BaselineExposureOffset" }
        51110 { return "DefaultBlackRender" }
        51111 { return "NewRawImageDigest" }
        51112 { return "RawToPreviewGain" }
        51113 { return "CacheBlob" }
        51114 { return "CacheVersion" }
        51125 { return "DefaultUserCrop" }
        51177 { return "DepthFormat" }
        51178 { return "DepthNear" }
        51179 { return "DepthFar" }
        51180 { return "DepthUnits" }
        51181 { return "DepthMeasureType" }
        51182 { return "EnhanceParams" }
        52525 { return "ProfileGainTableMap" }
        52526 { return "SemanticName" }
        52528 { return "SemanticInstanceID" }
        52529 { return "CalibrationIlluminant3" }
        52530 { return "CameraCalibration3" }
        52531 { return "ColorMatrix3" }
        52532 { return "ForwardMatrix3" }
        52533 { return "IlluminantData1" }
        52534 { return "IlluminantData2" }
        52535 { return "IlluminantData3" }
        52537 { return "ProfileHueSatMapData3" }
        52538 { return "ReductionMatrix3" }
        65024 { return "KodakKDCPrivateIFD" }

        default { return "Unknown ($tag_number)" }
    }
}

proc ExifIFDFieldByte {count} {
    if {$count <= 16} {
        hex $count "Value"
    } else {
        entry "Value" "$count bytes" $count
        bytes $count
        return "$count bytes"
    }
}

proc ExifIFDFieldAscii {count} {
    ascii $count "Value"
}

proc ExifIFDFieldWord {count} {
    if {$count == 1} {
        uint16 "Value"
    } else {
        for {set i 0} {$i < $count} {incr i} {
            uint16 "Value\[ $i \]"
        }
        return "$count words"
    }
}

proc ExifIFDFieldSWord {count} {
    if {$count == 1} {
        int16 "Value"
    } else {
        for {set i 0} {$i < $count} {incr i} {
            int16 "Value\[ $i \]"
        }
        return "$count words"
    }
}

proc ExifIFDFieldLong {count} {
    if {$count == 1} {
        uint32 "Value"
    } else {
        for {set i 0} {$i < $count} {incr i} {
            uint32 "Value\[ $i \]"
        }
        return "$count longs"
    }
}

proc ExifIFDFieldSLong {count} {
    if {$count == 1} {
        int32 "Value"
    } else {
        for {set i 0} {$i < $count} {incr i} {
            int32 "Value\[ $i \]"
        }
        return "$count longs"
    }
}

proc ExifIFDFieldRational {count} {
    if {$count == 1} {
        set num [uint32]
        set den [uint32]
        set value [expr double($num) / $den]
        entry "Value" "$value ($num / $den)" 8 [expr [pos] - 8]
        return $value
    } else {
        for {set i 0} {$i < $count} {incr i} {
            set num [uint32]
            set den [uint32]
            if {$den != 0} {
                set value [expr double($num) / $den]
                entry "Value\[ $i \]" "$value ($num / $den)" 8 [expr [pos] - 8]
            } else {
                entry "Value\[ $i \]" "NaN ($num / $den)" 8 [expr [pos] - 8]
            }
        }
        return "$count rationals"
    }
}

proc ExifIFDFieldSRational {count} {
    if {$count == 1} {
        set num [int32]
        set den [int32]
        set value [expr double($num) / $den]
        entry "Value" "$value ($num / $den)" 8 [expr [pos] - 8]
        return $value
    } else {
        for {set i 0} {$i < $count} {incr i} {
            set num [int32]
            set den [int32]
            if {$den != 0} {
                set value [expr double($num) / $den]
                entry "Value\[ $i \]" "$value ($num / $den)" 8 [expr [pos] - 8]
            } else {
                entry "Value\[ $i \]" "NaN ($num / $den)" 8 [expr [pos] - 8]
            }
        }
        return "$count rationals"
    }
}

proc ExifIFDFieldFloat {count} {
    if {$count == 1} {
        float "Value"
    } else {
        for {set i 0} {$i < $count} {incr i} {
            float "Value\[ $i \]"
        }
        return "$count floats"
    }
}

proc ExifIFDFieldDouble {count} {
    if {$count == 1} {
        double "Value"
    } else {
        for {set i 0} {$i < $count} {incr i} {
            double "Value\[ $i \]"
        }
        return "$count doubles"
    }
}

proc ExifIFDField {header_pos field_size component_count read_proc} {
    set total_size [expr $component_count * $field_size]
    if {$total_size == 0} {
        set result "(Empty)"
    } elseif {$total_size > 4} {
        set offset [uint32 "Remote Offset"]
        jumpa [expr $header_pos + $offset] {
            set result [$read_proc $component_count]
            set result "$result (Remote)"
        }
    } else {
        set result [$read_proc $component_count]
        set leftovers [expr 4 - $total_size]
        if {$leftovers > 0} {
            set padding_value [hex $leftovers "Padding ($leftovers bytes)"]
            check { $padding_value == 0 }
        }
    }

    return $result
}

proc ExifJumpToIFD {header_pos offset} {
    jumpa [expr $header_pos + $offset] {
        ExifIFD $header_pos
    }
}

proc ExifHandleSubIFDTag {header_pos tag_pos} {
    jumpa $tag_pos {
        assert { [uint16] == 330 } "expected SubIFD tag number"
        assert { [uint16] == 4 } "expected uint32 component type"
        set count [uint32]
        set total_size [expr 4 * $count]
        set offset [uint32]
        if {$total_size <= 4} {
            ExifJumpToIFD $header_pos $offset
        } else {
            jumpa [expr $header_pos + $offset] {
                for {set i 0} {$i < $count} {incr i} {
                    ExifJumpToIFD $header_pos [uint32]
                }
            }
        }
    }
}

proc ExifIFDEntry {header_pos count} {
    # REVISIT: (fosterbrereton) Because of the remote nature of some of these IFD values, the range
    # of the fields can get misinterpreted (because there are multiple ranges, not a single
    # contiguous one.) Selecting the IFD entry in the template breakdown, then, may highlight bytes
    # that are not actually part of the selected IFD entry.
    section "\[ $count \]" {
        set tag_pos [pos]
        set tag_number [uint16 "Tag Number"]
        set field_type [uint16]
        set field_type_str "unknown"
        switch $field_type {
            1  { set field_type_str "uint8" }
            2  { set field_type_str "ascii" }
            3  { set field_type_str "uint16" }
            4  { set field_type_str "uint32" }
            5  { set field_type_str "urational" }
            6  { set field_type_str "sint8" }
            7  { set field_type_str "undefined" }
            8  { set field_type_str "sint16" }
            9  { set field_type_str "sint32" }
            10 { set field_type_str "srational" }
            11 { set field_type_str "float" }
            12 { set field_type_str "double" }
        }
        entry "Type" "$field_type_str" 2 [expr [pos] - 2]
        set component_count [uint32 "Count"]
        switch $field_type {
            1  { set tag_value [ExifIFDField $header_pos 1 $component_count ExifIFDFieldByte] }
            2  { set tag_value [ExifIFDField $header_pos 1 $component_count ExifIFDFieldAscii] }
            3  { set tag_value [ExifIFDField $header_pos 2 $component_count ExifIFDFieldWord] }
            4  { set tag_value [ExifIFDField $header_pos 4 $component_count ExifIFDFieldLong] }
            5  { set tag_value [ExifIFDField $header_pos 8 $component_count ExifIFDFieldRational] }
            6  { set tag_value [ExifIFDField $header_pos 1 $component_count ExifIFDFieldByte] }
            7  { set tag_value [ExifIFDField $header_pos 1 $component_count ExifIFDFieldByte] }
            8  { set tag_value [ExifIFDField $header_pos 2 $component_count ExifIFDFieldSWord] }
            9  { set tag_value [ExifIFDField $header_pos 4 $component_count ExifIFDFieldSLong] }
            10 { set tag_value [ExifIFDField $header_pos 8 $component_count ExifIFDFieldSRational] }
            11 { set tag_value [ExifIFDField $header_pos 4 $component_count ExifIFDFieldFloat] }
            12 { set tag_value [ExifIFDField $header_pos 8 $component_count ExifIFDFieldDouble] }
            default { die "Bad field_type: $field_type" }
        }

        # Exif has this weird nesting structure that we account for here. IFDs also contain an
        # offset to the _next_ IFD, which is another implicit data structure within Exif.
        if {$tag_number == 34665 || $tag_number == 34853 || $tag_number == 40965 || $tag_number == 65024} {
            ExifJumpToIFD $header_pos $tag_value
        } elseif {$tag_number == 330} {
            ExifHandleSubIFDTag $header_pos $tag_pos
        }

        # REVISIT: (fosterbrereton) We need to switch to GPS and interop tag names for those IFDs.
        sectionname [ExifIFDTagName $tag_number]
        sectionvalue $tag_value
    }
}

proc ExifIFD {header_pos} {
    section "IFD" {
        set count [uint16 "Entry Count"]
        section "Entries" {
            for {set i 0} {$i < $count} {incr i} {
                ExifIFDEntry $header_pos $i
            }
            sectionvalue "$count entries"
        }

        set next_offset [uint32 "Next IFD Offset"]
        if {$next_offset != 0} {
            ExifJumpToIFD $header_pos $next_offset
        }

        sectionvalue "$count entries"
    }
}

proc Exif {} {
    set header_pos [pos]
    set header [hex 2]

    if {$header == 0x4D4D} {
        big_endian
        entry "Header" "$header (Big Endian)" 2 [expr [pos] - 2]
    } elseif {$header == 0x4949} {
        little_endian
        entry "Header" "$header (Little Endian)" 2 [expr [pos] - 2]
    } else {
        die "bad header"
    }

    set tag_mark [uint16 "Tag Mark"]
    check { $tag_mark == 42 }

    set ifd_offset [uint32 "IFD Offset"]
    ExifJumpToIFD $header_pos $ifd_offset
}
