# Module 06 — 2D Axisymmetric Pulley Coupled-Q Analysis

## Purpose

This module documents a MATLAB LiveLink workflow for estimating the external or coupled quality factor `Qc` of a pulley-coupled microring resonator from a lightweight 2D axisymmetric COMSOL optical mode model.

The intended model is a single movable ridge waveguide in a 2D axisymmetric cross section. The same `.mph` model is solved twice:

1. once with the active waveguide centered at the ring radius;
2. once with the active waveguide centered at the bus-waveguide radius.

The ring and bus modes are then combined in MATLAB through a perturbative overlap integral over the bus ridge region. The script scans pulley coupling angle or coupling length and estimates `kappa^2` and `Qc`.

This module is intended for reproducible code organization and first-pass coupling design. Final design decisions should still be validated with more complete simulations or experiments when necessary.

---

## Related Files

```text
docs/livelink_coupled_q_2dsym.md
templates/livelink_coupled_q_2dsym_run.m
templates/livelink_coupled_q_2dsym_postprocess.m
templates/get_material_index_MgLN.m
cases/case_004_pulley_coupled_q_2dsym.md
examples/2dsym_single_waveguide_coupled_q/README.md
examples/2dsym_single_waveguide_coupled_q/expected_model_variables.md
```

The example `.mph` file should be added manually after cleaning the original local COMSOL file:

```text
examples/2dsym_single_waveguide_coupled_q/LN_ridge_2dsym_single_waveguide_example.mph
```

---

## Physical Idea

The method approximates the pulley coupling using two isolated single-waveguide modes:

- the ring mode, solved at radius `Radius` with width `w_ring`;
- the bus mode, solved at radius `R_bus_center` with width `w_bus`.

The ring field is sampled over the future bus region. The bus field is solved in the same single-waveguide model after moving the active waveguide center. The coupling strength is estimated from the permittivity perturbation associated with adding the bus ridge:

```text
Gamma = (omega / 4) * | integral(conj(E_ring) · Delta_epsilon · E_bus dA) |
        / sqrt(|P_ring P_bus|)
```

The phase mismatch is approximated as:

```text
DeltaBeta = neff_ring * k0 * Radius / R_bus_center - neff_bus * k0
```

For a coupling length `Lc`, the effective power coupling is estimated by:

```text
S_eff = sqrt((DeltaBeta/2)^2 + Gamma^2)
Phi   = Lc * S_eff
kappa^2 = |Gamma * Lc * sinc(Phi)|^2
```

The coupled Q is estimated using:

```text
Qc = 2*pi*neff_ring*L_ring / (lambda*kappa^2)
L_ring = 2*pi*Radius
```

All lengths in the calculation are converted to SI units where required.

---

## Required COMSOL Model Assumptions

The example `.mph` should already be validated in the COMSOL GUI. It should contain:

- a 2D axisymmetric optical mode analysis model;
- a single active lithium-niobate ridge waveguide;
- a PML or sufficiently large computational window;
- global parameters that MATLAB can modify;
- TE/TM diagnostic variables;
- a working study and dataset.

Recommended tags:

```text
study tag:   std1
mode tag:    mode
dataset tag: dset1
physics tag: ewfd
```

Required or recommended COMSOL parameters:

```text
Radius
w_center
w_ln
t_ln
t_ridge
w_pml
theta
w_sub
t_sio2
t_air
wavelength
ne
no
n_sio2
nref
```

Required COMSOL result expressions:

```text
ewfd.neff
ewfd.Er
ewfd.Ez
ewfd.Ephi
ewfd.Hr
ewfd.Hz
ewfd.normE
```

Required diagnostic expressions:

```text
TEfrac
TMfrac
```

Recommended radius-average expressions, tried in order by the template:

```text
ewfd.rAverage
ewfd.raverage
rAverage
raverage
Radius
```

---

## Workflow

### 1. Clean and save the example `.mph`

Starting from a known working local model, clean the result data and remove private paths. Save a lightweight example as:

```text
examples/2dsym_single_waveguide_coupled_q/LN_ridge_2dsym_single_waveguide_example.mph
```

The repository `.gitignore` allows small teaching `.mph` files under `examples/`.

### 2. Run the LiveLink calculation

Run:

```text
templates/livelink_coupled_q_2dsym_run.m
```

The script will:

1. load the example model;
2. generate ring, bus, and plot interpolation grids;
3. solve the ring-centered single-waveguide mode;
4. select a TE-like or TM-like bound ring mode;
5. sample ring fields on both ring and future bus regions;
6. solve the bus-centered single-waveguide mode;
7. select a TE-like or TM-like bound bus mode;
8. compute the overlap-based `Gamma`, `DeltaBeta`, `kappa^2`, and `Qc`;
9. save raw results and metadata to a timestamped folder under `local_outputs/`.

### 3. Run post-processing

Run:

```text
templates/livelink_coupled_q_2dsym_postprocess.m
```

This script loads the latest output folder by default and plots:

- `Qc` versus pulley angle;
- `kappa^2` versus pulley angle;
- a mode-selection summary table.

---

## Important Checks

Before trusting `Qc`, check:

1. The selected ring and bus modes are the intended TE/TM families.
2. `real(neff)` is reasonable for the wavelength and geometry.
3. The Q screening is only used to reject clearly leaky or PML-like modes.
4. The radius correction `neff_actual = neff_raw * rAverage / r_center` is appropriate for the model convention.
5. The ring field sampled over the bus region is not dominated by interpolation artifacts.
6. The bus-region mask matches the actual bus ridge geometry.
7. `kappa^2` remains in a physically reasonable weak-coupling range for the intended approximation.
8. `Qc` is not interpreted at angles where the perturbative approximation is no longer valid.

---

## Known Limitations

This module does not solve the full coupled ring-bus supermode problem. It uses isolated-mode fields and a perturbative overlap estimate. Therefore:

- it is best used for fast design scans and trend analysis;
- it may be inaccurate for very small gaps or strong hybridization;
- it does not capture all radiation or scattering effects of the full coupler;
- it depends on consistent field normalization and COMSOL eigenmode conventions;
- it should be cross-checked against full simulations or measured coupling when accuracy is critical.

---

## Output Data

The run script saves a timestamped output folder containing:

```text
coupled_q_raw.mat
coupled_q_summary.csv
coupled_q_config.mat
```

The raw `.mat` file contains:

```text
cfg
geom
select
target_wavelengths
theta_scan_vec
res_Qc
res_Kappa_sq
res_Gamma
res_DeltaBeta
res_neff_ring
res_neff_bus
res_Q_ring
res_Q_bus
res_TE_ring
res_TM_ring
res_TE_bus
res_TM_bus
modeSummaryTable
```

The CSV file is intended for quick inspection and records one row per wavelength.
