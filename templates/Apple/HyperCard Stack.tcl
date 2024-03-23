big_endian

proc c_string {label} {
	set str_start [pos]
	for {set i 1} {![end]} {incr i} {
		if { [uint8] == 0 } {
			break
		}
	}
	set str_end [pos]
	goto $str_start
	set str_length [expr {$str_end - $str_start -1}]
	if { $str_length > 0 } {
		str $str_length "macRoman" $label
	} else {
		entry $label ""
	}
	move 1
}

proc align {} {
	if { [expr ([pos] % 2) != 0] } {
		move 1
	}
}

proc parse_part {number} {
	section "Part $number" {
		set part_size [uint16]
		uint16 "Part ID"
		# 1 button, 2 field
		uint8 "Part Type"
		# 7 hidden, 5 dontWrap, 4 dontSearch, 3 sharedText, 2 fixedLineHeight, 1 autoTab, 0 disabled/lockText
		uint8 "Part Flags"
		set rect_top [int16]
		set rect_left [int16]
		set rect_bottom [int16]
		set rect_right [int16]
		entry "Rect" "$rect_left,$rect_top,$rect_right,$rect_bottom"
		# 15 showName/autoSelect, 14 highlight/showLines, 13 wideMargins/autoHighlight
		# 12 sharedHighlight/multipleLines, 11-8 buttonFamily, 0-3 style
		uint16 "Ext. Part Flags"
		uint16 "titleWidth/lastSelectedLine"
		uint16 "icon/firstSelectedLine"
		int16 "textAlignment"
		int16 "textFontID"
		uint16 "textSize"
		uint16 "textStyle"
		uint16 "lineHeight"
		c_string "Name"
		move 1
		c_string "Script"
		align
	}
}

proc parse_contents {number} {
	section "Contents $number" {
		set part_id [int16]
		if { $part_id < 0 } {
			set real_id [expr -$part_id]
			entry "For Card Part" "$real_id"
		} else {
			entry "For Bg Part" "$part_id"
		}
		set contents_size [uint16 "Contents Size"]
		set pre_style_length_pos [pos]
		set style_length_raw [uint16 "Raw Style/Text Length"]
		set raw_contents_startpos [pos]
		set raw_contents_endpos [expr $raw_contents_startpos + $contents_size - 2]
		if { $style_length_raw > 32767 } {
			set style_length [expr $style_length_raw - 32770]
			bytes $style_length "Style Data"
		} else {
			goto [expr $pre_style_length_pos + 1]
			entry "Style Data" "--"
		}
		set contents_length [expr $raw_contents_endpos - [pos]]
		entry "Text Length" "$contents_length"
		str $contents_length "macRoman" "Text"
		
		align
	}
}

if [catch {
    for {set i 1} {![end]} {incr i} {
    	section "Block $i" {
            set block_start [pos]
			set block_size [uint32] ;
			set block_type [str 4 "macRoman"]
			set block_id [int32] ;
			sectionname "$block_type $block_id ($block_size bytes)"
			switch $block_type {
				"STAK" {
					move 32
					uint32 "Number of Cards"
					uint32 "Some Card ID"
					uint32 "LIST ID"
					set num_free_blocks [uint32 "Number of FREE Blocks"]
					set size_free_blocks [uint32 "Size of FREE Blocks"]
					uint32 "PRNT ID"
					uint32 "Password Hash"
					uint16 "User Level"
					move 2
					# 10 is cantPeek, 11 cantAbort, 13 privateAccess, 14 cantDelete, 15 cantModify
					uint16 "Flags"
					move 18
					move 4
					bytes 4 "Created Version"
					bytes 4 "Edited Version"
					bytes 4 "Compacted Version"
					move 328
					uint16 "Height"
					uint16 "Width"
					move 260
					section -collapsed "Patterns" {
						for {set p 1} {$p <= 40} {incr p} {
							bytes 8 "Pattern $p Data"
						}
					}
					section "Free Blocks" {
						for {set f 1} {$f <= $num_free_blocks} {incr f} {
							section "Free Block $f" {
								uint32 "Offset"
								uint32 "Length"
							}
						}
					}
					goto 1536
					# seems part before script is magical fixed size?
					c_string "Script"
				}
				"LIST" {
					set number_of_tables [uint32]
					move 8
					uint16 "Size of Card Blocks"
					move 16
					section "$number_of_tables Page Blocks" {
						for {set t 0} {$t < $number_of_tables} {incr t} {
							move 2
							uint32 "Page block ID"
						}
					}
				}
				"FREE" {
					sectionname "$block_size bytes unused"
				}
				"PAGE" {
# 					move 12
# 					set block_end_offs [expr {$block_size + $block_start}]
# 					for {set p 0} {[pos] < $block_end_offs} {incr p} {
# 						uint32 "Card ID"
# 						uint8 "Flags"
# 					}
				}
			"BKGD" {
					move 4
					int32 "Picture BMAP ID"
					# 14 cantDelete, 13 hide card picture, 11 dontSearch
					uint16 "Flags"
					move 2
					uint32 "Number of Cards"
					uint32 "Next Bg"
					uint32 "Previous Bg"
					set num_parts [uint16]
					uint16 "Next new Part ID"
					uint32 "Part List Size"
					set num_contents [uint16]
					uint32 "Part Content List Size"
					str 4 "macRoman" "Script Lang. Type"
					section "$num_parts Parts" {
						for {set p 1} {$p <= $num_parts} {incr p} {
							parse_part $p
						}
					}
					section "$num_contents Contents" {
						for {set p 1} {$p <= $num_contents} {incr p} {
							parse_contents $p
						}
					}
				}
			"CARD" {
					move 4
					int32 "Picture BMAP ID"
					# 14 cantDelete, 13 hide card picture, 11 dontSearch
					uint16 "Flags"
					move 10
					uint32 "PAGE ID"
					uint32 "Bg ID"
					set num_parts [uint16]
					uint16 "Next New Part ID"
					uint32 "Size of Part List"
					set num_contents [uint16]
					uint32 "Size of Part Contents List"
					# str 4 "macRoman" "Script Lang. Type"
					section "$num_parts Parts" {
						for {set p 1} {$p <= $num_parts} {incr p} {
							parse_part $p
						}
					}
					section "$num_contents Contents" {
						for {set p 1} {$p <= $num_contents} {incr p} {
							parse_contents $p
						}
					}
					c_string "Name"
					c_string "Script"
				}
				"TAIL" {
					move 4
					set text_length [uint8]
					str $text_length "macRoman" "End Marker Text"
				}
				default {
					entry "Block Data" "" [expr {$block_size - 12}]
					move [expr {$block_size - 12}]
				}
			}
			set known_end [pos]
			set used_length [expr {$known_end - $block_start}]
			set remaining_length [expr {$block_size - $used_length}]
			if {$remaining_length > 0} {
				entry "$remaining_length bytes Excess Data" "" $remaining_length
				move $remaining_length
			}
		}
	}
}] {
	puts $errorInfo
}

