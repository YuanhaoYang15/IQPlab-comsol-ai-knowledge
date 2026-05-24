# Local Agent Execution with MATLAB/COMSOL LiveLink

This note records a successful local-agent test for running a MATLAB/COMSOL
LiveLink script through Codex.

The purpose of this test was workflow validation. It verified that an AI coding
agent can access a local repository, start MATLAB, connect to COMSOL LiveLink,
run a single-point script, and save numerical output. It did not validate the
final physical mode selection.

---

## Tested Workflow

The tested workflow was:

```text
Codex desktop app
        -> local repository workspace
        -> local terminal command execution
        -> MATLAB command-line startup
        -> COMSOL LiveLink MATLAB path
        -> COMSOL mphserver
        -> mphstart connection
        -> existing MATLAB LiveLink script
        -> saved .mat output
```

This workflow required sufficient local permissions for the Codex app.

---

## Environment Used in the Test

The local paths used in this test were:

```text
MATLAB executable:
D:\Matlab\R2025a\bin\matlab.exe

COMSOL root:
D:\Matlab\COMSOL63\Multiphysics

COMSOL LiveLink MATLAB path:
D:\Matlab\COMSOL63\Multiphysics\mli

COMSOL mphserver executable:
D:\Matlab\COMSOL63\Multiphysics\bin\win64\comsolmphserver.exe
```

These paths are machine-specific examples. They should not be treated as
portable repository defaults.

---

## Target Script

The tested script was:

```text
templates/matlab/comsol_extract_single_mode_point_template.m
```

The script used the model path, study tag, dataset tag, parameter names, and
result expressions already written in the file.

The test used a temporary wrapper under `local_outputs/` so that tracked
repository files were not edited during the first run.

---

## Key Startup Requirement

Simply running MATLAB with the COMSOL `mli` folder added to the MATLAB path was
not sufficient. MATLAB could find the LiveLink `.m` files, such as `mphload`,
`mphglobal`, and `mphinterp`, but the COMSOL Java API/server connection was not
initialized. In that case, the script failed at `ModelUtil.showProgress(...)`.

The successful workflow required:

1. starting or using a COMSOL `mphserver`;
2. adding the COMSOL `mli` folder to the MATLAB path;
3. calling `mphstart` from MATLAB;
4. using an absolute repository root or calling `cd(repoRoot)`;
5. running the target script after the COMSOL server connection was established.

A working wrapper pattern is:

```matlab
clear; clc;

repoRoot = 'D:\Project\NUS\Code\IQPlab-comsol-ai-knowledge';
comsolMli = 'D:\Matlab\COMSOL63\Multiphysics\mli';
targetScript = fullfile(repoRoot, 'templates', 'matlab', ...
    'comsol_extract_single_mode_point_template.m');

if exist(targetScript, 'file') ~= 2
    error('Wrapper:TargetScriptNotFound', ...
        'Target script not found:\n%s', targetScript);
end

cd(repoRoot);
addpath(comsolMli);

which mphstart
which mphload
which mphglobal
which mphinterp

mphstart;
run(targetScript);
```

Using an absolute repository root was important. A relative path from inside
`local_outputs/` failed because MATLAB's current working directory was not
necessarily the repository root.

For a long unattended sweep, the wrapper should not normally restart
`comsolmphserver` for every parameter point. That pattern is useful for
isolating a failing case, but it wastes startup time and can leave extra MATLAB
renderer helper processes on Windows. Prefer one persistent server connection
and per-point checkpoint saving; restart the server only when recovering from a
known LiveLink or model-state failure.

---

## Successful Test Result

The local-agent run successfully completed the single-point LiveLink script.

Observed status:

```text
MATLAB started: yes
mphstart connected to COMSOL server: yes, localhost:2036
Target script found: yes
Target script reached mphload: yes
COMSOL model loaded: yes
Study ran: yes
Candidate modes extracted: 10
Accepted modes after optional filter: 4
Output .mat saved: yes
```

The output was saved under `local_outputs/`, for example:

```text
local_outputs/single_mode_point_extraction_<timestamp>/
    single_mode_point_raw_and_processed.mat
```

Files under `local_outputs/` are local generated outputs and should normally
not be committed.

---

## Candidate Modes Versus Accepted Modes

The script intentionally extracts all returned eigenmodes first.

For the tested run, COMSOL returned ten candidate modes. The optional filter
was applied afterward, and four modes passed the relative imaginary-index
criterion.

This is expected behavior. The repository policy is to save raw candidate-mode
data before applying thresholds or filters. The raw candidate-mode count and
the filtered accepted-mode count should be interpreted separately.

The filter rule used in the script is:

```matlab
abs(imag(neff)) < abs(real(neff)) * cfg.relativeImagThreshold
```

Using `abs(imag(neff))` avoids accepting highly lossy modes only because of a
negative imaginary-part sign convention.

---

## What This Test Validates

This test validates the local execution workflow:

- Codex can access the local repository.
- Codex can run local terminal commands with sufficient permission.
- MATLAB can be launched from the local agent environment.
- MATLAB can find COMSOL LiveLink functions after adding the `mli` path.
- MATLAB can connect to a COMSOL server with `mphstart`.
- The existing single-point LiveLink template can load a model, run one study,
  extract returned modes, and save output.

---

## What This Test Does Not Validate

This test does not prove that the accepted modes are the final physical modes
for research analysis.

Further physical validation is still required:

- inspect mode profiles;
- check field confinement in the intended waveguide/core region;
- check whether accepted modes include PML, substrate, or radiation-like modes;
- verify `real(neff)`, `imag(neff)`, loss, and Q-like metrics;
- compare nearby geometries for continuity;
- use component-ratio or overlap-based mode-family checks when needed.

A successful LiveLink run means the toolchain works. It does not replace
single-geometry physical validation.

---

## Recommended Safe Agent Workflow

For future local-agent tests:

1. Check `git status` first.
2. Use temporary wrappers under `local_outputs/`.
3. Do not edit tracked files before the first run.
4. Do not commit or push from the agent unless explicitly requested.
5. Start with a single-point test.
6. Inspect saved raw and processed results.
7. Only then move to small sweeps.
8. Avoid full parameter sweeps until the single-point model is physically
   validated.

This workflow keeps AI-assisted automation useful while reducing the risk of
unintended file edits, expensive solver runs, or premature physical conclusions.

---

## Suggested Future Module

This test can be expanded into a future module such as:

```text
Module 06 — Local Agent Execution with MATLAB/COMSOL LiveLink
```

Possible contents:

- Codex or IDE-agent permission setup;
- MATLAB command-line startup checks;
- COMSOL `mli` path configuration;
- `mphserver` and `mphstart` connection checks;
- absolute-path wrapper pattern;
- single-point LiveLink execution;
- saved `.mat` summary checks;
- guidelines for agent-assisted debugging;
- warnings against launching full sweeps before validation.
