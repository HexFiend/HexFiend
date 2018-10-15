#!/usr/bin/env bash
# This script should be called from the root directory

set -e

# Configure our variables
URL="https://github.com/sparkle-project/Sparkle/releases/download/1.19.0/Sparkle-1.19.0.tar.bz2"
OUTPUT_DIR="vendor"
ARCHIVE="Sparkle.tar.bz2"
FRAMEWORK="Sparkle.framework"

# Make output directory
mkdir -p "$OUTPUT_DIR"

# Move to the output directory
cd "$OUTPUT_DIR"

# Do nothing if framework already exists
if [ -e "$FRAMEWORK" ]; then
	exit
fi

# Download Sparkle
nscurl -o "$ARCHIVE" "$URL"

# Extract Sparkle.framework
tar -xvf "$ARCHIVE" "$FRAMEWORK"
