# Case 002 — Waveguide Width Sweep with Bound-Mode Filtering

This case demonstrates a practical mode-analysis sweep:

> Sweep the waveguide width and track acceptable bound modes using loss or Q thresholds.

## Motivation

A mode-analysis study can return several modes at each geometry point. During a parameter sweep, the ordering of modes may change, and some returned modes may be leaky or PML-like. Therefore, using only `solnum = 1` is not robust.

This case uses the imaginary part of `ewfd.neff` to estimate propagation loss and Q, then selects acceptable modes using user-defined thresholds.

## Model

Example model path:

```text
examples/LN_ridge_waveguide_Zcut.mph
```

The script assumes the waveguide width is controlled by the COMSOL global parameter:

```text
w_ln
```

If the model uses a different parameter name, edit:

```matlab
cfg.paramName = 'w_ln';
```

in:

```text
templates/livelink_parameter_sweep_bound_modes.m
```

## Sweep parameter

Default sweep:

```matlab
cfg.wList_um = linspace(0.8, 1.4, 13);
```

## Extracted result

The script reads all returned effective indices:

```matlab
neff_all = mphglobal(model, 'ewfd.neff', ...
    'dataset', cfg.datasetTag, ...
    'solnum', 'all', ...
    'complexout', 'on');
```

Then it computes:

```text
loss_dB_per_cm
Q_est
```

from the imaginary part of `neff`.

## Bound-mode selection

Default selection:

```matlab
cfg.useLossThreshold  = true;
cfg.maxLoss_dB_per_cm = 10;

cfg.useQThreshold = false;
cfg.minQ_est      = 1e5;
```

Accepted modes are sorted by decreasing `real(neff)`.

TE/TM classification is intentionally not included in this case. It should be handled later using field-component fractions or region-integral diagnostics.

## Output

The script writes results to:

```text
local_outputs/
└── waveguide_width_bound_mode_sweep_YYYYMMDD_HHMMSS/
    ├── sweep_config.mat
    ├── sweep_raw.mat
    └── sweep_summary.csv
```

The `local_outputs` directory should not be committed to GitHub.

## Post-processing

Run:

```text
templates/livelink_parameter_sweep_postprocess.m
```

to reload the raw sweep result, change thresholds, and regenerate plots without rerunning COMSOL.
