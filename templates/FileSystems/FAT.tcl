# Based on:
#   https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc776720(v=ws.10)
#   http://msdn.microsoft.com/en-us/windows/hardware/gg463080.aspx

requires 510 "55 AA"

# BIOS Parameter Block (BPB)
hex 3 JumpBoot
ascii 8 OEM
uint16 BytesPerSector
uint8 SectorsPerCluster
uint16 ReservedSectorsCount
uint8 NumberOfFATs
uint16 RootEntriesCount
uint16 SectorsCount
uint8 MediaDescriptor
uint16 SectorsPerFAT
uint16 SectorsPerTrack
uint16 NumberOfHeads
uint32 HiddenSectorsCount
uint32 LargeSectorsCount

# Extended BIOS Parameter Block
uint8 DriveNumber
hex 1 Reserved
hex 1 ExtendedBootSignature
uint32 SerialNumber
ascii 11 VolumeLabel
ascii 8 SystemIdentifier
hex 448 Bootcode

hex 2 Signature
