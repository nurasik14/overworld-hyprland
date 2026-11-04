#!/usr/bin/env bash
# fetch-minecraft-assets.sh — (re)create assets/mc/ (Mojang art, sounds, models, font; © Mojang, NEVER committed).
#
#   scripts/fetch-minecraft-assets.sh [--build] [--sounds-only] [--force] [--download] [--version V]
#
#   assets/mc/{textures,models,blockstates,font,texts,lang/en_us.json}   from the client jar
#   assets/mc/sounds/**.ogg + assets/mc/sounds.json                       from the asset index objects
#   assets/mc/VERSION                                                     the game version the files came from
#
# Source (first that works):
#   1. a local launcher install — newest ~/.minecraft/versions/*/<id>.jar whose version.json id is a release, with
#      ~/.minecraft/assets/{indexes,objects}  (read-only; skipped with --download)
#   2. Mojang's servers — piston-meta.mojang.com (manifest, version json, asset index) and
#      resources.download.minecraft.net (sound objects), every file sha1-verified; client jar from the version json's url.
#
#   --version V    use release V (default: the newest locally installed, else Mojang's latest release)
#   --sounds-only  only sounds + sounds.json
#   --force        rebuild even when OUT/VERSION already matches (default: idempotent no-op)
#   --download     ignore ~/.minecraft, always fetch from Mojang
#   --build        afterwards run the derived-asset builds: font (assets/fonts, installed to ~/.local/share/fonts/overworld)
#                  and icons (assets/icons/mc); needs `uv` (tools/assetforge)
# Env: OUT=<dir>  target (default <repo>/assets/mc; with a custom OUT the --build products go to $OUT.build, not the repo)
#      MINECRAFT_DIR=<dir>  local launcher dir (default ~/.minecraft)     JOBS=<n>  parallel copies/downloads (default 6)
set -euo pipefail

REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd -P)"
OUT="${OUT:-$REPO/assets/mc}"
MCDIR="${MINECRAFT_DIR:-$HOME/.minecraft}"
JOBS="${JOBS:-6}"
MANIFEST="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
OBJECTS="https://resources.download.minecraft.net"

BUILD=0 SOUNDS_ONLY=0 FORCE=0 DOWNLOAD=0 WANT=""
while (($#)); do
    case "$1" in
        --build) BUILD=1 ;;
        --sounds-only) SOUNDS_ONLY=1 ;;
        --force) FORCE=1 ;;
        --download) DOWNLOAD=1 ;;
        --version) WANT="${2:?--version needs a value}"; shift ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "fetch-minecraft-assets: unknown option $1" >&2; exit 2 ;;
    esac
    shift
done
for c in jq unzip sha1sum xargs; do command -v "$c" >/dev/null || { echo "fetch-minecraft-assets: $c is required" >&2; exit 1; }; done

log() { echo "fetch-minecraft-assets: $*" >&2; }
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ow-fetch.XXXXXX")"
trap 'rm -rf "${tmp:?}"' EXIT

