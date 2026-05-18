# MATLAB LiveLink Parameter Sweep with Bound-Mode Filtering

This note introduces a practical MATLAB LiveLink workflow for COMSOL mode-analysis parameter sweeps.

The example task is:

> Sweep the waveguide width, solve multiple optical modes at each sweep point, estimate propagation loss from `imag(neff)`, and save reusable mode-level results for later post-processing.

The key point is that a parameter sweep is not only a `for` loop. In a mode-analysis study, each run may return several eigenmodes, and not all returned modes are physically useful bound modes. Therefore, before using the effective index as a sweep result, the workflow should read all returned modes and either:

1. filter acceptable bound modes using a loss or Q threshold; or
2. save all returned modes together with diagnostic quantities, such as `frac_E2_LN`, for later inspection.

---

## Why use MATLAB sweep instead of only COMSOL GUI sweep?

COMSOL provides GUI-based parametric sweeps, which are convenient for simple cases. However, MATLAB-controlled sweeps are often more useful for research workflows because they allow:

- customized sweep logic;
- explicit control of parameter updates through `model.param.set`;
- extraction of all returned eigenmodes after each run;
- threshold-based bound-mode filtering;
- checkpoint saving after every sweep point;
- saving raw mode data before selecting a final mode;
- changing loss or Q thresholds later without rerunning COMSOL;
- customized post-processing and plotting.

The recommended workflow is:

```text
Run expensive COMSOL simulations once
        ↓
Save raw mode-level results
        ↓
Post-process many times in MATLAB
        ↓
Avoid rerunning COMSOL unless the model or sweep parameters change
```

---

## Recommended Module 04 scripts

This module uses three MATLAB templates.

```text
templates/
├── livelink_parameter_sweep_bound_modes.m
├── livelink_parameter_sweep_with_integral.m
└── livelink_parameter_sweep_postprocess.m
```

### `livelink_parameter_sweep_bound_modes.m`

This is the main bound-mode filtering template.

It should:

1. load one COMSOL mode-analysis model;
2. sweep the waveguide width;
3. run the mode-analysis study at each width;
4. read all returned values of `ewfd.neff`;
5. convert `imag(neff)` to an estimated propagation loss;
6. estimate a rough Q metric from `real(neff)` and `imag(neff)`;
7. select acceptable bound modes using user-defined thresholds;
8. sort accepted modes, for example by descending `real(neff)`;
9. save both raw mode data and accepted-mode results.

This script is useful when the goal is to obtain a clean selected mode branch after each parameter point.

### `livelink_parameter_sweep_with_integral.m`

This is a diagnostic all-mode integral template.

It should:

1. load the same COMSOL mode-analysis model;
2. sweep the waveguide width;
3. read all returned modes using `solnum = 'all'`;
4. extract `ewfd.neff` and predefined scalar/integral quantities for every mode;
5. save all mode-level results;
6. not filter bound modes;
7. not make plots.

This script is useful for testing whether predefined integral quantities can serve as bound-mode indicators. For example, one can compare:

```text
imag(neff)
loss_dB_per_cm
Q_est
frac_E2_LN
```

A useful diagnostic question is:

> Does a large `frac_E2_LN` select the same physically bound modes as a small `imag(neff)` or low propagation loss?

The run script should only save results. Plotting and interpretation should be handled by the post-processing script.

### `livelink_parameter_sweep_postprocess.m`

This script should not run COMSOL. It should only load saved results and make plots or summary tables.

The recommended design is to let the user manually select the result format in the user-configuration block:

```matlab
cfgPost.resultFormat = 'integral_all_modes';
```

Recommended options are:

```text
'bound_modes'
    Post-process results from livelink_parameter_sweep_bound_modes.m.

'integral_all_modes'
    Post-process all-mode integral results from livelink_parameter_sweep_with_integral.m.

'integral_single_mode'
    Post-process older single-mode integral results saved as valueMat.

'auto'
    Infer the format from sweep_raw.mat. Useful for quick testing, but less clear for teaching.
```

For teaching material, manual selection is preferred over fully automatic dispatch because it makes the intended plotting logic explicit.

---

## Core parameter-sweep workflow

The basic loop is:

```matlab
for jj = 1:numel(cfg.wList_um)
    w_um = cfg.wList_um(jj);

    model.param.set(cfg.paramName, ...
        sprintf('%.12g[%s]', w_um, cfg.paramUnit));

    model.study(cfg.studyTag).run;

    neff_all = mphglobal(model, 'ewfd.neff', ...
        'dataset', cfg.datasetTag, ...
        'solnum', 'all', ...
        'Complexout', 'on');

    % Convert imag(neff) to loss.
    % Filter or save modes depending on the script.
end
```

The number of modes to solve should be configured in the COMSOL mode-analysis study. The exact LiveLink tag for this setting is model-dependent, so this module keeps the number-of-modes setting inside the `.mph` file.

---

## Bound-mode filtering from `imag(neff)`

For a mode with complex effective index,

```text
neff = real(neff) + i imag(neff)
```

and free-space wavelength `lambda0`, the propagation constant is:

```text
beta = k0 * neff
k0   = 2*pi/lambda0
```

