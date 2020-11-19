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
        set format [uint16 -hex "Format"]
        set num_channels [int16 "# of Channels"]
        set sample_rate [uint32 "Sample Rate"]
        uint32 "Bytes per second"
        set bytes_per_sample [uint16 "Block Align"]
        uint16 "Bits per sample"
        if {$format == 0xFFFE} {
            section "WAVEFORMATEXTENDED"
            uint16 "Extended Size"
            uint16 "Valid bits per sample"
            uint32 -hex "Channel Map"
            uuid "Format GUID"
            endsection
	    } else {
            move [expr $chunk_size - 16]
        }
    } elseif { $chunk_id == "PEAK" } {
        uint32 "PEAK chunk version"
        uint32 "Timestamp"
        for {set i 0} {$i < $num_channels} {incr i} {
            section [format "Channel %d Peak" $i]
            float "Value"
            uint32 "Position"
            endsection
        }
    } elseif { $chunk_id == "fact" } {
        hex 4 "Data"
    } elseif { $chunk_id == "data" } {
        set num_samples [expr $chunk_size / $bytes_per_sample]
        entry "# of Samples" $num_samples
        set duration [expr double($num_samples) / double($sample_rate)]
        entry "Duration" [format "%0.3f s" $duration]
        move $chunk_size
    } elseif {$chunk_id == "bext"} {
        ascii 256 "Description" 
        ascii 32 "Originator"
        ascii 32 "Originator Ref" 
        ascii 10 "Date"
        ascii 8 "Time"
        uint64 "Time Reference"
        set bext_version [uint16 "BEXT chunk version"]
        if {$bext_version > 0} {
            hex 32 "UMID"
            hex 32 "UMID Ext"
        } else {
            hex 64
        }
        uint16
        uint16
        uint16
        uint16
        uint16
        move 180
        set coding_history_length [expr $chunk_size - 602]
        if {$coding_history_length > 0} {
            ascii $coding_history_length "Coding History"
        }
    } elseif {$chunk_id == "LIST"} {
        set list_form [ascii 4 "LIST Form"]

        if {$list_form == "INFO"} {
            set remain [expr $chunk_size - 4]
            section "INFO Metadata"
            while {$remain > 0} { 
                section "Entry"
                ascii 4 "Key"
                set field_length [uint32 "Value Length"]
                ascii $field_length "Value"
                endsection
                set remain [expr $remain - 8 - $field_length]
            }
            endsection            
        } else {
            move [expr $chunk_size - 4]
        }
    } else {
        move $chunk_size
    }
    endsection
}
