# Android binary XML format (also resources.arsc)
# Initial template by relikd
#
# based on:
# https://android.googlesource.com/platform/frameworks/base/+/master/libs/androidfw/include/androidfw/ResourceTypes.h
# https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/libs/androidfw/ResourceTypes.cpp
# alternative:
# https://github.com/aosp-mirror/platform_frameworks_base/blob/master/libs/androidfw/include/androidfw/ResourceTypes.h
# https://github.com/aosp-mirror/platform_frameworks_base/blob/master/libs/androidfw/ResourceTypes.cpp

little_endian

proc lookup_type {typ} {
	switch $typ {
		0 { return "Null" }
		1 { return "StringPool" }
		2 { return "Table" }
		3 { return "XmlTree" }
		256 { return "StartNamespace" }
		257 { return "EndNamespace" }
		258 { return "StartElement" }
		259 { return "EndElement" }
		260 { return "CDATA" }
		384 { return "ResourceMap" }
		512 { return "Package" }
		513 { return "TType" }
		514 { return "TTypeSpec" }
		515 { return "Library" }
		516 { return "Overlayable" }
		517 { return "OverlayablePolicy" }
		518 { return "StagedAlias" }
		default { return "Unknown" }
	}
}

proc next_chunk {} {
	set offset [pos]
	set type [uint16 -hex "Type"]
	set header_len [uint16 "Header size (B)"]
	set chunk_len [uint32 "Chunk size (B)"]
	set type_name [lookup_type $type]
	sectionname $type_name
	# offsetHeader, offsetData, offsetNextChunk
	set a [expr $offset + 8]
	set b [expr $offset + $header_len]
	set c [expr $offset + $chunk_len]

	switch $type_name {
		"StringPool" { parse_StringPool $offset $a $b $c }
		"Table" { parse_Table $offset $a $b $c }
		"XmlTree" { parse_XmlTree $offset $a $b $c }
		"StartNamespace" { parse_StartNamespace $offset $a $b $c }
		"EndNamespace" { parse_EndNamespace $offset $a $b $c }
		"StartElement" { parse_StartElement $offset $a $b $c }
		"EndElement" { parse_EndElement $offset $a $b $c }
		"CDATA" { parse_CDATA $offset $a $b $c }
		"ResourceMap" { parse_ResourceMap $offset $a $b $c }
		"Package" { parse_Package $offset $a $b $c }
		"TType" { parse_TType $offset $a $b $c }
		"TTypeSpec" { parse_TTypeSpec $offset $a $b $c }
		"# Library" { parse_Library $offset $a $b $c }
		"# Overlayable" { parse_Overlayable $offset $a $b $c }
		"# OverlayablePolicy" { parse_OverlayablePolicy $offset $a $b $c }
		"# StagedAlias" { parse_StagedAlias $offset $a $b $c }
		default {
			set len [expr $c - $a]
			entry "...?" "($len Bytes)" $len
			goto $c
		}
	}
}


################################################
#
#  Helper
#
################################################

# Each start_Header resets current [pos] to start of header
proc start_Header {offsetHeader offsetData} {
	goto $offsetHeader
	section "Header"
	sectionvalue "(8 + [expr $offsetData - $offsetHeader] Bytes)"
}

# Each start_Data resets current [pos] to start of data
proc start_Data {offsetData offsetNextChunk} {
	goto $offsetData
	section "Data"
	sectionvalue "([expr $offsetNextChunk - $offsetData] Bytes)"
}

# If there are thousands of entries, only show the first X of those
# eval will expose all variables inside this procedure to the calling block
proc truncatable {limit sectName count lastIndex block {vars []}} {
	set maxEntries [expr min($count, $limit)]
	section -collapsed "$sectName" {
		sectionvalue "($count)"
		lassign $vars arg1 arg2 arg3 arg4 arg5 arg6
		for {set i 0} {$i < $maxEntries} {incr i} {
			eval $block
		}
		# truncate
		if {$count > $maxEntries} {
			set len [expr $lastIndex - [pos]]
			if {$len > 0} {
				entry "..." "" $len
			}
			# last entry
			goto $lastIndex
			set i [expr $count - 1]
			eval $block
		}
	}
}

