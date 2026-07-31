#Requires -Version 5.1
<#
.SYNOPSIS
  Download official (v1-pinned) and/or Huihui-abliterated NInfer artifacts.

.PARAMETER Models
  all | baseline | abliterated | 35b-baseline | 27b-baseline | 35b-abliterated | 27b-abliterated

.PARAMETER Out
  Destination directory for .ninfer files (default: .\models)
#>
param(
  [ValidateSet('all','baseline','abliterated','35b-baseline','27b-baseline','35b-abliterated','27b-abliterated')]
  [string]$Models = 'abliterated',
  [string]$Out = (Join-Path (Get-Location) 'models')
)

$ErrorActionPreference = 'Stop'

function Ensure-Hf {
  if (-not (Get-Command hf -ErrorAction SilentlyContinue)) {
    throw "hf CLI not found. Install: pip install -U 'huggingface_hub[cli]'"
  }
}

$catalog = @{
  '35b-baseline' = @{
    Repo = 'neroued/Qwen3.6-35B-A3B-NInfer'
    File = 'qwen3_6_35b_a3b.ninfer'
    Revision = 'b8204617b0a7'
    Sha256 = '9e8378398d2b789a77224b5110c7590adbbc6fd4accd139b918157b2b9da7163'
  }
  '27b-baseline' = @{
    Repo = 'neroued/Qwen3.6-27B-NInfer'
    File = 'qwen3_6_27b.ninfer'
    Revision = '56da0d05410f'
    Sha256 = '74fac75f3a6b7ab7b52e08c36969c7a33a8ba23465910eccd72d195adb497127'
  }
  '35b-abliterated' = @{
    Repo = 'ahmed22xa/Qwen3.6-35B-A3B-huihui-abliterated-NInfer'
    File = 'qwen3_6_35b_a3b_huihui_abliterated.ninfer'
    Revision = $null
    Sha256 = 'be263652c8540b9f6d2655fcded3b23eed3193e0c18f9fc29f088a9cd3d6689b'
  }
  '27b-abliterated' = @{
    Repo = 'ahmed22xa/Qwen3.6-27B-huihui-abliterated-NInfer'
    File = 'qwen3_6_27b_huihui_abliterated.ninfer'
    Revision = $null
    Sha256 = '1022d8695caa5d04528f7633e4b21bcbefd3b6173cd67babdd4af0ab682c3dc2'
  }
}

$groups = @{
  'all' = @('35b-baseline','27b-baseline','35b-abliterated','27b-abliterated')
  'baseline' = @('35b-baseline','27b-baseline')
  'abliterated' = @('35b-abliterated','27b-abliterated')
}

$keys = if ($groups.ContainsKey($Models)) { $groups[$Models] } else { @($Models) }

Ensure-Hf
New-Item -ItemType Directory -Force -Path $Out | Out-Null

foreach ($key in $keys) {
  $m = $catalog[$key]
  $dest = Join-Path $Out $m.File
  Write-Host "==> $key -> $($m.Repo) / $($m.File)"
  $args = @('download', $m.Repo, $m.File, '--local-dir', $Out)
  if ($m.Revision) { $args += @('--revision', $m.Revision) }
  & hf @args
  if (-not (Test-Path $dest)) { throw "Missing after download: $dest" }
  $hash = (Get-FileHash -Algorithm SHA256 -Path $dest).Hash.ToLowerInvariant()
  if ($hash -ne $m.Sha256.ToLowerInvariant()) {
    throw "SHA-256 mismatch for $($m.File)`n  expected $($m.Sha256)`n  got      $hash"
  }
  Write-Host "OK $($m.File) sha256=$hash"
}

Write-Host "Done. Artifacts in $Out"
