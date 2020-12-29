# Reference Templates
# https://www.sweetscape.com/010editor/repository/files/BMP.bt
# https://raw.githubusercontent.com/synalysis/Grammars/master/bitmap.grammar

# Reference Documents
# http://www.digicamsoft.com/bmp/bmp.html
# http://en.wikipedia.org/wiki/BMP_file_format

little_endian
requires 0 "42 4D"
section "Header" {
	ascii 2 "bfType"
	uint32 "bfSize"
	uint16 "bfReserved1"
	uint16 "bfReserved2"
	hex 4 "bfOffBits"
}
section "BITMAPINFOHEADER" {
	uint32 "biSize"
	uint32 "biWidth"
	int32 "biHeight"	; # signed; heights can be negative
	uint16 "biPlanes"
	uint16 "biBitCount"
	uint32 "biCompression"
	uint32 "biSizeImage"
	uint32 "biXPelsPerMeter"
	uint32 "biYPelsPerMeter"
	uint32 "biClrUsed"
	uint32 "biClrImportant"
}
# section "ImageData" {
# 	for {set i 0} {![end]} {incr i} {
# 		uint8 "Byte $i"
# 	}
# }
