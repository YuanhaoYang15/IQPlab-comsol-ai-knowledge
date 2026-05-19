clear; close all; clc;

%% Batch_postprocess_ring_qpm_jump_breaks.m
% Post-process saved Module 07 Ring QPM results without rerunning COMSOL.
%
% This template reloads saved all-mode data from run_ring_qpm_case, reselects
% IR and SH branches using configurable Q and polarization thresholds, detects
% selected-branch neff jumps, splits dispersion calculations at jump boundaries,
% and writes auditable tables plus per-case processed .mat files.
%
% Use this when the original COMSOL sweep is expensive but branch-selection or
% jump-detection thresholds need to be reviewed.

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));

%% User configuration

cfg = struct();

% Source folders to scan for saved RingQPM_*.mat files. Leave empty to use
% templates/ring_qpm/results.
cfg.source_roots = {
    fullfile(project_root, 'results')
    };

% Optional explicit result files. These are processed in addition to source_roots.
cfg.source_files = {};

% Recursively scan source_roots for RingQPM_*.mat.
cfg.recursive = true;
cfg.file_pattern = 'RingQPM_*.mat';

% Branch reselection thresholds. Leave cfg.Q_threshold = [] to reuse out.opts.
cfg.Q_threshold = [];
cfg.pol_threshold = 0.5;

% Jump detection settings.
cfg.jump_window_half_width = 5;
cfg.jump_ratio_threshold = 3;
cfg.jump_abs_floor = 1e-3;
cfg.min_segment_points = 8;

