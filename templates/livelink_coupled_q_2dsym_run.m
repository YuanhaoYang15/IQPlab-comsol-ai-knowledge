%% LIVELINK_COUPLED_Q_2DSYM_RUN
%
% Module 06 run script.
%
% Estimate pulley coupled Q from a 2D axisymmetric single-waveguide
% COMSOL mode model. The same model is solved twice at each wavelength:
% once for the ring-centered waveguide and once for the bus-centered
% waveguide. The coupling strength is then estimated from a perturbative
% overlap integral over the bus ridge region.
%
% Required example model:
%   examples/2dsym_single_waveguide_coupled_q/
%       LN_ridge_2dsym_single_waveguide_example.mph
%
% This script intentionally saves raw numerical results before plotting so
% post-processing can be repeated without rerunning COMSOL.

clear; close all; clc;

%% 1. Global settings

% ---- grid ----
d_grid_int  = 0.02;   % um
d_grid_plot = 0.02;   % um

% ---- number of modes searched ----
N_modes_search = 10;

% ---- geometry, um ----
geom.Radius    = 30;
geom.w_ring    = 1;
geom.w_bus     = 0.5;
geom.w_gap     = 0.5;
geom.theta_deg = 60;
geom.t_ln      = 0.6;
geom.t_ridge   = 0.4;

geom.w_pml     = 1.5;
geom.t_sio2    = 2.0;
geom.t_air     = 2.0;

% ---- mode selection ----
select.ring.pol   = 'TM';   % 'TE' or 'TM'
select.ring.order = 1;      % 1 = highest-neff bound mode in this polarization

select.bus.pol    = 'TM';
select.bus.order  = 1;

Q_threshold   = 1e4;
pol_threshold = 0.5;        % 0.5 = dominant; 0.8 = strict TE/TM-like

% ---- wavelength scan ----
target_wavelengths = [0.775 1.55];
N_waves = numel(target_wavelengths);

% ---- pulley coupling length / angle scan ----
theta_start = 0;
theta_end   = 60;
N_angles    = 1000;
theta_scan_vec = linspace(theta_start, theta_end, N_angles);

% ---- bus center ----
R_bus_center = geom.Radius + geom.w_ring/2 + geom.w_gap + geom.w_bus/2;

% ---- output ----
scriptDir = fileparts(mfilename('fullpath'));
repoRoot  = fileparts(scriptDir);

cfg = struct();
cfg.modelFile = fullfile(repoRoot, 'examples', ...
    '2dsym_single_waveguide_coupled_q', ...
    'LN_ridge_2dsym_single_waveguide_example.mph');
cfg.outputRoot = fullfile(repoRoot, 'local_outputs');
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
cfg.runName = ['coupled_q_2dsym_', timestamp];
cfg.outputDir = fullfile(cfg.outputRoot, cfg.runName);
if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

cfg.rawMatFile = fullfile(cfg.outputDir, 'coupled_q_raw.mat');
cfg.configMatFile = fullfile(cfg.outputDir, 'coupled_q_config.mat');
cfg.summaryCsvFile = fullfile(cfg.outputDir, 'coupled_q_summary.csv');
cfg.figureDir = fullfile(cfg.outputDir, 'figures');
if ~exist(cfg.figureDir, 'dir')
    mkdir(cfg.figureDir);
end

cfg.saveModeProfileFigures = true;

%% 2. Load single COMSOL model

save(cfg.configMatFile, 'cfg', 'geom', 'select', ...
    'target_wavelengths', 'theta_scan_vec', ...
    'Q_threshold', 'pol_threshold', 'N_modes_search');

fprintf('Loading single COMSOL model...\n');
fprintf('  %s\n', cfg.modelFile);
if exist(cfg.modelFile, 'file') ~= 2
    error('CoupledQ:ModelFileNotFound', ...
        ['Example COMSOL model file not found:\n  %s\n\n', ...
         'Please copy the cleaned 2Dsym example .mph file to this path ', ...
         'or update cfg.modelFile.'], cfg.modelFile);
end
model = mphload(cfg.modelFile, 'Tag_SinglePulley');
fprintf('Model loaded.\n');
    
%% 3. Build integration and plotting grids

fprintf('Generating interpolation grids...\n');

% Ring-region grid
r_vec_R = (geom.Radius - geom.w_ring/2 - 2) : d_grid_int : ...
    (geom.Radius + geom.w_ring/2 + 2);

z_vec_R = (geom.t_ln - geom.t_ridge - 1.0) : d_grid_int : ...
    (geom.t_ln + 1.0);

