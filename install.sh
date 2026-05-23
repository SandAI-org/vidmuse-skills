#!/usr/bin/env bash
set -euo pipefail

OSS_BASE_URL="${VIDMUSE_CLI_OSS_BASE_URL:-https://vidmuse.sandcdn.com/cli}"
OSS_BASE_URL="${OSS_BASE_URL%/}"
VERSION_REQUEST="${VIDMUSE_CLI_VERSION:-latest}"
SKIP_CHECKSUM="${VIDMUSE_CLI_SKIP_CHECKSUM:-0}"

log() {
  printf '%s\n' "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

validate_base_url() {
  case "$OSS_BASE_URL" in
    https://*) return ;;
    *) die "VIDMUSE_CLI_OSS_BASE_URL must use https" ;;
  esac
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

path_contains_dir() {
  local dir="$1"
  case ":${PATH:-}:" in
    *":${dir}:"*) return 0 ;;
    *) return 1 ;;
  esac
}

first_writable_path_dir() {
  local path_dir=""
  local existing=""

  existing="$(command -v vidmuse 2>/dev/null || true)"
  if [ -n "$existing" ] && [ -w "$(dirname "$existing")" ]; then
    dirname "$existing"
    return 0
  fi

  IFS=':' read -r -a path_dirs <<< "${PATH:-}"
  for path_dir in "${path_dirs[@]}"; do
    if [ -n "$path_dir" ] && [ "${path_dir#/}" != "$path_dir" ] && [ -d "$path_dir" ] && [ -w "$path_dir" ]; then
      printf '%s\n' "$path_dir"
      return 0
    fi
  done

  return 1
}

default_install_dir() {
  local path_dir=""

  if [ -n "${VIDMUSE_CLI_INSTALL_DIR:-}" ]; then
    printf '%s\n' "$VIDMUSE_CLI_INSTALL_DIR"
    return
  fi

  if path_dir="$(first_writable_path_dir)"; then
    printf '%s\n' "$path_dir"
    return
  fi

  printf '%s\n' "$HOME/.local/bin"
}

download() {
  local url="$1"
  local dest="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 --retry-delay 1 -o "$dest" "$url"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -O "$dest" "$url"
    return
  fi

  die "missing curl or wget for downloading $url"
}

detect_os() {
  case "$(uname -s)" in
    Darwin) printf 'darwin\n' ;;
    Linux) printf 'linux\n' ;;
    MINGW*|MSYS*|CYGWIN*) printf 'windows\n' ;;
    *) die "unsupported OS: $(uname -s)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'amd64\n' ;;
    arm64|aarch64) printf 'arm64\n' ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
}

extract_json_string() {
  local key="$1"
  sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

resolve_latest_version() {
  local manifest_file=""
  local version=""

  manifest_file="$(mktemp)"
  if download "${OSS_BASE_URL}/latest.json" "$manifest_file"; then
    version="$(extract_json_string version < "$manifest_file")"
    if [ -n "$version" ]; then
      printf '%s\n' "$version"
      return 0
    fi
  fi

  return 1
}

sha256_file() {
  local file="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi

  die "missing sha256sum or shasum for checksum verification"
}

verify_checksum() {
  local file="$1"
  local asset_name="$2"
  local checksums_file="$3"
  local expected=""
  local actual=""

  if [ "$SKIP_CHECKSUM" = "1" ]; then
    log "checksum verification skipped by VIDMUSE_CLI_SKIP_CHECKSUM=1"
    return 0
  fi

  expected="$(awk -v name="$asset_name" '$2 == name {print $1}' "$checksums_file" | head -n 1)"
  if [ -z "$expected" ]; then
    die "checksum for $asset_name was not found"
  fi

  actual="$(sha256_file "$file")"
  if [ "$actual" != "$expected" ]; then
    die "checksum mismatch for $asset_name"
  fi
}

asset_name_for() {
  local os_name="$1"
  local arch_name="$2"
  local base="vidmuse-${os_name}-${arch_name}"

  case "$os_name" in
    darwin) printf '%s.zip\n' "$base" ;;
    windows) printf '%s.exe\n' "$base" ;;
    *) printf '%s\n' "$base" ;;
  esac
}

