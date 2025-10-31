# Wherigo Cartridge
# .types = ( gwc );
#
# Specifications:
#   https://github.com/WFoundation/WF.Compiler
#   https://github.com/driquet/gwcd/blob/master/gwc_spec.md
#
# Copyright (c) 2025 Markus Birth
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

requires 0 "02 0a 43 41 52 54 00"

little_endian

hex 2 "Signature"
ascii 5 "Identifier"

set count [uint16 "Obj Count"]

set objAddrs [list]
section -collapsed "Obj References" {
    for { set i 1 } { $i <= $count } { incr i } {
        set objId [uint16 "Obj #$i ID"]
        set objAddr [uint32 -hex "Obj #$i Addr"]
        lappend objAddrs $objId
        lappend objAddrs $objAddr
    }
}

section "Header" {
    int32 "Length"

    double "Latitude"
    double "Longitude"
    double "Altitude"
    
    # Seconds since 2004-02-10 01:00:00
    set cTime [int64]
    incr cTime 1076378400
    entry "Creation Time" [clock format $cTime]
    
    int16 "Splash/Poster ID"
    int16 "Icon ID"
    
    cstr "utf8" "Cart Type"
    cstr "utf8" "Player Name"
    int64 "Groundspeak Player ID"
    
    cstr "utf8" "Cart Name"
    cstr "utf8" "Cart GUID"
    cstr "utf8" "Cart Description"
    cstr "utf8" "Start Loc Desc"
    cstr "utf8" "Version"
    cstr "utf8" "Author"
    cstr "utf8" "Company"
    cstr "utf8" "Recommended Device"
    
    int32 "Completion Code Len"
    cstr "utf8" "Completion Code"
}

foreach {objId objAddr} $objAddrs {
    section -collapsed "Obj $objId" {
        goto $objAddr
        if {$objId == 0} {
            # Obj 0 is always Lua
            set strLen [uint32 "Length"]
            sectionvalue "Lua / $strLen Bytes"
            hex $strLen "Lua Bytecode"
        } else {
            set valid [int8 "Is Valid?"]
            
            if {$valid == 0} {
                sectionvalue "DELETED"
            } else {
                set type [int32 "Typecode"]
                set len [uint32 "Length"]
                
                switch $type {
                    -1 { sectionvalue "DELETED / $len Bytes" }
                     1 { sectionvalue "BMP / $len Bytes" }
                     2 { sectionvalue "PNG / $len Bytes" }
                     3 { sectionvalue "JPG / $len Bytes" }
                     4 { sectionvalue "GIF / $len Bytes" }
                    17 { sectionvalue "WAV / $len Bytes" }
                    18 { sectionvalue "MP3 / $len Bytes" }
                    19 { sectionvalue "FDL / $len Bytes" }
                    20 { sectionvalue "SND / $len Bytes" }
                    21 { sectionvalue "OGG / $len Bytes" }
                    33 { sectionvalue "SWF / $len Bytes" }
                    49 { sectionvalue "TXT / $len Bytes" }
                    default { sectionvalue "??? / $len Bytes" }
                }
                
                bytes $len "Payload"
            }
        }
    }
}
