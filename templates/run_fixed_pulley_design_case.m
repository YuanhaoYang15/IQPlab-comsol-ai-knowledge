%% RUN_FIXED_PULLEY_DESIGN_CASE
%
% Fixed-geometry pulley-coupler design scan.
%
% This is a design-workflow template, not a validated final device recipe.
% Start from a GUI-validated 2D axisymmetric single-waveguide model and update
% the user-configuration block for the intended geometry, mode family, and
% Qc window.
%
% Workflow:
%   1. Solve isolated ring and bus modes at 1550 nm and 775 nm.
%   2. Estimate pulley Qc(theta) for theta = 0..60 deg.
%   3. Reject the structure unless the 1550-nm ring Qrad exceeds 5e6.
%   4. Find common theta windows with Qc in [1e5, 1e7] at both wavelengths.
%   5. Reject windows narrower than 1 degree.
%   6. Pick one nominal theta per window by minimizing a log-distance score
%      to Qtarget = 1e6, with 1550 nm and 775 nm weighted equally.
%
% The optional wavelength scan is disabled by default because it is much more
% expensive. If enabled, it scans lambda_IR = 1.55 +/- 0.10 um and maps the
% SH wavelength as lambda_SH = lambda_IR/2.

clear; close all; clc;
set(groot, 'defaultFigureVisible', 'off');

%% ===================== 1. User configuration =====================

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);

cfg = struct();
cfg.modelFile = get_env_text('PULLEY_QC_MODEL_FILE', fullfile(repoRoot, ...
    'examples', '2dsym_single_waveguide_coupled_q', ...
    'LN_ridge_2dsym_single_waveguide_example.mph'));
cfg.outputRoot = get_env_text('PULLEY_QC_OUTPUT_ROOT', fullfile(repoRoot, 'local_outputs'));
cfg.saveFigures = get_env_bool('PULLEY_QC_SAVE_FIGURES', true);

% Mode-solver settings.
cfg.N_modes_search = 10;
cfg.mode_Q_select_threshold = 1e4;
cfg.pol_threshold = 0.5;

% Design filters.
cfg.Qrad_min = 5e6;
cfg.QradCheckMinLambdaUm = 1.0;
cfg.Qint_est = 1e6;
cfg.Qc_hard_min = 1e5;
cfg.Qc_hard_max = 1e7;
cfg.Qc_preferred_min = 3e5;
cfg.Qc_preferred_max = 5e6;
cfg.Qtarget = 1e6;
cfg.min_window_width_deg = 1.0;
cfg.strong_coupling_warning_Qc = 3e5;
cfg.wavelengthNeffJumpWarning = 0.02;
cfg.skipCouplerIfQradFails = get_env_bool('PULLEY_QC_SKIP_COUPLER_IF_QRAD_FAILS', true);

% Group-index handling for Qc.
% If true, Qc uses ring ng interpolated from existing ring_qpm
% post-processed results. No new dispersion simulation is launched here.
% The default is off so the template can run without a prior ring_qpm result.
cfg.useRealNgForQc = get_env_bool('PULLEY_QC_USE_REAL_NG', false);
cfg.requireRealNgForQc = get_env_bool('PULLEY_QC_REQUIRE_REAL_NG', false);
cfg.ngSearchRoot = get_env_text('PULLEY_QC_NG_SEARCH_ROOT', fullfile(repoRoot, 'local_outputs'));
cfg.ngMatchTolerance = 1e-6;
cfg.ngInterpMethod = 'pchip';

% Center-angle scan.
cfg.center_wavelengths_um = [1.55, 0.775];
cfg.theta_scan_deg = 0:0.05:60;

% Optional wavelength scan around the chosen theta values.
cfg.runWavelengthScan = get_env_bool('PULLEY_QC_RUN_WAVELENGTH_SCAN', false);
cfg.lambda0_IR_um = 1.55;
cfg.lambda_span_IR_um = 0.20;
cfg.lambda_step_IR_um = get_env_number('PULLEY_QC_LAMBDA_STEP_UM', 0.005);
cfg.wavelengthThetaMode = get_env_text('PULLEY_QC_WAVELENGTH_THETA_MODE', 'start_nominal_end');

% Geometry in um.
geom = struct();
geom.Radius = get_env_number('PULLEY_QC_RADIUS_UM', 50.0);
geom.w_ring = get_env_number('PULLEY_QC_WRING_UM', 1.0);
geom.w_bus = get_env_number('PULLEY_QC_WBUS_UM', 0.6);
geom.w_gap = get_env_number('PULLEY_QC_GAP_UM', 0.5);
geom.t_ln = 0.6;
geom.t_ridge = 0.4;
geom.theta_deg = 60;
geom.w_pml = 1.5;
geom.t_sio2 = 2.0;
geom.t_air = 2.0;

geomTag = sprintf('R%s_w%s_gap%s_bus%s', ...
    num_tag(geom.Radius), num_tag(geom.w_ring), ...
    num_tag(geom.w_gap), num_tag(geom.w_bus));
cfg.runName = ['fixed_pulley_', geomTag, '_', ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))];
cfg.outputDir = fullfile(cfg.outputRoot, cfg.runName);
cfg.figureDir = fullfile(cfg.outputDir, 'figures');

cfg.rawMatFile = fullfile(cfg.outputDir, 'fixed_pulley_raw.mat');
cfg.summaryCsvFile = fullfile(cfg.outputDir, 'fixed_pulley_summary.csv');
cfg.windowCsvFile = fullfile(cfg.outputDir, 'fixed_pulley_windows.csv');
cfg.configMatFile = fullfile(cfg.outputDir, 'fixed_pulley_config.mat');

if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end
if ~exist(cfg.figureDir, 'dir'), mkdir(cfg.figureDir); end

R_bus_center = geom.Radius + geom.w_ring/2 + geom.w_gap + geom.w_bus/2;

select = struct();
select.ring.pol = 'TM';
select.ring.order = 1;
select.bus.pol = 'TM';
select.bus.order = 1;

save(cfg.configMatFile, 'cfg', 'geom', 'select', 'R_bus_center');

%% ===================== 2. Run center wavelength theta scan =====================

