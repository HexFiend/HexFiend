# Utility/General.tcl
# 2021 Jul 13 | fosterbrereton | Initial implementation
#
# .hidden = true;

hf_min_version_required 2.15

####################################################################################################
# `die` may be used to preemptively terminate a template evaluation. This can be useful when the
# file being analyzed is in some unknown state and recovery is not possible. The command takes an
# optional description string to guide the debugging/analysis process. The command will also output
# the current read offset within the file to assist in the same.
#
# Examples:
#     die                 # Reports "died"
#     die "invalid value" # Reports "invalid value"

proc die {{msg "died"}} {
    set where [pos]
    error "Fatal template error: $msg. Read offset: $where"
}

####################################################################################################
# `assert` should be used to ensure a binary file's state is self-consistent. In the event an
# assertion does not hold, it is assumed that template evaluation is non-recoverable, and should
# preemptively terminate. Like `die`, this command takes an optional message string, and will
# report the read head position within the file.
#
# Examples:
#     assert { $apple_count == $orange_count }                  # Reports "assertion does not hold"
#     assert { $apple_count == $orange_count } "count mismatch" # Reports "count mismatch"

proc assert {cond {msg "assertion does not hold"}} {
    if {![uplevel 1 expr $cond]} { die "$msg ($cond)" }
}

####################################################################################################
# `check` may be used to ensure binary file state in a recoverable way. In the event a check fails,
# an entry will be added to the template output.
#
# Examples:
#     check { $tag_mark == 42 }

proc check {cond} {
    if {![uplevel 1 expr $cond]} {
        entry "" "CHECK: ($cond) does not hold" 1 [expr [pos] - 1]
    }
}

####################################################################################################
# `report` may be used to add an informative entry to the template output. It is assumed the
# condition causing the report is recoverable (that is, template evaluation can still continue.)
#
# Examples:
#     report "Invalid bKGD chunk length"

proc report {msg} {
    entry "" "REPORT: $msg"
}

####################################################################################################
# `sentry` should be used to ensure a read operation is exactly as long as expected. This can be
# useful in file formats where a sub-structure is length-prefixed, and the reading of structure is
# expected to be exactly that length.
#
# Example:
#     section "Chunk" {
#         set length [uint32 "Length"]
#         sentry $length {
#             # ... process the chunk
#         }
#         # At this point, if the read position isn't exactly $length bytes from when
#         # the sentry block began, template evaluation will error out.
#         hex 4 "CRC"
#     }

proc sentry {length body} {
    set sentry_start [pos]
    uplevel 1 $body
    set sentry_end [pos]
    set read_length [expr $sentry_end - $sentry_start]
    assert { $read_length == $length } "Expected to read $length bytes; read $read_length instead"
}

####################################################################################################
# `jumpa` and `jumpr` may be used to temporarily move the read position during binary file
# interpretation. An example here is reading Exif data, where longer metadata values are stored at
# a remote offset instead of inline. `jumpa` takes an absolute offset from the anchor point;
# `jumpr` takes a relative one from the current read position (and therefore can be a negative
# number.) At the end of the body the read position is restored to its original offset.
#
# Example:
#     set header_pos [...] # Some absolute header offset
#     set offset [uint32 "Remote Offset"]
#     jumpa [expr $header_pos + $offset] {
#         set result [$read_proc $component_count] # Remote read
#     }
#     # At this point the read head is restored to just after the read of $offset

proc jumpa {position body} {
    set marker [pos]
    goto $position
    uplevel 1 $body
    goto $marker
    return $marker
}

proc jumpr {position body} {
    set marker [pos]
    move $position
    uplevel 1 $body
    goto $marker
    return $marker
}

####################################################################################################
# `main_guard` may be used as a high-level error/exception catch-all. Without this proc, template
# evaluations that error out discard the entry tree that's been constructed, and shows just the
# error in the template area. This proc will capture the error and dump it as a final entry to the
# template evaluation, and preserve any entries that have already been added. The intent is to give
# template users a better understanding of what was interpreted correctly before things went off
# the rails. You should only use `main_guard` once, at the start of processing of your main
# template file.
#
# Example:
#     # Within DNG.tcl:
#     main_guard {
#         Exif
#     }
proc main_guard {body} {
    if [catch {
        uplevel 1 $body
    }] {
        uplevel 1 { entry "FATAL" $errorInfo }
    }
}

####################################################################################################
# `human_size` may be used to describe a size in more human-readable terms, using SI units for the
# value with 2-3 significant digits.

proc human_size {size} {
    if {$size == 0} { return "0 bytes" }

    switch [::tcl::mathfunc::int [::tcl::mathfunc::floor [::tcl::mathfunc::log10 $size]]] {
        3 -
        4 -
        5 {
            set size [expr $size / 1024.0]
            return [format "%.2f KB" $size]
        }
        6 -
        7 -
        8 {
            set size [expr $size / (1024.0 * 1024.0)]
            return [format "%.2f MB" $size]
        }
        9 -
        10 -
        11 {
            set size [expr $size / (1024.0 * 1024.0 * 1024.0)]
            return [format "%.2f GB" $size]
        }
        default { return "$size bytes"}
    }
}

####################################################################################################
