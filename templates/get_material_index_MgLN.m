function n_idx = get_material_index_MgLN(lambda_um)
%% get_material_index
% Wavelength-dependent refractive indices for:
%   1. 5 mol.% MgO-doped congruent lithium niobate, 24.5 C
%   2. SiO2
%
% Input:
%   lambda_um : wavelength in um
%
% Output:
%   n_idx.no      : LN ordinary refractive index
%   n_idx.ne      : LN extraordinary refractive index
%   n_idx.n_sio2  : SiO2 refractive index
%   n_idx.n_clad  : same as n_sio2, for compatibility

    lambda  = lambda_um;
    lambda2 = lambda.^2;

    %% ===================== MgO-doped LN ordinary index =====================
    % 5 mol.% MgO-doped CLN, 24.5 C, ordinary ray
    %
    % n_o^2 =
    %   5.6533
    % + 0.1185 / (lambda^2 - 0.2091^2)
    % + 89.61  / (lambda^2 - 10.85^2)
    % - 1.97e-2 * lambda^2

    no2 = 5.6533 ...
        + 0.1185 ./ (lambda2 - 0.2091^2) ...
        + 89.61  ./ (lambda2 - 10.85^2) ...
        - 1.97e-2 .* lambda2;

    %% ===================== MgO-doped LN extraordinary index =====================
    % 5 mol.% MgO-doped CLN, 24.5 C, extraordinary ray
    %
    % n_e^2 =
    %   5.756
    % + 0.0983 / (lambda^2 - 0.2020^2)
    % + 189.32 / (lambda^2 - 12.52^2)
    % - 1.32e-2 * lambda^2

    ne2 = 5.756 ...
        + 0.0983 ./ (lambda2 - 0.2020^2) ...
        + 189.32 ./ (lambda2 - 12.52^2) ...
        - 1.32e-2 .* lambda2;

    %% ===================== SiO2 index =====================
    % Fused silica Sellmeier
    %
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

end