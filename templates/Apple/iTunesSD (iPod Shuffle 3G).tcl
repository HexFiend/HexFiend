# https://web.archive.org/web/20131016014401/https://shuffle3db.wikispaces.com/iTunesSD3gen
little_endian
while {![end]} {
    set chunk_id [ascii 4 "Chunk ID"]
    if {$chunk_id == "bdhs"} {
        section "Shuffle Database" {
            set db_version_ [hex 4 "DB Version?"]
            set chunk_size [uint32 "Chunk Size"]
            set total_number_of_tracks [uint32 "Total Tracks"]
            set total_number_of_playlists [uint32 "Total Playlists"]
            set unknown [bytes 8]
            set max_volume [bytes 1 "Max Volume"]
            set voiceover_enabled [bytes 1 "Voicover Enabled"]
            set unknown [bytes 2]
            set total_tracks_without_podcasts [uint32 "Total Tracks (Excluding Podcasts and AudioBooks)"]
            set track_header_offset [uint32 "Track Header Offset"]
            set playlist_header_offset [uint32 "Playlist Header Offset"]
            set unknown [bytes 20]
        }
    }
    if {$chunk_id == "hths"} {
        section "Track Header" {
            set chunk_size [uint32 "Chunk Size"]
            set number_of_tracks [uint32 "number_of_tracks"]
            set unknown [bytes 8]
            for { set i 0}  {$i < $number_of_tracks} {incr i} {
                set track_offset [uint32 "Track Offset"]
            }
        }
    }
    if {$chunk_id == "rths"} {
        section "Track" {
            set chunk_size [uint32 "Chunk Size"]
            set start_at_pos_ms [uint32 "start_at_pos_ms"]
            set stop_at_pos_ms [uint32 "stop_at_pos_ms"]
            set volume_gain [uint32 "volume_gain"]
            set filetype [uint32 "filetype"]
            set filename [ascii 256 "filename"]
            set bookmark [uint32 "bookmark"]
            set dontskip [bytes 1 "dontskip"]
            set remember [bytes 1 "remember"]
            set unintalbum [bytes 1 "unintalbum"]
            set unknown [bytes 1]
            set pregap [uint32 "pregap"]
            set postgap [uint32 "postgap"]
            set numsamples [uint32 "numsamples"]
            set unknown [bytes 4]
            set gapless [uint32 "gapless"]
            set unknown [bytes 4]
            set albumid [uint32 "albumid"]
            set track [uint16 "track"]
            set disc [uint16 "disc"]
            set unknown [bytes 8]
            set dbid [hex 8 "dbid"]
            set artistid [uint32 "artistid"]
            set unknown [bytes 32]
        }
    }
    if {$chunk_id == "hphs"} {
        section "Playlist Header" {
            set chunk_size [uint32 "Chunk Size"]
            set number_of_playlists [uint32 "number_of_playlists"]
            set number_of_non_podcast_lists [uint16 "number_of_non_podcast_lists"]
            set number_of_master_lists [uint16 "number_of_master_lists"]
            set number_of_non_audiobook_lists [uint16 "number_of_non_audiobook_lists"]
            set unknown [bytes 2]
            for { set i 0}  {$i < $number_of_playlists} {incr i} {
                set playlist_offset [uint32 "Playlist Offset"]
            }
        }
    }
    if {$chunk_id == "lphs"} {
        section "Playlist" {
            set chunk_size [uint32 "Chunk Size"]
            set number_of_songs [uint32 "number_of_songs"]
            set number_of_nonaudio [uint32 "number_of_nonaudio"]
            set dbid [hex 8 "dbid"]
            set listtype [uint32 "listtype"]
            set unknown [bytes 16]
            for { set i 0}  {$i < $number_of_songs} {incr i} {
                set track_id [uint32 "Track ID"]
            }
        }
    }
}
