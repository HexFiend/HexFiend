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
#     - https://math-atlas.sourceforge.net/devel/assembly/MachORuntime.pdf
#     - https://en.wikipedia.org/wiki/Mach-O
#     - https://github.com/ziglang/zig/blob/master/lib/std/macho.zig
#     - https://github.com/llvm/llvm-project/blob/main/lld/MachO/InputFiles.cpp
#     - https://pkg.go.dev/github.com/blacktop/go-macho/types
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

proc lc_symtab_nlist_64_stab_str {type} {
    switch $type {
        32 { set result  "N_GSYM" }
        34 { set result  "N_FNAME" }
        36 { set result  "N_FUN" }
        38 { set result  "N_STSYM" }
        40 { set result  "N_LCSYM" }
        46 { set result  "N_BNSYM" }
        48 { set result  "N_PC" }
        50 { set result  "N_AST" }
        60 { set result  "N_OPT" }
        64 { set result  "N_RSYM" }
        68 { set result  "N_SLINE" }
        78 { set result  "N_ENSYM" }
        96 { set result  "N_SSYM" }
        100 { set result "N_SO" }
        102 { set result "N_OSO" }
        104 { set result "N_LIB" }
        128 { set result "N_LSYM" }
        130 { set result "N_BINCL" }
        132 { set result "N_SOL" }
        134 { set result "N_PARAMS" }
        136 { set result "N_VERSION" }
        138 { set result "N_OLEVEL" }
        160 { set result "N_PSYM" }
        162 { set result "N_EINCL" }
        164 { set result "N_ENTRY" }
        192 { set result "N_LBRAC" }
        194 { set result "N_EXCL" }
        224 { set result "N_RBRAC" }
        226 { set result "N_BCOMM" }
        228 { set result "N_ECOMM" }
        232 { set result "N_ECOML" }
        254 { set result "N_LENG" }
        default { die "unknown STAB value ($type)" }
    }
    return $result
}

