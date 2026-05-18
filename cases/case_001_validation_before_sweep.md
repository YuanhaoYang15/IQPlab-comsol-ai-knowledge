# Case 001 — Single-Geometry Validation Before Parameter Sweep

## Purpose

This case demonstrates the minimum validation workflow that should be completed before launching any COMSOL MATLAB LiveLink parameter sweep.

The goal is not to obtain a final design result. The goal is to answer a simpler question:

> Does one representative geometry run correctly, return physically meaningful modes, and produce trustworthy scalar results?

This case should be used before running sweep cases such as:

```text
cases/case_002_waveguide_width_sweep.md
```

A failed single-geometry validation means the full parameter sweep is not ready.

---

## Related files

```text
AGENTS.md

docs/livelink_environment_setup.md
docs/matlab_livelink_parameter_sweep.md

templates/check_livelink_connection.m
templates/livelink_minimal_workflow.m
templates/livelink_parameter_sweep_bound_modes.m
```

The scripts assume a COMSOL model similar to:

```text
examples/LN_ridge_waveguide_Zcut.mph
```

The actual `.mph` file may be omitted from the GitHub repository if it is too large, private, or model-specific.

---

## Core principle

Before running a large sweep, validate one representative geometry.

For optical mode-analysis models, never assume that a COMSOL-returned eigenmode is useful only because the solver returns it.

At the single-geometry stage, check:

1. the model can be loaded from MATLAB;
2. the LiveLink connection works;
3. the expected study tag exists;
4. the expected dataset tag exists;
5. the study runs successfully;
6. all returned modes can be extracted;
7. `real(neff)` is in a reasonable range;
8. `imag(neff)`, propagation loss, or estimated Q is reasonable;
9. the field profile is localized in the intended waveguide region;
10. no obvious PML-localized or substrate mode is being mistaken for the target mode.

Only after these checks should a parameter sweep be launched.

---

## Physical example

A typical validation geometry may be a lithium-niobate ridge waveguide mode-analysis model.

Example parameters:

```text
w_ln      = 1.2[um]
t_ln      = 0.4[um]
t_ridge   = 0.2[um]
lambda0   = 1.55[um]
```

These values are only examples. The correct validation point should be chosen near the center of the intended sweep range, not at an extreme boundary.

For example, if the later sweep is:

```matlab
cfg.wList_um = linspace(0.8, 1.4, 13);
```

then a good first validation point is:

```matlab
w_ln = 1.1[um]
```

or:

```matlab
w_ln = 1.2[um]
```

---

## COMSOL-side preparation

Before using MATLAB, open the `.mph` file in COMSOL GUI and confirm the following items.

### Required model components

The model should contain:

1. an optical mode-analysis physics interface;
2. a validated geometry;
3. materials with correct refractive indices or permittivity tensors;
4. mesh settings that are already known to run for one geometry;
5. boundary conditions or PML settings appropriate for the problem;
6. one mode-analysis study;
7. one result dataset containing the solved modes.

### Required tags

Confirm the actual COMSOL tags.

Common examples are:

```text
study tag    : std1
dataset tag  : dset1
physics tag  : ewfd
```

Do not assume these tags are correct. Check them in the COMSOL Model Builder.

### Required expressions

For a basic optical mode-analysis validation, the most important expression is:

```text
ewfd.neff
```

Optional but useful diagnostic expressions may include:

```text
ewfd.dampzdB
frac_E2_LN
TE_frac
TM_frac
```

The optional expressions must be defined in the COMSOL model before MATLAB can extract them.

---

## Step 1: Check LiveLink connection

Run:

```text
templates/check_livelink_connection.m
```

The expected result is that MATLAB can communicate with the COMSOL server.

If this fails, do not debug the optical model yet. Fix the environment first.

Common causes are:

```text
MATLAB was not started from COMSOL Multiphysics with MATLAB
COMSOL server is not running
COMSOL mli path is missing
wrong COMSOL version
wrong port
license unavailable
```

---

## Step 2: Run the minimal LiveLink workflow

Run:

```text
templates/livelink_minimal_workflow.m
```

This script should do only the minimum required actions:

