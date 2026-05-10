%% check_livelink_connection.m
% Minimal test for checking whether MATLAB is connected to COMSOL LiveLink.
%
% Recommended usage:
%   1. Start "COMSOL Multiphysics with MATLAB".
%   2. Run this script in MATLAB.
%
% Alternative manual workflow:
%   1. Start a COMSOL Multiphysics Server manually.
%   2. Start MATLAB normally.
%   3. Add the COMSOL LiveLink mli directory to the MATLAB path.
%   4. Run mphstart with the correct port.
%   5. Run this script.
%
% Example manual setup:
%   addpath('C:\Program Files\COMSOL\COMSOL63\Multiphysics\mli');
%   mphstart(2036);
%
% Notes:
%   - Do not write real usernames or passwords into this script.
%   - Do not commit machine-specific private paths unless they are examples.

clear; clc;

fprintf('Checking COMSOL LiveLink connection...\n');

try
    import com.comsol.model.*
    import com.comsol.model.util.*

    ModelUtil.showProgress(true);

    tags = mphtags;

    fprintf('LiveLink connection is active.\n');

    if isempty(tags)
        fprintf('No model is currently loaded on the COMSOL server.\n');
    else
        fprintf('Models currently available on the COMSOL server:\n');
        disp(tags);
    end

catch ME
    fprintf('LiveLink connection test failed.\n');
    fprintf('Error message:\n%s\n\n', ME.message);

    fprintf('Possible fixes:\n');
    fprintf('1. Start MATLAB using "COMSOL Multiphysics with MATLAB".\n');
    fprintf('2. Or start a COMSOL server manually and run mphstart in MATLAB.\n');
    fprintf('3. If MATLAB cannot find mphstart, add <COMSOL_ROOT>\\mli to the MATLAB path.\n');
    fprintf('4. Check whether the COMSOL server port is correct.\n');
    fprintf('5. Check whether the first-time COMSOL server username/password has been configured.\n');
    fprintf('6. If the login information is corrupted or forgotten, reset it using the COMSOL login reset workflow.\n');
end
