requires 0 "52 49 46 46" ;# RIFF
requires 8 "57 41 56 45" ;# WAVE
ascii 4 "Header Chunk ID"
uint32 "File Size"
ascii 4 "Header Chunk Type"
while {![end]} {
    set chunk_id [ascii 4]
    section $chunk_id
    set chunk_size [uint32 "Chunk Size"]
    if {$chunk_id == "fmt "} {
        sectionvalue "Wave sample format"
        set format [uint16 -hex "Format"]
        set num_channels [int16 "# of Channels"]
        set sample_rate [uint32 "Sample Rate"]
        uint32 "Bytes per second"
        set bytes_per_sample [uint16 "Block Align"]
        uint16 "Bits per sample"
        if {$format == 0xFFFE} {
            section "Extended Format" {
                uint16 "Extended Size"
                uint16 "Valid bits per sample"
                uint32 -hex "Channel Map"
                uuid "Format GUID"
            }
	    } else {
            entry "Extended Format" "(Not Applicable)"
            move [expr $chunk_size - 16]
        }
    } elseif { $chunk_id == "PEAK" } {
        uint32 "PEAK chunk version"
        uint32 "Timestamp"
        for {set i 0} {$i < $num_channels} {incr i} {
            section [format "Channel %d Peak" $i] {
                float "Value"
                uint32 "Position"
            }            
        }
    } elseif { $chunk_id == "fact" } {
        hex 4 "Data"
    } elseif { $chunk_id == "data" } {
        sectionvalue "Interleaved audio data"
        set num_samples [expr $chunk_size / $bytes_per_sample]
        entry "# of Samples" $num_samples
        set duration [expr double($num_samples) / double($sample_rate)]
        entry "Duration" [format "%0.3f s" $duration]
        move $chunk_size
        move [expr $chunk_size % 2]
    } elseif {$chunk_id == "bext"} {
        sectionvalue "Broadcast Wave metadata"
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
    } elseif {$chunk_id == "LIST"} {
        set list_form [ascii 4 "LIST Form"]

        if {$list_form == "INFO"} {
            set remain [expr $chunk_size - 4]
            section "INFO Metadata" {
                set info_item 0
                while {$remain > 0} { 
                    section $info_item
                    ascii 4 "Key"
                    set field_length [uint32 "Value Length"]
                    ascii $field_length "Value"
                    endsection
                    set remain [expr $remain - 8 - $field_length - ($field_length % 2)]
                    set info_item [expr $info_item + 1]
                    move [expr $field_length % 2]
                }
            }       
        } else {
            move [expr $chunk_size - 4]
        }
    } elseif {$chunk_id == "umid"} {
        hex 8 "?"
        hex 8 "Time Snap"
        hex 8 "?"
    } else {
        if {$chunk_size % 2 == 1} {
            move [expr $chunk_size + 1]
        } else {
            move $chunk_size
        }
        
    }
    endsection
}
