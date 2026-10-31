#!/bin/bash
# Build the WalkingPad Lite data field for vivoactive4s.
set -e
cd "$(dirname "$0")"
export PATH=/usr/lib/jvm/java-19-openjdk-amd64/bin:$PATH
../sdk/bin/monkeyc -d vivoactive4s -f monkey.jungle -o bin/walkingpad.prg -y developer_key.der -O3z --warn
