%% livelink_result_extraction_2d_fields.m
% Extract global results, integration variables, and 2D field maps from a
% COMSOL model using MATLAB LiveLink.
%
% Purpose
% -------
% This script demonstrates Module 03:
%
%   - mphglobal for scalar/global quantities,
%   - mphinterp for 2D field maps on a regular grid,
%   - reading COMSOL variables based on integration operators,
%   - optional GUI inspection with mphlaunch(model),
%   - saving extracted data and metadata.
%
% Expected model
% --------------
% The default teaching model is:
%
%   <repo_root>/examples/LN_ridge_waveguide_Zcut.mph
%
% The model is expected to contain:
%
%   - a study with tag 'std1',
%   - optical physics with tag 'ewfd',
%   - user-defined variables:
%       E2_physical
%       E2_LN
%       E2_pml
%       frac_E2_LN
%       frac_E2_pml
%
% These variables are expected to be based on COMSOL integration operators
% such as intop_physical, intop_LN_physical, and intop_pml.
%
% Important
% ---------
% Physical integrals should normally exclude PML domains. PML-related
% integrals are useful mainly as diagnostics for leakage or spurious modes.
%
% mphlaunch note
% --------------
% This script can optionally call mphlaunch(model) after extraction. This
% opens the current in-memory COMSOL model in the GUI for inspection. It does
% not overwrite the original .mph file unless the user explicitly saves the
% model in COMSOL or calls mphsave.

clear; clc;

%% =======================
%  USER INPUT SECTION
% ========================

% Infer repository root from script location.
% Expected location:
%   <repo_root>/templates/livelink_result_extraction_2d_fields.m
scriptDir = fileparts(mfilename('fullpath'));
[~, scriptFolderName] = fileparts(scriptDir);

if strcmpi(scriptFolderName, 'templates')
    repoRoot = fileparts(scriptDir);
else
    repoRoot = pwd;
    msg = sprintf(['This script is not located inside a folder named "templates".\n' ...
                   'Using the current MATLAB folder as repoRoot:\n%s\n\n' ...
                   'Recommended location:\n<repo_root>/templates/livelink_result_extraction_2d_fields.m'], repoRoot);
    warning('%s', msg);
end

% Model path.
modelPath = fullfile(repoRoot, 'examples', 'LN_ridge_waveguide_Zcut.mph');

% Study tag.
studyTag = 'std1';

% Set to false if the model has already been solved and you only want to
% test result extraction from the current solution.
runStudy = true;

% Global expressions to read with mphglobal.
globalExpressions = {
    'ewfd.neff'
    'E2_physical'
    'E2_LN'
    'E2_pml'
    'frac_E2_LN'
    'frac_E2_pml'
};

globalNames = {
    'neff'
    'E2_physical'
    'E2_LN'
    'E2_pml'
    'frac_E2_LN'
    'frac_E2_pml'
};

% 2D field expression to interpolate.
fieldExpression = 'ewfd.normE';
fieldName = 'normE';

% Field representation for plotting and saving.
% Options:
%   'raw'   : save the value returned by COMSOL
%   'abs'   : absolute value
%   'real'  : real part
%   'imag'  : imaginary part
%   'phase' : angle in radians
fieldRepresentation = 'abs';

% 2D interpolation grid.
% Units below are micrometers for user readability. The script converts them
% to meters before calling mphinterp.
xRangeUm = [-7.5, 7.5];
yRangeUm = [-3.0, 3.0];

numX = 401;
numY = 241;

% Output settings.
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outputFolder = fullfile(repoRoot, 'local_outputs', ['result_extraction_', timestamp]);
outputFileName = 'result_extraction_2d_fields.mat';

% Options.
% Use options.openGuiAfterRun to inspect the current in-memory COMSOL model
% after the MATLAB extraction. This is useful when checking selections,
% integration operators, variables, datasets, or field profiles.
options = struct();
options.makePlot = true;
options.savePlot = true;
options.openGuiAfterRun = false;
options.showComsolProgress = true;

%% =======================
%  BASIC INPUT CHECKS
% ========================

fprintf('Starting LiveLink result extraction workflow.\n\n');

fprintf('Repository root:\n%s\n\n', repoRoot);
fprintf('Model path:\n%s\n\n', modelPath);

if ~exist(modelPath, 'file')
    msg = sprintf(['The COMSOL teaching model was not found:\n%s\n\n' ...
                   'Please make sure the model is placed at:\n' ...
                   '<repo_root>/examples/LN_ridge_waveguide_Zcut.mph'], modelPath);
    error('%s', msg);
end

if numel(globalExpressions) ~= numel(globalNames)
    error('%s', 'globalExpressions and globalNames must have the same length.');
end

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

for ii = 1:numel(globalNames)
    globalNames{ii} = matlab.lang.makeValidName(globalNames{ii});
end

fieldName = matlab.lang.makeValidName(fieldName);

%% =======================
%  IMPORT COMSOL CLASSES
% ========================

import com.comsol.model.*
import com.comsol.model.util.*

ModelUtil.showProgress(options.showComsolProgress);

%% =======================
%  LOAD MODEL
% ========================

fprintf('Loading COMSOL model...\n');
model = mphload(modelPath);
fprintf('Model loaded successfully.\n\n');

%% =======================
%  RUN STUDY
% ========================

runtimeSeconds = NaN;

