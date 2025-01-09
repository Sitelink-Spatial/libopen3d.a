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
        url: "https://github.com/Imajion/libopen3d.a/releases/download/r6/libopen3d.a.xcframework.zip",
        checksum: "7a107303e5e11e7ec9a1e5cd25f8abdcdf52b38c5226a66d0d85f3a587e6084a"
    )

```