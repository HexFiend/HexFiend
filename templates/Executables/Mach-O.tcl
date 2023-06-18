####################################################################################################
# Executables/Mach-O.tcl
# 2021 Jul 14 | fosterbrereton | Initial implementation
####################################################################################################

hf_min_version_required 2.15
big_endian

include "Utility/General.tcl"

####################################################################################################
#
# Helpful Documentation:
#     - https://h3adsh0tzz.com/2020/01/macho-file-format/
#     - https://lowlevelbits.org/parsing-mach-o-files/
#     - https://eclecticlight.co/2020/07/28/universal-binaries-inside-fat-headers/
#     - https://www.objc.io/issues/6-build-tools/mach-o-executables/#mach-o
#     - https://medium.com/tokopedia-engineering/a-curious-case-of-mach-o-executable-26d5ecadd995
#
####################################################################################################

namespace eval macho {

####################################################################################################

proc flags_name {flags} {    
    set result ""

    if { ($flags & 0x1) != 0 } { set result "$result MH_NOUNDEFS" }
    if { ($flags & 0x2) != 0 } { set result "$result MH_INCRLINK" }
    if { ($flags & 0x4) != 0 } { set result "$result MH_DYLDLINK" }
    if { ($flags & 0x8) != 0 } { set result "$result MH_BINDATLOAD" }
    if { ($flags & 0x10) != 0 } { set result "$result MH_PREBOUND" }
    if { ($flags & 0x20) != 0 } { set result "$result MH_SPLIT_SEGS" }
    if { ($flags & 0x40) != 0 } { set result "$result MH_LAZY_INIT" }
    if { ($flags & 0x80) != 0 } { set result "$result MH_TWOLEVEL" }
    if { ($flags & 0x100) != 0 } { set result "$result MH_FORCE_FLAT" }
    if { ($flags & 0x200) != 0 } { set result "$result MH_NOMULTIDEFS" }
    if { ($flags & 0x400) != 0 } { set result "$result MH_NOFIXPREBINDING" }
    if { ($flags & 0x800) != 0 } { set result "$result MH_PREBINDABLE" }
    if { ($flags & 0x1000) != 0 } { set result "$result MH_ALLMODSBOUND" }
    if { ($flags & 0x2000) != 0 } { set result "$result MH_SUBSECTIONS_VIA_SYMBOLS" }
    if { ($flags & 0x4000) != 0 } { set result "$result MH_CANONICAL" }
    if { ($flags & 0x8000) != 0 } { set result "$result MH_WEAK_DEFINES" }
    if { ($flags & 0x10000) != 0 } { set result "$result MH_BINDS_TO_WEAK" }
    if { ($flags & 0x20000) != 0 } { set result "$result MH_ALLOW_STACK_EXECUTION" }
    if { ($flags & 0x40000) != 0 } { set result "$result MH_ROOT_SAFE" }
    if { ($flags & 0x80000) != 0 } { set result "$result MH_SETUID_SAFE" }
    if { ($flags & 0x100000) != 0 } { set result "$result MH_NO_REEXPORTED_DYLIBS" }
    if { ($flags & 0x200000) != 0 } { set result "$result MH_PIE" }
    if { ($flags & 0x400000) != 0 } { set result "$result MH_DEAD_STRIPPABLE_DYLIB" }
    if { ($flags & 0x800000) != 0 } { set result "$result MH_HAS_TLV_DESCRIPTORS" }
    if { ($flags & 0x1000000) != 0 } { set result "$result MH_NO_HEAP_EXECUTION" }
    if { ($flags & 0x02000000) != 0 } { set result "$result MH_APP_EXTENSION_SAFE" }
    if { ($flags & 0x04000000) != 0 } { set result "$result MH_NLIST_OUTOFSYNC_WITH_DYLDINFO" }
    if { ($flags & 0x08000000) != 0 } { set result "$result MH_SIM_SUPPORT" }
    if { ($flags & 0x80000000) != 0 } { set result "$result MH_DYLIB_IN_CACHE" }

    if { $result == "" } {
        return "none"
    } else {
        return [join $result " | "]
    }
}

####################################################################################################

proc segment_command_flags_name {flags} {    
    set result ""

    if { ($flags & 0x1) != 0 } { set result "$result SG_HIGHVM" }
    if { ($flags & 0x2) != 0 } { set result "$result SG_FVMLIB" }
    if { ($flags & 0x4) != 0 } { set result "$result SG_NORELOC" }
    if { ($flags & 0x8) != 0 } { set result "$result SG_PROTECTED_VERSION_1" }
    if { ($flags & 0x10) != 0 } { set result "$result SG_READ_ONLY" }

    if { $result == "" } {
        return "none"
    } else {
        return [join $result " | "]
    }
}

####################################################################################################

proc filetype_name {filetype} {
    if {$filetype == 0x1} { return "MH_OBJECT" }
    if {$filetype == 0x2} { return "MH_EXECUTE" }
    if {$filetype == 0x3} { return "MH_FVMLIB" }
    if {$filetype == 0x4} { return "MH_CORE" }
    if {$filetype == 0x5} { return "MH_PRELOAD" }
    if {$filetype == 0x6} { return "MH_DYLIB" }
    if {$filetype == 0x7} { return "MH_DYLINKER" }
    if {$filetype == 0x8} { return "MH_BUNDLE" }
    if {$filetype == 0x9} { return "MH_DYLIB_STUB" }
    if {$filetype == 0xa} { return "MH_DSYM" }
    if {$filetype == 0xb} { return "MH_KEXT_BUNDLE" }
    if {$filetype == 0xc} { return "MH_FILESET" }

    die "unknown filetype ($filetype)"
}

####################################################################################################

proc signature_name {signature} {
    if {$signature == 0xfeedface} { big_endian; return "MH_MAGIC" }
    if {$signature == 0xcefaedfe} { little_endian; return "MH_CIGAM" }
    if {$signature == 0xfeedfacf} { big_endian; return "MH_MAGIC_64" }
    if {$signature == 0xcffaedfe} { little_endian; return "MH_CIGAM_64" }
    if {$signature == 0xcafebabe} { big_endian; return "FAT_MAGIC" }
    if {$signature == 0xbebafeca} { little_endian; return "FAT_CIGAM" }
    if {$signature == 0xcafebabf} { big_endian; return "FAT_MAGIC_64" }
    if {$signature == 0xbfbafeca} { little_endian; return "FAT_CIGAM_64" }

    die "unknown signature ($signature)"
}

####################################################################################################

proc load_command_name {command} {
    set LC_REQ_DYLD 0x80000000

    if {$command == 0x80000000} { return "LC_REQ_DYLD" }
    if {$command == 0x1} { return "LC_SEGMENT" }
    if {$command == 0x2} { return "LC_SYMTAB" }
    if {$command == 0x3} { return "LC_SYMSEG" }
    if {$command == 0x4} { return "LC_THREAD" }
    if {$command == 0x5} { return "LC_UNIXTHREAD" }
    if {$command == 0x6} { return "LC_LOADFVMLIB" }
    if {$command == 0x7} { return "LC_IDFVMLIB" }
    if {$command == 0x8} { return "LC_IDENT" }
    if {$command == 0x9} { return "LC_FVMFILE" }
    if {$command == 0xa} { return "LC_PREPAGE" }
    if {$command == 0xb} { return "LC_DYSYMTAB" }
    if {$command == 0xc} { return "LC_LOAD_DYLIB" }
    if {$command == 0xd} { return "LC_ID_DYLIB" }
    if {$command == 0xe} { return "LC_LOAD_DYLINKER" }
    if {$command == 0xf} { return "LC_ID_DYLINKER" }
    if {$command == 0x10} { return "LC_PREBOUND_DYLIB" }
    if {$command == 0x11} { return "LC_ROUTINES" }
    if {$command == 0x12} { return "LC_SUB_FRAMEWORK" }
    if {$command == 0x13} { return "LC_SUB_UMBRELLA" }
    if {$command == 0x14} { return "LC_SUB_CLIENT" }
    if {$command == 0x15} { return "LC_SUB_LIBRARY" }
    if {$command == 0x16} { return "LC_TWOLEVEL_HINTS" }
    if {$command == 0x17} { return "LC_PREBIND_CKSUM" }
    if {$command == [ expr 0x18 | $LC_REQ_DYLD ]} { return "LC_LOAD_WEAK_DYLIB" }
    if {$command == 0x19} { return "LC_SEGMENT_64" }
    if {$command == 0x1a} { return "LC_ROUTINES_64" }
    if {$command == 0x1b} { return "LC_UUID" }
    if {$command == [ expr 0x1c | $LC_REQ_DYLD ]} { return "LC_RPATH" }
    if {$command == 0x1d} { return "LC_CODE_SIGNATURE" }
    if {$command == 0x1e} { return "LC_SEGMENT_SPLIT_INFO" }
    if {$command == [ expr 0x1f | $LC_REQ_DYLD ]} { return "LC_REEXPORT_DYLIB" }
    if {$command == 0x20} { return "LC_LAZY_LOAD_DYLIB" }
    if {$command == 0x21} { return "LC_ENCRYPTION_INFO" }
    if {$command == 0x22} { return "LC_DYLD_INFO" }
    if {$command == [ expr 0x22 | $LC_REQ_DYLD ]} { return "LC_DYLD_INFO_ONLY" }
    if {$command == [ expr 0x23 | $LC_REQ_DYLD ]} { return "LC_LOAD_UPWARD_DYLIB" }
    if {$command == 0x24} { return "LC_VERSION_MIN_MACOSX" }
    if {$command == 0x25} { return "LC_VERSION_MIN_IPHONEOS" }
    if {$command == 0x26} { return "LC_FUNCTION_STARTS" }
    if {$command == 0x27} { return "LC_DYLD_ENVIRONMENT" }
    if {$command == [ expr 0x28 | $LC_REQ_DYLD ]} { return "LC_MAIN" }
    if {$command == 0x29} { return "LC_DATA_IN_CODE" }
    if {$command == 0x2A} { return "LC_SOURCE_VERSION" }
    if {$command == 0x2B} { return "LC_DYLIB_CODE_SIGN_DRS" }
    if {$command == 0x2C} { return "LC_ENCRYPTION_INFO_64" }
    if {$command == 0x2D} { return "LC_LINKER_OPTION" }
    if {$command == 0x2E} { return "LC_LINKER_OPTIMIZATION_HINT" }
    if {$command == 0x2F} { return "LC_VERSION_MIN_TVOS" }
    if {$command == 0x30} { return "LC_VERSION_MIN_WATCHOS" }
    if {$command == 0x31} { return "LC_NOTE" }
    if {$command == 0x32} { return "LC_BUILD_VERSION" }
    if {$command == [ expr 0x33 | $LC_REQ_DYLD ]} { return "LC_DYLD_EXPORTS_TRIE" }
    if {$command == [ expr 0x34 | $LC_REQ_DYLD ]} { return "LC_DYLD_CHAINED_FIXUPS" }
    if {$command == [ expr 0x35 | $LC_REQ_DYLD ]} { return "LC_FILESET_ENTRY" }

    die "unknown command ($command)"
}

####################################################################################################

proc lc_segment_section_64_flags_name {flags} {
    set section_type [expr $flags & 0xff]

    if {$section_type == 0x0}  { entry "" "S_REGULAR" 1 [expr [pos] - 4]}
    if {$section_type == 0x1}  { entry "" "S_ZEROFILL" 1 [expr [pos] - 4]}
    if {$section_type == 0x2}  { entry "" "S_CSTRING_LITERALS" 1 [expr [pos] - 4]}
    if {$section_type == 0x3}  { entry "" "S_4BYTE_LITERALS" 1 [expr [pos] - 4]}
    if {$section_type == 0x4}  { entry "" "S_8BYTE_LITERALS" 1 [expr [pos] - 4]}
    if {$section_type == 0x5}  { entry "" "S_LITERAL_POINTERS" 1 [expr [pos] - 4]}
    if {$section_type == 0x6}  { entry "" "S_NON_LAZY_SYMBOL_POINTERS" 1 [expr [pos] - 4]}
    if {$section_type == 0x7}  { entry "" "S_LAZY_SYMBOL_POINTERS" 1 [expr [pos] - 4]}
    if {$section_type == 0x8}  { entry "" "S_SYMBOL_STUBS" 1 [expr [pos] - 4]}
    if {$section_type == 0x9}  { entry "" "S_MOD_INIT_FUNC_POINTERS" 1 [expr [pos] - 4]}
    if {$section_type == 0xa}  { entry "" "S_MOD_TERM_FUNC_POINTERS" 1 [expr [pos] - 4]}
    if {$section_type == 0xb}  { entry "" "S_COALESCED" 1 [expr [pos] - 4]}
    if {$section_type == 0xc}  { entry "" "S_GB_ZEROFILL" 1 [expr [pos] - 4]}
    if {$section_type == 0xd}  { entry "" "S_INTERPOSING" 1 [expr [pos] - 4]}
    if {$section_type == 0xe}  { entry "" "S_16BYTE_LITERALS" 1 [expr [pos] - 4]}
    if {$section_type == 0xf}  { entry "" "S_DTRACE_DOF" 1 [expr [pos] - 4]}
    if {$section_type == 0x10} { entry "" "S_LAZY_DYLIB_SYMBOL_POINTERS" 1 [expr [pos] - 4]}
    if {$section_type == 0x11} { entry "" "S_THREAD_LOCAL_REGULAR" 1 [expr [pos] - 4]}
    if {$section_type == 0x12} { entry "" "S_THREAD_LOCAL_ZEROFILL" 1 [expr [pos] - 4]}
    if {$section_type == 0x13} { entry "" "S_THREAD_LOCAL_VARIABLES" 1 [expr [pos] - 4]}
    if {$section_type == 0x14} { entry "" "S_THREAD_LOCAL_VARIABLE_POINTERS" 1 [expr [pos] - 4]}
    if {$section_type == 0x15} { entry "" "S_THREAD_LOCAL_INIT_FUNCTION_POINTERS" 1 [expr [pos] - 4]}
    if {$section_type == 0x16} { entry "" "S_INIT_FUNC_OFFSETS" 1 [expr [pos] - 4]}

    if {($flags & 0x80000000) != 0} { entry "" "S_ATTR_PURE_INSTRUCTIONS" 3 [expr [pos] - 3]}
    if {($flags & 0x40000000) != 0} { entry "" "S_ATTR_NO_TOC" 3 [expr [pos] - 3]}
    if {($flags & 0x20000000) != 0} { entry "" "S_ATTR_STRIP_STATIC_SYMS" 3 [expr [pos] - 3]}
    if {($flags & 0x10000000) != 0} { entry "" "S_ATTR_NO_DEAD_STRIP" 3 [expr [pos] - 3]}
    if {($flags & 0x08000000) != 0} { entry "" "S_ATTR_LIVE_SUPPORT" 3 [expr [pos] - 3]}
    if {($flags & 0x04000000) != 0} { entry "" "S_ATTR_SELF_MODIFYING_CODE" 3 [expr [pos] - 3]}
    if {($flags & 0x02000000) != 0} { entry "" "S_ATTR_DEBUG" 3 [expr [pos] - 3]}
    if {($flags & 0x00000400) != 0} { entry "" "S_ATTR_SOME_INSTRUCTIONS" 3 [expr [pos] - 3]}
    if {($flags & 0x00000200) != 0} { entry "" "S_ATTR_EXT_RELOC" 3 [expr [pos] - 3]}
    if {($flags & 0x00000100) != 0} { entry "" "S_ATTR_LOC_RELOC" 3 [expr [pos] - 3]}

    return $section_type
}

####################################################################################################

proc lc_segment_section_64 {main_offset count} {
    section "\[ $count \]" {
        set sectname [ascii 16 sectname]
        set segname [ascii 16 segname]
        sectionname "$segname.$sectname"
        uint64 addr
        set size [uint64 size]
        sectionvalue "[human_size $size]"
        set offset [uint32 offset]
        uint32 align
        uint32 reloff
        uint32 nreloc
        set flags [uint32 -hex flags]
        set section_type [lc_segment_section_64_flags_name $flags]
        uint32 reserved1
        uint32 reserved2
        uint32 reserved3
        jumpa [expr $main_offset + $offset] {
            if {$section_type == 2} {
                set count 0
                set cur_size 0
                section "literals" {
                    while {$cur_size < $size} {
                        set cur_string [cstr "ascii" "\[ $count \]"]
                        set cur_string_len [expr [string length $cur_string] + 1]
                        set cur_size [expr $cur_size + $cur_string_len]
                        incr count
                        if {$count >= 5000} {
                            entry "" "(remainder of strings elided)"
                            break
                        }
                    }
                    sectionvalue "$count entries"
                }
            } elseif {$size != 0} {
                bytes $size "data"
            }
        }
    }
}

####################################################################################################

proc lc_segment_64 {main_offset command_size} {
    ascii 16 segname
    uint64 vmaddr
    uint64 vmsize
    uint64 fileoff
    set filesize [uint64]
    set hsize [human_size $filesize]
    entry "filesize" $hsize 8 [expr [pos] - 8]
    int32 maxprot
    int32 initprot
    set nsects [uint32 nsects]
    set flags [uint32]
    set flags_str [segment_command_flags_name $flags]
    entry "flags" $flags_str 4 [expr [pos] - 4]
    if {$nsects != 0} {
        section "sections" {
            for {set i 0} {$i < $nsects} {incr i} {
                lc_segment_section_64 $main_offset $i
            }
        }
    }
    sectionvalue $hsize
}

####################################################################################################

proc nibbled_version {label} {
    section $label {
        set dot [uint8 dot]
        set minor [uint8 minor]
        set major [uint16 major]
        set result "$major.$minor.$dot"
        sectionvalue "$result"
    }
    return $result
}

####################################################################################################

proc lc_version_min_macosx {main_offset command_size} {
    sectionvalue [nibbled_version version]
    nibbled_version sdk
}

####################################################################################################

proc lc_symtab_nlist_64 {stroff count} {
    section "\[ $count \]" {
        set n_strx [uint32 n_strx]
        set n_type [uint8 n_type]
        set n_sect [uint8 n_sect]
        set n_desc [uint16 n_desc]
        set n_value [uint64 n_value]
        jumpa [expr $stroff + $n_strx] {
            set symbol_name [cstr "ascii" symbol_name]
        }
        sectionvalue "$symbol_name"
    }
}

####################################################################################################

proc lc_symtab {main_offset command_size} {
    set symoff [uint32 symoff]
    set nsyms [uint32 nsyms]
    set stroff [uint32 stroff]
    set strsize [uint32 strsize]
    if {$nsyms < 10000} {
        jumpa [expr $main_offset + $symoff] {
            section "symbols" {
                for {set i 0} {$i < $nsyms} {incr i} {
                    lc_symtab_nlist_64 [expr $main_offset + $stroff] $i
                }
                sectionvalue "$nsyms entries"
            }
        }
    } else {
        entry "symbols" "$nsyms entries (elided)" $strsize [expr $main_offset + $stroff]
    }
    # The strings are pooled together at the end of the section, but they are referenced by each of
    # the symbols above (by n_strx, the byte offset of the string within this pool.) We do not need
    # to iterate all the strings here, as they will be covered by the symbol table above.
    sectionvalue [human_size $strsize]
}

####################################################################################################

proc lc_source_version {} {
    set version [uint64]
    set a [expr $version >> 40]
    set b [expr ($version >> 30) & 0x3ff]
    set c [expr ($version >> 20) & 0x3ff]
    set d [expr ($version >> 10) & 0x3ff]
    set e [expr $version & 0x3ff]
    set version_str "$a.$b.$c.$d.$e"
    entry "version" $version_str
    sectionvalue $version_str
}

####################################################################################################

proc lc_build_tool_version {count} {
    section "\[ $count \]" {
        set tool [uint32]
        switch $tool {
            1 { set tool_str "TOOL_CLANG" }
            2 { set tool_str "TOOL_SWIFT" }
            3 { set tool_str "TOOL_LD" }
            default { die "unknown tool ($tool)" }
        }
        entry "tool" "$tool_str" 4 [expr [pos] - 4]
        nibbled_version version
    }
}

####################################################################################################

proc lc_main {} {
    uint64 entryoff
    uint64 stacksize
}

####################################################################################################

proc lc_uuid {} {
    sectionvalue [uuid uuid]
}

####################################################################################################

proc lc_build_version {} {
    set platform [uint32]
    switch $platform {
        1 { set platform_str "PLATFORM_MACOS" }
        2 { set platform_str "PLATFORM_IOS" }
        3 { set platform_str "PLATFORM_TVOS" }
        4 { set platform_str "PLATFORM_WATCHOS" }
        5 { set platform_str "PLATFORM_BRIDGEOS" }
        6 { set platform_str "PLATFORM_MACCATALYST" }
        7 { set platform_str "PLATFORM_IOSSIMULATOR" }
        8 { set platform_str "PLATFORM_TVOSSIMULATOR" }
        9 { set platform_str "PLATFORM_WATCHOSSIMULATOR" }
        10 { set platform_str "PLATFORM_DRIVERKIT" }
        default { die "unknown platform ($platform)" }
    }
    entry "platform" "$platform_str" 4 [expr [pos] - 4]
    set minos [nibbled_version minos]
    nibbled_version sdk
    set ntools [uint32 ntools]
    for {set i 0} {$i < $ntools} {incr i} {
        lc_build_tool_version $i
    }
    sectionvalue "$platform_str $minos"
}

####################################################################################################
# The way lc_str is stored in the binary, the string is appended to the end of the data structure it
# is a part of. The offset determines where that string starts relative to the load command, but
# jumping there, reading the string, and jumping back puts the read position in a funky state when
# the load command structure has finished reading (that is, it'll be at the start of the string,
# when it needs to be past it to resume reading the next load command.) Therefore we take a bit of
# an unorthodox approach here, by reading the offset, then the rest of the load command fields, and
# then finally the string (with necessary padding at the end) so the read position is ready to go
# for the next load command.

proc lc_str {command_pos command_size body} {
    uint32 lc_str_offset
    uplevel 1 $body
    set result [cstr "ascii" lc_str_string]
    set cur_size [expr [pos] - $command_pos]
    # entry "cur_size" $cur_size
    set leftovers [expr $command_size - $cur_size]
    if {$leftovers != 0} {
        bytes $leftovers padding
    }
    return $result
}

####################################################################################################

proc lc_str_only {command_pos command_size} {
    sectionvalue [lc_str $command_pos $command_size {}]
}

####################################################################################################

proc lc_load_dylib {main_offset command_pos command_size} {
    sectionvalue [lc_str $command_pos $command_size {
        uint32 timestamp
        nibbled_version current_version
        nibbled_version compatibility_version
    }]
}

####################################################################################################

proc lc_idfvmlib {main_offset command_size} {
    lc_str $command_pos $command_size {
        uint32 minor_version
        uint32 header_addr
    }
}

####################################################################################################

proc lc_linkedit_data {main_offset command_size} {
    set dataoff [uint32 dataoff]
    set datasize [uint32 datasize]
    # the offset is relative to the __LINKEDIT segment, which we do not have here.
    sectionvalue "__LINKEDIT data"
}

####################################################################################################

proc lc_dysymtab {main_offset command_size} {
    uint32 ilocalsym
    uint32 nlocalsym
    uint32 iextdefsym
    uint32 nextdefsym
    uint32 iundefsym
    uint32 nundefsym
    uint32 tocoff
    uint32 ntoc
    uint32 modtaboff
    uint32 nmodtab
    uint32 extrefsymoff
    uint32 nextrefsyms
    uint32 indirectsymoff
    uint32 nindirectsyms
    uint32 extreloff
    uint32 nextrel
    uint32 locreloff
    uint32 nlocrel
}

####################################################################################################

proc load_command {main_offset count} {
    section "\[ $count \]" {
        set command_pos [pos]
        set command [uint32 -hex "cmd"]
        set command_str [load_command_name $command]
        sectionname $command_str
        set command_size [uint32 "cmdsize"]
        sectionvalue ""
        switch $command_str {
            "LC_SEGMENT_64" { lc_segment_64 $main_offset $command_size }
            "LC_SYMTAB" { lc_symtab $main_offset $command_size }
            "LC_DYSYMTAB" { lc_dysymtab $main_offset $command_size }
            "LC_SOURCE_VERSION" { lc_source_version }
            "LC_BUILD_VERSION" { lc_build_version }
            "LC_UUID" { lc_uuid }
            "LC_MAIN" { lc_main }

            "LC_VERSION_MIN_MACOSX" -
            "LC_VERSION_MIN_IPHONEOS" -
            "LC_VERSION_MIN_WATCHOS" -
            "LC_VERSION_MIN_TVOS" { lc_version_min_macosx $main_offset $command_size }

            "LC_CODE_SIGNATURE" -
            "LC_SEGMENT_SPLIT_INFO" -
            "LC_FUNCTION_STARTS" -
            "LC_DATA_IN_CODE" -
            "LC_DYLIB_CODE_SIGN_DRS" -
            "LC_LINKER_OPTIMIZATION_HINT" -
            "LC_DYLD_EXPORTS_TRIE" -
            "LC_DYLD_CHAINED_FIXUPS" { lc_linkedit_data $main_offset $command_size }

            "LC_IDFVMLIB" -
            "LC_LOADFVMLIB" { lc_idfvmlib $main_offset $command_size }

            "LC_ID_DYLIB" -
            "LC_LOAD_DYLIB" -
            "LC_LOAD_WEAK_DYLIB" -
            "LC_REEXPORT_DYLIB" { lc_load_dylib $main_offset $command_pos $command_size }

            "LC_ID_DYLINKER" -
            "LC_LOAD_DYLINKER" -
            "LC_DYLD_ENVIRONMENT" -
            "LC_RPATH" { lc_str_only $command_pos $command_size }

            default {
                set command_leftovers [expr $command_size - 8]
                bytes $command_leftovers "cmddata"
            }
        }
    }
}

####################################################################################################

proc load_commands {main_offset ncmds} {
    section "load commands" {
        for {set i 0} {$i < $ncmds} {incr i} {
            load_command $main_offset $i
        }
    }
}

####################################################################################################

proc cputype_name {cputype} {
    if {$cputype == 1} { return "CPU_TYPE_VAX" }
    if {$cputype == 6} { return "CPU_TYPE_MC680x0" }
    if {$cputype == 7} { return "CPU_TYPE_X86" }
    if {$cputype == [expr 7 | 0x01000000]} { return "CPU_TYPE_X86_64" }
    if {$cputype == 10} { return "CPU_TYPE_MC98000" }
    if {$cputype == 11} { return "CPU_TYPE_HPPA" }
    if {$cputype == 12} { return "CPU_TYPE_ARM" }
    if {$cputype == [expr 12 | 0x01000000] } { return "CPU_TYPE_ARM64" }
    if {$cputype == [expr 12 | 0x02000000]} { return "CPU_TYPE_ARM64_32" }
    if {$cputype == 13} { return "CPU_TYPE_MC88000" }
    if {$cputype == 14} { return "CPU_TYPE_SPARC" }
    if {$cputype == 15} { return "CPU_TYPE_I860" }
    if {$cputype == 18} { return "CPU_TYPE_POWERPC" }
    if {$cputype == [expr 18 | 0x01000000]} { return "CPU_TYPE_POWERPC64" }

    die "unknown cputype ($cputype)"
}

####################################################################################################

proc fat_arch {count} {
    section "arch\[ $count \]" {
        big_endian
        set cputype [int32]
        set cputype_str [cputype_name $cputype]
        entry "cputype" $cputype_str 4 [expr [pos] - 4]
        sectionname $cputype_str
        uint32 -hex "cpusubtype"
        set offset [uint32 offset]
        set size [uint32 size]
        sectionvalue [human_size $size]
        uint32 align
        jumpa $offset {
            container $offset
        }
    }
}

####################################################################################################

proc fat_header {} {
    section "header" {
        set signature [uint32]
        set signature_str [signature_name $signature]
        entry "signature" $signature_str 4 [expr [pos] - 4]
        sectionvalue $signature_str

        set is_64_bit [expr $signature == 0xcafebabf || $signature == 0xbfbafeca]
        set nfat_arch [uint32 nfat_arch]
    }

    for {set i 0} {$i < $nfat_arch} {incr i} {
        fat_arch $i
    }
}

####################################################################################################

proc container {main_offset} {
    section "header" {
        set signature [uint32]
        set signature_str [signature_name $signature]
        entry "signature" $signature_str 4 [expr [pos] - 4]
        sectionvalue $signature_str

        set cputype [int32]
        set cputype_str [cputype_name $cputype]
        entry "cputype" $cputype_str 4 [expr [pos] - 4]

        uint32 -hex "cpusubtype"

        set filetype [uint32]
        set filetype_str [filetype_name $filetype]
        entry "filetype" $filetype_str 4 [expr [pos] - 4]

        set ncmds [uint32 "ncmds"]
        uint32 "sizeofcmds"

        set flags [uint32]
        set flags_str [flags_name $flags]
        entry "flags" $flags_str 4 [expr [pos] - 4]

        if {$signature == 0xfeedfacf || $signature == 0xcffaedfe} {
            uint32 "reserved"
        }
    }

    load_commands $main_offset $ncmds
}

####################################################################################################
# end of namespace macho
}
####################################################################################################

main_guard {
    set signature [uint32]
    # Rewind to the top of the file
    move -4

    if {$signature == 0xcafebabf || $signature == 0xbfbafeca ||
        $signature == 0xcafebabe || $signature == 0xbebafeca} {
        macho::fat_header
    } else {
        macho::container 0
    }
}

####################################################################################################