% Output and plotting.
cfg.output_root = fullfile(project_root, 'results', ...
    ['postprocessed_jump_break_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
cfg.save_case_plots = true;
cfg.save_fig = true;
cfg.save_png = true;
cfg.IR_color = [0.0000 0.4470 0.7410];
cfg.SH_color = [0.8500 0.3250 0.0980];

%% Collect files

if ~exist(cfg.output_root, 'dir')
    mkdir(cfg.output_root);
end
case_root = fullfile(cfg.output_root, 'cases');
if ~exist(case_root, 'dir')
    mkdir(case_root);
end

source_files = collect_result_files(cfg);
save(fullfile(cfg.output_root, 'postprocess_config.mat'), 'cfg', 'source_files');

fprintf('Post-processing output root:\n%s\n', cfg.output_root);
fprintf('Candidate result files: %d\n', numel(source_files));

%% Process files

summary_rows = {};
jump_rows = {};
skipped_rows = {};

for ii = 1:numel(source_files)
    source_file = source_files{ii};
    try
        S = load(source_file, 'out');
        if ~isfield(S, 'out')
            skipped_rows(end+1,:) = {source_file, 'missing_out'}; %#ok<AGROW>
            continue;
        end
        out = S.out;
        if ~isfield(out, 'status') || ~strcmp(string(out.status), "success")
            skipped_rows(end+1,:) = {source_file, 'status_not_success'}; %#ok<AGROW>
            continue;
        end

        processed = process_one_result(out, source_file, cfg);
        case_dir = fullfile(case_root, make_case_tag(processed.meta, ii));
        if ~exist(case_dir, 'dir')
            mkdir(case_dir);
        end

        save(fullfile(case_dir, 'processed_result.mat'), 'processed', '-v7.3');
        write_case_summary(fullfile(case_dir, 'case_summary.txt'), processed);
        if cfg.save_case_plots
            make_case_plots(case_dir, processed, cfg);
        end

        summary_rows(end+1,:) = make_summary_row(source_file, case_dir, processed); %#ok<AGROW>
        jump_rows = append_jump_rows(jump_rows, source_file, case_dir, processed);
        fprintf('Processed %d/%d: %s\n', ii, numel(source_files), source_file);
    catch ME
        skipped_rows(end+1,:) = {source_file, ME.message}; %#ok<AGROW>
        fprintf('Skipped %d/%d: %s\n  %s\n', ii, numel(source_files), source_file, ME.message);
    end
end

batch_summary = cell2table_safe(summary_rows, {'source_file','case_dir', ...
    'Radius','w_ln','t_ln','t_ridge','theta_deg','IR_pol','IR_order','SH_pol','SH_order', ...
    'lambda0_IR','span_IR','step_IR','IR_jump_count','SH_jump_count', ...
    'IR_segment_count','SH_segment_count','QPM_valid_points','GVM_valid_points'});
jump_warnings = cell2table_safe(jump_rows, {'source_file','case_dir','band','jump_index', ...
    'lambda_left_nm','lambda_right_nm','delta_neff','local_delta_neff','jump_ratio', ...
    'solnum_left','solnum_right','TE_left','TE_right','TM_left','TM_right','Q_left','Q_right'});
skipped_files = cell2table_safe(skipped_rows, {'source_file','reason'});

writetable(batch_summary, fullfile(cfg.output_root, 'batch_summary.csv'));
writetable(jump_warnings, fullfile(cfg.output_root, 'jump_warnings.csv'));
writetable(skipped_files, fullfile(cfg.output_root, 'skipped_files.csv'));
save(fullfile(cfg.output_root, 'batch_tables.mat'), 'batch_summary', 'jump_warnings', 'skipped_files');

fprintf('\nPost-processing finished.\n');
fprintf('Output root:\n%s\n', cfg.output_root);
fprintf('Processed files: %d\n', height(batch_summary));
fprintf('Jump warnings: %d\n', height(jump_warnings));
fprintf('Skipped files: %d\n', height(skipped_files));

%% Local functions

function files = collect_result_files(cfg)
files = cfg.source_files(:);
for ii = 1:numel(cfg.source_roots)
    root = cfg.source_roots{ii};
    if exist(root, 'dir') ~= 7
        warning('Source root does not exist: %s', root);
        continue;
    end
    if cfg.recursive
        listing = dir(fullfile(root, '**', cfg.file_pattern));
    else
        listing = dir(fullfile(root, cfg.file_pattern));
    end
    for jj = 1:numel(listing)
        if ~listing(jj).isdir
            files{end+1,1} = fullfile(listing(jj).folder, listing(jj).name); %#ok<AGROW>
        end
    end
end
files = unique(files, 'stable');
end

function processed = process_one_result(out, source_file, cfg)
c0 = 299792458;
meta = extract_meta(out);
q_threshold = get_q_threshold(out, cfg);

IR_sel = reselect_band(out.Data_IR, out.select.IR.pol, out.select.IR.order, q_threshold, cfg.pol_threshold);
SH_sel = reselect_band(out.Data_SH, out.select.SH.pol, out.select.SH.order, q_threshold, cfg.pol_threshold);

jump_opts = struct('ratioThreshold', cfg.jump_ratio_threshold, ...
    'windowHalfWidth', cfg.jump_window_half_width, ...
    'absFloor', cfg.jump_abs_floor, ...
    'minSegmentPoints', cfg.min_segment_points);

IR = make_band('IR', out.lambda_IR(:), IR_sel, out.geom.Radius, out.scan.lambda0_IR, c0, jump_opts);
SH = make_band('SH', out.lambda_SH(:), SH_sel, out.geom.Radius, out.scan.lambda0_IR/2, c0, jump_opts);

[Lambda_QPM_um, GVM_fs_per_mm] = calc_qpm_gvm(out.lambda_IR(:), IR.neff(:), IR.ng(:), SH, c0);
Walk = calc_walk(IR, SH);

processed = struct();
processed.source_file = source_file;
processed.meta = meta;
processed.cfg = cfg;
processed.q_threshold = q_threshold;
processed.pol_threshold = cfg.pol_threshold;
processed.jump_opts = jump_opts;
processed.IR = IR;
processed.SH = SH;
processed.Lambda_QPM_um = Lambda_QPM_um;
processed.GVM_fs_per_mm = GVM_fs_per_mm;
processed.Walk = Walk;
end

function meta = extract_meta(out)
meta = struct();
names = {'Radius','w_ln','t_ln','t_ridge','theta_deg'};
for ii = 1:numel(names)
    if isfield(out.geom, names{ii})
        meta.(names{ii}) = out.geom.(names{ii});
    else
        meta.(names{ii}) = NaN;
    end
end
meta.IR_pol = string(out.select.IR.pol);
meta.IR_order = out.select.IR.order;
meta.SH_pol = string(out.select.SH.pol);
meta.SH_order = out.select.SH.order;
meta.lambda0_IR = out.scan.lambda0_IR;
meta.span_IR = out.scan.span_IR;
meta.step_IR = out.scan.step_IR;
end

function q_threshold = get_q_threshold(out, cfg)
if ~isempty(cfg.Q_threshold)
    q_threshold = cfg.Q_threshold;
elseif isfield(out, 'opts') && isfield(out.opts, 'Q_threshold')
    q_threshold = out.opts.Q_threshold;
else
    q_threshold = 1e4;
end
end

function Sel = reselect_band(Data, pol, order_target, Q_th, pol_th)
n_point = numel(Data.lambda_um);
Sel = struct();
Sel.neff = nan(n_point,1);
Sel.neff_raw = nan(n_point,1);
Sel.Q = nan(n_point,1);
Sel.TE = nan(n_point,1);
Sel.TM = nan(n_point,1);
Sel.solnum = nan(n_point,1);
Sel.has_candidate = false(n_point,1);

for ii = 1:n_point
    neff = Data.neff_all(ii,:).';
    neff_raw = Data.neff_raw_all(ii,:).';
    Q = Data.Q_all(ii,:).';
    TE = Data.TE_all(ii,:).';
    TM = Data.TM_all(ii,:).';

    is_bound = Q > Q_th & isfinite(Q) & real(neff) > 1;
    switch upper(pol)
        case 'TE'
            is_pol = TE >= pol_th & TE >= TM;
        case 'TM'
            is_pol = TM >= pol_th & TM > TE;
        otherwise
            error('Unknown polarization: %s', pol);
    end

    idx = find(is_bound & is_pol);
    if isempty(idx) || order_target > numel(idx)
        continue;
    end
    [~, sort_idx] = sort(real(neff(idx)), 'descend');
    idx = idx(sort_idx);
    kk = idx(order_target);

    Sel.has_candidate(ii) = true;
    Sel.neff(ii) = real(neff(kk));
    Sel.neff_raw(ii) = real(neff_raw(kk));
    Sel.Q(ii) = Q(kk);
    Sel.TE(ii) = TE(kk);
    Sel.TM(ii) = TM(kk);
    Sel.solnum(ii) = kk;
end
end

function Band = make_band(label, lambda, Sel, R_um, center_um, c0, opts)
finite = isfinite(Sel.neff);
jump = detect_jumps(lambda, Sel, opts);
segments = finite_segments(finite, jump.is_jump, opts.minSegmentPoints);
ng = nan(size(lambda));
results = struct([]);

for ss = 1:size(segments,1)
    idx = segments(ss,1):segments(ss,2);
    ng(idx) = calc_ng(lambda(idx), Sel.neff(idx));
    results(end+1).idx = idx; %#ok<AGROW>
    try
        results(end).Result = calc_dint(lambda(idx), Sel.neff(idx), R_um, center_um, c0, ...
            sprintf('%s segment %d', label, ss));
        results(end).message = "";
    catch ME
        results(end).Result = [];
        results(end).message = string(ME.message);
    end
end

Band = struct('label', label, 'lambda', lambda, 'neff', Sel.neff, ...
    'neff_raw', Sel.neff_raw, 'Q', Sel.Q, 'TE', Sel.TE, 'TM', Sel.TM, ...
    'solnum', Sel.solnum, 'has_candidate', Sel.has_candidate, ...
    'jump', jump, 'segments', segments, 'ng', ng, 'results', results);
end

function jump = detect_jumps(lambda, Sel, opts)
neff = Sel.neff(:);
d = abs(diff(neff));
local = nan(size(d));
ratio = nan(size(d));
is_jump = false(size(d));

for kk = 1:numel(d)
    if ~isfinite(d(kk))
        continue;
    end
    lo = max(1, kk - opts.windowHalfWidth);
    hi = min(numel(d), kk + opts.windowHalfWidth);
    neighbors = d(lo:hi);
    neighbors(kk-lo+1) = [];
    neighbors = neighbors(isfinite(neighbors));
    if isempty(neighbors)
        local(kk) = opts.absFloor;
    else
        local(kk) = max(median(neighbors), opts.absFloor);
    end
    ratio(kk) = d(kk) / local(kk);
    is_jump(kk) = d(kk) >= opts.absFloor && ratio(kk) >= opts.ratioThreshold;
end

jump = struct();
jump.lambda_left = lambda(1:end-1);
jump.lambda_right = lambda(2:end);
jump.delta_neff = d;
jump.local_delta_neff = local;
jump.jump_ratio = ratio;
jump.is_jump = is_jump;
jump.index = find(is_jump);
jump.solnum_left = Sel.solnum(1:end-1);
jump.solnum_right = Sel.solnum(2:end);
jump.TE_left = Sel.TE(1:end-1);
jump.TE_right = Sel.TE(2:end);
jump.TM_left = Sel.TM(1:end-1);
jump.TM_right = Sel.TM(2:end);
jump.Q_left = Sel.Q(1:end-1);
jump.Q_right = Sel.Q(2:end);
end

function segments = finite_segments(finite, is_jump, min_pts)
segments = zeros(0,2);
start_idx = [];
for ii = 1:numel(finite)
    if finite(ii) && isempty(start_idx)
        start_idx = ii;
    end
    end_here = false;
    if ~isempty(start_idx)
        if ~finite(ii)
            end_here = true;
            end_idx = ii - 1;
        elseif ii < numel(finite) && is_jump(ii)
            end_here = true;
            end_idx = ii;
        elseif ii == numel(finite)
            end_here = true;
            end_idx = ii;
        end
        if end_here
            if end_idx - start_idx + 1 >= min_pts
                segments(end+1,:) = [start_idx, end_idx]; %#ok<AGROW>
            end
            start_idx = [];
        end
    end
end
end

function ng = calc_ng(lambda, neff)
lambda = lambda(:);
neff = neff(:);
ng = nan(size(lambda));
if numel(lambda) < 3
    return;
end
dneff_dlambda = gradient(neff, lambda);
ng = neff - lambda .* dneff_dlambda;
end

function Result = calc_dint(lambda, neff, R_um, center_um, c0, label)
lambda = lambda(:);
neff = neff(:);
valid = isfinite(lambda) & isfinite(neff);
lambda = lambda(valid);
neff = neff(valid);
if numel(lambda) < 5
    error('At least five valid wavelength points are required for %s.', label);
end

omega = 2*pi*c0./(lambda*1e-6);
m_float = 2*pi*R_um.*neff./lambda;
[m_float, sort_idx] = sort(m_float);
omega = omega(sort_idx);

m_int_min = ceil(min(m_float));
m_int_max = floor(max(m_float));
if m_int_max - m_int_min < 4
    error('Integer mode range is too small for %s.', label);
end
m_int = (m_int_min:m_int_max).';
omega_int = interp1(m_float, omega, m_int, 'pchip');

m0 = round(interp1(lambda, 2*pi*R_um.*neff./lambda, center_um, 'pchip'));
omega0 = interp1(m_int, omega_int, m0, 'pchip');
mu = m_int - m0;

fit_coef = polyfit(mu, omega_int, 2);
D1 = fit_coef(2);
D2 = 2*fit_coef(1);
Dint = omega_int - (omega0 + D1*mu);

Result = struct();
Result.label = label;
Result.m_int = m_int;
Result.mu = mu;
Result.omega_rad_s = omega_int;
Result.freq_Hz = omega_int/(2*pi);
Result.m0 = m0;
Result.omega0_rad_s = omega0;
Result.D1_rad_s = D1;
Result.D1_Hz = D1/(2*pi);
Result.D2_rad_s = D2;
Result.D2_Hz = D2/(2*pi);
Result.Dint_rad_s = Dint;
Result.Dint_Hz = Dint/(2*pi);
end

function [Lambda, GVM] = calc_qpm_gvm(lambda_IR, neff_IR, ng_IR, SH, c0)
lambda_SH_query = lambda_IR(:)/2;
neff_SH = interp1(SH.lambda(:), SH.neff(:), lambda_SH_query, 'pchip', NaN);
ng_SH = interp1(SH.lambda(:), SH.ng(:), lambda_SH_query, 'pchip', NaN);
Lambda = abs(lambda_IR(:) ./ (2*(neff_SH(:)-neff_IR(:))));
GVM = ((ng_SH(:)-ng_IR(:))/c0)*1e12;
end

function Walk = calc_walk(IR, SH)
Walk = struct('mu_IR', [], 'mu_SH', [], 'Delta_f_SHG_Hz', [], 'Delta_f_rel_Hz', []);
if isempty(IR.results) || isempty(SH.results)
    return;
end

rows = [];
for ii = 1:numel(IR.results)
    if isempty(IR.results(ii).Result)
        continue;
    end
    Rir = IR.results(ii).Result;
    for jj = 1:numel(SH.results)
        if isempty(SH.results(jj).Result)
            continue;
        end
        Rsh = SH.results(jj).Result;
        mu_IR = Rir.mu(:);
        mu_SH = 2*mu_IR;
        f_SH = interp1(Rsh.mu(:), Rsh.freq_Hz(:), mu_SH, 'pchip', NaN);
        delta = f_SH - 2*Rir.freq_Hz(:);
        rows = [rows; [mu_IR, mu_SH, delta]]; %#ok<AGROW>
    end
end
if isempty(rows)
    return;
end
[mu_unique, idx] = unique(rows(:,1), 'stable');
mu_SH = rows(idx,2);
delta = rows(idx,3);
delta0 = interp1(mu_unique, delta, 0, 'pchip', NaN);
Walk.mu_IR = mu_unique;
Walk.mu_SH = mu_SH;
Walk.Delta_f_SHG_Hz = delta;
Walk.Delta_f_rel_Hz = delta - delta0;
end

function tag = make_case_tag(meta, idx)
tag = sprintf('%03d_R%s_w%s_tln%s_tr%s_th%s_IR%s%d_SH%s%d', ...
    idx, num_tag(meta.Radius), num_tag(meta.w_ln), num_tag(meta.t_ln), ...
    num_tag(meta.t_ridge), num_tag(meta.theta_deg), ...
    upper(meta.IR_pol), meta.IR_order-1, upper(meta.SH_pol), meta.SH_order-1);
end

function s = num_tag(x)
s = sprintf('%.6g', x);
s = strrep(s, '.', 'p');
s = strrep(s, '-', 'm');
end

function make_case_plots(case_dir, processed, cfg)
figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 980, 760]);
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot_segments(gca, processed.IR.lambda*1e3, processed.IR.neff, processed.IR.segments, 'o-', cfg.IR_color, 'IR');
hold on;
plot_segments(gca, processed.SH.lambda*1e3, processed.SH.neff, processed.SH.segments, 's-', cfg.SH_color, 'SH');
grid on; box on; xlabel('Wavelength (nm)'); ylabel('Selected neff'); legend('Location', 'best');

