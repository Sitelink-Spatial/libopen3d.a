# libopen3d.a

## Dependencies

    * xcode
    * brew install git openssl


## Build

    ./build.sh build release arm64-apple-ios14.0


## Reference in Swift Module

``` swift

    .binaryTarget(
        name: "libopen3d.a",
        url: "https://github.com/Imajion/libopen3d.a/releases/download/r8/libopen3d.a.xcframework.zip",
        checksum: "1647cf65763a5b2beb0c3e7cf6a2e2ed95fbfe013cab0d2be56a62a3c0535dc3"
    )

```
