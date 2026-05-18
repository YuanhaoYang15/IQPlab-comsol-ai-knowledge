# IQP Lab COMSOL AI Knowledge Base

This repository collects COMSOL simulation knowledge, MATLAB LiveLink templates, troubleshooting notes, and validation workflows for integrated photonics, nonlinear optics, and optomechanics simulations.

The goal is to provide a structured knowledge base that can be used by lab members, ChatGPT, Codex, or other AI coding assistants to reproduce, debug, and improve common COMSOL workflows.

The current teaching sequence focuses on MATLAB LiveLink for COMSOL optical mode-analysis workflows:

```text
Module 01  LiveLink environment setup
Module 02  Basic single-run LiveLink workflow
Module 03  Result extraction and post-processing
Module 04  Parameter sweep with bound-mode filtering
Module 05  Mode-family identification and overlap-based verification
```

---

## Repository Structure

```text
IQPlab-comsol-ai-knowledge/
├── docs/
├── templates/
├── cases/
├── examples/
├── tests/
├── AGENTS.md
├── README.md
├── .gitignore
└── .gitattributes
```

### `docs/`

Structured notes, SOP-style explanations, modeling guidelines, and module documentation.

Current documentation files include:

```text
docs/livelink_environment_setup.md
docs/matlab_livelink_basic_workflow.md
docs/matlab_livelink_result_extraction.md
docs/matlab_livelink_parameter_sweep.md
docs/matlab_livelink_mode_family_identification.md
```

### `templates/`

Reusable MATLAB LiveLink scripts and post-processing templates.

Current template files include:

```text
templates/check_livelink_connection.m
templates/livelink_minimal_workflow.m
templates/livelink_result_extraction_2d_fields.m
templates/livelink_parameter_sweep_bound_modes.m
templates/livelink_parameter_sweep_with_integral.m
templates/livelink_parameter_sweep_postprocess.m
templates/livelink_mode_family_component_ratio.m
templates/livelink_mode_family_component_postprocess.m
templates/livelink_mode_family_overlap_check.m
templates/livelink_mode_family_overlap_postprocess.m
```

### `cases/`

Case-study notes for real simulation workflows, validation checks, and debugging lessons.

Current case files include:

```text
cases/case_001_validation_before_sweep.md
cases/case_002_waveguide_width_sweep.md
cases/case_003_mode_family_identification.md
```

### `examples/`

Small teaching models or lightweight example files.

Large COMSOL models should generally not be committed. If an example `.mph` file is intentionally included, it should be small enough for GitHub and suitable for public sharing.

### `tests/`

Validation prompts, checklists, and expected answer patterns for AI-assisted workflows.

---

## Intended Users

This repository is intended for:

- lab members learning reusable COMSOL workflows;
- researchers writing MATLAB LiveLink automation scripts;
- users debugging optical mode-analysis simulations;
- users organizing parameter sweeps and post-processing pipelines;
- AI coding assistants such as ChatGPT, Codex, Claude, Gemini, Copilot, Cursor, or other local/agent-style tools that need lab-specific simulation context.

---

## Main Topics

The current focus includes:

- MATLAB LiveLink environment setup;
- loading and running existing COMSOL `.mph` models from MATLAB;
- setting COMSOL global parameters using MATLAB;
- reading scalar results with `mphglobal`;
- reading 2D field maps with `mphinterp`;
- using COMSOL-defined integration operators and variables;
- excluding PML regions from physical integrals;
- optical mode-analysis result extraction;
- effective index, propagation loss, and Q screening;
- parameter sweeps over waveguide geometry;
- all-mode extraction during geometry sweeps;
- bound-mode filtering using `imag(neff)`, loss, or Q thresholds;
- diagnostic field-fraction quantities such as `frac_E2_LN`;
- mode-family identification using component-ratio diagnostics;
- overlap-based mode continuity checks across geometry sweeps;
- reproducible data saving and post-processing.

---

## How to Use This Repository

### For human users

Recommended reading order:

```text
1. docs/livelink_environment_setup.md
2. docs/matlab_livelink_basic_workflow.md
3. docs/matlab_livelink_result_extraction.md
4. docs/matlab_livelink_parameter_sweep.md
5. docs/matlab_livelink_mode_family_identification.md
```

Recommended script order:

```text
1. templates/check_livelink_connection.m
2. templates/livelink_minimal_workflow.m
3. templates/livelink_result_extraction_2d_fields.m
4. templates/livelink_parameter_sweep_bound_modes.m
5. templates/livelink_parameter_sweep_with_integral.m
6. templates/livelink_parameter_sweep_postprocess.m
7. templates/livelink_mode_family_component_ratio.m
8. templates/livelink_mode_family_component_postprocess.m
9. templates/livelink_mode_family_overlap_check.m
10. templates/livelink_mode_family_overlap_postprocess.m
```

Recommended case-study order:

```text
1. cases/case_001_validation_before_sweep.md
2. cases/case_002_waveguide_width_sweep.md
3. cases/case_003_mode_family_identification.md
```

### For AI coding assistants

Read `AGENTS.md` first. It defines the expected assistant role, simulation validation checklist, and MATLAB LiveLink coding style.

Then use:

```text
docs/       for conceptual and workflow context
templates/  for runnable script patterns
cases/      for common mistakes and validation logic
tests/      for checking whether answers are trustworthy
```

The preferred response style is practical and reproducible: identify the model assumption, give complete code when appropriate, preserve raw results, and avoid trusting a mode only because COMSOL returned it.

---

## Using This Repository with AI Assistants

This repository is public so that lab members can give the repository URL directly to AI assistants. However, different AI tools access GitHub in different ways, and these access methods have different reliability levels.

### 1. Web/chatbot access

A simple chatbot can usually read this repository from the public GitHub URL:

```text
https://github.com/YuanhaoYang15/IQPlab-comsol-ai-knowledge
```

A recommended first prompt is:

```text
Please read README.md and AGENTS.md first. Then use this repository as the project context for COMSOL MATLAB LiveLink mode-analysis workflows.
```

This mode is convenient for:

- understanding the repository structure;
- reading documentation;
- answering workflow questions;
- using `tests/validation_prompts.md` for prompt-based AI evaluation;
- suggesting documentation or template improvements.

Limitations:

- web access may read cached or delayed repository content;
- browser-extracted GitHub raw files may display incorrect line breaks;
- the AI may not see the full repository consistently;
- the AI cannot run MATLAB or COMSOL;
- the AI cannot reliably inspect local `.mph` models, local paths, or generated output files.

### 2. GitHub connector access

Some AI assistants, including ChatGPT in supported modes, can connect to GitHub through a GitHub app or connector. This is usually better than raw web browsing because the assistant can search repository files more directly and may access private repositories if authorized.

Recommended usage:

```text
1. Connect the AI assistant to GitHub.
2. Grant access only to the repositories needed for the task.
3. Ask the assistant to read README.md and AGENTS.md before modifying or reviewing code.
4. Use tests/validation_prompts.md to evaluate whether the assistant follows repository rules.
```

For this repository, it is usually sufficient to grant access only to:

```text
YuanhaoYang15/IQPlab-comsol-ai-knowledge
```

Connector access is useful for:

- repository-level search;
- documentation review;
- template review;
- branch or pull-request style workflows, if the tool supports them.

Limitations:

- it may still rely on indexing or retrieval rather than a full local working tree;
- exact source formatting should still be verified if a formatting issue is suspected;
- it usually cannot run MATLAB/COMSOL unless connected to a local or configured compute environment.

### 3. Local clone / IDE agent access

For serious code review, debugging, or runnable tests, the most reliable workflow is to clone the repository locally and open it in an AI coding environment such as Cursor, VS Code Copilot, Claude Code, Codex CLI, Aider, or another local agent.

Recommended local setup:

```bash
git clone https://github.com/YuanhaoYang15/IQPlab-comsol-ai-knowledge.git
cd IQPlab-comsol-ai-knowledge
```

