proc parse_fmt {} {
    global num_channels
    section "Format Descriptor" {
        sectionvalue "Wave sample format"
        set format [uint16]
        if {$format == 0x1} {
            entry "Format" "PCM" 2 [expr [pos]-2]
        } elseif {$format == 0x3} {
            entry "Format" "IEEE_FLOAT" 2 [expr [pos]-2]
        } elseif {$format == 0x6} {
            entry "Format" "ALAW" 2 [expr [pos]-2]
        } elseif {$format == 0x7} {
            entry "Format" "MULAW" 2 [expr [pos]-2]
        } elseif {$format == 0xFFFE} {
            entry "Format" "EXTENSIBLE" 2 [expr [pos]-2]
        } else {
            entry "Format" [format 0x%x $format] 2 [expr [pos]-2]
        }
        set num_channels [int16 "# of Channels"]
        set sample_rate [uint32 "Sample Rate"]
        uint32 "Bytes per second"
        set bytes_per_sample [uint16]
        if {$bytes_per_sample == 0x1} {
            entry "Block Align" "8 bit mono" 2 [expr [pos]-2]
        } elseif {$bytes_per_sample == 0x2} {
            entry "Block Align" "8 bit stereo / 16 bit mono" 2 [expr [pos]-2]
        } elseif {$bytes_per_sample == 0x4} {
            entry "Block Align" "16 bit stereo" 2 [expr [pos]-2]
        } else {
           entry "Block Align" [format 0x%x $bytes_per_sample] 2 [expr [pos]-2]
        }
        uint16 "Bits per sample"
        if {$format == 0xFFFE} {
            section "Extended Format" {
                uint16 "Extended Size"
                uint16 "Valid bits per sample"
                uint32 -hex "Channel Map"
                uuid "Format GUID"
            }
        } else {
            entry "Extended Format" "(Not Present)"
        }
    }
}

proc parse_peak {} {
    global num_channels
    section "Channel Peak Descriptor" {
        uint32 "PEAK chunk version"
        uint32 "Timestamp"
        for {set i 0} {$i < $num_channels} {incr i} {
            section [format "Channel %d Peak" $i] {
                float "Value"
                uint32 "Position"
            }            
        }
    }
}

proc parse_cue {} {
    section "Cue List" {
        set count [uint32 "List Count"]
        for {set i 0} { $i < $count } { incr i } {
            section $i {
                uint32 "Cue Point ID"
                uint32 "Sample Position"
                ascii 4 "Sited Chunk ID"
                uint32 "Chunk Start"
                uint32 "Block Start"
                uint32 "Sample Offset"
            }
        }
    }
}

proc parse_labl {length} {
    section "Simple Label" {
        uint32 "Cue Point ID"
        ascii [expr $length - 4] "Name"
    }
}

proc parse_ltxt {length} {
    section "Labeled Range" {
        uint32 "Cue Point ID"
        uint32 "Sample Length"
        ascii 4 "Purpose Code"
        hex 2 "Country"
        hex 2 "Language"
        hex 2 "Dialect"
        hex 2 "Code Page"
        set text_length [expr $length - 20]
        if {$text_length > 0} {
            ascii $text_length "Name"
        }
    }
}

