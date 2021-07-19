# HexFiend Preferences

This table is intended to document the various (hidden) preferences for the application. Note this is not an exhaustive list of preferences. Rather, they are those that do not have a means of alteration within the GUI and may be useful for development/debugging purposes. You can find more information on reading/writing these values programatically via `man defaults`. The domain for HexFiend is `com.ridiculousfish.HexFiend `.

# Preference Table

| Name | Type | Default | Notes |
|---|---|---|---|
| `BinaryTemplatesAutoCollapseValuedGroups` | `bool` | `false` | If `true`, will auto-collapse template sections that have been given a value (via the `sectionvalue` command.) This includes a section value of `""`, which will display nothing but still collapse the section. |
| `BinaryTemplatesSingleClickAction` and `BinaryTemplatesDoubleClickAction ` | `integer`s | `0` and `1`, respectively | Specify the single- and double-click behavior for sections and entries in the template tree. <br/> - `0`: do nothing <br/> - `1`: scroll to offset <br/> - `2`: select bytes |
| `BinaryTemplateScriptTimeout` | `integer` | `10` | Number of additional sections the template evaluation engine should be given before timing out. This can be useful when analyzing larger binary files, or templates that generate a large number of sections/entries. |
| `BinaryTemplateSelectionColor` | `data` | n/a | Specify a custom color to use as the template selection color. |
| `HFDebugMenu` | `bool` | `false` | If `true`, will add a Debug menu to the menubar, with some additional preferences/commands. |
| `UseBlueAlternatingColor` | `bool` | `false` | If `true`, will use the classic blue alternating color. Otherwise, the application will use a system-defined color (that is dark mode aware.) |
