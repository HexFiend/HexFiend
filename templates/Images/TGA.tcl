# based off
# https://en.wikipedia.org/wiki/Truevision_TGA#Header
# http://www.paulbourke.net/dataformats/tga/
# https://www.sweetscape.com/010editor/repository/files/TGA.bt

little_endian

section "Header" {
    set id_length [ uint8 "ID length" ]
    uint8 "Color map type"
    uint8 "Image type"                  ;# datatypecode

    # TODO translate image type into:
    # 0  -  No image data included.
    # 1  -  Uncompressed, color-mapped images.
    # 2  -  Uncompressed, RGB images.
    # 3  -  Uncompressed, black and white images.
    # 9  -  Runlength encoded color-mapped images.
    #10  -  Runlength encoded RGB images.
    #11  -  Compressed, black and white images.
    #32  -  Compressed color-mapped data, using Huffman, Delta, and
    #       runlength encoding.
    #33  -  Compressed color-mapped data, using Huffman, Delta, and
    #       runlength encoding.  4-pass quadtree-type process.

    section "Color map specification" {
        uint16 "First entry index"      ;# colourmaporigin
        set color_map_length     [ uint16 "Color map length" ]
        set color_map_entry_size [ uint8 "Color map entry size" ]
    }

    section "Image specification" {
        uint16 "X-origin"
        uint16 "Y-origin"
        set width  [ uint16 "Width" ]
        set height [ uint16 "Height" ]
        set bpp    [ uint8 "Bits per pixel" ]

        ;# bit field. bits 3-0 give the alpha channel depth, bits 5-4 give direction
        uint8 "Image descriptor"
    }

    if {$id_length > 0} {
        hex $id_length "Image ID"
    }
}

set color_map_size [ expr {$color_map_entry_size * $color_map_length} ]
if {$color_map_size > 0} {
    hex $color_map_size "Color map data"
}

# TODO pixel_data_size incorrect on RLE images
set pixel_data_size [ expr { $bpp / 8 } ]
set image_data_size [ expr { $width * $height * $pixel_data_size } ]
if {$image_data_size > 0} {
    hex $image_data_size "Image data"
}

if {![end]} {
    section "Footer" {
        uint32 "Extension offset"
        uint32 "Developer area offset"
        ascii 18 "Signature"  ;# "TRUEVISION-XFILE.\0"
    }
}

# TODO: support "Extension area", https://en.wikipedia.org/wiki/Truevision_TGA#Extension_area_(optional)