# ---------------------------------------------------------------------------------------------- pick the source
src_jar="" src_index="" src_objects="" version=""
if ((!DOWNLOAD)) && [[ -d "$MCDIR/versions" && -d "$MCDIR/assets/objects" ]]; then
    best=""
    while IFS= read -r -d '' j; do
        id="$(unzip -p "$j" version.json 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)"
        [[ "$id" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || continue         # releases only (no snapshots / loader ids)
        [[ -n "$WANT" && "$id" != "$WANT" ]] && continue
        [[ -n "$(unzip -Z1 "$j" 'assets/minecraft/textures/gui/*' 2>/dev/null | head -n 1)" ]] || continue   # a real client jar
        best+="$id"$'\t'"$j"$'\n'
    done < <(find "$MCDIR/versions" -name '*.jar' -print0 2>/dev/null)
    if [[ -n "$best" ]]; then
        line="$(printf '%s' "$best" | sort -t$'\t' -k1,1V | tail -1)"
        version="${line%%$'\t'*}"; src_jar="${line#*$'\t'}"
        # the asset index id lives in the launcher's version json next to the jar
        vj="${src_jar%.jar}.json"
        aid="$(jq -r '.assetIndex.id // .assets // empty' "$vj" 2>/dev/null || true)"
        if [[ -n "$aid" && -f "$MCDIR/assets/indexes/$aid.json" ]]; then
            src_index="$MCDIR/assets/indexes/$aid.json"; src_objects="$MCDIR/assets/objects"
        else
            log "local jar $src_jar has no matching asset index — taking the sounds from Mojang"
        fi
    fi
fi

if [[ -n "$src_jar" && -n "$src_index" ]]; then
    log "source: local $src_jar (Minecraft $version), index $(basename "$src_index")"
else
    command -v curl >/dev/null || { echo "fetch-minecraft-assets: curl is required to download" >&2; exit 1; }
    curl -fsS -m 60 "$MANIFEST" -o "$tmp/manifest.json"
    if [[ -n "$WANT" ]]; then version="$WANT"; elif [[ -z "$version" ]]; then version="$(jq -r '.latest.release' "$tmp/manifest.json")"; fi
    vurl="$(jq -r --arg v "$version" '.versions[] | select(.id == $v) | .url' "$tmp/manifest.json")"
    [[ -n "$vurl" ]] || { echo "fetch-minecraft-assets: version $version not in Mojang's manifest" >&2; exit 1; }
    curl -fsS -m 60 "$vurl" -o "$tmp/version.json"
    curl -fsS -m 120 "$(jq -r '.assetIndex.url' "$tmp/version.json")" -o "$tmp/index.json"
    [[ "$(sha1sum "$tmp/index.json" | cut -d' ' -f1)" == "$(jq -r '.assetIndex.sha1' "$tmp/version.json")" ]] || { echo "fetch-minecraft-assets: asset index checksum mismatch" >&2; exit 1; }
    src_index="$tmp/index.json"; src_objects=""
    if ((!SOUNDS_ONLY)) && [[ -z "$src_jar" ]]; then
        log "downloading client jar $version …"
        curl -fsS -m 600 "$(jq -r '.downloads.client.url' "$tmp/version.json")" -o "$tmp/client.jar"
        [[ "$(sha1sum "$tmp/client.jar" | cut -d' ' -f1)" == "$(jq -r '.downloads.client.sha1' "$tmp/version.json")" ]] || { echo "fetch-minecraft-assets: client jar checksum mismatch" >&2; exit 1; }
        src_jar="$tmp/client.jar"
    fi
    log "source: Mojang servers (Minecraft $version)"
fi

# ---------------------------------------------------------------------------------------------- idempotence
done_already=0
if ((!FORCE)) && [[ -f "$OUT/VERSION" && -f "$OUT/.complete" && "$(head -1 "$OUT/VERSION")" == "$version" && -f "$OUT/sounds.json" ]]; then
    if ((SOUNDS_ONLY)) || [[ -d "$OUT/textures" ]]; then
        log "$OUT is already Minecraft $version (--force to redo)"
        done_already=1
    fi
fi

if ((!done_already)); then
    stage="$tmp/stage"; mkdir -p "$stage"
    # ------------------------------------------------------------------------------------------ jar parts
    if ((!SOUNDS_ONLY)); then
        log "extracting textures, models, blockstates, font, texts, lang from the jar …"
        unzip -q -o "$src_jar" 'assets/minecraft/textures/*' 'assets/minecraft/models/*' 'assets/minecraft/blockstates/*' \
            'assets/minecraft/font/*' 'assets/minecraft/texts/*' 'assets/minecraft/lang/en_us.json' -d "$tmp/jar"
        for d in textures models blockstates font texts; do
            mv "$tmp/jar/assets/minecraft/$d" "$stage/$d"
        done
        mkdir -p "$stage/lang"; mv "$tmp/jar/assets/minecraft/lang/en_us.json" "$stage/lang/en_us.json"
    fi

    # ------------------------------------------------------------------------------------------ sounds
    jq -r '.objects | to_entries[] | select(.key | test("^minecraft/sounds(/.*\\.ogg|\\.json)$")) | "\(.value.hash) \(.key)"' "$src_index" > "$tmp/sound-list"
    log "sounds: $(wc -l < "$tmp/sound-list") objects (sha1-verified) …"
    # destination dirs in one go, then either copy from the local object store (one shell, no per-file forks of bash)
    # or download everything with a single parallel curl; finally verify all sha1s with one `sha1sum -c`.
    awk '{k=$2; sub(/^minecraft\//, "", k); n=split(k, a, "/"); d=""; for (i=1;i<n;i++) d=d a[i] "/"; print d}' "$tmp/sound-list" | sort -u |
        while IFS= read -r d; do mkdir -p "$stage/$d"; done
    if [[ -n "$src_objects" ]]; then
        awk -v so="$src_objects" -v st="$stage" '{k=$2; sub(/^minecraft\//, "", k); printf "cp -- \"%s/%s/%s\" \"%s/%s\"\n", so, substr($1,1,2), $1, st, k}' "$tmp/sound-list" > "$tmp/copy.sh"
        bash "$tmp/copy.sh"
    else
        awk -v base="$OBJECTS" -v st="$stage" '{k=$2; sub(/^minecraft\//, "", k); printf "url = \"%s/%s/%s\"\noutput = \"%s/%s\"\n", base, substr($1,1,2), $1, st, k}' "$tmp/sound-list" > "$tmp/curl.cfg"
        curl -fsS --parallel --parallel-max "$JOBS" --retry 5 --retry-all-errors -m 300 -K "$tmp/curl.cfg"
    fi
    awk -v st="$stage" '{k=$2; sub(/^minecraft\//, "", k); printf "%s  %s/%s\n", $1, st, k}' "$tmp/sound-list" > "$tmp/sha1.list"
    sha1sum --quiet -c "$tmp/sha1.list" || { echo "fetch-minecraft-assets: checksum mismatch in sounds" >&2; exit 1; }
    [[ -f "$stage/sounds.json" ]] || { echo "fetch-minecraft-assets: sounds.json missing" >&2; exit 1; }
    log "sounds: $(find "$stage/sounds" -name '*.ogg' | wc -l) .ogg files + sounds.json"

    # ------------------------------------------------------------------------------------------ install into $OUT
    mkdir -p "$OUT"
    rm -f "$OUT/.complete"
    parts=(sounds sounds.json)
    ((SOUNDS_ONLY)) || parts+=(textures models blockstates font texts lang)
    for part in "${parts[@]}"; do
        rm -rf "${OUT:?}/${part:?}"
        mv "$stage/$part" "$OUT/$part"
    done
    echo "$version" > "$OUT/VERSION"
    touch "$OUT/.complete"
    log "wrote $OUT (Minecraft $version)"
fi

# ---------------------------------------------------------------------------------------------- derived builds
if ((BUILD)); then
    uv_bin="$(command -v uv || ls ~/.hermes/tools/uv-*/uv 2>/dev/null | head -1 || true)"
    [[ -n "$uv_bin" ]] || { echo "fetch-minecraft-assets: --build needs uv (tools/assetforge)" >&2; exit 1; }
    if [[ "$OUT" == "$REPO/assets/mc" ]]; then bout="$REPO/assets"; else bout="$OUT.build"; fi
    log "building font → $bout/fonts and icons → $bout/icons/mc"
    "$uv_bin" run --project "$REPO/tools/assetforge" python "$REPO/tools/assetforge/build_font.py" --mc "$OUT" --out "$bout/fonts"
    "$uv_bin" run --project "$REPO/tools/assetforge" python "$REPO/tools/assetforge/render_icons.py" --mc "$OUT" --out "$bout/icons/mc"
    if [[ "$OUT" == "$REPO/assets/mc" ]]; then
        mkdir -p "$HOME/.local/share/fonts/overworld"
        cp "$bout"/fonts/OverworldMojangles-*.ttf "$HOME/.local/share/fonts/overworld/"
        if command -v fc-cache >/dev/null; then fc-cache -f "$HOME/.local/share/fonts/overworld" || true; fi
    fi
fi
