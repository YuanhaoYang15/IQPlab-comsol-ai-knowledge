function out = run_ring_qpm_case(model, geom, scan, select, opts)
%RUN_RING_QPM_CASE Compute neff/ng/Dint/GVM/QPM/SHG mismatch for one ring geometry.
% Required external dependency: get_material_index_MgLN(lambda_um)
% Required COMSOL variables: TEfrac, TMfrac; optional rAverage.

if nargin < 5, opts = struct(); end
c0 = 299792458;
opts = fill_default_opts(opts);
check_inputs(geom, scan, select, opts);
geom.w_center = geom.Radius;

n_step = round(scan.span_IR/scan.step_IR);
lambda_IR = linspace(scan.lambda0_IR-scan.span_IR/2, scan.lambda0_IR+scan.span_IR/2, n_step+1);
lambda_SH = lambda_IR/2;
lambda0_SH = scan.lambda0_IR/2;

if opts.do_validation
    fprintf('\n========== Pre-validation ==========\n');
    val = validate_ring_qpm_case(model, geom, scan, select, opts);
    if ~val.pass
        out = struct('status','validation_failed','validation',val,'geom',geom,'scan',scan,'select',select,'opts',opts);
        if opts.save_result && opts.save_validation_fail
            out.save_path = make_result_filename(geom, scan, select, opts);
            save(out.save_path, 'out');
            fprintf('Validation failed. Diagnostic file saved to:\n%s\n', out.save_path);
        end
        if opts.stop_on_validation_fail
            error('Validation failed for this geometry.');
        end
        return;
    end
    N_modes_search = val.recommended_N_modes;
else
    val = [];
    N_modes_search = opts.N_modes_initial;
end

fprintf('\n========== Full wavelength scan ==========\n');
fprintf('Geometry: R=%.4f um, w=%.4f um, tLN=%.4f um, tRidge=%.4f um\n', ...
    geom.Radius, geom.w_ln, geom.t_ln, geom.t_ridge);
fprintf('Using N_modes_search = %d\n', N_modes_search);

Data_IR = scan_neff_band_single_model(model, lambda_IR, geom, select.IR.pol, select.IR.order, ...
    N_modes_search, opts.Q_threshold, opts.pol_threshold, 'IR', opts);
Data_SH = scan_neff_band_single_model(model, lambda_SH, geom, select.SH.pol, select.SH.order, ...
    N_modes_search, opts.Q_threshold, opts.pol_threshold, 'SH', opts);

neff_IR = Data_IR.neff_sel(:);
neff_SH = Data_SH.neff_sel(:);
ng_IR = calc_ng_from_neff(lambda_IR(:), neff_IR);
ng_SH = calc_ng_from_neff(lambda_SH(:), neff_SH);

Result_IR = calc_dint_from_neff(lambda_IR, neff_IR, geom.Radius, scan.lambda0_IR, c0, 'IR band');
Result_SH = calc_dint_from_neff(lambda_SH, neff_SH, geom.Radius, lambda0_SH, c0, 'SH band');

if opts.verbose
    fprintf('\n========= Ring dispersion summary =========\n');
    print_dint_summary(Result_IR); print_dint_summary(Result_SH);
end

neff_SH_on_half_IR = interp1(lambda_SH(:), neff_SH(:), lambda_IR(:)/2, 'pchip', 'extrap');
Lambda_QPM_signed_um = lambda_IR(:) ./ (2*(neff_SH_on_half_IR(:)-neff_IR(:)));
Lambda_QPM_um = abs(Lambda_QPM_signed_um);

ng_SH_on_half_IR = interp1(lambda_SH(:), ng_SH(:), lambda_IR(:)/2, 'pchip', 'extrap');
GVM_fs_per_mm = ((ng_SH_on_half_IR(:)-ng_IR(:))/c0)*1e12;

Walk = calc_shg_frequency_mismatch(Result_IR, Result_SH, scan.lambda0_IR, opts.verbose);
min_Q_IR_sel = min_finite(Data_IR.Q_sel(:));
min_Q_SH_sel = min_finite(Data_SH.Q_sel(:));
smooth = check_branch_smoothness(lambda_IR, neff_IR, lambda_SH, neff_SH, Data_IR, Data_SH, opts);

