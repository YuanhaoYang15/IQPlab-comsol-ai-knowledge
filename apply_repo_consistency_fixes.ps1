# apply_repo_consistency_fixes.ps1
# Apply small documentation consistency fixes without using git patch.
# Run from the repository root:
#   powershell -ExecutionPolicy Bypass -File .\apply_repo_consistency_fixes.ps1

$ErrorActionPreference = "Stop"

function Replace-Text {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Old,
        [Parameter(Mandatory=$true)][string]$New
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $Text = Get-Content -Raw -Encoding UTF8 $Path

    if (-not $Text.Contains($Old)) {
        throw "Target text not found in: $Path"
    }

    $Text = $Text.Replace($Old, $New)

    # Write as UTF-8. In Windows PowerShell 5.1 this may include BOM;
    # this is acceptable for Markdown files. Git will still track the text.
    Set-Content -Encoding UTF8 -Path $Path -Value $Text

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

Replace-Text `
    -Path "docs/livelink_environment_setup.md" `
    -Old $OldEnv `
    -New $NewEnv

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

Replace-Text `
    -Path "docs/matlab_livelink_parameter_sweep.md" `
    -Old $OldSweep `
    -New $NewSweep

# 3. Point Case 002 to Module 05 / Case 003 instead of vague later modules.
$OldCase = @'
This case focuses on items 1–4 and introduces item 6 as a diagnostic. Full TE/TM classification and mode-family tracking are left for later modules.
'@

$NewCase = @'
This case focuses on items 1–4 and introduces item 6 as a diagnostic.
Component-ratio-based mode-family identification and overlap-based verification
are handled next in Module 05 and `cases/case_003_mode_family_identification.md`.
'@

Replace-Text `
    -Path "cases/case_002_waveguide_width_sweep.md" `
    -Old $OldCase `
    -New $NewCase

Write-Host ""
Write-Host "Done. Now run:"
Write-Host "  git diff"
Write-Host "  git status"
