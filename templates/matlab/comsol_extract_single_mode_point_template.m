%% comsol_extract_single_mode_point_template.m
% Single-point COMSOL optical mode extraction with MATLAB LiveLink.
%
% Purpose:
%   Load one existing COMSOL .mph model, set one geometry/wavelength point,
%   run one mode-analysis study, extract all candidate modes, and save raw
%   candidate-mode data before any filtering.
%
% Important:
%   This template assumes the COMSOL model has already been built and
%   validated in the COMSOL GUI. The user must adapt model-specific paths,
%   study tags, dataset tags, parameter names, and result expressions below.
%
%   Do not assume that solnum = 1 or the first returned eigenmode is the
%   desired physical mode. Inspect field profiles and confinement diagnostics
%   before trusting a final physical interpretation.

clear; clc;

%% ===================== 1. User configuration =====================

thisFile = mfilename('fullpath');
if isempty(thisFile)
    templateDir = pwd;
else
    templateDir = fileparts(thisFile);
end

repoRoot = fileparts(fileparts(templateDir));

cfg = struct();

% Model path. Replace this with the local model to validate.
cfg.modelPath = fullfile(repoRoot, 'examples', 'LN_ridge_waveguide_Zcut.mph');

% Output folder. Results are saved under local_outputs and should normally
% not be committed to Git.
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
cfg.outputDir = fullfile(repoRoot, 'local_outputs', ...
    ['single_mode_point_extraction_', timestamp]);
cfg.outputMatFile = fullfile(cfg.outputDir, ...
    'single_mode_point_raw_and_processed.mat');

% COMSOL study and dataset tags. Check these in COMSOL Model Builder.
cfg.studyTag = 'std1';
cfg.datasetTag = 'dset1';

% Explicit solution selection for mode-analysis results.
% Use 'all' to extract all returned candidate modes.
cfg.solnum = 'all';

% Result expressions. These must match variables available in the model.
cfg.neffExpr = 'ewfd.neff';

% Optional COMSOL loss expression. If this expression is not available,
% the script stores NaN values and continues.
cfg.dampzdBExpr = 'ewfd.dampzdB';
cfg.tryDampzdB = true;

% Geometry and wavelength parameters to set before running the study.
% Replace parameter names and values with names from the COMSOL model.
%
% Each value should include units when appropriate, for example '1.2[um]'.
cfg.paramNames = {
    'w_ln'
    'lambda0'
};

cfg.paramValues = {
    '1.20[um]'
    '1.55[um]'
};

% Wavelength used for the optional Q estimate and loss-like diagnostics.
% Keep this consistent with cfg.paramValues and the COMSOL model.
cfg.lambda0_um = 1.55;
cfg.computeQEstimate = true;

% Optional relative-loss filter.
% Use abs(imag(neff)) because eigenmode sign conventions can make lossy
% modes appear with either positive or negative imaginary effective index.
%
% A mode is accepted when:
%   abs(imag(neff)) < abs(real(neff)) * cfg.relativeImagThreshold
cfg.applyRelativeImagFilter = true;
cfg.relativeImagThreshold = 1e-6;

% Sorting rule for accepted modes.
cfg.sortAcceptedBy = 'real_neff_descend';

% COMSOL progress output.
cfg.showComsolProgress = true;

%% ===================== 2. Basic input checks =====================

fprintf('Starting single-point COMSOL mode extraction.\n\n');
fprintf('Model path:\n%s\n\n', cfg.modelPath);

if exist(cfg.modelPath, 'file') ~= 2
    error('SingleModePoint:ModelFileNotFound', ...
        ['COMSOL model file not found:\n  %s\n\n', ...
         'Update cfg.modelPath before running this script.'], ...
        cfg.modelPath);
end

if numel(cfg.paramNames) ~= numel(cfg.paramValues)
    error('SingleModePoint:ParameterConfigMismatch', ...
        'cfg.paramNames and cfg.paramValues must have the same length.');
end

if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

%% ===================== 3. Import COMSOL classes =====================

import com.comsol.model.*
import com.comsol.model.util.*

ModelUtil.showProgress(cfg.showComsolProgress);

%% ===================== 4. Load model and set parameters =====================

fprintf('Loading COMSOL model with mphload.\n');
model = mphload(cfg.modelPath);

fprintf('Setting COMSOL parameters.\n');
for ii = 1:numel(cfg.paramNames)
    paramName = cfg.paramNames{ii};
    paramValue = cfg.paramValues{ii};

    fprintf('  %s = %s\n', paramName, paramValue);
    model.param.set(paramName, paramValue);
end

%% ===================== 5. Run one mode-analysis study =====================

fprintf('\nRunning study "%s".\n', cfg.studyTag);
model.study(cfg.studyTag).run;

%% ===================== 6. Extract all candidate modes =====================

fprintf('Extracting all candidate modes with mphglobal.\n');

neff = mphglobal(model, cfg.neffExpr, ...
    'dataset', cfg.datasetTag, ...
    'solnum', cfg.solnum, ...
    'complexout', 'on');

neff = neff(:);
numModes = numel(neff);
modeIndex = (1:numModes).';

if numModes == 0
    error('SingleModePoint:NoModesReturned', ...
        'No modes were returned by expression "%s".', cfg.neffExpr);
