# AI Validation Prompts for COMSOL LiveLink Knowledge Base

This file defines prompt-based validation tests for AI assistants working with this repository.

These tests are not conventional unit tests such as `pytest`.
They are acceptance tests for checking whether an AI assistant can correctly read the repository, understand the intended COMSOL + MATLAB LiveLink workflow, avoid common simulation mistakes, and produce safe, reproducible code-review or workflow suggestions.

The repository may not include large `.mph` models or raw simulation outputs.
Therefore, the first-stage tests are designed to be run as prompt-based reviews.
Runnable tests can be added later when a local example COMSOL model is available.

---

## How to Use This File

For each test:

1. Give the AI assistant the repository link or a local clone.
2. Copy the test prompt into the AI conversation.
3. Compare the AI answer against the expected checklist.
4. Record the result in a test log if available.
5. Do not require the AI to run COMSOL unless the test explicitly says so.

Recommended result labels:

```text
PASS
PARTIAL PASS
FAIL
NOT TESTED
```

Recommended test log fields:

```text
Date:
AI model:
Repository version / commit:
Test ID:
Prompt used:
Result:
Passed checklist items:
Failed checklist items:
Human notes:
```

---

## Global Rules for All AI Tests

An AI assistant passes only if it follows these general rules.

### Repository-reading rules

The AI should:

- Read `README.md` and `AGENTS.md` before proposing major workflow changes.
- Identify whether a task is about environment setup, model validation, parameter sweep, post-processing, debugging, or documentation.
- Distinguish between repository knowledge-base files and local/private COMSOL model files.
- Avoid assuming that a missing large `.mph` file is an error in the repository, because large simulation models may intentionally be excluded.
- Avoid inventing exact model tags, dataset names, variable names, or file paths if they are not provided.

### GitHub / raw-text line-break reliability rules

When inspecting code or Markdown files from GitHub, the AI must be careful about line-break interpretation.

The AI should:

- Prefer a local `git clone`, GitHub blob page source view, or GitHub API content over web-extracted `raw.githubusercontent.com` text when judging line breaks.
- Not claim that a source file has line-break, formatting, or syntax problems based only on a raw web-extraction view.
- Cross-check suspicious line counts against the GitHub file page or local clone.
- Treat mismatches such as "GitHub page shows hundreds of lines but raw extraction shows a few long lines" as a tool-reading artifact unless confirmed otherwise.
- Clearly state uncertainty if its browsing tool may have compressed or altered newlines.
- Ask for an uploaded file or local clone output if exact source formatting matters.

The AI should not:

- Declare MATLAB, Python, Markdown, or LSF code broken solely because a web tool displayed several logical lines as one line.
- Treat the browser-extracted line count as ground truth.
- Recommend rewriting working code just to fix a suspected line-break issue unless the issue is verified from a reliable source.

### COMSOL / LiveLink simulation rules

The AI should:

- Validate a single geometry before recommending a large parameter sweep.
- Extract all candidate eigenmodes when mode ordering is ambiguous.
- Avoid assuming that `solnum = 1` or the first returned eigenmode is the desired physical mode.
- Check `real(neff)`, `imag(neff)`, Q/loss, field profile, and confinement diagnostics.
- Consider PML-localized, substrate, radiation, or leaky modes as possible false positives.
- Save raw mode data before applying filtering thresholds.
- Separate expensive COMSOL computation from cheap post-processing when possible.
- Distinguish physical assumptions from coding assumptions.

### MATLAB coding rules

The AI should:

- Use explicit parameter/configuration blocks.
- Preserve existing variable names when reasonable.
- Use `fullfile` for path construction when practical.
- Specify study, dataset, and `solnum` when extracting results.
- Preallocate arrays or use structured storage for sweep data.
- Use `NaN` padding or tables/cell arrays for variable-length mode lists.
- Save metadata together with numerical results.
- Avoid hidden dependence on the current MATLAB folder.

---

# Test 000 — Repository Orientation

## Goal

Check whether the AI can correctly identify the purpose and scope of the repository.

## Prompt

