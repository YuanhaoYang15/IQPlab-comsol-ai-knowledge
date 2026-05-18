function est = estimate_sweep_time_upper_bound(model, geom_probe, scan, opts, n_cases)
%ESTIMATE_SWEEP_TIME_UPPER_BOUND
% Estimate an upper bound of total sweep time before running validation/full scan.
%
% The estimate is based on timing one representative geometry using
% opts.N_modes_max at the IR center wavelength and SH center wavelength.
%
% It does NOT save files and does NOT create output directories.

    fprintf('\n========== Runtime pre-estimation ==========\n');

    if ~isfield(opts, 'runtime_estimate_repeats')
        opts.runtime_estimate_repeats = 1;
    end

    if ~isfield(opts, 'validation_use_center')
        opts.validation_use_center = true;
    end

    Nmax = opts.N_modes_max;

    lambda_IR_probe = scan.lambda0_IR;
    lambda_SH_probe = scan.lambda0_IR / 2;

    fprintf('Probe geometry:\n');
    fprintf('  R       = %.4f um\n', geom_probe.Radius);
    fprintf('  w_ln    = %.4f um\n', geom_probe.w_ln);
    fprintf('  t_ridge = %.4f um\n', geom_probe.t_ridge);
    fprintf('Probe N_modes = opts.N_modes_max = %d\n', Nmax);

    % ---- time IR solve ----
    t_IR = nan(opts.runtime_estimate_repeats, 1);
    for kk = 1:opts.runtime_estimate_repeats
        fprintf('Timing IR solve %.6f um, repeat %d/%d...\n', ...
            lambda_IR_probe, kk, opts.runtime_estimate_repeats);

        n_idx = get_material_index_MgLN(lambda_IR_probe);
        update_ring_model_params_for_timing(model, geom_probe, lambda_IR_probe, n_idx);

        tic;
        run_solver_only_for_timing(model, Nmax);
        t_IR(kk) = toc;

        fprintf('  IR solve time = %.2f s\n', t_IR(kk));
    end

    % ---- time SH solve ----
    t_SH = nan(opts.runtime_estimate_repeats, 1);
    for kk = 1:opts.runtime_estimate_repeats
        fprintf('Timing SH solve %.6f um, repeat %d/%d...\n', ...
            lambda_SH_probe, kk, opts.runtime_estimate_repeats);

        n_idx = get_material_index_MgLN(lambda_SH_probe);
        update_ring_model_params_for_timing(model, geom_probe, lambda_SH_probe, n_idx);

        tic;
        run_solver_only_for_timing(model, Nmax);
        t_SH(kk) = toc;

        fprintf('  SH solve time = %.2f s\n', t_SH(kk));
    end

    t_IR_med = median(t_IR, 'omitnan');
    t_SH_med = median(t_SH, 'omitnan');

    % Use the slower of IR/SH as conservative one-solve time.
    t_one_solve_upper = max(t_IR_med, t_SH_med);

    % ---- count solves ----
    lambda_IR = (scan.lambda0_IR - scan.span_IR/2) : scan.step_IR : ...
                (scan.lambda0_IR + scan.span_IR/2);

    n_lambda_IR = numel(lambda_IR);
    n_full_solves_per_case = 2 * n_lambda_IR;  % IR band + SH band

    if opts.validation_use_center
        n_validation_points = 6;  % IR start/center/end + SH start/center/end
    else
        n_validation_points = 4;  % IR start/end + SH start/end
    end

    N_trial_list = opts.N_modes_initial : opts.N_modes_step : opts.N_modes_max;
    n_validation_trials_max = numel(N_trial_list);

    n_validation_solves_upper_per_case = n_validation_points * n_validation_trials_max;

    % Conservative upper bound:
    % Each geometry may try all validation trials, then run full scan.
    n_solves_upper_per_case = n_validation_solves_upper_per_case + n_full_solves_per_case;

    total_solves_upper = n_cases * n_solves_upper_per_case;
    total_time_upper_s = total_solves_upper * t_one_solve_upper;

    % A more realistic typical estimate:
    % validation passes at first trial.
    n_solves_typical_per_case = n_validation_points + n_full_solves_per_case;
    total_solves_typical = n_cases * n_solves_typical_per_case;
    total_time_typical_s = total_solves_typical * t_one_solve_upper;

    est = struct();

    est.N_modes_max = Nmax;
    est.t_IR_s = t_IR;
    est.t_SH_s = t_SH;
    est.t_IR_median_s = t_IR_med;
    est.t_SH_median_s = t_SH_med;
    est.t_one_solve_upper_s = t_one_solve_upper;

    est.n_cases = n_cases;
    est.n_lambda_IR = n_lambda_IR;
    est.n_full_solves_per_case = n_full_solves_per_case;
    est.n_validation_points = n_validation_points;
    est.n_validation_trials_max = n_validation_trials_max;
    est.n_validation_solves_upper_per_case = n_validation_solves_upper_per_case;

    est.n_solves_upper_per_case = n_solves_upper_per_case;
    est.total_solves_upper = total_solves_upper;
    est.total_time_upper_s = total_time_upper_s;

    est.n_solves_typical_per_case = n_solves_typical_per_case;
    est.total_solves_typical = total_solves_typical;
    est.total_time_typical_s = total_time_typical_s;

    fprintf('\n========== Runtime estimate summary ==========\n');
    fprintf('Median IR solve time at N_modes_max = %.2f s\n', t_IR_med);
    fprintf('Median SH solve time at N_modes_max = %.2f s\n', t_SH_med);
    fprintf('Conservative one-solve time used     = %.2f s\n', t_one_solve_upper);
    fprintf('\n');
    fprintf('Number of geometry cases             = %d\n', n_cases);
    fprintf('Number of IR wavelength points        = %d\n', n_lambda_IR);
    fprintf('Full scan solves per case             = %d\n', n_full_solves_per_case);
    fprintf('Validation points per trial           = %d\n', n_validation_points);
    fprintf('Max validation trials per case         = %d\n', n_validation_trials_max);
    fprintf('Upper-bound solves per case            = %d\n', n_solves_upper_per_case);
    fprintf('\n');
    fprintf('Typical estimate: %s\n', format_seconds(total_time_typical_s));
    fprintf('Upper-bound estimate: %s\n', format_seconds(total_time_upper_s));
    fprintf('==============================================\n\n');
