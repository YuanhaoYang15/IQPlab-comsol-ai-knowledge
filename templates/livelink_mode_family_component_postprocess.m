%% LiveLink Module 05A: Component-ratio post-processing
% This script loads saved component-ratio results and makes diagnostic plots.
% It does NOT run COMSOL.

clear; clc; close all;

%% ===================== 1. User configuration =====================
thisFile = mfilename('fullpath');
if isempty(thisFile)
    templateDir = pwd;
else
    templateDir = fileparts(thisFile);
end
repoRoot = fileparts(templateDir);

cfgPost = struct();

% Leave empty to automatically use the newest component-ratio output folder.
cfgPost.resultDir = '';

% Which table to plot:
%   'accepted' : mode_family_metrics.csv
%   'all'      : mode_family_all_modes.csv
cfgPost.tableMode = 'accepted';

cfgPost.plotNeffColoredByExFrac = true;
cfgPost.plotNeffColoredByEyFrac = true;
cfgPost.plotLossVsWidth = true;
cfgPost.plotFractionsVsWidth = true;
cfgPost.plotFamilyLabels = true;

%% ===================== 2. Locate result folder =====================
if isempty(cfgPost.resultDir)
    outputRoot = fullfile(repoRoot, 'local_outputs');
    cfgPost.resultDir = find_newest_folder( ...
        outputRoot, 'mode_family_component_ratio_*');
end

switch lower(cfgPost.tableMode)
    case 'accepted'
        metricsFile = fullfile(cfgPost.resultDir, 'mode_family_metrics.csv');
    case 'all'
        metricsFile = fullfile(cfgPost.resultDir, 'mode_family_all_modes.csv');
    otherwise
        error('ModeFamily:UnknownTableMode', ...
            'Unknown cfgPost.tableMode: %s', cfgPost.tableMode);
end

if exist(metricsFile, 'file') ~= 2
    error('ModeFamily:MetricsFileNotFound', ...
        'Cannot find metrics file:\n  %s', metricsFile);
end

T = readtable(metricsFile);

fprintf('Loaded mode-family metrics:\n  %s\n', metricsFile);
fprintf('Number of plotted rows: %d\n', height(T));

if isempty(T)
    warning('ModeFamily:EmptyTable', ...
        'The selected metrics table is empty. No plots will be generated.');
    return;
end

%% ===================== 3. Diagnostic plots =====================
if cfgPost.plotNeffColoredByExFrac
    figure;
    scatter(T.w_um, T.neff_real, 40, T.Ex_frac_xy, 'filled');
    grid on;
    colorbar;
    xlabel('Waveguide width (\mum)');
    ylabel('real(n_{eff})');
    title('Mode family map colored by Ex fraction');
end

if cfgPost.plotNeffColoredByEyFrac
    figure;
    scatter(T.w_um, T.neff_real, 40, T.Ey_frac_xy, 'filled');
    grid on;
    colorbar;
    xlabel('Waveguide width (\mum)');
    ylabel('real(n_{eff})');
    title('Mode family map colored by Ey fraction');
end

if cfgPost.plotLossVsWidth
    figure;
    semilogy(T.w_um, T.loss_dB_per_cm, '.', 'MarkerSize', 12);
    grid on;
    xlabel('Waveguide width (\mum)');
    ylabel('Loss estimated from imag(n_{eff}) (dB/cm)');
    title('Mode loss versus waveguide width');
end

if cfgPost.plotFractionsVsWidth
    figure;
    hold on;
    plot(T.w_um, T.Ex_frac_xy, '.', 'MarkerSize', 12);
    plot(T.w_um, T.Ey_frac_xy, '.', 'MarkerSize', 12);
    grid on;
    xlabel('Waveguide width (\mum)');
    ylabel('Component fraction');
    title('Ex/Ey component fractions');
    legend('Ex fraction in Ex+Ey', 'Ey fraction in Ex+Ey', ...
        'Location', 'best');
    hold off;
end

if cfgPost.plotFamilyLabels
    figure;
    hold on;

    labels = string(T.family_label);
    uniqueLabels = unique(labels);

    for kk = 1:numel(uniqueLabels)
        idx = labels == uniqueLabels(kk);
        plot(T.w_um(idx), T.neff_real(idx), '.', ...
            'MarkerSize', 14, ...
            'DisplayName', uniqueLabels(kk));
    end

    grid on;
    xlabel('Waveguide width (\mum)');
    ylabel('real(n_{eff})');
    title('Mode branches grouped by component-ratio label');
    legend('Location', 'best');
    hold off;
end

%% ===================== Local helper functions =====================
function resultDir = find_newest_folder(outputRoot, pattern)
%FIND_NEWEST_FOLDER Find newest folder matching a pattern.

    folderList = dir(fullfile(outputRoot, pattern));
    folderList = folderList([folderList.isdir]);

    if isempty(folderList)
        error('ModeFamily:NoOutputFolder', ...
            'No output folder found in %s matching pattern %s', ...
            outputRoot, pattern);
    end

    [~, idx] = max([folderList.datenum]);
    resultDir = fullfile(folderList(idx).folder, folderList(idx).name);
end
