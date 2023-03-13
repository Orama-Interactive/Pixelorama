# Building Ubuntu Touch click packages

# Ubuntu Touch Click Packages

The following subdirectory contains the necessary development files to create a click package of the app for [Ubuntu Touch](https://ubuntu-touch.io). Special thanks to @abmyii and the UBPorts team for making this possible.

## Build instructions

1. Start by exporting the pack file with the preset "Clickable (package only)".
2. Copy the resulting .pck file from the `dist/linux` directory (or wherever you specified the Linux export) into the `Misc/Clickable` directory and rename it to `Pixelorama.pck`.
3. Copy the `pixelorama_data` directory from the root into `Misc/Clickable`. 
4. In the terminal, run the following:

```
$ cd Misc/Clickable
$ clickable build
```

The resulting click file should be present in the `build` directory inside of `Misc/Clickable`, which can be installed on an Ubuntu Touch device by copying the file over.

### Multiple architectures

Note: To build for different architectures, pass in the `CLICKABLE_ARCH `environment variable.

For example, to build for armhf and arm64:
```
$ CLICKABLE_ARCH=armhf clickable build
$ CLICKABLE_ARCH=arm64 clickable build
```
> Note: It is recommended that you provide packages for at least the `armhf` and `arm64` architectures.

### Important gotcha: File loading and saving

Due to AppArmor policy restrictions, you are not able to save to anywhere outside of the user data directory.
