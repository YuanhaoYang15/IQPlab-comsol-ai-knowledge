# AI Validation Prompts for COMSOL MATLAB LiveLink Repository

## Purpose

This file defines practical validation tests for an AI assistant that is asked to work with this repository from zero.

These are not `pytest`-style software unit tests. They are prompt-based acceptance tests for checking whether an AI assistant can:

1. read the repository structure correctly;
2. follow `AGENTS.md` before writing code;
3. distinguish validation, simulation sweep, and post-processing;
4. avoid unsafe assumptions about COMSOL eigenmodes;
5. produce MATLAB LiveLink scripts that are reproducible and reviewable;
6. diagnose common COMSOL mode-analysis failure modes.

Use this file when evaluating ChatGPT, Codex, or another AI assistant on this repository.

---

## How to use these tests

For each test:

1. Start a fresh AI chat or coding-agent session.
2. Give the AI only the repository URL or the local repository folder.
3. Paste the test prompt exactly.
4. Evaluate the answer using the checklist and red flags.
5. Record the result as:

```text
PASS
PARTIAL PASS
FAIL
```

A good AI answer should cite or explicitly use repository files such as:

```text
AGENTS.md
docs/livelink_environment_setup.md
docs/matlab_livelink_parameter_sweep.md
cases/case_001_validation_before_sweep.md
cases/case_002_waveguide_width_sweep.md
templates/*.m
```

The AI does not need to run COMSOL unless the test explicitly says so. If the `.mph` model file is missing, the correct behavior is to state that clearly and still provide a dry-run or template-level validation plan.

---

## Global scoring rubric

Use this rubric for every test.

### PASS

The answer:

- follows `AGENTS.md` principles;
- separates model validation, sweep execution, and post-processing;
- does not assume the first COMSOL eigenmode is the target mode;
- uses all-mode extraction when appropriate;
- preserves raw results before filtering;
- includes model path, study tag, dataset tag, and result-expression checks;
- warns about PML-localized, radiation, substrate, or slab modes;
- gives reproducible MATLAB code or a concrete workflow when code is requested;
- states limitations clearly if required files are missing.

### PARTIAL PASS

The answer is useful but misses one or two important items, for example:

- gives a reasonable workflow but no output-file structure;
- extracts all modes but does not discuss field-profile inspection;
- gives code but weak error handling;
- mentions PML modes but does not give a pass/fail criterion.

### FAIL

The answer is unsafe or not useful, for example:

- assumes `solnum = 1` or the first returned mode is correct;
- starts a full sweep before single-geometry validation;
- filters modes without saving raw mode-level data;
- ignores study/dataset/result-expression tags;
- treats every returned eigenmode as physical;
- overwrites old output folders;
- gives only vague GUI instructions when a reproducible script was requested.

---

# Test 000 — Repository Orientation

## Goal

Check whether the AI can understand the purpose, structure, and operating rules of the repository before editing files.

## Prompt

```text
You are given this repository:

https://github.com/YuanhaoYang15/IQPlab-comsol-ai-knowledge

Start from zero. Read the repository structure and summarize what this repo is for.
Then explain which files an AI assistant should read first before modifying MATLAB LiveLink scripts.
Do not write code yet.
```

## Expected answer checklist

A good answer should mention:

- this is a COMSOL MATLAB LiveLink knowledge base for integrated photonics simulations;
- `AGENTS.md` is the first file an AI assistant should read;
- `docs/` contains workflow and environment notes;
- `templates/` contains reusable MATLAB LiveLink scripts;
- `cases/` contains scenario-based validation and sweep examples;
- `tests/validation_prompts.md` contains AI acceptance tests;
- large `.mph` files may be omitted from GitHub;
- AI should not assume returned eigenmodes are physical.

## Red flags

Fail the answer if it:

- ignores `AGENTS.md`;
- claims the repository is a general MATLAB toolbox only;
- assumes all examples are directly runnable without checking missing `.mph` files;
- proposes editing scripts before reading the validation cases.

---

# Test 001 — Case 001 Single-Geometry Validation

## Goal

Check whether the AI understands the required validation before launching a parameter sweep.

## Prompt

```text
Read AGENTS.md and cases/case_001_validation_before_sweep.md.

Explain the minimum validation workflow that should be completed before launching any COMSOL MATLAB LiveLink parameter sweep.
Then write or modify a MATLAB script that:

1. loads one example .mph model;
2. optionally sets one representative geometry parameter;
3. runs one mode-analysis study;
4. extracts all values of ewfd.neff using solnum = all;
5. estimates loss_dB_per_cm and Q_est for every returned mode;
6. saves a raw mode table and configuration metadata;
7. prints a pass/fail checklist for whether the model is ready for a full sweep.

Do not launch a parameter sweep.
Do not assume the first returned mode is the target mode.
```

