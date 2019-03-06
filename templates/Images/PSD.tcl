# Official specification: https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
# Based on https://github.com/Reeywhaar/psd_lib/blob/master/psd_spec.md

#PROCEDURES

proc padStrLen {len} {
	set len_plus_one [expr {$len + 1}]
	set rem [expr {$len_plus_one % 2}]
	return [expr {$len_plus_one + $rem - 1}]
}

proc padto2 {len} {
	set rem [expr {$len % 2}]
	return [expr {$len + $rem}]
}

#TEMPLATE

big_endian

requires 0 "38 42 50 53"; #8BPS

section "Header" {
	ascii 4 "Signature"
	set version [uint16]; #Version
	move -2
	if {$version == 0x01} {
		entry "Version" "PSD" 2
	} elseif {$version == 0x02} {
		entry "Version" "PSB" 2
	} else {
		entry "Version" "Unknown" 2
	}
	move 2
	bytes 6 "#reserved"
	uint16 "Number of channels"
	uint32 "Height"
	uint32 "Width"
	uint16 "Depth"
	hex 2 "Color Mode"
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
			section "Image Resource $i" {
				ascii 4 "Signature"
				uint16 "ID"
				set name_len [uint8 "Name length"]
				if {$name_len == 0} {
					entry "Name" "empty"
					move 1
				} else {
					str [padStrLen $name_len] "utf8" "Name"
				}
				set data_len [uint32 "Data length"]
				set data_len_padded [padto2 $data_len]
				bytes $data_len_padded "Data"
				set i [incr i]
			}
		}
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
				set layers_count [uint16 "Layers count"]

				for {set i 0} {$i < $layers_count} {incr i} {
					section "Layers $i" {
						section "Rect" {
							uint32 "Top"
							uint32 "Left"
							uint32 "Bottom"
							uint32 "Right"
						}

						section "Channel info" {
							set channel_count [uint16 "count"]
							set channel_lengths [list]
							for {set channel_count_i 0} {$channel_count_i < $channel_count} {incr channel_count_i} {
								uint16 "ID"
								if {$version == 0x02} {
									set chan_len [uint64 "Length"]
								} else {
									set chan_len [uint32 "Length"]
								}
								lappend channel_lengths $chan_len
							}
							lappend channel_info $channel_lengths
						}

						ascii 4  "Blend mode signature"
						ascii 4  "Blend mode key"
						uint8    "Opacity"
						uint8    "Clipping"
						hex   1  "Flags"
						uint8    "#padding"

						set extra_data_length [uint32 "Extra data length"]
						bytes $extra_data_length "Extra data"
					}
				}
			}
		}
	}

	section "Channel Data" {
		set layer_i 0
		foreach layer_channels $channel_info {
			section "Layer $layer_i" {
				set channel_i 0
				foreach length $layer_channels {
					section "Channel $channel_i" {
						hex 2 "Compression method"
						entry "#Data length" [ expr {$length - 2} ]
						if {$length > 2} {
							bytes [ expr {$length - 2} ] "Data"
						} else {
							entry "Data" "empty"
						}
					}
					set channel_i [incr channel_i]
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
	hex 2 "Compression method"
	bytes eof "Compressed Data"
}