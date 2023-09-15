#!/bin/bash

CONFIG=$1
if [[ "release" != "$CONFIG" ]] && [[ "debug" != "$CONFIG" ]]; then
    echo "Specify \"release\" or \"debug\""
    exit -1
fi

./build.sh build $CONFIG arm64-apple-ios12.0

./build.sh build $CONFIG arm64-apple-macos12.0

./build.sh build $CONFIG x86_64-apple-ios12.0-simulator

