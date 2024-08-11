#!/bin/bash

# AppImage Install
#
# A script that "installs" applications that are packaged as AppImages.
# Desktop entries and icons are created and provided to XDG menu.


# Installer data

INSTALLER_DIR="$(realpath $HOME/.local/share/appimage-installer)"
INSTALLER_BIN_DIR="${INSTALLER_DIR}/bin"
mkdir -p "$INSTALLER_DIR"  # TODO Check errors
mkdir -p "$INSTALLER_BIN_DIR"


# Utility functions

function get_desktop_entry() {
  grep "^$2=" "$1" | cut -d= -f2 | sed 's/^"//; s/"$//'  # Also removing surrounding double quotes
}

function get_file_extension() {
  sed 's/.*\.//' <<< "$1"
}

function remove_file_extension() {
  sed 's/\.[^.]*$//' <<< "$1"
}

function get_icon_size() {
  identify "$1" | cut -d' ' -f3 | cut -d'x' -f1
}

function log_error() {
  printf "\e[31m%s\e[39m\n" "$1"
}

function log_info() {
  printf "%s\n" "$1"
}

function log_success() {
  printf "\e[32m%s\e[39m\n" "$1"
}


# Main functions

function appimage_install() {
  APPIMAGE="$(realpath "$1")"
  APPIMAGE_DEST="$(realpath "$INSTALLER_BIN_DIR/$(basename "$APPIMAGE")")"
  chmod u+rx "$APPIMAGE"

  TMPDIR="$(mktemp -d)"
  trap "rm -r '$TMPDIR'" EXIT

  # Need to change to $TMPDIR because AppImage extracts into the current directory
  cd "$TMPDIR"

  if ! "$APPIMAGE" --appimage-extract 1>/dev/null 2>&1; then
    log_error "Failed to extract AppImage" >&2
    exit 1
  fi

  APPIMAGE_DIR="$TMPDIR/squashfs-root"

  DESKTOP_FILE="$(realpath $(ls "$APPIMAGE_DIR/"*.desktop))"
  APPNAME="$(get_desktop_entry "$DESKTOP_FILE" Name)"

  if [ $? -ne 0 ]; then
    log_error "Could not find .desktop file in AppImage"
    exit 2
  elif [ $(wc -l <<< "$DESKTOP_FILE") -gt 1 ]; then
    log_error "Found multiple .desktop files in AppImage (cannot choose)"
    exit 3
  fi

  ICON_NAME="$(get_desktop_entry "$DESKTOP_FILE" Icon)"
  ICON_FILE="$(realpath "$(find "$APPIMAGE_DIR" -name "$ICON_NAME.svg" -or -name "$ICON_NAME.png" -or -name "$ICON_NAME.ico" -or -name "$ICON_NAME.xpm" | head -n1)")"

  if [ ! -f "$ICON_FILE" ]; then
    log_error "Could not find icon in AppImage. Aborting..."
    exit 4
  fi

  # Ensure it is a PNG of correct size (resizing it to a standard size saves effort when uninstalling)
  NEW_ICON_FILE="$(remove_file_extension "$ICON_FILE").png"
  magick "$ICON_FILE" -resize 128x128 "$NEW_ICON_FILE"
  ICON_FILE="$NEW_ICON_FILE"

  ICON_SIZE="$(get_icon_size "$ICON_FILE")"

  sed -i 's:^Exec=.*:Exec="'"$APPIMAGE_DEST"'":' "$DESKTOP_FILE"

  xdg-desktop-menu install --mode user --novendor "$DESKTOP_FILE"
  xdg-icon-resource install --mode user --novendor --size "$ICON_SIZE" "$ICON_FILE"
  cp "$APPIMAGE" "$APPIMAGE_DEST"

  log_success "Installed $APPNAME ($(basename "$APPIMAGE"))"
}


function appimage_uninstall() {
  SEARCH_TERM="$1"

  for f in ~/.local/share/applications/*.desktop; do
    if [ "$(get_desktop_entry "$f" Name)" = "$SEARCH_TERM" -o "$(basename "$(get_desktop_entry "$f" Exec)")" = "$(basename "$SEARCH_TERM")" ]; then
      DESKTOP_FILE="$(realpath "$f")"
      APPNAME="$(get_desktop_entry "$DESKTOP_FILE" Name)"
      ICON_NAME="$(get_desktop_entry "$DESKTOP_FILE" Icon)"
      APPIMAGE="$(get_desktop_entry "$DESKTOP_FILE" Exec)"
      if [ "$(dirname "$APPIMAGE")" != "$INSTALLER_BIN_DIR" ]; then
        log_error "Application '$APPNAME' was not installed with this program" >&2
        exit 1
      fi
      xdg-desktop-menu uninstall --mode user "$DESKTOP_FILE"
      xdg-icon-resource uninstall --mode user --size 128 "$ICON_NAME"
      rm "$APPIMAGE"
      log_success "Uninstalled $APPNAME ($(basename "$APPIMAGE"))"
      return
    fi
  done

  log_error "Could not find application '$SEARCH_TERM'" >&2
}


# Help functions

function header() {
  cat <<EOF
AppImage Install - Command line tool for "installing" AppImages

This program adds the AppImage to the current user's application menu.
To do this, it makes a copy of the AppImage so you can move the original file
around without trouble. It then extracts the .desktop file and an icon from
the AppImage and registers them with XDG.

EOF
}


function usage() {
  cat <<EOF
Usage: $0 <--install|--uninstall|--help> [arg]

  --install     Install an AppImage application, where [arg] is the path
                to the AppImage.
  --uninstall   Uninstall an application previously installed with this script.
                [arg] is the name of the app (what is in the Name= field of
                the .desktop file) or the name of the AppImage file.
  -h|--help     Print this information.

EOF
}


# Argument parsing

case "$1" in
  --help|-h)
    header
    usage
    exit 0
    ;;
  --install)
    appimage_install "$2"
    exit 0
    ;;
  --uninstall)
    appimage_uninstall "$2"
    exit 0
    ;;
  *)
    log_error "Unknown option '$COMMAND'"
    usage
    exit 1
    ;;
esac

