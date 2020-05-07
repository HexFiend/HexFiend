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
        int16 "Format"
        set num_channels [int16 "# of Channels"]
        set sample_rate [uint32 "Sample Rate"]
        uint32 "Byte Rate"
        set bytes_per_sample [uint16 "Bytes per sample"]
        uint16 "Bits per sample"
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
    } else {
        move $chunk_size
    }
    endsection
}
