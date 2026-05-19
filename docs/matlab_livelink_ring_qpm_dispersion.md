# MATLAB LiveLink Ring QPM Dispersion Workflow

Module 07 extends the optical mode-analysis sequence from single-mode extraction and mode-family tracking to a complete ring-level dispersion and quasi-phase-matching workflow.

The module is built around a reusable MATLAB toolbox for 1550 nm fundamental modes and 775 nm second-harmonic modes in a lithium-niobate ring geometry. It uses a COMSOL mode-analysis model through MATLAB LiveLink, extracts selected IR and SH mode branches, and computes ring-level quantities relevant to SHG, OPO, and frequency-grid design.

---

## Purpose

This module is intended for questions such as:

```text
For a given ring radius and waveguide geometry, what are the IR and SH mode grids?
How do D1, D2, Dint, GVM, GVD, and QPM period vary with wavelength?
Is the selected 1550 nm mode branch smooth enough to define a usable frequency grid?
How does the SH mode grid compare with twice the IR mode grid?
```

The main workflow is:

```text
COMSOL mode analysis over wavelength
        ↓
select IR and SH mode families
        ↓
store raw and selected mode data
        ↓
compute ring dispersion and QPM metrics
        ↓
plot and reinterpret without rerunning COMSOL
```

---

## File structure

Recommended repository placement:

```text
docs/
└── matlab_livelink_ring_qpm_dispersion.md

templates/
└── ring_qpm/
    ├── README.md
    ├── README_dependencies.txt
    ├── scripts/
    │   ├── Sweep_ring_qpm_geometry.m
    │   ├── Plot_single_ring_qpm_result.m
    │   ├── Batch_postprocess_ring_qpm_jump_breaks.m
    │   └── Query_ring_qpm_postprocessed_result.m
    ├── functions/
    │   ├── run_ring_qpm_case.m
    │   ├── estimate_sweep_time_upper_bound.m
    │   ├── get_material_index.m
    │   ├── get_material_index_MgLN.m
    │   └── get_material_index_r.m
    └── plotting/
        └── plot_ring_qpm_result.m

cases/
└── case_005_ring_qpm_dispersion_workflow.md

tests/
└── validation_prompts_module_07_ring_qpm.md
```

Do not commit large local outputs:

```text
models/*.mph
results/*.mat
results/**/*.mat
local_outputs/
```

The `.mph` model and generated `.mat` files should stay local unless they are deliberately sanitized, small, and suitable for public sharing.

---

## Main scripts

### `scripts/Sweep_ring_qpm_geometry.m`

This is the high-level sweep driver. It:

- loads one COMSOL `.mph` model from a local `models/` folder;
- adds the module's `functions/` and `plotting/` folders to the MATLAB path;
- defines geometry lists, wavelength range, and target mode families;
- estimates runtime before the full sweep;
- loops over ring radius, waveguide width, and ridge thickness;
- calls `run_ring_qpm_case` for each geometry;
- saves one result `.mat` file per successful case plus a sweep log.

Important user-editable blocks:

```matlab
R_list       = 30:10:100;    % [um]
w_list       = 1.1;          % [um]
t_ridge_list = 0.4;          % [um]

scan.lambda0_IR = 1.55;      % [um]
scan.span_IR    = 0.20;      % [um]
scan.step_IR    = 0.002;     % [um]

select.IR.pol   = 'TM';
select.IR.order = 1;
select.SH.pol   = 'TM';
select.SH.order = 1;
```

### `functions/run_ring_qpm_case.m`

This is the core calculation function. For one geometry, it:

- validates whether enough modes are solved at representative wavelengths;
- scans IR wavelengths and maps SH wavelengths by `lambda_SH = lambda_IR/2`;
- reads all returned modes and keeps raw mode tables;
- selects the desired TE-like or TM-like mode branch;
- computes selected-branch `neff`, `ng`, Q, and mode fractions;
- converts waveguide-mode data into ring-mode data;
- computes QPM period, GVM, `D1`, `D2`, `Dint`, and SHG frequency mismatch;
- saves a structured `out` variable.

### `plotting/plot_ring_qpm_result.m`

This plotting helper loads one saved `out` structure and creates summary figures for:

- `neff` and QPM period;
- group index `ng`;
- integrated dispersion `Dint`;
- GVM and SHG mismatch.

It also supports post-processing crop and center-wavelength reset without rerunning COMSOL.

### `scripts/Plot_single_ring_qpm_result.m`

This is a user-level plotting script for one saved result. The latest version includes an additional GVD figure for both wavelength bands.

### `scripts/Batch_postprocess_ring_qpm_jump_breaks.m`

This is a post-processing script for saved results. It does not rerun COMSOL.
It reloads the all-mode arrays saved in `out.Data_IR` and `out.Data_SH`,
reselects the requested branches using configurable Q and polarization
thresholds, detects selected-branch `neff` jumps, and splits dispersion
calculations at jump boundaries.

Use this script when:

- `Dint`, QPM period, GVM, or SHG mismatch shows sharp nonphysical features;
- the selected `solnum` changes abruptly across wavelength;
- a branch may have crossed or exchanged character with another mode family;
- thresholds need to be reinterpreted without rerunning an expensive COMSOL sweep.

The output includes `batch_summary.csv`, `jump_warnings.csv`, per-case
`processed_result.mat` files, and optional figures. These outputs are generated
data and should remain local.

### `scripts/Query_ring_qpm_postprocessed_result.m`

This helper reads a `postprocessed_jump_break_*` output folder and retrieves one
case by geometry and mode-selection metadata. It is intended for reviewing one
postprocessed case after a larger batch run.