# Boilerplate code to group options into Flags
proc parse_flags {size label listofpairs} {
	set flags 0
	# manual little-endian conversion
	for {set i 0} {$i < $size} {incr i} {
		set flags [expr $flags | [uint8] << ($i * 8)]
	}
	move -$size
	if {$flags == 0} {
		entry $label 0 $size
	} else {
		section $label {
			sectionvalue "raw: $flags"
			# eval $block
			foreach {bits desc} $listofpairs {
				if {$flags & $bits} { entry "$desc" $bits $size }
			}
		}
	}
	move $size
	return $flags
}


################################################
#
#  StringPool
#
################################################

proc parse_StringPool {offset offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	set strCount [uint32 "String count"]
	set styleCount [uint32 "Style count"]
	set flags [parse_flags 4 "Flags" {
		0x1 "Sorted"
		0x100 "UTF8"
	}]
	set strStart [uint32 "Strings start"]
	set styleStart [uint32 "Styles start"]
	endsection

	start_Data $offsetData $offsetNextChunk
	# String indices
	set offsetIndices [pos]
	set lastIdxStr [expr $offsetIndices + ($strCount - 1) * 4]
	truncatable 20 "String Indices" $strCount $lastIdxStr {
		uint32 $i
	}

	# Style indices
	set offsetIndicesStyle [pos]
	set lastIdxStyle [expr $offsetIndicesStyle + ($styleCount - 1) * 4]
	truncatable 20 "Style Indices" $styleCount $lastIdxStyle {
		uint32 $i
	}

	# Strings
	goto $lastIdxStr
	set lastIdx [expr $offset + $strStart + [uint32]]
	goto [expr $offset + $strStart]
	set offsetStr [pos]

	set isUTF8 [expr $flags & 256]
	truncatable 100 "Strings" $strCount $lastIdx {
		stringpool_str $i $arg1 $arg2 $arg3
	} [list $isUTF8 $offsetIndices $offsetStr]

	# Styles
	if {$styleCount > 0} {
		goto $lastIdxStyle
		set lastIdx [expr $offset + $styleStart + [uint32]]
		goto [expr $offset + $styleStart]
		set offsetStyles [pos]

		truncatable 20 "Styles" $styleCount $lastIdx {
			stringpool_style $i $arg1 $arg2
		} [list $offsetIndicesStyle $offsetStyles]
		hex 8 "Style end"
	} else {
		section -collapsed "Styles" {
			sectionvalue "(0)"
		}
	}
	endsection
	goto $offsetNextChunk
}

proc stringpool_str {index isUTF8 offsetIndices offsetData} {
	goto [expr $offsetIndices + $index * 4]
	goto [expr $offsetData + [uint32]]

	if {$isUTF8 == 0} {
		set len [uint16]
		if {($len & 0x8000 ) > 0} {
			set len [expr (($len & 0x7FFFF ) << 16 ) + [uint16]]
		}
		str [expr ($len * 2) + 2] "utf16le" "$index"

	} else {
		set lenA [uint8]
		if {($lenA & 0x80 ) > 0} {
			set lenA [expr (($lenA & 0x7F ) << 8 ) + [uint8]]
		}
		set lenB [uint8]
		if {($lenB & 0x80 ) > 0} {
			set lenB [expr (($lenB & 0x7F ) << 8 ) + [uint8]]
		}
		str [expr $lenB + 1] "utf8" "$index"
	}
}

proc stringpool_style {index offsetIndices offsetData} {
	goto [expr $offsetIndices + $index * 4]
	goto [expr $offsetData + [uint32]]

	section "$index" {
		uint32 "Name"
		uint32 "First char"
		uint32 "Last char"
		move 4
	}
}


################################################
#
#  Table
#
################################################

proc parse_Table {offset offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	uint32 "Package count"
	endsection
	# no data-section because data is remaining document
	goto $offsetData
}


################################################
#
#  XmlTree
#
################################################

proc parse_XmlTree {offset offsetHeader offsetData offsetNextChunk} {
	# no header-section
	# no data-section because data is remaining document
	goto $offsetData
}


################################################
#
#  Namespace
#
################################################

proc parse_StartNamespace {offset offsetHeader offsetData offsetNextChunk} {
	parse_Namespace $offsetHeader $offsetData $offsetNextChunk
}

proc parse_EndNamespace {offset offsetHeader offsetData offsetNextChunk} {
	parse_Namespace $offsetHeader $offsetData $offsetNextChunk
}

proc parse_Namespace {offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	uint32 "Line number"
	int32 "Comment"
	endsection

	start_Data $offsetData $offsetNextChunk
	uint32 "Prefix"
	uint32 "URI"
	endsection
	goto $offsetNextChunk
}


