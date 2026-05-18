# Case 002 — Waveguide Width Sweep with Bound-Mode Diagnostics

## Purpose

This case demonstrates how to use MATLAB LiveLink to sweep a waveguide-width parameter in a COMSOL optical mode-analysis model.

The case has two complementary goals:

1. use `imag(neff)` to estimate propagation loss and filter acceptable bound modes;
2. compare predefined integral quantities, such as `frac_E2_LN`, with `imag(neff)` as possible bound-mode indicators.

The example is intentionally simple. It focuses on result handling and mode screening, not on TE/TM classification or mode-family tracking.

---

## Related files

```text
docs/matlab_livelink_parameter_sweep.md

templates/livelink_parameter_sweep_bound_modes.m
templates/livelink_parameter_sweep_with_integral.m
templates/livelink_parameter_sweep_postprocess.m
```

The scripts assume a COMSOL model similar to:

```text
examples/LN_ridge_waveguide_Zcut.mph
```

The actual `.mph` file may be omitted from the GitHub repository if it is too large or not intended for public release.

---

## Physical example

The swept parameter is the waveguide width:

```matlab
cfg.paramName = 'w_ln';
cfg.paramUnit = 'um';
cfg.wList_um  = linspace(0.8, 1.4, 13);
```

At each width point, COMSOL solves a mode-analysis study and returns several candidate modes.

The important point is:

> The first returned mode is not always the desired physical bound mode.

Therefore, the workflow should read all returned modes and inspect or filter them.

---

## COMSOL-side preparation

Before running the MATLAB scripts, check the COMSOL model.

### Required settings

The model should contain:

```text
1. A global parameter for waveguide width
   Example: w_ln

2. A mode-analysis study
   Example tag: std1

3. A result dataset for the solved modes
   Example tag: dset1

4. The optical mode variable
   ewfd.neff
```

### Number of modes

The number of modes to solve should be set in the COMSOL mode-analysis study.

For this case, it is usually better to request several modes instead of only one mode, for example:

```text
number of modes = 4, 6, 8, or larger
```

The exact value depends on the geometry, wavelength, and expected number of guided or weakly guided modes.

### Optional predefined integral variable

For the all-mode integral diagnostic script, the COMSOL model should also define a scalar variable such as:

```text
frac_E2_LN
```

A typical meaning is:

```text
electric-field energy fraction inside the lithium-niobate waveguide region
```

The exact definition depends on the model. The key requirement is that the expression can be evaluated by `mphglobal` for every returned mode.

---

## Script 1: Bound-mode sweep

Use:

```text
templates/livelink_parameter_sweep_bound_modes.m
```

This script is for threshold-based mode selection.

At every waveguide width, it should:

```text
1. set the width parameter;
2. run the mode-analysis study;
3. read all returned values of ewfd.neff;
4. estimate loss from imag(neff);
5. estimate Q_est from real(neff) and imag(neff);
6. apply a loss or Q threshold;
7. save raw and accepted modes.
```

Example threshold settings:

```matlab
cfg.useLossThreshold  = true;
cfg.maxLoss_dB_per_cm = 10;

cfg.useQThreshold = false;
cfg.minQ_est      = 1e5;
```

This script should save a folder similar to:

```text
local_outputs/
└── waveguide_width_bound_mode_sweep_YYYYMMDD_HHMMSS/
    ├── sweep_config.mat
    ├── sweep_raw.mat
    ├── sweep_summary.csv
    └── sweep_all_modes.csv
```

---

## Script 2: All-mode integral sweep

Use:

```text
templates/livelink_parameter_sweep_with_integral.m
```

This script is for diagnostic all-mode data extraction.

It should:

```text
1. set the width parameter;
2. run the mode-analysis study;
3. read all returned modes using solnum = 'all';
4. extract ewfd.neff for every mode;
5. extract predefined integral quantities, such as frac_E2_LN, for every mode;
6. save all mode-level results;
7. not filter modes;
8. not make plots.
```