[RR_R, ZZ_R] = meshgrid(r_vec_R, z_vec_R);
Coords_R_m = [RR_R(:)' * 1e-6; ZZ_R(:)' * 1e-6];
dA_R = (d_grid_int * 1e-6)^2;
N_grid_R = size(Coords_R_m, 2);

% Bus-region grid
r_vec_B = (R_bus_center - geom.w_bus/2 - 2) : d_grid_int : ...
    (R_bus_center + geom.w_bus/2 + 2);

z_vec_B = z_vec_R;

[RR_B, ZZ_B] = meshgrid(r_vec_B, z_vec_B);
Coords_B_m = [RR_B(:)' * 1e-6; ZZ_B(:)' * 1e-6];
dA_B = (d_grid_int * 1e-6)^2;
N_grid_B = size(Coords_B_m, 2);

% Plot grid covering both ring and bus
r_plot_min = geom.Radius - geom.w_ring/2 - 2.5;
r_plot_max = R_bus_center + geom.w_bus/2 + 2.5;

r_vec_Plot = r_plot_min : d_grid_plot : r_plot_max;
z_vec_Plot = (geom.t_ln - geom.t_ridge - 1.2) : d_grid_plot : ...
    (geom.t_ln + 1.2);

[RR_Plot, ZZ_Plot] = meshgrid(r_vec_Plot, z_vec_Plot);
Coords_Plot_m = [RR_Plot(:)' * 1e-6; ZZ_Plot(:)' * 1e-6];
N_grid_Plot = size(Coords_Plot_m, 2);

%% 4. Preallocate results

res_Qc        = zeros(N_waves, N_angles);
res_Kappa_sq  = zeros(N_waves, N_angles);
res_Gamma     = zeros(N_waves, 1);
res_DeltaBeta = zeros(N_waves, 1);

res_neff_ring = zeros(N_waves, 1);
res_neff_bus  = zeros(N_waves, 1);
res_Q_ring    = zeros(N_waves, 1);
res_Q_bus     = zeros(N_waves, 1);
res_TE_ring   = zeros(N_waves, 1);
res_TM_ring   = zeros(N_waves, 1);
res_TE_bus    = zeros(N_waves, 1);
res_TM_bus    = zeros(N_waves, 1);

%% 5. Main loop

fprintf('================================================\n');
fprintf('Start single-model pulley coupling calculation\n');
fprintf('================================================\n');