fprintf('Loading COMSOL model:\n  %s\n', cfg.modelFile);
if exist(cfg.modelFile, 'file') ~= 2
    error('FixedPulley:ModelNotFound', 'Model file not found:\n  %s', cfg.modelFile);
end

model = mphload(cfg.modelFile, 'Tag_FixedPulleyDesign');
fprintf('Model loaded.\n');

fprintf('\nRunning center-wavelength pulley scan...\n');
if cfg.skipCouplerIfQradFails
    qradPrecheck = run_ring_qrad_precheck(model, cfg.center_wavelengths_um, ...
        geom, select, cfg);
else
    qradPrecheck = struct('pass', true);
end

if qradPrecheck.pass
    centerResult = run_pulley_for_wavelengths(model, cfg.center_wavelengths_um, ...
        cfg.theta_scan_deg, geom, R_bus_center, select, cfg);
else
    fprintf('\nQrad precheck failed. Skipping bus solves and pulley Qc calculation.\n');
    centerResult = make_qrad_failed_center_result(qradPrecheck, cfg);
end

fprintf('\nFinding acceptable theta windows...\n');
if qradPrecheck.pass
    [windowTable, windowStruct] = find_theta_windows(centerResult, cfg);
else
    windowStruct = struct([]);
    windowTable = table();
end

if isempty(windowStruct)
    fprintf('No common theta window passed all filters.\n');
else
    disp(windowTable);
end

summaryTable = make_summary_table(centerResult, cfg);
writetable(summaryTable, cfg.summaryCsvFile);
writetable(windowTable, cfg.windowCsvFile);

if cfg.saveFigures
    plot_center_qc(centerResult, windowStruct, cfg, geom);
end

%% ===================== 3. Optional wavelength scans =====================

wavelengthScan = struct([]);
if cfg.runWavelengthScan && ~isempty(windowStruct)
    fprintf('\nRunning optional wavelength scans at start/nominal/end of each window...\n');
    lambda_IR = (cfg.lambda0_IR_um - cfg.lambda_span_IR_um/2) : ...
        cfg.lambda_step_IR_um : ...
        (cfg.lambda0_IR_um + cfg.lambda_span_IR_um/2);
    lambda_SH = lambda_IR ./ 2;

    theta_list = collect_window_theta_points(windowStruct, cfg.wavelengthThetaMode);

    for kk = 1:numel(theta_list)
        theta_curr = theta_list(kk);
        fprintf('\nWavelength scan %d/%d at theta = %.4f deg\n', ...
            kk, numel(theta_list), theta_curr);

        wlResult = run_pulley_for_wavelengths(model, [lambda_IR(:), lambda_SH(:)], ...
            theta_curr, geom, R_bus_center, select, cfg);
        wavelengthScan(kk).theta_deg = theta_curr;
        wavelengthScan(kk).result = wlResult;
        wavelengthScan(kk).warning = make_wavelength_scan_warning(wlResult, cfg);
    end
else
    fprintf('\nOptional wavelength scan is disabled. Set cfg.runWavelengthScan = true to enable it.\n');
end

%% ===================== 4. Save raw results =====================

save(cfg.rawMatFile, 'cfg', 'geom', 'select', 'R_bus_center', ...
    'centerResult', 'summaryTable', 'windowTable', 'windowStruct', ...
    'wavelengthScan', '-v7.3');

fprintf('\nSaved raw result:\n  %s\n', cfg.rawMatFile);
fprintf('Saved summary CSV:\n  %s\n', cfg.summaryCsvFile);
fprintf('Saved window CSV:\n  %s\n', cfg.windowCsvFile);
if cfg.saveFigures
    fprintf('Saved figure folder:\n  %s\n', cfg.figureDir);
else
    fprintf('Figure export disabled for this run.\n');
end

%% ========================================================================
% Local functions
% ========================================================================

function result = run_pulley_for_wavelengths(model, wavelength_input_um, theta_deg_vec, geom, R_bus_center, select, cfg)
% wavelength_input_um:
%   Vector [lambda1 lambda2 ...] for center scans, or Nx2 matrix
%   [lambda_IR, lambda_SH] for optional paired scans.

if isvector(wavelength_input_um)
    lambda_um = wavelength_input_um(:);
    band_name = strings(numel(lambda_um), 1);
    for ii = 1:numel(lambda_um)
        band_name(ii) = sprintf('lambda_%04dnm', round(lambda_um(ii)*1000));
    end
else
    lambda_um = wavelength_input_um(:);
    band_name = strings(numel(lambda_um), 1);
    n_pair = size(wavelength_input_um, 1);
    for ii = 1:n_pair
        band_name(ii) = sprintf('IR_%04dnm', round(wavelength_input_um(ii,1)*1000));
        band_name(ii+n_pair) = sprintf('SH_%04dnm', round(wavelength_input_um(ii,2)*1000));
    end
end

theta_deg_vec = theta_deg_vec(:).';
N_waves = numel(lambda_um);
N_theta = numel(theta_deg_vec);

res_Qc = nan(N_waves, N_theta);
res_Kappa_sq = nan(N_waves, N_theta);
res_Gamma = nan(N_waves, 1);
res_DeltaBeta = nan(N_waves, 1);
res_neff_ring = nan(N_waves, 1);
res_neff_bus = nan(N_waves, 1);
res_ng_ring = nan(N_waves, 1);
res_ng_source = strings(N_waves, 1);
res_Q_ring = nan(N_waves, 1);
res_Q_bus = nan(N_waves, 1);
res_solnum_ring = nan(N_waves, 1);
res_solnum_bus = nan(N_waves, 1);
res_TE_ring = nan(N_waves, 1);
res_TM_ring = nan(N_waves, 1);
res_TE_bus = nan(N_waves, 1);
res_TM_bus = nan(N_waves, 1);

