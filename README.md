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
        url: "https://github.com/Imajion/libopen3d.a/releases/download/r7/libopen3d.a.xcframework.zip",
        checksum: "9382565ba33adc6f6134d26447692e37cf9d860e175677b1ebd88e6123e85b2e"
    )

```