for ii = 1:N_waves

    lambda_curr = target_wavelengths(ii);

    fprintf('\n>>> Lambda = %.4f um\n', lambda_curr);

    n_idx = get_material_index_MgLN(lambda_curr);
    n_clad = 1;

    fprintf('    Material: no = %.4f, ne = %.4f, n_sio2 = %.4f\n', ...
        n_idx.no, n_idx.ne, n_idx.n_sio2);

    %% 5.1 Solve ring mode using the single model

    fprintf('    Solving Ring %s%d mode...\n', ...
        upper(select.ring.pol), select.ring.order);

    update_single_waveguide_model(model, geom, lambda_curr, n_idx, ...
        geom.Radius, geom.w_ring, geom.Radius);

    run_solver_only(model, N_modes_search);

    ring_mode = select_bound_mode_by_pol(model, N_modes_search, ...
        select.ring.pol, select.ring.order, ...
        Q_threshold, pol_threshold, ...
        geom.Radius, 'Ring');

    fprintf('      Ring: solnum = %d, neff_actual = %.6f, neff_raw = %.6f, Q = %.3e, TEfrac = %.3f, TMfrac = %.3f, rAverage = %.4f um\n', ...
        ring_mode.solnum, real(ring_mode.neff), real(ring_mode.neff_raw), ...
        ring_mode.Q, ring_mode.TEfrac, ring_mode.TMfrac, ...
        ring_mode.rAverage*1e6);

    % Extract ring fields immediately before overwriting the model solution
    extract_R = @(expr) fix_dim(mphinterp(model, expr, ...
        'coord', Coords_R_m, ...
        'solnum', ring_mode.solnum, ...
        'Complexout', 'on'), N_grid_R);

    info_ring.neff   = real(ring_mode.neff);
    info_ring.Q      = ring_mode.Q;
    info_ring.solnum = ring_mode.solnum;
    info_ring.TEfrac = ring_mode.TEfrac;
    info_ring.TMfrac = ring_mode.TMfrac;

    info_ring.Ez   = extract_R('ewfd.Ez');
    info_ring.Er   = extract_R('ewfd.Er');
    info_ring.Ephi = extract_R('ewfd.Ephi');
    info_ring.Hr   = extract_R('ewfd.Hr');
    info_ring.Hz   = extract_R('ewfd.Hz');

    % Ring field sampled on the future bus region, needed for coupling integral
    E_Ring_on_Bus.Er = fix_dim(mphinterp(model, 'ewfd.Er', ...
        'coord', Coords_B_m, ...
        'solnum', ring_mode.solnum, ...
        'Complexout', 'on'), N_grid_B);

    E_Ring_on_Bus.Ez = fix_dim(mphinterp(model, 'ewfd.Ez', ...
        'coord', Coords_B_m, ...
        'solnum', ring_mode.solnum, ...
        'Complexout', 'on'), N_grid_B);

    E_Ring_on_Bus.Ephi = fix_dim(mphinterp(model, 'ewfd.Ephi', ...
        'coord', Coords_B_m, ...
        'solnum', ring_mode.solnum, ...
        'Complexout', 'on'), N_grid_B);

    % Plot data for ring, extracted before bus solve
    Ez_Ring_Plot = abs(fix_dim(mphinterp(model, 'ewfd.Ez', ...
        'coord', Coords_Plot_m, ...
        'solnum', ring_mode.solnum, ...
        'Complexout', 'on'), N_grid_Plot));
    Er_Ring_Plot = abs(fix_dim(mphinterp(model, 'ewfd.Er', ...
        'coord', Coords_Plot_m, ...
        'solnum', ring_mode.solnum, ...
        'Complexout', 'on'), N_grid_Plot));
    normE_Ring_Plot = abs(fix_dim(mphinterp(model, 'ewfd.normE', ...
        'coord', Coords_Plot_m, ...
        'solnum', ring_mode.solnum, ...
        'Complexout', 'on'), N_grid_Plot));

    %% 5.2 Solve bus mode using the same model

    fprintf('    Solving Bus %s%d mode...\n', ...
        upper(select.bus.pol), select.bus.order);

    update_single_waveguide_model(model, geom, lambda_curr, n_idx, ...
        R_bus_center, geom.w_bus, geom.Radius);

    run_solver_only(model, N_modes_search);

    bus_mode = select_bound_mode_by_pol(model, N_modes_search, ...
        select.bus.pol, select.bus.order, ...
        Q_threshold, pol_threshold, ...
        R_bus_center, 'Bus');

    fprintf('      Bus:  solnum = %d, neff_actual = %.6f, neff_raw = %.6f, Q = %.3e, TEfrac = %.3f, TMfrac = %.3f, rAverage = %.4f um\n', ...
        bus_mode.solnum, real(bus_mode.neff), real(bus_mode.neff_raw), ...
        bus_mode.Q, bus_mode.TEfrac, bus_mode.TMfrac, ...
        bus_mode.rAverage*1e6);

    extract_B = @(expr) fix_dim(mphinterp(model, expr, ...
        'coord', Coords_B_m, ...
        'solnum', bus_mode.solnum, ...
        'Complexout', 'on'), N_grid_B);

    info_bus.neff   = real(bus_mode.neff);
    info_bus.Q      = bus_mode.Q;
    info_bus.solnum = bus_mode.solnum;
    info_bus.TEfrac = bus_mode.TEfrac;
    info_bus.TMfrac = bus_mode.TMfrac;

    info_bus.Ez   = extract_B('ewfd.Ez');
    info_bus.Er   = extract_B('ewfd.Er');
    info_bus.Ephi = extract_B('ewfd.Ephi');
    info_bus.Hr   = extract_B('ewfd.Hr');
    info_bus.Hz   = extract_B('ewfd.Hz');

    Ez_Bus_Plot = abs(fix_dim(mphinterp(model, 'ewfd.Ez', ...
        'coord', Coords_Plot_m, ...
        'solnum', bus_mode.solnum, ...
        'Complexout', 'on'), N_grid_Plot));
    Er_Bus_Plot = abs(fix_dim(mphinterp(model, 'ewfd.Er', ...
        'coord', Coords_Plot_m, ...
        'solnum', bus_mode.solnum, ...
        'Complexout', 'on'), N_grid_Plot));
    normE_Bus_Plot = abs(fix_dim(mphinterp(model, 'ewfd.normE', ...
        'coord', Coords_Plot_m, ...
        'solnum', bus_mode.solnum, ...
        'Complexout', 'on'), N_grid_Plot));

    %% 5.3 Coupling calculation

    Sphi_R = 0.5 * real(info_ring.Ez .* conj(info_ring.Hr) ...
        - info_ring.Er .* conj(info_ring.Hz));

    P_Ring = sum(Sphi_R, 'omitnan') * dA_R;

    Sphi_B = 0.5 * real(info_bus.Ez .* conj(info_bus.Hr) ...
        - info_bus.Er .* conj(info_bus.Hz));

    P_Bus = sum(Sphi_B, 'omitnan') * dA_B;

    Norm_Factor = 1 / sqrt(abs(P_Ring * P_Bus));

    % Bus ridge mask
    W_bottom = geom.w_bus + 2 * geom.t_ridge * cot(geom.theta_deg * pi/180);
    H_from_slab = ZZ_B - (geom.t_ln - geom.t_ridge);
    Half_Width  = (W_bottom/2) - H_from_slab * cot(geom.theta_deg * pi/180);

    Mask_Z = (ZZ_B > (geom.t_ln - geom.t_ridge)) & (ZZ_B <= geom.t_ln);
    Mask_R = abs(RR_B - R_bus_center) <= Half_Width;

    Mask_Bus_1D = (Mask_Z & Mask_R);
    Mask_Bus_1D = Mask_Bus_1D(:);

    % Permittivity perturbation
    epsilon0 = 8.854187817e-12;
    c0 = 299792458;
    omega = 2*pi*c0 / (lambda_curr * 1e-6);

    d_eps_r   = (n_idx.no^2 - n_clad^2) * epsilon0;
    d_eps_z   = (n_idx.ne^2 - n_clad^2) * epsilon0;
    d_eps_phi = (n_idx.no^2 - n_clad^2) * epsilon0;

    vec = @(x) x(:);

    Term_r   = d_eps_r   * conj(vec(E_Ring_on_Bus.Er))   .* vec(info_bus.Er);
    Term_z   = d_eps_z   * conj(vec(E_Ring_on_Bus.Ez))   .* vec(info_bus.Ez);
    Term_phi = d_eps_phi * conj(vec(E_Ring_on_Bus.Ephi)) .* vec(info_bus.Ephi);

    Integrand = Term_r + Term_z + Term_phi;

    Integral_Value = sum(Integrand(Mask_Bus_1D), 'omitnan') * dA_B;
    Gamma = (omega / 4) * abs(Integral_Value) * Norm_Factor;

    % Phase mismatch
    k0 = 2*pi/(lambda_curr * 1e-6);

    neff_ring = info_ring.neff;
    neff_bus  = info_bus.neff;

    Delta_Beta = neff_ring * k0 * (geom.Radius / R_bus_center) ...
        - neff_bus  * k0;

    fprintf('      Coupling: Gamma = %.4e rad/m, DeltaBeta = %.4e rad/m\n', ...
        Gamma, Delta_Beta);

    Lc_vec_curr = R_bus_center * 1e-6 * (theta_scan_vec * pi/180);

    S_eff = sqrt((Delta_Beta/2)^2 + Gamma^2);
    Phi_vec = Lc_vec_curr * S_eff;

    sinc_val = ones(size(Phi_vec));
    idx_nz = abs(Phi_vec) > 1e-12;
    sinc_val(idx_nz) = sin(Phi_vec(idx_nz)) ./ Phi_vec(idx_nz);

    Kappa_sq_vec = abs(Gamma .* Lc_vec_curr .* sinc_val).^2;

    res_Qc(ii, :) = (2*pi*neff_ring*(2*pi*geom.Radius*1e-6)) ./ ...
        ((lambda_curr*1e-6) .* Kappa_sq_vec);

    res_Kappa_sq(ii, :) = Kappa_sq_vec;

    res_Gamma(ii)     = Gamma;
    res_DeltaBeta(ii) = Delta_Beta;

    res_neff_ring(ii) = neff_ring;
    res_neff_bus(ii)  = neff_bus;

    res_Q_ring(ii) = info_ring.Q;
    res_Q_bus(ii)  = info_bus.Q;

    res_TE_ring(ii) = info_ring.TEfrac;
    res_TM_ring(ii) = info_ring.TMfrac;
    res_TE_bus(ii)  = info_bus.TEfrac;
    res_TM_bus(ii)  = info_bus.TMfrac;

    %% 5.4 Plot selected mode profiles

    ring_mode_index = select.ring.order - 1;
    bus_mode_index  = select.bus.order  - 1;

    figure('Name', sprintf('Mode Profile Lambda %.4f um', lambda_curr), ...
        'Color', 'w', 'Position', [100, 50, 1200, 500]);

    % ---------------- Ring row ----------------
    subplot(2, 3, 1);
    plot_field(RR_Plot, ZZ_Plot, Ez_Ring_Plot, ...
        sprintf('Ring %s%d |Ez|', upper(select.ring.pol), ring_mode_index), ...
        neff_ring, geom, R_bus_center, 'Ring');

    subplot(2, 3, 2);
    plot_field(RR_Plot, ZZ_Plot, normE_Ring_Plot, ...
        sprintf('Ring %s%d |E|', upper(select.ring.pol), ring_mode_index), ...
        neff_ring, geom, R_bus_center, 'Ring');

    subplot(2, 3, 3);
    plot_field(RR_Plot, ZZ_Plot, Er_Ring_Plot, ...
        sprintf('Ring %s%d Re(Er)', upper(select.ring.pol), ring_mode_index), ...
        neff_ring, geom, R_bus_center, 'Ring');

    % ---------------- Bus row ----------------
    subplot(2, 3, 4);
    plot_field(RR_Plot, ZZ_Plot, Ez_Bus_Plot, ...
        sprintf('Bus %s%d |Ez|', upper(select.bus.pol), bus_mode_index), ...
        neff_bus, geom, R_bus_center, 'Bus');

    subplot(2, 3, 5);
    plot_field(RR_Plot, ZZ_Plot, normE_Bus_Plot, ...
        sprintf('Bus %s%d |E|', upper(select.bus.pol), bus_mode_index), ...
        neff_bus, geom, R_bus_center, 'Bus');

    subplot(2, 3, 6);
    plot_field(RR_Plot, ZZ_Plot, Er_Bus_Plot, ...
        sprintf('Bus %s%d Re(Er)', upper(select.bus.pol), bus_mode_index), ...
        neff_bus, geom, R_bus_center, 'Bus');

    drawnow;
    if cfg.saveModeProfileFigures
        figName = sprintf('mode_profiles_lambda_%04dnm.png', round(lambda_curr*1000));
        exportgraphics(gcf, fullfile(cfg.figureDir, figName), 'Resolution', 200);
    end