for ii = 1:N_waves
    fprintf('\n>>> Lambda = %.6f um (%d/%d)\n', lambda_um(ii), ii, N_waves);
    one = compute_one_wavelength(model, lambda_um(ii), theta_deg_vec, ...
        geom, R_bus_center, select, cfg);

    res_Qc(ii, :) = one.Qc(:).';
    res_Kappa_sq(ii, :) = one.Kappa_sq(:).';
    res_Gamma(ii) = one.Gamma;
    res_DeltaBeta(ii) = one.DeltaBeta;
    res_neff_ring(ii) = one.ring.neff;
    res_neff_bus(ii) = one.bus.neff;
    res_ng_ring(ii) = one.ng_ring;
    res_ng_source(ii) = string(one.ng_source);
    res_Q_ring(ii) = one.ring.Q;
    res_Q_bus(ii) = one.bus.Q;
    res_solnum_ring(ii) = one.ring.solnum;
    res_solnum_bus(ii) = one.bus.solnum;
    res_TE_ring(ii) = one.ring.TEfrac;
    res_TM_ring(ii) = one.ring.TMfrac;
    res_TE_bus(ii) = one.bus.TEfrac;
    res_TM_bus(ii) = one.bus.TMfrac;
end

result = struct();
result.lambda_um = lambda_um;
result.band_name = band_name;
result.theta_deg = theta_deg_vec;
result.Qc = res_Qc;
result.Kappa_sq = res_Kappa_sq;
result.Gamma = res_Gamma;
result.DeltaBeta = res_DeltaBeta;
result.neff_ring = res_neff_ring;
result.neff_bus = res_neff_bus;
result.ng_ring = res_ng_ring;
result.ng_source = res_ng_source;
result.Q_ring = res_Q_ring;
result.Q_bus = res_Q_bus;
result.solnum_ring = res_solnum_ring;
result.solnum_bus = res_solnum_bus;
result.TE_ring = res_TE_ring;
result.TM_ring = res_TM_ring;
result.TE_bus = res_TE_bus;
result.TM_bus = res_TM_bus;
result.extraction = cfg.Qint_est ./ (cfg.Qint_est + res_Qc);
result.extinction_depth = 4 .* res_Qc .* cfg.Qint_est ./ ((res_Qc + cfg.Qint_est).^2);
end

function precheck = run_ring_qrad_precheck(model, lambda_um, geom, select, cfg)
lambda_um = lambda_um(:);
lambda_um = lambda_um(lambda_um > cfg.QradCheckMinLambdaUm);
if isempty(lambda_um)
    lambda_um = max(cfg.center_wavelengths_um(:));
end
N_waves = numel(lambda_um);

precheck = struct();
precheck.pass = true;
precheck.lambda_um = lambda_um;
precheck.neff_ring = nan(N_waves, 1);
precheck.ng_ring = nan(N_waves, 1);
precheck.ng_source = strings(N_waves, 1);
precheck.Q_ring = nan(N_waves, 1);
precheck.TE_ring = nan(N_waves, 1);
precheck.TM_ring = nan(N_waves, 1);
precheck.solnum_ring = nan(N_waves, 1);
precheck.message = strings(N_waves, 1);

fprintf('\nRunning ring-Qrad precheck for long-wavelength ring mode only...\n');
for ii = 1:N_waves
    lam = lambda_um(ii);
    fprintf('  Qrad precheck lambda = %.6f um\n', lam);
    n_idx = get_material_index_MgLN(lam);
    update_single_waveguide_model(model, geom, lam, n_idx, ...
        geom.Radius, geom.w_ring, geom.Radius);
    run_solver_only(model, cfg.N_modes_search);

    ring_mode = select_bound_mode_by_pol(model, cfg.N_modes_search, ...
        select.ring.pol, select.ring.order, cfg.mode_Q_select_threshold, ...
        cfg.pol_threshold, geom.Radius, 'Ring precheck');

    precheck.neff_ring(ii) = ring_mode.neff;
    precheck.Q_ring(ii) = ring_mode.Q;
    precheck.TE_ring(ii) = ring_mode.TEfrac;
    precheck.TM_ring(ii) = ring_mode.TMfrac;
    precheck.solnum_ring(ii) = ring_mode.solnum;

    try
        [precheck.ng_ring(ii), precheck.ng_source(ii)] = ...
            get_ring_ng_for_qc(geom, lam, real(ring_mode.neff), cfg);
    catch ME
        if cfg.requireRealNgForQc
            rethrow(ME);
        end
        precheck.ng_ring(ii) = real(ring_mode.neff);
        precheck.ng_source(ii) = "neff_fallback_after_ng_error";
    end

    if ring_mode.Q < cfg.Qrad_min
        precheck.pass = false;
        precheck.message(ii) = "Qrad_fail";
    else
        precheck.message(ii) = "Qrad_pass";
    end

    fprintf('    ring solnum=%d, neff=%.7f, Qrad=%.3e, TM=%.3f, ng=%.6f\n', ...
        ring_mode.solnum, real(ring_mode.neff), ring_mode.Q, ...
        ring_mode.TMfrac, precheck.ng_ring(ii));
end
end

function result = make_qrad_failed_center_result(precheck, cfg)
lambda_all = cfg.center_wavelengths_um(:);
N_waves = numel(lambda_all);
N_theta = numel(cfg.theta_scan_deg);

result = struct();
result.lambda_um = lambda_all;
result.band_name = strings(N_waves, 1);
for ii = 1:N_waves
    result.band_name(ii) = sprintf('lambda_%04dnm', round(lambda_all(ii)*1000));
end
result.theta_deg = cfg.theta_scan_deg(:).';
result.Qc = nan(N_waves, N_theta);
result.Kappa_sq = nan(N_waves, N_theta);
result.Gamma = nan(N_waves, 1);
result.DeltaBeta = nan(N_waves, 1);

result.neff_ring = nan(N_waves, 1);
result.ng_ring = nan(N_waves, 1);
result.ng_source = strings(N_waves, 1);
result.Q_ring = nan(N_waves, 1);
result.solnum_ring = nan(N_waves, 1);
result.TE_ring = nan(N_waves, 1);
result.TM_ring = nan(N_waves, 1);

for ii = 1:numel(precheck.lambda_um)
    [~, idx] = min(abs(lambda_all - precheck.lambda_um(ii)));
    result.neff_ring(idx) = precheck.neff_ring(ii);
    result.ng_ring(idx) = precheck.ng_ring(ii);
    result.ng_source(idx) = precheck.ng_source(ii);
    result.Q_ring(idx) = precheck.Q_ring(ii);
    result.solnum_ring(idx) = precheck.solnum_ring(ii);
    result.TE_ring(idx) = precheck.TE_ring(ii);
    result.TM_ring(idx) = precheck.TM_ring(ii);