Example expression list:

```matlab
cfg.resultExprList = {
    'ewfd.neff'
    'frac_E2_LN'
};
```

This script should save a folder similar to:

```text
local_outputs/
└── waveguide_width_sweep_with_integral_all_modes_YYYYMMDD_HHMMSS/
    ├── sweep_config.mat
    ├── sweep_raw.mat
    ├── sweep_all_modes.csv
    └── sweep_point_summary.csv
```

The purpose is to examine whether `frac_E2_LN` behaves like a bound-mode indicator.

---

## Script 3: Post-processing

Use:

```text
templates/livelink_parameter_sweep_postprocess.m
```

This script should not run COMSOL. It should only load saved data.

The user should manually choose the result format in the configuration block:

```matlab
cfgPost.resultFormat = 'bound_modes';
```

or:

```matlab
cfgPost.resultFormat = 'integral_all_modes';
```

Recommended options:

```text
'bound_modes'
    Plot and summarize threshold-filtered bound-mode results.

'integral_all_modes'
    Plot and summarize all-mode integral diagnostic results.

'integral_single_mode'
    Support older single-mode integral results.

'auto'
    Infer the result format from the saved MAT file.
```

For teaching and debugging, manual selection is clearer than fully automatic dispatch.

---

## Recommended diagnostic plots

For `bound_modes`, useful plots are:

```text
selected real(neff) versus waveguide width
selected loss versus waveguide width
all returned modes with accepted modes highlighted
```

For `integral_all_modes`, useful plots are:

```text
all returned real(neff) versus waveguide width
all returned loss versus waveguide width
loss versus frac_E2_LN
frac_E2_LN versus waveguide width
```

The most important diagnostic comparison is:

```text
low loss from imag(neff)
        versus
large field fraction in the target region
```

If both indicators select the same modes, `frac_E2_LN` can be used as an additional bound-mode sanity check.

---

## Interpretation guidelines

A physically useful bound mode should usually satisfy several checks:

```text
1. real(neff) is in a reasonable range.
2. imag(neff) is small.
3. estimated loss is below the chosen threshold.
4. Q_est is sufficiently high.
5. the field is localized in the intended waveguide region.
6. predefined region fraction, such as frac_E2_LN, is large.
7. results change smoothly with waveguide width.
```

This case focuses on items 1鈥? and introduces item 6 as a diagnostic.
Component-ratio-based mode-family identification and overlap-based verification
are handled next in Module 05 and `cases/case_003_mode_family_identification.md`.

---

## Common failure modes

### No acceptable mode is found

Possible causes:

```text
loss threshold too strict
wrong PML setting
wrong wavelength or material index
mode-analysis search shift is far from the target mode
number of modes is too small
```

### Too many modes are accepted

Possible causes:

```text
loss threshold too loose
several physical modes exist
substrate or slab modes have similar loss
mode family has not been classified yet
```

### `frac_E2_LN` is missing

Possible causes:

```text
the variable is not defined in the COMSOL model
the integration operator has a different name
the expression does not evaluate for all modes
the dataset or solnum setting is wrong
```

### `frac_E2_LN` and loss disagree

Possible causes:

```text
field fraction is not normalized as expected
the selected region is too large or too small
PML modes still have non-negligible field in the region
the mode is weakly confined but not fully unphysical
```

This disagreement is useful information. It means the bound-mode criterion should not rely on only one scalar metric.

---

## Expected outcome

After running this case, the user should understand:

```text
1. why parameter sweeps in mode analysis require all-mode extraction;
2. how imag(neff) can be converted into a loss screening metric;
3. how a loss or Q threshold can select acceptable bound modes;
4. why raw mode-level data should be saved before final selection;
5. how predefined integral quantities can help diagnose mode confinement;
6. why plotting should be handled in a separate post-processing script.
```

