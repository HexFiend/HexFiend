little_endian
requires 0 "00 00"

# stolen from TIFF.tcl
proc backwardEntry {label value length} {
  move -$length
  entry $label $value $length
  move $length
}


section "Header" {
	uint16 "Reserved"
	set type [ uint16 ]


	if { $type == 1 }  {
		backwardEntry "Type" "Icon" 2 
	} elseif { $type == 2 } {
		backwardEntry "Type" "Cursor" 2
	} else {
		backwardEntry "Type" $type 2
	}
	
	set imagecount [ uint16 "Image count" ]
}
for { set i 0 } { $i < $imagecount } { incr i } {
	section "Image $i" {
		set w [ uint8 ]
		if { $w == 0 } {
			set w 256
		}
		backwardEntry "Width" $w 1
		set h [ uint8 ]
		if { $h == 0 } {
			set h 256
		}
		backwardEntry "Height" $h 1

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