################################################
#
#  StartElement
#
################################################

proc parse_StartElement {offset offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	uint32 "Line number"
	int32 "Comment"
	endsection

	start_Data $offsetData $offsetNextChunk
	int32 "NS"
	uint32 "Name"
	set attr_start [uint16 "Attribute start"]
	set attr_size [uint16 "Attribute size"]
	set attr_count [uint16 "Attribute count"]
	uint16 "Index id"
	uint16 "Index class"
	uint16 "Index style"

	section -collapsed "Attributes" {
		sectionvalue "($attr_count)"
		for {set i 0} {$i < $attr_count} {incr i} {
			section $i {
				uint32 "NS"
				uint32 "Name"
				uint32 -hex "Raw value"
				parse_xml_value
			}
		}
	}
	endsection
	goto $offsetNextChunk
}


################################################
#
#  EndElement
#
################################################

proc parse_EndElement {offset offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	uint32 "Line number"
	int32 "Comment"
	endsection

	start_Data $offsetData $offsetNextChunk
	int32 "NS"
	uint32 "Name"
	endsection
	goto $offsetNextChunk
}


################################################
#
#  CDATA
#
################################################

proc parse_CDATA {offset offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	uint32 "Line number"
	int32 "Comment"
	endsection

	start_Data $offsetData $offsetNextChunk
	uint32 "Raw data"
	parse_xml_value
	endsection
	goto $offsetNextChunk
}


################################################
#
#  ResourceMap
#
################################################

proc parse_ResourceMap {offset offsetHeader offsetData offsetNextChunk} {
	set count [expr ($offsetNextChunk - $offsetData) / 4]
	start_Data $offsetData $offsetNextChunk
	truncatable 100 "Entries" $count [expr $offsetNextChunk - 4] {
		uint32 -hex "$i"
	}
	endsection
	goto $offsetNextChunk
}


################################################
#
#  Package
#
################################################

proc parse_Package {offset offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	uint32 -hex "ID"
	set name [string trimright [utf16 256] "\x00"]
	entry "Name" $name 256 [expr [pos] - 256]
	uint32 "Type string-pool offset"
	uint32 "Type last public index"
	uint32 "Key string-pool offset"
	uint32 "Key last public index"
	uint32 "Type id offset"
	endsection
	# no data-section because package content (data) is encoded in chunks
	goto $offsetData
}


################################################
#
#  TType
#
################################################

proc parse_TType {offset offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	uint8 "ID"
	set flags [parse_flags 1 "Flags" {
		0x01 "Sparse"
		0x02 "Offset16"
	}]
	uint16 "Reserved"
	set count [uint32 "Entry count"]
	set entriesStart [uint32 "Entries start"]
	parse_type_config
	endsection

	start_Data $offsetData $offsetNextChunk
	# Indices
	set offsetIndices [pos]
	set lastIdxStyle [expr $offsetIndices + ($count - 1) * 4]
	truncatable 20 "Indices" $count $lastIdxStyle {
		ttype_data_index "$i" $arg1
	} [list $flags]
	# Data
	parse_ttype_entries [expr $offset + $entriesStart] $offsetNextChunk
	# set remaining [expr $offsetNextChunk - [pos]]
	# entry "remaining" "($remaining Bytes)" $remaining
	endsection
	goto $offsetNextChunk
}

proc ttype_data_index {index flags} {
	if {$flags & 0x01} {
		# sparse
		set idx [uint16]
		set offset [uint16]
		entry "$idx" [expr $offset * 4] 4 [expr [pos] - 4]
	} elseif {$flags & 0x02} {
		# offset16
		set offset [uint16]
		if {$offset == 0xFFFF} {
			entry "$index" "NO_ENTRY" 2 [expr [pos] - 2]
		} else {
			entry "$index" [expr $offset * 4] 2 [expr [pos] - 2]
		}
	} else {
		set offset [uint32]
		if {$offset == 0xFFFFFFFF} {
			entry "$index" "NO_ENTRY" 4 [expr [pos] - 4]
		} else {
			entry "$index" $offset 4 [expr [pos] - 4]
		}
	}
}


################################################
#
#  TTypeSpec
#
################################################