end

%% 6. Save

modeSummaryTable = make_mode_summary_table(target_wavelengths, ...
    res_neff_ring, res_neff_bus, res_Q_ring, res_Q_bus, ...
    res_TE_ring, res_TM_ring, res_TE_bus, res_TM_bus, ...
    res_Gamma, res_DeltaBeta);
writetable(modeSummaryTable, cfg.summaryCsvFile);

save(cfg.rawMatFile, ...
    'geom', 'select', 'target_wavelengths', 'theta_scan_vec', ...
    'Q_threshold', 'pol_threshold', ...
    'res_Qc', 'res_Kappa_sq', 'res_Gamma', 'res_DeltaBeta', ...
    'res_neff_ring', 'res_neff_bus', ...
    'res_Q_ring', 'res_Q_bus', ...
    'res_TE_ring', 'res_TM_ring', ...
    'res_TE_bus', 'res_TM_bus', 'modeSummaryTable');

fprintf('\nResults saved to %s\n', cfg.rawMatFile);
fprintf('Summary saved to %s\n', cfg.summaryCsvFile);

%% 7. Plot Qc

figure('Name', 'Coupled Q Scan', 'Color', 'w', 'Position', [150, 100, 650, 450]);
colors = lines(N_waves);

for ii = 1:N_waves
    semilogy(theta_scan_vec, res_Qc(ii, :), '-', ...
        'LineWidth', 2, ...
        'Color', colors(ii, :), ...
        'DisplayName', sprintf('\\lambda = %.0f nm', target_wavelengths(ii)*1000));
    hold on;
