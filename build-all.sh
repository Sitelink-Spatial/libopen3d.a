#!/bin/bash

./clean.sh

./build.sh build release arm64-apple-ios14.0

#./build.sh build release arm64-apple-macosx

./build.sh build release x86_64-apple-ios14.0-simulator

