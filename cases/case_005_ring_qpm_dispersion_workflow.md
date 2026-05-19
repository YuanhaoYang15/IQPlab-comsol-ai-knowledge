# Case 005 — Ring QPM Dispersion Workflow

## Context

This case documents a ring-level dispersion workflow for lithium-niobate devices where the target nonlinear process links a 1550 nm fundamental mode family with a 775 nm second-harmonic mode family.

The goal is not simply to extract `neff` from COMSOL. The goal is to build a mode-grid model that can be used to reason about QPM period, Dint, GVM, SHG mismatch, and the usable density/uniformity of the 1550 nm frequency grid.

---

## Recommended workflow

1. Start from a GUI-validated COMSOL mode-analysis model.
2. Define `TEfrac`, `TMfrac`, and preferably `rAverage` in the model.
3. Run a single geometry with validation enabled.
4. Inspect the selected IR and SH mode branches.
5. Compute and plot ring quantities.
6. Run geometry sweeps only after the single-case result is physically reasonable.

---

## Important implementation choices

### Keep raw and selected modes

The workflow stores both all returned modes and the selected branch. This allows later debugging when the wrong mode family is selected or when mode ordering changes.

### Use post-processing for thresholds

Do not rerun the expensive COMSOL sweep just to reinterpret a Q threshold, TE/TM threshold, or plotting window. Save raw data first.

### Break suspicious branches before dispersion interpretation

When the selected branch has an abrupt `neff` jump, do not force one global
`Dint` fit across the jump. Reload the saved all-mode data, reselect the target
mode family, detect jump boundaries, and compute dispersion only inside each
continuous segment.

The reusable template is:

```text
templates/ring_qpm/scripts/Batch_postprocess_ring_qpm_jump_breaks.m
```

The companion query helper is:

```text
templates/ring_qpm/scripts/Query_ring_qpm_postprocessed_result.m
```

This workflow keeps COMSOL solving separate from cheap branch-selection review.
It also preserves the raw all-mode data so that a suspicious selected branch can
be audited without rerunning the original sweep.

### Treat `rAverage` carefully

For axisymmetric or curved-coordinate optical mode models, the raw `ewfd.neff` may need correction using the actual radial average. The template stores:

```text
neff_raw_all
neff_all
rAverage_all
scale_all
```

so that this correction can be audited.

---

## Common failure modes

```text
No TE-like or TM-like mode found
    The Q threshold or polarization threshold may be too strict, or too few modes are requested.

Dint looks discontinuous
    The selected branch may jump to another family, or the wavelength grid is too sparse.
    Use jump-break post-processing before interpreting D1, D2, GVM, or SHG mismatch.

QPM period has sharp spikes
    neff_SH - neff_IR may pass near zero, or one branch is incorrectly selected.

SHG mismatch has missing points
    The integer SH mode range may not include mu_SH = 2*mu_IR for all IR points.

Result is sensitive to PML settings
    A PML/substrate/leaky mode may be selected, or the model boundary setup is not converged.
```

---

## What to ask an AI assistant to check

A useful prompt is:

```text
Read docs/matlab_livelink_ring_qpm_dispersion.md and templates/ring_qpm/ first.
Then inspect whether my selected IR and SH mode branches are physically continuous.
Do not assume solnum = 1 is correct. Check raw modes, Q values, TE/TM fractions, and Dint smoothness.
```
