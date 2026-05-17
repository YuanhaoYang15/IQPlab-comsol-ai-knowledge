%% LiveLink Module 04: Parameter sweep with predefined integral quantities
% This script extends the bound-mode parameter sweep example.
%
% Use case:
%   The COMSOL model already contains predefined integration operators,
%   variables, or derived scalar expressions, for example:
%       frac_E2_LN
%       substrate_energy_ratio
%       TE_frac
%       TM_frac
%
% Main idea:
%   For each waveguide width, this script reads ALL returned mode solutions
%   using solnum = 'all'. It does not filter bound modes. Instead, it saves:
%       - neff for every returned mode
%       - loss estimated from imag(neff)
%       - Q_est estimated from real(neff) / imag(neff)
%       - predefined integral quantities for every returned mode
%
% This is useful for checking whether quantities such as frac_E2_LN can act
% as a bound-mode indicator, similar to imag(neff) or propagation loss.

clear; clc; close all;

%% ===== User configuration =====
thisFile = mfilename('fullpath');
if isempty(thisFile)
    templateDir = pwd;
else
    templateDir = fileparts(thisFile);
end
repoRoot = fileparts(templateDir);

cfg = struct();

% COMSOL model and tags
cfg.modelFile  = fullfile(repoRoot, 'examples', 'LN_ridge_waveguide_Zcut.mph');
cfg.studyTag   = 'std1';
cfg.datasetTag = 'dset1';

% Parameter to sweep
cfg.paramName = 'w_ln';
cfg.paramUnit = 'um';
cfg.wList_um  = linspace(0.8, 1.4, 13);

% Optical wavelength used for converting imag(neff) to propagation loss.
% This value should match the wavelength used in the COMSOL mode model.
cfg.lambda0_um = 1.55;

% Read all returned modes after each run.
% The number of modes to solve should be set in the COMSOL model/study step.
% The exact LiveLink tag for "number of modes" is model-dependent, so this
% template keeps that setting inside the .mph file.
cfg.solnum = 'all';

% Expressions to extract for every returned mode.
% These expressions must be available in the COMSOL model.
%
% Notes:
%   - ewfd.neff is required for loss and Q_est calculation.
%   - frac_E2_LN is an example predefined scalar/integral variable.
%   - Each expression should return one value per solved mode when using
%     solnum = 'all'.
cfg.resultExprList = {
    'ewfd.neff'
    'frac_E2_LN'
    % 'substrate_energy_ratio'
    % 'TE_frac'
    % 'TM_frac'
};

cfg.neffExpr = 'ewfd.neff';
cfg.fracExprForQuickPlot = 'frac_E2_LN';

% Output folder
cfg.outputRoot = fullfile(repoRoot, 'local_outputs');
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
cfg.runName = ['waveguide_width_sweep_with_integral_all_modes_', timestamp];
cfg.outputDir = fullfile(cfg.outputRoot, cfg.runName);

cfg.saveAfterEachPoint = true;

%% ===== Prepare output folder =====
if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end
save(fullfile(cfg.outputDir, 'sweep_config.mat'), 'cfg');

%% ===== Load COMSOL model =====
if exist(cfg.modelFile, 'file') ~= 2
    error('LiveLinkSweep:ModelFileNotFound', ...
        ['COMSOL model file not found:\n  %s\n\n', ...
         'Please update cfg.modelFile in this script.'], ...
        cfg.modelFile);
end

fprintf('Loading COMSOL model:\n  %s\n', cfg.modelFile);
model = mphload(cfg.modelFile);

%% ===== Preallocate results =====
N = numel(cfg.wList_um);

emptyResult = struct( ...
    'w_um', NaN, ...
    'success', false, ...
    'message', "", ...
    'runtime_s', NaN, ...
    'numModes', 0, ...
    'modeIndex', [], ...
    'exprList', {cfg.resultExprList}, ...
    'valueMat', [], ...
    'neff_all', [], ...
    'loss_dB_per_cm_all', [], ...
    'Q_est_all', []);

results = repmat(emptyResult, N, 1);

