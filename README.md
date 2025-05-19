# IOS Remote Desktop Clients

## Intro

sCloudRDP is a VNC client for iOS and Mac OS X. aSPICE is a SPICE Client for iOS and Mac OS X.

## Links to Apple App Store

sCloudRDP Pro is available at [sCloudRDP Pro](https://apps.apple.com/app/sCloudRDP-pro/id1506461202).

aSPICE Pro is available at [aSPICE Pro](https://apps.apple.com/app/aspice-pro/id1560593107).

aRDP is available at [aRDP Pro](https://apps.apple.com/app/ardp-pro/id1620745523)

## Building

The libraries that come bundled with this projects have been verified to build up to Big Sur with XCode 13.4.1.

Your contributions with fixes for later MacOS versions and XCode are welcome.

### Building Libraries
First, build dependent libraries, optionally providing the type of build as a parameter:

```bash
./build-libs.sh Debug
```

### Gotchas

- If at build-time of any of the Targets you start getting missing _iconv related symbols,
edit the broken Target settings, and ensure
`$(PROJECT_DIR)/aspice-lib-ios/cerbero/build/dist/ios_universal/lib` is
**NOT** one of the `Build Settings->Library Search Paths`. It is automatically added
when libraries from the directory are added to dependencies and breaks the build
for reasons unknown.

- If during build of aSPICE dependencies with cerbero you get an error like `build-tools/bin/meson:
No such file or directory`, it seems to be because meson is installed in /usr/local/bin instead
of where cerbero expects it. You can workaround with a command like (replace /PATH/TO):
```
ln -s /usr/local/bin/meson 
/PATH/TO/remote-desktop-clients-ios/aspice-lib-ios/cerbero/build/build-tools/bin/
```
Retry the cerbero build from the failed step (option 2).

- The first time FreeRDP build runs, it will stop and you have to set a development team. Follow
the script instructions in the terminal.


### Developing

- Open `sCloudRDP.xcodeproj` in Xcode.
- You will probably need to enter your Development team ID into the project.
- Get it from https://developer.apple.com/account/#/membership/
