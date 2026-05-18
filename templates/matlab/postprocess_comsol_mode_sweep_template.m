%% postprocess_comsol_mode_sweep_template.m
% Post-process already-saved COMSOL mode-sweep data without calling COMSOL.
%
% This template assumes the expensive COMSOL simulations have already been
% completed and saved to disk. It loads raw candidate modes, applies a
% relative imaginary-index filter, sorts accepted modes, and saves processed
% results separately from the raw data.
%
% This script intentionally does not use:
%   - mphload
%   - mphglobal
%   - mphinterp
%   - model.study(...).run
%
% Expected raw input structure when useSyntheticDemo = false:
%
%   raw = struct array with one element per sweep point.
%
%   Required fields:
%       raw(i).sweepValue
%           Numeric value of the swept parameter at point i.
%
%       raw(i).neff
%           Complex vector of all candidate effective indices returned by
%           COMSOL at sweep point i. The vector may have a different length
%           at each sweep point.
%
%   Optional fields:
%       raw(i).modeIndex
%           Numeric vector of original COMSOL mode indices. If missing, this
%           script uses 1:numel(raw(i).neff).
%
%       raw(i).label
%           Text label for the sweep point.
%
% Example:
%
%   raw(1).sweepValue = 0.80;
%   raw(1).neff = [2.12 + 1e-8i, 1.94 + 2e-4i];
%   raw(1).modeIndex = [1, 2];

clear; clc;

%% ===================== 1. User configuration =====================

cfg = struct();

% Set true to run the built-in synthetic example.
% Set false to load raw mode data from cfg.rawMatFile.
cfg.useSyntheticDemo = true;

% Input file used when cfg.useSyntheticDemo = false.
cfg.rawMatFile = fullfile('local_outputs', 'example_sweep', 'raw_modes.mat');

% Variable name expected inside cfg.rawMatFile.
cfg.rawVariableName = 'raw';

% Relative imaginary-index threshold.
% Use abs(imag(neff)) because eigenmode sign conventions can make lossy
% modes appear with either positive or negative imaginary effective index.
%
% A mode is accepted when:
%   abs(imag(neff)) < abs(real(neff)) * cfg.relativeImagThreshold
cfg.relativeImagThreshold = 1e-6;

% Output folder for processed results. The raw input file is never
% overwritten by this script.
cfg.outputRoot = fullfile('local_outputs', 'postprocessed_mode_sweeps');
cfg.runName = ['relative_imag_filter_', ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))];
cfg.outputDir = fullfile(cfg.outputRoot, cfg.runName);

% Output file names.
cfg.processedMatName = 'processed_mode_sweep.mat';
cfg.acceptedCsvName = 'accepted_modes.csv';
cfg.pointSummaryCsvName = 'sweep_point_summary.csv';

%% ===================== 2. Load or create raw data =====================

if cfg.useSyntheticDemo
    raw = make_synthetic_demo_raw_data();
    sourceDescription = 'built-in synthetic demo dataset';
else
    loaded = load(cfg.rawMatFile);

    if ~isfield(loaded, cfg.rawVariableName)
        error('ModePostprocess:MissingRawVariable', ...
            'Input file does not contain variable "%s":\n  %s', ...
            cfg.rawVariableName, cfg.rawMatFile);
    end

    raw = loaded.(cfg.rawVariableName);
    sourceDescription = cfg.rawMatFile;
end

raw = validate_and_normalize_raw_data(raw);

%% ===================== 3. Preallocate processed outputs =====================

numSweepPoints = numel(raw);

emptyProcessed = struct( ...
    'sweepIndex', NaN, ...
    'sweepValue', NaN, ...
    'numCandidateModes', 0, ...
    'numAcceptedModes', 0, ...
    'acceptedModeIndex', [], ...
    'acceptedNeff', [], ...
    'acceptedRealNeff', [], ...
    'acceptedImagNeff', [], ...
    'acceptedAbsImagNeff', []);

processed = repmat(emptyProcessed, numSweepPoints, 1);