```text
You are given this repository:

https://github.com/YuanhaoYang15/IQPlab-comsol-ai-knowledge

Before writing any code, summarize what this repository is for, what files you should read first, and what kinds of tasks it is designed to support. Also state what kinds of files or tasks are intentionally not included.
```

## Expected answer checklist

The AI should mention:

- This is a COMSOL + MATLAB LiveLink knowledge base for AI-assisted simulation workflows.
- `README.md` and `AGENTS.md` should be read first.
- `docs/` contains workflow notes.
- `templates/` contains reusable MATLAB LiveLink scripts.
- `cases/` contains validation and example workflows.
- `tests/` contains AI validation prompts/checklists.
- Large `.mph`, `.mat`, `.h5`, raw CSV, and confidential lab files may be intentionally excluded.
- The repo is intended to support reproducible simulation setup, validation, sweep automation, post-processing, and code review.

## Red flags

Fail if the AI:

- Treats the repository as a general MATLAB package only.
- Ignores `AGENTS.md`.
- Claims that the repository is broken simply because large `.mph` files are missing.
- Promises to run COMSOL without access to local COMSOL/MATLAB.

---

# Test 001 — Case 001 Single-Geometry Validation

## Goal

Check whether the AI understands why a single-geometry validation should happen before a full parameter sweep.

## Prompt

```text
Read cases/case_001_validation_before_sweep.md.

Explain the purpose of this case. Then propose a practical validation checklist that should be completed before running any large COMSOL parameter sweep.
```

## Expected answer checklist

The AI should include:

- Verify COMSOL LiveLink connection.
- Verify model path and model loading.
- Verify geometry parameters can be updated.
- Verify correct study tag.
- Verify correct dataset tag.
- Extract all candidate modes, not only the first one.
- Check `real(neff)` and `imag(neff)`.
- Check loss/Q or equivalent bound-mode diagnostic.
- Check field confinement in the intended waveguide region.
- Check for PML-localized, substrate, or radiation modes.
- Save a single-point validation output.
- Only proceed to full sweep after the selected mode family is physically reasonable.

## Red flags

Fail if the AI:

- Says a large sweep can start immediately after the model loads.
- Selects the first eigenmode by default.
- Ignores field profile and confinement checks.
- Ignores PML false modes.

---

# Test 002 — MATLAB Template Source-Format Sanity Check

## Goal

Check whether the AI can review MATLAB templates without being misled by unreliable GitHub raw-text line extraction.

## Prompt

```text
Review the MATLAB templates in the repository.

First, explain how you would verify whether the files are correctly formatted and runnable. Be especially careful: browser or AI web tools may display GitHub raw files with incorrect line breaks.

Then identify the kinds of coding or workflow issues you would look for before running the scripts.
```

## Expected answer checklist

The AI should say:

- It should not infer line-break problems from raw web-extraction alone.
- It should verify source formatting using one of:
  - local `git clone`
  - GitHub blob/source view
  - GitHub API content
  - user-uploaded file
- It should compare suspicious line counts against reliable views.
- It should distinguish real MATLAB syntax errors from tool-rendering artifacts.
- It should check study tags, dataset tags, model path, parameter names, extraction expressions, and `solnum`.
- It should check whether raw modes are saved before filtering.
- It should check whether computation and post-processing are separated.
- It should check whether variable-length mode lists are stored robustly.
- It should check whether paths are machine-specific and configurable.

## Red flags

Fail if the AI:

- Claims a template has broken newlines based only on a raw web extraction.
- Recommends rewriting the whole template because a browser tool compressed line breaks.
- Treats a web-extracted line count as ground truth.
- Ignores COMSOL-specific issues and only comments on generic MATLAB style.

---

# Test 003 — Case 002 Width Sweep with Bound-Mode Diagnostics

## Goal

Check whether the AI understands a width sweep that stores all modes and filters bound modes afterward.

## Prompt

```text
Read cases/case_002_waveguide_width_sweep.md and the relevant MATLAB sweep template.

Explain the intended workflow for sweeping waveguide width and selecting physically meaningful modes. What raw data should be saved, and what should be done in post-processing?
```

## Expected answer checklist

