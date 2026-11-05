#!/usr/bin/env bash
#
# mintalia installer — niri × noctalia dotfiles
#
# One-line:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/IgnazBhatta/mintalia/main/install.sh)"
#
# The script is intentionally boring: it installs Noctalia first, backs up
# everything it touches, then copies the themed configs into place.

set -Eeuo pipefail

REPO_URL="https://github.com/IgnazBhatta/mintalia"
REPO_BRANCH="main"
MINTALIA_DIR="${MINTALIA_DIR:-$HOME/.local/share/mintalia}"
BACKUP_ROOT="$HOME/.mintalia-backup"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

ASSUME_YES=0
DISCORD=""
SPOTIFY=""
WAYVIBES=""
BROWSER=""
INSTALL_SDDM=1
AUR_HELPER=""

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_MINT=$'\033[38;5;121m'
else
  C_RESET=""; C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_MINT=""
fi

say()  { printf '%s\n' "${C_MINT}::${C_RESET} $*"; }
ok()   { printf '%s\n' "${C_GREEN}✓${C_RESET} $*"; }
warn() { printf '%s\n' "${C_YELLOW}!${C_RESET} $*" >&2; }
die()  { printf '%s\n' "${C_RED}error:${C_RESET} $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
mintalia installer

Usage:
  install.sh [options]

Options:
  -y, --yes            accept defaults (no optional apps, skip browser)
      --discord        install Vesktop + Discord themes
      --no-discord     do not install Discord
      --spotify        install Spotify + Spicetify + Noctalia color sync
      --no-spotify     do not install Spotify
      --wayvibes       install Wayvibes + the NK Cream soundpack
      --no-wayvibes    do not install Wayvibes
      --browser=NAME   floorp | zen | none
      --no-sddm        leave the login manager alone
  -h, --help           show this help

Environment:
  MINTALIA_DIR         checkout location (default: ~/.local/share/mintalia)

Examples:
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/IgnazBhatta/mintalia/main/install.sh)"
  ./install.sh --browser=zen --discord
EOF
}

for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    --discord) DISCORD=1 ;;
    --no-discord) DISCORD=0 ;;
    --spotify) SPOTIFY=1 ;;
    --no-spotify) SPOTIFY=0 ;;
    --wayvibes) WAYVIBES=1 ;;
    --no-wayvibes) WAYVIBES=0 ;;
    --browser=floorp|--browser=zen|--browser=none) BROWSER="${arg#*=}" ;;
    --no-sddm) INSTALL_SDDM=0 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $arg (try --help)" ;;
  esac
done

# ---------------------------------------------------------------------------
# Bootstrap: when piped from curl there is no checkout next to the script.
# ---------------------------------------------------------------------------
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
SELF_DIR=""
if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
  SELF_DIR="$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd)"
fi

if [[ -z "$SELF_DIR" || ! -d "$SELF_DIR/config" ]]; then
  command -v git >/dev/null 2>&1 || die "git is required to bootstrap mintalia"
  say "Fetching mintalia into $MINTALIA_DIR"
  if [[ -d "$MINTALIA_DIR/.git" ]]; then
    git -C "$MINTALIA_DIR" pull --ff-only
  elif [[ -e "$MINTALIA_DIR" ]]; then
    die "$MINTALIA_DIR exists but is not a mintalia checkout"
  else
    mkdir -p "$(dirname "$MINTALIA_DIR")"
    git clone --depth=1 --branch "$REPO_BRANCH" "$REPO_URL" "$MINTALIA_DIR"
  fi
  exec bash "$MINTALIA_DIR/install.sh" "$@"
fi

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] && die "run this as your normal user, not root"
[[ -f /etc/arch-release ]] || die "mintalia targets Arch-based systems (Arch, CachyOS, EndeavourOS)"
command -v pacman >/dev/null 2>&1 || die "pacman not found"

if [[ $ASSUME_YES -eq 1 ]]; then
  [[ -z "$DISCORD" ]] && DISCORD=0
  [[ -z "$SPOTIFY" ]] && SPOTIFY=0
  [[ -z "$WAYVIBES" ]] && WAYVIBES=0
  [[ -z "$BROWSER" ]] && BROWSER=none
