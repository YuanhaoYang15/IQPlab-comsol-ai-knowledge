# MATLAB LiveLink for COMSOL: Basic Workflow

## Purpose

This note introduces the basic single-run workflow for controlling an existing COMSOL model from MATLAB using LiveLink for MATLAB.

It focuses on the minimal workflow needed to:

- load an existing `.mph` model,
- update selected model parameters,
- run an existing study,
- extract numerical results,
- save data for later post-processing,
- optionally open the COMSOL GUI for inspection.

This module assumes that the LiveLink environment has already been configured and tested. Before using this workflow, read:

```text
docs/livelink_environment_setup.md
templates/check_livelink_connection.m
```

## 1. Recommended Starting Point

For this basic workflow, the recommended starting point is an existing COMSOL `.mph` model that has already been built and manually validated in the COMSOL GUI.

In other words, this module assumes the following workflow:

```text
Build and validate the model in COMSOL GUI
→ Load the model from MATLAB using LiveLink
→ Modify selected parameters
→ Run an existing study
→ Extract and save results
```

This is the beginner-friendly and lab-recommended workflow.

Although LiveLink can also be used to construct a COMSOL model from scratch, including geometry, selections, materials, physics, mesh, studies, and result definitions, that approach is more suitable for advanced users. For most users, especially when starting out, it is easier and safer to first build a working model in the GUI and then use LiveLink for automation.

## 2. What Should Already Exist in the `.mph` Model?

Before using the basic LiveLink workflow, the `.mph` model should ideally contain the following components.

### 2.1 Global parameters and variables

The model should already define the key parameters that MATLAB will modify.

Examples include:

```text
waveguide width
etch depth
film thickness
gap
radius
wavelength
frequency
temperature
material constants
```

The parameter names should be clear and stable, because the MATLAB script will refer to them using commands such as:

```matlab
model.param.set('w', '1.2[um]');
model.param.set('lambda0', '1.55[um]');
```

### 2.2 Geometry

The geometry should already be built and should run successfully in COMSOL.

For a beginner LiveLink workflow, MATLAB usually should not be responsible for creating the entire geometry from scratch. Instead, MATLAB should only modify selected geometry parameters that already exist in the model.

Examples:

```text
waveguide width
waveguide height
ring radius
bus-ring gap
electrode gap
PML thickness
substrate thickness
```

After changing these parameters, the geometry should be able to rebuild automatically.

### 2.3 Named selections

Named selections are strongly recommended.

Examples:

```text
sel_core
sel_cladding
sel_substrate
sel_electrode
sel_pml
sel_port
sel_outer_boundary
```

Using named selections is more robust than relying on raw domain or boundary numbers. Domain and boundary numbers may change when the geometry is modified, while named selections provide a clearer interface between the GUI model and the MATLAB script.

### 2.4 Materials

The main materials should already be assigned in the COMSOL model.

For integrated photonics and related simulations, common materials may include:

```text
lithium niobate
silicon nitride
silicon dioxide
silicon
air
metal electrodes
piezoelectric materials
substrate materials
```

For anisotropic materials such as lithium niobate, the coordinate convention and tensor orientation should be checked carefully in the GUI before automation.

### 2.5 Physics interfaces

The required physics interfaces should already be added and configured.

In the context of the IQP lab, possible physics interfaces include the following.

#### Electromagnetic waves

This is commonly used for optical waveguide modes, ring resonators, optical transmission, and field distribution calculations.

Typical use cases include:

```text
optical mode solving
effective index extraction
field profile calculation
frequency-domain optical response
resonator eigenmode calculation
```

The physics tag may appear as something like `ewfd`, but the exact tag depends on the model.

#### Electrostatics

This is commonly used for static electric-field simulations, especially in electro-optic tuning and modulator-related models.

Typical use cases include:

```text
DC electrode field calculation
voltage-induced electric field distribution
electro-optic tuning estimation
capacitance-related analysis
```

For electro-optic simulations, a common workflow is to first solve the electrostatic field and then use the electric field to calculate an optical permittivity or refractive-index perturbation through the electro-optic tensor.

This coupling is often implemented through variables, material definitions, or a sequential workflow, rather than through a single universal “electro-optic multiphysics” node.

#### Solid mechanics

Solid Mechanics is commonly used for mechanical modes, acoustic modes, surface acoustic wave simulations, and mechanical displacement fields.

The physics tag is often something like `solid`, but this depends on the model.

Typical use cases include:

```text
mechanical eigenmodes
surface acoustic waves
elastic wave propagation
strain field extraction
mechanical displacement profiles
```

#### Piezoelectric coupling

For piezoelectric acoustic simulations, such as surface acoustic waves on lithium niobate or other piezoelectric materials, Solid Mechanics and Electrostatics may be coupled through a piezoelectric multiphysics setup.

