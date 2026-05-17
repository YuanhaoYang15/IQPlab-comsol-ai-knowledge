# Case 003 — Mode-Family Identification and Overlap Verification

## Purpose

This case demonstrates how to classify mode families in a COMSOL optical mode-analysis sweep and how to verify mode similarity near a possible crossing or avoided crossing.

The workflow has two parts:

```text
Part A:
    compute Ex/Ey component ratios for accepted bound modes

Part B:
    compute overlap matrices for selected neighboring parameter points
```

This case follows Module 04. Module 04 filters leaky modes using `imag(neff)`, loss, or Q-like metrics. Module 05 further distinguishes mode families and verifies mode continuity.

---

## Related files

```text
docs/matlab_livelink_mode_family_identification.md

templates/livelink_mode_family_component_ratio.m
templates/livelink_mode_family_component_postprocess.m
templates/livelink_mode_family_overlap_check.m
templates/livelink_mode_family_overlap_postprocess.m
```

---

## COMSOL preparation

The model should contain:

```text
1. A working optical mode-analysis study.
2. A sweepable width parameter, for example w_ln.
3. A global number-of-modes parameter, for example Nmode.
4. A physical-region integration operator, for example intop_LN_physical.
5. Field variables ewfd.Ex, ewfd.Ey, ewfd.Ez.
6. Effective-index variable ewfd.neff.
```

In the mode-analysis study, set the desired number of modes to:

```text
Nmode
```

so that MATLAB can control the number of solved modes through:

```matlab
cfg.Nmode = 10;
```

---

## Part A — Component-ratio extraction

Run:

```text
templates/livelink_mode_family_component_ratio.m
```

This script creates or updates COMSOL variables using MATLAB LiveLink:

```text
mode_IEx = intop_LN_physical(abs(ewfd.Ex)^2)
mode_IEy = intop_LN_physical(abs(ewfd.Ey)^2)
mode_IEz = intop_LN_physical(abs(ewfd.Ez)^2)
```

Then it reads these scalar quantities for all returned modes, filters accepted bound modes, and saves the result.

Main output:

```text
local_outputs/
└── mode_family_component_ratio_YYYYMMDD_HHMMSS/
    ├── mode_family_config.mat
    ├── mode_family_raw.mat
    ├── mode_family_metrics.csv
    ├── mode_family_all_modes.csv
    └── sweep_point_summary.csv
```

The primary table is:

```text
mode_family_metrics.csv
```

which contains accepted modes only.

---

## Part A post-processing

Run:

```text
templates/livelink_mode_family_component_postprocess.m
```

This script does not run COMSOL. It loads saved component-ratio results and makes plots.

Useful plots include:

```text
real(neff) versus width colored by Ex_frac_xy
real(neff) versus width colored by Ey_frac_xy
loss versus width
Ex_frac_xy and Ey_frac_xy versus width
mode branches grouped by family_label
```

The post-processing script can plot either:

```matlab
cfgPost.tableMode = 'accepted';
```

or:

```matlab
cfgPost.tableMode = 'all';
```

---

## Interpreting component-ratio plots

If a branch is consistently `Ex_dominant`, it means the mode has a large integrated `|Ex|²` contribution in the chosen integration region.

If a branch is consistently `Ey_dominant`, it means the mode has a large integrated `|Ey|²` contribution.

If a branch changes from `Ex_dominant` to `Ey_dominant`, the physical character of that eigenmode branch may be changing, often due to hybridization or an avoided crossing.

Do not automatically call these TE/TM modes until the coordinate convention and propagation direction are confirmed.

---

## Part B — Overlap check

After inspecting the component-ratio map, choose a suspicious crossing region.

A suspicious region may show:

```text
1. two neff branches approaching each other;
2. Ex_frac_xy or Ey_frac_xy changing rapidly;
3. family labels changing abruptly;
4. COMSOL mode index or sorted rank appearing to switch.
```

Edit the two parameter values in:

```text
templates/livelink_mode_family_overlap_check.m
```

For example:

```matlab
cfg.widthPrev_um = 1.20;
cfg.widthCurr_um = 1.25;
```

Then run the script.

The script solves both widths, filters accepted modes, interpolates fields for accepted modes, and saves:

```text
overlap_pairs.csv
overlap_matrix.csv
overlap_best_matches.csv
previous_modes.csv
current_modes.csv
```

---

## Part B post-processing

Run:

```text
templates/livelink_mode_family_overlap_postprocess.m
```

This script does not run COMSOL. It loads saved overlap results and makes plots.

The heatmap can be sorted by `real(neff)` in descending order. In that case, heatmap labels `1, 2, 3, ...` are sorted ranks, not necessarily original COMSOL `solnum`.

The sorted-order files:

```text
overlap_prev_mode_order_sorted.csv
overlap_curr_mode_order_sorted.csv
```

record how sorted ranks correspond to original mode indices and `real(neff)`.

---

## How to choose width pairs

For crossing diagnosis, use neighboring or nearby width pairs:

```text
1.00 → 1.05
1.05 → 1.10
1.10 → 1.15
...
```

Avoid using only distant endpoint comparisons, such as:

```text
1.00 → 1.40
```

unless the goal is simply to compare endpoint field similarity.

Distant endpoint comparisons may show broad hybridization and do not identify where the exchange occurs.

---

## Interpretation examples

### Case 1: overlap matrix remains diagonal

If neighboring-point overlap matrices are always diagonal-dominant, then the field profiles are continuous under the current sorting rule.

If `family_label` still changes along the same diagonal branch, then the eigenmode branch is continuous but its physical character is changing.

This is consistent with an avoided-crossing interpretation.

### Case 2: overlap matrix becomes off-diagonal

If the maximum overlap moves from the diagonal to an off-diagonal element, then the sorted mode rank or COMSOL mode index has likely swapped.

This indicates a branch-index exchange under the current sorting rule.

### Case 3: 2-by-2 mixed block

If two modes form a mixed block, such as:

```text
[0.5  0.5
 0.5  0.5]
```

then the two modes are strongly hybridized. A simple one-to-one assignment may be ambiguous.

---

## Main takeaway

Component-ratio metrics and overlap metrics answer different questions.

```text
Component ratio:
    What is the field character of the mode?

Overlap:
    Which mode at the neighboring parameter point is most similar in field profile?
```

Therefore:

```text
Ex/Ey fraction exchange
    indicates physical-character exchange

diagonal overlap
    indicates continuous eigenmode field evolution

off-diagonal overlap
    indicates mode-rank or index exchange

mixed block
    indicates hybridization and ambiguous branch assignment
```

Both metrics should be used together.