fi

if [[ -t 0 ]]; then
  PROMPT_TTY=/dev/stdin
elif [[ -r /dev/tty ]]; then
  PROMPT_TTY=/dev/tty
else
  PROMPT_TTY=""
fi

ask_yes_no() {
  local prompt="$1" default="${2:-n}" answer=""
  if [[ $ASSUME_YES -eq 1 ]]; then
    [[ "$default" == "y" ]]
    return
  fi
  if [[ -n "$PROMPT_TTY" ]]; then
    read -r -p "$prompt [y/N] " answer < "$PROMPT_TTY" || answer="$default"
  fi
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

ask_browser() {
  local answer=""
  if [[ $ASSUME_YES -eq 1 ]]; then BROWSER=none; return; fi
  printf '\n%s\n' "${C_BOLD}Browser${C_RESET}"
  printf '  1) Floorp  — my config + the animated Spirited Away theme\n'
  printf '  2) Zen      — follows Noctalia colors automatically\n'
  printf '  3) Skip\n'
  while true; do
    if [[ -n "$PROMPT_TTY" ]]; then
      read -r -p "Choose [3]: " answer < "$PROMPT_TTY" || answer=3
    fi
    case "${answer:-3}" in
      1) BROWSER=floorp; return ;;
      2) BROWSER=zen; return ;;
      3|"") BROWSER=none; return ;;
      *) warn "pick 1, 2, or 3" ;;
    esac
  done
}

if [[ -z "$DISCORD" ]]; then
  if ask_yes_no "Install Discord (Vesktop) and my Discord themes?" n; then DISCORD=1; else DISCORD=0; fi
fi
if [[ -z "$SPOTIFY" ]]; then
  if ask_yes_no "Install Spotify + Spicetify with Noctalia color sync?" n; then SPOTIFY=1; else SPOTIFY=0; fi
fi
if [[ -z "$WAYVIBES" ]]; then
  if ask_yes_no "Install Wayvibes and the NK Cream soundpack?" n; then WAYVIBES=1; else WAYVIBES=0; fi
fi
if [[ -z "$BROWSER" ]]; then ask_browser; fi

printf '\n%s\n' "${C_BOLD}mintalia${C_RESET}  niri × noctalia"
printf '  discord   : %s\n' "$([[ $DISCORD == 1 ]] && echo yes || echo no)"
printf '  spotify   : %s\n' "$([[ $SPOTIFY == 1 ]] && echo yes || echo no)"
printf '  wayvibes  : %s\n' "$([[ $WAYVIBES == 1 ]] && echo yes || echo no)"
printf '  browser   : %s\n' "$BROWSER"
printf '  sddm theme: %s\n\n' "$([[ $INSTALL_SDDM == 1 ]] && echo yes || echo no)"

say "Requesting sudo (needed for packages and the login theme)"
sudo -v || die "sudo is required"