end

realNeff = real(neff);
imagNeff = imag(neff);
absImagNeff = abs(imagNeff);

dampzdB = NaN(numModes, 1);
dampzdBStatus = "not requested";

if cfg.tryDampzdB
    try
        dampzdBRead = mphglobal(model, cfg.dampzdBExpr, ...
            'dataset', cfg.datasetTag, ...
            'solnum', cfg.solnum, ...
            'complexout', 'on');

        dampzdBRead = dampzdBRead(:);

        if numel(dampzdBRead) == numModes
            dampzdB = real(dampzdBRead);
            dampzdBStatus = "read successfully";
        else
            dampzdBStatus = "length mismatch; stored NaN";
        end
    catch ME
        dampzdBStatus = "failed; stored NaN";
        fprintf('Optional dampzdB extraction failed: %s\n', ME.message);
    end
end

Q_est = NaN(numModes, 1);

if cfg.computeQEstimate
    Q_est = estimate_q_from_neff(neff);
end

raw = struct();
raw.modeIndex = modeIndex;
raw.neff = neff;
raw.realNeff = realNeff;
raw.imagNeff = imagNeff;
raw.absImagNeff = absImagNeff;
raw.dampzdB = dampzdB;
raw.Q_est = Q_est;
raw.numModes = numModes;
raw.dampzdBStatus = dampzdBStatus;

rawTable = table( ...
    modeIndex, ...
    neff, ...
    realNeff, ...
    imagNeff, ...
    absImagNeff, ...
    dampzdB, ...
    Q_est, ...
    'VariableNames', { ...
        'modeIndex', ...
        'neff', ...
        'realNeff', ...
        'imagNeff', ...
        'absImagNeff', ...
        'dampzdB', ...
        'Q_est'});

%% ===================== 7. Optional filtering and sorting =====================

processed = struct();
processed.filterApplied = cfg.applyRelativeImagFilter;
processed.filterRule = ...
    'abs(imag(neff)) < abs(real(neff)) * cfg.relativeImagThreshold';
processed.relativeImagThreshold = cfg.relativeImagThreshold;

if cfg.applyRelativeImagFilter
    acceptedMask = absImagNeff < abs(realNeff) * ...
        cfg.relativeImagThreshold;
else
    acceptedMask = true(numModes, 1);
end

acceptedIndex = find(acceptedMask);

switch lower(cfg.sortAcceptedBy)
    case 'real_neff_descend'
        [~, sortOrder] = sort(realNeff(acceptedIndex), 'descend');
    otherwise
        error('SingleModePoint:UnknownSortRule', ...
            'Unknown cfg.sortAcceptedBy: %s', cfg.sortAcceptedBy);
end

acceptedIndex = acceptedIndex(sortOrder);

processed.acceptedIndex = acceptedIndex;
processed.acceptedModeIndex = modeIndex(acceptedIndex);
processed.acceptedNeff = neff(acceptedIndex);
processed.acceptedRealNeff = realNeff(acceptedIndex);
processed.acceptedImagNeff = imagNeff(acceptedIndex);
processed.acceptedAbsImagNeff = absImagNeff(acceptedIndex);
processed.acceptedDampzdB = dampzdB(acceptedIndex);
processed.acceptedQ_est = Q_est(acceptedIndex);
processed.numAcceptedModes = numel(acceptedIndex);
processed.sortRule = cfg.sortAcceptedBy;

acceptedTable = rawTable(acceptedIndex, :);

%% ===================== 8. Save raw and processed results =====================

metadata = struct();
metadata.createdAt = char(datetime('now'));
metadata.scriptName = mfilename;
metadata.modelPath = cfg.modelPath;
metadata.studyTag = cfg.studyTag;
metadata.datasetTag = cfg.datasetTag;
metadata.solnum = cfg.solnum;
metadata.neffExpr = cfg.neffExpr;
metadata.dampzdBExpr = cfg.dampzdBExpr;
metadata.parameterNames = cfg.paramNames;
metadata.parameterValues = cfg.paramValues;
metadata.note = ['Raw candidate modes are saved before filtering. ', ...
    'Accepted modes are a processed view, not a final physical selection.'];

save(cfg.outputMatFile, ...
    'cfg', ...
    'metadata', ...
    'raw', ...
    'processed', ...
    'rawTable', ...
    'acceptedTable');

fprintf('\nExtraction complete.\n');
fprintf('Returned candidate modes: %d\n', raw.numModes);
fprintf('Accepted modes after optional filter: %d\n', ...
    processed.numAcceptedModes);
fprintf('Saved MAT file:\n%s\n', cfg.outputMatFile);

%% ===================== Local helper functions =====================

function Q_est = estimate_q_from_neff(neff)
%ESTIMATE_Q_FROM_NEFF Compute a rough Q-like screening metric.
%
% This uses real(neff)/(2*abs(imag(neff))). It is only a screening metric.
% For final quantitative analysis, confirm the COMSOL eigenvalue convention
% and whether group index should be used instead of phase index.

    realNeff = real(neff(:));
    imagNeffAbs = abs(imag(neff(:)));

    Q_est = NaN(size(realNeff));
    valid = imagNeffAbs > 0;
    Q_est(valid) = realNeff(valid) ./ (2 * imagNeffAbs(valid));
end
