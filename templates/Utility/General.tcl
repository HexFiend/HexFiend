# Utility/General.tcl
# 2021 Jul 13 | fosterbrereton | Initial implementation

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

# `report` may be used to add an informative entry to the template output. It is assumed the
# condition causing the report is recoverable (that is, template evaluation can still continue.)
#
# Examples:
#     report "Invalid bKGD chunk length"

proc report {msg} {
    entry "" "REPORT: $msg"
}

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