proc parse_TTypeSpec {offset offsetHeader offsetData offsetNextChunk} {
	start_Header $offsetHeader $offsetData
	uint8 "ID"
	uint8 "Res0"
	set typesCount [uint16 "Types count"]
	set entryCount [uint32 "Entry count"]
	endsection

	start_Data $offsetData $offsetNextChunk
	set lastIdxStr [expr [pos] + ($entryCount - 1) * 4]
	truncatable 100 "Configuration Masks" $entryCount $lastIdxStr {
		parse_flags 4 "$i" {
			0x1 "MCC"
			0x2 "MNC"
			0x4 "Locale"
			0x8 "Touchscreen"
			0x10 "Keyboard"
			0x20 "Keyboard Hidden"
			0x40 "Navigation"
			0x80 "Orientation"
			0x100 "Density"
			0x200 "Screen Size"
			0x400 "Version"
			0x800 "Screen Layout"
			0x1000 "UI Mode"
			0x2000 "Smallest Screen Size"
			0x4000 "Layoutdir"
			0x8000 "Screen Round"
			0x10000 "Color Mode"
			0x20000 "Grammatical Gender"
			0x20000000 "Spec Staged Api"
			0x40000000 "Spec Public"
		}
		# last two "spec" flags probably not used (likely computed)
	}
	endsection
	goto $offsetNextChunk
}


################################################
#
#  XXX
#
################################################

# proc parse_XXX {offset offsetHeader offsetData offsetNextChunk} {
# 	start_Header $offsetHeader $offsetData
# 	endsection
# 	start_Data $offsetData $offsetNextChunk
# 	endsection
# 	goto $offsetNextChunk
# }

# Missing:
# "Library"
# "Overlayable"
# "OverlayablePolicy"
# "StagedAlias"


################################################
#
#  ResValue
#
################################################

proc parse_xml_value {} {
	uint16 "Size"
	uint8 "Res0"
	set type [uint8]
	entry "Data type" [lookup_dataType $type] 1 [expr [pos] - 1]
	set data [uint32 "Raw data"]
	entry "Computed" [computed_value $type $data] 4 [expr [pos] - 4]
}

proc lookup_dataType {typ} {
	switch $typ {
		0 { return "Null" }
		1 { return "Reference" }
		2 { return "Attribute" }
		3 { return "String" }
		4 { return "Float" }
		5 { return "Dimension" }
		6 { return "Fraction" }
		7 { return "DynamicReference" }
		8 { return "DynamicAttribute" }
		16 { return "IntDec" }
		17 { return "IntHex" }
		18 { return "IntBoolean" }
		28 { return "IntColorARGB8" }
		29 { return "IntColorRGB8" }
		30 { return "IntColorARGB4" }
		31 { return "IntColorRGB4" }
	}
}

proc computed_value {typ data} {
	switch $typ {
		0 {
			switch $data {
				0 { return "(null)" }
				1 { return "(null empty)" }
				default { return [format "(null) 0x%08x", $data] }
			}
		}
		1 { return [format "@%08X" $data] }
		2 { return [format "?%08X" $data] }
		3 { return $data }
		4 {
			binary scan [binary format I $data] R floatValue
			return [format "%g" $floatValue]
		}
		5 { return "[complex_value $data][complex_dimension $data]" }
		6 { return "[complex_value $data][complex_fraction $data]" }
		7 { return [format "@%08X" $data] }
		8 { return [format "?%08X" $data] }
		16 { return [format "%d" $data] }
		17 { return [format "0x%08x" $data] }
		18 { if {$data > 0} { return "true" } else { return "false" } }
		28 { return [format "#%08x" $data] }
		29 { return [format "#%08x" $data] }
		30 { return [format "#%08x" $data] }
		31 { return [format "#%08x" $data] }
	}
}

proc complex_value {complex} {
	set mul [expr $complex & 0xffffff00 ]
	switch [expr ($complex >> 4) & 0x3 ] {
		0 { return [expr $mul * 1.0 / (1 << 8) ] }
		1 { return [expr $mul * 1.0 / (1 << 7) * 1.0 / (1 << 8) ] }
		2 { return [expr $mul * 1.0 / (1 << 15) * 1.0 / (1 << 8) ] }
		3 { return [expr $mul * 1.0 / (1 << 23) * 1.0 / (1 << 8) ] }
	}
}

proc complex_fraction {complex} {
	switch [expr $complex & 0xf ] {
		0 { return "%" }
		1 { return "%p" }
		default { return "" }
	}
}

proc complex_dimension {complex} {
	switch [expr $complex & 0xf ] {
		0 { return "px" }
		1 { return "dp" }
		2 { return "sp" }
		3 { return "pt" }
		4 { return "in" }
		5 { return "mm" }
		default { return "" }
	}
}