Assuming the field amplitude evolves as:

```text
E(z) ~ exp(i*beta*z)
```

the power attenuation coefficient can be estimated as:

```text
alpha_power = 2*k0*abs(imag(neff))
```

where `alpha_power` has units of `1/m` if `lambda0` is given in meters.

The corresponding loss in dB/cm is:

```text
loss_dB_per_m  = 10*log10(exp(1))*alpha_power
loss_dB_per_cm = loss_dB_per_m/100
```

A rough propagation-limited Q screening metric is:

```text
Q_est = real(neff)/(2*abs(imag(neff)))
```

This `Q_est` uses `real(neff)` as a simple replacement for group index. It is useful as a screening metric, but for final quantitative analysis one should check the eigenvalue convention and use a more appropriate group index when necessary.

---

## Example threshold logic

The bound-mode script can select acceptable modes using either loss or Q:

```matlab
cfg.useLossThreshold  = true;
cfg.maxLoss_dB_per_cm = 10;

cfg.useQThreshold = false;
cfg.minQ_est      = 1e5;
```

The filtering logic is:

```matlab
valid = isfinite(real(neff_all)) & isfinite(imag(neff_all));

if cfg.useLossThreshold
    valid = valid & (loss_dB_per_cm_all <= cfg.maxLoss_dB_per_cm);
end

if cfg.useQThreshold
    valid = valid & (Q_est_all >= cfg.minQ_est);
end

accepted_idx = find(valid);
```

After filtering, accepted modes can be sorted by:

```text
real_neff_descend
loss_ascend
q_descend
```

A common first choice is to sort by descending `real(neff)`.

---

## Why save all raw modes?

Even if the final goal is a single mode branch, the script should save all returned modes first.

This is important because:

- the loss threshold may need to be changed later;
- the Q threshold may need to be changed later;
- the selected mode may jump if several modes have similar losses;
- different mode families may coexist in the same simulation window;
- diagnostic plots may reveal PML modes or substrate modes.

Therefore, the run script should save raw mode-level data before applying any final interpretation.

Recommended saved quantities for each sweep point include:

```text
w_um
success
message
runtime_s
neff_all
loss_dB_per_cm_all
Q_est_all
accepted_idx
selected_idx
```

---

## Direct scalar results, predefined integrals, and full fields

There are three common result types in parameter sweeps.

### 1. Direct scalar results

Examples:

```text
ewfd.neff
ewfd.dampzdB
eigenfrequency
```

Recommended method:

```text
Extract with mphglobal.
Save every sweep point.
```

### 2. Predefined scalar or integral results in one COMSOL model

Examples:

```text
frac_E2_LN
wg_energy_ratio
substrate_energy_ratio
TE_frac
TM_frac
```

These quantities depend only on one model and one solved mode. They are usually easiest to define inside the COMSOL model using integration operators, variables, or derived values. MATLAB can then extract them using `mphglobal`.

Recommended method:

```text
Define operators or variables in COMSOL.
Extract them with mphglobal.
Save compact scalar values for every returned mode.
```

This is the purpose of `livelink_parameter_sweep_with_integral.m`.

### 3. Dense field or vector results

Examples:

```text
Ex(x, y)
Ey(x, y)
Ez(x, y)
|E(x, y)|^2
```

Full field profiles can be read with `mphinterp`, but saving them for every sweep point can quickly generate large output files. For most sweeps, it is better to compute compact derived quantities immediately and save only the processed scalar results.

---

## Cross-model overlap integrals

If an overlap integral involves two fields from different models, different geometries, or different meshes, it is usually easier to compute the overlap in MATLAB.

Recommended workflow:

```text
model A: interpolate field A onto a common grid
model B: interpolate field B onto the same grid
        ↓
normalize the fields consistently
        ↓
compute the overlap integral in MATLAB
        ↓
save only the final scalar overlap
```

This is often more transparent than trying to construct a cross-model integral directly inside COMSOL.

---

## Recommended output folders

The run scripts should save results into `local_outputs/`, for example:

```text
local_outputs/
├── waveguide_width_bound_mode_sweep_YYYYMMDD_HHMMSS/
│   ├── sweep_config.mat
│   ├── sweep_raw.mat
│   ├── sweep_summary.csv
│   └── sweep_all_modes.csv
│
└── waveguide_width_sweep_with_integral_all_modes_YYYYMMDD_HHMMSS/
    ├── sweep_config.mat
    ├── sweep_raw.mat
    ├── sweep_all_modes.csv
    └── sweep_point_summary.csv
```

These generated output files should not be committed to the repository by default.

---

## Post-processing strategy

The post-processing script should be able to load a saved `sweep_raw.mat` file and then generate plots or summary tables without rerunning COMSOL.

For bound-mode results, useful plots include:

```text
selected real(neff) versus waveguide width
selected loss versus waveguide width
all returned modes with accepted modes highlighted
```

For all-mode integral results, useful plots include:

```text
all returned real(neff) versus waveguide width
all returned loss versus waveguide width
loss versus frac_E2_LN
frac_E2_LN versus waveguide width
```

The all-mode integral plots are intended for diagnosis, not final mode-family tracking.

---

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