## Expected answer checklist

A good answer should include:

- a clear user-editable configuration section;
- `modelPath`, `studyTag`, `datasetTag`, `lambda0_um`, and output folder settings;
- `mphload` or equivalent model-loading logic;
- `model.study(studyTag).run` or equivalent study-run logic;
- `mphglobal(..., 'solnum', 'all', 'Complexout', 'on')` for all returned modes;
- calculation of `real_neff`, `imag_neff`, `loss_dB_per_cm`, and `Q_est`;
- `table(...)` output for mode-level results;
- saving to a timestamped local output folder;
- no overwrite of old results;
- field-profile inspection listed as required before accepting modes;
- warning that scalar metrics alone are insufficient.

## Red flags

Fail the answer if it:

- uses only `solnum = 1`;
- picks the mode with largest `real(neff)` without further checks;
- starts sweeping `w_ln` or another parameter;
- does not save raw all-mode data;
- ignores PML or substrate modes;
- hard-codes machine-specific paths without explaining them.

---

# Test 002 — MATLAB Template Sanity Check

## Goal

Check whether the AI can review repository MATLAB templates for basic runnability and formatting before using them.

## Prompt

```text
Review the MATLAB files in templates/ for basic syntax and runnability issues.
Focus especially on whether section comments, line breaks, user-input blocks, and function/script boundaries are safe for MATLAB.

Give a concise report of likely problems and provide corrected versions or patch-style replacements when necessary.
Do not change the physical workflow unless needed for correctness.
```

## Expected answer checklist

A good answer should:

- inspect raw `.m` file formatting rather than only rendered GitHub previews;
- notice dangerous one-line formatting if code appears on the same physical line as `%%` section comments;
- avoid changing scientific assumptions while fixing formatting;
- preserve variable names when possible;
- keep user-editable configuration at the top;
- keep output folders timestamped;
- keep all-mode extraction logic where appropriate;
- explain which files were changed and why.

## Red flags

Fail the answer if it:

- says the templates are runnable without checking raw file contents;
- rewrites everything into unrelated code;
- removes all-mode extraction;
- removes saving of raw data;
- introduces hidden global state or undocumented dependencies.

---

# Test 003 — Case 002 Width Sweep with Bound-Mode Diagnostics

## Goal

Check whether the AI can use Case 002 to design a safe parameter sweep workflow.

## Prompt

```text
Read AGENTS.md and cases/case_002_waveguide_width_sweep.md.

Design a MATLAB LiveLink workflow for sweeping the waveguide width w_ln.
The workflow should:

1. set w_ln for each sweep point;
2. run the mode-analysis study;
3. extract all returned ewfd.neff values;
4. estimate loss and Q for every mode;
5. save raw all-mode data for every width;
6. apply a configurable loss or Q threshold only after raw data are saved;
7. generate a CSV summary of accepted modes;
8. avoid plotting inside the expensive simulation script.

Explain how this differs from the single-geometry validation in Case 001.
```

## Expected answer checklist

A good answer should include:

- clear distinction between Case 001 and Case 002;
- sweep list such as `cfg.wList_um`;
- loop over width values;
- `try/catch` or equivalent failed-geometry handling;
- `solnum = 'all'` extraction;
- storage of variable-length mode lists using tables, structs, or `NaN` padding;
- raw `.mat` save before mode filtering;
- configurable thresholds such as `maxLoss_dB_per_cm` or `minQ_est`;
- separate post-processing script recommendation;
- diagnostic interpretation of too many or too few accepted modes.

## Red flags

Fail the answer if it:

- extracts only one mode per width;
- overwrites results from previous runs;
- applies thresholds before preserving raw data;
- mixes plotting, simulation, and post-processing into one hard-to-rerun script;
- assumes the accepted mode family is tracked correctly only by mode index.

---

# Test 004 — Post-Processing Without Re-Running COMSOL

## Goal

Check whether the AI keeps expensive simulation runs separate from cheap threshold tuning and plotting.

## Prompt

```text
I already ran a COMSOL MATLAB LiveLink width sweep and saved raw all-mode data.
Now I want to change the loss threshold and regenerate summary plots.

Write a MATLAB post-processing workflow that loads existing results and does not call COMSOL at all.
It should allow me to change the threshold and regenerate accepted-mode tables and diagnostic plots.
```

## Expected answer checklist

A good answer should:

- explicitly avoid `mphload`, `mphstart`, and `model.study(...).run`;
- load existing `.mat` or `.csv` result files;
- allow threshold parameters to be changed at the top;
- rebuild accepted-mode summaries from raw mode data;
- produce diagnostic plots from saved data only;
- keep raw data unchanged;
- save new post-processed results in a separate folder or with clear filenames;
- warn that changing threshold cannot fix wrong physics or bad mode extraction.

## Red flags

Fail the answer if it:

- re-runs COMSOL;
- modifies raw results;
- cannot handle multiple modes per sweep point;
- chooses modes only by array index;
- gives plotting code that depends on hidden variables from the simulation script.

---

# Test 005 — Suspicious Low-Loss Mode Diagnosis

## Goal

Check whether the AI can diagnose false-positive modes in a PML-based optical mode-analysis simulation.

## Prompt

```text
In my COMSOL mode-analysis sweep, some returned modes have very small imag(neff), so the estimated loss is low.
However, the field profile looks mostly in the substrate or near the PML, not inside the lithium-niobate waveguide.

How should I diagnose this? Should I accept the low-loss mode as a bound waveguide mode?
Give a practical debugging checklist and suggest what scalar quantities I should extract in addition to ewfd.neff.
```

## Expected answer checklist

A good answer should say:

- do not accept the mode based only on low `imag(neff)`;
- inspect field profile and confinement;
- check whether the mode is substrate, slab, radiation, or PML-localized;
- extract region-integral quantities such as `frac_E2_LN` or core energy fraction;
- compare loss against confinement metrics;
- check PML distance, PML thickness, mesh, and boundary conditions;
- check effective-index range relative to material indices;
- request more modes if needed;
- use mode-family tracking or overlap later for sweeps.

## Red flags

Fail the answer if it:

- says low loss is sufficient to accept the mode;
- recommends simply loosening the threshold;
- ignores PML effects;
- ignores field-profile inspection;
- cannot distinguish numerical modes from physical guided modes.

---

# Test 006 — Anisotropic Lithium-Niobate Tensor Sanity Check

## Goal

Check whether the AI handles anisotropic lithium-niobate simulations carefully.

## Prompt

```text
I am using anisotropic lithium niobate in a COMSOL optical mode-analysis model.
Before trusting the sweep results, what coordinate and material-tensor checks should I perform?
Assume the model may be z-cut or x-cut, and the propagation direction may differ between models.
```

## Expected answer checklist

A good answer should mention:

- crystal cut must be identified explicitly;
- propagation direction must be identified explicitly;
- COMSOL coordinate convention must be checked;
- distinguish refractive-index tensor from relative-permittivity tensor;
- tensor rotation order must be documented;
- ordinary and extraordinary indices must be assigned to the correct crystal axes;
- mode polarization interpretation depends on propagation direction;
- test with simple limiting cases before full sweep;
- compare expected `neff` ranges with physical material indices.

## Red flags

Fail the answer if it:

- assumes z-cut and x-cut use the same tensor orientation;
- confuses `n` and `epsilon_r = n^2`;
- ignores propagation direction;
- gives a final TE/TM label without checking field components or coordinate convention.

---

# Test 007 — Mode-Family Tracking Strategy

## Goal

Check whether the AI understands that mode tracking across a sweep requires more than sorting by effective index.

## Prompt

```text
I swept waveguide width and extracted several modes at every width.
The modes sometimes cross or hybridize, and sorting by real(neff) gives discontinuous branches.

Design a robust mode-family tracking strategy for the next module.
It should use saved all-mode data and, if necessary, field-overlap information.
Do not re-run the whole sweep unless absolutely necessary.
```

## Expected answer checklist

A good answer should include:

- use saved all-mode data first;
- sort-by-`neff` is not sufficient near crossings or hybridization;
- use overlap between fields at neighboring sweep points when field data are available;
- construct an overlap matrix between modes at adjacent parameter points;
- choose assignments using maximum overlap or an assignment algorithm;
- include continuity constraints for `real(neff)`, loss, and confinement metrics;
- identify ambiguous regions and flag them for manual inspection;
- preserve raw branch assignments and allow reprocessing;
- explain that true mode hybridization may make labels physically ambiguous.

## Red flags

Fail the answer if it:

- says sorting by descending `real(neff)` is always enough;
- ignores field profiles;
- overwrites raw data with tracked branches only;
- hides ambiguous mode crossings;
- assumes diagonal overlap must always mean no mode change without interpretation.

---

# Test 008 — AI Code Review Before Commit

## Goal

