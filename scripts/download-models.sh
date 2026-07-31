#!/usr/bin/env bash
# Download official (v1-pinned) and/or Huihui-abliterated NInfer artifacts.
# Usage: ./scripts/download-models.sh [all|baseline|abliterated|35b-baseline|27b-baseline|35b-abliterated|27b-abliterated]
# Env: OUT=./models (default)
set -euo pipefail

MODELS="${1:-abliterated}"
OUT="${OUT:-./models}"

if ! command -v hf >/dev/null 2>&1; then
  echo "hf CLI not found. Install: pip install -U 'huggingface_hub[cli]'" >&2
  exit 1
fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

download_one() {
  local key="$1" repo="$2" file="$3" rev="$4" expect="$5"
  echo "==> $key -> $repo / $file"
  local args=(download "$repo" "$file" --local-dir "$OUT")
  if [[ -n "$rev" ]]; then
    args+=(--revision "$rev")
  fi
  hf "${args[@]}"
  local dest="$OUT/$file"
  [[ -f "$dest" ]] || { echo "Missing after download: $dest" >&2; exit 1; }
  local got
  got="$(sha256_file "$dest")"
  if [[ "${got,,}" != "${expect,,}" ]]; then
    echo "SHA-256 mismatch for $file" >&2
    echo "  expected $expect" >&2
    echo "  got      $got" >&2
    exit 1
  fi
  echo "OK $file sha256=$got"
}

mkdir -p "$OUT"

run_key() {
  case "$1" in
    35b-baseline)
      download_one "$1" "neroued/Qwen3.6-35B-A3B-NInfer" "qwen3_6_35b_a3b.ninfer" "b8204617b0a7" \
        "9e8378398d2b789a77224b5110c7590adbbc6fd4accd139b918157b2b9da7163"
      ;;
    27b-baseline)
      download_one "$1" "neroued/Qwen3.6-27B-NInfer" "qwen3_6_27b.ninfer" "56da0d05410f" \
        "74fac75f3a6b7ab7b52e08c36969c7a33a8ba23465910eccd72d195adb497127"
      ;;
    35b-abliterated)
      download_one "$1" "ahmed22xa/Qwen3.6-35B-A3B-huihui-abliterated-NInfer" \
        "qwen3_6_35b_a3b_huihui_abliterated.ninfer" "" \
        "be263652c8540b9f6d2655fcded3b23eed3193e0c18f9fc29f088a9cd3d6689b"
      ;;
    27b-abliterated)
      download_one "$1" "ahmed22xa/Qwen3.6-27B-huihui-abliterated-NInfer" \
        "qwen3_6_27b_huihui_abliterated.ninfer" "" \
        "1022d8695caa5d04528f7633e4b21bcbefd3b6173cd67babdd4af0ab682c3dc2"
      ;;
    *)
      echo "Unknown model key: $1" >&2
      exit 1
      ;;
  esac
}

case "$MODELS" in
  all) keys=(35b-baseline 27b-baseline 35b-abliterated 27b-abliterated) ;;
  baseline) keys=(35b-baseline 27b-baseline) ;;
  abliterated) keys=(35b-abliterated 27b-abliterated) ;;
  35b-baseline|27b-baseline|35b-abliterated|27b-abliterated) keys=("$MODELS") ;;
  *)
    echo "Usage: $0 [all|baseline|abliterated|35b-baseline|27b-baseline|35b-abliterated|27b-abliterated]" >&2
    exit 1
    ;;
esac

for k in "${keys[@]}"; do
  run_key "$k"
done

echo "Done. Artifacts in $OUT"
