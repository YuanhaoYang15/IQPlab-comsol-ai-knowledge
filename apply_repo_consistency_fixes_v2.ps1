# apply_repo_consistency_fixes_v2.ps1
# Idempotent consistency fixes for IQPlab-comsol-ai-knowledge.
#
# Run from the repository root:
#   powershell -ExecutionPolicy Bypass -File .\apply_repo_consistency_fixes_v2.ps1
#
# This version is safe to rerun. It skips files that were already updated.

$ErrorActionPreference = "Stop"

function Update-TextBlock {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Old,
        [Parameter(Mandatory=$true)][string]$New,
        [Parameter(Mandatory=$true)][string]$AlreadyUpdatedMarker
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $Text = Get-Content -Raw -Encoding UTF8 $Path

    if ($Text.Contains($AlreadyUpdatedMarker)) {
        Write-Host "Already updated, skip: $Path"
        return
    }

    if (-not $Text.Contains($Old)) {
        Write-Warning "Target block not found and updated marker not found: $Path"
        Write-Warning "No change made to this file."
        return
    }

    $Text = $Text.Replace($Old, $New)
    Set-Content -Encoding UTF8 -Path $Path -Value $Text
    Write-Host "Updated: $Path"
}

function Update-RegexBlock {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Pattern,
        [Parameter(Mandatory=$true)][string]$Replacement,
        [Parameter(Mandatory=$true)][string]$AlreadyUpdatedMarker
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $Text = Get-Content -Raw -Encoding UTF8 $Path

    if ($Text.Contains($AlreadyUpdatedMarker)) {
        Write-Host "Already updated, skip: $Path"
        return
    }

    $NewText = [regex]::Replace($Text, $Pattern, $Replacement, "Singleline")

    if ($NewText -eq $Text) {
        Write-Warning "Regex target not found and updated marker not found: $Path"
        Write-Warning "No change made to this file."
        return
    }

    Set-Content -Encoding UTF8 -Path $Path -Value $NewText
    Write-Host "Updated: $Path"
}

# 1. Fix stale next-step reference in environment setup doc.
$OldEnv = @'
After the environment setup is verified, continue with:

```text
docs/matlab_livelink_getting_started.md
templates/livelink_minimal_workflow.m
```

The environment setup should be completed before running large parameter sweeps or automated post-processing scripts.
'@

$NewEnv = @'
After the environment setup is verified, continue with the basic single-run
workflow and then the single-geometry validation case:

```text
docs/matlab_livelink_basic_workflow.md
templates/livelink_minimal_workflow.m
cases/case_001_validation_before_sweep.md
```

The environment setup and single-geometry validation should both be completed
before running large parameter sweeps or automated post-processing scripts.
'@

Update-TextBlock `
    -Path "docs/livelink_environment_setup.md" `
    -Old $OldEnv `
    -New $NewEnv `
    -AlreadyUpdatedMarker "cases/case_001_validation_before_sweep.md"

# 2. Update Module 04 boundary now that Module 05 exists.
$OldSweep = @'
## What this module does not cover yet

This module intentionally does not solve the following more specific tasks:

```text
TE/TM classification
mode-family tracking across width
field-overlap based mode matching
automatic branch stitching
parallel COMSOL jobs
optimization loops
```

These should be introduced in later modules after the basic sweep, loss screening, and all-mode result-saving workflow is clear.
'@

$NewSweep = @'
## Boundary with Module 05

This module intentionally stops at all-mode extraction, scalar diagnostics,
and bound-mode filtering. It does not perform final mode-family identification
or overlap-based verification by itself.

The following tasks are handled by Module 05:

```text
component-ratio-based mode-family identification
Ex/Ey-dominant and hybrid-mode labeling
field-overlap-based mode similarity checks
diagnosis of crossings and avoided crossings
mode-rank exchange checks
branch-stitching diagnostics
```

The following tasks are still beyond the current teaching sequence:

```text
parallel COMSOL jobs
optimization loops
```

Use `docs/matlab_livelink_mode_family_identification.md` after the Module 04
raw/accepted-mode sweep is working reliably.
'@

Update-TextBlock `
    -Path "docs/matlab_livelink_parameter_sweep.md" `
    -Old $OldSweep `
    -New $NewSweep `
    -AlreadyUpdatedMarker "## Boundary with Module 05"

# 3. Point Case 002 to Module 05 / Case 003 instead of vague later modules.
# Use regex because this sentence may have line-ending or spacing differences.
$CasePattern = "This case focuses on items 1.?4 and introduces item 6 as a diagnostic\.\s+Full TE/TM classification and mode-family tracking are left for later modules\."

$CaseReplacement = @'
This case focuses on items 1–4 and introduces item 6 as a diagnostic.
Component-ratio-based mode-family identification and overlap-based verification
are handled next in Module 05 and `cases/case_003_mode_family_identification.md`.
'@

Update-RegexBlock `
    -Path "cases/case_002_waveguide_width_sweep.md" `
    -Pattern $CasePattern `
    -Replacement $CaseReplacement `
    -AlreadyUpdatedMarker "cases/case_003_mode_family_identification.md"

Write-Host ""
Write-Host "Done. Now check:"
Write-Host "  git diff"
Write-Host "  git status"