Check whether the AI can review a proposed repository change using project rules.

## Prompt

```text
Review my proposed change before I commit it:

- I added a MATLAB LiveLink parameter sweep script.
- The script runs COMSOL, filters modes by loss threshold, plots the final heatmap, and saves only the accepted mode at each parameter point.
- It overwrites the previous output folder each time.

Is this acceptable for this repository? If not, explain what should be changed before commit.
```

## Expected answer checklist

A good answer should say this is not acceptable as-is because:

- expensive simulation and plotting should be separated;
- raw all-mode data must be saved before filtering;
- accepted-mode-only output is insufficient for changing thresholds later;
- overwriting previous output folders is unsafe;
- user-editable parameters should be clear;
- output metadata should include sweep parameters, study/dataset tags, thresholds, and expressions;
- plots should be generated in a post-processing script or at least from saved data;
- the script should handle failed geometries and missing modes.

## Red flags

Fail the answer if it:

- approves the change without concerns;
- focuses only on plot aesthetics;
- ignores raw data preservation;
- ignores overwrite risk;
- ignores separation between computation and post-processing.

---

# Test 009 — Missing Example Model Handling

## Goal

Check whether the AI behaves correctly when the example `.mph` file is not present in the GitHub repository.

## Prompt

```text
I cloned the repository and tried to run the minimal LiveLink script, but examples/LN_ridge_waveguide_Zcut.mph is missing.
What should I do?
Should the AI assistant still be able to help me test the repository?
```

## Expected answer checklist

A good answer should say:

- the `.mph` file may be intentionally omitted because it is large, private, or model-specific;
- this prevents true end-to-end execution but not documentation/template review;
- use a local `.mph` file and update `modelPath`;
- first run connection and path checks;
- verify study tag, dataset tag, and result expressions in the local model;
- do a dry-run review of scripts if COMSOL execution is unavailable;
- do not fabricate expected numerical results without running a model.

## Red flags

Fail the answer if it:

- claims the repository is broken only because the `.mph` file is absent;
- invents numerical results;
- ignores the need to update `modelPath`;
- suggests committing large private `.mph` files without considering `.gitignore` and confidentiality.

---

# Test 010 — End-to-End Dry Run Plan

## Goal

Check whether the AI can propose a realistic staged test plan for the whole repository without overpromising.

## Prompt

```text
I want to test whether this repository is ready for a new AI assistant to use from zero.
Design a staged validation plan.
Assume COMSOL may not be available in the first stage, and the example .mph file may be missing from GitHub.
```

## Expected answer checklist

A good answer should propose stages such as:

1. repository structure and documentation review;
2. MATLAB template syntax and formatting check;
3. LiveLink environment connection check;
4. local `.mph` path and tag validation;
5. Case 001 single-geometry validation;
6. Case 002 small sweep with all-mode extraction;
7. post-processing threshold change without re-running COMSOL;
8. failure-mode diagnosis tests;
9. optional mode-family tracking tests;
10. final commit-readiness review.

It should also distinguish:

- documentation-only tests;
- dry-run code review tests;
- local COMSOL execution tests;
- physics-result validation tests.

## Red flags

Fail the answer if it:

- requires COMSOL for every test;
- claims documentation review alone proves end-to-end readiness;
- skips single-geometry validation;
- skips post-processing-only tests;
- does not state what cannot be verified without `.mph` and COMSOL.

---

## Recommended validation record format

Use this simple table to record AI test results.

```text
Date:
AI system/model:
Repository commit hash:
Tester:

| Test ID | Result | Notes |
|---|---|---|
| 000 | PASS / PARTIAL PASS / FAIL | |
| 001 | PASS / PARTIAL PASS / FAIL | |
| 002 | PASS / PARTIAL PASS / FAIL | |
| 003 | PASS / PARTIAL PASS / FAIL | |
| 004 | PASS / PARTIAL PASS / FAIL | |
| 005 | PASS / PARTIAL PASS / FAIL | |
| 006 | PASS / PARTIAL PASS / FAIL | |
| 007 | PASS / PARTIAL PASS / FAIL | |
| 008 | PASS / PARTIAL PASS / FAIL | |
| 009 | PASS / PARTIAL PASS / FAIL | |
| 010 | PASS / PARTIAL PASS / FAIL | |
```

Recommended summary:

```text
Overall readiness:
- Documentation-level AI test: ready / not ready
- MATLAB-template AI test: ready / not ready
- Local COMSOL execution test: ready / not ready
- End-to-end sweep test: ready / not ready

Blocking issues:
1.
2.
3.

Next actions:
1.
2.
3.
```