fprintf('\n========= Qrad reference =========\n');
fprintf('IR selected branch min Qrad = %.3e\n', min_Q_IR_sel);
fprintf('SH selected branch min Qrad = %.3e\n', min_Q_SH_sel);
if ~smooth.pass
    fprintf('\nWARNING: branch smoothness/Q check raised warnings.\n');
    fprintf('  max neff jump IR = %.3e, SH = %.3e\n', smooth.max_jump_IR, smooth.max_jump_SH);
    fprintf('  min Q IR = %.3e, SH = %.3e\n', smooth.min_Q_IR, smooth.min_Q_SH);
end

out = struct();
out.status = 'success';
out.geom = geom; out.scan = scan; out.select = select; out.opts = opts;
out.validation = val; out.N_modes_search = N_modes_search;
out.lambda_IR = lambda_IR; out.lambda_SH = lambda_SH;
out.Data_IR = Data_IR; out.Data_SH = Data_SH;
out.neff_IR = neff_IR; out.neff_SH = neff_SH;
out.ng_IR = ng_IR; out.ng_SH = ng_SH;
out.Result_IR = Result_IR; out.Result_SH = Result_SH;
out.Lambda_QPM_um = Lambda_QPM_um; out.Lambda_QPM_signed_um = Lambda_QPM_signed_um;
out.GVM_fs_per_mm = GVM_fs_per_mm; out.Walk = Walk;
out.min_Q_IR_sel = min_Q_IR_sel; out.min_Q_SH_sel = min_Q_SH_sel;
out.smooth = smooth;

if opts.save_result
    out.save_path = make_result_filename(geom, scan, select, opts);
    save(out.save_path, 'out');
    fprintf('\nResult saved to:\n%s\n', out.save_path);
end
end

function val = validate_ring_qpm_case(model, geom, scan, select, opts)
if opts.validation_use_center
    lambda_IR_test = unique([scan.lambda0_IR-scan.span_IR/2, scan.lambda0_IR, scan.lambda0_IR+scan.span_IR/2]);
else
    lambda_IR_test = unique([scan.lambda0_IR-scan.span_IR/2, scan.lambda0_IR+scan.span_IR/2]);
end
lambda_SH_test = lambda_IR_test/2;
N_list = opts.N_modes_initial:opts.N_modes_step:opts.N_modes_max;
val = struct('pass',false,'recommended_N_modes',NaN,'message','','tests',[]);
last_records = [];
for N_modes = N_list
    fprintf('Validation trial with N_modes = %d\n', N_modes);
    pass_this_N = true; records = [];
    for ii = 1:numel(lambda_IR_test)
        rec = validate_one_point(model, geom, lambda_IR_test(ii), select.IR.pol, select.IR.order, N_modes, opts.Q_threshold, opts.pol_threshold, 'IR', opts);
        records = append_struct_record(records, rec); if ~rec.pass, pass_this_N = false; end
    end
    for ii = 1:numel(lambda_SH_test)
        rec = validate_one_point(model, geom, lambda_SH_test(ii), select.SH.pol, select.SH.order, N_modes, opts.Q_threshold, opts.pol_threshold, 'SH', opts);
        records = append_struct_record(records, rec); if ~rec.pass, pass_this_N = false; end
    end
    last_records = records;
    if pass_this_N
        val.pass = true;
        val.recommended_N_modes = min(N_modes + opts.N_modes_margin, opts.N_modes_max);
        val.message = "validation_passed";
        val.tests = records;
        return;
    end
end
val.message = 'validation_failed'; val.recommended_N_modes = opts.N_modes_max; val.tests = last_records;
end

function rec = validate_one_point(model, geom, lambda_um, pol, order, N_modes, Q_th, pol_th, band_name, opts)
rec = struct('band',band_name,'lambda_um',lambda_um,'N_modes',N_modes,'pol',pol,'order',order, ...
    'pass',false,'solnum',NaN,'neff',NaN,'Q',NaN,'TEfrac',NaN,'TMfrac',NaN,'message','');
try
    n_idx = get_material_index_MgLN(lambda_um);
    update_ring_model_params(model, geom, lambda_um, n_idx);
    run_solver_only(model, N_modes, opts);
    ModeTable = read_all_modes_with_Q_TE_TM(model, N_modes, geom.Radius);
    mode_info = select_mode_from_table(ModeTable, pol, order, Q_th, pol_th);
    rec.pass = true; rec.solnum = mode_info.solnum; rec.neff = real(mode_info.neff);
    rec.Q = mode_info.Q; rec.TEfrac = mode_info.TEfrac; rec.TMfrac = mode_info.TMfrac; rec.message = 'ok';
    fprintf('  [%s] %.6f um: pass, %s%d solnum=%d, neff=%.6f, Q=%.2e\n', ...
        band_name, lambda_um, upper(pol), order-1, rec.solnum, rec.neff, rec.Q);
