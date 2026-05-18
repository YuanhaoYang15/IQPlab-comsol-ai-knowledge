# Expected COMSOL Model Variables for Module 06

The Module 06 MATLAB templates assume a 2D axisymmetric optical mode model with the following tags, parameters, and result expressions.

## Recommended Tags

```text
study tag:        std1
mode feature tag: mode
dataset tag:      dset1
physics tag:      ewfd
```

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
```

Units are expected to be set by MATLAB using strings such as `1.55[um]` or `60[deg]` where appropriate.

## Required Field Expressions

```text
ewfd.neff
ewfd.Er
ewfd.Ez
ewfd.Ephi
ewfd.Hr
ewfd.Hz
ewfd.normE
```

## Required Mode-Family Diagnostics

```text
TEfrac
TMfrac
```

The exact definitions can be model-specific, but they should return one value per solved mode and should be consistent with the intended TE-like and TM-like classification.

## Radius-Average Expression

The template tries the following expressions in order:

```text
ewfd.rAverage
ewfd.raverage
rAverage
raverage
Radius
```

`ewfd.rAverage` or an equivalent model-defined expression is preferred. The fallback to `Radius` is only a convenience and should be checked carefully.

## Minimal MATLAB Sanity Checks

After saving the `.mph` example, run checks similar to:

```matlab
model = mphload('LN_ridge_2dsym_single_waveguide_example.mph');
model.study('std1').feature('mode').set('neigs', '4');
model.study('std1').run;

neff = mphglobal(model, 'ewfd.neff', ...
    'dataset', 'dset1', 'solnum', 'all', 'Complexout', 'on');

TEfrac = mphglobal(model, 'TEfrac', ...
    'dataset', 'dset1', 'solnum', 'all');

TMfrac = mphglobal(model, 'TMfrac', ...
    'dataset', 'dset1', 'solnum', 'all');
```

If these expressions fail, update either the model variable names or the template configuration before using Module 06.
