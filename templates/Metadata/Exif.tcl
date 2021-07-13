# Metadata/Exif.tcl
# 2021 Jul 13 | fosterbrereton | Initial implementation

include "Utility/General.tcl"

proc ExifIFDTagName {tag_number} {
    switch $tag_number {
        11 { return "ProcessingSoftware" }
        254 { return "NewSubfileType" }
        255 { return "SubfileType" }
        256 { return "ImageWidth" }
        257 { return "ImageLength" }
        258 { return "BitsPerSample" }
        259 { return "Compression" }
        262 { return "PhotometricInterpretation" }
        263 { return "Threshholding" }
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
        280 { return "MinSampleValue" }
        281 { return "MaxSampleValue" }
        282 { return "XResolution" }
        283 { return "YResolution" }
        284 { return "PlanarConfiguration" }
        285 { return "PageName" }
        286 { return "XPosition" }
        287 { return "YPosition" }
        288 { return "FreeOffsets" }
        289 { return "FreeByteCounts" }
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
        326 { return "BadFaxLines" }
        327 { return "CleanFaxData" }
        328 { return "ConsecutiveBadFaxLines" }
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
        400 { return "GlobalParametersIFD" }
        401 { return "ProfileType" }
        402 { return "FaxProfile" }
        403 { return "CodingMethods" }
        404 { return "VersionYear" }
        405 { return "ModeNumber" }
        433 { return "Decode" }
        434 { return "DefaultImageColor" }
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
        559 { return "StripRowCounts" }
        700 { return "XMP" }
        18246 { return "Rating" }
        18249 { return "RatingPercent" }
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
        34732 { return "ImageLayer" }
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
        37396 { return "SubjectLocation" }
        37397 { return "ExposureIndex" }
        37398 { return "TIFFEPStandardID" }
        37399 { return "SensingMethod" }
        37500 { return "MakerNote" }
        37510 { return "UserComment" }
        37520 { return "SubsecTime" }
        37521 { return "SubsecTimeOriginal" }
        37522 { return "SubsecTimeDigitized" }
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
        42033 { return "LensSpecification" }
        42034 { return "LensSpecification" }
        42035 { return "LensMake" }
        42036 { return "LensModel" }
        42037 { return "LensSerialNumber" }
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

        34665 { return "ExifIFD" }
        34853 { return "GPSIFD" }
        40965 { return "InteroperabilityIFD" }

        default { return $tag_number }
    }
}

proc ExifIFDFieldByte {count} {
    if {$count <= 16} {
        hex $count "Value"
    } else {
        bytes $count "Value"
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
    set is_remote [expr $total_size > 4]
    set read_pos 0

    if {$is_remote} {
        set offset [uint32 "Remote Offset"]
        set read_pos [pos]
        goto [expr $header_pos + $offset]
    }

    sentry $total_size {
        set result [$read_proc $component_count]
    }

    if {$is_remote} {
        goto $read_pos
    } else {
        set leftovers [expr 4 - $total_size]
        if {$leftovers > 0} {
            set padding_value [hex $leftovers "Padding ($leftovers bytes)"]
            check { $padding_value == 0 }
        }
    }

    return $result
}

proc ExifIFDEntry {header_pos count} {
    # REVISIT: (fosterbrereton) Because of the remote nature of some of these IFD values, the range
    # of the fields can get misinterpreted (because there are multiple ranges, not a single
    # contiguous one.) Selecting the IFD entry in the template breakdown, then, may highlight bytes
    # that are not actually part of the selected IFD entry.
    section "\[ $count \]" {
        set tag_number [uint16 "Tag Number"]
        set field_type [uint16 "Field Type"]
        set component_count [uint32 "Component Count"]
        switch $field_type {
            1  { set tag_value [ExifIFDField $header_pos 1 $component_count ExifIFDFieldByte] }
            2  { set tag_value [ExifIFDField $header_pos 1 $component_count ExifIFDFieldAscii] }
            3  { set tag_value [ExifIFDField $header_pos 2 $component_count ExifIFDFieldWord] }
            4  { set tag_value [ExifIFDField $header_pos 4 $component_count ExifIFDFieldLong] }
            5  { set tag_value [ExifIFDField $header_pos 8 $component_count ExifIFDFieldRational] }
            6  { set tag_value [ExifIFDField $header_pos 1 $component_count ExifIFDFieldByte] }
            7  { set tag_value [ExifIFDField $header_pos 1 $component_count ExifIFDFieldByte] }
            8  { set tag_value [ExifIFDField $header_pos 2 $component_count ExifIFDFieldWord] }
            9  { set tag_value [ExifIFDField $header_pos 4 $component_count ExifIFDFieldLong] }
            10 { set tag_value [ExifIFDField $header_pos 8 $component_count ExifIFDFieldRational] }
            11 { set tag_value [ExifIFDField $header_pos 4 $component_count ExifIFDFieldFloat] }
            12 { set tag_value [ExifIFDField $header_pos 8 $component_count ExifIFDFieldDouble] }
        }

        # Exif has this weird nesting structure that we account for here. IFDs also contain an
        # offset to the _next_ IFD, which is another implicit data structure within Exif.
        if {$tag_number == 34665 || $tag_number == 34853 || $tag_number == 40965} {
            set marker [pos]
            goto [expr $header_pos + $tag_value]
            ExifIFD $header_pos
            goto $marker
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
            set marker [pos]
            goto [expr $header_pos + $next_offset]
            ExifIFD $header_pos
            goto $marker
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
    set read_pos [pos]

    if {$ifd_offset != 8} {
        goto [expr $header_pos + $offset]
    }

    ExifIFD $header_pos

    if {$ifd_offset != 8} {
        goto $read_pos
    }
}