catch ME
    rec.pass = false; rec.message = ME.message;
    fprintf('  [%s] %.6f um: failed, %s\n', band_name, lambda_um, ME.message);
end
end

function Data = scan_neff_band_single_model(model, lambda_list, geom, pol_target, order_target, N_modes, Q_th, pol_th, band_name, opts)
display_mode = lower(string(opts.display_mode));

if isfield(opts, 'case_id')
    case_id = opts.case_id;
else
    case_id = NaN;
end

if isfield(opts, 'n_cases')
    n_cases = opts.n_cases;
else
    n_cases = NaN;
end
n_step = numel(lambda_list);
Data.lambda_um = lambda_list(:);
Data.neff_sel = nan(n_step,1); Data.neff_raw_sel = nan(n_step,1); Data.Q_sel = nan(n_step,1);
Data.TE_sel = nan(n_step,1); Data.TM_sel = nan(n_step,1); Data.rAverage_sel = nan(n_step,1); Data.solnum_sel = nan(n_step,1);
Data.neff_all = nan(n_step,N_modes); Data.neff_raw_all = nan(n_step,N_modes); Data.Q_all = nan(n_step,N_modes);
Data.TE_all = nan(n_step,N_modes); Data.TM_all = nan(n_step,N_modes); Data.rAverage_all = nan(n_step,N_modes); Data.scale_all = nan(n_step,N_modes);
for ii = 1:n_step
    lam = lambda_list(ii);
    if display_mode == "compact"
        if isfinite(case_id) && isfinite(n_cases)
            fprintf('\rCase %d/%d | R=%.2f um, w=%.3f um, t_ridge=%.3f um | %s %d/%d | lambda=%.6f um', ...
                case_id, n_cases, ...
                geom.Radius, geom.w_ln, geom.t_ridge, ...
                band_name, ii, n_step, lam);
        else
            fprintf('\r%s %d/%d | lambda=%.6f um', ...
                band_name, ii, n_step, lam);
        end
    elseif display_mode == "verbose"
        fprintf('\n[%s] lambda = %.6f um (%d/%d)\n', ...
            band_name, lam, ii, n_step);
    end
    n_idx = get_material_index_MgLN(lam);
    update_ring_model_params(model, geom, lam, n_idx);
    run_solver_only(model, N_modes, opts);
    ModeTable = read_all_modes_with_Q_TE_TM(model, N_modes, geom.Radius);
    Data.neff_all(ii,:) = ModeTable.neff_actual(:).'; Data.neff_raw_all(ii,:) = ModeTable.neff_raw(:).';
    Data.Q_all(ii,:) = ModeTable.Q(:).'; Data.TE_all(ii,:) = ModeTable.TEfrac(:).'; Data.TM_all(ii,:) = ModeTable.TMfrac(:).';
    Data.rAverage_all(ii,:) = ModeTable.rAverage(:).'; Data.scale_all(ii,:) = ModeTable.scale(:).';
    if opts.verbose || opts.print_mode_table
        if display_mode == "verbose"
            print_mode_table(ModeTable, band_name, lam, pol_target, order_target, Q_th, pol_th);
        end
    end
    mode_info = select_mode_from_table(ModeTable, pol_target, order_target, Q_th, pol_th);
    Data.neff_sel(ii) = real(mode_info.neff); Data.neff_raw_sel(ii) = real(mode_info.neff_raw);
    Data.Q_sel(ii) = mode_info.Q; Data.TE_sel(ii) = mode_info.TEfrac; Data.TM_sel(ii) = mode_info.TMfrac;
    Data.rAverage_sel(ii) = mode_info.rAverage; Data.solnum_sel(ii) = mode_info.solnum;
    if display_mode == "verbose"
        fprintf('  -> selected %s%d: solnum = %d, neff = %.8f, raw = %.8f, Q = %.3e, TE = %.3f, TM = %.3f\n', ...
            upper(pol_target), order_target-1, mode_info.solnum, ...
            real(mode_info.neff), real(mode_info.neff_raw), ...
            mode_info.Q, mode_info.TEfrac, mode_info.TMfrac);
    end
