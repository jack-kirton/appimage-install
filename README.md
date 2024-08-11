# AppImage Install

A quick and dirty script to "install" AppImages (that is, add them to the user's XDG applications menu).

To install an AppImage, do:

```bash
appimage-install.sh --install foo.AppImage
```

To uninstall:

```bash
appimage-install.sh --uninstall foo.AppImage  # Use the original AppImage name
# Or
appimage-install.sh --uninstall Foo  # Use the application name (specified in the .desktop file)
```

If you are installing a new version of an AppImage, you should probably uninstall the old one first.