end

result.neff_bus = nan(N_waves, 1);
result.Q_bus = nan(N_waves, 1);
result.solnum_bus = nan(N_waves, 1);
result.TE_bus = nan(N_waves, 1);
result.TM_bus = nan(N_waves, 1);
result.extraction = nan(N_waves, N_theta);
result.extinction_depth = nan(N_waves, N_theta);
result.qradPrecheck = precheck;
end

function one = compute_one_wavelength(model, lambda_um, theta_deg_vec, geom, R_bus_center, select, cfg)

n_idx = get_material_index_MgLN(lambda_um);
n_clad = 1;

[Coords_R_m, dA_R, N_grid_R, Coords_B_m, dA_B, N_grid_B, RR_B, ZZ_B] = ...
    build_integration_grids(geom, R_bus_center);

fprintf('    Material: no = %.5f, ne = %.5f, n_sio2 = %.5f\n', ...
    n_idx.no, n_idx.ne, n_idx.n_sio2);

% Ring solve.
fprintf('    Solving ring %s%d mode...\n', upper(select.ring.pol), select.ring.order-1);
update_single_waveguide_model(model, geom, lambda_um, n_idx, ...
    geom.Radius, geom.w_ring, geom.Radius);
run_solver_only(model, cfg.N_modes_search);
ring_mode = select_bound_mode_by_pol(model, cfg.N_modes_search, ...
    select.ring.pol, select.ring.order, cfg.mode_Q_select_threshold, ...
    cfg.pol_threshold, geom.Radius, 'Ring');

extract_R = @(expr) fix_dim(mphinterp(model, expr, ...
    'coord', Coords_R_m, 'solnum', ring_mode.solnum, ...
    'Complexout', 'on'), N_grid_R);
extract_R_on_B = @(expr) fix_dim(mphinterp(model, expr, ...
    'coord', Coords_B_m, 'solnum', ring_mode.solnum, ...
    'Complexout', 'on'), N_grid_B);

ring_fields.Ez = extract_R('ewfd.Ez');
ring_fields.Er = extract_R('ewfd.Er');
ring_fields.Hr = extract_R('ewfd.Hr');
ring_fields.Hz = extract_R('ewfd.Hz');

ring_on_bus.Er = extract_R_on_B('ewfd.Er');
ring_on_bus.Ez = extract_R_on_B('ewfd.Ez');
ring_on_bus.Ephi = extract_R_on_B('ewfd.Ephi');

fprintf('      Ring: solnum=%d, neff=%.7f, Qrad=%.3e, TE=%.3f, TM=%.3f\n', ...
    ring_mode.solnum, real(ring_mode.neff), ring_mode.Q, ...
    ring_mode.TEfrac, ring_mode.TMfrac);

% Bus solve.
fprintf('    Solving bus %s%d mode...\n', upper(select.bus.pol), select.bus.order-1);
update_single_waveguide_model(model, geom, lambda_um, n_idx, ...
    R_bus_center, geom.w_bus, geom.Radius);
run_solver_only(model, cfg.N_modes_search);
bus_mode = select_bound_mode_by_pol(model, cfg.N_modes_search, ...
    select.bus.pol, select.bus.order, cfg.mode_Q_select_threshold, ...
    cfg.pol_threshold, R_bus_center, 'Bus');

extract_B = @(expr) fix_dim(mphinterp(model, expr, ...
    'coord', Coords_B_m, 'solnum', bus_mode.solnum, ...
    'Complexout', 'on'), N_grid_B);

bus_fields.Ez = extract_B('ewfd.Ez');
bus_fields.Er = extract_B('ewfd.Er');
bus_fields.Ephi = extract_B('ewfd.Ephi');
bus_fields.Hr = extract_B('ewfd.Hr');
bus_fields.Hz = extract_B('ewfd.Hz');

fprintf('      Bus:  solnum=%d, neff=%.7f, Q=%.3e, TE=%.3f, TM=%.3f\n', ...
    bus_mode.solnum, real(bus_mode.neff), bus_mode.Q, ...
    bus_mode.TEfrac, bus_mode.TMfrac);

% Coupling calculation.
Sphi_R = 0.5 * real(ring_fields.Ez .* conj(ring_fields.Hr) ...
    - ring_fields.Er .* conj(ring_fields.Hz));
P_Ring = sum(Sphi_R, 'omitnan') * dA_R;

Sphi_B = 0.5 * real(bus_fields.Ez .* conj(bus_fields.Hr) ...
    - bus_fields.Er .* conj(bus_fields.Hz));
P_Bus = sum(Sphi_B, 'omitnan') * dA_B;

Norm_Factor = 1 / sqrt(abs(P_Ring * P_Bus));

W_bottom = geom.w_bus + 2 * geom.t_ridge * cot(geom.theta_deg * pi/180);
H_from_slab = ZZ_B - (geom.t_ln - geom.t_ridge);
Half_Width = (W_bottom/2) - H_from_slab * cot(geom.theta_deg * pi/180);
Mask_Z = (ZZ_B > (geom.t_ln - geom.t_ridge)) & (ZZ_B <= geom.t_ln);
Mask_R = abs(RR_B - R_bus_center) <= Half_Width;
Mask_Bus_1D = (Mask_Z & Mask_R);
Mask_Bus_1D = Mask_Bus_1D(:);

epsilon0 = 8.854187817e-12;
c0 = 299792458;
omega = 2*pi*c0 / (lambda_um * 1e-6);

d_eps_r = (n_idx.no^2 - n_clad^2) * epsilon0;
d_eps_z = (n_idx.ne^2 - n_clad^2) * epsilon0;
d_eps_phi = (n_idx.no^2 - n_clad^2) * epsilon0;

vec = @(x) x(:);
Term_r = d_eps_r * conj(vec(ring_on_bus.Er)) .* vec(bus_fields.Er);
Term_z = d_eps_z * conj(vec(ring_on_bus.Ez)) .* vec(bus_fields.Ez);
Term_phi = d_eps_phi * conj(vec(ring_on_bus.Ephi)) .* vec(bus_fields.Ephi);
Integrand = Term_r + Term_z + Term_phi;

