clear; clc; close all;

% LIVELINK_PARAMETER_SWEEP_BOUND_MODES
%
% Goal:
%   Sweep the waveguide width in a COMSOL mode-analysis model, read all
%   returned effective indices after each run, and select acceptable bound
%   modes using propagation-loss or Q thresholds.
%
% Teaching point:
%   For mode-analysis sweeps, do not blindly use solnum = 1 as the final
%   result. Read all returned modes, compute loss/Q screening metrics, filter
%   acceptable bound modes, and save all raw mode data for later
%   post-processing.

%% ===================== 1. User configuration =====================

scriptDir = fileparts(mfilename('fullpath'));
repoRoot  = fileparts(scriptDir);

cfg = struct();

% COMSOL model path.
% This assumes the example model is stored in the repo examples folder.
cfg.modelFile = fullfile(repoRoot, 'examples', 'LN_ridge_waveguide_Zcut.mph');

% COMSOL study and dataset tags.
% These tags must match the model.
cfg.studyTag   = 'std1';
cfg.datasetTag = 'dset1';

% Optional: mode-analysis study-step feature tag.
% In many models this may be 'mode', but it can be different.
% If this tag is wrong, the script will warn and continue.
cfg.modeStudyFeatureTag = 'mode';

% Number of modes to ask COMSOL to solve.
% Keep this large enough to include the desired bound mode and nearby modes.
cfg.numModes = 6;

% Swept COMSOL global parameter.
% Change this name if your model uses a different width parameter.
cfg.paramName = 'w_ln';
cfg.paramUnit = 'um';
cfg.wList_um  = linspace(0.8, 1.4, 13);

% Optical wavelength used for converting imag(neff) to propagation loss.
% This value should match the wavelength used in the COMSOL model.
cfg.lambda0_um = 1.55;

% Thresholds for bound-mode filtering.
% You can use loss threshold, Q threshold, or both.
cfg.useLossThreshold  = true;
cfg.maxLoss_dB_per_cm = 10;

cfg.useQThreshold = false;
cfg.minQ_est      = 1e5;

% Sorting rule for accepted modes.
% For a simple waveguide, sorting by real(neff) from high to low is often a
% reasonable first step. TE/TM classification should be handled separately.
cfg.sortAcceptedBy = 'real_neff_descend';

% Output folder. This is intentionally outside tracked repo files.
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
cfg.outputDir = fullfile(repoRoot, 'local_outputs', ...
    ['waveguide_width_bound_mode_sweep_', timestamp]);

if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

cfg.rawMatFile     = fullfile(cfg.outputDir, 'sweep_raw.mat');
cfg.configMatFile  = fullfile(cfg.outputDir, 'sweep_config.mat');
cfg.summaryCsvFile = fullfile(cfg.outputDir, 'sweep_summary.csv');

save(cfg.configMatFile, 'cfg');

%% ===================== 2. Load COMSOL model =====================

fprintf('Loading COMSOL model:\n%s\n\n', cfg.modelFile);
model = mphload(cfg.modelFile);

% Try to set the number of modes from MATLAB.
% This may need adjustment for different COMSOL models.
try
    model.study(cfg.studyTag).feature(cfg.modeStudyFeatureTag).set( ...
        'neigs', num2str(cfg.numModes));
    fprintf('Set number of modes to %d using study feature "%s".\n\n', ...
        cfg.numModes, cfg.modeStudyFeatureTag);
catch ME
    warning('LiveLinkSweep:SetNumModesFailed', ...
        ['Could not set the number of modes using study feature "%s".\n', ...
        'The script will continue. Make sure the COMSOL model already ', ...
        'has the desired number of modes configured.\nOriginal message: %s'], ...
        cfg.modeStudyFeatureTag, ME.message);
end

%% ===================== 3. Preallocate result structure =====================

numSweepPoints = numel(cfg.wList_um);

emptyResult = struct( ...
    'success', false, ...
    'errorMessage', '', ...
    'w_um', NaN, ...
    'neff_all', [], ...
    'loss_dB_per_cm_all', [], ...
    'Q_est_all', [], ...
    'accepted_idx', [], ...
    'neff_accepted', [], ...
    'loss_dB_per_cm_accepted', [], ...
    'Q_est_accepted', [], ...
    'selected_neff', NaN, ...
    'selected_loss_dB_per_cm', NaN, ...
    'selected_Q_est', NaN);