end
if display_mode == "compact"
    fprintf('\n');
end
end

function update_ring_model_params(model, g, lambda_um, n)
to_um = @(x) [num2str(x,16),'[um]']; to_deg = @(x) [num2str(x,16),'[deg]'];
safe_set_param(model,'Radius',to_um(g.Radius)); safe_set_param(model,'w_center',to_um(g.Radius));
safe_set_param(model,'w_ln',to_um(g.w_ln)); safe_set_param(model,'t_ln',to_um(g.t_ln));
safe_set_param(model,'t_ridge',to_um(g.t_ridge)); safe_set_param(model,'w_pml',to_um(g.w_pml)); safe_set_param(model,'theta',to_deg(g.theta_deg));
safe_set_param(model,'w_sub',to_um(g.w_ln+8));
if isfield(g,'t_sio2'), safe_set_param(model,'t_sio2',to_um(g.t_sio2)); end
if isfield(g,'t_air'), safe_set_param(model,'t_air',to_um(g.t_air)); end
safe_set_param(model,'wavelength',to_um(lambda_um));
safe_set_param(model,'no',num2str(n.no,16)); safe_set_param(model,'ne',num2str(n.ne,16)); safe_set_param(model,'n_sio2',num2str(n.n_sio2,16));
safe_set_param(model,'nref',num2str(max([n.no,n.ne]),16));
safe_set_param(model,'Ravg',to_um(g.Radius)); safe_set_param(model,'rAverage',to_um(g.Radius));
end

function safe_set_param(model, name, value)
try, model.param.set(name,value); catch, end
end

function run_solver_only(model, num_modes, opts)
model.study('std1').feature('mode').set('neigs', num2str(num_modes));
if isfield(opts,'eigwhich') && ~isempty(opts.eigwhich)
    try, model.study('std1').feature('mode').set('eigwhich', opts.eigwhich); catch, end
end
model.study('std1').run;
end

function ModeTable = read_all_modes_with_Q_TE_TM(model, N_modes, r_center_um)
sol_list = 1:N_modes; dataset_tag = get_dataset_tag(model);
neff_raw = mphglobal(model,'ewfd.neff','dataset',dataset_tag,'solnum',sol_list);
TEfrac_raw = mphglobal(model,'TEfrac','dataset',dataset_tag,'solnum',sol_list);
TMfrac_raw = mphglobal(model,'TMfrac','dataset',dataset_tag,'solnum',sol_list);
rAverage_raw = read_rAverage_from_model(model,N_modes,dataset_tag);
neff_raw = neff_raw(:); TEfrac_raw = real(TEfrac_raw(:)); TMfrac_raw = real(TMfrac_raw(:));
neff_raw_vec = nan(N_modes,1); neff_actual_vec = nan(N_modes,1); Q_vec = nan(N_modes,1); TE_vec = nan(N_modes,1); TM_vec = nan(N_modes,1); rAvg_vec = nan(N_modes,1);
N_found = min(numel(neff_raw),N_modes); neff_raw_vec(1:N_found) = neff_raw(1:N_found);
N_TE = min(numel(TEfrac_raw),N_modes); N_TM = min(numel(TMfrac_raw),N_modes);
TE_vec(1:N_TE) = TEfrac_raw(1:N_TE); TM_vec(1:N_TM) = TMfrac_raw(1:N_TM);
if numel(rAverage_raw)==1
    rAvg_vec(:)=rAverage_raw;
else
    N_RA = min(numel(rAverage_raw),N_modes); rAvg_vec(1:N_RA)=rAverage_raw(1:N_RA);
end
r_center_m = r_center_um*1e-6; scale_vec = rAvg_vec./r_center_m; neff_actual_vec = neff_raw_vec.*scale_vec;
Q_vec = real(neff_actual_vec)./(2*abs(imag(neff_actual_vec))); Q_vec(~isfinite(Q_vec)) = 1e99;
ModeTable.solnum=(1:N_modes).'; ModeTable.neff_raw=neff_raw_vec; ModeTable.neff_actual=neff_actual_vec; ModeTable.Q=Q_vec;
ModeTable.TEfrac=TE_vec; ModeTable.TMfrac=TM_vec; ModeTable.rAverage=rAvg_vec; ModeTable.r_center_m=r_center_m; ModeTable.scale=scale_vec;
end