Integral_Value = sum(Integrand(Mask_Bus_1D), 'omitnan') * dA_B;
Gamma = (omega / 4) * abs(Integral_Value) * Norm_Factor;

k0 = 2*pi/(lambda_um * 1e-6);
neff_ring = real(ring_mode.neff);
neff_bus = real(bus_mode.neff);
[ng_ring, ng_source] = get_ring_ng_for_qc(geom, lambda_um, neff_ring, cfg);
DeltaBeta = neff_ring * k0 * (geom.Radius / R_bus_center) - neff_bus * k0;

Lc_vec = R_bus_center * 1e-6 * (theta_deg_vec * pi/180);
S_eff = sqrt((DeltaBeta/2)^2 + Gamma^2);
Phi_vec = Lc_vec * S_eff;
sinc_val = ones(size(Phi_vec));
idx_nz = abs(Phi_vec) > 1e-12;
sinc_val(idx_nz) = sin(Phi_vec(idx_nz)) ./ Phi_vec(idx_nz);
Kappa_sq = abs(Gamma .* Lc_vec .* sinc_val).^2;
Qc = (2*pi*ng_ring*(2*pi*geom.Radius*1e-6)) ./ ...
    ((lambda_um*1e-6) .* Kappa_sq);

fprintf('      Coupling: Gamma=%.4e rad/m, DeltaBeta=%.4e rad/m\n', ...
    Gamma, DeltaBeta);
fprintf('      Qc group index: ng_ring=%.6f (%s)\n', ng_ring, ng_source);

one = struct();
one.Qc = Qc;
one.Kappa_sq = Kappa_sq;
one.Gamma = Gamma;
one.DeltaBeta = DeltaBeta;
one.ng_ring = ng_ring;
one.ng_source = ng_source;
one.ring = ring_mode;
one.bus = bus_mode;
end

function [Coords_R_m, dA_R, N_grid_R, Coords_B_m, dA_B, N_grid_B, RR_B, ZZ_B] = build_integration_grids(geom, R_bus_center)
d_grid_int = 0.02; % um

r_vec_R = (geom.Radius - geom.w_ring/2 - 2) : d_grid_int : ...
    (geom.Radius + geom.w_ring/2 + 2);
z_vec_R = (geom.t_ln - geom.t_ridge - 1.0) : d_grid_int : ...
    (geom.t_ln + 1.0);
[RR_R, ZZ_R] = meshgrid(r_vec_R, z_vec_R);
Coords_R_m = [RR_R(:)' * 1e-6; ZZ_R(:)' * 1e-6];
dA_R = (d_grid_int * 1e-6)^2;
N_grid_R = size(Coords_R_m, 2);

r_vec_B = (R_bus_center - geom.w_bus/2 - 2) : d_grid_int : ...
    (R_bus_center + geom.w_bus/2 + 2);
z_vec_B = z_vec_R;
[RR_B, ZZ_B] = meshgrid(r_vec_B, z_vec_B);
Coords_B_m = [RR_B(:)' * 1e-6; ZZ_B(:)' * 1e-6];
dA_B = dA_R;
N_grid_B = size(Coords_B_m, 2);
end

function [windowTable, windows] = find_theta_windows(result, cfg)
theta = result.theta_deg(:);
Qc1550 = result.Qc(1, :).';
Qc775 = result.Qc(2, :).';

qrad_idx = result.lambda_um(:) > cfg.QradCheckMinLambdaUm;
qrad_pass = any(qrad_idx) && all(result.Q_ring(qrad_idx) >= cfg.Qrad_min);
in_hard = qrad_pass ...
    & Qc1550 >= cfg.Qc_hard_min & Qc1550 <= cfg.Qc_hard_max ...
    & Qc775 >= cfg.Qc_hard_min & Qc775 <= cfg.Qc_hard_max;

segments = logical_segments(in_hard);
windows = struct([]);

for ii = 1:size(segments, 1)
    idx = segments(ii, 1):segments(ii, 2);
    theta_start = theta(idx(1));
    theta_end = theta(idx(end));
    theta_width = theta_end - theta_start;

    if theta_width < cfg.min_window_width_deg
        continue;
    end

    score = abs(log10(Qc1550(idx) ./ cfg.Qtarget)) + ...
        abs(log10(Qc775(idx) ./ cfg.Qtarget));
    [best_score, best_local] = min(score);
    best_idx = idx(best_local);

    w = struct();
    w.window_id = numel(windows) + 1;
    w.theta_start_deg = theta_start;
    w.theta_end_deg = theta_end;
    w.theta_width_deg = theta_width;
    w.theta_nominal_deg = theta(best_idx);
    w.score_nominal = best_score;
    w.Qc_1550_nominal = Qc1550(best_idx);
    w.Qc_775_nominal = Qc775(best_idx);
    w.extraction_1550_nominal = cfg.Qint_est / (cfg.Qint_est + Qc1550(best_idx));
    w.extraction_775_nominal = cfg.Qint_est / (cfg.Qint_est + Qc775(best_idx));
    w.extinction_1550_nominal = 4 * Qc1550(best_idx) * cfg.Qint_est / ...
        ((Qc1550(best_idx) + cfg.Qint_est)^2);
    w.extinction_775_nominal = 4 * Qc775(best_idx) * cfg.Qint_est / ...
        ((Qc775(best_idx) + cfg.Qint_est)^2);
    w.in_preferred_1550 = Qc1550(best_idx) >= cfg.Qc_preferred_min ...
        && Qc1550(best_idx) <= cfg.Qc_preferred_max;
    w.in_preferred_775 = Qc775(best_idx) >= cfg.Qc_preferred_min ...
        && Qc775(best_idx) <= cfg.Qc_preferred_max;
    w.strong_coupling_warning = Qc1550(best_idx) < cfg.strong_coupling_warning_Qc ...
        || Qc775(best_idx) < cfg.strong_coupling_warning_Qc;

    windows = append_struct(windows, w);
end

if isempty(windows)
    windowTable = table();
else
    windowTable = struct2table(windows);
end
end

function segments = logical_segments(mask)
mask = mask(:);
dm = diff([false; mask; false]);
starts = find(dm == 1);
ends = find(dm == -1) - 1;
segments = [starts, ends];
end

