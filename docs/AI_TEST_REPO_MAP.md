# AI Test Repository Map

This file is a quick orientation guide for a new AI coding assistant working
with the IQP Lab COMSOL AI knowledge base.

The repository collects COMSOL simulation guidance, MATLAB LiveLink script
templates, validation cases, and AI evaluation prompts for integrated
photonics, nonlinear optics, and optomechanics workflows.

It is meant to help lab members and AI assistants reproduce common workflows,
debug suspicious simulation results, write safer MATLAB LiveLink scripts, and
separate expensive COMSOL solving from cheaper post-processing.

It is not meant to contain all private COMSOL `.mph` models, large simulation
outputs, confidential lab data, or machine-specific configuration files.

## Major Folders and Files

Top-level stable orientation files:

- `README.md` gives the main repository overview, module sequence, file
  structure, and usage model.
- `AGENTS.md` gives assistant-specific rules, simulation principles, coding
  style, validation checklists, and repository safety policy.
- `.gitignore` and `.gitattributes` define repository hygiene and source
  handling rules.

Main folders:

- `docs/` contains conceptual workflow notes and module documentation.
- `templates/` contains reusable MATLAB LiveLink scripts and post-processing
  patterns.
- `cases/` contains validated workflow cases, debugging lessons, and
  interpretation guidance.
- `tests/` contains AI validation prompts and expected-answer checklists.
- `examples/` contains lightweight teaching examples only.
- `local_outputs/` is for generated local results and should normally not be
  committed.

Current documentation files:

- `docs/livelink_environment_setup.md`
- `docs/matlab_livelink_basic_workflow.md`
- `docs/matlab_livelink_result_extraction.md`
- `docs/matlab_livelink_parameter_sweep.md`
- `docs/matlab_livelink_mode_family_identification.md`

Current template files:

- `templates/check_livelink_connection.m`
- `templates/livelink_minimal_workflow.m`
- `templates/livelink_result_extraction_2d_fields.m`
- `templates/livelink_parameter_sweep_bound_modes.m`
- `templates/livelink_parameter_sweep_with_integral.m`
- `templates/livelink_parameter_sweep_postprocess.m`
- `templates/livelink_mode_family_component_ratio.m`
- `templates/livelink_mode_family_component_postprocess.m`
- `templates/livelink_mode_family_overlap_check.m`
- `templates/livelink_mode_family_overlap_postprocess.m`

Current case files:

- `cases/case_001_validation_before_sweep.md`
- `cases/case_002_waveguide_width_sweep.md`
- `cases/case_003_mode_family_identification.md`

Current AI validation file:

- `tests/validation_prompts.md`

## Recommended Reading Order

Start with:

1. `README.md`
2. `AGENTS.md`

Then read the module documentation in order:

1. `docs/livelink_environment_setup.md`
2. `docs/matlab_livelink_basic_workflow.md`
3. `docs/matlab_livelink_result_extraction.md`
4. `docs/matlab_livelink_parameter_sweep.md`
5. `docs/matlab_livelink_mode_family_identification.md`

For practical examples, read the cases after the matching module:

1. `cases/case_001_validation_before_sweep.md`
2. `cases/case_002_waveguide_width_sweep.md`
3. `cases/case_003_mode_family_identification.md`

For AI evaluation tasks, read `tests/validation_prompts.md` before judging
whether another assistant answer passes or fails.

## Stable Instructions Versus Examples and Templates

Treat these files as stable instruction sources:

- `README.md`
- `AGENTS.md`
- `tests/validation_prompts.md`
- The conceptual documentation under `docs/`

These files define repository expectations, assistant behavior, simulation
validation principles, and evaluation criteria. They should guide how an AI
assistant interprets or edits the rest of the repository.

Treat these files as examples or reusable patterns:

- MATLAB scripts under `templates/`
- Case-study notes under `cases/`
- Lightweight teaching files under `examples/`

Templates are intended to be adapted to a real local COMSOL model. They may
contain example model paths, study tags, dataset tags, parameter names, and
COMSOL expressions that must be checked against the actual `.mph` file before
running.

Cases explain validated workflows and common mistakes. They are especially
useful for understanding how to diagnose suspicious modes, avoid premature
large sweeps, and preserve raw simulation data.

## New AI Assistant Starting Checklist

Before giving simulation advice or editing scripts:

1. Read `README.md` and `AGENTS.md`.
2. Identify the relevant module and matching template.
3. Check whether the task needs documentation review, code editing, local
   MATLAB execution, or COMSOL LiveLink validation.
4. Do not claim MATLAB, COMSOL, or LiveLink tests were run unless they were
   actually run in an environment with those tools.
5. Do not assume `solnum = 1` or the first returned eigenmode is the physical
   target mode.
6. Recommend single-geometry validation before any large parameter sweep.
7. Preserve raw candidate-mode data before applying thresholds or filters.
8. Keep COMSOL run scripts separate from cheap post-processing scripts when
   possible.

## Line-ending and Markdown formatting caution

Do not claim that a Markdown, MATLAB, Python, or LSF file has broken line
breaks based only on a raw web-extraction view.

Some browser or AI web tools may display GitHub raw text with compressed,
merged, or otherwise misleading line breaks. That display artifact is not the
same thing as the actual file content.

Before diagnosing line-ending or source-format problems, verify with a
reliable source such as:

- a local git clone;
- GitHub blob/source view;
- GitHub API or connector file content;
- a user-uploaded source file;
- actual local syntax checking or execution.

If a file runs locally, treat that as strong evidence that a raw-web
line-break issue is only a tool-rendering artifact unless reliable contrary
evidence is available.

When reporting a real formatting problem, cite exact file paths and line
numbers, and explain the evidence. Avoid vague claims that a file is broken
because a web view showed unusually long or merged lines.
