# Binary Templates

Binary Templates are a new feature in Hex Fiend 2.9 that allow you to visualize the structure of a binary file. They are implemented in [Tcl](https://www.tcl.tk) since this language is easy to embed, easy to write, has a ton of features, and already ships with macOS.

## Getting Started

1. Open a file in Hex Fiend
2. Select from the **Views** menu **Binary Templates**
3. On the right-side of the window the template view will show. Here you can select a template from the templates folder. Templates are stored at `~/Library/Application Support/com.ridiculousfish.HexFiend/Templates`. Each template must have the `.tcl` file extension.

## Writing your First Template

Now that you're familiar with the templates user interface, let's write your first template. As stated before, templates are written using Tcl. If you're already familiar with a programming language, scan through the [tutorial](https://www.tcl.tk/man/tcl8.5/tutorial/tcltutorial.html) to get a feel for the language.

1. With your favorite text editor, create a new file and save it to `~/Library/Application Support/com.ridiculousfish.HexFiend/Templates/First.tcl`.
2. Enter the code below and save:
```tcl
uint32 "UInt32"
```
3. Go back to Hex Fiend and select **Refresh** from the **Templates** drop-down. You should see your template listed as **First** if everything was correct so far.
4. Open any file and change the selection cursor to new locations. You'll see the "UInt32" field update.

Congrats, you've written the most basic and simplest template that actually does something!

## Commands

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
| big_endian | Sets the endian mode to big | `big_endian` |
| little_endian | Sets the endian mode back to little (default) | `little_endian` |
| bytes *len* *label* [v2.10] | Reads *len* bytes | `bytes 128 "Data"` |
| hex *len* *label* | Reads *len* bytes as hexadecimal | `hex 16 "UUID"` |
| ascii *len* *label* | Reads *len* bytes as ASCII | `ascii 32 "Name"` |
| move *len* | Moves the file pointer *len* bytes, can be negative | `move -4` |
| end | Returns true if the file is eof | `while {![end]} { ... }` |