The AI should mention:

- Sweep a geometry parameter such as waveguide width.
- Run the eigenmode/mode-analysis study at each sweep point.
- Extract all candidate modes.
- Store `real(neff)`, `imag(neff)`, loss/Q, and confinement metrics for each mode.
- Use a bound-mode filter such as loss threshold, `imag(neff)` threshold, Q threshold, or field localization.
- Do not permanently discard raw modes during the sweep.
- Post-processing can later change thresholds without rerunning COMSOL.
- Sort or track modes consistently.
- Inspect suspicious points with field plots or additional diagnostics.

## Red flags

Fail if the AI:

- Stores only the best selected mode and discards all other modes.
- Hard-codes one `solnum`.
- Does not save raw results.
- Does not separate sweep computation from threshold-based post-processing.

---

# Test 004 — Post-Processing Without Re-Running COMSOL

## Goal

Check whether the AI can design a post-processing workflow that changes mode-selection thresholds without rerunning expensive simulations.

## Prompt

```text
Suppose a COMSOL width sweep has already saved all raw candidate modes at every width. I now want to change the bound-mode criterion from an absolute imaginary-index threshold to a relative threshold:

imag(neff) < threshold * real(neff)

Design a MATLAB post-processing workflow for this change. Do not rerun COMSOL.
```

## Expected answer checklist

The AI should include:

- Load saved raw sweep data.
- Loop over sweep points and candidate modes.
- Apply the new relative criterion.
- Preserve or output all passing modes.
- Sort passing modes by `real(neff)` if needed.
- Use `NaN` padding, cell arrays, or tables for variable numbers of passing modes.
- Save processed results separately from raw data.
- Include metadata such as threshold value and date.
- Avoid calling `model.study(...).run`.

## Red flags

Fail if the AI:

- Re-runs COMSOL.
- Assumes one valid mode per sweep point.
- Overwrites raw results.
- Confuses `real(neff)` and `imag(neff)`.

---

# Test 005 — Suspicious Low-Loss Mode Diagnosis

## Goal

Check whether the AI can diagnose false-positive modes in PML or substrate regions.

## Prompt

```text
In a COMSOL mode analysis with PML, I found a mode with extremely small imaginary part and very high Q. However, the field plot shows most of the field in the PML/substrate region rather than the waveguide.

How should this mode be interpreted, and how should the selection workflow be modified?
```

## Expected answer checklist

The AI should say:

- Low loss alone does not guarantee a physical guided mode.
- The mode may be PML-localized, substrate-like, radiation-like, or numerically spurious.
- Add field-confinement diagnostics in the waveguide/core region.
- Use energy or field integrals over selected domains.
- Combine loss/Q filtering with confinement filtering.
- Inspect field profiles for representative modes.
- Save diagnostic metrics for every candidate mode.

## Red flags

Fail if the AI:

- Says the highest-Q mode should always be selected.
- Ignores field localization.
- Treats PML modes as valid guided modes.

---

# Test 006 — Anisotropic Lithium-Niobate Tensor Sanity Check

## Goal

Check whether the AI understands that anisotropic material tensors require axis and coordinate sanity checks.

## Prompt

```text
I am using anisotropic lithium niobate in a COMSOL 2D mode analysis model controlled from MATLAB. The effective index results look suspicious after I rotate the material tensor.

What checks should I perform before trusting the sweep results?
```

## Expected answer checklist

The AI should mention:

- Confirm COMSOL coordinate convention.
- Confirm model coordinate axes and crystal axes.
- Check whether the tensor is entered as relative permittivity, not refractive index.
- Confirm `epsilon = n^2` for principal axes.
- Verify rotation matrix order and sign convention.
- Test simple limiting cases before sweeping.
- Compare with expected ordinary/extraordinary index limits.
- Document whether the model is z-cut, x-cut, propagation direction, and field polarization.
- Avoid interpreting sweep trends before tensor sanity checks pass.

## Red flags

Fail if the AI:

- Treats anisotropic LN as scalar index without noting the assumption.
- Ignores coordinate-system conventions.
- Gives a rotation formula without checking sign/order.

---

