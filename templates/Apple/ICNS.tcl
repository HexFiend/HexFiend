# https://en.Wikipedia.org/wiki/Apple_Icon_Image_format
big_endian
requires 0 "69 63 6E 73"
ascii 4 "magic number"
uint32 "file size (B)"
proc chunk_head {} {
	ascii 4 "chunk type"
	uint32 "chunk length (B)"
}
while {![end]} {
	set chunk_type [ascii 4]
	set chunk_length [uint32]
	set chunk_data_length [expr {$chunk_length - 8}]
	move -8
	if {$chunk_type == "TOC "} {
		section "table of contents" {
			chunk_head
			entry "chunk data" "" $chunk_data_length
			move $chunk_data_length
		}
	} elseif {$chunk_type == "info"} {
		section "information chunk" {
			chunk_head
			section "chunk data" {
				sectionvalue "binary plist"
				# https://Medium.com/@karaiskc/281e6da00dbd
				ascii 6 "binary plist magic"
				ascii 2 "plist version"
				str [expr {$chunk_data_length - 8}] "ascii" "plist object table"
			}
		}
	} elseif {$chunk_type == "name"} {
		section "“name” chunk" {
			chunk_head
			entry "chunk data" "" $chunk_data_length
			move $chunk_data_length
		}
	} elseif {$chunk_type == "icnV"} {
		section "Icon Composer version" {
			bytes 4 "version number"
			entry "note" "The version number is a 4-byte big-endian float."
		}
	} else {
		section "icon" {
			ascii 4 "icon type"
			set icon_size ""
			set icon_target_size ""
			set icon_supported_version ""
			set icon_color_depth 0
			set icon_alpha_depth 0
			set icon_formats ""
			set unknown_icon_type 0
			# https://en.Wikipedia.org/wiki/Apple_Icon_Image_format#Icon_types
			switch $chunk_type {
				"ICON" {
					set icon_size "32×32"
					set icon_supported_version "1.0"
					set icon_color_depth 1
					set icon_alpha_depth 0
				}
				"ICN#" {
					set icon_size "32×32"
					set icon_supported_version "6.0"
					set icon_color_depth 1
					set icon_alpha_depth 1
				}
				"icm#" {
					set icon_size "16×16"
					set icon_supported_version "6.0"
					set icon_color_depth 1
					set icon_alpha_depth 1
				}
				"icm4" {
					set icon_size "16×12"
					set icon_supported_version "7.0"
					set icon_color_depth 4
					set icon_alpha_depth 0
				}
				"icm8" {
					set icon_size "16×12"
					set icon_supported_version "7.0"
					set icon_color_depth 8
					set icon_alpha_depth 0
				}
				"ics#" {
					set icon_size "16×16"
					set icon_supported_version "6.0"
					set icon_color_depth 1
					set icon_alpha_depth 1
				}
				"ics4" {
					set icon_size "16×16"
					set icon_supported_version "7.0"
					set icon_color_depth 4
					set icon_alpha_depth 0
				}
				"ics8" {
					set icon_size "16×16"
					set icon_supported_version "7.0"
					set icon_color_depth 8
					set icon_alpha_depth 0
				}
				"is32" {
					set icon_size "16×16"
					set icon_supported_version "8.5"
					set icon_color_depth 24
					set icon_alpha_depth 0
				}
				"s8mk" {
					set icon_size "16×16"
					set icon_supported_version "8.5"
					set icon_color_depth 0
					set icon_alpha_depth 8
				}
				"icl4" {
					set icon_size "32×32"
					set icon_supported_version "7.0"
					set icon_color_depth 4
					set icon_alpha_depth 0
				}
				"icl8" {
					set icon_size "32×32"
					set icon_supported_version "7.0"
					set icon_color_depth 8
					set icon_alpha_depth 0
				}
				"il32" {
					set icon_size "32×32"
					set icon_supported_version "8.5"
					set icon_color_depth 24
					set icon_alpha_depth 0
				}
				"l8mk" {
					set icon_size "32×32"
					set icon_supported_version "8.5"
					set icon_color_depth 0
					set icon_alpha_depth 8
				}
				"ich#" {
					set icon_size "48×48"
					set icon_supported_version "8.5"
					set icon_color_depth 0
					set icon_alpha_depth 1
				}
				"ich4" {
					set icon_size "48×48"
					set icon_supported_version "8.5"
					set icon_color_depth 4
					set icon_alpha_depth 0
				}
				"ich8" {
					set icon_size "48×48"
					set icon_supported_version "8.5"
					set icon_color_depth 8
					set icon_alpha_depth 0
				}
				"ih32" {
					set icon_size "48×48"
					set icon_supported_version "8.5"
					set icon_color_depth 24
					set icon_alpha_depth 0
				}
				"h8mk" {
					set icon_size "48×48"
					set icon_supported_version "8.5"
					set icon_color_depth 0
					set icon_alpha_depth 8
				}
				"it32" {
					set icon_size "128×128"
					set icon_supported_version "10.0"
					set icon_color_depth 24
					set icon_alpha_depth 0
				}
				"t8mk" {
					set icon_size "128×128"
					set icon_supported_version "10.0"
					set icon_color_depth 0
					set icon_alpha_depth 8
				}
				"icp4" {
					set icon_size "16×16"
					set icon_supported_version "10.7"
					set icon_formats "PNG / JPEG 2000"
				}
				"icp5" {
					set icon_size "32×32"
					set icon_supported_version "10.7"
					set icon_formats "PNG / JPEG 2000"
				}
				"icp6" {
					set icon_size "64×64"
					set icon_supported_version "10.7"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic07" {
					set icon_size "128×128"
					set icon_supported_version "10.7"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic08" {
					set icon_size "256×256"
					set icon_supported_version "10.5"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic09" {
					set icon_size "512×512"
					set icon_supported_version "10.5"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic10" {
					set icon_size "1024×1024"
					set icon_target_size "512×512"
					set icon_supported_version "10.7"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic11" {
					set icon_size "32×32"
					set icon_target_size "16×16"
					set icon_supported_version "10.8"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic12" {
					set icon_size "64×64"
					set icon_target_size "32×32"
					set icon_supported_version "10.8"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic13" {
					set icon_size "256×256"
					set icon_target_size "128×128"
					set icon_supported_version "10.8"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic14" {
					set icon_size "512×512"
					set icon_target_size "256×256"
					set icon_supported_version "10.8"
					set icon_formats "PNG / JPEG 2000"
				}
				"ic04" {
					set icon_size "16×16"
					set icon_formats "ARGB"
				}
				"ic05" {
					set icon_size "32×32"
					set icon_formats "ARGB"
				}
				"icsB" {
					set icon_size "36×36"
				}
				"icsb" {
					set icon_size "18×18"
				}
				default {
					set unknown_icon_type 1
				}
			}
			if {$icon_size != "" || $icon_target_size != ""} {
				if {$icon_target_size != ""} {
					sectionvalue "$chunk_type ($icon_target_size@2×)"
				} else {
					sectionvalue "$chunk_type ($icon_size@2×)"
				}
			}
			if {$unknown_icon_type == 0} {
				section "type lookup" {
					if {$icon_size != ""} {
						entry "size" $icon_size
						if {$icon_target_size != ""} {
							entry "retina size" "$icon_target_size@2×"
						}
					}
					if {$icon_color_depth > 0 || $icon_alpha_depth > 0} {
						if {$icon_color_depth > 0 && $icon_alpha_depth > 0} {
							entry "channels" "color & alpha"
						} elseif {$icon_color_depth > 0} {
							entry "channels" "color"
						} else {
							entry "channels" "alpha"
						}
						if {$icon_color_depth > 0} {
							if {$icon_color_depth == 1} {
								entry "color depth" "$icon_color_depth bit"
							} else {
								entry "color depth" "$icon_color_depth bits"
							}
						}
						if {$icon_alpha_depth > 0} {
							if {$icon_alpha_depth == 1} {
								entry "alpha depth" "$icon_alpha_depth bit"
							} else {
								entry "alpha depth" "$icon_alpha_depth bits"
							}
						}
					} elseif {$icon_formats != ""} {
						entry "format(s)" $icon_formats
					}
					if {$icon_supported_version != ""} {
						entry "first version" "macOS $icon_supported_version"
					}
				}
			} else {
				entry "warning" "unrecognised icon type"
			}
			uint32 "chunk length (B)"
			entry "chunk data" "" $chunk_data_length
			move $chunk_data_length
		}
	}
}
