# FileFormats/IFF.tcl
#
# Template for generic IFF files. Read the docs in FileFormats/IFF_Common.tcl
# for a general explanation of the parsing procedure.
# See Images/ILBM(_Procedures).tcl to see how a file format can be implemented.
#
# 2025 Jun 03 | Andreas Stahl | Initial implementation
#
# Documentation referenced:
# - EA IFF 85 https://www.martinreddy.net/gfx/2d/IFF.txt
#
# Author(s)
# - Andreas Stahl https://www.github.com/nonsquarepixels
#
# .types = ( iff );
# .min_version_required = 2.17;

include "Utility/General.tcl"
include "FileFormats/IFF_Common.tcl"

big_endian

main_guard {
    iffMain
}