function dataset_tag = get_dataset_tag(model)
try
    tags = cellstr(model.result.dataset.tags);
    if any(strcmp(tags,'dset1')), dataset_tag='dset1'; else, dataset_tag=tags{end}; end
catch
    dataset_tag='dset1';
end
end

function rAverage_vec = read_rAverage_from_model(model, N_modes, dataset_tag)
sol_list = 1:N_modes; candidate_exprs = {'ewfd.rAverage','ewfd.raverage','rAverage','raverage'};
for ii=1:numel(candidate_exprs)
    try
        tmp = mphglobal(model,candidate_exprs{ii},'dataset',dataset_tag,'solnum',sol_list,'unit','m');
        if ~isempty(tmp), rAverage_vec = tmp(:); return; end
    catch
    end
end
try
    tmp = mphglobal(model,'Radius','dataset',dataset_tag,'unit','m'); rAverage_vec = tmp(:);
    fprintf('WARNING: rAverage not found. Fallback to parameter Radius.\n'); return;
catch
    error('Could not read rAverage or Radius from COMSOL model.');
end
end

function print_mode_table(ModeTable, band_name, lambda_um, pol_target, order_target, Q_th, pol_th)
isBound = ModeTable.Q > Q_th & isfinite(ModeTable.Q) & real(ModeTable.neff_actual)>1;
switch upper(pol_target)
    case 'TE', isPol = ModeTable.TEfrac>=pol_th & ModeTable.TEfrac>=ModeTable.TMfrac;
    case 'TM', isPol = ModeTable.TMfrac>=pol_th & ModeTable.TMfrac>ModeTable.TEfrac;
    otherwise, error('pol_target must be TE or TM.');
end
fprintf('\nSolved mode table [%s, lambda = %.6f um], target = %s%d\n', band_name, lambda_um, upper(pol_target), order_target-1);
fprintf('  r_center = %.4f um\n', ModeTable.r_center_m*1e6);
fprintf('  ---------------------------------------------------------------------------------------\n');
fprintf('  solnum   Re(neff_actual)  Re(neff_raw)        Q        TEfrac   TMfrac   rAvg(um)  Bound  Pol\n');
fprintf('  ---------------------------------------------------------------------------------------\n');
for kk=1:numel(ModeTable.solnum)
    if isfinite(real(ModeTable.neff_actual(kk)))
        fprintf('  %4d      %12.6f   %12.6f   %9.3e   %7.3f  %7.3f   %8.3f    %d      %d\n', kk, real(ModeTable.neff_actual(kk)), real(ModeTable.neff_raw(kk)), ModeTable.Q(kk), ModeTable.TEfrac(kk), ModeTable.TMfrac(kk), ModeTable.rAverage(kk)*1e6, isBound(kk), isPol(kk));
    end
end
fprintf('  ---------------------------------------------------------------------------------------\n\n');
end

function mode_info = select_mode_from_table(ModeTable, pol_target, order_target, Q_th, pol_th)
isBound = ModeTable.Q > Q_th & isfinite(ModeTable.Q) & real(ModeTable.neff_actual)>1;
switch upper(pol_target)
    case 'TE', isPol = ModeTable.TEfrac>=pol_th & ModeTable.TEfrac>=ModeTable.TMfrac;
    case 'TM', isPol = ModeTable.TMfrac>=pol_th & ModeTable.TMfrac>ModeTable.TEfrac;
    otherwise, error('pol_target must be TE or TM.');
end
idx_candidates = find(isBound & isPol);
if isempty(idx_candidates), error('No %s-like bound mode found. Try lowering Q_threshold or pol_threshold.', upper(pol_target)); end
[~,idx_sort] = sort(real(ModeTable.neff_actual(idx_candidates)),'descend'); idx_candidates = idx_candidates(idx_sort);
if order_target > numel(idx_candidates)
    error('Requested %s%d, but only %d %s-like bound modes were found.', upper(pol_target), order_target-1, numel(idx_candidates), upper(pol_target));
end
idx = idx_candidates(order_target);
mode_info.solnum=idx; mode_info.neff=ModeTable.neff_actual(idx); mode_info.neff_raw=ModeTable.neff_raw(idx); mode_info.Q=ModeTable.Q(idx);
mode_info.TEfrac=ModeTable.TEfrac(idx); mode_info.TMfrac=ModeTable.TMfrac(idx); mode_info.rAverage=ModeTable.rAverage(idx); mode_info.scale=ModeTable.scale(idx);
end