function theta_list = collect_window_theta_points(windows, mode)
theta_list = [];
for ii = 1:numel(windows)
    switch lower(string(mode))
        case "nominal_only"
            theta_list = [theta_list, windows(ii).theta_nominal_deg]; %#ok<AGROW>
        case "start_nominal_end"
            theta_list = [theta_list, ...
                windows(ii).theta_start_deg, ...
                windows(ii).theta_nominal_deg, ...
                windows(ii).theta_end_deg]; %#ok<AGROW>
        otherwise
            error('Unknown wavelengthThetaMode: %s', mode);
    end
end
theta_list = unique(theta_list, 'stable');
end

function T = make_summary_table(result, cfg)
qrad_pass = result.Q_ring(:) >= cfg.Qrad_min;
T = table(result.lambda_um(:), result.neff_ring(:), result.neff_bus(:), ...
    result.ng_ring(:), result.ng_source(:), ...
    result.Q_ring(:), qrad_pass(:), result.Q_bus(:), ...
    result.TE_ring(:), result.TM_ring(:), result.TE_bus(:), result.TM_bus(:), ...
    result.Gamma(:), result.DeltaBeta(:), ...
    'VariableNames', {'lambda_um', 'neff_ring', 'neff_bus', ...
    'ng_ring_for_Qc', 'ng_source', ...
    'Qrad_ring', 'Qrad_pass', 'Q_bus', ...
    'TE_ring', 'TM_ring', 'TE_bus', 'TM_bus', ...
    'Gamma_rad_per_m', 'DeltaBeta_rad_per_m'});
end

function warningInfo = make_wavelength_scan_warning(result, cfg)
warningInfo = struct();
warningInfo.pol_threshold = cfg.pol_threshold;
warningInfo.neff_jump_threshold = cfg.wavelengthNeffJumpWarning;
warningInfo.IR = make_band_warning(result, result.lambda_um > 1.0, cfg);
warningInfo.SH = make_band_warning(result, result.lambda_um <= 1.0, cfg);
warningInfo.has_warning = warningInfo.IR.has_warning || warningInfo.SH.has_warning;
end

function bandWarn = make_band_warning(result, idx, cfg)
bandWarn = struct();
bandWarn.has_data = any(idx);
bandWarn.has_warning = false;
bandWarn.solnum_ring_changed = false;
bandWarn.solnum_bus_changed = false;
bandWarn.max_neff_ring_step = NaN;
bandWarn.max_neff_bus_step = NaN;
bandWarn.min_TM_ring = NaN;
bandWarn.min_TM_bus = NaN;
bandWarn.message = "";

if ~bandWarn.has_data
    bandWarn.message = "no_data";
    return;
end

[lambda_sort, order] = sort(result.lambda_um(idx));
ring_sol = result.solnum_ring(idx);
bus_sol = result.solnum_bus(idx);
ring_neff = real(result.neff_ring(idx));
bus_neff = real(result.neff_bus(idx));
ring_TM = result.TM_ring(idx);
bus_TM = result.TM_bus(idx);

ring_sol = ring_sol(order);
bus_sol = bus_sol(order);
ring_neff = ring_neff(order);
bus_neff = bus_neff(order);
ring_TM = ring_TM(order);
bus_TM = bus_TM(order);

bandWarn.lambda_min_um = min(lambda_sort);
bandWarn.lambda_max_um = max(lambda_sort);
bandWarn.solnum_ring_changed = numel(unique(ring_sol(isfinite(ring_sol)))) > 1;
bandWarn.solnum_bus_changed = numel(unique(bus_sol(isfinite(bus_sol)))) > 1;
bandWarn.max_neff_ring_step = max(abs(diff(ring_neff)), [], 'omitnan');
bandWarn.max_neff_bus_step = max(abs(diff(bus_neff)), [], 'omitnan');
bandWarn.min_TM_ring = min(ring_TM, [], 'omitnan');
bandWarn.min_TM_bus = min(bus_TM, [], 'omitnan');

neff_jump = bandWarn.max_neff_ring_step > cfg.wavelengthNeffJumpWarning ...
    || bandWarn.max_neff_bus_step > cfg.wavelengthNeffJumpWarning;
pol_near_threshold = bandWarn.min_TM_ring < cfg.pol_threshold + 0.05 ...
    || bandWarn.min_TM_bus < cfg.pol_threshold + 0.05;

bandWarn.has_warning = bandWarn.solnum_ring_changed ...
    || bandWarn.solnum_bus_changed ...
    || neff_jump ...
    || pol_near_threshold;

messages = strings(0, 1);
if bandWarn.solnum_ring_changed, messages(end+1) = "ring_solnum_changed"; end %#ok<AGROW>
if bandWarn.solnum_bus_changed, messages(end+1) = "bus_solnum_changed"; end %#ok<AGROW>
if neff_jump, messages(end+1) = "large_neff_step"; end %#ok<AGROW>
if pol_near_threshold, messages(end+1) = "TM_fraction_near_threshold"; end %#ok<AGROW>
if isempty(messages), messages = "ok"; end
bandWarn.message = strjoin(messages, ",");
end

function plot_center_qc(result, windows, cfg, geom)
fig = figure('Name', 'Fixed Geometry Pulley Qc Scan', ...
    'Color', 'w', 'Position', [120, 100, 720, 480], ...
    'Visible', 'off');

semilogy(result.theta_deg, result.Qc(1, :), '-', 'LineWidth', 1.8, ...
    'DisplayName', '1550 nm');
hold on;
semilogy(result.theta_deg, result.Qc(2, :), '-', 'LineWidth', 1.8, ...
    'DisplayName', '775 nm');
yline(cfg.Qc_hard_min, '--k', 'HandleVisibility', 'off');
yline(cfg.Qc_hard_max, '--k', 'HandleVisibility', 'off');
yline(cfg.Qtarget, ':k', 'HandleVisibility', 'off');

