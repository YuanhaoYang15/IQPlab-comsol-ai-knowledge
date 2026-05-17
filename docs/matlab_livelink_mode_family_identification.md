# MATLAB LiveLink Mode-Family Identification and Overlap-Based Verification

Module 05 continues the optical mode-analysis workflow after Module 04.

Module 04 focuses on reading all returned modes and filtering clearly leaky modes using `imag(neff)`, propagation loss, or a Q-like metric. Module 05 focuses on distinguishing mode families among the remaining accepted modes and using field-overlap integrals to verify mode continuity near crossings or avoided crossings.

This module has two main goals:

1. **Mode-family classification**  
   COMSOL mode analysis returns eigenmodes, but it does not automatically provide a robust TE/TM or mode-family label in the same way that some dedicated optical mode solvers do. Therefore, the user often needs to classify modes from field-component metrics.

2. **Overlap-based verification**  
   Near a mode crossing or avoided crossing, scalar indicators such as `real(neff)`, `Ex_frac_xy`, or `Ey_frac_xy` may change rapidly or become ambiguous. Normalized field-overlap integrals provide a post-processing check for mode similarity between two neighboring sweep points.

---

## File structure

```text
docs/
└── matlab_livelink_mode_family_identification.md

templates/
├── livelink_mode_family_component_ratio.m
├── livelink_mode_family_component_postprocess.m
├── livelink_mode_family_overlap_check.m
└── livelink_mode_family_overlap_postprocess.m

cases/
└── case_003_mode_family_identification.md
```

The calculation scripts and post-processing scripts are intentionally separated.

---

## Key workflow principle

This module follows the same workflow principle as Module 04:

```text
expensive COMSOL solving / field extraction
        ↓
save compact raw and processed data
        ↓
cheap MATLAB post-processing
        ↓
change plots, thresholds, and interpretation without rerunning COMSOL
```

Therefore:

```text
component_ratio.m
    runs COMSOL and saves component-ratio data

component_postprocess.m
    loads saved component-ratio data and makes plots

overlap_check.m
    runs COMSOL for selected parameter pairs and saves overlap data

overlap_postprocess.m
    loads saved overlap data and makes overlap plots
```

---

## Part A — Component-ratio mode-family classification

### Purpose

The component-ratio workflow is used to classify accepted bound modes according to their field-component content.

For the current teaching model, the geometry is a standard 2D Cartesian waveguide cross-section. The relevant electric-field components are:

```text
ewfd.Ex
ewfd.Ey
ewfd.Ez
```

The script intentionally labels the modes as:

```text
Ex_dominant
Ey_dominant
hybrid_xy
```

instead of automatically calling them TE or TM. The mapping from `Ex_dominant` / `Ey_dominant` to TE-like / TM-like depends on the model coordinate convention and propagation direction.

---

## COMSOL-side requirement: number of modes

The number of solved modes should be controlled explicitly.

In the COMSOL mode-analysis study node, set the desired number of modes to a global parameter, for example:

```text
Nmode
```

Then the MATLAB script can control it from the configuration block:

```matlab
cfg.setNmodeParam = true;
cfg.NmodeParamName = 'Nmode';
cfg.Nmode = 10;
```

This avoids hidden dependence on a manually edited GUI value.

---

## COMSOL-side requirement: integration operator

The component-ratio script uses a COMSOL integration operator over the physical region used for mode classification. In the teaching model, the operator is:

```text
intop_LN_physical
```

The operator should integrate over the intended physical region, usually excluding PML domains.

The MATLAB script uses LiveLink to create or update a variable group, for example:

```text
var_mode_family
```

and defines the following variables inside COMSOL:

```text
mode_IEx = intop_LN_physical(abs(ewfd.Ex)^2)
mode_IEy = intop_LN_physical(abs(ewfd.Ey)^2)
mode_IEz = intop_LN_physical(abs(ewfd.Ez)^2)
```

Then it constructs:

```text
mode_Ixy  = mode_IEx + mode_IEy
mode_Ixyz = mode_IEx + mode_IEy + mode_IEz
```

and the component fractions:

```text
mode_Ex_frac_xy  = mode_IEx/mode_Ixy
mode_Ey_frac_xy  = mode_IEy/mode_Ixy
mode_Ex_frac_xyz = mode_IEx/mode_Ixyz
mode_Ey_frac_xyz = mode_IEy/mode_Ixyz
mode_Ez_frac_xyz = mode_IEz/mode_Ixyz
```

These quantities are read for all returned modes using:

```matlab
mphglobal(model, 'mode_IEx', ...
    'dataset', cfg.datasetTag, ...
    'solnum', 'all', ...
    'Complexout', 'on');
```

---

## Why use COMSOL integration variables for Part A?

For single-model, single-solution scalar metrics, it is usually cleaner to define integration variables in COMSOL and read them with `mphglobal`.

