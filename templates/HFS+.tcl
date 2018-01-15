# "Located 1024 bytes from the start of the volume"
# Based on https://www.x-ways.net/winhex/templates/HFSPlus_Volume_Header.tpl

# A copy of this volume header, the alternate volume header, is stored starting 1024 bytes before the end of the volume.

big_endian

ascii 2	"Signature" ;# H+ or HX
uint16	"Version"
hex 4	"Attributes" ; # 00 00 08 00 set? Volume Inconsistent!
ascii 4 "LastMountedVersion" ;# HFSJ if journaled, 10.0 if not; fsck and other tools also possible
uint32 "JournalInfoBlock"

macdate	"CreateDate"
macdate	"ModifyDate"
macdate	"BackupDate"
macdate	"CheckedDate"

uint32	"FileCount"
uint32	"FolderCount"

uint32	"BlockSize"
uint32	"TotalBlocks"
uint32	"FreeBlocks"

uint32	"NextAllocation"
uint32	"RsrcClumpSize"
uint32	"DataClumpSize"
uint32	"NextCatalogID"

uint32	"WriteCount"
hex 8	"EncodingsBitmap"

section "FinderInfo Array" {
	uint32	"OS Dir ID"
	uint32	"Finder Dir ID"
	uint32	"Mount Open Dir"
	uint32	"OS8/9 Dir ID"
	uint32	"Reserved"
	uint32	"OS X Dir ID"
	hex 8   "Volume ID"
}

foreach {file} [list Allocation ExtentsOverflow Catalog Attributes Startup] {
	section "$file File" {
		uint64	"LogicalSize"
		uint32	"ClumpSize"
		uint32	"TotalBlocks"
		for {set i 0} {$i < 10} {incr i} {
			uint32	"StartBlock"
			uint32	"BlockCount"
		}
	}
}