results = repmat(emptyResult, numSweepPoints, 1);

%% ===================== 4. Parameter sweep =====================

for ii = 1:numSweepPoints
    w_um = cfg.wList_um(ii);

    fprintf('============================================================\n');
    fprintf('Sweep point %d / %d\n', ii, numSweepPoints);
    fprintf('%s = %.6g %s\n', cfg.paramName, w_um, cfg.paramUnit);

    results(ii).w_um = w_um;

    try
        % Update COMSOL global parameter.
        model.param.set(cfg.paramName, sprintf('%.12g[%s]', ...
            w_um, cfg.paramUnit));

        % Run the study.
        model.study(cfg.studyTag).run;

        % Read all returned modes.
        neff_all = mphglobal(model, 'ewfd.neff', ...
            'dataset', cfg.datasetTag, ...
            'solnum', 'all', ...
            'complexout', 'on');

        neff_all = neff_all(:);

        % Compute loss and Q screening metrics.
        [loss_dB_per_cm_all, Q_est_all] = neffToLossAndQ( ...
            neff_all, cfg.lambda0_um);

        % Select acceptable bound modes.
        accepted_idx = selectBoundModes( ...
            neff_all, loss_dB_per_cm_all, Q_est_all, cfg);

        % Sort accepted modes.
        accepted_idx = sortAcceptedModes( ...
            accepted_idx, neff_all, loss_dB_per_cm_all, Q_est_all, cfg);

        % Save results for this point.
        results(ii).success = true;
        results(ii).neff_all = neff_all;
        results(ii).loss_dB_per_cm_all = loss_dB_per_cm_all;
        results(ii).Q_est_all = Q_est_all;
        results(ii).accepted_idx = accepted_idx;
        results(ii).neff_accepted = neff_all(accepted_idx);
        results(ii).loss_dB_per_cm_accepted = ...
            loss_dB_per_cm_all(accepted_idx);
        results(ii).Q_est_accepted = Q_est_all(accepted_idx);

        if ~isempty(accepted_idx)
            firstAccepted = accepted_idx(1);
            results(ii).selected_neff = neff_all(firstAccepted);
            results(ii).selected_loss_dB_per_cm = ...
                loss_dB_per_cm_all(firstAccepted);
            results(ii).selected_Q_est = Q_est_all(firstAccepted);
        end

        fprintf('Returned modes: %d\n', numel(neff_all));
        fprintf('Accepted modes: %d\n', numel(accepted_idx));

        if ~isempty(accepted_idx)
            fprintf('Selected mode: neff = %.12g%+.3gi\n', ...
                real(results(ii).selected_neff), ...
                imag(results(ii).selected_neff));
            fprintf('Selected loss = %.6g dB/cm\n', ...
                results(ii).selected_loss_dB_per_cm);
            fprintf('Selected Q_est = %.6g\n', results(ii).selected_Q_est);
        else
            fprintf('No mode passed the current threshold.\n');
        end

    catch ME
        results(ii).success = false;
        results(ii).errorMessage = ME.message;
        warning('LiveLinkSweep:SweepPointFailed', ...
            'Sweep point failed: %s', ME.message);
    end

    % Checkpoint save after every sweep point.
    save(cfg.rawMatFile, 'cfg', 'results');
end

%% ===================== 5. Export summary table =====================

summaryTable = makeSweepSummaryTable(results);
writetable(summaryTable, cfg.summaryCsvFile);

fprintf('\n============================================================\n');
fprintf('Sweep finished.\n');
fprintf('Raw MAT file:\n%s\n', cfg.rawMatFile);
fprintf('Summary CSV file:\n%s\n', cfg.summaryCsvFile);

%% ===================== Local helper functions =====================

