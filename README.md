# IQP Lab COMSOL AI Knowledge Base

This repository collects COMSOL simulation knowledge, MATLAB LiveLink templates, troubleshooting notes, and validation workflows for integrated photonics, nonlinear optics, and optomechanics simulations.

The goal is to provide a structured knowledge base that can be used by lab members, ChatGPT, Codex, or other AI coding assistants to reproduce, debug, and improve common COMSOL workflows.

## Repository Structure

- `docs/`  
  Structured COMSOL simulation notes, SOPs, and modeling guidelines.

- `templates/`  
  Reusable MATLAB LiveLink scripts, COMSOL automation templates, and post-processing scripts.

- `cases/`  
  Real simulation debugging cases, common mistakes, and lessons learned.

- `tests/`  
  Validation prompts and expected answer checklists for testing AI-assisted workflows.

## Main Topics

The current focus of this repository includes:

- Optical mode solving in COMSOL
- PML setup and bound-mode filtering
- Effective index, propagation loss, and Q-factor extraction
- MATLAB LiveLink automation
- Parameter sweeps over waveguide geometry
- Mode tracking across geometry sweeps
- Anisotropic lithium niobate material settings
- Common COMSOL warnings and debugging strategies
- Reproducible data saving and plotting workflows

## Intended Users

This repository is intended for:

- Lab members learning or reusing COMSOL workflows
- Researchers writing MATLAB LiveLink automation scripts
- AI assistants such as Codex or ChatGPT that need lab-specific simulation context

## How to Use This Repository

For human users:

1. Start from the relevant SOP in `docs/`.
2. Use scripts in `templates/` as starting points.
3. Check similar debugging cases in `cases/`.
4. Use the validation checklists in `tests/` before trusting simulation results.

For Codex or other AI coding assistants:

1. Read `AGENTS.md` first.
2. Use `docs/` as the main knowledge base.
3. Use `templates/` as coding references.
4. Use `cases/` to understand common failure modes.
5. Follow the validation checklist before accepting simulation results.

## General Simulation Principles

Before trusting a COMSOL result, check:

- Whether the field profile looks physical
- Whether the mode is confined in the intended region
- Whether the effective index is within a reasonable range
- Whether the Q factor or propagation loss is reasonable
- Whether the result changes smoothly with nearby parameters
- Whether the mesh is sufficiently converged
- Whether boundary conditions and PML settings are appropriate
- Whether material tensors and coordinate conventions are correctly defined

## Data and File Policy

Large COMSOL models, raw simulation data, and generated output files should not be committed to this repository by default.

Avoid committing:

- `.mph` files
- large `.mat` files
- raw measurement data
- private unpublished results
- temporary COMSOL recovery files
- automatically generated solver output

Commit only:

- reusable documentation
- lightweight scripts
- validated templates
- carefully selected example files
- troubleshooting notes
- AI instruction files

## Modules

### Module 01: LiveLink Environment Setup

Related files:

- `docs/livelink_environment_setup.md`
- `templates/check_livelink_connection.m`

Purpose:

This module explains how to configure MATLAB LiveLink for COMSOL and test whether MATLAB is connected to the COMSOL server.

### Module 02: Basic MATLAB LiveLink Workflow

Related files:

- `docs/matlab_livelink_basic_workflow.md`
- `templates/livelink_minimal_workflow.m`

Purpose:

This module explains how to load a COMSOL model, set parameters, run a study, extract results, and save data.

## Module 04 — Parameter Sweep and Batch Automation

Module 04 introduces MATLAB-controlled COMSOL parameter sweeps. The example
sweeps the waveguide width and extracts the effective index after each run.

Main files:

- `docs/matlab_livelink_parameter_sweep.md`
- `templates/livelink_parameter_sweep_scalar.m`
- `templates/livelink_parameter_sweep_postprocess.m`
- `templates/livelink_parameter_sweep_with_integral.m`
- `cases/case_002_waveguide_width_sweep.md`

Core idea:

```text
run expensive COMSOL simulations once
save compact sweep results
post-process many times in MATLAB
```


## Current Status

This repository is under active development. The first stage focuses on optical mode solving, PML-based bound-mode filtering, MATLAB LiveLink automation, and geometry parameter sweeps.

More modules may be added later, including acoustic simulations, optomechanical overlap calculations, thermal tuning, electro-optic simulations, and nonlinear photonics workflows.