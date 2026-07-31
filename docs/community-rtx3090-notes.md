# Community notes: RTX 3090 install, abliterated artifacts, context limits

Notes from validating [Don-Chad/ninfer-3090](https://github.com/Don-Chad/ninfer-3090) prebuilt **v0.3.1** on a single **RTX 3090 24 GB** (Windows, driver ~610.x). This documents what works, what breaks, and how to obtain ready-made abliterated `.ninfer` files without converting locally.

## Why these notes exist

The upstream engine only loads **`.ninfer`** containers (not GGUF / safetensors at runtime). Abliterated weights therefore need either:

1. A full BF16 Hugging Face checkpoint converted with `tools/convert/qwen3_6_*`, or
2. A pre-converted `.ninfer` download (preferred for most users).

Additionally, current Hugging Face **`main`** artifacts for the official NInfer models may be **container v2** (e.g. DFlash). The Don-Chad **v0.3.1** prebuilt expects **container v1** (`NINFER\0\x01`). Pinning the revisions below avoids a silent “wrong magic / incompatible artifact” failure.

## Recommended install layout

```
ninfer-3090/                 # install root (NINFER_ROOT)
  bin/                       # Windows or Ubuntu release from GitHub Releases
  models/                    # .ninfer artifacts
  scripts/                   # optional: copy from this repo’s scripts/install-root/
```

Set `NINFER_ROOT` to that directory, or run the serve helpers from `scripts/install-root/` after copying them next to `bin/` and `models/`.

## Official baseline artifacts (container v1 pins)

| Model | HF repo | Pin revision | Filename | Size | SHA-256 |
|---|---|---|---|---:|---|
| Qwen3.6-35B-A3B | [neroued/Qwen3.6-35B-A3B-NInfer](https://huggingface.co/neroued/Qwen3.6-35B-A3B-NInfer) | `b8204617b0a7` | `qwen3_6_35b_a3b.ninfer` | ~20.84 GiB | `9e8378398d2b789a77224b5110c7590adbbc6fd4accd139b918157b2b9da7163` |
| Qwen3.6-27B | [neroued/Qwen3.6-27B-NInfer](https://huggingface.co/neroued/Qwen3.6-27B-NInfer) | `56da0d05410f` | `qwen3_6_27b.ninfer` | ~16.29 GiB | `74fac75f3a6b7ab7b52e08c36969c7a33a8ba23465910eccd72d195adb497127` |

Do **not** assume `main` matches these digests.

## Abliterated artifacts (pre-converted, container v1)

Converted with the upstream converters from Huihui BF16 sources (full tensor sets including MTP; Vision tensors present in the artifact even when unused at runtime):

| Artifact | Source BF16 | HF download | Size | SHA-256 |
|---|---|---|---:|---|
| `qwen3_6_35b_a3b_huihui_abliterated.ninfer` | [huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated](https://huggingface.co/huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated) | [ahmed22xa/Qwen3.6-35B-A3B-huihui-abliterated-NInfer](https://huggingface.co/ahmed22xa/Qwen3.6-35B-A3B-huihui-abliterated-NInfer) | ~20.84 GiB | `be263652c8540b9f6d2655fcded3b23eed3193e0c18f9fc29f088a9cd3d6689b` |
| `qwen3_6_27b_huihui_abliterated.ninfer` | [huihui-ai/Huihui-Qwen3.6-27B-abliterated](https://huggingface.co/huihui-ai/Huihui-Qwen3.6-27B-abliterated) | [ahmed22xa/Qwen3.6-27B-huihui-abliterated-NInfer](https://huggingface.co/ahmed22xa/Qwen3.6-27B-huihui-abliterated-NInfer) | ~16.29 GiB | `1022d8695caa5d04528f7633e4b21bcbefd3b6173cd67babdd4af0ab682c3dc2` |

Quant recipe matches upstream official NInfer role-based mixed formats (embeddings/attention/shared experts W8, routed experts Q4/Q5/Q6, norms BF16/FP32, etc.). Footprint matches the official artifacts of the same architecture.

### Why Huihui (not every “abliterated” BF16)

Some abliterated BF16 dumps omit MTP (and related) tensors. The converter expects the **full** official parameter set (~1045 tensors for 35B-A3B including MTP + Vision frontends). Huihui matched the expected counts; incomplete dumps fail or need surgery outside this project’s scope.

### Download without converting

From the install root (or any folder; pass `--out`):

```powershell
# PowerShell
.\scripts\download-models.ps1 -Models abliterated
# or: baseline | all | 35b-abliterated | 27b-abliterated | ...
```

```bash
# bash / WSL
./scripts/download-models.sh abliterated
```

Requires [`hf`](https://huggingface.co/docs/huggingface_hub/guides/cli) (`pip install -U huggingface_hub`).

## Runtime findings (RTX 3090 24 GB)

### Text vs vision

| Model | `--text-only` | Vision | Notes |
|---|---|---|---|
| 35B-A3B (official or huihui) | **Required** on 24 GB | Not usable in practice | Vision workspace does not fit with useful KV |
| 27B (official or huihui) | Not required | Works | ~19 GiB reserved in short smoke tests with vision path |

### Serve / API

`ninfer-serve` exposes OpenAI- and Anthropic-compatible routes. Root `/` is **404**. Use:

- `GET /health`
- `GET /v1/models`
- `POST /v1/chat/completions`

The request `model` field must match `--model-id` (e.g. `qwen3.6-35b-a3b-huihui-abliterated`).

### Throughput smoke (indicative, short prompts)

- 35B MTP-3 + INT8 KV + `--text-only`: roughly **250–317 tok/s** decode in local smoke tests
- 27B vision path, same speculation flags: roughly **40–50 tok/s** in short vision smoke tests

Upstream README numbers for repetition-rich code + prompt-lookup remain the published ceiling; ordinary text sits nearer the MTP-controlled figures.

### Max `--max-context` (measured)

Flags for primary numbers: `--kv-dtype int8 --mtp-draft-tokens 3 --lm-head-draft`, CUDA Graphs on. 35B always `--text-only`. 27B without `--text-only` (vision workspace reserved). Free VRAM ~22.8 GiB before load in the test environment.

| Model | Max `--max-context` (INT8) | GPU reserved | Notes |
|---|---:|---:|---|
| 35B baseline / huihui | **81920** | ~22.03 GiB | 86016 can load but graph capture becomes very slow / flaky |
| 27B baseline / huihui (vision) | **90112** | ~21.92 GiB | 94208 near the edge |

Absolute capacity (slower / quality trade-off):

| Config | Max `--max-context` |
|---|---:|
| 35B `--kv-dtype k8v4` or `int4` + `--no-cuda-graph --text-only` | **131072** |
| 27B `--kv-dtype k8v4` + `--no-cuda-graph` (vision) | **131072** |

CLI max-context numbers above are **not** directly transferable to `ninfer-serve` with the same
flags. CLI and serve share the same engine planner; the OOM gap comes from **what is reserved at
startup**, not from a second memory system.

### CUDA Graphs (what / why / cost)

CUDA Graphs record a full decode round once and **replay** it each step, cutting CPU launch
overhead (higher tok/s). They are **on by default**.

Cost: VRAM for many captured executables across capacity **frontier ranges**, plus separate
families for ordinary decode, MTP, and prompt-lookup. Long frontiers are budgeted at tens of MiB
each in the planner (`graph_allowance_bytes`). Large `--max-context` combined with MTP **and**
prompt-lookup therefore multiplies graph reservation quickly.

`--no-cuda-graph` skips that allowance (eager launches). Use it when long context on 24 GB matters
more than peak decode speed.

### Serve vs CLI on 24 GB (INT8 + MTP-3 + prompt-lookup)

| Mode | Practical max `--max-context` |
|---|---:|
| 35B + graphs (default) | **8192** (12288 already OOMs) |
| 35B + `--no-cuda-graph` | **65536** |
| 27B vision + graphs | **12288** |
| 27B vision + `--no-cuda-graph` | **64000** (65536 fails by a thin margin) |

A CLI smoke without prompt-lookup can appear to “fit” a larger context with graphs still enabled,
because lookup graph families are absent from the plan. Matching serve’s Lookup + MTP + Graphs
flags reproduces the tighter serve limits.

Default serve helpers therefore use **`--no-cuda-graph`** with **65536** (35B) / **64000** (27B vision).

## Convert yourself (optional)

Only needed if you change the BF16 source or converter recipe:

```text
# 35B-A3B — from a checkout that includes tools/convert
python -m tools.convert.qwen3_6_35b_a3b \
  --checkpoint <BF16_DIR> \
  --output models/qwen3_6_35b_a3b_custom.ninfer
```

```text
# 27B
python -m tools.convert.qwen3_6_27b \
  --checkpoint <BF16_DIR> \
  --output models/qwen3_6_27b_custom.ninfer
```

Exact flags follow upstream `tools/convert` / maintainer docs. Source BF16 for Huihui is large (~tens of GB); delete checkpoints after conversion if disk is tight.

## Serve helpers

See `scripts/install-root/`. Copy next to `bin/` + `models/`, or set `NINFER_ROOT`.

| Script | Artifact | Model id | Notes |
|---|---|---|---|
| `start-serve-abliterated.cmd` | 35B huihui | `qwen3.6-35b-a3b-huihui-abliterated` | `--text-only`, `--max-context 65536`, `--no-cuda-graph` |
| `start-serve-baseline.cmd` | 35B official | `qwen3.6-35b-a3b` | same |
| `start-serve-27b-abliterated.cmd` | 27B huihui | `qwen3.6-27b-huihui-abliterated` | vision, `--max-context 64000`, `--no-cuda-graph` |
| `start-serve-27b-baseline.cmd` | 27B official | `qwen3.6-27b` | same |

## Licensing / attribution

- Engine: upstream Don-Chad / Neroued NInfer project licenses as published in this repository.
- Official `.ninfer` weights: see neroued model cards on Hugging Face.
- Huihui abliterated BF16 sources: see huihui-ai model cards; converted NInfer dumps inherit the same base-model constraints plus conversion attribution on the published model cards.

## What this branch does *not* change

No engine kernel changes are claimed here. This branch adds documentation, download helpers, and serve scripts for a validated RTX 3090 workflow (v1 pins, abliterated downloads, 65k default context, vision vs text-only).
