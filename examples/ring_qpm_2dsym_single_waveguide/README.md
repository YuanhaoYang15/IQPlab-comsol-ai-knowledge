# 2D Axisymmetric Single-Waveguide Example for Ring QPM Analysis

This folder contains a lightweight COMSOL example model that can be used with Module 07.

Example model file:

```text
LN_ridge_ring_qpm_2dsym_single_waveguide_example.mph
```

This model is copied from the Module 06 2D axisymmetric single-waveguide teaching example. That reuse is intentional: Module 07 needs a validated single-waveguide mode-analysis model that can be swept over ring radius, waveguide geometry, and wavelength before converting the selected mode branches into ring-mode quantities.

The model is intended for teaching and workflow validation, not as a final device model. Use it first for one geometry, inspect the selected IR and SH modes, and only then run larger sweeps.

## Intended Module 07 Use

The Ring QPM workflow expects a local model in:

```text
templates/ring_qpm/models/
```

For a local test, copy this `.mph` file into that folder:

```text
templates/ring_qpm/models/LN_ridge_ring_qpm_2dsym_single_waveguide_example.mph
```

Then configure a single geometry in:

```text
templates/ring_qpm/scripts/Sweep_ring_qpm_geometry.m
```

or call:

```text
templates/ring_qpm/functions/run_ring_qpm_case.m
```

from a small local MATLAB runner.

## Recommended First Test

For a first Module 07 sanity check, use one geometry before any sweep:

```text
Radius  = 50 um
w_ln    = 1.2 um
t_ln    = 0.6 um
t_ridge = 0.4 um
IR mode = TM0
SH mode = TM0
```

Before trusting the result, inspect:

- selected IR and SH `solnum` values;
- `real(neff)` and Q for all candidate modes;
- `TEfrac` and `TMfrac`;
- selected-branch smoothness;
- `Dint`, GVM, QPM period, and SHG mismatch plots;
- whether `rAverage` is a real model-defined diagnostic or only the fallback to `Radius`.

## File Policy

This `.mph` file is included only as a small public teaching example. Large private models, stored solution datasets, and generated `.mat` results should remain local.