acceptedTables = cell(numSweepPoints, 1);
summarySweepIndex = zeros(numSweepPoints, 1);
summarySweepValue = NaN(numSweepPoints, 1);
summaryNumCandidateModes = zeros(numSweepPoints, 1);
summaryNumAcceptedModes = zeros(numSweepPoints, 1);

%% ===================== 4. Filter and sort modes =====================

for ii = 1:numSweepPoints
    neff = raw(ii).neff(:);
    modeIndex = raw(ii).modeIndex(:);

    realNeff = real(neff);
    imagNeff = imag(neff);
    absImagNeff = abs(imagNeff);

    isAccepted = absImagNeff < abs(realNeff) * ...
        cfg.relativeImagThreshold;

    acceptedModeIndex = modeIndex(isAccepted);
    acceptedNeff = neff(isAccepted);

    [acceptedRealNeffSorted, sortOrder] = sort(real(acceptedNeff), 'descend');

    acceptedModeIndex = acceptedModeIndex(sortOrder);
    acceptedNeff = acceptedNeff(sortOrder);
    acceptedImagNeff = imag(acceptedNeff);
    acceptedAbsImagNeff = abs(acceptedImagNeff);

    processed(ii).sweepIndex = ii;
    processed(ii).sweepValue = raw(ii).sweepValue;
    processed(ii).numCandidateModes = numel(neff);
    processed(ii).numAcceptedModes = numel(acceptedNeff);
    processed(ii).acceptedModeIndex = acceptedModeIndex(:).';
    processed(ii).acceptedNeff = acceptedNeff(:).';
    processed(ii).acceptedRealNeff = acceptedRealNeffSorted(:).';
    processed(ii).acceptedImagNeff = acceptedImagNeff(:).';
    processed(ii).acceptedAbsImagNeff = acceptedAbsImagNeff(:).';

    acceptedTables{ii} = table( ...
        repmat(ii, numel(acceptedNeff), 1), ...
        repmat(raw(ii).sweepValue, numel(acceptedNeff), 1), ...
        acceptedModeIndex(:), ...
        acceptedNeff(:), ...
        real(acceptedNeff(:)), ...
        imag(acceptedNeff(:)), ...
        abs(imag(acceptedNeff(:))), ...
        'VariableNames', { ...
            'sweepIndex', ...
            'sweepValue', ...
            'modeIndex', ...
            'neff', ...
            'realNeff', ...
            'imagNeff', ...
            'absImagNeff'});

    summarySweepIndex(ii) = ii;
    summarySweepValue(ii) = raw(ii).sweepValue;
    summaryNumCandidateModes(ii) = numel(neff);
    summaryNumAcceptedModes(ii) = numel(acceptedNeff);
end

acceptedModeTable = vertcat_tables(acceptedTables);

sweepPointSummary = table( ...
    summarySweepIndex, ...
    summarySweepValue, ...
    summaryNumCandidateModes, ...
    summaryNumAcceptedModes, ...
    'VariableNames', { ...
        'sweepIndex', ...
        'sweepValue', ...
        'numCandidateModes', ...
        'numAcceptedModes'});

%% ===================== 5. Save processed results separately =====================

if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

metadata = struct();
metadata.createdAt = char(datetime('now'));
metadata.scriptName = mfilename;
metadata.sourceDescription = sourceDescription;
metadata.filterRule = ...
    'abs(imag(neff)) < abs(real(neff)) * cfg.relativeImagThreshold';
metadata.sortRule = 'real(neff) descending within each sweep point';

processedMatFile = fullfile(cfg.outputDir, cfg.processedMatName);
acceptedCsvFile = fullfile(cfg.outputDir, cfg.acceptedCsvName);
summaryCsvFile = fullfile(cfg.outputDir, cfg.pointSummaryCsvName);

save(processedMatFile, ...
    'cfg', ...
    'metadata', ...
    'raw', ...
    'processed', ...
    'acceptedModeTable', ...
    'sweepPointSummary');

writetable(acceptedModeTable, acceptedCsvFile);
writetable(sweepPointSummary, summaryCsvFile);

