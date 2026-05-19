# Ring QPM Toolbox Template

This folder contains a MATLAB LiveLink workflow for ring-level dispersion and quasi-phase-matching calculations using 1550 nm fundamental modes and 775 nm second-harmonic modes.

The code is intended as a reusable template. It assumes that the user already has a local COMSOL mode-analysis `.mph` model with the required parameters and variables.

---

## What is included

```text
scripts/
├── Sweep_ring_qpm_geometry.m
├── Plot_single_ring_qpm_result.m
├── Batch_postprocess_ring_qpm_jump_breaks.m
└── Query_ring_qpm_postprocessed_result.m

functions/
├── run_ring_qpm_case.m
├── estimate_sweep_time_upper_bound.m
├── get_material_index.m
├── get_material_index_MgLN.m
└── get_material_index_r.m

plotting/
└── plot_ring_qpm_result.m
```

---

## What is intentionally not included

Do not commit private or large files here:

```text
models/*.mph
results/*.mat
results/**/*.mat
```

Keep the COMSOL model and generated results local unless a small sanitized teaching example is deliberately added to `examples/`.

---

## Expected local folder layout

For local use, place the `.mph` model and result folders next to this template:

```text
ring_qpm/
├── functions/
├── plotting/
├── scripts/
├── models/      # local only; ignored by git
└── results/     # local only; ignored by git
```

Then run:

```matlab
scripts/Sweep_ring_qpm_geometry.m
```

or open the script and run it section by section.

---

## Main outputs

The core result is the MATLAB structure `out`, saved in each result `.mat` file.

Important fields:

```text
out.Data_IR, out.Data_SH
out.Result_IR, out.Result_SH
out.Lambda_QPM_um
out.GVM_fs_per_mm
out.Walk.Delta_f_SHG_Hz
out.Walk.Delta_f_rel_Hz
out.smooth
```

The post-processing script `scripts/Batch_postprocess_ring_qpm_jump_breaks.m`
does not rerun COMSOL. It reloads saved `out.Data_IR` and `out.Data_SH`
all-mode arrays, reselects the requested IR and SH branches, detects large
selected-branch `neff` jumps, and splits `Dint`, QPM, GVM, and SHG mismatch
calculations at jump boundaries. The companion query script can retrieve one
postprocessed case by geometry and mode-selection metadata.

---

## Validation checklist

Before trusting a large sweep result:

- verify the COMSOL model manually for one geometry;
- verify that `TEfrac`, `TMfrac`, and `rAverage` are meaningful;
- check that enough modes are requested;
- check selected solnums and mode fractions at IR and SH wavelengths;
- check that selected `neff` branches are smooth;
- rerun jump-break post-processing when branch continuity is suspicious;
- check minimum selected-branch Q values;
- verify units before interpreting `D1`, `D2`, and `Dint`.