end


function update_ring_model_params_for_timing(model, g, lambda_um, n)
% Minimal duplicate of update_ring_model_params, used only for pre-timing.

    to_um  = @(x) [num2str(x, 16), '[um]'];
    to_deg = @(x) [num2str(x, 16), '[deg]'];

    safe_set_param_for_timing(model, 'Radius',   to_um(g.Radius));
    safe_set_param_for_timing(model, 'w_center', to_um(g.Radius));
    safe_set_param_for_timing(model, 'w_ln',     to_um(g.w_ln));
    safe_set_param_for_timing(model, 't_ln',     to_um(g.t_ln));
    safe_set_param_for_timing(model, 't_ridge',  to_um(g.t_ridge));
    safe_set_param_for_timing(model, 'w_pml',    to_um(g.w_pml));
    safe_set_param_for_timing(model, 'theta',    to_deg(g.theta_deg));

    w_sub_val = g.w_ln + 8;
    safe_set_param_for_timing(model, 'w_sub', to_um(w_sub_val));

    if isfield(g, 't_sio2')
        safe_set_param_for_timing(model, 't_sio2', to_um(g.t_sio2));
    end

    if isfield(g, 't_air')
        safe_set_param_for_timing(model, 't_air', to_um(g.t_air));
    end

    safe_set_param_for_timing(model, 'wavelength', to_um(lambda_um));

    safe_set_param_for_timing(model, 'no',     num2str(n.no, 16));
    safe_set_param_for_timing(model, 'ne',     num2str(n.ne, 16));
    safe_set_param_for_timing(model, 'n_sio2', num2str(n.n_sio2, 16));

    nref_val = max([n.no, n.ne]);
    safe_set_param_for_timing(model, 'nref', num2str(nref_val, 16));

    safe_set_param_for_timing(model, 'Ravg', to_um(g.Radius));
    safe_set_param_for_timing(model, 'rAverage', to_um(g.Radius));
end


function safe_set_param_for_timing(model, name, value)
    try
        model.param.set(name, value);
    catch
    end
end


function run_solver_only_for_timing(model, num_modes)
    model.study('std1').feature('mode').set('neigs', num2str(num_modes));
    model.study('std1').run;
end


function str = format_seconds(t)
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