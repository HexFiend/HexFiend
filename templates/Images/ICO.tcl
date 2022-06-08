little_endian
requires 0 "00 00"
section "Header" {
	uint16 "Reserved"
	set type [ uint16 ]
	if { $type == 1 }  {
		entry "Type" "Icon"
	} elseif { $type == 2 } {
		entry "Type" "Cursor"
	} else {
		entry "Type" $type
	}
	
	set imagecount [ uint16 "Image count" ]
}
for { set i 0 } { $i < $imagecount } { incr i } {
	section "Image $i" {
		uint8 "Width"
		uint8 "Height"
		uint8 "Color palette size"
		uint8 "Reserved"
		if { $type == 1 } {
			uint16 "Color planes"
			uint16 "Bits per pixel"
		} else {
			uint16 "Hot spot x"
			uint16 "Hot spot y"
		}
		set isize [ uint32 "Image size" ]
		set ioffset [ uint32 "Image offset" ]

		set p [ pos ]
		goto $ioffset
		bytes $isize "Image data"
		goto $p
	}
}
