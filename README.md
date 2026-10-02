IF you a Devloper contribute in this project

## RootHide build

Use the official [RootHide Theos fork](https://github.com/roothide/theos), then run:

```sh
make release-package-roothide
```

The package is emitted under `packages/` with Debian architecture
`iphoneos-arm64e` and an iOS 15.0 deployment target. GitHub Actions also builds
and uploads a separate `tlinkios-roothide-build` artifact.