################################################
#
#  Type Config
#
################################################

proc parse_type_config {} {
	set configStart [pos]
	section -collapsed "Config" {
		set size [uint32 "Size"]
		# uint32 "IMSI"
		# uint32 "Locale"
		# uint32 "Screen Type"
		# uint32 "Input Type"
		# uint32 "Screen Size"
		# uint32 "Version"
		# uint32 "Screen Config"
		# uint32 "Screen Size DP"
		section "IMSI" {
			uint16 "mcc"
			uint16 "mnc"
		}
		section "Locale" {
			uint16 "Language"
			uint16 "Country"
		}
		section "Screen Type" {
			uint8 "Orientation"
			uint8 "Touchscreen"
			uint16 "Density"
		}
		section "Input Type" {
			uint8 "Keyboard"
			uint8 "Navigation"
			uint8_bits 3,2 "Nav Hidden"
			move -1
			uint8_bits 1,0 "Keys Hidden"
			uint8_bits 1,0 "Grammatical Gender"
		}
		section "Screen Size" {
			uint16 "screenWidth"
			uint16 "screenHeight"
		}
		section "Version" {
			uint16 "SDK Version"
			uint16 "Minor Version"
		}
		section "Screen Config" {
			uint8_bits 7,6 "Layout Direction"
			move -1
			uint8_bits 5,4 "Layout Long"
			move -1
			uint8_bits 3,2,1,0 "Layout Size"
			uint8_bits 5,4 "UI Mode Night"
			move -1
			uint8_bits 3,2,1,0 "UI Mode Type"
			uint16 "Smallest Screen Width DP"
		}
		section "Screen Size DP" {
			uint16 "Screen Width DP"
			uint16 "Screen Height DP"
		}
		ascii 4 "Locale Script"
		ascii 8 "Locale Variant"
		# uint32 "Screen Config 2"
		section "Screen Config 2" {
			uint8_bits 1,0 "Layout Round"
			uint8_bits 3,2 "Color Mode HDR"
			move -1
			uint8_bits 1,0 "Color Mode Wide Gamut"
			uint16 "Pad2"
		}
		# actually a boolean
		uint32 "Locale Script Was Computed"
		ascii 8 "Locale Numbering System"
		goto [expr $configStart + $size]
	}
}


################################################
#
#  Type Entry
#
################################################

proc parse_ttype_entries {offsetEntries offsetEnd} {
	section -collapsed "Entries" {
		sectionvalue "([expr $offsetEnd - $offsetEntries] Bytes)"
		set i 0
		while {[pos] < $offsetEnd} {
			section "$i" {
				move 2
				set isCompact [expr [uint16] & 0x8]
				move -4
				if {$isCompact} {
					ttype_entry_compact
				} else {
					ttype_entry_full
				}
			}
			set i [expr $i + 1]
			# limit to X entries
			if {$i > 10} {
				set len [expr $offsetEnd - [pos]]
				if {$len > 0} {
					entry "remaining" "..." $len
					goto $offsetEnd
				}
			}
		}
	}
}

proc ttype_entry_compact {} {
	sectionvalue "(compact)"
	uint16 "Key"
	parse_flags 1 "Flags" {
		0x01 "Complex"
		0x02 "Public"
		0x04 "Weak"
		0x08 "Compact"
	}
	uint8 "Type"
	uint32 "Data"
	# thats it. The whole entry is encoded in 8 bytes
}

proc ttype_entry_full {} {
	uint16 "Size"
	set flags [parse_flags 2 "Flags" {
		0x0001 "Complex"
		0x0002 "Public"
		0x0004 "Weak"
		0x0008 "Compact"
	}]
	uint32 "Key"
	if {$flags & 0x1} {
		sectionvalue "(complex)"
		uint32 "Parent"
		set count [uint32 "Count"]
		section -collapsed "Map" {
			sectionvalue "($count)"
			for {set i 0} {$i < $count} {incr i} {
				section "$i" {
					uint32 -hex "Name"
					parse_xml_value
				}
			}
		}
	} else {
		sectionvalue "(full)"
		section "Value" {
			parse_xml_value
		}
	}
}

proc parse_table_ref {} {
	# The highest 8 bits of uint32 are the package.
	# But because of little-endian, we invert the order here
	uint16 "Entry"
	uint8 "Type"
	uint8 -hex "Package"
}

# main entry
while {![end]} {
	section "" {
		next_chunk
	}
}