%% ===== Run parameter sweep =====
fprintf('\nStarting all-mode sweep with predefined integral quantities.\n');
fprintf('Number of width points: %d\n', N);
fprintf('Number of expressions: %d\n', numel(cfg.resultExprList));
fprintf('Solution selection: solnum = %s\n\n', string(cfg.solnum));

for jj = 1:N
    w_um = cfg.wList_um(jj);
    tStart = tic;

    fprintf('[%d/%d] %s = %.6g %s ...\n', ...
        jj, N, cfg.paramName, w_um, cfg.paramUnit);

    results(jj).w_um = w_um;

    try
        % Update parameter.
        paramString = sprintf('%.12g[%s]', w_um, cfg.paramUnit);
        model.param.set(cfg.paramName, paramString);

        % Run study.
        model.study(cfg.studyTag).run;

        % Extract all requested expressions for all returned modes.
        [valueMat, exprList] = extract_all_mode_expressions(model, cfg);

        neffCol = find(strcmp(exprList, cfg.neffExpr), 1);
        if isempty(neffCol)
            error('LiveLinkSweep:MissingNeffExpression', ...
                'cfg.resultExprList must include cfg.neffExpr = %s.', ...
                cfg.neffExpr);
        end

        neff_all = valueMat(:, neffCol);
        [loss_dB_per_cm_all, Q_est_all] = neff_to_loss_and_q( ...
            neff_all, cfg.lambda0_um);

        numModes = numel(neff_all);

        results(jj).success = true;
        results(jj).message = "OK";
        results(jj).runtime_s = toc(tStart);
        results(jj).numModes = numModes;
        results(jj).modeIndex = (1:numModes).';
        results(jj).exprList = exprList;
        results(jj).valueMat = valueMat;
        results(jj).neff_all = neff_all;
        results(jj).loss_dB_per_cm_all = loss_dB_per_cm_all;
        results(jj).Q_est_all = Q_est_all;

        fprintf('  Returned modes: %d\n', numModes);
        fprintf('  real(neff) range: %.6g to %.6g\n', ...
            min(real(neff_all)), max(real(neff_all)));
        fprintf('  loss range: %.6g to %.6g dB/cm\n', ...
            min(loss_dB_per_cm_all), max(loss_dB_per_cm_all));
        fprintf('  done. time = %.2f s\n\n', results(jj).runtime_s);

    catch ME
        results(jj).success = false;
        results(jj).message = string(ME.message);
        results(jj).runtime_s = toc(tStart);

        fprintf('  failed. time = %.2f s\n', results(jj).runtime_s);
        fprintf('  Error: %s\n\n', ME.message);
    end

    if cfg.saveAfterEachPoint
        save(fullfile(cfg.outputDir, 'sweep_raw.mat'), 'cfg', 'results');
    end
end

%% ===== Save final results =====
allModeTable = make_all_mode_summary_table(results, cfg);
pointSummaryTable = make_point_summary_table(results);

save(fullfile(cfg.outputDir, 'sweep_raw.mat'), ...
    'cfg', 'results', 'allModeTable', 'pointSummaryTable');

writetable(allModeTable, ...
    fullfile(cfg.outputDir, 'sweep_all_modes.csv'));

writetable(pointSummaryTable, ...
    fullfile(cfg.outputDir, 'sweep_point_summary.csv'));

fprintf('\nSweep finished.\n');
fprintf('Results saved to:\n  %s\n', cfg.outputDir);
fprintf('All-mode table:\n  %s\n', ...
    fullfile(cfg.outputDir, 'sweep_all_modes.csv'));


