big_endian
requires 0 "78617221" ;# xar!
ascii 4 "Signature"
uint16 "Header Size"
uint16 "Version"
set compressed_length [uint64 "TOC Compressed Length"]
uint64 "TOC Uncompressed Length"
uint32 "Checksum"
set compressed_data [bytes $compressed_length "TOC Data"]
set xml [zlib_uncompress $compressed_data]

#puts "${xml}"
package require tdom
set doc [dom parse $xml]
set root [$doc documentElement]
set nodes [$root selectNodes "//file"]
section "Files" {
	foreach node $nodes {
		section [[lindex [$node getElementsByTagName "name"] 0] text] {
			entry "ID" [$node getAttribute "id"]
			entry "Type" [[lindex [$node getElementsByTagName "type"] 0] text]
			entry "User" [[lindex [$node getElementsByTagName "user"] 0] text]
			entry "Group" [[lindex [$node getElementsByTagName "group"] 0] text]
			entry "UID" [[lindex [$node getElementsByTagName "uid"] 0] text]
			entry "GID" [[lindex [$node getElementsByTagName "gid"] 0] text]
			entry "Mode" [[lindex [$node getElementsByTagName "mode"] 0] text]
		}
	}
}