fprintf('Processed mode sweep saved to:\n  %s\n', processedMatFile);
fprintf('Accepted mode table saved to:\n  %s\n', acceptedCsvFile);
fprintf('Sweep point summary saved to:\n  %s\n', summaryCsvFile);
fprintf('\nRaw candidate modes were preserved in memory and not overwritten.\n');

%% ===================== Local helper functions =====================

function raw = make_synthetic_demo_raw_data()
%MAKE_SYNTHETIC_DEMO_RAW_DATA Create variable-length candidate mode data.

    raw = struct( ...
        'sweepValue', {}, ...
        'neff', {}, ...
        'modeIndex', {}, ...
        'label', {});

    raw(1).sweepValue = 0.80;
    raw(1).neff = [ ...
        2.1200 + 0.2e-7i, ...
        1.9300 + 8.0e-6i, ...
        1.6500 + 1.0e-3i];
    raw(1).modeIndex = [1, 2, 3];
    raw(1).label = 'width_0p80_um';

    raw(2).sweepValue = 1.00;
    raw(2).neff = [ ...
        2.2100 + 0.6e-7i, ...
        2.0500 + 1.5e-7i, ...
        1.8100 + 3.0e-5i, ...
        1.5200 + 2.0e-3i];
    raw(2).modeIndex = [1, 2, 3, 4];
    raw(2).label = 'width_1p00_um';

    raw(3).sweepValue = 1.20;
    raw(3).neff = [ ...
        2.3200 + 0.8e-7i, ...
        2.1800 + 2.8e-6i];
    raw(3).modeIndex = [1, 2];
    raw(3).label = 'width_1p20_um';

    raw(4).sweepValue = 1.40;
    raw(4).neff = [ ...
        2.4100 + 1.0e-7i, ...
        2.2600 + 0.3e-7i, ...
        2.0300 + 5.0e-6i, ...
        1.7000 + 7.5e-4i, ...
        1.4500 + 1.5e-3i];
    raw(4).modeIndex = [1, 2, 3, 4, 5];
    raw(4).label = 'width_1p40_um';
end

function raw = validate_and_normalize_raw_data(raw)
%VALIDATE_AND_NORMALIZE_RAW_DATA Check required fields and fill defaults.

    requiredFields = {'sweepValue', 'neff'};

    if ~isstruct(raw)
        error('ModePostprocess:InvalidRawData', ...
            'Raw data must be a struct array.');
    end

    for ii = 1:numel(requiredFields)
        if ~isfield(raw, requiredFields{ii})
            error('ModePostprocess:MissingRawField', ...
                'Raw data is missing required field: %s', ...
                requiredFields{ii});
        end
    end

    for ii = 1:numel(raw)
        raw(ii).neff = raw(ii).neff(:);
        numModes = numel(raw(ii).neff);

        if isempty(raw(ii).sweepValue) || ~isscalar(raw(ii).sweepValue)
            error('ModePostprocess:InvalidSweepValue', ...
                'raw(%d).sweepValue must be a numeric scalar.', ii);
        end

        if ~isfield(raw, 'modeIndex') || isempty(raw(ii).modeIndex)
            raw(ii).modeIndex = (1:numModes).';
        else
            raw(ii).modeIndex = raw(ii).modeIndex(:);

            if numel(raw(ii).modeIndex) ~= numModes
                error('ModePostprocess:ModeIndexSizeMismatch', ...
                    ['raw(%d).modeIndex must have the same length as ', ...
                     'raw(%d).neff.'], ii, ii);
            end
        end

        if ~isfield(raw, 'label') || isempty(raw(ii).label)
            raw(ii).label = sprintf('sweep_%d', ii);
        end
    end
end

function T = vertcat_tables(tableCell)
%VERTCAT_TABLES Concatenate tables while preserving columns for no matches.

    if isempty(tableCell)
        T = table();
        return;
    end

    T = tableCell{1};

    for ii = 2:numel(tableCell)
        T = [T; tableCell{ii}]; %#ok<AGROW>
    end
end