function ng = calc_ng_from_neff(lambda_um, neff)
lambda_um = lambda_um(:); neff = neff(:); valid = isfinite(lambda_um) & isfinite(neff);
if sum(valid)<5, error('Too few valid neff points for ng calculation.'); end
lambda_v=lambda_um(valid); neff_v=neff(valid); [lambda_v,idx]=sort(lambda_v); neff_v=neff_v(idx);
neff_smooth = interp1(lambda_v,neff_v,lambda_um,'pchip','extrap');
dneff_dlambda = gradient(neff_smooth, lambda_um);
ng = neff_smooth - lambda_um.*dneff_dlambda;
end

function Result = calc_dint_from_neff(lambda_um, neff, R_um, center_lambda_um, c0, label)
lambda_um=lambda_um(:); neff=neff(:); valid=isfinite(lambda_um)&isfinite(neff); lambda_um=lambda_um(valid); neff=neff(valid);
if numel(lambda_um)<5, error('%s: too few valid neff points to calculate Dint.', label); end
omega = 2*pi*c0./(lambda_um*1e-6);
m_float = 2*pi*R_um.*neff./lambda_um;
[m_sort,idx]=sort(m_float,'ascend'); omega_sort=omega(idx); lambda_sort=lambda_um(idx); neff_sort=neff(idx);
[m_unique,ia]=unique(m_sort,'stable'); omega_unique=omega_sort(ia); lambda_unique=lambda_sort(ia); neff_unique=neff_sort(ia);
neff_center=interp1(lambda_um,neff,center_lambda_um,'pchip','extrap'); m0_float=2*pi*R_um*neff_center/center_lambda_um; m0=round(m0_float);
m_int=(ceil(min(m_unique)):floor(max(m_unique))).';
if numel(m_int)<5, error('%s: too few integer azimuthal modes covered. Increase wavelength span.', label); end
omega_m=interp1(m_unique,omega_unique,m_int,'pchip'); lambda_m_um=interp1(m_unique,lambda_unique,m_int,'pchip'); neff_m=interp1(m_unique,neff_unique,m_int,'pchip');
mu=m_int-m0; idx0=find(mu==0,1); if isempty(idx0), error('%s: center mode m0 is outside the interpolated integer mode range.', label); end
omega0=omega_m(idx0); idx_p1=find(mu==1,1); idx_m1=find(mu==-1,1);
if ~isempty(idx_p1) && ~isempty(idx_m1)
    D1=(omega_m(idx_p1)-omega_m(idx_m1))/2; D2=omega_m(idx_p1)-2*omega0+omega_m(idx_m1);
else
    fit_idx=abs(mu)<=min(3,max(abs(mu))); p=polyfit(mu(fit_idx),omega_m(fit_idx),2); D1=p(2); D2=2*p(1);
end
Dint=omega_m-(omega0+D1*mu);
Result.label=label; Result.R_um=R_um; Result.center_lambda_input_um=center_lambda_um; Result.m0_float=m0_float; Result.m0=m0;
Result.m_int=m_int(:); Result.mu=mu(:); Result.lambda_m_um=lambda_m_um(:); Result.neff_m=neff_m(:);
Result.omega_rad_s=omega_m(:); Result.omega0_rad_s=omega0; Result.D1_rad_s=D1; Result.D2_rad_s=D2; Result.Dint_rad_s=Dint(:);
Result.freq_Hz=omega_m(:)/(2*pi); Result.freq0_Hz=omega0/(2*pi); Result.D1_Hz=D1/(2*pi); Result.D2_Hz=D2/(2*pi); Result.Dint_Hz=Dint(:)/(2*pi);
end

