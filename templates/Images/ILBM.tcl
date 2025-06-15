# Images/ILBM.tcl
# Template for ILBM (Interleaved Bitmap) and PBM (Planar Bitmap) files.
# This is an IFF file format. Read the docs in FileFormats/IFF_Common.tcl for
# a general explanation of the parsing procedure.
#
# 2022 Jun 28 | Andreas Stahl | Initial implementation.
# 2025 Jun 06 | Andreas Stahl | Extracted IFF procedure, added documentation.
#
# Documentation referenced:
# - https://wiki.amigaos.net/wiki/ILBM_IFF_Interleaved_Bitmap
# - https://moddingwiki.shikadi.net/wiki/LBM_Format
#
# Authors:
# - Andreas Stahl https://www.github.com/nonsquarepixels
#
# .types = ( lbm, ilbm, pbm, bbm, brush, anim );
# .min_version_required = 2.17;

hf_min_version_required 2.17

include "Utility/General.tcl"
include "FileFormats/IFF_Common.tcl"
include "Images/ILBM_Procedures.tcl"

big_endian

main_guard {
    iffMain
}