This mode is preferred when the AI needs to:

- inspect the real file tree;
- verify real line breaks and indentation;
- check `git status` or `git diff`;
- edit multiple files consistently;
- use local MATLAB, COMSOL, LiveLink, or Python environments;
- run local validation scripts;
- access local `.mph` models that should not be committed to GitHub.

For COMSOL workflows, local clone plus local MATLAB/COMSOL access is the only realistic route for true end-to-end runnable validation.

### Recommended access level by task

| Task | Recommended AI access method |
|---|---|
| Understand README, AGENTS, and docs | Public GitHub URL or GitHub connector |
| Prompt-based AI validation | Public GitHub URL or GitHub connector |
| Documentation editing | GitHub connector or local clone |
| MATLAB template review | GitHub connector, preferably local clone |
| Cross-file refactoring | Local clone / IDE agent |
| Check exact line breaks or formatting | Local clone or GitHub source view |
| Run MATLAB syntax checks | Local clone with MATLAB |
| Run COMSOL LiveLink validation | Local clone with MATLAB + COMSOL |
| Open branch or pull request | GitHub connector or GitHub coding agent |

### Source-format and line-break warning

When an AI assistant reads GitHub files through a browser or raw-text extraction tool, it may incorrectly display many source-code lines as one long line. This can create false claims that a MATLAB, Python, Markdown, or LSF file has broken line breaks.

Therefore:

- do not trust raw web-extracted line counts as ground truth;
- do not claim a source file is broken only because `raw.githubusercontent.com` appears to merge lines;
- cross-check with the GitHub blob/source page, a local `git clone`, GitHub API content, or a user-uploaded file;
- if the code runs locally, local execution is strong evidence that the apparent line-break issue is a tool-reading artifact;
- if exact formatting matters, ask for a local clone, uploaded file, or direct source view before proposing formatting fixes.

### Recommended collaboration model for lab members

For general use:

```text
Public repository URL → chatbot or GitHub connector → README.md + AGENTS.md first
```

For reliable coding work:

```text
Local git clone → AI coding assistant / IDE agent → inspect files and git diff locally
```

For true COMSOL validation:

```text
Local git clone
        + local .mph model
        + local MATLAB/COMSOL LiveLink setup
        + single-geometry validation
        + small sweep
        + full sweep only after validation
```

For repository contributions:

```text
Fork + pull request
```

or, for trusted maintainers:

```text
collaborator branch + pull request
```

Do not give direct push access unless the user is expected to maintain the repository.

---

## General Simulation Principles

Before trusting a COMSOL result, check:

- whether the field profile looks physical;
- whether the mode is confined in the intended region;
- whether the effective index is within a reasonable range;
- whether the Q factor or propagation loss is reasonable;
- whether the result changes smoothly with nearby parameters;
- whether the mesh is sufficiently converged;
- whether boundary conditions and PML settings are appropriate;
- whether material tensors and coordinate conventions are correctly defined;
- whether the selected dataset and solution number are correct.

For optical mode-analysis workflows, do not assume that `solnum = 1` is always the desired physical mode. During a geometry sweep, COMSOL may return several eigenmodes, and their ordering can change. Always inspect or save all returned modes before making a final selection.

---

## Module 01 — LiveLink Environment Setup

### Purpose

Module 01 explains how to configure MATLAB LiveLink for COMSOL and verify that MATLAB can communicate with the COMSOL server.

It covers:

- the COMSOL-MATLAB client-server relationship;
- COMSOL installation and MATLAB installation paths;
- starting COMSOL with MATLAB;
- manually connecting MATLAB to a COMSOL server;
- first-time local username/password setup;
- common setup problems.

### Related files

```text
docs/livelink_environment_setup.md
templates/check_livelink_connection.m
```

### Core idea

```text
Configure LiveLink correctly
        ↓
Start MATLAB with a COMSOL server connection
        ↓
Run a minimal connection test
        ↓
Only then run larger automation scripts
```