end

grid on;
box on;
xlabel('\theta (degree)');
ylabel('Q_c');
ylim([1e5 1e7])

title(sprintf('R = %.0f \\mum, w_{ring} = %.2f \\mum, w_{bus} = %.2f \\mum, gap = %.2f \\mum', ...
    geom.Radius, geom.w_ring, geom.w_bus, geom.w_gap));

legend('Location', 'best');
exportgraphics(gcf, fullfile(cfg.figureDir, 'coupled_q_scan.png'), 'Resolution', 200);

%% ========================================================================
% Local functions
% ========================================================================

function update_single_waveguide_model(model, g, lambda_um, n, w_center_um, w_active_um, Radius_um)
% Update the single-waveguide COMSOL model.
%
% w_center_um:
%   active waveguide center position.
%
% w_active_um:
%   active waveguide top width.
%
% Radius_um:
%   reference ring radius parameter in the model.
%
% Important:
%   If your COMSOL mode analysis uses Radius as rAverage, then Radius_um
%   controls the neff normalization. For the cleanest treatment, consider
%   creating a separate COMSOL parameter Ravg and using it as the mode
%   analysis reference radius.

to_um  = @(x) [num2str(x, 16), '[um]'];
to_deg = @(x) [num2str(x, 16), '[deg]'];

