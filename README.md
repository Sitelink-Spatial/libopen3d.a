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
        url: "https://github.com/Imajion/libopen3d.a/releases/download/r1/libopen3d.a.xcframework.zip",
        checksum: "f0375b4459b879c7fcc30c8598436b92550be7b72620cf09d6e1e15267fd7dfb"
    )

```