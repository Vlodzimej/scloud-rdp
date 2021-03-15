# IOS Remote Desktop Clients

## bVNC

VNC client for iOS.

### Building Libraries
First, build dependent libraries, optionally providing the type of build as a parameter:

```bash
./build-libs.sh Debug

```

### Gotchas

If at build-time of any of the Targets you start getting missing _iconv related symbols,
edit the broken Target settings, and ensure
`$(PROJECT_DIR)/aspice-lib-ios/cerbero/build/dist/ios_universal/lib` is
**NOT** one of the `Build Settings->Library Search Paths`. It is automatically added
when libraries from the directory are added to dependencies and breaks the build
for reasons unknown.

### Developing

- Open `bVNC.xcodeproj` in Xcode.
- You will probably need to enter your Development team ID into the project.
- Get it from https://developer.apple.com/account/#/membership/