This is different from overlap verification. Component-ratio metrics such as `mode_IEx`, `mode_IEy`, and `mode_IEz` are scalar quantities for each mode in one model, so they are compact and easy to save.

Advantages:

```text
no manual interpolation grid needed
no large field arrays saved
PML exclusion can be handled by the integration operator
fast and compact output
easy to inspect variables in COMSOL GUI
```

---

## Bound-mode filtering before mode-family classification

Mode-family classification should not be applied blindly to every returned mode. The script first reads all modes, estimates loss and Q, and then filters accepted bound modes.

Example settings:

```matlab
cfg.useLossThreshold  = true;
cfg.maxLoss_dB_per_cm = 10;

cfg.useQThreshold = false;
cfg.minQ_est      = 1e5;
```

The script still reads all returned modes, but the main output contains accepted modes only.

Main output:

```text
mode_family_metrics.csv
```

Optional debugging output:

```text
mode_family_all_modes.csv
```

The debugging output can be enabled with:

```matlab
cfg.saveAllModesCsv = true;
```

---

## Component-ratio labels

For each accepted mode, define:

```text
IEx = ∫ |Ex|² dA
IEy = ∫ |Ey|² dA
IEz = ∫ |Ez|² dA
```

and:

```text
Ex_frac_xy = IEx/(IEx + IEy)
Ey_frac_xy = IEy/(IEx + IEy)
```

A simple label rule is:

```text
Ex_frac_xy > threshold  → Ex_dominant
Ey_frac_xy > threshold  → Ey_dominant
otherwise               → hybrid_xy
```

The default threshold can be:

```matlab
cfg.minDominantFraction = 0.80;
```

This threshold is a classification heuristic, not a fundamental physical constant.

---

## Part A scripts

### Run script

```text
templates/livelink_mode_family_component_ratio.m
```

This script:

```text
1. loads the COMSOL model;
2. defines LiveLink-generated integration variables;
3. sets Nmode;
4. sweeps the waveguide width;
5. reads all returned modes;
6. estimates loss and Q;
7. filters accepted modes;
8. computes component-ratio labels;
9. saves accepted-mode and optional all-mode tables.
```

It does not make plots.

Recommended output folder:

```text
local_outputs/
└── mode_family_component_ratio_YYYYMMDD_HHMMSS/
    ├── mode_family_config.mat
    ├── mode_family_raw.mat
    ├── mode_family_metrics.csv
    ├── mode_family_all_modes.csv
    └── sweep_point_summary.csv
```

### Post-processing script

```text
templates/livelink_mode_family_component_postprocess.m
```

This script loads saved component-ratio data and makes plots. It does not run COMSOL.

Useful plots include:

```text
real(neff) versus width, colored by Ex_frac_xy
real(neff) versus width, colored by Ey_frac_xy
loss versus width
Ex_frac_xy and Ey_frac_xy versus width
mode branches grouped by family_label
```

The user can choose whether to plot accepted modes or all modes:

```matlab
cfgPost.tableMode = 'accepted';
```

or:

```matlab
cfgPost.tableMode = 'all';
```

---

## Part B — Overlap-based verification near crossings

### Purpose

The overlap workflow is used only for selected parameter pairs, especially near crossings or avoided crossings.

Unlike component-ratio metrics, overlap verification requires the actual field profiles from two different parameter points. Therefore, this part uses `mphinterp` to read fields on a common grid.

The normalized overlap between mode `m` at the previous parameter point and mode `n` at the current parameter point is:

```text
O_mn =
|∫ conj(E_m(previous)) · E_n(current) dA|²
/
[∫ |E_m(previous)|² dA · ∫ |E_n(current)|² dA]
```

where:

```text
E = [Ex, Ey, Ez]
```

The overlap is close to 1 when the two field profiles are very similar and close to 0 when they are very different.

---

## Filtering before overlap

The overlap script should not interpolate fields for every lossy returned mode. It first applies the same loss/Q filtering logic and then interpolates fields only for selected accepted modes:

```matlab
cfg.onlyOverlapAcceptedModes = true;
```

This keeps the overlap matrix focused and reduces field-interpolation cost.

---

## Interpolation grid

The overlap script defines a common grid, for example:

```matlab
cfg.xList_um = linspace(-1.5, 1.5, 241);
cfg.yList_um = linspace(-0.2, 1.2, 181);
cfg.coordScaleToModel = 1e-6;
cfg.coordScaleToMeter = 1e-6;
```

For the current teaching model, the COMSOL geometry uses SI coordinates internally, so the micrometer grid is converted to meters before calling `mphinterp`.

If the model coordinate unit is different, `cfg.coordScaleToModel` should be changed accordingly.

---

## Part B scripts

### Run script

```text
templates/livelink_mode_family_overlap_check.m
```

This script:

```text
1. loads the COMSOL model;
2. defines the same LiveLink-generated integration variables;
3. sets Nmode;
4. solves the previous parameter value;
5. filters accepted modes;
6. interpolates fields for accepted modes;
7. solves the current parameter value;
8. filters accepted modes;
9. interpolates fields for accepted modes;
10. computes the overlap matrix;
11. saves overlap results.
```

It does not make plots.

Recommended output folder:

```text
local_outputs/
└── mode_family_overlap_check_YYYYMMDD_HHMMSS/
    ├── overlap_config.mat
    ├── overlap_raw.mat
    ├── overlap_pairs.csv
    ├── overlap_matrix.csv
    ├── overlap_best_matches.csv
    ├── previous_modes.csv
    └── current_modes.csv
```

### Post-processing script

```text
templates/livelink_mode_family_overlap_postprocess.m
```

This script loads saved overlap results and makes plots. It does not run COMSOL.

Useful plots include:

```text
overlap matrix heatmap
best overlap versus previous mode index
pairwise neff comparison colored by overlap
```

The heatmap can be sorted by real effective index:

```matlab
cfgPost.heatmapSortMode = 'neff_descend';
```

In this mode, heatmap axis labels `1, 2, 3, ...` are sorted ranks:

```text
rank 1 = accepted mode with largest real(neff)
rank 2 = accepted mode with second largest real(neff)
...
```

The script also saves sorted mode-order files:

```text
overlap_prev_mode_order_sorted.csv
overlap_curr_mode_order_sorted.csv
overlap_matrix_sorted.csv
```

These files record the relationship between sorted rank, original COMSOL mode index, and `real(neff)`.

---

## How to choose parameter pairs for overlap

Overlap verification should usually be performed between neighboring or nearby sweep points, not two very distant endpoints.

Recommended usage:

```text
1.00 → 1.05
1.05 → 1.10
1.10 → 1.15
...
```

This reveals whether the mode continuity is diagonal, off-diagonal, or hybridized locally.

Comparing distant points, such as `1.0` and `1.4`, can be useful for endpoint similarity, but it is not the best way to diagnose the local behavior of a crossing.

---

## Interpreting overlap matrices

### Diagonal-dominant overlap matrix

If the overlap matrix is diagonal-dominant for neighboring sweep points, it means:

```text
mode rank 1 at the previous point is most similar to mode rank 1 at the current point
mode rank 2 at the previous point is most similar to mode rank 2 at the current point
...
```

This indicates that the field profiles are continuous under the current sorting rule.

### Off-diagonal-dominant overlap matrix

If the largest overlap moves off the diagonal, it means that the current sorting or mode index has likely swapped relative to field similarity.

For example:

```text
previous rank 2 → current rank 3
previous rank 3 → current rank 2
```

This suggests a mode-rank or branch-index exchange.

### Mixed 2-by-2 block

A matrix block like:

```text
[0.5  0.5
 0.5  0.5]
```

or any strongly mixed block suggests mode hybridization. In this case, a simple one-to-one branch assignment may be ambiguous.

---

## Component character versus overlap continuity

Component-ratio metrics and overlap metrics answer different questions.

```text
Component ratio:
    What is the physical field character of this mode?

Field overlap:
    Which mode at the next parameter point is most similar in field profile?
```

Near an avoided crossing, these can give different but complementary information.

### Adiabatic eigenmode branch

The maximum-overlap rule usually follows the adiabatic eigenmode branch:

```text
follow the eigenmode that changes continuously in field profile
```

If overlap matrices remain diagonal through a crossing region, the eigenmode branch is continuous under the current sorting.

### Diabatic or physical-character branch

A component-ratio label follows physical character:

```text
follow the Ex-dominant or Ey-dominant character
```

If `Ex_frac_xy` and `Ey_frac_xy` exchange while the overlap matrix remains diagonal, then:

```text
the eigenmode branch is continuous,
but the physical character is exchanged along that branch
```

This is a typical avoided-crossing interpretation.

Therefore, overlap should be used as a verification tool, not as the only possible tracking rule.

---

## Common pitfalls

### Treating Ex-dominant as TE without checking coordinates

`Ex_dominant` only means that the selected integral of `|Ex|²` is large. Whether this corresponds to TE-like or TM-like depends on coordinate convention and propagation direction.

### Forgetting to set Nmode

If the desired number of modes is set manually in the GUI and not controlled by a parameter, different scripts may solve different numbers of modes. Use a global parameter such as `Nmode`.

### Including lossy modes in overlap

Overlap matrices become harder to interpret if many lossy or PML-like modes are included. Apply loss/Q filtering before field interpolation.

### Comparing distant endpoints

A distant endpoint comparison may show broad mixing even if local overlap is diagonal. Use neighboring sweep points to diagnose crossings.

### Over-trusting maximum overlap

Maximum overlap tracks field-profile continuity. It does not necessarily track a fixed physical character such as Ex-dominant or Ey-dominant.
