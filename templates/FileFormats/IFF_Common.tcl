# FileFormats/IFF_Common.tcl
#
# 2025 Jun 03 | Andreas Stahl | Initial implementation
#
# Documentation referenced:
# - EA IFF 85 https://www.martinreddy.net/gfx/2d/IFF.txt
# - https://wiki.amigaos.net/wiki/A_Quick_Introduction_to_IFF
#
# How this works
# --------------
#
# The IFF File format is comprised of chunks, which have a 4 byte ASCII
# identifier and a 32 bit unsigned (big endian) length value, followed
# immediately by the data (of given length) of the chunk. Since the format
# originated on Motorola 68k systems, all numbers should be treated as big
# endian, and all chunks need to be of even length, to ensure 16-bit aligned
# access on each chunk start.
#
# Most -- if not all -- files that were written and read by programs using the
# IFF file format consist of a single chunk of id FORM, which defines a sub
# type 4 byte ASCII identifier also called _FORM type_, followed by chunks
# associated with this type.
#
# There are other basic container types, like CAT and LIST, but they are not
# used by most applications. (Even the ANIM type is a FORM of multiple
# consecutive ILBM FORMS, not a CAT file, as you might think.) This template
# supports all standard IFF Chunks, including CAT, LIST and PROP.
#
# This template works by exploiting tcl's flexible procedure naming scheme,
# basically registering parsers for each chunk type, by defining procedures
# using the naming scheme `parse$FormType$ChunkId` which takes a single length
# parameter.
#
# There is a fallback for chunks that are generic and associated with multiple
# FORM types, like FORM, CAT, or TEXT: these are parsed in the `parse$ChunkId`
# procedures defined in this file, but additional "generic" chunks can be
# defined in this way.
#
# Author(s)
# - Andreas Stahl https://www.github.com/nonsquarepixels
#
# .hidden = true;

###############################################################################
# FORM: basic structured data chunk.
proc parseForm {length} {
    set begin [pos]
    set formType [ascii 4 "Sub Type"]
    while {[expr ([pos] - $begin) < $length]} {
        parseChunk $formType
    }
}

###############################################################################
# 'CAT ': ConCATenation Chunk, basically a list of data objects, with an type
# hint (like "ILBM", or "    ")
proc parseCat {length} {
    set begin [pos]
    set contentType [ascii 4 "Type Hint"]
    while {[expr ([pos] - $begin) < $length]} {
        parseChunk $contentType
    }
}

###############################################################################
# LIST: defines a group very much like CAT but it also gives a scope for PROPs.
# Aliased to CAT.
proc parseList {length} {
    parseCat $length
}

###############################################################################
# PROP: supplies shared properties for the FORMs in a LIST.
# Aliased to FORM.
proc parseProp {length} {
    parseForm $length
}

###############################################################################
# TEXT: Standard ASCII Text chunk, length is determined by chunk length
# information.
proc parseText {length} {
    sectionname "Text"
    ascii $length "Content"
}

###############################################################################
# '(c) ': Standard ASCII Copyright information chunk, length is determined by
# chunk length information.
proc parse(c) {length} {
    sectionname "Copyright"
    ascii $length "Content"
}

###############################################################################
# ANNO: Standard ASCII Annotation chunk, length is determined by chunk length
# information.
proc parseAnno {length} {
    sectionname "Copyright"
    ascii $length "Content"
}

###############################################################################
# entry procedure for parsing of IFF chunks. Reads the chunk header and
# dispatches to a specialized procedure defined for the chunk id. If no handler
# procedure is found, a more generic procedure (without FORM type prefix) is 
# searched for. If that lookup also fails, a warning is printed to the debugger
# console and the chunks content is marked as untyped range of bytes.
proc parseChunk {{formType "IFF"}} {
    set needsPadding false
    section "" {
        section -collapsed "Chunk"
        set type [ascii 4 "Type"]
        set length [int32 "Length"]
        sectionvalue "$type [human_size $length]"
        endsection

        set needsPadding [expr $length % 2 == 1]
        set formType [string trim $formType]
        set type [string trim $type]
        sectionname "$formType.$type"
        sectionvalue [human_size $length]
        set formType [string totitle $formType]
        set type [string totitle $type]

        set longProcName "parse$formType$type"
        set shortProcName "parse$type"

        sentry $length {

            if {$formType != "IFF" &&
                [info procs $longProcName] == $longProcName} {
                $longProcName $length
            } elseif {[info procs $shortProcName] == $shortProcName} {
                $shortProcName $length
            } elseif {$length > 0 } {
                puts "IFF: Couldn't find parser for $formType, $type chunks."
                puts "IFF: implement proc $longProcName or $shortProcName!"
                bytes $length "Content"
            }
        }
    }
    if {$needsPadding} {
        bytes 1 "Padding"
    }
}

###############################################################################
# Parses IFF chunks until the end of file is reached.
proc iffMain {} {
    while {![end]} {
        parseChunk
    }
}