1. locate the repository root;
2. locate the example `.mph` file;
3. load the model;
4. optionally set one or several parameters;
5. run the existing study;
6. extract one or several scalar results;
7. save the result and metadata.

This script should not perform a parameter sweep.

---

## Step 3: Validate model path and tags

The minimal workflow should explicitly print:

```text
repository root
model path
study tag
result expressions
output folder
```

If the model path is wrong, fix:

```matlab
modelPath = fullfile(repoRoot, 'examples', 'LN_ridge_waveguide_Zcut.mph');
```

If the study tag is wrong, fix:

```matlab
studyTag = 'std1';
```

If the result dataset is required explicitly, use the correct dataset tag when calling `mphglobal`:

```matlab
neff_all = mphglobal(model, 'ewfd.neff', ...
    'dataset', datasetTag, ...
    'solnum', 'all', ...
    'Complexout', 'on');
```

---

## Step 4: Extract all returned modes

For mode-analysis studies, the validation should read all returned modes, not only the first mode.

Recommended extraction pattern:

```matlab
neff_all = mphglobal(model, 'ewfd.neff', ...
    'dataset', cfg.datasetTag, ...
    'solnum', 'all', ...
    'Complexout', 'on');
```

Then inspect:

```matlab
real(neff_all)
imag(neff_all)
```

A useful diagnostic table is:

```text
mode_index    real_neff    imag_neff    loss_dB_per_cm    Q_est
```

The exact number of returned modes is controlled by the COMSOL mode-analysis study setting.

If only one mode is returned, check whether the number of modes requested in COMSOL is too small.

---

## Step 5: Estimate loss and Q for screening

For an optical mode with:

```text
neff = real(neff) + i imag(neff)
```

and free-space wavelength:

```text
lambda0
```

use:

```matlab
k0 = 2*pi/lambda0_m;
alpha_power_per_m = 2*k0*abs(imag(neff_all));
loss_dB_per_m = 10*log10(exp(1))*alpha_power_per_m;
loss_dB_per_cm = loss_dB_per_m/100;
Q_est = real(neff_all)./(2*abs(imag(neff_all)));
```

This is a screening estimate. For final quantitative loss or Q analysis, confirm the eigenvalue convention and use the appropriate group index if needed.

---

## Step 6: Inspect field profiles

Scalar values alone are not enough.

For the representative geometry, inspect the field profiles in COMSOL GUI or by MATLAB field interpolation.

At minimum, check:

```text
|E| distribution
Ex, Ey, Ez components if TE/TM character matters
field localization inside the waveguide core
field leakage into substrate, cladding, or PML
```

A physically useful bound mode should usually have:

```text
reasonable real(neff)
small imag(neff) or low loss
large confinement in the intended waveguide region
no dominant field inside the PML
smooth and interpretable mode shape
```

If several modes satisfy the scalar threshold, do not decide only by mode index. Use field shape and later mode-family tracking.

---

## Step 7: Optional small-perturbation check

Before launching the full sweep, run two or three nearby points manually.

Example:

```matlab
w_test_um = [1.15, 1.20, 1.25];
```

For each point, check whether the candidate mode changes smoothly.

Useful quantities are:

```text
real(neff)
imag(neff)
loss_dB_per_cm
Q_est
field profile
region-integral confinement metric, if available
```

A suspicious result may show:

```text
sudden jump in real(neff)
sudden jump in loss
mode index changes without physical reason
field moves into PML or substrate
accepted mode disappears at only one nearby point
```

This step is not full mode-family tracking. It is only a sanity check before the expensive sweep.

---

## Step 8: Decide whether the model is ready for sweep

Use the following decision table.

| Check | Pass condition | If failed |
|---|---|---|
| LiveLink connection | MATLAB can call COMSOL | fix environment first |
| model path | `.mph` file is found | fix repo path or file location |
| study run | mode-analysis study finishes | debug COMSOL model in GUI |
| result extraction | `ewfd.neff` can be extracted | check expression, dataset, solnum |
| mode count | several modes can be returned if needed | increase number of modes in COMSOL |
| scalar sanity | at least one plausible candidate mode | check material, geometry, boundary, search shift |
| field profile | candidate mode is localized in target region | reject PML/substrate/radiation mode |
| nearby-point check | candidate changes smoothly | use more diagnostics before sweep |

