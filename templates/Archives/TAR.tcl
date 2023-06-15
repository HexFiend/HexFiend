# .types = ( public.tar-archive, tar );

little_endian

while {![end]} {

	scan [ascii 100] %s fname
	move 24
	scan [ascii 12] %o size
	move 121
	scan [ascii 8] %s magic
	move -265

	section "file" {

		section "header" {
			ascii 100	fname
			ascii 8 	mode
			ascii 8 	uid
			ascii 8 	gid
			ascii 12 	size
			ascii 12 	mtime
			ascii 8 	chksum
			ascii 1 	linkflag
			ascii 100 	arch_linkname
			ascii 8 	magic
			ascii 32 	uname
			ascii 32 	gname
			ascii 8 	devmajor
			ascii 8 	devminor
			bytes 167 	reserved
		}

		sectionvalue $fname

		set size [expr {int(ceil($size / 512.0)) * 512}]

		if {([pos] + $size < [len]) && ($size > 0)} {
			bytes $size payload
		}

	}
}