function Walk = calc_shg_frequency_mismatch(Result_IR, Result_SH, center_lambda_IR, verbose)
if nargin<4, verbose=false; end
mu_IR_all=Result_IR.mu(:); f_IR_all=Result_IR.freq_Hz(:); lambda_IR_all=Result_IR.lambda_m_um(:);
mu_SH_all=Result_SH.mu(:); f_SH_all=Result_SH.freq_Hz(:); lambda_SH_all=Result_SH.lambda_m_um(:);
mu_SH_req=2*mu_IR_all; [tf,loc]=ismember(mu_SH_req,mu_SH_all);
mu_IR_use=mu_IR_all(tf); mu_SH_use=mu_SH_req(tf); f_IR_use=f_IR_all(tf); f_SH_use=f_SH_all(loc(tf)); lambda_IR_use=lambda_IR_all(tf); lambda_SH_use=lambda_SH_all(loc(tf));
if isempty(mu_IR_use), error('No matching SH modes found for mu_SH = 2*mu_IR. Increase wavelength span.'); end
Delta_f_SHG_Hz=f_SH_use-2*f_IR_use; idx0=find(mu_IR_use==0,1);
if isempty(idx0), warning('No mu_IR = 0 point found. Using wavelength closest to center.'); [~,idx0]=min(abs(lambda_IR_use-center_lambda_IR)); end
Delta_f0_Hz=Delta_f_SHG_Hz(idx0); Delta_f_rel_Hz=Delta_f_SHG_Hz-Delta_f0_Hz;
Walk.mu_IR_use=mu_IR_use; Walk.mu_SH_use=mu_SH_use; Walk.f_IR_use_Hz=f_IR_use; Walk.f_SH_use_Hz=f_SH_use;
Walk.lambda_IR_use_um=lambda_IR_use; Walk.lambda_SH_use_um=lambda_SH_use; Walk.Delta_f_SHG_Hz=Delta_f_SHG_Hz; Walk.Delta_f0_Hz=Delta_f0_Hz; Walk.Delta_f_rel_Hz=Delta_f_rel_Hz;
if verbose
    fprintf('\n========= SHG mismatch center reference =========\n'); fprintf('  mu_IR = %d, mu_SH = %d\n', mu_IR_use(idx0), mu_SH_use(idx0));
    fprintf('  lambda_IR = %.9f um\n', lambda_IR_use(idx0)); fprintf('  lambda_SH = %.9f um\n', lambda_SH_use(idx0)); fprintf('  center offset f_SH - 2*f_IR = %.6f GHz\n', Delta_f0_Hz/1e9);
end
end

function opts = fill_default_opts(opts)
if ~isfield(opts,'N_modes_initial'), opts.N_modes_initial=10; end
if ~isfield(opts,'N_modes_max'), opts.N_modes_max=30; end
if ~isfield(opts,'N_modes_step'), opts.N_modes_step=4; end
if ~isfield(opts,'N_modes_margin'), opts.N_modes_margin=2; end
if ~isfield(opts,'edge_margin'), opts.edge_margin=2; end
if ~isfield(opts,'Q_threshold'), opts.Q_threshold=1e7; end
if ~isfield(opts,'pol_threshold'), opts.pol_threshold=0.5; end
if ~isfield(opts,'do_validation'), opts.do_validation=true; end
if ~isfield(opts,'validation_use_center'), opts.validation_use_center=true; end
if ~isfield(opts,'save_result'), opts.save_result=true; end
if ~isfield(opts,'save_validation_fail'), opts.save_validation_fail=true; end
if ~isfield(opts,'stop_on_validation_fail'), opts.stop_on_validation_fail=false; end
if ~isfield(opts,'output_dir'), opts.output_dir=pwd; end
if ~isfield(opts,'overwrite'), opts.overwrite=false; end
if ~isfield(opts,'result_prefix'), opts.result_prefix='RingQPM'; end
if ~isfield(opts,'verbose'), opts.verbose=false; end
if ~isfield(opts,'print_mode_table'), opts.print_mode_table=false; end
if ~isfield(opts,'eigwhich'), opts.eigwhich=''; end
if ~isfield(opts,'neff_jump_threshold'), opts.neff_jump_threshold=0.02; end
if ~isfield(opts,'Q_warning_threshold'), opts.Q_warning_threshold=1e6; end
if ~isfield(opts, 'display_mode')
    if isfield(opts, 'verbose') && opts.verbose
        opts.display_mode = 'verbose';
    else
        opts.display_mode = 'compact';
    end
end
if ~isfield(opts, 'verbose')
    opts.verbose = strcmpi(opts.display_mode, 'verbose');
end
end