Only when the important checks pass should the user proceed to:

```text
cases/case_002_waveguide_width_sweep.md
```

---

## Recommended output

The validation run should save local outputs similar to:

```text
local_outputs/
└── validation_single_geometry_YYYYMMDD_HHMMSS/
    ├── validation_config.mat
    ├── validation_result.mat
    ├── validation_modes.csv
    └── validation_notes.md
```

The generated `local_outputs` folder should not be committed to GitHub by default.

The saved metadata should include:

```text
model path
study tag
dataset tag
parameter values
result expressions
number of returned modes
runtime
COMSOL/MATLAB version if convenient
```

---

## Expected outcome

After completing this case, the user should know:

1. whether MATLAB can control the COMSOL model;
2. whether the model path and COMSOL tags are correct;
3. whether the study can run for one representative geometry;
4. whether all returned modes can be extracted;
5. whether at least one returned mode is physically plausible;
6. whether scalar metrics and field profiles are consistent;
7. whether the model is ready for a full parameter sweep.

The correct outcome is not necessarily a successful mode. A failed validation is also useful if it prevents a large invalid sweep.

---

## AI validation prompt

Use the following prompt to test whether an AI assistant can handle this case from zero.

```text
You are given this COMSOL MATLAB LiveLink repository. Start from AGENTS.md and Case 001.
Explain the validation workflow that should be completed before launching a parameter sweep.
Then write or modify a MATLAB script that loads one example .mph model, runs one mode-analysis study, extracts all values of ewfd.neff, estimates loss_dB_per_cm and Q_est, saves the raw mode table, and lists the checks required before continuing to Case 002.
Do not assume solnum = 1 is the target mode.
Do not launch a full parameter sweep.
```

A good AI answer should:

```text
read AGENTS.md first
avoid assuming the first returned mode is correct
check model path, study tag, dataset tag, and result expression
extract solnum = all
save raw mode-level data
separate validation from sweep
recommend field-profile inspection
warn about PML-localized and substrate modes
provide clear pass/fail criteria
```

A weak AI answer would:

```text
only run solnum = 1
skip field-profile validation
immediately launch a full parameter sweep
ignore PML modes
overwrite old outputs
fail to save raw results
hide all user-editable settings inside the code body
```

---

## Common failure modes

### MATLAB cannot connect to COMSOL

Likely causes:

```text
COMSOL server not running
MATLAB was not launched through COMSOL Multiphysics with MATLAB
missing mli path
wrong COMSOL version
license issue
```

Fix the environment before debugging the model.

### The `.mph` file cannot be found

Likely causes:

```text
example model was not committed
model is stored outside the repo
script is being run from the wrong folder
relative path assumption is wrong
```

Use an explicit `modelPath` first, then generalize the path logic later.

### Study tag is wrong

Likely causes:

```text
COMSOL study is not named std1
model has several studies
study was copied and renamed
```

Check the tag in COMSOL Model Builder and update the MATLAB script.

### `ewfd.neff` cannot be extracted

Likely causes:

```text
wrong physics tag
wrong dataset tag
study did not generate the expected solution
expression is not available for that dataset
solnum setting is wrong
```

First test `mphglobal(model, 'ewfd.neff')` without extra options, then add dataset and solnum options once the expression is confirmed.

### All modes look lossy

Possible causes:

```text
PML is too close or too aggressive
search shift is far from the guided mode
geometry is not guiding at this wavelength
material index is wrong
mesh is too coarse
boundary condition is wrong
```

Do not fix this by loosening the threshold only. Inspect the field profile first.

### A low-loss mode is not the target mode

Possible causes:

```text
substrate mode
slab mode
PML-related numerical mode
wrong polarization family
higher-order guided mode
```

Use field localization, region integrals, and mode-family tracking before accepting it as the target mode.

---

## Notes for later modules

This case intentionally does not solve:

```text
TE/TM classification
mode-family tracking
field-overlap matching
branch stitching
parallel COMSOL jobs
optimization loops
```

Those tasks should be introduced only after the single-geometry validation and basic all-mode extraction workflow are reliable.