binary_name_for() {
  local os_name="$1"
  local arch_name="$2"

  if [ "$os_name" = "windows" ]; then
    printf 'vidmuse-%s-%s.exe\n' "$os_name" "$arch_name"
    return
  fi

  printf 'vidmuse-%s-%s\n' "$os_name" "$arch_name"
}

resolve_install_target() {
  local target="$1"
  local link_target=""

  if [ -L "$target" ]; then
    link_target="$(readlink "$target")" || die "could not resolve symlink target: $target"
    case "$link_target" in
      /*) printf '%s\n' "$link_target" ;;
      *) printf '%s\n' "$(dirname "$target")/${link_target}" ;;
    esac
    return
  fi

  printf '%s\n' "$target"
}

hard_link_count() {
  local target="$1"

  if [ ! -e "$target" ]; then
    printf '1\n'
    return
  fi

  stat -c '%h' "$target" 2>/dev/null ||
    stat -f '%l' "$target" 2>/dev/null ||
    printf '1\n'
}

install_asset() {
  local asset_file="$1"
  local asset_name="$2"
  local binary_name="$3"
  local target="$4"
  local extract_dir=""
  local source_file="$asset_file"
  local target_path=""
  local temp_target=""
  local link_count="1"

  case "$asset_name" in
    *.zip)
      need_cmd unzip
      extract_dir="$(mktemp -d)"
      unzip -q "$asset_file" -d "$extract_dir"
      source_file="$(find "$extract_dir" -type f -name "$binary_name" -print -quit)"
      [ -n "$source_file" ] || die "archive did not contain $binary_name"
      ;;
  esac

  target_path="$(resolve_install_target "$target")"
  mkdir -p "$(dirname "$target_path")"

  if [ "${VIDMUSE_CLI_SELF_UPDATE:-0}" != "1" ]; then
    cp "$source_file" "$target_path" || die "could not copy binary to target"
    chmod 0755 "$target_path" || die "could not mark binary executable"
    return
  fi

  link_count="$(hard_link_count "$target_path")"
  case "$link_count" in
    ''|*[!0-9]*) link_count="1" ;;
  esac

  if [ "$link_count" -gt 1 ]; then
    die "target binary has ${link_count} hard links; run the installer manually after vidmuse exits"
  fi

  temp_target="$(mktemp "${target_path}.tmp.XXXXXX")"
  cp "$source_file" "$temp_target" || { rm -f "$temp_target"; die "could not copy binary to temporary target"; }
  chmod 0755 "$temp_target" || { rm -f "$temp_target"; die "could not mark binary executable"; }
  mv -f "$temp_target" "$target_path" || { rm -f "$temp_target"; die "could not replace target binary"; }
}

os_name="$(detect_os)"
arch_name="$(detect_arch)"
validate_base_url

asset_name="$(asset_name_for "$os_name" "$arch_name")"
binary_name="$(binary_name_for "$os_name" "$arch_name")"
INSTALL_DIR="$(default_install_dir)"
target_name="vidmuse"

if [ "$os_name" = "windows" ]; then
  target_name="vidmuse.exe"
fi

if [ "$VERSION_REQUEST" = "latest" ]; then
  version="$(resolve_latest_version)" || die "could not resolve latest VidMuse CLI version"
else
  version="$VERSION_REQUEST"
fi

release_base="${OSS_BASE_URL}/releases/${version}"
asset_file="$(mktemp)"
checksums_file="$(mktemp)"
target="${INSTALL_DIR}/${target_name}"

log "installing VidMuse CLI ${version} for ${os_name}/${arch_name}"

download "${release_base}/${asset_name}" "$asset_file" || die "could not download ${asset_name} from release CDN"

download "${release_base}/checksums.txt" "$checksums_file" || die "could not download checksums.txt from release CDN"

verify_checksum "$asset_file" "$asset_name" "$checksums_file"
install_asset "$asset_file" "$asset_name" "$binary_name" "$target"

log "installed VidMuse CLI to $target"
if ! path_contains_dir "$(dirname "$target")"; then
  log "warning: $(dirname "$target") is not on PATH; add it to PATH to run vidmuse directly"
fi
"$target" --version >&2 || true
printf '%s\n' "$target"
