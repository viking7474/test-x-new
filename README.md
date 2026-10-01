IF you a Devloper contribute in this tweak project

IF user then try it and suggest improvements on https://t.me/projectweaponx


tweak dummy id pass ->
ac1@gmail.com
asdf@123

## RootHide build

Use the official [RootHide Theos fork](https://github.com/roothide/theos), then run:

```sh
make release-package-roothide
```

The package is emitted under `packages/` with Debian architecture
`iphoneos-arm64e` and an iOS 15.0 deployment target. GitHub Actions also builds
and uploads a separate `tlinkios-roothide-build` artifact.