Typical use cases include:

```text
piezoelectric surface acoustic waves
electrical excitation of acoustic modes
acoustic displacement and electric potential coupling
IDT-driven acoustic simulations
```

#### Other possible physics interfaces

Depending on the specific project, other physics interfaces may also be used, such as heat transfer, electrical currents, RF-related interfaces, or additional multiphysics couplings.

This basic LiveLink module does not require all users to follow a single fixed physics-interface style. The key requirement is that the physics setup should be manually validated in the COMSOL GUI before using MATLAB to automate it.

### 2.6 Boundary conditions

Important boundary conditions should already be set in the GUI.

Examples include:

```text
PML boundaries
scattering boundaries
ports
periodic or Floquet boundaries
fixed constraints
free boundaries
electric potential boundaries
ground boundaries
terminal conditions
```

For optical, acoustic, and electrostatic simulations, boundary-condition mistakes are often difficult to diagnose purely from MATLAB. They should be checked in the GUI before running large automated sweeps.

### 2.7 Mesh

The mesh should already be defined and tested.

The mesh does not need to be final for every parameter value, but it should be reasonable for the reference case.

Before automation, check:

```text
Does the mesh build successfully?
Is the mesh fine enough in important regions?
Does the mesh resolve thin layers or small gaps?
Does the mesh work after changing key parameters?
Is there a mesh convergence check for critical results?
```

### 2.8 Study and solver

The required study should already exist in the model.

Common study types in lab workflows may include:

```text
Mode Analysis
Frequency Domain
Eigenfrequency
Stationary
```

The MATLAB script will usually run an existing study by its tag:

```matlab
model.study('std1').run;
```

Therefore, the study tag must be known and stable.

The study should be tested manually in COMSOL before it is called from MATLAB.

### 2.9 Result expressions and datasets

The model should have at least one manually validated result expression or dataset.

Examples:

```text
effective index
frequency
Q factor
field components
electric potential
displacement field
strain field
power flow
mode area
overlap integral
```

In MATLAB, result expressions may be extracted using functions such as:

```text
mphglobal
mphinterp
mpheval
```

The expression names and dataset choices should be checked in COMSOL before writing a batch script.

### 2.10 One manually validated reference case

Before using LiveLink automation, there should be at least one reference case that has been manually checked in the GUI.

For this reference case, verify:

```text
The geometry is correct.
The material assignment is correct.
The physics setup is correct.
The mesh builds successfully.
The study runs successfully.
The result looks physically reasonable.
The key result expressions can be evaluated.
```

This reference case becomes the baseline for MATLAB automation.

## 3. Basic Idea of the LiveLink Workflow

A typical MATLAB LiveLink workflow is:

1. Start MATLAB with an active COMSOL LiveLink connection.
2. Load an existing COMSOL model using `mphload`.
3. Set selected parameters using `model.param.set`.
4. Run an existing study using `model.study(studyTag).run`.
5. Extract results using functions such as `mphglobal`, `mphinterp`, or `mpheval`.
6. Save the results and metadata to a `.mat` file.
7. Optionally open the COMSOL GUI using `mphlaunch(model)`.

## 4. Minimal Script Skeleton

A minimal script looks like this:

```matlab
clear; clc;

import com.comsol.model.*
import com.comsol.model.util.*

model = mphload('your_model.mph');

model.param.set('w', '1.2[um]');
model.param.set('h', '600[nm]');

model.study('std1').run;

neff = mphglobal(model, 'ewfd.neff');

save('result.mat', 'neff');
```

This is the basic structure that most lab automation scripts build upon.

## 5. Loading a COMSOL Model

Use `mphload` to load an existing `.mph` model:

```matlab
modelPath = 'your_model.mph';
model = mphload(modelPath);
```

Recommended practice:

- Use an absolute path or a path relative to the script location.
- Avoid special characters in file paths when possible.
- Do not load very large models unnecessarily when testing the script structure.
- Keep a backup copy of important `.mph` models.

Example using the script folder as the base directory:

```matlab
scriptDir = fileparts(mfilename('fullpath'));
modelPath = fullfile(scriptDir, '..', 'models', 'your_model.mph');
model = mphload(modelPath);
```

## 6. Setting Parameters

Use `model.param.set` to set COMSOL parameters from MATLAB.

Recommended:

```matlab
model.param.set('w', '1.2[um]');
model.param.set('h', '600[nm]');
model.param.set('lambda0', '1.55[um]');
```

Avoid setting physical parameters without units:

```matlab
model.param.set('w', 1.2);
```

In most lab workflows, parameter values should be passed as strings with explicit units.

Good practice:

- Keep all user-editable parameters at the top of the script.
- Use the same parameter names as in the COMSOL model.
- Use explicit units for lengths, frequencies, powers, temperatures, voltages, and material constants when applicable.
- Do not hard-code many parameters throughout the script.

