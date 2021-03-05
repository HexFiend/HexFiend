# Reference

Hex Fiend extends [Tcl](https://www.tcl.tk/) with additional commands for interacting with the opened file. Many of these commands were heavily inspired by [WinHex](https://www.x-ways.net/winhex/templates/).

## Types

Type commands all have the same structure of `type [label]`:

```tcl
uint32 "Size"
```

As of v2.10+ the label argument is optional. When the label is not passed, no entry in the UI will be created. This allows using the returned result strictly programmatically. For example:

```tcl
set size [uint32]
```

| Type        | Description |
| ------------| ----------- |
| uint64      | Reads an unsigned 64-bit integer |
| int64       | Reads a signed 64-bit integer |
| uint32      | Reads an unsigned 32-bit integer |
| int32       | Reads a signed 32-bit integer |
| uint24      | Reads an unsigned 24-bit integer |
| uint16      | Reads an unsigned 16-bit integer |
| int16       | Reads a signed 16-bit integer |
| uint8       | Reads an unsigned 8-bit integer |
| int8        | Reads a signed 8-bit integer |
| uint8_bits  | Read some number of `bits` out of an unsigned 8-bit integer |
| uint16_bits | Read some number of `bits` out of an unsigned 16-bit integer |
| uint32_bits | Read some number of `bits` out of an unsigned 32-bit integer |
| uint64_bits | Read some number of `bits` out of an unsigned 64-bit integer |
| float       | Reads a 32-bit floating point |
| double      | Reads a 64-bit floating point |
| uuid        | Reads 16-byte UUID |
| macdate     | Reads classic Mac OS 4-byte date (seconds since January 1, 1904) |
| fatdate     | Reads FAT, or DOS, 2-byte date (v2.13+) |
| fattime     | Reads FAT, or DOS, 2-byte time (v2.13+) |
| unixtime32  | Reads a UNIX time in (seconds since 00:00:00 UTC on 1 January 1970) |
| unixtime64  | Reads a UNIX time in (seconds since 00:00:00 UTC on 1 January 1970) |

As of v2.11+, unsigned integer types have an optional parameter `-hex` which causes the displayed value to be in hexadecimal, instead of decimal:

```tcl
uint32 -hex "CRC"
```

## Grouping

Any command that takes a label will create a new entry in the user interface with the label provided and a string representation of the data type. However, this could become a long list of entries. Therefore entries can be grouped via the `section` command.

`section` takes a label argument, just like types do. However, no value is associated with the group. To end grouping, use the `endsection` command. Here's an example:

```tcl
section "Header"
uint32 "Size"
endsection
```

There is also the simpler alternative syntax which does not require using `endsection`:

```tcl
section "Header" {
    uint32 "Size"
}
```

Sections can be nested within each other.

Sections by default don't have any value. To set a value on a section, use the `sectionvalue` command (v2.11+), which works on the current section:

```tcl
sectionvalue "Example Value"
```

## Endian

The default endian mode for the type commands above is little. To interpret types as big endian, use the `big_endian` command. To go back to little, use `little_endian`. No arguments are passed.

## File Pointer

The file pointer is automatically moved forward for any command that reads data. However the following commands can be used to alter and access the file pointer's offset.

| Command  | Description | Example |
| ------------- | ------------- | ------------- |
| move *len* | Moves the file pointer *len* bytes, can be negative | `move -4` |
| goto *position* | Moves the file pointer to absolute *position*, relative to the anchor | `goto 10` |
| end | Returns true if the file is at the end (beyond the file length) | `while {![end]} { ... }` |
| pos | Return current file pointer position | `entry label $v 4 [expr [pos]-4]` |
| len | Return file length in bytes ||

## Raw Bytes

Various commands are provided for reading and interpreting multiple bytes.

| Command  | Description | Example |
| ------------- | ------------- | ------------- |
| bytes *len* *label* | Reads *len* bytes as raw data [v2.10+] | `bytes 128 "Data"` |
| hex *len* *label* | Reads *len* bytes as hexadecimal | `hex 16 "UUID"` |
| ascii *len* *label* | Reads *len* bytes as ASCII | `ascii 32 "Name"` |
| utf16 *len* *label* | Reads *len* bytes as UTF16 (via current endian) | `utf16 12 "Name"` |
| str *len* *encoding* *label* | Reads *len* bytes using the specified *encoding* identifier [v2.11+] | `str 8 "utf8" "Name"` |
| cstr *encoding* *label* | Reads a sequence of zero-termited bytes using the specified *encoding* identifier | `cstr "utf8" "Name"` |

A special length value `eof` can be used to go to the end of the file (v2.11+):

```tcl
bytes eof "Compressed Data"
```

## Restrictions

The `requires` command can be used to restrict where the template is used.

| Parameter  | Description |
| ------------- | ------------- |
| offset | Offset in file where restriction begins |
| hex | Bytes as hexadecimal that must match in file |

### Example

```tcl
requires 510 "55 AA" ;# Master Boot Record
```

If the bytes at offset 510 (from the anchor) do not match "55 AA" in hexadecimal, then the template stops executing and errors out. Otherwise execution continues.

## Custom Entries

Occasionally one may need to add entries to the UI not directly related to read data (e.g. programatically calculated values). For this the `entry` command can be used (v2.11+).

| Parameter  | Description |
| ------------- | ------------- |
| label | Label to display |
| value | Value to display |
| length | Length of entry (optional, relative to current file offset) |
| offset | Offset of entry (optional) |

If length or offset is specified, the file pointer is not moved forward.

### Example

```tcl
entry "Channel" $channel
```

## Compression

| Command  | Description | Example |
| ------------- | ------------- | ------------- |
| zlib_uncompress *data* | Decompress *data* via zlib | `zlib_uncompress $compressed_data` |
