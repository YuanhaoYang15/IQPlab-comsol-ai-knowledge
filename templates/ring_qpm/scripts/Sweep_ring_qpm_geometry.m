clear; close all; clc;

%% Sweep_ring_qpm_geometry.m
% Loads the COMSOL model once, scans geometry, and calls run_ring_qpm_case.

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root,'functions'));
addpath(fullfile(project_root,'plotting'));
model_dir  = fullfile(project_root,'models');
result_dir = fullfile(project_root,'results');
if ~exist(result_dir,'dir'), mkdir(result_dir); end

mph_files = dir(fullfile(model_dir,'*.mph'));
if isempty(mph_files)
    error('No .mph file found in models/ folder.');
elseif numel(mph_files) > 1
    fprintf('Multiple .mph files found. Using the first one:\n%s\n', mph_files(1).name);
end
file_mph = fullfile(model_dir,mph_files(1).name);
fprintf('Loading COMSOL model:\n%s\n', file_mph);
model = mphload(file_mph,'Tag_RingQPM_Sweep');
try model.disableUpdates(true); catch, end

%% Geometry sweep settings
R_list       = 30:10:100;             % [um]
w_list       = 1.1;   % [um]
t_ridge_list = 0.4;           % [um]

base_geom.t_ln      = 0.6;
base_geom.theta_deg = 60;
base_geom.w_pml     = 1.5;
base_geom.t_sio2    = 2.0;
base_geom.t_air     = 2.0;

%% Wavelength scan
scan.lambda0_IR = 1.55;     % [um]
scan.span_IR    = 0.20;     % [um]
scan.step_IR    = 0.002;    % [um]

%% Mode selection
select.IR.pol   = 'TM';     % 'TE' or 'TM'
select.IR.order = 1;        % 1 = TE0/TM0
select.SH.pol   = 'TM';
select.SH.order = 1;

%% Options
opts = struct();
opts.Q_threshold   = 1e4;
opts.pol_threshold = 0.5;
opts.N_modes_initial = 10;
opts.N_modes_step    = 10;
opts.N_modes_max     = 20;
opts.N_modes_margin  = 1;
opts.edge_margin     = 1;
opts.do_validation = true;
opts.validation_use_center = true;
opts.save_result = true;
opts.overwrite = false;
opts.verbose = false;
opts.print_mode_table = false;
opts.eigwhich = '';
% ---- runtime estimation / confirmation ----
opts.runtime_estimate_repeats = 1;
opts.require_run_confirmation = true;
% ---- display mode ----
opts.display_mode = 'silent';   % 'compact', 'verbose', or 'silent'

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
opts.output_dir = fullfile(result_dir,['sweep_' timestamp]);
if ~exist(opts.output_dir,'dir'), mkdir(opts.output_dir); end

%% Runtime pre-estimation before validation / sweep

% Number of geometry cases
n_cases = numel(R_list) * numel(w_list) * numel(t_ridge_list);

% Use one representative geometry for timing.
% You can choose the first point, middle point, or manually set geom_probe.
geom_probe = base_geom;
geom_probe.Radius  = R_list(1);
geom_probe.w_ln    = w_list(1);
geom_probe.t_ridge = t_ridge_list(1);

% Alternative: use middle point as a more representative geometry.
% geom_probe.Radius  = R_list(ceil(numel(R_list)/2));
% geom_probe.w_ln    = w_list(ceil(numel(w_list)/2));
% geom_probe.t_ridge = t_ridge_list(ceil(numel(t_ridge_list)/2));

runtime_est = estimate_sweep_time_upper_bound(model, geom_probe, scan, opts, n_cases);

% Ask user to explicitly confirm before creating output directory and running sweep.
if opts.require_run_confirmation
    cmd = input('Type "run" to start the full sweep and create the output directory: ', 's');

    if ~strcmpi(strtrim(cmd), 'run')
        fprintf('\nSweep cancelled by user. No output directory was created.\n');
        return;
    end
end

% Create output directory only after user confirmation.
if ~exist(opts.output_dir, 'dir')
    mkdir(opts.output_dir);
end

% Save pre-estimation result for record.
save(fullfile(opts.output_dir, 'Runtime_estimate.mat'), 'runtime_est');

%% Run sweep
sweep_timer = tic;
completed_cases = 0;
log_list = struct([]);
case_id = 0;