function check_inputs(geom, scan, select, opts)
required_geom={'Radius','w_ln','t_ln','t_ridge','theta_deg','w_pml'};
for ii=1:numel(required_geom), if ~isfield(geom,required_geom{ii}), error('geom.%s is required.',required_geom{ii}); end, end
required_scan={'lambda0_IR','span_IR','step_IR'};
for ii=1:numel(required_scan), if ~isfield(scan,required_scan{ii}), error('scan.%s is required.',required_scan{ii}); end, end
if scan.step_IR<=0 || scan.span_IR<=0, error('scan.step_IR and scan.span_IR must be positive.'); end
if scan.step_IR>scan.span_IR, error('scan.step_IR should not be larger than scan.span_IR.'); end
if ~isfield(select,'IR') || ~isfield(select,'SH'), error('select.IR and select.SH are required.'); end
if opts.N_modes_initial>opts.N_modes_max, error('opts.N_modes_initial should be <= opts.N_modes_max.'); end
end

function recs = append_struct_record(recs, rec)
if isempty(recs), recs = rec; else, recs(end+1) = rec; end
end

function print_dint_summary(Result)
idx0=find(Result.mu==0,1); fprintf('\n%s\n',Result.label); fprintf('  R = %.6f um\n',Result.R_um);
fprintf('  center lambda input = %.6f um\n',Result.center_lambda_input_um); fprintf('  nearest resonance lambda0 = %.9f um\n',Result.lambda_m_um(idx0));
fprintf('  m0_float, m0 = %.6f, %d\n',Result.m0_float,Result.m0); fprintf('  D1/2pi = FSR = %.6f GHz\n',Result.D1_Hz/1e9);
fprintf('  D2/2pi = %.6f MHz\n',Result.D2_Hz/1e6); fprintf('  mode range = mu [%d, %d]\n',min(Result.mu),max(Result.mu));
end

function val = min_finite(x)
x=x(:); x=x(isfinite(x)); if isempty(x), val=NaN; else, val=min(x); end
end

function smooth = check_branch_smoothness(lambda_IR, neff_IR, lambda_SH, neff_SH, Data_IR, Data_SH, opts)
smooth.max_jump_IR=max_or_nan(abs(diff(neff_IR(:)))); smooth.max_jump_SH=max_or_nan(abs(diff(neff_SH(:))));
smooth.min_Q_IR=min_finite(Data_IR.Q_sel); smooth.min_Q_SH=min_finite(Data_SH.Q_sel);
smooth.warn_IR_jump=smooth.max_jump_IR>opts.neff_jump_threshold; smooth.warn_SH_jump=smooth.max_jump_SH>opts.neff_jump_threshold;
smooth.warn_IR_Q=smooth.min_Q_IR<opts.Q_warning_threshold; smooth.warn_SH_Q=smooth.min_Q_SH<opts.Q_warning_threshold;
smooth.pass=~(smooth.warn_IR_jump||smooth.warn_SH_jump||smooth.warn_IR_Q||smooth.warn_SH_Q);
smooth.lambda_IR=lambda_IR(:); smooth.lambda_SH=lambda_SH(:);
end

function v=max_or_nan(x)
if isempty(x), v=NaN; else, v=max(x); end
end

function save_path = make_result_filename(geom, scan, select, opts)
tag=sprintf(['R%s_w%s_tln%s_tr%s_th%s_IR%s%d_SH%s%d_lam%s_span%s_step%s'], ...
    num_tag(geom.Radius),num_tag(geom.w_ln),num_tag(geom.t_ln),num_tag(geom.t_ridge),num_tag(geom.theta_deg), ...
    upper(select.IR.pol),select.IR.order-1,upper(select.SH.pol),select.SH.order-1,num_tag(scan.lambda0_IR*1e3),num_tag(scan.span_IR*1e3),num_tag(scan.step_IR*1e3));
fname=[opts.result_prefix '_' tag '.mat']; if ~exist(opts.output_dir,'dir'), mkdir(opts.output_dir); end
save_path=fullfile(opts.output_dir,fname); if ~opts.overwrite, save_path=make_unique_filename(save_path); end
end

function s=num_tag(x)
s=sprintf('%.4g',x); s=strrep(s,'.','p'); s=strrep(s,'-','m');
end

function path_out=make_unique_filename(path_in)
if ~exist(path_in,'file'), path_out=path_in; return; end
[folder,base,ext]=fileparts(path_in); kk=1;
while true
    path_try=fullfile(folder,sprintf('%s_%03d%s',base,kk,ext));
    if ~exist(path_try,'file'), path_out=path_try; return; end
    kk=kk+1;
end
end
