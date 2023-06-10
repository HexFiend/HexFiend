# Official specification: https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
# Based on https://github.com/Reeywhaar/psd_lib/blob/master/psd_spec.md

#PROCEDURES

proc padto2 {len} {
	set rem [expr {$len % 2}]
	return [expr {$len + $rem}]
}

proc bits {len label} {
	set data [hex $len]
	set bytes [binary format H* [string range $data 2 end]]
	binary scan $bytes B* bits
	move [expr -$len]
	entry "$label" "0b$bits" $len
	move $len
}

proc pascalString {label {padding 2}} {
	set len [uint8 "$label length"]
	if {$len == 0} {
		entry $label "empty"
		move [expr $padding - 1]
	} else {
		set rem [expr {($len + 1) % $padding}]
		if {$rem == 0} {
			set strlen $len
		} else {
			set strlen [expr {$len - $rem + $padding}]
		}
		ascii $strlen $label
	}
}

proc compression {label} {
	set value [uint16]
	move -2
	if {$value == 0x00} {
		entry $label "Raw" 2
	} elseif {$value == 0x01} {
		entry $label "RLE" 2
	} elseif {$value == 0x02} {
		entry $label "ZIP with prediction" 2
	} elseif {$value == 0x03} {
		entry $label "ZIP without prediction" 2
	} else {
		entry $label "Unknown" 2
	}
	move 2
}

proc colorMode {label} {
	set value [uint16]
	move -2
	if {$value == 0x00} {
		entry $label "Bitmap" 2
	} elseif {$value == 0x01} {
		entry $label "Grayscale" 2
	} elseif {$value == 0x02} {
		entry $label "Indexed" 2
	} elseif {$value == 0x03} {
		entry $label "RGB" 2
	} elseif {$value == 0x04} {
		entry $label "CMYK" 2
	} elseif {$value == 0x07} {
		entry $label "Multichannel" 2
	} elseif {$value == 0x08} {
		entry $label "Duotone" 2
	} elseif {$value == 0x09} {
		entry $label "LAB" 2
	} else {
		entry $label "Unknown" 2
	}
	move 2
}

proc psd_version {label} {
	set version [uint16]
	move -2
	if {$version == 0x01} {
		entry $label "PSD" 2
	} elseif {$version == 0x02} {
		entry $label "PSB" 2
	} else {
		entry $label "Unknown" 2
	}
	move 2
	return $version
}

#TEMPLATE

big_endian

requires 0 "38 42 50 53"; #8BPS

section "Header" {
	ascii 4 "Signature"
	set version [psd_version "Version"]
	bytes 6 "#reserved"
	uint16 "Channels count"
	uint32 "Height"
	uint32 "Width"
	uint16 "Depth"
	colorMode "Color Mode"
}

set cms_len [uint32 "Color mode section length"]
if {$cms_len > 0} {
	bytes $cms_len "Color mode section"
} else {
	entry "Color mode section" "empty"
}

set imrs_len [uint32 "Image resources section length"]
if {$imrs_len > 0} {
	set imrs_end [ expr { [pos] + $imrs_len } ]
	section "Image resources section" {
		set i 0
		while {[pos] < $imrs_end} {
			section "Image resource $i" {
				set signature [ascii 4 "Signature"]
				if {$signature != "8BIM"} {
					move -4
					error "Invalid signature on Image resource $i: $signature, position: [pos]"
				}
				uint16 "ID"
				pascalString "Name" 2
				set data_len [uint32 "Data length"]
				set data_len_padded [padto2 $data_len]
				if {$data_len_padded > 0} {
					bytes $data_len_padded "Data"
				} else {
					entry "Data" "empty"
				}
				set i [incr i]
			}
		}
		sectionvalue $i
	}
} else {
	entry "Image resources section" "empty"
}

if {$version == 0x02} {
	set lars_len [uint64 "Layers resources section length"]
} else {
	set lars_len [uint32 "Layers resources section length"]
}