model.param.set('Radius',   to_um(Radius_um));
model.param.set('w_center', to_um(w_center_um));
model.param.set('w_ln',     to_um(w_active_um));

model.param.set('t_ln',     to_um(g.t_ln));
model.param.set('t_ridge',  to_um(g.t_ridge));
model.param.set('w_pml',    to_um(g.w_pml));
model.param.set('theta',    to_deg(g.theta_deg));

% Make sure the computational window is wide enough to include
% both the ring-centered and bus-centered sampling regions.
w_sub_val = max(10 + w_active_um, ...
    abs(w_center_um - g.Radius) + w_active_um + 8);

model.param.set('w_sub', to_um(w_sub_val));

if isfield(g, 't_sio2')
    model.param.set('t_sio2', to_um(g.t_sio2));
end

if isfield(g, 't_air')
    model.param.set('t_air', to_um(g.t_air));
end

model.param.set('wavelength', to_um(lambda_um));

model.param.set('ne', num2str(n.ne, 16));
model.param.set('no', num2str(n.no, 16));
model.param.set('n_sio2', num2str(n.n_sio2, 16));


nref_val = max([n.ne, n.no]);
model.param.set('nref', num2str(nref_val, 16));
end

function run_solver_only(model, num_modes)
model.study('std1').feature('mode').set('neigs', num2str(num_modes));
model.study('std1').run;
end

function mode_info = select_bound_mode_by_pol(model, N_modes, pol_target, order_target, Q_th, pol_th, r_center_um, tag_str)
% Select the order_target-th bound mode of a given polarization.
%
% Important:
%   COMSOL raw neff in 2D axisymmetric mode analysis can be tied to rAverage.
%   The actual local neff at waveguide center r_center is corrected as
%
%       neff_actual = neff_raw * rAverage / r_center
%
% Inputs:
%   r_center_um:
%       actual waveguide center radius in um
%       Ring: geom.Radius
%       Bus:  R_bus_center
%
%   tag_str:
%       string used only for command-line printing, e.g. 'Ring' or 'Bus'

if nargin < 8
    tag_str = '';
end

sol_list = 1:N_modes;

% --- read raw COMSOL neff ---
neff_raw = mphglobal(model, 'ewfd.neff', ...
    'dataset', 'dset1', ...
    'solnum', sol_list);

% --- read TE/TM fractions defined in the mph model ---
TE_raw = mphglobal(model, 'TEfrac', ...
    'dataset', 'dset1', ...
    'solnum', sol_list);

TM_raw = mphglobal(model, 'TMfrac', ...
    'dataset', 'dset1', ...
    'solnum', sol_list);

% --- read rAverage, in meter ---
rAverage_raw = read_rAverage_from_model(model, N_modes);

neff_raw     = neff_raw(:);
TE_raw       = real(TE_raw(:));
TM_raw       = real(TM_raw(:));
rAverage_raw = rAverage_raw(:);

N_found = numel(neff_raw);

neff_raw_vec    = nan(N_modes, 1);
neff_actual_vec = nan(N_modes, 1);
TE_vec          = nan(N_modes, 1);
TM_vec          = nan(N_modes, 1);
Q_vec           = nan(N_modes, 1);
rAvg_vec        = nan(N_modes, 1);
scale_vec       = nan(N_modes, 1);

neff_raw_vec(1:N_found) = neff_raw;

N_TE = min(numel(TE_raw), N_modes);
N_TM = min(numel(TM_raw), N_modes);

TE_vec(1:N_TE) = TE_raw(1:N_TE);
TM_vec(1:N_TM) = TM_raw(1:N_TM);

% rAverage may be returned as scalar or mode-dependent vector
if numel(rAverage_raw) == 1
    rAvg_vec(:) = rAverage_raw;
else
    N_RA = min(numel(rAverage_raw), N_modes);
    rAvg_vec(1:N_RA) = rAverage_raw(1:N_RA);
end

% --- radius correction ---
r_center_m = r_center_um * 1e-6;

scale_vec = rAvg_vec ./ r_center_m;
neff_actual_vec = neff_raw_vec .* scale_vec;