for ii = 1:numel(windows)
    xline(windows(ii).theta_start_deg, ':', 'Color', [0.2 0.6 0.2], ...
        'HandleVisibility', 'off');
    xline(windows(ii).theta_end_deg, ':', 'Color', [0.2 0.6 0.2], ...
        'HandleVisibility', 'off');
    xline(windows(ii).theta_nominal_deg, '-', 'Color', [0.1 0.4 0.1], ...
        'LineWidth', 1.0, 'HandleVisibility', 'off');
end

grid on; box on;
xlabel('Pulley angle theta (degree)');
ylabel('Estimated Q_c');
ylim([1e4 1e8]);
title(sprintf('R=%.0f um, w_{ring}=%.2f um, gap=%.2f um, w_{bus}=%.2f um', ...
    geom.Radius, geom.w_ring, geom.w_gap, geom.w_bus));
legend('Location', 'best');

exportgraphics(fig, fullfile(cfg.figureDir, 'center_Qc_vs_theta.png'), ...
    'Resolution', 200);
close(fig);
end

function update_single_waveguide_model(model, g, lambda_um, n, w_center_um, w_active_um, Radius_um)
to_um = @(x) [num2str(x, 16), '[um]'];
to_deg = @(x) [num2str(x, 16), '[deg]'];

model.param.set('Radius', to_um(Radius_um));
model.param.set('w_center', to_um(w_center_um));
model.param.set('w_ln', to_um(w_active_um));
model.param.set('t_ln', to_um(g.t_ln));
model.param.set('t_ridge', to_um(g.t_ridge));
model.param.set('w_pml', to_um(g.w_pml));
model.param.set('theta', to_deg(g.theta_deg));

w_sub_val = max(10 + w_active_um, abs(w_center_um - g.Radius) + w_active_um + 8);
model.param.set('w_sub', to_um(w_sub_val));

if isfield(g, 't_sio2'), model.param.set('t_sio2', to_um(g.t_sio2)); end
if isfield(g, 't_air'), model.param.set('t_air', to_um(g.t_air)); end

model.param.set('wavelength', to_um(lambda_um));
model.param.set('ne', num2str(n.ne, 16));
model.param.set('no', num2str(n.no, 16));
model.param.set('n_sio2', num2str(n.n_sio2, 16));
model.param.set('nref', num2str(max([n.ne, n.no]), 16));
end

function run_solver_only(model, num_modes)
model.study('std1').feature('mode').set('neigs', num2str(num_modes));
model.study('std1').run;
end

function mode_info = select_bound_mode_by_pol(model, N_modes, pol_target, order_target, Q_th, pol_th, r_center_um, tag_str)
sol_list = 1:N_modes;
neff_raw = mphglobal(model, 'ewfd.neff', 'dataset', 'dset1', 'solnum', sol_list);
TE_raw = mphglobal(model, 'TEfrac', 'dataset', 'dset1', 'solnum', sol_list);
TM_raw = mphglobal(model, 'TMfrac', 'dataset', 'dset1', 'solnum', sol_list);
rAverage_raw = read_rAverage_from_model(model, N_modes);

neff_raw = neff_raw(:);
TE_raw = real(TE_raw(:));
TM_raw = real(TM_raw(:));
rAverage_raw = rAverage_raw(:);

neff_raw_vec = nan(N_modes, 1);
TE_vec = nan(N_modes, 1);
TM_vec = nan(N_modes, 1);
rAvg_vec = nan(N_modes, 1);

N_found = min(numel(neff_raw), N_modes);
neff_raw_vec(1:N_found) = neff_raw(1:N_found);
TE_vec(1:min(numel(TE_raw), N_modes)) = TE_raw(1:min(numel(TE_raw), N_modes));
TM_vec(1:min(numel(TM_raw), N_modes)) = TM_raw(1:min(numel(TM_raw), N_modes));

if numel(rAverage_raw) == 1
    rAvg_vec(:) = rAverage_raw;
else
    rAvg_vec(1:min(numel(rAverage_raw), N_modes)) = rAverage_raw(1:min(numel(rAverage_raw), N_modes));
end

r_center_m = r_center_um * 1e-6;
scale_vec = rAvg_vec ./ r_center_m;
neff_actual_vec = neff_raw_vec .* scale_vec;
Q_vec = real(neff_actual_vec) ./ (2 * abs(imag(neff_actual_vec)));
Q_vec(~isfinite(Q_vec)) = 1e99;

isBound = Q_vec > Q_th & isfinite(Q_vec) & real(neff_actual_vec) > 1;
switch upper(pol_target)
    case 'TE'
        isPol = TE_vec >= pol_th & TE_vec >= TM_vec;
    case 'TM'
        isPol = TM_vec >= pol_th & TM_vec > TE_vec;
    otherwise
        error('pol_target must be TE or TM.');
end

print_mode_table(tag_str, pol_target, order_target, ...
    neff_raw_vec, neff_actual_vec, Q_vec, TE_vec, TM_vec, ...
    rAvg_vec, r_center_m, isBound, isPol);

idx_candidates = find(isBound & isPol);
if isempty(idx_candidates)
    error('No %s-like bound mode found for %s.', upper(pol_target), tag_str);
end

[~, idx_sort] = sort(real(neff_actual_vec(idx_candidates)), 'descend');
idx_candidates = idx_candidates(idx_sort);
if order_target > numel(idx_candidates)
    error('Requested %s%d for %s, but only %d candidates were found.', ...
        upper(pol_target), order_target-1, tag_str, numel(idx_candidates));
end

idx = idx_candidates(order_target);
mode_info.solnum = idx;
mode_info.neff = neff_actual_vec(idx);
mode_info.neff_raw = neff_raw_vec(idx);
mode_info.Q = Q_vec(idx);
mode_info.TEfrac = TE_vec(idx);
mode_info.TMfrac = TM_vec(idx);
mode_info.rAverage = rAvg_vec(idx);
mode_info.r_center = r_center_m;
mode_info.scale = scale_vec(idx);
end

function rAverage_vec = read_rAverage_from_model(model, N_modes)
sol_list = 1:N_modes;
candidate_exprs = {'ewfd.rAverage', 'ewfd.raverage', 'rAverage', 'raverage'};

for ii = 1:numel(candidate_exprs)
    try
        tmp = mphglobal(model, candidate_exprs{ii}, ...
            'dataset', 'dset1', 'solnum', sol_list, 'unit', 'm');
        if ~isempty(tmp)
            rAverage_vec = tmp(:);
            return;
        end
    catch
    end
