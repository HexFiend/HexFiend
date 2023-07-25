# Executable and Linkable Format
# embbededc 2021 

little_endian

section "File Header" {
  ascii 4 "File identification"
  set ei_class [uint8 -hex "File class"]
  set ei_data [uint8 -hex "Data encoding"]
  uint8 -hex "File version"
  uint8 -hex "Operating system/ABI identification"
  uint8 -hex "ABI Version"

  move 7

  if {$ei_data > 1} {
    big_endian
  }

  uint16 -hex "Object file type"
  uint16 -hex "Target instruction set architecture"
  uint32 -hex "Version"

  if {$ei_class < 2} {
    uint32 -hex "Entry point"
    set e_phoff [uint32 -hex "Program header address"]
    set e_shoff [uint32 -hex "Section header address"]
  } else {
    uint64 -hex "Entry point"
    set e_phoff [uint64 -hex "Program header address"]
    set e_shoff [uint64 -hex "Section header address"]
  }

  uint32 -hex "Flags"
  uint16 -hex "Program header size"
  uint16 -hex "Program header entry size"
  set e_phnum [uint16 -hex "Program header entry count"]
  uint16 -hex "Section header entry size"
  set e_shnum [uint16 -hex "Section header entry count"]
  uint16 -hex "Section header table index of section name string table"
}

goto $e_phoff

section "Program header table" {
  for {set i 0} {$i < $e_phnum} {incr i} {
    section "Program header $i" {
      uint32 -hex "Segment type"

      if {$ei_class > 1} {
        uint32 -hex "Flags"
        uint64 -hex "Offset"
        uint64 -hex "Virtual address"
        uint64 -hex "Physical address"
        uint64 -hex "Size in file"
        uint64 -hex "Size in memory"
        uint64 -hex "Alignment"
      } else {
        uint32 -hex "Offset"
        uint32 -hex "Virtual address"
        uint32 -hex "Physical address"
        uint32 -hex "Size in file"
        uint32 -hex "Size in memory"
        uint32 -hex "Flags"
        uint32 -hex "Alignment"
      }
    }
  }
}

goto $e_shoff

section "Section header table" {
  for {set i 0} {$i < $e_shnum} {incr i} {
    section "Section header $i" {
      uint32 -hex "Name offset"
      uint32 -hex "Type"

      if {$ei_class > 1} {
        uint64 -hex "Flags"
        uint64 -hex "Virtual address"
        uint64 -hex "Offset"
        uint64 -hex "Size"
        uint32 -hex "Link"
        uint32 -hex "Info"
        uint64 -hex "Alignment"
        uint64 -hex "Entry size"
      } else {
        uint32 -hex "Flags"
        uint32 -hex "Virtual address"
        uint32 -hex "Offset"
        uint32 -hex "Size"
        uint32 -hex "Link"
        uint32 -hex "Info"
        uint32 -hex "Alignment"
        uint32 -hex "Entry size"
      }
    }
  }
}

