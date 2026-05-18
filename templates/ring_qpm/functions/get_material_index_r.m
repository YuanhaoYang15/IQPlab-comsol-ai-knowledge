function n_idx = get_material_index_r(lambda_um)
%% get_material_index
% Wavelength-dependent refractive indices for LN and SiO2.
%
% Input:
%   lambda_um : wavelength in um
%
% Output:
%   n_idx.no      : LN ordinary index
%   n_idx.ne      : LN extraordinary index
%   n_idx.n_sio2  : SiO2 index
%   n_idx.n_clad  : same as n_sio2, for compatibility with existing COMSOL code

    lambda = lambda_um;
    lambda2 = lambda.^2;

    %% ===================== LN ordinary index =====================
    % n_o^2 - 1 =
    %   2.6734 lambda^2 / (lambda^2 - 0.01764)
    % + 1.2290 lambda^2 / (lambda^2 - 0.05914)
    % + 12.614 lambda^2 / (lambda^2 - 474.60)

    no2 = 1 ...
        + 2.6734 .* lambda2 ./ (lambda2 - 0.01764) ...
        + 1.2290 .* lambda2 ./ (lambda2 - 0.05914) ...
        + 12.614 .* lambda2 ./ (lambda2 - 474.60);

    %% ===================== LN extraordinary index =====================
    % n_e^2 - 1 =
    %   2.9804 lambda^2 / (lambda^2 - 0.02047)
    % + 0.5981 lambda^2 / (lambda^2 - 0.0666)
    % + 8.9543 lambda^2 / (lambda^2 - 416.08)

    ne2 = 1 ...
        + 2.9804 .* lambda2 ./ (lambda2 - 0.02047) ...
        + 0.5981 .* lambda2 ./ (lambda2 - 0.0666) ...
        + 8.9543 .* lambda2 ./ (lambda2 - 416.08);

    %% ===================== SiO2 index =====================
    % n_SiO2^2 - 1 =
    %   0.6961663 lambda^2 / (lambda^2 - 0.0684043^2)
    % + 0.4079426 lambda^2 / (lambda^2 - 0.1162414^2)
    % + 0.8974794 lambda^2 / (lambda^2 - 9.896161^2)

    nsio2_2 = 1 ...
        + 0.6961663 .* lambda2 ./ (lambda2 - 0.0684043^2) ...
        + 0.4079426 .* lambda2 ./ (lambda2 - 0.1162414^2) ...
        + 0.8974794 .* lambda2 ./ (lambda2 - 9.896161^2);

    %% ===================== Output =====================

    n_idx.no     = sqrt(no2);
    n_idx.ne     = sqrt(ne2);
    n_idx.n_sio2 = sqrt(nsio2_2);

    % 为了兼容之前 Optical_mode_neff_only_Dint.m 里可能用到的 n_clad
    n_idx.n_clad = n_idx.n_sio2;

end