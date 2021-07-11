# Binary Templates Tutorial

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

Congrats, you've written the most basic and simplest template that actually does something! Visit the [reference](Reference.md) for details on other commands available.

## Development and debug tips

### How to see debug logs

Run application directly in a terminal:
```sh
$ /Applications/Hex\ Fiend.app/Contents/MacOS/Hex\ Fiend
```
Now in a template do `puts test` and you will see `test` on the terminal.

### Keep partial template tree on error

Wrap parse code in a `catch` and print error on crash. This will hide the error from Hex Fiend and show the partial tree.

```tcl
if [catch {
    # call parse code
}] {
    puts $errorInfo
}
```

### Automatically reload template on save

You can use `osascript` to make Hex Fiend reload a template and then use a file change notification tool to trigger.

Here is an example using [modd](https://github.com/cortesi/modd) configuration to reload the template "WAV" when `WAV.tcl` changes:

```
WAV.tcl {
    prep: osascript \
        -e 'tell application "System Events"' \
	    -e '    tell process "Hex Fiend"' \
	    -e '        click pop up button 1 of window 1' \
	    -e '        click menu item "WAV" of menu 1 of pop up button 1 of window 1' \
	    -e '    end tell' \
        -e 'end tell'
}
```

It shouldn't be much trouble doing the same with `watchexec` or other tools.