## 7. Running a Study

Run a study by its tag:

```matlab
studyTag = 'std1';
model.study(studyTag).run;
```

The study tag must match the tag in the COMSOL Model Builder.

Common examples are:

```text
std1
std2
```

If the script fails at this step, check:

- whether the study tag is correct,
- whether the model can be solved manually in COMSOL,
- whether all required parameters have been defined,
- whether the geometry and mesh have rebuilt correctly,
- whether the solver settings are valid.

## 8. Extracting Results

The most common LiveLink result extraction functions are:

- `mphglobal`: extract global scalar or solution-level quantities.
- `mphinterp`: interpolate expressions at specified coordinates.
- `mpheval`: evaluate expressions on mesh points or datasets.

### 8.1 Extracting global quantities

Use `mphglobal` for scalar quantities such as effective index, frequency, Q factor, or integrated quantities.

Example:

```matlab
neff = mphglobal(model, 'ewfd.neff');
freq = mphglobal(model, 'freq');
```

The expression must be valid in the COMSOL model and dataset.

### 8.2 Interpolating at coordinates

Use `mphinterp` when evaluating fields or expressions at specific coordinates.

Example:

```matlab
coord = [0; 0];
Ez0 = mphinterp(model, 'ewfd.Ez', 'coord', coord);
```

The coordinate dimension must match the model geometry dimension.

### 8.3 Evaluating field data

Use `mpheval` when extracting field data on mesh points.

Example:

```matlab
data = mpheval(model, 'ewfd.normE');
```

This is useful for post-processing field profiles, although for complex plotting workflows it is often better to define dedicated datasets or exports in the COMSOL model.

## 9. Saving Results

A good LiveLink script should save both numerical results and metadata.

Recommended data to save:

- extracted numerical results,
- model path,
- study tag,
- parameter values,
- result expressions,
- script name,
- timestamp,
- runtime.

Example:

```matlab
metadata = struct();
metadata.modelPath = modelPath;
metadata.studyTag = studyTag;
metadata.params = params;
metadata.time = datestr(now);

save('result.mat', 'results', 'metadata');
```

Do not rely only on generated figures. Always save the numerical data needed to reproduce the figures.

## 10. Optional GUI Inspection

After running the model from MATLAB, the COMSOL GUI can be opened using:

```matlab
mphlaunch(model);
```

This is useful for checking:

- model parameters,
- geometry updates,
- mesh,
- solution datasets,
- field profiles,
- derived values,
- unexpected solver behavior.

For large automated sweeps, avoid opening the GUI inside every loop. Use GUI inspection only for validation cases or suspicious results.

## 11. Common Problems

### Problem 1: `mphload` cannot find the model

Check:

- whether the path is correct,
- whether the file exists,
- whether the file extension is `.mph`,
- whether the file is locked by another COMSOL session.

### Problem 2: Parameter setting fails

Check:

- whether the parameter name exists in COMSOL,
- whether the value is passed as a string,
- whether the unit is valid,
- whether the parameter is used consistently in the model.

### Problem 3: Study tag is wrong

Check the study tag in COMSOL Model Builder.

The display name of a study is not always the same as its internal tag.

### Problem 4: Result expression is wrong

Check:

- whether the expression is valid in COMSOL,
- whether the physics interface prefix is correct,
- whether the expression is available for the selected dataset,
- whether the study has been solved successfully.

Examples of possible physics prefixes include:

```text
ewfd
es
solid
```

The exact prefix depends on the physics interface and tag names in the model.

### Problem 5: The script runs but the result is suspicious

Check:

- whether the field profile looks physical,
- whether the correct solution or mode is selected,
- whether the mesh is sufficiently converged,
- whether the parameter values are actually updated,
- whether the result changes smoothly when parameters are slightly varied.

## 12. Best Practices

- Build and validate the model in the COMSOL GUI first.
- Use MATLAB LiveLink for automation, not as the first debugging layer.
- Keep all user inputs at the top of the script.
- Use descriptive variable names.
- Use explicit units in `model.param.set`.
- Save numerical data and metadata.
- Use `try/catch` blocks in scripts that may fail.
- Run one validation case before automating many cases.
- Use `mphlaunch(model)` when results look suspicious.
- Avoid overwriting old results unless intentional.
- Avoid committing large `.mph` models or generated `.mat` files to GitHub by default.

## 13. Recommended Template

The corresponding template script is:

```text
templates/livelink_minimal_workflow.m
```

Use that file as the starting point for writing a single-run MATLAB LiveLink script.

## 14. Next Module

After mastering the single-run workflow, the next module should cover:

```text
MATLAB LiveLink parameter sweeps and result saving
```

That module should introduce loops, failed-case handling, intermediate saving, runtime estimation, and organized output folders.
