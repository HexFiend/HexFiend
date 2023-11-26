<img align="right" src="docs/screenshot.png?raw=true">

# Hex Fiend

A fast and clever open source hex editor for macOS.

Download the latest version from the [releases](https://github.com/ridiculousfish/HexFiend/releases) page.

![CI](https://github.com/ridiculousfish/HexFiend/workflows/CI/badge.svg)

## Features

- **Insert, delete, rearrange.**  Hex Fiend does not limit you to in-place changes like some hex editors.
- **Work with huge files.**  Hex Fiend can handle as big a file as you’re able to create.  It’s been tested on files as large as 118 GB.
- **Small footprint.**  Hex Fiend does not keep your files in memory.  You won’t dread launching or working with Hex Fiend even on low-RAM machines.
- **Fast.**  Open a huge file, scroll around, copy and paste, all instantly.  Find what you’re looking for with fast searching.
- **Binary diff.**  Hex Fiend can show the differences between files, taking into account insertions or deletions. Simply open two files in Hex Fiend and then use the File > Compare menus.
- **Smart saving.**  Hex Fiend knows not to waste time overwriting the parts of your files that haven’t changed, and never needs temporary disk space.
- **Data inspector.**  Interpret data as integer or floating point, signed or unsigned, big or little endian.
- **Binary templates.**  Visualize the structure of a file through scripting. See [documentation](https://github.com/ridiculousfish/HexFiend/tree/master/templates).
- **Embeddable!**  It’s really easy to incorporate Hex Fiend’s hex or data views into your app using the Hex Fiend framework.  Its permissive BSD-style license won’t burden you. See the [API reference](http://ridiculousfish.com/hexfiend/docs/) for details. Check out the [projects using Hex Fiend](https://github.com/HexFiend/HexFiend/blob/master/docs/ProjectsUsingHexFiend.md).
