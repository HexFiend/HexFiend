# Quick and Dirty ZIP Format by Lemnet
# https://en.wikipedia.org/wiki/Zip_(file_format)

little_endian
requires 0 "50 4B 03 04"

while {![end]} {
	set sig [uint32]
	move -4
	if {$sig == 67324752} {
		section "Local file header" {
			uint32 -hex "Signature"
			uint16 -hex "Version needed to extract"
			uint16 -hex "General purpose bit flag"
			uint16 -hex "Compression method"
			uint16 -hex "File last modification time"
			uint16 -hex "File last modification date"
			uint32 -hex "CRC-32"
			set cs [uint32]
			move -4
			uint32 "Compressed size"
			uint32 "Uncompressed size"
			set fnl [uint16]
			move -2
			uint16 "File name length"
			set exl [uint16]
			move -2
			uint16 "Extra field length"
			if {$fnl > 0} {
				ascii $fnl "File name"
			}
			if {$exl > 0} {
				hex $exl "Extra field"
			}
			hex $cs "data"
		}
	} elseif {$sig == 33639248} {
		section "Central directory file header" {
			uint32 -hex "Signature"
			uint16 -hex "Version made by"
			uint16 -hex "Version needed to extract"
			uint16 -hex "General purpose bit flag"
			uint16 -hex "Compression method"
			uint16 -hex "File last modification time"
			uint16 -hex "File last modification date"
			uint32 -hex "CRC-32"
			uint32 "Compressed size"
			uint32 "Uncompressed size"
			set fnl [uint16]
			move -2
			uint16 "File name length"
			set exl [uint16]
			move -2
			uint16 "Extra field length"
			set fcl [uint16]
			move -2
			uint16 "File comment length"
			uint16 "Disk number where file starts"
			uint16 -hex "Internal file attributes"
			uint32 -hex "External file attributes"
			uint32 "Relative offset of local file header"
			if {$fnl > 0} {
				ascii $fnl "File name"
			}
			if {$exl > 0} {
				hex $exl "Extra field"
			}
			if {$fcl > 0} {
				hex $fcl "File comment"
			}
		}
	} elseif {$sig == 101010256} {
		section "End of central directory record" {
			uint32 -hex "Signature"
			uint16 "Number of this disk"
			uint16 "Disk where central directory starts"
			uint16 "Number of central directory records on this disk"
			uint16 "Total number of central directory records"
			uint32 "Size of central directory"
			uint32 "Offset of start of central directory"
			set cl [uint16]
			move -2
			uint16  "Comment length"
			if {$cl > 0} {
				hex $cl "Comment"
			}
		}
	} else {
		entry "error" "sig not recognised"
		break
	}
}
