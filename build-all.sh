#!/bin/bash

#--------------------------------------------------------------------
# Functions

Log()
{
    echo ">>>>>> $@"
}

exitWithError()
{
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "! $@"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit -1
}

exitOnError()
{
    if [[ 0 -eq $? ]]; then return 0; fi
    exitWithError $@
}

doBuild()
{
    echo "----------------------------------------"
    Log "Building $1"
    echo "----------------------------------------"
    ./build.sh build $CONFIG $1
    exitOnError "Failed to build $1"

    CFGBUILT="$CFGBUILT $1"
}

#--------------------------------------------------------------------
# Configuration

CFGBUILT=
CONFIG=$1
if [[ "release" != "$CONFIG" ]] && [[ "debug" != "$CONFIG" ]]; then
    exitWithError "Specify \"release\" or \"debug\""
fi

#--------------------------------------------------------------------
# Build

doBuild arm64-apple-ios12.0

# doBuild arm64-apple-macos12.0

doBuild arm64_x86_64-apple-ios12.0-simulator

echo "Build succeeded: $CFGBUILT"
