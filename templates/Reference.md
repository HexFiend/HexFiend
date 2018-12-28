# Reference

Hex Fiend extends Tcl with additional commands for interacting with the opened file. Many of these commands were heavily inspired by [WinHex](https://www.x-ways.net/winhex/templates/).

| Command  | Description | Example |
| ------------- | ------------- | ------------- |
| uint64 *label*  | Reads an unsigned 64-bit integer  | `uint64 "Label"` |
| int64 *label* | Reads a signed 64-bit integer  | `int64 "Label"` |
| uint32 *label* | Reads an unsigned 32-bit integer  | `uint32 "Label"` |
| int32 *label* | Reads a signed 32-bit integer  | `int32 "Label"` |
| uint16 *label* | Reads an unsigned 16-bit integer  | `uint16 "Label"` |
| int16 *label* | Reads a signed 16-bit integer  | `int16 "Label"` |
| uint8 *label* | Reads an unsigned 8-bit integer  | `uint8 "Label"` |
| int8 *label* | Reads a signed 8-bit integer  | `int8 "Label"` |
| float *label* | Reads a 32-bit floating point  | `float "Label"` |
| double *label* | Reads a 64-bit floating point  | `double "Label"` |
| uuid *label* | Reads 16-byte UUID | `uuid "GUID"` |
| macdate *label* | Reads classic Mac OS 4-byte date (seconds since January 1, 1904) | `macdate "CreateDate"` |
| big_endian | Sets the endian mode to big | `big_endian` |
| little_endian | Sets the endian mode back to little (default) | `little_endian` |
| bytes *len* *label* [v2.10] | Reads *len* bytes | `bytes 128 "Data"` |
| hex *len* *label* | Reads *len* bytes as hexadecimal | `hex 16 "UUID"` |
| ascii *len* *label* | Reads *len* bytes as ASCII | `ascii 32 "Name"` |
| utf16 *len* *label* | Reads *len* bytes as UTF16 | `utf16 12 "Name"` |
| move *len* | Moves the file pointer *len* bytes, can be negative | `move -4` |
| goto *position* | Moves the file pointer to *position*, relative to the anchor | `goto 10` |
| end | Returns true if the file is eof | `while {![end]} { ... }` |
| requires *offset* *hex* | Restricts template to data whose bytes at *offset* match *hex* | `requires 510 "55 AA"` |
| zlib_uncompress *data* | Decompress *data* via zlib | `zlib_uncompress $compressed_data` |