for iR = 1:numel(R_list)
    for iw = 1:numel(w_list)
        for it = 1:numel(t_ridge_list)
            case_id = case_id + 1;
            geom = base_geom;
            geom.Radius  = R_list(iR);
            geom.w_ln    = w_list(iw);
            geom.t_ridge = t_ridge_list(it);

            fprintf('\n====================================================\n');
            fprintf('Case %d: R=%.2f um, w=%.3f um, t_ridge=%.3f um\n', ...
                case_id, geom.Radius, geom.w_ln, geom.t_ridge);
            fprintf('====================================================\n');

            rec = make_empty_log_record();
            rec.case_id = case_id;
            rec.Radius = geom.Radius; rec.w_ln = geom.w_ln;
            rec.t_ln = geom.t_ln; rec.t_ridge = geom.t_ridge; rec.theta_deg = geom.theta_deg;
            opts_case = opts;
            opts_case.case_id = case_id;
            opts_case.n_cases = n_cases;
            try
                case_timer = tic;

                fprintf('\n====================================================\n');
                fprintf('Case %d/%d | R = %.2f um, w = %.3f um, t_ridge = %.3f um\n', ...
                    case_id, n_cases, geom.Radius, geom.w_ln, geom.t_ridge);
                fprintf('====================================================\n');

                out = run_ring_qpm_case(model, geom, scan, select, opts_case);

                case_time_s = toc(case_timer);
                completed_cases = completed_cases + 1;

                elapsed_s = toc(sweep_timer);
                avg_case_time_s = elapsed_s / completed_cases;
                eta_s = avg_case_time_s * (n_cases - completed_cases);

                fprintf('\nFinished case %d/%d | status = %s\n', ...
                    case_id, n_cases, string(out.status));
                fprintf('  case time = %s\n', format_seconds_local(case_time_s));
                fprintf('  elapsed   = %s\n', format_seconds_local(elapsed_s));
                fprintf('  ETA       = %s\n', format_seconds_local(eta_s));
                rec.status = out.status;
                if isfield(out,'save_path'), rec.save_path = out.save_path; end
                if strcmp(out.status,'success')
                    rec.min_Q_IR_sel = out.min_Q_IR_sel;
                    rec.min_Q_SH_sel = out.min_Q_SH_sel;
                    rec.center_mismatch_GHz = out.Walk.Delta_f0_Hz/1e9;
                    rec.N_modes_search = out.N_modes_search;
                    rec.message = 'ok';
                elseif isfield(out,'validation') && isfield(out.validation,'message')
                    rec.message = out.validation.message;
                end
            catch ME
                case_time_s = toc(case_timer);
                completed_cases = completed_cases + 1;

                elapsed_s = toc(sweep_timer);
                avg_case_time_s = elapsed_s / completed_cases;
                eta_s = avg_case_time_s * (n_cases - completed_cases);

                rec.status = "error";
                rec.message = string(ME.message);
                rec.save_path = "";
                rec.min_Q_IR_sel = NaN;
                rec.min_Q_SH_sel = NaN;
                rec.center_mismatch_GHz = NaN;

                fprintf('\nERROR in case %d/%d:\n%s\n', case_id, n_cases, ME.message);
                fprintf('  case time = %s\n', format_seconds_local(case_time_s));
                fprintf('  elapsed   = %s\n', format_seconds_local(elapsed_s));
                fprintf('  ETA       = %s\n', format_seconds_local(eta_s));
            end

            log_list = append_log_record(log_list,rec);
            save(fullfile(opts.output_dir,'Sweep_log.mat'), ...
                'log_list','R_list','w_list','t_ridge_list','base_geom','scan','select','opts');
        end
    end
end

fprintf('\nSweep finished. Results folder:\n%s\n', opts.output_dir);

function rec = make_empty_log_record()
rec = struct();
rec.case_id = NaN; rec.status = ''; rec.message = ''; rec.save_path = '';
rec.Radius = NaN; rec.w_ln = NaN; rec.t_ln = NaN; rec.t_ridge = NaN; rec.theta_deg = NaN;
rec.min_Q_IR_sel = NaN; rec.min_Q_SH_sel = NaN; rec.center_mismatch_GHz = NaN; rec.N_modes_search = NaN;
end

function log_list = append_log_record(log_list,rec)
if isempty(log_list), log_list = rec; else, log_list(end+1) = rec; end
end

function str = format_seconds_local(t)

if ~isfinite(t)
    str = 'NaN';
    return;
end

if t < 60
    str = sprintf('%.1f s', t);
elseif t < 3600
    str = sprintf('%.1f min', t/60);
else
    h = floor(t/3600);
    m = floor((t - h*3600)/60);
    s = round(t - h*3600 - m*60);
    str = sprintf('%d h %d min %d s', h, m, s);
end

end