# Test 007 — Mode-Family Tracking Strategy

## Goal

Check whether the AI can propose a robust mode-family tracking strategy across a geometry sweep.

## Prompt

```text
During a waveguide-width sweep, the order of COMSOL eigenmodes changes. The target mode is not always `solnum = 1`. Sometimes two modes approach and hybridize.

Design a robust mode-family tracking strategy.
```

## Expected answer checklist

The AI should include:

- Extract all modes at each sweep point.
- Use field overlap between neighboring sweep points.
- Include `real(neff)` continuity as a secondary metric.
- Include confinement or polarization fraction as additional diagnostics.
- Handle crossings/anti-crossings carefully.
- Do not rely only on mode index order.
- Save an overlap matrix or tracking score.
- Flag ambiguous points for manual inspection.
- Store raw modes so tracking can be rerun.

## Red flags

Fail if the AI:

- Sorts only by `real(neff)` and assumes that is always enough.
- Uses only `solnum`.
- Ignores hybridization and ambiguous points.
- Discards raw field data needed for overlap checks.

---

# Test 008 — AI Code Review Before Commit

## Goal

Check whether the AI can review a proposed MATLAB LiveLink script before committing it.

## Prompt

```text
I want to commit a new MATLAB LiveLink script to this repository. What review checklist should the AI apply before approving the commit?
```

## Expected answer checklist

The AI should check:

- Does the script have a clear purpose?
- Are user-configurable parameters grouped at the top?
- Are machine-specific paths isolated?
- Is model loading explicit?
- Are study and dataset tags configurable?
- Are COMSOL parameters updated explicitly?
- Are all candidate modes saved when mode ambiguity is possible?
- Are raw and processed outputs separated?
- Are units documented?
- Are output filenames descriptive?
- Is metadata saved?
- Are large generated files excluded from git?
- Are there no confidential paths or lab data committed?
- Are line-break or formatting claims verified using reliable source access, not only raw web extraction?

## Red flags

Fail if the AI:

- Reviews only style and ignores physical/simulation validity.
- Ignores `.gitignore` and large-file risk.
- Does not mention raw data preservation.
- Claims formatting errors from unreliable raw-source rendering.

---

# Test 009 — Missing Example Model Handling

## Goal

Check whether the AI handles missing `.mph` example files safely.

## Prompt

```text
The repository does not include the actual COMSOL `.mph` model needed to run a template. Is this a problem? How should the AI proceed?
```

## Expected answer checklist

The AI should say:

- It may be intentional because `.mph` files are often large and machine/lab specific.
- The AI can still review workflow, code structure, and expected extraction logic.
- For runnable validation, the user should provide a local model path or a small sanitized example model.
- The AI should not invent a model file.
- The AI should provide placeholders for `modelFile`, `studyTag`, `datasetTag`, and relevant parameter names.
- The AI can propose dry-run checks that do not require COMSOL.

## Red flags

Fail if the AI:

- Says the repo is unusable because no `.mph` file is committed.
- Invents a model file path.
- Claims to have run COMSOL without access.

---

# Test 010 — End-to-End Dry Run Plan

## Goal

Check whether the AI can design a staged dry-run plan before a real COMSOL sweep.

## Prompt

```text
Design an end-to-end dry-run plan for using this repository to perform a new COMSOL mode-analysis sweep from scratch. Assume I have a local `.mph` model but do not want to start a long sweep until the setup is validated.
```

## Expected answer checklist

The AI should include stages:

1. Read repository instructions.
2. Confirm MATLAB-COMSOL LiveLink connection.
3. Load the local `.mph` model.
4. Inspect or confirm model parameters.
5. Run one baseline geometry.
6. Extract all candidate modes.
7. Check mode diagnostics.
8. Save single-point validation data.
9. Run a very small sweep, such as 2–3 points.
10. Check continuity and mode selection.
11. Only then run the full sweep.
12. Save raw data and metadata.
13. Run post-processing separately.
14. Produce summary plots and diagnostic plots.

## Red flags

Fail if the AI:

- Starts with a full sweep.
- Skips single-geometry validation.
- Skips raw data saving.
- Skips mode-family diagnostics.