end

try
    tmp = mphglobal(model, 'Radius', 'dataset', 'dset1', 'unit', 'm');
    rAverage_vec = tmp(:);
    fprintf('WARNING: rAverage variable was not found. Fallback to parameter Radius.\n');
catch
    error('Could not read rAverage or Radius from COMSOL.');
end
end

function field = fix_dim(field_in, n_grid)
if size(field_in, 1) ~= n_grid && size(field_in, 2) == n_grid
    field = field_in.';
else
    field = field_in;
end
end

function print_mode_table(tag_str, pol_target, order_target, ...
    neff_raw_vec, neff_actual_vec, Q_vec, TE_vec, TM_vec, ...
    rAvg_vec, r_center_m, isBound, isPol)
fprintf('\nSolved mode table [%s], target = %s%d\n', ...
    tag_str, upper(pol_target), order_target-1);
fprintf('  r_center = %.4f um\n', r_center_m*1e6);
fprintf('  -------------------------------------------------------------------------------\n');
fprintf('  solnum   Re(neff_actual)  Re(neff_raw)        Q        TEfrac   TMfrac   rAvg(um)  Bound  Pol\n');
fprintf('  -------------------------------------------------------------------------------\n');
for kk = 1:numel(neff_actual_vec)
    if isfinite(real(neff_actual_vec(kk)))
        fprintf('  %4d      %12.6f   %12.6f   %9.3e   %7.3f  %7.3f   %8.3f    %d      %d\n', ...
            kk, real(neff_actual_vec(kk)), real(neff_raw_vec(kk)), ...
            Q_vec(kk), TE_vec(kk), TM_vec(kk), rAvg_vec(kk)*1e6, ...
            isBound(kk), isPol(kk));
    end
end
fprintf('  -------------------------------------------------------------------------------\n\n');
end

function [ng_ring, source_desc] = get_ring_ng_for_qc(geom, lambda_um, neff_fallback, cfg)
if ~isfield(cfg, 'useRealNgForQc') || ~cfg.useRealNgForQc
    ng_ring = neff_fallback;
    source_desc = "neff_fallback_disabled";
    return;
end

files = dir(fullfile(cfg.ngSearchRoot, '**', 'processed_result.mat'));
tol = cfg.ngMatchTolerance;

for ii = 1:numel(files)
    f = fullfile(files(ii).folder, files(ii).name);
    try
        S = load(f);
        if ~isfield(S, 'processed')
            continue;
        end
        P = S.processed;
        if ~isfield(P, 'meta')
            continue;
        end
        meta = P.meta;
        if ~is_matching_ring_qpm_meta(meta, geom, tol)
            continue;
        end

        if lambda_um > 1.0
            band = P.IR;
            band_name = "IR";
        else
            band = P.SH;
            band_name = "SH";
        end

        if ~isfield(band, 'lambda') || ~isfield(band, 'ng')
            continue;
        end

        lambda_vec = band.lambda(:);
        ng_vec = band.ng(:);
        valid = isfinite(lambda_vec) & isfinite(ng_vec);
        lambda_vec = lambda_vec(valid);
        ng_vec = ng_vec(valid);

        if numel(lambda_vec) < 2
            continue;
        end

        if lambda_um < min(lambda_vec) - 1e-9 || lambda_um > max(lambda_vec) + 1e-9
            continue;
        end

        ng_ring = interp1(lambda_vec, ng_vec, lambda_um, cfg.ngInterpMethod);
        source_desc = sprintf('%s:%s', band_name, f);
        return;

    catch
        % Try the next candidate file.
    end
end

if isfield(cfg, 'requireRealNgForQc') && cfg.requireRealNgForQc
    error(['Real ring ng was requested for Qc, but no matching ring_qpm ', ...
        'processed_result.mat was found for R=%.6g um, w=%.6g um, ', ...
        'tLN=%.6g um, tRidge=%.6g um, lambda=%.6g um.'], ...
        geom.Radius, geom.w_ring, geom.t_ln, geom.t_ridge, lambda_um);
end

ng_ring = neff_fallback;
source_desc = "neff_fallback_missing_ng";
end

function tf = is_matching_ring_qpm_meta(meta, geom, tol)
required = {'Radius', 'w_ln', 't_ln', 't_ridge', 'theta_deg', ...
    'IR_pol', 'IR_order', 'SH_pol', 'SH_order'};
for ii = 1:numel(required)
    if ~isfield(meta, required{ii})
        tf = false;
        return;
    end
end

tf = abs(meta.Radius - geom.Radius) <= tol ...
    && abs(meta.w_ln - geom.w_ring) <= tol ...
    && abs(meta.t_ln - geom.t_ln) <= tol ...
    && abs(meta.t_ridge - geom.t_ridge) <= tol ...
    && abs(meta.theta_deg - geom.theta_deg) <= tol ...
    && strcmpi(string(meta.IR_pol), "TM") ...
    && strcmpi(string(meta.SH_pol), "TM") ...
    && double(meta.IR_order) == 1 ...
    && double(meta.SH_order) == 1;
end

function out = append_struct(in, rec)
if isempty(in)
    out = rec;
else
    out = in;
    out(end+1) = rec;
end
end

function value = get_env_number(name, default_value)
raw = getenv(name);
if isempty(raw)
    value = default_value;
    return;
end
value = str2double(raw);
if ~isfinite(value)
    error('Invalid numeric environment override %s=%s', name, raw);
end
end

function value = get_env_bool(name, default_value)
raw = strtrim(lower(getenv(name)));
if isempty(raw)
    value = default_value;
    return;
end
switch raw
    case {'1', 'true', 'yes', 'on'}
        value = true;
    case {'0', 'false', 'no', 'off'}
        value = false;
    otherwise
        error('Invalid boolean environment override %s=%s', name, raw);
end
end

function value = get_env_text(name, default_value)
raw = getenv(name);
if isempty(raw)
    value = default_value;
else
    value = raw;
end
end

function tag = num_tag(x)
tag = sprintf('%.4g', x);
tag = strrep(tag, '.', 'p');
tag = strrep(tag, '-', 'm');
end