####################################################################################################
# Many of the comments in this routine were colaesced from sources linked at the top of this file.
proc lc_symtab_nlist_64_stab {symbol_name type} {
    set stab_str [lc_symtab_nlist_64_stab_str $type]
    entry "    N_STAB" $stab_str 1 [expr [pos] - 1]
    set symbol_name_length [string length $symbol_name]

    if {$symbol_name_length != 0} {
        set symbol_name "'$symbol_name'"
    }

    sectionvalue "($stab_str) $symbol_name"

    # Gleaned from <mach-o/stab.h>
    #
    # Hex  | Dec | STAB      | Info w/ name,type,sect,desc,value interpretations
    # -----|-----|-----------|--------------------------------------------------
    # 0x20 | 32  | N_GSYM    | global symbol: name,,NO_SECT,type,0
    # 0x22 | 34  | N_FNAME   | procedure name (f77 kludge): name,,NO_SECT,0,0
    # 0x24 | 36  | N_FUN     | procedure: name,,n_sect,linenumber,address
    # 0x26 | 38  | N_STSYM   | static symbol: name,,n_sect,type,address
    # 0x28 | 40  | N_LCSYM   | .lcomm symbol: name,,n_sect,type,address
    # 0x2e | 46  | N_BNSYM   | begin nsect sym: 0,,n_sect,0,address
    # 0x30 | 48  | N_PC      | global pascal symbol: name,,NO_SECT,subtype,line
    # 0x32 | 50  | N_AST     | AST file path: name,,NO_SECT,0,0
    # 0x3c | 60  | N_OPT     | emitted with gcc2_compiled and in gcc source
    # 0x40 | 64  | N_RSYM    | register sym: name,,NO_SECT,type,register
    # 0x44 | 68  | N_SLINE   | src line: 0,,n_sect,linenumber,address
    # 0x4e | 78  | N_ENSYM   | end nsect sym: 0,,n_sect,0,address
    # 0x60 | 96  | N_SSYM    | structure elt: name,,NO_SECT,type,struct_offset
    # 0x64 | 100 | N_SO      | source file name: name,,n_sect,0,address
    # 0x66 | 102 | N_OSO     | object file name: name,,cpusubtype?,1,st_mtime
    # 0x68 | 104 | N_LIB     | dynamic library file name: name,,NO_SECT,0,0
    # 0x80 | 128 | N_LSYM    | local sym: name,,NO_SECT,type,offset
    # 0x82 | 130 | N_BINCL   | include file beginning: name,,NO_SECT,0,sum
    # 0x84 | 132 | N_SOL     | #included file name: name,,n_sect,0,address
    # 0x86 | 134 | N_PARAMS  | compiler parameters: name,,NO_SECT,0,0
    # 0x88 | 136 | N_VERSION | compiler version: name,,NO_SECT,0,0
    # 0x8A | 138 | N_OLEVEL  | compiler -O level: name,,NO_SECT,0,0
    # 0xa0 | 160 | N_PSYM    | parameter: name,,NO_SECT,type,offset
    # 0xa2 | 162 | N_EINCL   | include file end: name,,NO_SECT,0,0
    # 0xa4 | 164 | N_ENTRY   | alternate entry: name,,n_sect,linenumber,address
    # 0xc0 | 192 | N_LBRAC   | left bracket: 0,,NO_SECT,nesting level,address
    # 0xc2 | 194 | N_EXCL    | deleted include file: name,,NO_SECT,0,sum
    # 0xe0 | 224 | N_RBRAC   | right bracket: 0,,NO_SECT,nesting level,address
    # 0xe2 | 226 | N_BCOMM   | begin common: name,,NO_SECT,0,0
    # 0xe4 | 228 | N_ECOMM   | end common: name,,n_sect,0,0
    # 0xe8 | 232 | N_ECOML   | end common (local name): 0,,n_sect,0,address
    # 0xfe | 254 | N_LENG    | second stab entry with length information

    switch $type {
        34 -
        50 -
        104 -
        134 -
        136 -
        138 -
        162 -
        226 {
            hex 1 NO_SECT
            hex 2 zero
            hex 8 zero
        }
        36 -
        68 -
        164 {
            set n_sect [uint8 n_sect]
            set line_number [uint16 line_number]
            set address [uint64 -hex address]
            set addr_hex [format 0x%x $address]
            sectionvalue "($stab_str) $n_sect $addr_hex $symbol_name"
        }
        46 -
        78 -
        100 -
        132 -
        232 {
            set n_sect [uint8 n_sect]
            set line_number [uint16 line_number]
            set address [uint64 -hex address]
            set addr_hex [format 0x%x $address]
            sectionvalue "($stab_str) $n_sect $addr_hex $symbol_name"
        }
        default {
            uint8 n_sect
            uint16 n_desc
            uint64 n_value
        }
    }
}

