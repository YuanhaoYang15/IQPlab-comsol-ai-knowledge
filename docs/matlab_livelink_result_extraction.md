# MATLAB LiveLink for COMSOL: Result Extraction and Post-processing

## Purpose

This module explains how to extract numerical results from an existing COMSOL model using MATLAB LiveLink.

It focuses on common post-processing tasks for 2D integrated photonics, electrostatic, acoustic, and coupled simulations:

- reading scalar results using `mphglobal`,
- extracting 2D field distributions using `mphinterp`,
- understanding when to use `mpheval`,
- defining integration operators in COMSOL,
- reading user-defined integral variables from MATLAB,
- excluding PML domains from physical integrals,
- using `mphlaunch(model)` to inspect suspicious results in the COMSOL GUI,
- saving extracted data for reproducible plotting.

This module assumes that the model can already be loaded and solved through the basic LiveLink workflow.

Recommended prerequisite:

```text
docs/matlab_livelink_basic_workflow.md
templates/livelink_minimal_workflow.m
```

## 1. Recommended Model Preparation in COMSOL

For a beginner-friendly workflow, define the main post-processing objects in the COMSOL GUI first, then read them from MATLAB.

The `.mph` model should ideally contain:

- named selections for important regions,
- integration operators for selected domains,
- variables that evaluate useful integrated quantities,
- at least one manually validated result expression,
- a solved reference case checked in the COMSOL GUI.

This approach keeps the physics and region definitions visible in the GUI and makes the MATLAB script simpler and more reliable.

## 2. Result Expressions

A result expression is any COMSOL expression that can be evaluated after solving the model.

Examples include:

```text
ewfd.neff
ewfd.normE
ewfd.Ex
ewfd.Ey
ewfd.Ez
es.normE
solid.disp
solid.u
solid.v
solid.w
freq
```

User-defined variables can also be result expressions. For example, if the model defines:

```text
E2_physical
E2_LN
frac_E2_LN
```

then MATLAB can read them using:

```matlab
frac_E2_LN = mphglobal(model, 'frac_E2_LN');
```

The exact variable names depend on the physics tag and the model definitions.

## 3. Global Evaluation with `mphglobal`

Use `mphglobal` to evaluate scalar or solution-level quantities.

Typical use cases:

```text
effective index
frequency
Q factor
integrated quantities
energy fractions
overlap factors
user-defined variables
```

Example:

```matlab
neff = mphglobal(model, 'ewfd.neff');
freq = mphglobal(model, 'freq');
```

For user-defined variables:

```matlab
E2_physical = mphglobal(model, 'E2_physical');
E2_LN = mphglobal(model, 'E2_LN');
frac_E2_LN = mphglobal(model, 'frac_E2_LN');
```

If the model has multiple solutions, such as multiple eigenmodes, the returned value may contain multiple entries. The script should record all returned values rather than silently assuming only one solution exists.

## 4. Extracting 2D Field Distributions with `mphinterp`

For 2D field maps, a convenient approach is to interpolate the COMSOL solution onto a regular MATLAB grid.

Example:

```matlab
x = linspace(-3e-6, 3e-6, 301);
y = linspace(-2e-6, 2e-6, 201);
[X, Y] = meshgrid(x, y);

coord = [X(:)'; Y(:)'];

E = mphinterp(model, 'ewfd.normE', ...
    'coord', coord, ...
    'edim', 'domain');

E = reshape(E, size(X));
```

Important points:

- For a 2D model, `coord` should have size `2 × N`.
- Each column of `coord` is one evaluation point.
- Use `edim = 'domain'` for domain field quantities.
- Use `edim = 'boundary'` for boundary quantities.
- Coordinates are usually passed in SI units, unless the model has been set up otherwise.
- If the expression is complex, decide whether to save the complex value, absolute value, real part, imaginary part, or phase.

For optical fields, common expressions include:

```text
ewfd.normE
ewfd.Ex
ewfd.Ey
ewfd.Ez
```

For electrostatic fields:

```text
es.normE
es.Ex
es.Ey
es.Ez
```

For mechanical displacement:

```text
solid.disp
solid.u
solid.v
solid.w
```