% --- Q calculated from corrected neff ---
% Since the correction factor is real, Q is essentially unchanged,
% but using neff_actual keeps all printed/output quantities self-consistent.
Q_tmp = real(neff_actual_vec) ./ (2 * abs(imag(neff_actual_vec)));
Q_tmp(~isfinite(Q_tmp)) = 1e99;
Q_vec = Q_tmp;

% --- bound-mode filter ---
isBound = Q_vec > Q_th & isfinite(Q_vec) & real(neff_actual_vec) > 1;

% --- polarization filter ---
switch upper(pol_target)
    case 'TE'
        isPol = TE_vec >= pol_th & TE_vec >= TM_vec;
    case 'TM'
        isPol = TM_vec >= pol_th & TM_vec > TE_vec;
    otherwise
        error('pol_target must be TE or TM.');
end

% --- always print mode table ---
print_mode_table(tag_str, pol_target, order_target, ...
    neff_raw_vec, neff_actual_vec, Q_vec, TE_vec, TM_vec, ...
    rAvg_vec, r_center_m, isBound, isPol);

idx_candidates = find(isBound & isPol);

if isempty(idx_candidates)
    error('No %s-like bound mode found for %s. Try lowering pol_th or Q_th.', ...
        upper(pol_target), tag_str);
end

% Sort selected polarization modes by corrected actual neff
[~, idx_sort] = sort(real(neff_actual_vec(idx_candidates)), 'descend');
idx_candidates = idx_candidates(idx_sort);

if order_target > numel(idx_candidates)
    error('Requested %s%d for %s, but only %d %s-like bound modes were found.', ...
        upper(pol_target), order_target-1, tag_str, ...
        numel(idx_candidates), upper(pol_target));
end

idx = idx_candidates(order_target);

mode_info.solnum    = idx;
mode_info.neff      = neff_actual_vec(idx);   % corrected actual neff
mode_info.neff_raw  = neff_raw_vec(idx);      % raw COMSOL neff
mode_info.Q         = Q_vec(idx);
mode_info.TEfrac    = TE_vec(idx);
mode_info.TMfrac    = TM_vec(idx);
mode_info.rAverage  = rAvg_vec(idx);
mode_info.r_center  = r_center_m;
mode_info.scale     = scale_vec(idx);
end

function field = fix_dim(field_in, n_grid)
if size(field_in, 1) ~= n_grid && size(field_in, 2) == n_grid
    field = field_in.';
else
    field = field_in;
end
end

function plot_field(X, Y, Data, TitleStr, neff_val, g, R_bus_cen, ActiveTag)
% 1. 【核心修改】将 NaN (无数据点) 替换为 0
% 这样可以确保背景也是有颜色的（通常是深蓝色），而不是白色的空洞
Data(isnan(Data)) = 0;

% 2. 绘图
% 使用 surf 并设置 view(2) 通常比 pcolor 更快且更稳定，效果一致
% 这里保留你原本的 pcolor 逻辑，配合 shading interp
h = pcolor(X, Y, reshape(Data, size(X)));
set(h, 'EdgeColor', 'none'); % 确保不显示网格线

shading interp;       % 插值平滑，填满网格
axis equal tight;     % 紧贴数据边界，不留外部边框
colormap(gca, 'jet'); % 设置色图

title(sprintf('%s (neff=%.4f)', TitleStr, neff_val));
hold on;

% --- 以下样式代码保持不变 ---
style_solid  = {'Color', 'w', 'LineWidth', 1.2, 'LineStyle', '-'};
style_dashed = {'Color', 'w', 'LineWidth', 0.8, 'LineStyle', '--'};

if strcmp(ActiveTag, 'Ring')
    style_ring = style_solid;
    style_bus  = style_dashed;
else
    style_ring = style_dashed;
    style_bus  = style_solid;
end

draw_geometry_outlines(X, g, R_bus_cen, style_ring, style_bus);
hold off;
end

function draw_geometry_outlines(X, g, R_bus_cen, style_ring, style_bus)
x_min = min(X(:)); x_max = max(X(:));

z_slab_bot  = 0;
z_slab_top  = g.t_ln - g.t_ridge;
z_ridge_top = g.t_ln;

dx = g.t_ridge * cot(g.theta_deg * pi/180);

plot([x_min, x_max], [z_slab_bot, z_slab_bot], 'Color', 'w', 'LineWidth', 1.0, 'LineStyle', '-');

R_L_bot = g.Radius - g.w_ring/2 - dx;
R_R_bot = g.Radius + g.w_ring/2 + dx;
B_L_bot = R_bus_cen - g.w_bus/2 - dx;
B_R_bot = R_bus_cen + g.w_bus/2 + dx;

