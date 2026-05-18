%% LIVELINK_COUPLED_Q_2DSYM_POSTPROCESS
%
% Post-process Module 06 coupled-Q output without rerunning COMSOL.

clear; clc; close all;

%% ===================== 1. User configuration =====================
scriptDir = fileparts(mfilename('fullpath'));
repoRoot  = fileparts(scriptDir);

cfg = struct();
cfg.outputRoot = fullfile(repoRoot, 'local_outputs');

% Leave empty to use the latest coupled_q_2dsym_* folder.
cfg.runDir = '';

cfg.yLim_Qc = [1e4, 1e9];
cfg.saveFigures = true;

%% ===================== 2. Locate and load data =====================
if isempty(cfg.runDir)
    d = dir(fullfile(cfg.outputRoot, 'coupled_q_2dsym_*'));
    d = d([d.isdir]);
    if isempty(d)
        error('No coupled_q_2dsym_* output folder found under:\n  %s', ...
            cfg.outputRoot);
    end
    [~, idx] = max([d.datenum]);
    cfg.runDir = fullfile(d(idx).folder, d(idx).name);
end

rawMatFile = fullfile(cfg.runDir, 'coupled_q_raw.mat');
if exist(rawMatFile, 'file') ~= 2
    error('Raw result file not found:\n  %s', rawMatFile);
end

fprintf('Loading coupled-Q result:\n  %s\n', rawMatFile);
S = load(rawMatFile);

figDir = fullfile(cfg.runDir, 'postprocess_figures');
if cfg.saveFigures && ~exist(figDir, 'dir')
    mkdir(figDir);
end

%% ===================== 3. Plot Qc =====================
figure('Name', 'Coupled Q Scan', 'Color', 'w', 'Position', [150, 100, 680, 460]);
for ii = 1:numel(S.target_wavelengths)
    semilogy(S.theta_scan_vec, S.res_Qc(ii, :), '-', ...
        'LineWidth', 2, ...
        'DisplayName', sprintf('lambda = %.0f nm', S.target_wavelengths(ii)*1000));
    hold on;
end
grid on; box on;
xlabel('Pulley angle theta (degree)');
ylabel('Coupled Q, Q_c');
ylim(cfg.yLim_Qc);
title(sprintf('R = %.0f um, w_{ring} = %.2f um, w_{bus} = %.2f um, gap = %.2f um', ...
    S.geom.Radius, S.geom.w_ring, S.geom.w_bus, S.geom.w_gap));
legend('Location', 'best');

if cfg.saveFigures
    exportgraphics(gcf, fullfile(figDir, 'Qc_vs_theta.png'), 'Resolution', 200);
end

%% ===================== 4. Plot kappa squared =====================
figure('Name', 'Power Coupling Scan', 'Color', 'w', 'Position', [180, 130, 680, 460]);
for ii = 1:numel(S.target_wavelengths)
    semilogy(S.theta_scan_vec, S.res_Kappa_sq(ii, :), '-', ...
        'LineWidth', 2, ...
        'DisplayName', sprintf('lambda = %.0f nm', S.target_wavelengths(ii)*1000));
    hold on;
end
grid on; box on;
xlabel('Pulley angle theta (degree)');
ylabel('Power coupling coefficient, kappa^2');
title('Estimated pulley power coupling');
legend('Location', 'best');

if cfg.saveFigures
    exportgraphics(gcf, fullfile(figDir, 'kappa2_vs_theta.png'), 'Resolution', 200);
end

%% ===================== 5. Display mode summary =====================
if isfield(S, 'modeSummaryTable')
    disp(S.modeSummaryTable);
else
    T = table(S.target_wavelengths(:), S.res_neff_ring(:), S.res_neff_bus(:), ...
        S.res_Q_ring(:), S.res_Q_bus(:), S.res_Gamma(:), S.res_DeltaBeta(:), ...
        'VariableNames', {'lambda_um', 'neff_ring', 'neff_bus', ...
        'Q_ring', 'Q_bus', 'Gamma_rad_per_m', 'DeltaBeta_rad_per_m'});
    disp(T);
end

fprintf('\nPost-processing finished.\n');
fprintf('Run folder:\n  %s\n', cfg.runDir);