function [loss_dB_per_cm, Q_est] = neffToLossAndQ(neff, lambda0_um)
%NEFFTOLOSSANDQ Convert imag(neff) to propagation loss and Q estimate.
%
% Assumption:
%   E(z) ~ exp(i*k0*neff*z)
%
% Then:
%   alpha_power = 2*k0*abs(imag(neff))
%   loss_dB_per_m = 10*log10(exp(1))*alpha_power
%   Q_est = real(neff)/(2*abs(imag(neff)))
%
% Note:
%   Q_est is a simple screening metric based on neff. For publication-level
%   analysis, confirm the eigenvalue convention and whether group index is
%   needed instead of real(neff).

    lambda0_m = lambda0_um * 1e-6;
    k0 = 2*pi/lambda0_m;

    n_imag = abs(imag(neff));

    alpha_power_per_m = 2*k0*n_imag;
    loss_dB_per_m = 10*log10(exp(1)) * alpha_power_per_m;
    loss_dB_per_cm = loss_dB_per_m / 100;

    Q_est = NaN(size(neff));
    nonzeroImag = n_imag > 0;
    Q_est(nonzeroImag) = real(neff(nonzeroImag)) ./ ...
        (2*n_imag(nonzeroImag));
    Q_est(~nonzeroImag & isfinite(real(neff))) = Inf;
end

function accepted_idx = selectBoundModes(neff, loss_dB_per_cm, Q_est, cfg)
%SELECTBOUNDMODES Select candidate bound modes based on thresholds.

    valid = isfinite(real(neff)) & isfinite(imag(neff));

    if cfg.useLossThreshold
        valid = valid & (loss_dB_per_cm <= cfg.maxLoss_dB_per_cm);
    end

    if cfg.useQThreshold
        valid = valid & (Q_est >= cfg.minQ_est);
    end

    accepted_idx = find(valid);
end

function accepted_idx = sortAcceptedModes( ...
    accepted_idx, neff, loss_dB_per_cm, Q_est, cfg)
%SORTACCEPTEDMODES Sort accepted modes for consistent output.

    if isempty(accepted_idx)
        return;
    end

    switch lower(cfg.sortAcceptedBy)
        case 'real_neff_descend'
            [~, order] = sort(real(neff(accepted_idx)), 'descend');

        case 'loss_ascend'
            [~, order] = sort(loss_dB_per_cm(accepted_idx), 'ascend');

        case 'q_descend'
            [~, order] = sort(Q_est(accepted_idx), 'descend');

        otherwise
            warning('LiveLinkSweep:UnknownSortRule', ...
                'Unknown sorting rule. Keep original order.');
            order = 1:numel(accepted_idx);
    end

    accepted_idx = accepted_idx(order);
end

function summaryTable = makeSweepSummaryTable(results)
%MAKESWEEPSUMMARYTABLE Create one-row-per-sweep-point summary.

    numSweepPoints = numel(results);

    w_um = NaN(numSweepPoints, 1);
    success = false(numSweepPoints, 1);
    num_modes_returned = NaN(numSweepPoints, 1);
    num_modes_accepted = NaN(numSweepPoints, 1);
    selected_neff_real = NaN(numSweepPoints, 1);
    selected_neff_imag = NaN(numSweepPoints, 1);
    selected_loss_dB_per_cm = NaN(numSweepPoints, 1);
    selected_Q_est = NaN(numSweepPoints, 1);
    errorMessage = strings(numSweepPoints, 1);

    for ii = 1:numSweepPoints
        w_um(ii) = results(ii).w_um;
        success(ii) = results(ii).success;
        num_modes_returned(ii) = numel(results(ii).neff_all);
        num_modes_accepted(ii) = numel(results(ii).accepted_idx);

        if results(ii).success && ~isempty(results(ii).accepted_idx)
            selected_neff_real(ii) = real(results(ii).selected_neff);
            selected_neff_imag(ii) = imag(results(ii).selected_neff);
            selected_loss_dB_per_cm(ii) = ...
                results(ii).selected_loss_dB_per_cm;
            selected_Q_est(ii) = results(ii).selected_Q_est;
        end

        errorMessage(ii) = string(results(ii).errorMessage);
    end

    summaryTable = table( ...
        w_um, ...
        success, ...
        num_modes_returned, ...
        num_modes_accepted, ...
        selected_neff_real, ...
        selected_neff_imag, ...
        selected_loss_dB_per_cm, ...
        selected_Q_est, ...
        errorMessage);
end