####################################################################################################
# Many of the comments in this routine were colaesced from sources linked at the top of this file.
proc lc_symtab_nlist_64 {stroff count} {
    section "\[ $count \]" {
        set n_strx [uint32 n_strx]

        jumpa [expr $stroff + $n_strx] {
            set symbol_name [cstr "ascii"]
        }

        sectionvalue "$symbol_name"

        set symbol_name_length [string length $symbol_name]

        if {$symbol_name_length != 0} {
            entry "    symbol name" $symbol_name $symbol_name_length [expr $stroff + $n_strx + 1]
        }

        set n_type [uint8 n_type]

        # N_STAB entries; handle them separately.
        if [expr ($n_type & 0xe0) != 0x00] {
            lc_symtab_nlist_64_stab $symbol_name $n_type
        } else {
            # If this bit is on, this symbol is marked as having limited global scope. When the file is
            # fed to the static linker, it clears the `N_EXT` bit for each symbol with the `N_PEXT` bit
            # set. (The ld option -keep_private_externs turns off this behavior.)
            if [expr ($n_type & 0x10) == 0x10] { entry "    N_PEXT" "" 1 [expr [pos] - 1] }

            # N_TYPE fields and their interpretations
            # The symbol is undefined. Undefined symbols are symbols referenced in this module but
            # defined in a different module. 
            if [expr ($n_type & 0x0e) == 0x00] { entry "    N_UNDF" "" 1 [expr [pos] - 1] }
            # The symbol is absolute. The linker does not update the value of an absolute symbol.
            if [expr ($n_type & 0x0e) == 0x02] { entry "    N_ABS" "" 1 [expr [pos] - 1] }
            # The symbol is defined in the section number given in n_sect.
            if [expr ($n_type & 0x0e) == 0x0e] { entry "    N_SECT" "" 1 [expr [pos] - 1] }
            # The symbol is undefined and the image is using a prebound value for the symbol.
            if [expr ($n_type & 0x0e) == 0x0c] { entry "    N_PBUD" "" 1 [expr [pos] - 1] }
            # The symbol is defined to be the same as another symbol. The n_value field is an index into
            # the string table specifying the name of the other symbol. When that symbol is linked, both
            # this and the other symbol point to the same defined type and value.
            if [expr ($n_type & 0x0e) == 0x0a] { entry "    N_INDR" "" 1 [expr [pos] - 1] }

            # If this bit is on, this symbol is an external symbol, a symbol that is either defined
            # outside this file or that is defined in this file but can be referenced by other files.
            if [expr ($n_type & 0x01) == 0x01] { entry "    N_EXT" "" 1 [expr [pos] - 1] }

            # An integer specifying the number of the section that this symbol can be found in, or
            # NO_SECT if the symbol is not to be found in any section of this image. The sections are
            # contiguously numbered across segments, starting from 1, according to the order they appear
            # in the LC_SEGMENT load commands.
            set n_sect [uint8 n_sect]
            # A 16-bit value providing additional information about the nature of this symbol.
            set n_desc [uint16 n_desc]

            # Some of these flags have several interpretations. See <mach-o/nlist.h> for more details.
            # Must be set for any symbol that might be referenced by another image. The strip tool uses
            # this bit to avoid removing symbols that must exist: If the symbol has this bit set, strip
            # does not strip it.
            if [expr ($n_desc & 0x0010) == 0x0010] { entry "    REFERENCED_DYNAMICALLY" "" 2 [expr [pos] - 2] }
            # Used by the dynamic linker at runtime. Do not set this bit in a linked image.
            # In a relocatable (.o) file, this bit is the `N_NO_DEAD_STRIP` bit, which tells the static
            # linker not to dead strip this symbol. Since this bit should not be set in a linked image,
            # we will assume if it is set, it means `N_NO_DEAD_STRIP`.
            if [expr ($n_desc & 0x0020) == 0x0020] { entry "    N_NO_DEAD_STRIP" "" 2 [expr [pos] - 2] }
            # Indicates that this symbol is a weak reference. If the dynamic linker cannot find a
            # definition for this symbol, it sets the address of this symbol to zero. The static linker
            # sets this symbol given the appropriate weak-linking flags.
            if [expr ($n_desc & 0x0040) == 0x0040] { entry "    N_WEAK_REF" "" 2 [expr [pos] - 2] }
            # Indicates that this symbol is a weak definition. If the static linker or the dynamic
            # linker finds another (non-weak) definition for this symbol, the weak definition is
            # ignored. Only symbols in a coalesced section can be marked as a weak definition.
            if [expr ($n_desc & 0x0080) == 0x0080] { entry "    N_WEAK_DEF" "" 2 [expr [pos] - 2] }
            # I couldn't find an explicit description of this bit. See this link for details on what ARM
            # Thumb is: https://stackoverflow.com/a/10638621/153535. Presumably if this bit is set, this
            # symbol definition is written against the ARM Thumb instruction set.
            if [expr ($n_desc & 0x0008) == 0x0008] { entry "    N_ARM_THUMB_DEF" "" 2 [expr [pos] - 2] }
            # Indicates that the function is actually a resolver function and should be called to get
            # the address of the real function to use. This bit is only available in .o files.
            if [expr ($n_desc & 0x0100) == 0x0100] { entry "    N_SYMBOL_RESOLVER" "" 2 [expr [pos] - 2] }
            # A section can have multiple symbols. A symbol that does not have the N_ALT_ENTRY attribute
            # indicates a beginning of a subsection. Therefore, by definition, a symbol is always
            # present at the beginning of each subsection. A symbol with N_ALT_ENTRY attribute does not
            # start a new subsection and can point to a middle of a subsection.
            if [expr ($n_desc & 0x0200) == 0x0200] { entry "    N_ALT_ENTRY" "" 2 [expr [pos] - 2] }
            # Indicates that the symbol is used infrequently and the linker should order it towards the
            # end of the section.
            if [expr ($n_desc & 0x0400) == 0x0400] { entry "    N_COLD_FUNC" "" 2 [expr [pos] - 2] }

            set n_value [uint64 -hex n_value]
        }
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
