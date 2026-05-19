# Expected COMSOL Model Variables for Module 07

The Module 07 Ring QPM templates assume a 2D axisymmetric optical mode-analysis model with the following tags, parameters, and result expressions.

This example model is reused from the Module 06 single-waveguide coupled-Q example, so most of the required interface is shared.

## Recommended Tags

```text
study tag:        std1
mode feature tag: mode
dataset tag:      dset1
physics tag:      ewfd
```

The Module 07 helper normally uses `dset1` when present. If `dset1` is not present, it falls back to the last available dataset.

## Required Global Parameters

```text
Radius      ring reference radius
w_center    active waveguide center radius
w_ln        active waveguide top width
t_ln        lithium-niobate film thickness
t_ridge     etched ridge height
w_pml       PML width
theta       ridge sidewall angle
w_sub       radial computational-window width or substrate span
t_sio2      SiO2 layer thickness
t_air       air-cladding thickness
wavelength  optical wavelength
ne          LN extraordinary refractive index
no          LN ordinary refractive index
n_sio2      SiO2 refractive index
nref        mode-search reference index
Ravg        optional radius/reference-radius parameter
rAverage    optional radius-average parameter or diagnostic fallback
```

MATLAB sets dimensional values using unit strings such as:

```text
50[um]
1.55[um]
60[deg]
```

## Required Mode Results

```text
ewfd.neff
TEfrac
TMfrac
```

`TEfrac` and `TMfrac` must return one value per solved mode. Their exact definitions are model-specific, but they should consistently identify the intended TE-like and TM-like mode families.

## Recommended Radius-Average Expressions

The Module 07 code tries to read radius-average information using:

```text
ewfd.rAverage
ewfd.raverage
rAverage
raverage
Radius
```

`ewfd.rAverage` or an equivalent model-defined expression is preferred. The fallback to `Radius` is acceptable for a quick teaching run, but it should be treated as a diagnostic fallback rather than proof that the curvature/radius correction is physically validated.

## Minimal MATLAB Sanity Check

After copying the example `.mph` into `templates/ring_qpm/models/`, run a one-geometry test before any large sweep:

```matlab
model = mphload('LN_ridge_ring_qpm_2dsym_single_waveguide_example.mph');
model.study('std1').feature('mode').set('neigs', '6');
model.study('std1').run;

neff = mphglobal(model, 'ewfd.neff', ...
    'dataset', 'dset1', 'solnum', 'all', 'Complexout', 'on');

TEfrac = mphglobal(model, 'TEfrac', ...
    'dataset', 'dset1', 'solnum', 'all');

TMfrac = mphglobal(model, 'TMfrac', ...
    'dataset', 'dset1', 'solnum', 'all');
```

If these expressions fail, update either the model variables or the Module 07 template configuration before trusting the result.

## Module 07 Validation Reminders

Do not assume `solnum = 1` is the desired mode. Save and inspect all returned modes, then select the desired TM-like or TE-like branch using Q and mode-fraction diagnostics.

For the first single-geometry run, check both the 1550 nm IR branch and the mapped 775 nm SH branch. A smooth `Dint` curve is useful evidence of continuity, but it does not by itself prove that the physical mode character has not changed near a crossing.