nexttile;
semilogy(processed.IR.lambda*1e3, processed.IR.Q, 'o-', 'Color', cfg.IR_color); hold on;
semilogy(processed.SH.lambda*1e3, processed.SH.Q, 's-', 'Color', cfg.SH_color);
grid on; box on; xlabel('Wavelength (nm)'); ylabel('Selected Q'); legend({'IR','SH'}, 'Location', 'best');

nexttile;
plot(processed.IR.lambda*1e3, processed.Lambda_QPM_um, 'k.-');
grid on; box on; xlabel('IR wavelength (nm)'); ylabel('QPM period (um)');

save_current_figure(case_dir, 'selected_branch_summary', cfg);

figure('Visible', 'off', 'Color', 'w', 'Position', [140, 120, 980, 700]);
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot_result_segments(processed.IR.results, cfg.IR_color, '-'); hold on;
plot_result_segments(processed.SH.results, cfg.SH_color, '--');
grid on; box on; xlabel('mu'); ylabel('Dint / 2pi (Hz)'); legend({'IR','SH'}, 'Location', 'best');

nexttile;
plot(processed.Walk.mu_IR, processed.Walk.Delta_f_rel_Hz/1e9, 'k.-');
grid on; box on; xlabel('IR mu'); ylabel('Relative SHG mismatch (GHz)');
save_current_figure(case_dir, 'segmented_dispersion_summary', cfg);
end