if runStudy
    fprintf('Running study: %s\n', studyTag);
    runTimer = tic;

    try
        model.study(studyTag).run;
    catch ME
        errMsg = char(ME.message);
        msg = sprintf(['Study run failed for study tag "%s".\n' ...
                       'Check whether the study tag exists and whether the model runs manually in COMSOL.\n\n' ...
                       'COMSOL/MATLAB error message:\n%s'], studyTag, errMsg);
        error('%s', msg);
    end

    runtimeSeconds = toc(runTimer);
    fprintf('Study finished. Runtime: %.2f seconds.\n\n', runtimeSeconds);
else
    fprintf('Skipping study run. The script will try to read the existing solution.\n\n');
end

%% =======================
%  GLOBAL EVALUATION
% ========================

fprintf('Reading global expressions using mphglobal...\n');

globalResults = struct();

for ii = 1:numel(globalExpressions)
    expr = globalExpressions{ii};
    field = globalNames{ii};

    try
        value = mphglobal(model, expr);
        globalResults.(field) = value;

        fprintf('  %s -> globalResults.%s = ', expr, field);
        disp(value);

    catch ME
        errMsg = char(ME.message);
        msg = sprintf(['Failed to evaluate global expression "%s".\n' ...
                       'Reason: %s'], expr, errMsg);
        warning('%s', msg);

        globalResults.(field) = NaN;
    end
end

fprintf('\n');

%% =======================
%  2D FIELD INTERPOLATION
% ========================

fprintf('Interpolating 2D field: %s\n', fieldExpression);

xUm = linspace(xRangeUm(1), xRangeUm(2), numX);
yUm = linspace(yRangeUm(1), yRangeUm(2), numY);

[XUm, YUm] = meshgrid(xUm, yUm);

% Convert micrometers to meters for COMSOL coordinates.
coord = [XUm(:)'; YUm(:)'] * 1e-6;

try
    rawField = mphinterp(model, fieldExpression, ...
        'coord', coord, ...
        'edim', 'domain');

catch ME
    errMsg = char(ME.message);
    msg = sprintf(['mphinterp failed for expression "%s".\n' ...
                   'Check the expression name, coordinate range, dataset, and edim setting.\n\n' ...
                   'Reason: %s'], fieldExpression, errMsg);
    error('%s', msg);
end

numPoints = numel(XUm);

% mphinterp may return one row per solution. For this beginner template,
% use the first solution if multiple rows are returned.
if isvector(rawField)
    fieldVector = rawField(:).';
elseif size(rawField, 2) == numPoints
    fieldVector = rawField(1, :);
elseif size(rawField, 1) == numPoints
    fieldVector = rawField(:, 1).';
else
    error('%s', 'Unexpected mphinterp output size. Check the number of solutions and evaluation points.');
end

switch lower(fieldRepresentation)
    case 'raw'
        fieldMap = reshape(fieldVector, size(XUm));
    case 'abs'
        fieldMap = reshape(abs(fieldVector), size(XUm));
    case 'real'
        fieldMap = reshape(real(fieldVector), size(XUm));
    case 'imag'
        fieldMap = reshape(imag(fieldVector), size(XUm));
    case 'phase'
        fieldMap = reshape(angle(fieldVector), size(XUm));
    otherwise
        error('Unknown fieldRepresentation: %s', fieldRepresentation);
end

fieldData = struct();
fieldData.expression = fieldExpression;
fieldData.name = fieldName;
fieldData.representation = fieldRepresentation;
fieldData.xUm = xUm;
fieldData.yUm = yUm;
fieldData.XUm = XUm;
fieldData.YUm = YUm;
fieldData.map = fieldMap;
fieldData.rawFirstSolutionVector = fieldVector;

fprintf('2D field interpolation finished.\n\n');

%% =======================
%  PLOT FIELD MAP
% ========================

if options.makePlot
    fig = figure('Name', '2D Field Extraction');
    imagesc(xUm, yUm, fieldMap);
    set(gca, 'YDir', 'normal');
    axis image;
    xlabel('x (um)');
    ylabel('y (um)');
    title(sprintf('%s, %s', fieldExpression, fieldRepresentation), 'Interpreter', 'none');
    colorbar;

    if options.savePlot
        figPath = fullfile(outputFolder, 'field_map.png');
        saveas(fig, figPath);
        fprintf('Saved field map figure to:\n%s\n\n', figPath);
    end
end

%% =======================
%  SAVE RESULTS AND METADATA
% ========================

metadata = struct();
metadata.modelPath = modelPath;
metadata.studyTag = studyTag;
metadata.runStudy = runStudy;
metadata.runtimeSeconds = runtimeSeconds;
metadata.globalExpressions = globalExpressions;
metadata.globalNames = globalNames;
metadata.fieldExpression = fieldExpression;
metadata.fieldName = fieldName;
metadata.fieldRepresentation = fieldRepresentation;
metadata.xRangeUm = xRangeUm;
metadata.yRangeUm = yRangeUm;
metadata.numX = numX;
metadata.numY = numY;
metadata.outputFolder = outputFolder;
metadata.outputFileName = outputFileName;
metadata.scriptPath = mfilename('fullpath');
metadata.time = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
metadata.options = options;

outputPath = fullfile(outputFolder, outputFileName);

fprintf('Saving extracted data and metadata to:\n%s\n\n', outputPath);

save(outputPath, 'globalResults', 'fieldData', 'metadata');

%% =======================
%  OPTIONAL GUI INSPECTION
% ========================

if options.openGuiAfterRun
    fprintf('Opening current in-memory COMSOL model in GUI for inspection...\n');
    fprintf('Do not click Save unless you intentionally want to update the .mph file.\n');
    mphlaunch(model);
end

fprintf('LiveLink result extraction workflow finished successfully.\n');
