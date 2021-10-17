# Based on:
#   https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc776720(v=ws.10)
#   http://msdn.microsoft.com/en-us/windows/hardware/gg463080.aspx

requires 510 "55 AA"

# BIOS Parameter Block (BPB)
hex 3 JumpBoot
ascii 8 OEM
set block_size [uint16 BytesPerSector]
uint8 SectorsPerCluster
uint16 ReservedSectorsCount
uint8 NumberOfFATs
uint16 RootEntriesCount
uint16 SectorsCount
uint8 MediaDescriptor
bytes 2 Unused
uint16 SectorsPerTrack
uint16 NumberOfHeads
uint32 HiddenSectorsCount
uint32 LargeSectorsCount

# Extended BIOS Parameter Block
uint32 SectorsPerFAT
hex 2 Flags
uint16 VersionOfFAT
uint32 RootDirectoryClusterNumber
set fsinfo_block [uint16 FSInfoSectorNumber]
uint16 BackupBootSectorClusterNumber
hex 12 Reserved

uint8 DriveNumber
hex 1 Reserved
hex 1 ExtendedBootSignature
uint32 SerialNumber
ascii 11 VolumeLabel
ascii 8 SystemIdentifier
hex 420 Bootcode

hex 2 Signature

set fsinfo_offset [expr $fsinfo_block * $block_size]
goto $fsinfo_offset

requires $fsinfo_offset "52 52 61 41"
requires [expr $fsinfo_offset + 484] "72 72 41 61"
requires [expr $fsinfo_offset + 508] "00 00 55 AA"

section "FSInfo" {
    # LeadSignature is always 0x41615252
    hex 4 LeadSignature
    hex 480 Reserved1
    # StructSignature is always 0x61417272
    hex 4 StructSignature
    uint32 FreeClusterCount
    uint32 NextFreeCluster
    hex 12 Reserved2
    # TrailSignature is always 0xAA550000
    hex 4 TrailSignature
}