---

## COMSOL-side requirements

The module assumes an already validated COMSOL optical mode-analysis model. It is not a from-scratch COMSOL model builder.

Required study and result assumptions:

```text
study tag:       std1
mode feature:    mode
dataset:         usually dset1, otherwise the last available dataset
```

Required or expected COMSOL parameters:

```text
Radius
w_center
w_ln
t_ln
t_ridge
w_pml
theta
wavelength
no
ne
n_sio2
nref
Ravg
rAverage
```

Optional geometry parameters used when present:

```text
t_sio2
t_air
```

Required mode-classification variables:

```text
TEfrac
TMfrac
```

Optional but recommended radial-average variables:

```text
ewfd.rAverage
ewfd.raverage
rAverage
raverage
```

If `rAverage` cannot be read, the script falls back to `Radius`, but that should be treated as a diagnostic fallback rather than a validated physical result.

---

## Important physical and coding conventions

### Wavelength convention

The fundamental band is scanned directly:

```text
lambda_IR = lambda0_IR +/- span_IR/2
```

The second-harmonic band is mapped from the fundamental wavelength:

```text
lambda_SH = lambda_IR / 2
```

### Ring mode number

The code estimates the azimuthal mode number using:

```text
m = 2*pi*R*neff/lambda
```

Then it interpolates onto integer `m` values and defines:

```text
mu = m - m0
```

where `m0` is the rounded mode number at the selected center wavelength.

### Integrated dispersion

For each band, the code computes:

```text
Dint(mu) = omega_mu - (omega0 + D1*mu)
```

Both angular-frequency and ordinary-frequency versions are saved:

```text
Dint_rad_s
Dint_Hz
D1_rad_s, D1_Hz
D2_rad_s, D2_Hz
```

### SHG mode-grid mismatch

The SHG grid comparison uses:

```text
mu_SH = 2*mu_IR
```

and computes:

```text
Delta_f_SHG = f_SH(mu_SH) - 2*f_IR(mu_IR)
```

A center-referenced version is also saved:

```text
Delta_f_rel = Delta_f_SHG - Delta_f_SHG(mu_IR = 0)
```

This is useful for identifying whether the SH mode grid remains aligned with twice the IR mode grid across many cavity modes.

### QPM period

The local QPM period estimate uses:

```text
Lambda_QPM = lambda_IR / [2*(neff_SH(lambda_IR/2) - neff_IR(lambda_IR))]
```

The signed value is saved as `Lambda_QPM_signed_um`, and the absolute value is saved as `Lambda_QPM_um`.

### GVM

The group-velocity mismatch is saved in `fs/mm`:

```text
GVM = (ng_SH - ng_IR)/c
```

where `ng_SH` is evaluated at `lambda_IR/2`.

---

## Output structure

A successful run saves an `out` structure with fields such as:

```text
out.status
out.geom
out.scan
out.select
out.opts
out.validation
out.lambda_IR
out.lambda_SH
out.Data_IR
out.Data_SH
out.neff_IR
out.neff_SH
out.ng_IR
out.ng_SH
out.Result_IR
out.Result_SH
out.Lambda_QPM_um
out.Lambda_QPM_signed_um
out.GVM_fs_per_mm
out.Walk
out.min_Q_IR_sel
out.min_Q_SH_sel
out.smooth
```

The `Data_IR` and `Data_SH` fields keep both raw mode arrays and selected-branch arrays. This is important because the selected branch can be audited later without rerunning COMSOL.

---

## Jump-break post-processing

Mode sorting by `real(neff)` can look smooth for many points and still fail near
crossings or avoided crossings. The jump-break post-processing template is a
second-pass diagnostic that keeps the expensive COMSOL solve separate from
cheap branch reinterpretation.

Recommended use:

1. Run the normal sweep and save all returned modes.
2. Inspect one or more suspicious saved `out` files.
3. Run `Batch_postprocess_ring_qpm_jump_breaks.m` with a user-selected source
   folder or explicit file list.
4. Review `jump_warnings.csv`, selected `solnum`, Q, TE/TM fractions, and
   segmented `Dint` plots.
5. Treat each segment as a continuous numerical branch only inside that segment.

This diagnostic does not prove that the physical mode character is unchanged.
A branch segment should still be checked using field profiles, TE/TM fractions,
Q, confinement diagnostics, and, when available, field-overlap tracking.

---

## Recommended validation workflow

Before running a large sweep:

1. Open the COMSOL model in the GUI and verify one geometry visually.
2. Confirm `TEfrac`, `TMfrac`, and, if possible, `rAverage` are defined correctly.
3. Run one geometry with `opts.do_validation = true`.
4. Inspect the selected solnums, Q values, and TE/TM fractions.
5. Plot one result and check whether `neff`, `ng`, and `Dint` are smooth.
6. Only then run a multi-geometry sweep.

For suspicious results, check:

```text
wrong mode family selected
insufficient number of solved modes
PML or substrate mode selected
rAverage/Radius correction missing or wrong
wavelength span too narrow for integer-mode interpolation
Dint interpreted in Hz when the code output is rad/s, or vice versa
```

---

## How this module relates to earlier modules

Module 07 depends on ideas from the earlier sequence:

```text
Module 01: LiveLink connection and model loading
Module 02: single-run study execution
Module 03: scalar result extraction with mphglobal
Module 04: all-mode extraction and bound-mode filtering
Module 05: mode-family identification by component metrics
Module 07: ring-level dispersion, QPM, and SHG grid analysis
```

It should not replace the earlier modules. It is a higher-level application built on top of them.