# Keep sudo alive for the long package step.
( while true; do sudo -n true; sleep 50; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------
ensure_aur() {
  if [[ -n "$AUR_HELPER" ]]; then return; fi
  if command -v yay >/dev/null 2>&1; then AUR_HELPER=yay
  elif command -v paru >/dev/null 2>&1; then AUR_HELPER=paru
  else
    say "Installing yay-bin (AUR helper)"
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    ( cd "$tmp/yay-bin" && makepkg -si --noconfirm )
    rm -rf "$tmp"
    AUR_HELPER=yay
  fi
}

install_pkgs() {
  local pac=() aur=() p
  for p in "$@"; do
    if pacman -Si "$p" >/dev/null 2>&1; then
      pac+=("$p")
    else
      aur+=("$p")
    fi
  done
  if ((${#pac[@]})); then
    sudo pacman -S --needed --noconfirm "${pac[@]}"
  fi
  if ((${#aur[@]})); then
    ensure_aur
    "$AUR_HELPER" -S --needed --noconfirm "${aur[@]}"
  fi
}

say "Installing Noctalia first (the shell must exist before its config)"
install_pkgs niri quickshell noctalia
command -v noctalia >/dev/null 2>&1 || die "Noctalia installation failed"

CORE_PKGS=(
  kitty fish fastfetch nautilus vlc sddm
  adw-gtk-theme papirus-icon-theme capitaine-cursors
  cava btop ffmpeg pipewire pkgconf base-devel
  ttf-jetbrains-mono-nerd ttf-meslo-nerd
  dconf playerctl polkit xdg-desktop-portal-gtk
)
EXTRA_PKGS=()
[[ $DISCORD == 1 ]] && EXTRA_PKGS+=(vesktop-bin)
[[ $SPOTIFY == 1 ]] && EXTRA_PKGS+=(spotify spicetify-cli)
[[ $WAYVIBES == 1 ]] && EXTRA_PKGS+=(wayvibes-git)
case "$BROWSER" in
  floorp) EXTRA_PKGS+=(floorp-bin) ;;
  zen) EXTRA_PKGS+=(zen-browser-bin) ;;
esac

say "Installing the rest of the stack"
install_pkgs "${CORE_PKGS[@]}"
say "Installing Nirimod and Shelly (compulsory)"
install_pkgs nirimod-git shelly
if ((${#EXTRA_PKGS[@]})); then
  say "Installing optional apps: ${EXTRA_PKGS[*]}"
  install_pkgs "${EXTRA_PKGS[@]}"
fi

# ---------------------------------------------------------------------------
# Detect the primary output (used for wallpaper + sticker placement)
# ---------------------------------------------------------------------------
OUTPUT="eDP-1"
WIDTH=1920
HEIGHT=1080
if [[ -n "${NIRI_SOCKET:-}" ]] && command -v niri >/dev/null 2>&1; then
  DETECTED="$(niri msg --json outputs 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
for name, out in data.items():
    logical = out.get("logical") or {}
    if logical.get("width") and logical.get("height"):
        print(name, logical["width"], logical["height"])
        break
' 2>/dev/null || true)"
  if [[ -n "$DETECTED" ]]; then
    read -r OUTPUT WIDTH HEIGHT <<< "$DETECTED"
  fi
fi
[[ -n "${OUTPUT:-}" ]] || OUTPUT="eDP-1"
[[ -n "${WIDTH:-}" && "$WIDTH" -gt 0 ]] || WIDTH=1920
[[ -n "${HEIGHT:-}" && "$HEIGHT" -gt 0 ]] || HEIGHT=1080
say "Primary output: $OUTPUT (${WIDTH}x${HEIGHT})"

# ---------------------------------------------------------------------------
# Backup + install helpers
# ---------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
exec > >(tee -a "$BACKUP_DIR/install.log") 2>&1

backup() {
  local path="$1" rel dest
  [[ -e "$path" || -L "$path" ]] || return 0
  rel="${path#/}"
  dest="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -a "$path" "$dest" 2>/dev/null || warn "could not back up $path"
}

install_text() {
  local src="$1" dest="$2" kind="${3:-plain}"
  shift 3 || true
  backup "$dest"
  mkdir -p "$(dirname "$dest")"
  python3 "$SELF_DIR/scripts/render.py" "$kind" "$src" "$dest" --home "$HOME" "$@"
  chmod 0644 "$dest"
  ok "$dest"
}

install_copy() {
  local src="$1" dest="$2"
  backup "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  ok "$dest"
}

# ---------------------------------------------------------------------------
# niri
# ---------------------------------------------------------------------------
say "Installing niri config + keybinds"
mkdir -p "$HOME/.config/niri/cfg"
install_text "$SELF_DIR/config/niri/config.kdl" "$HOME/.config/niri/config.kdl"
install_text "$SELF_DIR/config/niri/noctalia.kdl" "$HOME/.config/niri/noctalia.kdl"
install_text "$SELF_DIR/config/niri/cfg/keybinds.kdl" "$HOME/.config/niri/cfg/keybinds.kdl" niri \
  --browser "$BROWSER" \
  $([[ $SPOTIFY == 1 ]] && echo --spotify) \
  $([[ -n "$(command -v code 2>/dev/null)" ]] && echo --vscode) \
  $([[ -n "$(command -v zeditor 2>/dev/null || command -v zed 2>/dev/null)" ]] && echo --zed)
for f in animation autostart display input layout misc rules; do
  install_text "$SELF_DIR/config/niri/cfg/$f.kdl" "$HOME/.config/niri/cfg/$f.kdl"
done

# ---------------------------------------------------------------------------
# Noctalia
# ---------------------------------------------------------------------------
say "Installing Noctalia config (bar, widgets, stickers, plugins)"
NOCT_ARGS=(
  --output "$OUTPUT" --width "$WIDTH" --height "$HEIGHT" --browser "$BROWSER"
)
[[ $DISCORD == 1 ]] && NOCT_ARGS+=(--discord)
[[ $SPOTIFY == 1 ]] && NOCT_ARGS+=(--spotify)
[[ $WAYVIBES == 1 ]] && NOCT_ARGS+=(--wayvibes)
[[ -n "$(command -v code 2>/dev/null)" ]] && NOCT_ARGS+=(--vscode)
[[ -n "$(command -v zeditor 2>/dev/null || command -v zed 2>/dev/null)" ]] && NOCT_ARGS+=(--zed)
install_text "$SELF_DIR/config/noctalia/config.toml" "$HOME/.config/noctalia/config.toml" noctalia "${NOCT_ARGS[@]}"
install_copy "$SELF_DIR/config/color-schemes/noctalia.colors" "$HOME/.local/share/color-schemes/noctalia.colors"

# ---------------------------------------------------------------------------
# Terminal, shell, fetch, GTK, app themes
# ---------------------------------------------------------------------------
say "Installing kitty, fish and fastfetch"
install_text "$SELF_DIR/config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
install_text "$SELF_DIR/config/kitty/themes/noctalia.conf" "$HOME/.config/kitty/themes/noctalia.conf"
install_copy "$SELF_DIR/config/kitty/search.py" "$HOME/.config/kitty/search.py"
install_copy "$SELF_DIR/config/kitty/scroll_mark.py" "$HOME/.config/kitty/scroll_mark.py"
install_text "$SELF_DIR/config/fish/config.fish" "$HOME/.config/fish/config.fish"
install_text "$SELF_DIR/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
install_copy "$SELF_DIR/config/fastfetch/hutao.png" "$HOME/.config/fastfetch/hutao.png"
install_copy "$SELF_DIR/config/fastfetch/hutao-ascii.txt" "$HOME/.config/fastfetch/hutao-ascii.txt"
install_copy "$SELF_DIR/config/fastfetch/kitty.jsonc" "$HOME/.config/fastfetch/kitty.jsonc"

say "Installing GTK / KDE / Nautilus colors"
install_text "$SELF_DIR/config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
install_text "$SELF_DIR/config/gtk-3.0/noctalia.css" "$HOME/.config/gtk-3.0/noctalia.css"
install_text "$SELF_DIR/config/gtk-3.0/noctalia-extensions.css" "$HOME/.config/gtk-3.0/noctalia-extensions.css"
install_text "$SELF_DIR/config/kdeglobals" "$HOME/.config/kdeglobals"
install_text "$SELF_DIR/config/btop/themes/noctalia.theme" "$HOME/.config/btop/themes/noctalia.theme"
install_text "$SELF_DIR/config/cava/config" "$HOME/.config/cava/config"
install_text "$SELF_DIR/config/cava/themes/noctalia" "$HOME/.config/cava/themes/noctalia"

if command -v dconf >/dev/null 2>&1 && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/gtk-theme "'adw-gtk3-dark'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/icon-theme "'Papirus-Dark'" 2>/dev/null || true
  dconf write /org/gnome/desktop/interface/cursor-theme "'capitaine-cursors'" 2>/dev/null || true
  dconf write /org/gnome/nautilus/preferences/default-folder-viewer "'icon-view'" 2>/dev/null || true
  ok "dconf: dark GTK, Papirus-Dark, capitaine cursors"
fi

if command -v fc-cache >/dev/null 2>&1; then fc-cache -f >/dev/null 2>&1 || true; fi

# ---------------------------------------------------------------------------
# Optional apps
# ---------------------------------------------------------------------------
if [[ $DISCORD == 1 ]]; then
  say "Installing Discord / Vesktop themes"
  install_copy "$SELF_DIR/config/vesktop/themes/noctalia.theme.css" "$HOME/.config/vesktop/themes/noctalia.theme.css"
  install_copy "$SELF_DIR/config/vesktop/themes/noctalia-material.theme.css" "$HOME/.config/vesktop/themes/noctalia-material.theme.css"
  install_copy "$SELF_DIR/config/vesktop/themes/discord-system24.css" "$HOME/.config/vesktop/themes/discord-system24.css"
  install_text "$SELF_DIR/config/vesktop/settings.json" "$HOME/.config/vesktop/settings.json"
  install_text "$SELF_DIR/config/vesktop/settings/settings.json" "$HOME/.config/vesktop/settings/settings.json"
fi

if [[ $SPOTIFY == 1 ]]; then
  say "Installing Spicetify (Marketplace + Noctalia color sync)"
  SPOTIFY_PATH="/opt/spotify"
  if [[ ! -d "$SPOTIFY_PATH" ]]; then
    SPOTIFY_BIN="$(command -v spotify 2>/dev/null || true)"
    [[ -n "$SPOTIFY_BIN" ]] && SPOTIFY_PATH="$(dirname "$(readlink -f "$SPOTIFY_BIN")")"
  fi
  install_text "$SELF_DIR/config/spicetify/config-xpui.ini" "$HOME/.config/spicetify/config-xpui.ini"
  sed -i "s|__SPOTIFY_PATH__|$SPOTIFY_PATH|g" "$HOME/.config/spicetify/config-xpui.ini"
  install_text "$SELF_DIR/config/spicetify/Themes/marketplace/color.ini" "$HOME/.config/spicetify/Themes/marketplace/color.ini"
  mkdir -p "$HOME/.config/spicetify/CustomApps/marketplace"
  backup "$HOME/.config/spicetify/CustomApps/marketplace"
  cp -a "$SELF_DIR/config/spicetify/CustomApps/marketplace/." "$HOME/.config/spicetify/CustomApps/marketplace/"
  ok "$HOME/.config/spicetify/CustomApps/marketplace"
  if [[ -f "$HOME/.config/spotify/prefs" ]] && ! pgrep -x spotify >/dev/null 2>&1; then
    if command -v spicetify >/dev/null 2>&1; then
      spicetify backup apply >/dev/null 2>&1 && ok "Spicetify patched Spotify" || warn "Spicetify could not patch Spotify yet"
    fi
  else
    warn "Launch Spotify once, then run: spicetify backup apply"
  fi
fi

if [[ $WAYVIBES == 1 ]]; then
  say "Installing Wayvibes soundpack"
  mkdir -p "$HOME/wayvibes/soundpacks"
  cp -an "$SELF_DIR/assets/sounds/nkcream" "$HOME/wayvibes/soundpacks/nkcream" 2>/dev/null || true
  mkdir -p "$HOME/.local/state/noctalia/plugins/data/viksit-garg/wayvibes"
  cat > "$HOME/.local/state/noctalia/plugins/data/viksit-garg/wayvibes/state.json" <<EOF
{
  "name": "NK Cream",
  "path": "$HOME/wayvibes/soundpacks/nkcream",
  "volume": 3
}
EOF
  ok "NK Cream installed"
fi

# ---------------------------------------------------------------------------
# Browser themes
# ---------------------------------------------------------------------------
if [[ "$BROWSER" == "floorp" ]]; then
  say "Installing Floorp userChrome and the Spirited Away theme"
  FLOORP_ROOT=""
  for dir in "$HOME/.floorp" "$HOME/.config/floorp"; do
    if [[ -d "$dir" ]]; then FLOORP_ROOT="$dir"; break; fi
  done
  FLOORP_PROFILE=""
  if [[ -n "$FLOORP_ROOT" ]]; then
    FLOORP_PROFILE="$(find "$FLOORP_ROOT" -maxdepth 2 -name prefs.js -printf '%h\n' 2>/dev/null | head -n1 || true)"
  fi
  if [[ -z "$FLOORP_PROFILE" ]]; then
    timeout 20 floorp -CreateProfile mintalia >/dev/null 2>&1 || true
    for dir in "$HOME/.floorp" "$HOME/.config/floorp"; do
      if [[ -d "$dir" ]]; then
        FLOORP_PROFILE="$(find "$dir" -maxdepth 2 -name prefs.js -printf '%h\n' 2>/dev/null | head -n1 || true)"
        [[ -n "$FLOORP_PROFILE" ]] && break
      fi
    done
  fi
  if [[ -n "$FLOORP_PROFILE" ]]; then
    mkdir -p "$FLOORP_PROFILE/chrome"
    install_copy "$SELF_DIR/config/floorp/userChrome.css" "$FLOORP_PROFILE/chrome/userChrome.css"
    install_copy "$SELF_DIR/config/floorp/userContent.css" "$FLOORP_PROFILE/chrome/userContent.css"
    AMO_API="https://addons.mozilla.org/api/v5/addons/addon/spirited-away-animated/"
    THEME_GUID="$(curl -fsSL "$AMO_API" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("guid",""))' 2>/dev/null || true)"
    if [[ -n "$THEME_GUID" ]]; then
      mkdir -p "$FLOORP_PROFILE/extensions"
      if curl -fL "https://addons.mozilla.org/firefox/downloads/latest/spirited-away-animated/latest.xpi" \
        -o "$FLOORP_PROFILE/extensions/$THEME_GUID.xpi" 2>/dev/null; then
        cat >> "$FLOORP_PROFILE/user.js" <<EOF

// mintalia: Spirited Away (Animated) theme
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 15);
user_pref("extensions.activeThemeID", "$THEME_GUID");
EOF
        ok "Spirited Away theme queued for Floorp"
      else
        warn "Could not download the theme; install it from addons.mozilla.org/firefox/addon/spirited-away-animated/"
      fi
    else
      warn "Could not resolve the theme ID; install it from the Firefox theme store"
    fi
  else
    warn "Floorp profile not found. Open Floorp once, then rerun: ./install.sh --browser=floorp"
  fi
fi

if [[ "$BROWSER" == "zen" ]]; then
  say "Zen will be recolored by Noctalia's zen-browser template"
  warn "Open Zen once after logging in, then change the Noctalia wallpaper/theme to apply the colors"
fi

# ---------------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------------
say "Installing wallpapers, stickers and avatar"
mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Stickers"
cp -an "$SELF_DIR/assets/wallpapers/." "$HOME/Pictures/Wallpapers/"
cp -an "$SELF_DIR/assets/stickers/." "$HOME/Pictures/Stickers/"
[[ -e "$HOME/Pictures/Hutao.jpeg" ]] || cp -a "$SELF_DIR/assets/avatar.jpg" "$HOME/Pictures/Hutao.jpeg"
WALLPAPER="$HOME/Pictures/Wallpapers/wallhaven-k8j6k6_3840x1600.png"
[[ -f "$WALLPAPER" ]] || WALLPAPER="$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f | head -n1)"
ok "assets installed"

# ---------------------------------------------------------------------------
# SDDM
# ---------------------------------------------------------------------------
if [[ $INSTALL_SDDM == 1 ]]; then
  say "Installing the SDDM theme (mintalia)"
  SDDM_THEME=/usr/share/sddm/themes/mintalia
  backup "$SDDM_THEME"
  sudo mkdir -p "$SDDM_THEME"
  for f in Main.qml SessionsChoose.qml UsersChoose.qml metadata.desktop screenshot.png; do
    sudo cp -a "$SELF_DIR/config/sddm/$f" "$SDDM_THEME/$f"
  done
  TMP_CONF="$(mktemp)"
  python3 "$SELF_DIR/scripts/render.py" plain "$SELF_DIR/config/sddm/theme.conf" "$TMP_CONF" --home "$HOME"
  sudo install -Dm644 "$TMP_CONF" "$SDDM_THEME/theme.conf"
  rm -f "$TMP_CONF"
  backup /etc/sddm.conf.d/99-mintalia.conf
  printf '[Theme]\nCurrent=mintalia\n' | sudo tee /etc/sddm.conf.d/99-mintalia.conf >/dev/null
  if ! systemctl is-enabled sddm.service >/dev/null 2>&1; then
    sudo systemctl enable sddm.service >/dev/null 2>&1 || true
  fi
  ok "SDDM theme installed (applies after logout/reboot)"
fi

# ---------------------------------------------------------------------------
# Apply Noctalia
# ---------------------------------------------------------------------------
say "Applying Noctalia wallpaper and enabling plugins"
PLUGINS=(
  miixz/audio-sticker levi/warp noctalia/bongocat kenn/keybind-cheatsheet
  noctalia/wallhaven dotnetrob/cat oldirtty/color_picker
)
[[ $WAYVIBES == 1 ]] && PLUGINS+=(viksit-garg/wayvibes)

# Persist the wallpaper even if this runs from a TTY.
backup "$HOME/.local/state/noctalia/settings.toml"
python3 "$SELF_DIR/scripts/set-wallpaper.py" "$HOME/.local/state/noctalia/settings.toml" \
  --wallpaper "$WALLPAPER" --output "$OUTPUT"

if [[ -n "${NIRI_SOCKET:-}" ]] && command -v noctalia >/dev/null 2>&1; then
  if ! pgrep -x noctalia >/dev/null 2>&1; then
    ( setsid noctalia >/dev/null 2>&1 & ) || true
  fi
  # Wait until the freshly started shell answers IPC (max ~10 s).
  nmsg() {
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      noctalia msg "$@" >/dev/null 2>&1 && return 0
      sleep 1
    done
    return 1
  }
  nmsg config-reload || true
  nmsg wallpaper-set "$WALLPAPER" || true
  nmsg color-scheme-set wallpaper m3-content || true
  nmsg plugins update official || true
  nmsg plugins update community || true
  for p in "${PLUGINS[@]}"; do
    nmsg plugins enable "$p" || true
  done
  # Re-render GTK/kitty/btop/Spotify/Discord templates from the wallpaper palette.
  nmsg templates-apply || true
  niri msg action load-config-file >/dev/null 2>&1 || true
  ok "Noctalia reloaded; plugins are being fetched"
else
  warn "No niri session detected — wallpaper and plugins will apply on next login"
fi

if command -v noctalia >/dev/null 2>&1; then
  if noctalia config validate >/dev/null 2>&1; then
    ok "Noctalia config validates"
  else
    warn "Noctalia config validation reported an issue; run: noctalia config validate"
  fi
fi

# ---------------------------------------------------------------------------
# Final touches
# ---------------------------------------------------------------------------
if [[ "${SHELL:-}" != *fish && -x /usr/bin/fish ]]; then
  if ask_yes_no "Make fish your default shell?" n; then
    chsh -s /usr/bin/fish || warn "chsh failed; run it manually"
  fi
fi

mkdir -p "$HOME/.config/mintalia"
if git -C "$SELF_DIR" rev-parse --short HEAD >/dev/null 2>&1; then
  git -C "$SELF_DIR" rev-parse --short HEAD > "$HOME/.config/mintalia/commit"
fi

printf '\n%s\n' "${C_GREEN}${C_BOLD}mintalia is installed.${C_RESET}"
cat <<EOF

  backup      : $BACKUP_DIR
  config      : ~/.config/niri, ~/.config/noctalia, ~/.config/kitty
  wallpapers  : ~/Pictures/Wallpapers
  screenshots demo: https://github.com/IgnazBhatta/mintalia

Next steps
  1. Log out and back in (or reboot) so SDDM and the full shell reload.
  2. Open kitty and run: greet
  3. Super+Shift+W opens the wallpaper picker.
  4. Super+Shift+S opens the control center.

EOF
if [[ "$BROWSER" == "zen" ]]; then
  printf '  Zen: open it once, then Noctalia applies the theme on the next color change.\n'
fi
if [[ $SPOTIFY == 1 ]]; then
  printf '  Spotify: if it is unthemed, run "spicetify backup apply" once.\n'
  printf '  Spotify colors: Noctalia → Settings → Templates → apply "spicetify-noctalia".\n'
fi
if [[ "$BROWSER" == "floorp" ]]; then
  printf '  Floorp: restart it to load Spirited Away.\n'
fi
printf '\n'
