# Quick and Dirty JPG Format by Lemnet

big_endian
requires 0 "FF D8"

proc getmarker {marker} {
	switch $marker {
		65472 {return "SOF0"}  # 0xFFCO
		65473 {return "SOF1"}  # 0xFFC1
		65474 {return "SOF2"}  # 0xFFC2
		65475 {return "SOF3"}  # 0xFFC3
		65476 {return "DHT"}   # 0xFFC4
		65477 {return "SOF5"}  # 0xFFC5
		65478 {return "SOF6"}  # 0xFFC6
		65479 {return "SOF7"}  # 0xFFC7
		65480 {return "JPG"}   # 0xFFC8
		65481 {return "SOF9"}  # 0xFFC9
		65482 {return "SOF10"} # 0xFFCA
		65483 {return "SOF11"} # 0xFFCB
		65484 {return "DAC"}   # 0xFFCC
		65485 {return "SOF13"} # 0xFFCD
		65486 {return "SOF14"} # 0xFFCE
		65487 {return "SOF15"} # 0xFFCF
		65488 {return "RST0"}  # 0xFFD0
		65489 {return "RST1"}  # 0xFFD1
		65490 {return "RST2"}  # 0xFFD2
		65491 {return "RST3"}  # 0xFFD3
		65492 {return "RST4"}  # 0xFFD4
		65493 {return "RST5"}  # 0xFFD5
		65494 {return "RST6"}  # 0xFFD6
		65495 {return "RST7"}  # 0xFFD7
		65496 {return "SOI"}   # 0xFFD8
		65497 {return "EOI"}   # 0xFFD9
		65498 {return "SOS"}   # 0xFFDA
		65499 {return "DQT"}   # 0xFFDB
		65500 {return "DNL"}   # 0xFFDC
		65501 {return "DRI"}   # 0xFFDD
		65502 {return "DHP"}   # 0xFFDE
		65503 {return "EXP"}   # 0xFFDF
		65504 {return "APP0"}  # 0xFFE0
		65505 {return "APP1"}  # 0xFFE1
		65506 {return "APP2"}  # 0xFFE2
		65507 {return "APP3"}  # 0xFFE3
		65508 {return "APP4"}  # 0xFFE4
		65509 {return "APP5"}  # 0xFFE5
		65510 {return "APP6"}  # 0xFFE6
		65511 {return "APP7"}  # 0xFFE7
		65512 {return "APP8"}  # 0xFFE8
		65513 {return "APP9"}  # 0xFFE9
		65514 {return "APP10"} # 0xFFEA
		65515 {return "APP11"} # 0xFFEB
		65516 {return "APP12"} # 0xFFEC
		65517 {return "APP13"} # 0xFFED
		65518 {return "APP14"} # 0xFFEE
		65519 {return "APP15"} # 0xFFEF
		65520 {return "JPG0"}  # 0xFFFO
		65521 {return "JPG1"}  # 0xFFF1
		65522 {return "JPG2"}  # 0xFFF2
		65523 {return "JPG3"}  # 0xFFF3
		65524 {return "JPG4"}  # 0xFFF4
		65525 {return "JPG5"}  # 0xFFF5
		65526 {return "JPG6"}  # 0xFFF6
		65527 {return "JPG7"}  # 0xFFF7
		65528 {return "JPG8"}  # 0xFFF8
		65529 {return "JPG9"}  # 0xFFF9
		65530 {return "JPG10"} # 0xFFF9
		65531 {return "JPG11"} # 0xFFFB
		65532 {return "JPG12"} # 0xFFFC
		65533 {return "JPG12"} # 0xFFFD
		65534 {return "COM"}   # 0xFFFE
		default {return "unknow"}
	}
}

section "SOI" {
	hex 2 "marker"
	entry "(lenght)" 2
}
while {![end]} {
	set marker [uint16]
	if {$marker == 65497} { # 0xFFD9 EOI
		move -2
		section "EOI" {
			hex 2 "marker"
			entry "(lenght)" 2
		}
		break
	} else {
		set mark [getmarker $marker]
		set len [uint16]
		move -4
		section "$mark" {
			hex 2 "marker"
			uint16 "length"
			hex [expr $len -2] "data"
		}
		if {$marker == 65498} { # 0xFFDA SOS
			set pos0 [pos]
			while {![end]} {
				if {[uint8] == 255} { # 0xFF
					set tmp [uint8]
					if { $tmp == 196 || $tmp == 217 } { # 0xC4 or 0xD9
						set pos1 [pos]
						goto $pos0
						section "ECD" {
							hex [expr $pos1-$pos0-2] "data"
							entry "(lenght)" [expr $pos1-$pos0-2]
						}
						break
					}
				}
			}
		}
	}
}