if {$lars_len > 0} {
	set lars_end [ expr { [pos] + $lars_len } ]
	set channel_info [list]; # contains list of channel lengths per layer

	section "Layers resources section" {
		if {$version == 0x02} {
			set layers_info_len [uint64 "Layers info length"]
		} else {
			set layers_info_len [uint32 "Layers info length"]
		}

		section "Layers info" {
			if {$layers_info_len == 0} {
				entry "Layers count" 0
			} else {
				set layers_count [int16 "Layers count"]; # If it is a negative number, its absolute value is the number of layers and
				                                         # the first alpha channel contains the transparency data for the merged result.
				set layers_count [expr abs($layers_count)]
				sectionvalue $layers_count

				for {set i 0} {$i < $layers_count} {incr i} {
					section "Layer $i" {
						set layer_pos [pos]
						section "Rect" {
							set top [int32 "Top"]
							set left [int32 "Left"]
							set bottom [int32 "Bottom"]
							set right [int32 "Right"]
						}

						sectionvalue "[expr {$bottom - $top}]x[expr {$right - $left}]"

						section "Channel info" {
							set channel_count [uint16 "Count"]
							set channel_lengths [list]
							for {set channel_count_i 0} {$channel_count_i < $channel_count} {incr channel_count_i} {
								set chan_id [int16 "ID"]
								if {$version == 0x02} {
									set chan_len [uint64 "Length"]
								} else {
									set chan_len [uint32 "Length"]
								}
								lappend channel_lengths [dict create "id" $chan_id "len" $chan_len]
							}
							lappend channel_info $channel_lengths
						}


						set signature [ascii 4  "Blend mode signature"]
						if {$signature != "8BIM"} {
							move -4
							error "Invalid signature on layer $i: $signature, position: [pos], layer_pos: $layer_pos"
						}

						ascii 4  "Blend mode"
						uint8    "Opacity"
						uint8    "Clipping"
						bits  1  "Flags"
						uint8    "#padding"

						set extra_data_length [uint32 "Extra data length"]
						set extra_data_end [expr [pos] + [padto2 $extra_data_length]]
						section "Extra Data" {
							set mask_data_length [uint32 "Mask data length"]
							if {$mask_data_length > 0} {
								bytes $mask_data_length "Mask data"
							} else {
								entry "Mask data" "empty"
							}
							set blending_ranges_length [uint32 "Blending ranges length"]
							set blending_ranges_end [expr [pos] + [padto2 $blending_ranges_length]]
							if {$blending_ranges_length < 1} {
								entry "Blending ranges" "empty"
							} else {
								section "Blending ranges" {
									set blending_ranges_i 0
									while {[pos] < $blending_ranges_end} {
										section "Blending range $blending_ranges_i" {
											uint32 "source"
											uint32 "destination"
										}
										set blending_ranges_i [incr blending_ranges_i]
									}
								}
							}

							pascalString "Layer name" 4

							set additional_pos [pos]
							if {[pos] != $extra_data_end} {
								section "Additional info" {
									set entry_i 0
									while {[pos] < $extra_data_end} {
										section "Entry $entry_i" {
											set signature [ascii 4 "Signature"]
											if {$signature != "8BIM"} {
												move -4
												error "Invalid signature on additional info entry $entry_i: $signature, position: [pos]"
											}
											ascii 4 "Key"
											set data_len [uint32 "Length"]
											set data_len_padded [padto2 $data_len]
											if {$data_len_padded > 0} {
												bytes $data_len_padded "Data"
											} else {
												entry "Data" "empty"
											}
										}
									}
								}
							}
						}
						goto $extra_data_end
					}
				}
			}
		}
	}

	section "Channel Data" {
		set layer_i 0
		foreach layer_channels $channel_info {
			section "Layer $layer_i" {
				foreach info $layer_channels {
					set id [dict get $info "id"]
					set length [dict get $info "len"]
					section "Channel $id" {
						compression "Compression method"
						set ch_len [ expr {$length - 2} ]
						if {$ch_len > 0} {
							sectionvalue $ch_len
							bytes $ch_len "Data"
						} else {
							sectionvalue "empty"
						}
					}
				}
			}
			set layer_i [incr layer_i]
		}
	}

} else {
	entry "Layers resources section" "empty"
}

set global_mask_length [uint32 "Global mask length"]
if {$global_mask_length > 0} {
	bytes $global_mask_length "Global mask"
} else {
	entry "Global mask" "empty"
}

if {[expr {$lars_end - [pos]}] > 0} {
	bytes [expr {$lars_end - [pos]}] "Additional layer info"
} else {
	entry "Additional layer info" "empty"
}

goto $lars_end

section "Image Data" {
	compression "Compression method"
	bytes eof "Compressed Data"
}