### Typical first test

```matlab
clear; clc;

import com.comsol.model.*
import com.comsol.model.util.*

ModelUtil.showProgress(true);
mphtags
```

If `mphtags` runs without error, MATLAB is connected to a COMSOL server.

---

## Module 02 — Basic MATLAB LiveLink Workflow

### Purpose

Module 02 introduces the basic single-run workflow for controlling an existing COMSOL model from MATLAB.

It focuses on how to:

- load an existing `.mph` model using `mphload`;
- set model parameters using `model.param.set`;
- run an existing study;
- extract simple scalar results;
- save results for later analysis;
- optionally open the in-memory model in COMSOL GUI using `mphlaunch(model)`.

### Related files

```text
docs/matlab_livelink_basic_workflow.md
templates/livelink_minimal_workflow.m
```

### Core idea

```text
Build and validate the model in COMSOL GUI
        ↓
Load the model from MATLAB
        ↓
Modify selected parameters
        ↓
Run an existing study
        ↓
Extract and save results
```

### Recommended model preparation

Before using the template, the `.mph` model should already contain:

- global parameters that MATLAB will modify;
- working geometry and mesh;
- material definitions;
- physics interfaces;
- a study that runs successfully in COMSOL GUI;
- a result dataset that can be evaluated from MATLAB.

Module 02 intentionally does not construct the whole COMSOL model from scratch. The beginner-friendly workflow is to validate the model in the GUI first, then use LiveLink for reproducible automation.

---

## Module 03 — Result Extraction and Post-processing

### Purpose

Module 03 explains how to extract numerical results from an existing COMSOL model using MATLAB LiveLink.

It focuses on common post-processing tasks for 2D integrated photonics, electrostatic, acoustic, and coupled simulations:

- reading scalar quantities using `mphglobal`;
- reading multiple returned mode values;
- extracting 2D field distributions using `mphinterp`;
- understanding when to use `mpheval`;
- defining integration operators in COMSOL;
- reading user-defined integral variables from MATLAB;
- excluding PML domains from physical integrals;
- using `mphlaunch(model)` to inspect suspicious results;
- saving extracted data and metadata for reproducible plotting.

### Related files

```text
docs/matlab_livelink_result_extraction.md
templates/livelink_result_extraction_2d_fields.m
```

### Core idea

```text
Solve or load a validated model
        ↓
Extract scalar results with mphglobal
        ↓
Extract 2D fields with mphinterp
        ↓
Read predefined integral variables
        ↓
Save numerical results and metadata
        ↓
Plot from saved data, not only from the COMSOL GUI
```

### Typical scalar extraction

```matlab
neff = mphglobal(model, 'ewfd.neff', ...
    'dataset', cfg.datasetTag, ...
    'solnum', 'all', ...
    'Complexout', 'on');

frac_E2_LN = mphglobal(model, 'frac_E2_LN', ...
    'dataset', cfg.datasetTag, ...
    'solnum', 'all', ...
    'Complexout', 'on');
```

### Typical 2D field extraction

```matlab
x = linspace(-3e-6, 3e-6, 301);
y = linspace(-2e-6, 2e-6, 201);

[X, Y] = meshgrid(x, y);
coord = [X(:).'; Y(:).'];

E = mphinterp(model, 'ewfd.normE', ...
    'coord', coord, ...
    'edim', 'domain', ...
    'dataset', cfg.datasetTag, ...
    'solnum', cfg.solnum);

E = reshape(E, size(X));
```

### Important post-processing rule

For physical integrals, PML domains should usually be excluded. PML fields are affected by artificial absorbing-coordinate transformations and should not be interpreted as normal physical energy density. PML-domain integrals can still be useful as diagnostics for leaky or suspicious modes.

---

## Module 04 — Parameter Sweep with Bound-Mode Filtering

### Purpose

Module 04 introduces MATLAB-controlled COMSOL parameter sweeps for optical mode-analysis workflows.

