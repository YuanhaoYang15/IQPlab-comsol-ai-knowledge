# 2D Axisymmetric Single-Waveguide Example for Coupled-Q Analysis

This folder is reserved for a lightweight COMSOL example model used by Module 06.

Expected model file:

```text
LN_ridge_2dsym_single_waveguide_example.mph
```

The file should be created by cleaning a validated local 2D axisymmetric lithium-niobate ridge-waveguide optical mode model and saving it here.

The model should contain only the minimum information needed for the teaching workflow:

- one movable active ridge waveguide;
- one optical mode-analysis study;
- one result dataset;
- required field expressions and TE/TM diagnostic variables;
- no private local paths;
- no large stored solution data unless intentionally needed for the example.

The MATLAB template `templates/livelink_coupled_q_2dsym_run.m` expects this file by default.

Before committing the `.mph` file, please check:

1. The file opens locally in COMSOL.
2. The file can be loaded with `mphload`.
3. The result data have been cleared if the file size is large.
4. The model contains no confidential project data.
5. The model parameter names match `expected_model_variables.md`.
