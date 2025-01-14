little_endian

# Property names always consume 32 bytes
set nameLength 32

# Returns the property value at the current offset formatted as a string as best as possible
proc readValue { name length } {
    if { $length == 0 } {
        return "<null>"
    }

    set rawValue [bytes $length]
    move -$length

    # Before attempting to read a string, check if the value has more than a single null byte.
    # This takes care of values that are technically valid ASCII strings, but are actually numbers.
    # There's a simpler way of doing this nullCount check using regexp, but it broke VSCode syntax highlighting :/
    set stringWithoutNullBytes [string map {"\x00" ""} $rawValue]
    set nullCount [expr {[string length $rawValue] - [string length $stringWithoutNullBytes]}]
    if { $nullCount > 1 } {
        if { $length == 1 } {
            return [uint8]
        }

        if { $length == 2 } {
            return [uint16]
        }
        
        if { $length == 4 } {
            return [uint32]
        }
    
        if { $length == 8 } {
            return [uint64]
        }
    }

    # Special handling for the "compatible" property, which separates the three components using null bytes.
    # Replace null bytes by regular space so that the entire value is visible in the UI.
    if { $nullCount == 3 && $name == "compatible" } {
        move $length
        return [string map {"\x00" " "} $rawValue]
    }

    # Always format "AAPL,phandle" entries as hex
    if { $name == "AAPL,phandle" } {
        return [hex $length]
    }
    
    set stringValue [ascii $length]
    
    # If parsed ASCII results in an empty string, try to parse integer types instead.
    if { $stringValue == "" } {
        if { $length == 1 } {
            move -$length
            return [uint8]
        }

        if { $length == 2 } {
            move -$length
            return [uint16]
        }
        
        if { $length == 4 } {
            move -$length
            return [uint32]
        }
    
        if { $length == 8 } {
            move -$length
            return [uint64]
        }
    
        if { $nullCount == $length } {
            # In case empty ASCII can't be parsed as integer, describe the zeroed-out value size.
            return "<empty ($length bytes)>"
        } else {
            # If not fully empty, use hex instead
            move -$length
            return [hex $length]
        }
    }

    # After all other checks, return hex representation if string contains non-ASCII characters
    if {[regexp {[\x00-\x1F\x7F]} $stringValue]} {
        move -$length
        return [hex $length]
    }

    return $stringValue
}

# Reads a single property at the current offset
proc readProperty { } {
    global nameLength

    # Store current offset so that we can associate it with the UI entry for selection feedback
    set offset [pos]

    # Read property name
    set name [ascii $nameLength]
    
    # Read full header (length masked with flags)
    set header [uint32]
    
    # Remove flags from header to get the value length
    set length [expr $header & ~0x80000000]
    
    # Calculate 4-byte padding
    set remainder [expr {$length % 4}]
    set paddingBytes [expr {$remainder == 0 ? 0 : 4 - $remainder}]
    set paddedLength [expr $length + $paddingBytes]
    
    set value [readValue $name $length]
    
    # Generate UI entry with the name=value pair, associating it with the consumed length and start offset for selection feedback
    entry $name $value [expr $paddedLength + $nameLength + 4] $offset

    # If this is the "name" property, place the value on the section in the UI
    if { $name == "name" } {
        sectionvalue $value
    }

    # Advance pointer to account for padding
    move $paddingBytes
}

# Recursivelly reads a device tree node at the current offset, including its properties and children
proc readNode { } {
    global nameLength
    
    set propertyCount [uint32]
    set childCount [uint32]

    section "node ($propertyCount props, $childCount children)"
        for {set i $propertyCount} {$i > 0} {incr i -1} {
            readProperty
        }
        
        for {set i $childCount} {$i > 0} {incr i -1} {
            readNode
        }
    endsection
}

# Check if this is an Image4 wrapper, which is not supported
goto 6
set header [ascii 4]
if { $header == "IM4P" || $header == "IMG4" } {
    error "Image4 detected, please extract the device tree from the container and try again"
} else {
    goto 0
    
    # Kick off reading entire device tree
    readNode
}