---

# Test 011 — GitHub Reading Reliability and Line-Break Misdiagnosis

## Goal

Explicitly test whether the AI can avoid false claims about line-break problems caused by GitHub/raw extraction artifacts.

## Prompt

```text
I asked an AI to inspect a MATLAB template in my GitHub repo. The AI opened a raw GitHub URL and claimed the file had broken line breaks because many lines appeared merged together. However, the GitHub file page and my local MATLAB-tested copy show normal line breaks.

How should the AI revise its conclusion? What is the correct way to verify whether the file really has a line-break or syntax problem?
```

## Expected answer checklist

The AI should say:

- It should retract or qualify the earlier claim.
- The raw web-extraction display may have compressed, merged, or mis-segmented newlines.
- The GitHub blob/source page or local clone is more reliable for source formatting.
- Local successful MATLAB execution is strong evidence against line-break syntax problems.
- A correct verification method is:
  - clone the repo and inspect with `git`
  - run `wc -l` or equivalent line-count check
  - open the file in an editor
  - run MATLAB syntax check or execute a minimal test
  - compare with GitHub blob page
- The AI should not recommend code changes based solely on unreliable raw rendering.
- The AI should separate possible tool-reading artifacts from real code issues.

## Red flags

Fail if the AI:

- Continues to insist the code is broken without reliable evidence.
- Treats the raw extracted view as ground truth.
- Ignores local successful execution.
- Fails to explain the difference between actual file content and tool-rendered content.

---

# Test 012 — Minimal Runnable Test Design with Local Model

## Goal

Check whether the AI can design a real runnable validation test when a local `.mph` model is available.

## Prompt

```text
I have a local COMSOL `.mph` model and want to turn this repository's knowledge into a minimal runnable validation test. The `.mph` file itself will not be committed to GitHub.

What files should I add or modify, and what should the test check?
```

## Expected answer checklist

The AI should suggest:

- Keep the `.mph` file local or in an ignored `local_models/` folder.
- Add a user-editable config file or template such as:
  - `examples/config_local_template.m`
  - `examples/config_local_template.json`
- Add a minimal run script that:
  - loads the model
  - sets one geometry
  - runs one study
  - extracts all modes
  - saves raw output
  - writes a small summary table
- Add an expected-output checklist rather than committing large raw simulation files.
- Add `.gitignore` rules for local models and large outputs.
- Add a small mock output only if it is sanitized and useful.
- Document required local variables:
  - model path
  - COMSOL server/LiveLink setup
  - study tag
  - dataset tag
  - parameter names
  - extraction variables
- Include failure diagnostics for connection, missing tags, no modes, and suspicious modes.

## Red flags

Fail if the AI:

- Suggests committing large `.mph` files by default.
- Assumes the test can run on GitHub Actions without COMSOL licensing.
- Hard-codes the user's local path.
- Only tests whether MATLAB syntax runs and ignores physical mode validity.

---

# Suggested First Test Batch

For the first round of AI evaluation, use:

```text
Test 000
Test 001
Test 002
Test 011
```

These tests do not require COMSOL or MATLAB execution.
They mainly check whether the AI can correctly understand the repository and avoid tool-induced source-format misdiagnosis.

For the second round, use:

```text
Test 003
Test 004
Test 005
Test 007
```

These tests check whether the AI understands mode sweeps, raw data saving, bound-mode filtering, and mode-family tracking.

For a later local runnable test, use:

```text
Test 010
Test 012
```

These tests require a local `.mph` model and a configured MATLAB-COMSOL LiveLink environment.

---

# Notes for Human Evaluators

A good AI answer does not need to match the wording in this file exactly.
It should match the workflow logic and avoid the listed red flags.

The most important failure modes to catch are:

- selecting the first COMSOL eigenmode by default
- trusting Q/loss without checking field confinement
- running a full sweep before single-point validation
- discarding raw mode data
- mixing computation and post-processing
- inventing missing COMSOL tags or model paths
- committing large private simulation files
- claiming line-break or syntax problems based only on unreliable GitHub raw-text extraction