%% ===== Local helper functions =====
function [valueMat, exprList] = extract_all_mode_expressions(model, cfg)
%EXTRACT_ALL_MODE_EXPRESSIONS Extract all expressions for all returned modes.

    exprList = cfg.resultExprList(:);
    numExpr = numel(exprList);

    rawCell = cell(numExpr, 1);
    numValues = zeros(numExpr, 1);

    for kk = 1:numExpr
        expr = exprList{kk};

        rawValue = mphglobal(model, expr, ...
            'dataset', cfg.datasetTag, ...
            'solnum', cfg.solnum, ...
            'Complexout', 'on');

        rawValue = rawValue(:);

        rawCell{kk} = rawValue;
        numValues(kk) = numel(rawValue);
    end

    numModes = max(numValues);

    if numModes == 0
        valueMat = complex(NaN(0, numExpr));
        return;
    end

    valueMat = complex(NaN(numModes, numExpr));

    for kk = 1:numExpr
        if numValues(kk) == numModes
            valueMat(:, kk) = rawCell{kk};

        elseif numValues(kk) == 1 && numModes > 1
            % Some global quantities may return a single scalar. Repeat it
            % only as a fallback. For modal quantities, matching numModes is
            % preferred.
            valueMat(:, kk) = repmat(rawCell{kk}, numModes, 1);

            warning('LiveLinkSweep:ScalarRepeatedAcrossModes', ...
                ['Expression "%s" returned one scalar while other ', ...
                 'expressions returned %d modes. The scalar value was ', ...
                 'repeated across all modes.'], ...
                exprList{kk}, numModes);

        else
            error('LiveLinkSweep:ExpressionLengthMismatch', ...
                ['Expression "%s" returned %d values, but expected %d.\n', ...
                 'Check that this expression is defined for every mode ', ...
                 'solution and that dataset/solnum are correct.'], ...
                exprList{kk}, numValues(kk), numModes);
        end
    end
end

function [loss_dB_per_cm, Q_est] = neff_to_loss_and_q(neff, lambda0_um)
%NEFF_TO_LOSS_AND_Q Convert imag(neff) to loss and a rough Q metric.
%
% Field convention screening formula:
%   alpha_power = 2*k0*abs(imag(neff))
%   loss_dB_per_m = 10*log10(exp(1))*alpha_power
%
% Q_est uses real(neff) as a rough replacement for group index. It is only
% intended as a screening metric.

    lambda0_m = lambda0_um * 1e-6;
    k0 = 2*pi/lambda0_m;

    alpha_power_per_m = 2*k0*abs(imag(neff));
    loss_dB_per_m = 10*log10(exp(1)) * alpha_power_per_m;
    loss_dB_per_cm = loss_dB_per_m / 100;

    denom = 2*abs(imag(neff));
    Q_est = real(neff) ./ denom;
    Q_est(denom == 0) = Inf;
end

function T = make_all_mode_summary_table(results, cfg)
%MAKE_ALL_MODE_SUMMARY_TABLE Create one table row per sweep point and mode.

    T = table();

    for jj = 1:numel(results)
        if ~results(jj).success || isempty(results(jj).valueMat)
            continue;
        end

        numModes = results(jj).numModes;
        thisT = table( ...
            repmat(jj, numModes, 1), ...
            repmat(results(jj).w_um, numModes, 1), ...
            results(jj).modeIndex(:), ...
            real(results(jj).neff_all(:)), ...
            imag(results(jj).neff_all(:)), ...
            results(jj).loss_dB_per_cm_all(:), ...
            results(jj).Q_est_all(:), ...
            'VariableNames', { ...
                'sweep_index', ...
                'w_um', ...
                'mode_index', ...
                'neff_real', ...
                'neff_imag', ...
                'loss_dB_per_cm', ...
                'Q_est'});

        exprList = results(jj).exprList(:);
        valueMat = results(jj).valueMat;

        for kk = 1:numel(exprList)
            baseName = matlab.lang.makeValidName(exprList{kk});
            thisT.([baseName, '_real']) = real(valueMat(:, kk));
            thisT.([baseName, '_imag']) = imag(valueMat(:, kk));
        end

        T = [T; thisT]; %#ok<AGROW>
    end
end

function T = make_point_summary_table(results)
%MAKE_POINT_SUMMARY_TABLE Create one table row per sweep point.

    N = numel(results);

    sweepIndex = (1:N).';
    w_um = NaN(N, 1);
    success = false(N, 1);
    numModes = NaN(N, 1);
    runtime_s = NaN(N, 1);
    message = strings(N, 1);

    for jj = 1:N
        w_um(jj) = results(jj).w_um;
        success(jj) = results(jj).success;
        numModes(jj) = results(jj).numModes;
        runtime_s(jj) = results(jj).runtime_s;
        message(jj) = results(jj).message;
    end

    T = table(sweepIndex, w_um, success, numModes, runtime_s, message);
end