style_slab = {'Color', 'w', 'LineWidth', 1.0, 'LineStyle', '-'};
plot([x_min, R_L_bot],   [z_slab_top, z_slab_top], style_slab{:});
plot([R_R_bot, B_L_bot], [z_slab_top, z_slab_top], style_slab{:});
plot([B_R_bot, x_max],   [z_slab_top, z_slab_top], style_slab{:});

draw_open_ridge(g.Radius, g.w_ring, z_ridge_top, z_slab_top, dx, style_ring);
draw_open_ridge(R_bus_cen, g.w_bus, z_ridge_top, z_slab_top, dx, style_bus);
end

function draw_open_ridge(cen, w_top, z_top, z_bot, dx, style)
xv = [cen - w_top/2 - dx, cen - w_top/2, cen + w_top/2, cen + w_top/2 + dx];
yv = [z_bot,              z_top,         z_top,         z_bot];
plot(xv, yv, style{:});
end

function rAverage_vec = read_rAverage_from_model(model, N_modes)
% Read COMSOL rAverage-like variable in meter.
% Modify candidate_exprs if your model uses a different variable name.

sol_list = 1:N_modes;

candidate_exprs = { ...
    'ewfd.rAverage', ...
    'ewfd.raverage', ...
    'rAverage', ...
    'raverage' ...
    };

for ii = 1:numel(candidate_exprs)

    expr = candidate_exprs{ii};

    try
        tmp = mphglobal(model, expr, ...
            'dataset', 'dset1', ...
            'solnum', sol_list, ...
            'unit', 'm');

        if ~isempty(tmp)
            rAverage_vec = tmp(:);
            return;
        end

    catch
        % Try next candidate expression
    end
end

% Fallback: use parameter Radius if rAverage cannot be read
try
    tmp = mphglobal(model, 'Radius', ...
        'dataset', 'dset1', ...
        'unit', 'm');

    rAverage_vec = tmp(:);

    fprintf('WARNING: rAverage variable was not found. Fallback to parameter Radius.\n');
    return;

catch
    error(['Could not read rAverage from COMSOL. ', ...
           'Please check the exact variable name, e.g. ewfd.rAverage or rAverage.']);
end
end

function print_mode_table(tag_str, pol_target, order_target, ...
    neff_raw_vec, neff_actual_vec, Q_vec, TE_vec, TM_vec, ...
    rAvg_vec, r_center_m, isBound, isPol)
% Print all solved modes for debugging.
%
% neff_actual is the radius-corrected physical neff.

fprintf('\nSolved mode table [%s], target = %s%d\n', ...
    tag_str, upper(pol_target), order_target-1);

fprintf('  r_center = %.4f um\n', r_center_m*1e6);
fprintf('  -------------------------------------------------------------------------------\n');
fprintf('  solnum   Re(neff_actual)  Re(neff_raw)        Q        TEfrac   TMfrac   rAvg(um)  Bound  Pol\n');
fprintf('  -------------------------------------------------------------------------------\n');

for kk = 1:numel(neff_actual_vec)

    if isfinite(real(neff_actual_vec(kk)))

        fprintf('  %4d      %12.6f   %12.6f   %9.3e   %7.3f  %7.3f   %8.3f    %d      %d\n', ...
            kk, ...
            real(neff_actual_vec(kk)), ...
            real(neff_raw_vec(kk)), ...
            Q_vec(kk), ...
            TE_vec(kk), ...
            TM_vec(kk), ...
            rAvg_vec(kk)*1e6, ...
            isBound(kk), ...
            isPol(kk));
    end
end

fprintf('  -------------------------------------------------------------------------------\n\n');
end

function T = make_mode_summary_table(lambda_um, neff_ring, neff_bus, ...
    Q_ring, Q_bus, TE_ring, TM_ring, TE_bus, TM_bus, Gamma, DeltaBeta)
%MAKE_MODE_SUMMARY_TABLE Build one-row-per-wavelength summary table.

T = table(lambda_um(:), neff_ring(:), neff_bus(:), ...
    Q_ring(:), Q_bus(:), TE_ring(:), TM_ring(:), TE_bus(:), TM_bus(:), ...
    Gamma(:), DeltaBeta(:), ...
    'VariableNames', { ...
        'lambda_um', 'neff_ring', 'neff_bus', ...
        'Q_ring', 'Q_bus', 'TE_ring', 'TM_ring', 'TE_bus', 'TM_bus', ...
        'Gamma_rad_per_m', 'DeltaBeta_rad_per_m'});
end
