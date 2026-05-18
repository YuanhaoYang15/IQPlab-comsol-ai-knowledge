# Case 004 — Pulley Coupled-Q from a 2D Axisymmetric Single-Waveguide Model

## Goal

This case demonstrates how to estimate the external or coupled quality factor `Qc` of a pulley-coupled microring resonator using a 2D axisymmetric COMSOL mode model and MATLAB LiveLink.

The core idea is to reuse one single-waveguide 2D axisymmetric model by moving the active waveguide center:

```text
ring solve: active waveguide centered at Radius
bus solve:  active waveguide centered at R_bus_center
```

The ring and bus fields are combined in MATLAB through an overlap integral over the bus ridge region.

---

## Input Files

Required:

```text
examples/2dsym_single_waveguide_coupled_q/LN_ridge_2dsym_single_waveguide_example.mph
templates/livelink_coupled_q_2dsym_run.m
templates/livelink_coupled_q_2dsym_postprocess.m
templates/get_material_index_MgLN.m
```

The `.mph` file should be produced by cleaning a previously validated local model and saving it as a small teaching example.

---

## Why This Is a Separate Case

The workflow differs from ordinary mode sweeps because it combines two separate isolated-mode solves into one coupling estimate. It also requires careful interpretation of the radius used in COMSOL 2D axisymmetric mode analysis.

In particular, the script stores both:

```text
neff_raw
neff_actual = neff_raw * rAverage / r_center
```

This avoids silently mixing COMSOL's reference-radius convention with the physical ring and bus waveguide centers.

---

## Expected Workflow

1. Validate the single-waveguide `.mph` in COMSOL GUI.
2. Confirm the LiveLink connection from MATLAB.
3. Run one wavelength and one polarization first.
4. Inspect the printed mode table for ring and bus solves.
5. Confirm that the selected modes are the intended TE-like or TM-like families.
6. Confirm that `TEfrac`, `TMfrac`, `Q`, and `rAverage` are reasonable.
7. Run the full wavelength and pulley-angle scan.
8. Use the post-processing script to inspect `Qc` and `kappa^2`.
9. Treat the result as a design estimate, not a replacement for full coupled simulations or measurement.

---

## Acceptance Checklist

A result is acceptable for first-pass design only if:

- the model loads without path edits except the configurable `cfg.modelFile`;
- the study tag, mode feature tag, and dataset tag are correct;
- ring and bus mode tables are printed for every wavelength;
- the selected ring and bus modes pass the intended polarization filter;
- the selected modes have reasonable `real(neff)` values;
- the selected modes are not PML-localized or substrate-like modes;
- the bus-region mask matches the physical bus ridge area;
- `res_Qc` is finite over the useful angle range;
- the raw output `.mat` is saved before plotting;
- post-processing can be repeated without rerunning COMSOL.

---

## Red Flags

Do not trust the output if:

- the selected mode changes family between wavelengths;
- `rAverage` cannot be read and the fallback radius is physically inconsistent;
- `kappa^2` becomes large enough that the weak-coupling approximation is questionable;
- `Qc` contains many `Inf`, `NaN`, or extremely discontinuous points;
- the field profiles show strong PML/substrate localization;
- the bus mask does not overlap the actual bus ridge region;
- the model's TE/TM fraction definitions are missing or inconsistent with the plotted fields.

---

## Suggested Test Prompt for AI Assistants

```text
Read docs/livelink_coupled_q_2dsym.md and cases/case_004_pulley_coupled_q_2dsym.md.

Explain the workflow for estimating pulley coupled Q from a 2D axisymmetric single-waveguide COMSOL model. Then list the required COMSOL variables and the checks needed before trusting the result.
```

Expected answer should mention:

- isolated ring and bus single-waveguide solves;
- mode selection by TE/TM fraction and Q threshold;
- radius correction using `rAverage / r_center`;
- overlap integral over the bus ridge perturbation;
- saving raw data before plotting;
- limitations of the perturbative estimate.
