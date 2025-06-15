# FileFormats/RIFF.tcl
#
# Template for generic RIFF files. Since this is more or less just a
# little-endian IFF file format, we can reuse the IFF parsing procedures.
# Read the docs in FileFormats/IFF_Common.tcl for a general explanation of the
# parsing procedure.
#
# This basic template could be extended to parse common RIFF chunks, or
# used as a basis for a (re-)implementation of RIFF file formats like WAV, ANI,
# AVI, WebP.
# See Images/ILBM(_Procedures).tcl to see an example on how file formats could
# be implemented.
#
# 2025 Jun 07 | Andreas Stahl | Initial implementation
#
# Documentation referenced:
# - https://en.wikipedia.org/wiki/Resource_Interchange_File_Format
#
# .min_version_required = 2.17;

include "Utility/General.tcl"
include "FileFormats/IFF_Common.tcl"

little_endian

###############################################################################
# RIFF: The basic structured container chunk. Is equivalent to IFF FORM chunks.
# Thus, the actual parsing is just forwarded to parseForm.
proc parseRiff args {parseForm $args}

main_guard {
    iffMain
}
