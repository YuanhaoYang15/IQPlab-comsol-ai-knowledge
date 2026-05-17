# MATLAB LiveLink Parameter Sweep with Bound-Mode Filtering

This note introduces a practical MATLAB LiveLink workflow for COMSOL mode-analysis parameter sweeps.

The example task is:

> Sweep the waveguide width and extract acceptable bound optical modes based on the imaginary part of the effective index.

The key point is that a parameter sweep is not only a `for` loop. For mode analysis, each run may return several eigenmodes, and not all of them are physically useful bound modes. Therefore, before using the extracted effective index as a sweep result, the script should first read all returned modes and filter them using a loss or Q threshold.

## Why MATLAB sweep instead of only COMSOL GUI sweep?

COMSOL provides GUI-based parametric sweeps, which are convenient for simple cases. However, MATLAB-based sweeps are often better for research workflows because they allow:

- customized sweep logic;
- flexible threshold-based mode filtering;
- extraction of all returned eigenmodes after each run;
- saving raw mode data before selecting a final mode;
- changing loss or Q thresholds later without rerunning COMSOL;
- adding custom post-processing, plotting, and debugging logic.

## Core workflow

The recommended workflow is:

1. Load a COMSOL model.
2. Set the number of modes to solve in the mode-analysis study.
3. Define the waveguide-width sweep list in MATLAB.
4. For each waveguide width:
   - update the COMSOL global parameter using `model.param.set`;
   - run the mode-analysis study;
   - read all returned effective indices using `mphglobal`;
   - compute an equivalent propagation loss from `imag(neff)`;
   - estimate a propagation-limited Q from `imag(neff)`;
   - select acceptable modes using a loss or Q threshold;
   - sort accepted modes by `real(neff)`;
   - save all raw modes and accepted modes.
5. Post-process the saved results without rerunning COMSOL.

## Bound-mode filtering from the imaginary part of effective index

For a mode with

```text
neff = real(neff) + i imag(neff)
```

and free-space wavelength `lambda0`, the propagation constant is

```text
beta = k0 neff
k0 = 2 pi / lambda0
```

Assuming the field amplitude evolves as

```text
E(z) ~ exp(i beta z)
```

the power attenuation coefficient can be estimated as

```text
alpha_power = 2 k0 abs(imag(neff))
```

where `alpha_power` has units of `1/m` if `lambda0` is given in meters.

The corresponding propagation loss is

```text
loss_dB_per_m = 10 log10(e) alpha_power
loss_dB_per_cm = loss_dB_per_m / 100
```

A simple Q estimate is

```text
Q_est = real(neff) / (2 abs(imag(neff)))
```

This is equivalent to using the phase index as an approximation to the group index. If the group index is available, a more appropriate estimate is

```text
Q_est = ng / (2 abs(imag(neff)))
```

In this teaching module, `Q_est = real(neff)/(2 abs(imag(neff)))` is used as a compact screening metric. For final publication-quality loss or Q analysis, verify the eigenvalue convention, the group index definition, and the normalization used by the COMSOL model.

## Why read all modes?

A mode-analysis study usually returns multiple eigenmodes. During a geometry sweep, the ordering of returned modes may change. Therefore, it is risky to read only `solnum = 1` and assume it is always the desired physical mode.

Instead, the sweep script should read all returned modes:

```matlab
neff_all = mphglobal(model, 'ewfd.neff', ...
    'dataset', cfg.datasetTag, ...
    'solnum', 'all', ...
    'complexout', 'on');
```

Then the script can compute loss and Q for each mode, apply thresholds, and keep all accepted modes.

## Number of modes to solve

For mode analysis, the number of modes should be large enough to include the desired bound mode and nearby competing modes. If it is too small, the desired mode may disappear from the returned list when parameters change.

A typical starting point is:

```matlab
cfg.numModes = 6;
```

The exact LiveLink command for setting the number of modes depends on the study-step tag in the COMSOL model. A common pattern is:

```matlab
model.study('std1').feature('mode').set('neigs', num2str(cfg.numModes));
```

However, the study-step tag may not be `mode` in every model. The template script therefore keeps the study-step tag as a user-editable setting:

```matlab
cfg.modeStudyFeatureTag = 'mode';
```

If this tag does not match the model, the script will still run if the number of modes has already been configured in the COMSOL GUI.

## Recommended saving strategy

For each sweep point, save:

- the swept parameter value;
- all returned `neff` values;
- all computed losses;
- all estimated Q values;
- the indices of accepted modes;
- the accepted modes sorted by `real(neff)`;
- error messages if the sweep point fails.

This allows the user to change thresholds later during MATLAB post-processing without rerunning COMSOL.

Avoid saving dense field profiles for every sweep point unless the field distribution itself is required. If field data are needed only to compute compact quantities, extract the fields during each run, compute the desired scalar values, and save only those scalar results.

## Single-model integrals versus cross-model overlap

For quantities that depend only on one solution in one COMSOL model, such as mode energy in a selected domain, field fraction, or a predefined integral over a fixed region, it is usually convenient to define the integration operators and variables directly in the COMSOL model. MATLAB can then extract these compact scalar quantities using `mphglobal` after each run.

For overlap integrals involving fields from different models, different geometries, or different meshes, it is usually easier and more transparent to export the relevant field components to MATLAB using `mphinterp`, interpolate them onto a common grid, normalize them, and compute the overlap integral in MATLAB. In that case, the full field data do not need to be saved for every sweep point; usually only the processed overlap value should be saved.

## Files in this module

Recommended repo-aligned files:

```text
docs/
└── matlab_livelink_parameter_sweep.md

templates/
├── livelink_parameter_sweep_bound_modes.m
├── livelink_parameter_sweep_postprocess.m
└── livelink_parameter_sweep_with_integral.m

cases/
└── case_002_waveguide_width_bound_mode_sweep.md
```

The main teaching script is:

```text
templates/livelink_parameter_sweep_bound_modes.m
```