The example sweeps waveguide width, reads all returned modes at each sweep point, estimates propagation loss from `imag(neff)`, filters acceptable bound modes using loss or Q thresholds, and saves reusable mode-level results for later post-processing.

This module also includes an all-mode integral diagnostic workflow for comparing `imag(neff)`-based loss against predefined confinement indicators such as `frac_E2_LN`.

### Related files

```text
docs/matlab_livelink_parameter_sweep.md
templates/livelink_parameter_sweep_bound_modes.m
templates/livelink_parameter_sweep_with_integral.m
templates/livelink_parameter_sweep_postprocess.m
cases/case_002_waveguide_width_sweep.md
```

### Core idea

```text
Set up a validated mode-analysis model
        ↓
Request multiple modes per sweep point
        ↓
Sweep waveguide width using model.param.set
        ↓
Run the COMSOL study at each width
        ↓
Read all returned ewfd.neff values
        ↓
Estimate loss and Q from imag(neff)
        ↓
Filter acceptable bound modes
        ↓
Save raw and processed results
        ↓
Post-process without rerunning COMSOL
```

### Bound-mode filtering metric

For a complex effective index,

```text
neff = real(neff) + i imag(neff)
```

and free-space wavelength `lambda0`,

```text
beta = k0*neff
k0   = 2*pi/lambda0
```

Assuming:

```text
E(z) ~ exp(i*beta*z)
```

the power attenuation coefficient can be estimated as:

```text
alpha_power = 2*k0*abs(imag(neff))
```

and the loss can be converted to:

```text
loss_dB_per_m  = 10*log10(exp(1))*alpha_power
loss_dB_per_cm = loss_dB_per_m/100
```

A rough Q screening metric is:

```text
Q_est = real(neff)/(2*abs(imag(neff)))
```

This is a useful screening metric. For final quantitative analysis, check the COMSOL eigenvalue convention and consider using group index instead of phase index.

### Main sweep script

Use:

```text
templates/livelink_parameter_sweep_bound_modes.m
```

This script should:

- set the waveguide-width parameter;
- run the mode-analysis study;
- read all returned `ewfd.neff` values;
- compute loss and `Q_est`;
- filter accepted modes by threshold;
- sort accepted modes;
- save raw mode-level data and summary tables.

Example threshold settings:

```matlab
cfg.useLossThreshold  = true;
cfg.maxLoss_dB_per_cm = 10;

cfg.useQThreshold = false;
cfg.minQ_est      = 1e5;
```

### All-mode integral diagnostic script

Use:

```text
templates/livelink_parameter_sweep_with_integral.m
```

This script is intended to save all returned modes and their predefined integral quantities. It should not filter modes and should not make plots.

Example expressions:

```matlab
cfg.resultExprList = {
    'ewfd.neff'
    'frac_E2_LN'
};
```

This diagnostic workflow is useful for checking whether `frac_E2_LN` selects the same physically meaningful bound modes as small `imag(neff)` or low propagation loss.

### Post-processing script

Use:

```text
templates/livelink_parameter_sweep_postprocess.m
```

This script should not run COMSOL. It should only load saved results, regenerate plots, export summary tables, and allow threshold re-analysis.

Recommended manual selection:

```matlab
cfgPost.resultFormat = 'bound_modes';
```

or:

```matlab
cfgPost.resultFormat = 'integral_all_modes';
```

Recommended options:

```text
'bound_modes'
    Post-process threshold-filtered bound-mode results.

'integral_all_modes'
    Post-process all-mode predefined-integral diagnostic results.

'integral_single_mode'
    Support older single-mode integral results.

'auto'
    Infer the format from sweep_raw.mat.
```

For teaching and debugging, manual selection is usually clearer than fully automatic dispatch.

---

## Module 05 — Mode-Family Identification and Overlap-Based Verification

Module 05 distinguishes mode families after Module 04 has filtered acceptable bound modes.

Main goals:

```text
1. Use LiveLink-defined COMSOL integration variables to classify Ex/Ey-dominant modes.
2. Control the requested number of solved modes using a global Nmode parameter.
3. Filter lossy modes before mode-family analysis.
4. Use normalized field-overlap integrals to verify mode similarity near crossings.
5. Keep COMSOL run scripts separate from post-processing scripts.
```

Related files:

```text
docs/matlab_livelink_mode_family_identification.md

templates/livelink_mode_family_component_ratio.m
templates/livelink_mode_family_component_postprocess.m
templates/livelink_mode_family_overlap_check.m
templates/livelink_mode_family_overlap_postprocess.m

cases/case_003_mode_family_identification.md
```

Core idea:

```text
Part A:
    define component-integral variables in COMSOL
    read accepted-mode Ex/Ey fractions
    classify Ex_dominant, Ey_dominant, and hybrid modes

Part B:
    choose suspicious neighboring width points
    interpolate fields for accepted modes
    compute overlap matrices
    distinguish field continuity from physical-character exchange
```

A diagonal overlap matrix means that neighboring eigenmode branches are field-continuous under the current sorting rule. A change in `Ex_frac_xy` or `Ey_frac_xy` along that diagonal branch means that the physical mode character is changing, which is typical near avoided crossings.

---

## Recommended Output Policy

Run scripts should save generated results under:

```text
local_outputs/
```

Example output folders:

```text
local_outputs/
├── waveguide_width_bound_mode_sweep_YYYYMMDD_HHMMSS/
└── waveguide_width_sweep_with_integral_all_modes_YYYYMMDD_HHMMSS/
```

These folders should not be committed to GitHub.

A typical sweep folder may contain:

```text
sweep_config.mat
sweep_raw.mat
sweep_summary.csv
sweep_all_modes.csv
sweep_point_summary.csv
```

Large generated files should stay local unless they are deliberately selected as small teaching examples.

---

## Data and File Policy

Large COMSOL models, raw simulation data, and generated output files should not be committed to this repository by default.

Avoid committing:

```text
*.mph
*.mphbin
*.mph.lock
*.mat
*.h5
*.hdf5
*.dat
*.csv
local_outputs/
```

Exceptions can be made for small teaching examples, such as:

```text
examples/**/*.mph
examples/**/*.csv
```

Only commit:

- reusable documentation;
- lightweight scripts;
- validated templates;
- carefully selected public example files;
- troubleshooting notes;
- AI instruction files.

Do not commit:

- real COMSOL server passwords;
- personal usernames;
- license server information;
- private IP addresses;
- private unpublished data;
- large raw simulation outputs.

---

## Validation Before Large Sweeps

Before launching a large parameter sweep:

1. run a single geometry in the COMSOL GUI;
2. confirm the field profile is physical;
3. confirm `real(neff)` is reasonable;
4. estimate loss or Q from `imag(neff)`;
5. check that PML modes are not mistaken for guided modes;
6. test MATLAB extraction on one solved model;
7. save one small reference output;
8. only then run the full sweep.

A parameter sweep should not be used to compensate for an unvalidated single-point model.

---

## Current Status

The first five modules are now the core LiveLink teaching sequence:

```text
Module 01  Environment setup
Module 02  Basic model loading, solving, and scalar extraction
Module 03  Result extraction, 2D field maps, and integral variables
Module 04  Parameter sweep with all-mode extraction and bound-mode filtering
Module 05  Mode-family identification and overlap-based verification
```

Future modules may include:

- mode branch stitching across geometry sweeps;
- radiation-loss and bending-loss workflows;
- anisotropic lithium niobate tensor setup;
- acoustic and optomechanical simulations;
- electrostatic tuning simulations;
- thermal tuning simulations;
- nonlinear overlap calculations;
- optimization loops and batch-run management.

---

## Repository Development Notes

This repository is under active development. When adding a new module:

1. add the explanatory note in `docs/`;
2. add runnable templates in `templates/`;
3. add a representative case in `cases/` when useful;
4. update this `README.md`;
5. avoid committing generated `local_outputs/`;
6. keep scripts reproducible and configurable from the top user-configuration block.