function plot_segments(ax, x, y, segments, style, color, label)
first = true;
for ss = 1:size(segments,1)
    idx = segments(ss,1):segments(ss,2);
    if first
        plot(ax, x(idx), y(idx), style, 'Color', color, 'LineWidth', 1.3, 'DisplayName', label);
        first = false;
    else
        plot(ax, x(idx), y(idx), style, 'Color', color, 'LineWidth', 1.3, 'HandleVisibility', 'off');
    end
    hold(ax, 'on');
end
end

function plot_result_segments(results, color, style)
for ii = 1:numel(results)
    if isempty(results(ii).Result)
        continue;
    end
    R = results(ii).Result;
    plot(R.mu, R.Dint_Hz, style, 'Color', color, 'LineWidth', 1.3);
    hold on;
end
end

function save_current_figure(case_dir, base_name, cfg)
if cfg.save_fig
    savefig(fullfile(case_dir, [base_name '.fig']));
end
if cfg.save_png
    exportgraphics(gcf, fullfile(case_dir, [base_name '.png']), 'Resolution', 200);
end
close(gcf);
end

function write_case_summary(path, processed)
fid = fopen(path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Ring QPM jump-break post-processing summary\n');
fprintf(fid, 'Source file: %s\n', processed.source_file);
fprintf(fid, 'Q threshold: %.6g\n', processed.q_threshold);
fprintf(fid, 'Polarization threshold: %.6g\n\n', processed.pol_threshold);
fprintf(fid, 'Geometry: R=%.6g um, w=%.6g um, tLN=%.6g um, tRidge=%.6g um, theta=%.6g deg\n', ...
    processed.meta.Radius, processed.meta.w_ln, processed.meta.t_ln, ...
    processed.meta.t_ridge, processed.meta.theta_deg);
write_band_summary(fid, processed.IR);
write_band_summary(fid, processed.SH);
fprintf(fid, '\nValid QPM points: %d\n', sum(isfinite(processed.Lambda_QPM_um)));
fprintf(fid, 'Valid GVM points: %d\n', sum(isfinite(processed.GVM_fs_per_mm)));
end

function write_band_summary(fid, B)
fprintf(fid, '\n%s band\n', B.label);
fprintf(fid, '  Valid selected points: %d\n', sum(isfinite(B.neff)));
fprintf(fid, '  Jump count: %d\n', numel(B.jump.index));
fprintf(fid, '  Segment count: %d\n', size(B.segments,1));
if ~isempty(B.jump.index)
    fprintf(fid, '  Jump indices: %s\n', mat2str(B.jump.index(:).'));
end
end

function row = make_summary_row(source_file, case_dir, p)
m = p.meta;
row = {source_file, case_dir, m.Radius, m.w_ln, m.t_ln, m.t_ridge, m.theta_deg, ...
    char(m.IR_pol), m.IR_order, char(m.SH_pol), m.SH_order, ...
    m.lambda0_IR, m.span_IR, m.step_IR, ...
    numel(p.IR.jump.index), numel(p.SH.jump.index), ...
    size(p.IR.segments,1), size(p.SH.segments,1), ...
    sum(isfinite(p.Lambda_QPM_um)), sum(isfinite(p.GVM_fs_per_mm))};
end

function rows = append_jump_rows(rows, source_file, case_dir, p)
rows = append_band_jump_rows(rows, source_file, case_dir, p.IR);
rows = append_band_jump_rows(rows, source_file, case_dir, p.SH);
end

function rows = append_band_jump_rows(rows, source_file, case_dir, B)
for jj = 1:numel(B.jump.index)
    kk = B.jump.index(jj);
    rows(end+1,:) = {source_file, case_dir, B.label, kk, ...
        B.jump.lambda_left(kk)*1e3, B.jump.lambda_right(kk)*1e3, ...
        B.jump.delta_neff(kk), B.jump.local_delta_neff(kk), B.jump.jump_ratio(kk), ...
        B.jump.solnum_left(kk), B.jump.solnum_right(kk), ...
        B.jump.TE_left(kk), B.jump.TE_right(kk), ...
        B.jump.TM_left(kk), B.jump.TM_right(kk), ...
        B.jump.Q_left(kk), B.jump.Q_right(kk)}; %#ok<AGROW>
end
end

function T = cell2table_safe(rows, names)
if isempty(rows)
    T = cell2table(cell(0, numel(names)), 'VariableNames', names);
else
    T = cell2table(rows, 'VariableNames', names);
end
end
