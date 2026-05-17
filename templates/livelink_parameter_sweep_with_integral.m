%% LiveLink Module 04: Parameter sweep with predefined integral quantities
% This script extends the scalar sweep example.
%
% Use case:
%   The COMSOL model already contains predefined integration operators,
%   variables, or derived scalar expressions, for example:
%       wg_energy_ratio
%       substrate_energy_ratio
%       TE_frac
%       TM_frac
%
% MATLAB then only needs to extract these compact scalar quantities after
% each run using mphglobal.
%
% This is usually better than saving the full field profile for every
% sweep point.

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

% Which solution to extract
cfg.solnum = 1;

% Expressions to extract.
% The first one is usually available in optical mode studies.
% The remaining expressions are examples. They must already be defined in
% the COMSOL model before this script can run successfully.
cfg.resultExprList = {
    'ewfd.neff'
    'wg_energy_ratio'
    % 'substrate_energy_ratio'
    % 'TE_frac'
    % 'TM_frac'
};

% Output folder
cfg.outputRoot = fullfile(repoRoot, 'local_outputs');
cfg.runName = ['waveguide_width_sweep_with_integral_', ...
    datestr(now, 'yyyymmdd_HHMMSS')];
cfg.outputDir = fullfile(cfg.outputRoot, cfg.runName);
cfg.saveAfterEachPoint = true;

%% ===== Prepare output folder =====
if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end
save(fullfile(cfg.outputDir, 'sweep_config.mat'), 'cfg');

%% ===== Load COMSOL model =====
if exist(cfg.modelFile, 'file') ~= 2
    error(['COMSOL model file not found:\n  %s\n\n' ...
           'Please update cfg.modelFile in this script.'], cfg.modelFile);
end

fprintf('Loading COMSOL model:\n  %s\n', cfg.modelFile);
model = mphload(cfg.modelFile);

%% ===== Preallocate results =====
N = numel(cfg.wList_um);
Nexpr = numel(cfg.resultExprList);

valueMat = NaN(N, Nexpr) + 1i*NaN(N, Nexpr);
success = false(N, 1);
message = strings(N, 1);
runtime_s = NaN(N, 1);

%% ===== Run parameter sweep =====
fprintf('\nStarting sweep with predefined integral quantities.\n');
fprintf('Number of points: %d\n', N);
fprintf('Number of expressions: %d\n\n', Nexpr);

for jj = 1:N
    w_um = cfg.wList_um(jj);
    tStart = tic;

    fprintf('[%d/%d] %s = %.6g %s ... ', ...
        jj, N, cfg.paramName, w_um, cfg.paramUnit);

    try
        % Update parameter.
        paramString = sprintf('%.12g[%s]', w_um, cfg.paramUnit);
        model.param.set(cfg.paramName, paramString);

        % Run study.
        model.study(cfg.studyTag).run;

        % Extract all requested scalar expressions.
        for kk = 1:Nexpr
            expr = cfg.resultExprList{kk};
            rawValue = mphglobal(model, expr, ...
                'dataset', cfg.datasetTag, ...
                'solnum', cfg.solnum, ...
                'Complexout', 'on');
            valueMat(jj, kk) = first_scalar(rawValue);
        end

        success(jj) = true;
        message(jj) = "OK";
        runtime_s(jj) = toc(tStart);

        fprintf('done. time = %.2f s\n', runtime_s(jj));

    catch ME
        success(jj) = false;
        message(jj) = string(ME.message);
        runtime_s(jj) = toc(tStart);

        fprintf('failed. time = %.2f s\n', runtime_s(jj));
        fprintf('  Error: %s\n', ME.message);
    end

    if cfg.saveAfterEachPoint
        save(fullfile(cfg.outputDir, 'sweep_raw.mat'), ...
            'cfg', 'valueMat', 'success', 'message', 'runtime_s');
    end
end

%% ===== Save final results =====
summaryTable = make_integral_summary_table( ...
    cfg.wList_um, cfg.resultExprList, valueMat, success, message, runtime_s);

save(fullfile(cfg.outputDir, 'sweep_raw.mat'), ...
    'cfg', 'valueMat', 'success', 'message', 'runtime_s', 'summaryTable');

writetable(summaryTable, fullfile(cfg.outputDir, 'sweep_summary.csv'));

fprintf('\nSweep finished.\n');
fprintf('Results saved to:\n  %s\n', cfg.outputDir);

%% ===== Local helper functions =====
function value = first_scalar(rawValue)
%FIRST_SCALAR Return the first scalar value from a COMSOL result array.

    if isempty(rawValue)
        value = NaN;
    else
        value = rawValue(1);
    end
end

function T = make_integral_summary_table(wList_um, exprList, valueMat, ...
    success, message, runtime_s)
%MAKE_INTEGRAL_SUMMARY_TABLE Create table with real/imag columns.

    N = numel(wList_um);
    T = table((1:N).', wList_um(:), success(:), runtime_s(:), message(:), ...
        'VariableNames', {'index', 'w_um', 'success', 'runtime_s', 'message'});

    for kk = 1:numel(exprList)
        baseName = matlab.lang.makeValidName(exprList{kk});
        T.([baseName, '_real']) = real(valueMat(:, kk));
        T.([baseName, '_imag']) = imag(valueMat(:, kk));
    end
end