The exact available components depend on the model dimension and physics interface.

## 5. `mphinterp` vs `mpheval`

The two functions are useful for different post-processing styles.

Use `mphinterp` when:

- you want values on a regular grid,
- you want a line cut,
- you want values at specific coordinates,
- you want easy plotting with `imagesc`, `pcolor`, `surf`, or `contourf`.

Use `mpheval` when:

- you want field values on COMSOL mesh points,
- you want mesh-based data,
- you want to inspect the finite-element solution more directly.

For most beginner 2D field-plotting workflows, `mphinterp` on a regular grid is easier to use.

## 6. Named Selections for Post-processing

Named selections are strongly recommended because they give physical names to important domains or boundaries.

For a model with PML, it is useful to separate material selections from post-processing selections.

Example material selections:

```text
sel_LN_all
sel_SiO2_all
sel_Air_all
```

These may include both physical domains and PML domains, because PML regions still need material properties.

Example physical post-processing selections:

```text
sel_physical_domains
sel_LN_physical
sel_SiO2_physical
sel_Air_physical
```

These should exclude PML domains.

Example PML diagnostic selections:

```text
sel_pml_left
sel_pml_right
sel_pml_all
```

These are useful for checking leakage or spurious modes, but should not be included in physical integrals.

## 7. Integration Operators

For domain integrals, define integration operators in COMSOL:

```text
Component 1 → Definitions → Component Couplings → Integration
```

Recommended examples:

```text
intop_physical
selection: sel_physical_domains

intop_LN_physical
selection: sel_LN_physical

intop_pml
selection: sel_pml_all
```

For physical quantities such as mode confinement, mode area, energy fraction, and overlap integrals, integration should normally be performed only over non-PML physical domains.

PML domains are numerical absorbing regions. Fields inside PML depend on artificial absorbing coordinate transformations and should not be interpreted as physical fields.

PML-domain integrals can still be useful as diagnostics. For example, a large PML field integral may indicate a leaky mode, radiation-like mode, or problematic PML setup.

## 8. User-defined Integral Variables

After defining integration operators, define variables in:

```text
Component 1 → Definitions → Variables
```

For the teaching example model, useful variables include:

```text
E2_physical = intop_physical(ewfd.normE^2)
E2_LN       = intop_LN_physical(ewfd.normE^2)
E2_pml      = intop_pml(ewfd.normE^2)

frac_E2_LN  = E2_LN/E2_physical
frac_E2_pml = E2_pml/E2_physical
```

These are simple teaching examples. They are not intended to be rigorous definitions of electromagnetic energy, optical mode area, or nonlinear overlap.

For more rigorous optical energy or overlap calculations, the integrand should be chosen carefully based on the relevant physical theory.

## 9. Reading Integral Variables from MATLAB

Once the variables are defined in COMSOL, MATLAB can read them directly:

```matlab
E2_physical = mphglobal(model, 'E2_physical');
E2_LN = mphglobal(model, 'E2_LN');
E2_pml = mphglobal(model, 'E2_pml');

frac_E2_LN = mphglobal(model, 'frac_E2_LN');
frac_E2_pml = mphglobal(model, 'frac_E2_pml');
```

Alternatively, MATLAB can evaluate the integration operator directly:

```matlab
E2_LN = mphglobal(model, 'intop_LN_physical(ewfd.normE^2)');
```

For beginner workflows, it is usually clearer to define the variable in COMSOL and read the variable name in MATLAB.

## 10. Using `mphlaunch` for GUI Inspection

`mphlaunch(model)` opens the current COMSOL model object in the COMSOL GUI.

It is useful when MATLAB result extraction gives suspicious or unexpected results.

Example:

```matlab
mphlaunch(model);
```

Typical cases where `mphlaunch(model)` is helpful:

- checking whether named selections cover the intended domains or boundaries,
- checking whether integration operators use the correct selections,
- checking whether variables such as `frac_E2_LN` are defined correctly,
- checking whether the selected dataset corresponds to the intended solution,
- comparing MATLAB-interpolated field maps with COMSOL GUI field plots,
- inspecting mode profiles, mesh, PML regions, and boundary conditions.

Important behavior:

```text
mphload(modelPath)
→ loads the .mph file into the COMSOL server memory

MATLAB operations
→ modify the in-memory model object

mphlaunch(model)
→ opens the current in-memory model in the GUI
```

By default, `mphlaunch(model)` does not overwrite the original `.mph` file. The original file is changed only if the model is explicitly saved, for example by clicking Save in the COMSOL GUI or by calling `mphsave`.

Recommended practice:

- Use `mphlaunch(model)` as a diagnostic tool.
- Do not click Save unless you intentionally want to update the `.mph` file.
- If saving a modified model is needed, save it under a new name.

## 11. Dataset and Solution Selection

If a model has multiple datasets or multiple solutions, result extraction may require explicit dataset or solution selection.

Common cases include:

```text
multiple eigenmodes
frequency sweep
parameter sweep
multiple studies
several solution datasets
```

For simple examples, MATLAB often uses the active or default dataset. For more complex models, specify the dataset, solution number, or parameter index explicitly.

When results look wrong, check:

- which dataset is active,
- whether the intended study has been solved,
- whether the desired mode or solution index is selected,
- whether the result expression is defined on the selected dataset.

`mphlaunch(model)` is often the fastest way to inspect these dataset and solution settings visually.

## 12. Complex Fields

Frequency-domain electromagnetic and acoustic fields may be complex.

For field maps, decide which representation is physically meaningful:

```text
abs(field)
real(field)
imag(field)
angle(field)
abs(field)^2
```

For example:

```matlab
E = mphinterp(model, 'ewfd.Ez', 'coord', coord, 'edim', 'domain');
E_abs = abs(E);
E_phase = angle(E);
```

Do not accidentally compare a complex field directly as if it were a real scalar field.

## 13. Saving Results

A result-extraction script should save:

- global scalar results,
- field-map grids,
- extracted field values,
- model path,
- study tag,
- expression names,
- grid range and resolution,
- timestamp,
- script path.

This makes plots reproducible and avoids relying only on figures.

Recommended output folder:

```text
local_outputs/
```

This folder should normally be ignored by Git.

## 14. Common Problems

### Problem 1: `mphglobal` cannot evaluate an expression

Check:

- the expression name,
- the physics tag,
- whether the study has been solved,
- whether the expression is defined on the active dataset,
- whether a user-defined variable exists in the correct component.

### Problem 2: `mphinterp` returns unexpected values or NaNs

Check:

- whether the coordinates are inside the model domain,
- whether the coordinate array has size `dimension × number_of_points`,
- whether `edim` is appropriate,
- whether the dataset is correct,
- whether the solution exists.

### Problem 3: The field map is flipped or distorted

Check:

- whether `X` and `Y` are reshaped correctly,
- whether units are consistent,
- whether `axis image` and `set(gca, 'YDir', 'normal')` are used for plotting.

### Problem 4: Integral values include PML contributions

Check:

- whether the integration operator selection excludes PML domains,
- whether physical and PML selections are separated,
- whether variables such as `E2_physical` are based on `sel_physical_domains`.

### Problem 5: Multiple modes are returned

For mode analysis, expressions such as `ewfd.neff` may return multiple values. Record all values, and later decide which mode is physically relevant using field profiles, confinement, loss, polarization, or mode tracking.

### Problem 6: MATLAB and COMSOL GUI results do not look the same

Check:

- whether MATLAB and GUI are using the same dataset,
- whether the same solution number is being used,
- whether the field representation is the same,
- whether MATLAB is plotting `abs`, `real`, `imag`, or `phase`,
- whether the interpolation grid covers the same region shown in COMSOL.

Use `mphlaunch(model)` to inspect the current in-memory model and compare the GUI result with MATLAB extraction.

## 15. Recommended Template

The corresponding template script is:

```text
templates/livelink_result_extraction_2d_fields.m
```

This script demonstrates how to:

- load the teaching model,
- run the study,
- read `ewfd.neff`,
- read user-defined integral variables,
- interpolate `ewfd.normE` on a 2D grid,
- plot the field map,
- optionally open the current model in COMSOL GUI using `mphlaunch(model)`,
- save results and metadata.