proc parse_bext {chunk_size} {
    section "Broadcast-Wave Metadata" {
       ascii 256 "Description" 
        ascii 32 "Originator"
        ascii 32 "Originator Ref" 
        ascii 10 "Date"
        ascii 8 "Time"
        uint64 "Time Reference"
        set bext_version [uint16 "BEXT chunk version"]
        if {$bext_version > 0} {
            section "UMID Field" { 
                sectionvalue "SMPTE Universal Material Identifier"
                hex 10 "Universal Label"
                hex 1 "Material Type"
                hex 1 "Number creation method"
                set remaining_umid [ uint8 "UMID Size"]
                hex 3 "Instance Number"
                hex 16 "Material Number"
                if {$remaining_umid == 0x33} {
                    section "UMID Source Pack" { 
                        hex 8 "Time Data"
                        hex 12 "Geospatial Data"
                        ascii 4 "Country Code"
                        ascii 4 "Organization Code"
                        ascii 4 "User Code"
                    }
                } else {
                    entry  "UMID Source Pack" "(Not Present)"
                    hex 32
                }
            }
        } else {
            entry "UMID Field" "(Not Present)"
            hex 64
        }

        if {$bext_version > 1} {
            section "EBU Loudness Metadata" { 
                entry "Integrated Loudness" [expr double([uint16]) / double(100)] 
                entry "Loudness Range" [expr double([uint16]) / double(100)] 
                entry "True Peak" [expr double([uint16]) / double(100)] 
                entry "Max Momentary Loudness" [expr double([uint16]) / double(100)] 
                entry "Max Short Term Loudness" [expr double([uint16]) / double(100)] 
            }
        } else {
                entry "EBU Loudness Metadata" "(Not Present)"
                uint16
                uint16
                uint16
                uint16
                uint16
        }

        move 180
        set coding_history_length [expr $chunk_size - 602]
        if {$coding_history_length > 0} {
            ascii $coding_history_length "Coding History"
        } else {
            entry "Coding History" "(Not Present)"
        }
    }
}

proc parse_fact {} {
    uint32 "Sample Count"
}

proc parse_chunk {signature length} {
    entry "Chunk Contents" "" $length
    set content_start [pos]
    switch $signature {
        "fmt " { parse_fmt }
        "PEAK" { parse_peak }
        "bext" { parse_bext $length}
        "fact" { parse_fact }
        "cue " { parse_cue }
        "labl" { parse_labl $length}
        "ltxt" { parse_ltxt $length}
    }
    goto [expr $content_start + $length + ($length % 2)]
}

proc parse_list {length ds64} {
    section "Chunk List" {
        set remain $length
        set index 0
        while {$remain > 0} {
            section $index {
                set chunk_signature [ascii 4 "Chunk Signature"]
                
                if {[dict exists $ds64 $chunk_signature]} {
                    uint32 ;# Will be 0xFFFFFFFF
                    set chunk_size [dict get $ds64 $chunk_signature]
                    entry "Chunk Size DS64" $chunk_size
                } else {
                    set chunk_size [uint32 "Chunk Size"]
                }

                set chunk_displancement [expr $chunk_size + $chunk_size % 2 ]

                if {$chunk_signature == "LIST"} {
                    ascii 4 "LIST Form"
                    parse_list [expr $chunk_size - 4] $ds64
                } else {
                    parse_chunk $chunk_signature $chunk_size
                }
            }
            incr index
            set remain [expr $remain - ($chunk_displancement + 8) ]
        }
    }
}

proc parse_rf64 {} {
    section "RF64 Extended Header" {
        ascii 4 "DS64 Header Signature"
        set ds64_length [uint32 "DS64 Header Size"]
        set ds64_start [pos]

        set rf64_size [uint64 "Form Size"]
        set data_size [uint64 "Data Chunk Size"]
        uint64; # dead value, historically was frame count
        
        set ds64_dict [dict create "data" $data_size]
        set count [uint32 "Long Chunk Table Length"]

        for {set i 0} {$i < $count} {incr i}  {
            dict set $ds64_dict [ascii 4 "Long Chunk ID"] [uint64 "Long Chunk Size"]
        }
    }
    goto [expr $ds64_start + $ds64_length]
    parse_list [expr $rf64_size - ( 12 + $ds64_length )] $ds64_dict
}

proc parse_wave length {
    set remain [expr $length - 4]
    set empty_ds64 [dict create]
    parse_list $remain $empty_ds64
}

little_endian
requires 8 "57 41 56 45" ;# WAVE
set header_signature [ascii 4 "Header Signature"]
set riff_size [uint32 "RIFF Size"]
set riff_form [ascii 4 "RIFF Form"]
if {$header_signature == "RF64" || $header_signature == "BW64"} {
    parse_rf64 
} elseif {$header_signature == "RIFF" } {
    parse_wave $riff_size
} else {
    error "Not a WAVE file"
}
