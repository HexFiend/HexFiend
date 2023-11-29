# Byte Themes

Byte Themes provide a way to customize the foreground color of each byte depending on its value. They're available starting with verison 2.17. Currently they are designed for dark mode. Suggestions on light mode themes are welcomed!

# Location

Hex Fiend ships with some built-in themes as part of the app bundle. They can be found at:

```
Hex Fiend.app/Contents/Resources/ColorByteThemes
```

They may also be stored inside the app support folder:

```
~/Library/Application Support/com.ridiculousfish.HexFiend/ColorByteThemes
```

Files should use the "json5" extension.

# Format

Byte Themes are JSON5 files. This limits them to macOS 12 and greater, where support for JSON5 was added.

Here is an example:

```
{
    dark: {
        null: 0x999999,
        printable: "systemCyan",
        whitespace: "systemGreen",
        other: "systemGreen",
        extended: "systemYellow",
    },
    light: {
        null: 0x999999,
        printable: "systemCyan",
        whitespace: "systemGreen",
        other: "systemGreen",
        extended: "systemYellow",
    }
}
```

The format starts with the theme variant, light or dark. Each variant supports pre-defined categories. Each category maps to one or more byte values, listed below:

- null: 0
- printable: 33 - 126
- whitespace: 9, 10, 13, 32
- extended: 128 - 255
- other: everything else

The value for each category can be a number indicating the RGB color (hex preferred), or a name matching an [NSColor standard color](https://developer.apple.com/documentation/appkit/nscolor/standard_colors).

## Custom Ranges

The categories listed above use pre-defined byte ranges. To support a different set of ranges, custom expressions are supported via [NSPredicate](https://developer.apple.com/documentation/foundation/nspredicate?language=objc).

For example, to make all ASCII question marks red:

```
{
    dark: {
        ...
        custom: [
            {"$b == 0x3F": "systemRed"}
        ],
    }
}
```

The "custom" category is a list of expressions mapping to colors. Each expression should operate on the "$b" variable, which represents the byte integer value. If an expression matches, the pre-defined categories above are skipped.
