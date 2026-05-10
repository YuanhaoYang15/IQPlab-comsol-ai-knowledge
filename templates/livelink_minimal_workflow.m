%% livelink_minimal_workflow.m
% Minimal MATLAB LiveLink workflow for the IQP Lab teaching example.
%
% Purpose
% -------
% This script demonstrates the recommended beginner workflow:
%
%   1. Build and validate a COMSOL model in the GUI.
%   2. Load the existing .mph model from MATLAB.
%   3. Optionally update selected model parameters.
%   4. Run an existing study.
%   5. Extract selected numerical results.
%   6. Save the results and metadata.
%   7. Optionally open the COMSOL GUI for inspection.
%
% Expected repository layout
% --------------------------
% This script is intended to be placed at:
%
%   <repo_root>/templates/livelink_minimal_workflow.m
%
% The example COMSOL model is expected at:
%
%   <repo_root>/examples/LN_ridge_waveguide_Zcut.mph
%
% Recommended usage
% -----------------
%   1. Copy this file into the repo templates/ folder.
%   2. Put LN_ridge_waveguide_Zcut.mph into the repo examples/ folder.
%   3. Start "COMSOL Multiphysics with MATLAB".
%   4. Run templates/check_livelink_connection.m.
%   5. Run this script.
%
% Notes
% -----
%   - This script assumes that MATLAB is already connected to a COMSOL server.
%   - If MATLAB was started normally, manually add the COMSOL mli path and
%     run mphstart before using this script.
%   - This script does not build the COMSOL model from scratch.
%   - The .mph model should already contain geometry, materials, physics,
%     mesh, study, solver settings, and validated result expressions.

clear; clc;

%% =======================
%  USER INPUT SECTION
% ========================

% Infer repository root from script location.
% Expected location:
%   <repo_root>/templates/livelink_minimal_workflow.m
scriptDir = fileparts(mfilename('fullpath'));
[~, scriptFolderName] = fileparts(scriptDir);

if strcmpi(scriptFolderName, 'templates')
    repoRoot = fileparts(scriptDir);
else
    repoRoot = pwd;
    msg = sprintf(['This script is not located inside a folder named "templates".\n' ...
                   'Using the current MATLAB folder as repoRoot:\n%s\n\n' ...
                   'Recommended location:\n<repo_root>/templates/livelink_minimal_workflow.m'], repoRoot);
    warning('%s', msg);
end

% Teaching model path.
modelPath = fullfile(repoRoot, 'examples', 'LN_ridge_waveguide_Zcut.mph');

% Study tag in the COMSOL model.
% Check the actual tag in COMSOL Model Builder.
studyTag = 'std1';

% Parameters to update before running the study.
%
% Keep this empty if you only want to test loading and running the example model.
% Add parameters only after confirming the exact parameter names in COMSOL.
%
% Example:
%   params.w_core = '1.2[um]';
%   params.lambda0 = '1.55[um]';
%
params = struct();

% Result expressions extracted using mphglobal.
% For an optical mode-analysis model using Electromagnetic Waves, Frequency
% Domain, ewfd.neff is a common expression for effective index.
resultExpressions = {
    'ewfd.neff'
};

% Field names used in the saved MATLAB results structure.
resultNames = {
    'neff'
};

% Output folder for generated local results.
% Generated .mat files should normally be ignored by Git.
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outputFolder = fullfile(repoRoot, 'local_outputs', ['minimal_workflow_', timestamp]);

outputFileName = 'minimal_workflow_result.mat';

% Set to true if you want to open COMSOL GUI after the run.
openGuiAfterRun = false;

% Show COMSOL progress information.
showComsolProgress = true;

%% =======================
%  BASIC INPUT CHECKS
% ========================

fprintf('Starting minimal MATLAB LiveLink workflow.\n\n');

fprintf('Repository root:\n%s\n\n', repoRoot);
fprintf('Model path:\n%s\n\n', modelPath);

if ~exist(modelPath, 'file')
    msg = sprintf(['The COMSOL teaching model was not found:\n%s\n\n' ...
                   'Please make sure the model is placed at:\n' ...
                   '<repo_root>/examples/LN_ridge_waveguide_Zcut.mph\n\n' ...
                   'Also make sure this script is placed at:\n' ...
                   '<repo_root>/templates/livelink_minimal_workflow.m'], modelPath);
    error('%s', msg);
end

if numel(resultExpressions) ~= numel(resultNames)
    error('%s', 'resultExpressions and resultNames must have the same length.');
end

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

for ii = 1:numel(resultNames)
    resultNames{ii} = matlab.lang.makeValidName(resultNames{ii});
end

%% =======================
%  IMPORT COMSOL CLASSES
% ========================

import com.comsol.model.*
import com.comsol.model.util.*

ModelUtil.showProgress(showComsolProgress);

%% =======================
%  LOAD COMSOL MODEL
% ========================

fprintf('Loading COMSOL model...\n');

model = mphload(modelPath);

fprintf('Model loaded successfully.\n\n');

%% =======================
%  OPTIONAL: SHOW MODEL TAGS
% ========================

try
    tags = mphtags;
    fprintf('Current model tags on the COMSOL server:\n');
    disp(tags);
catch ME
    errMsg = char(ME.message);
    warning('%s', sprintf('Could not query model tags using mphtags. Reason: %s', errMsg));
end

%% =======================
%  SET PARAMETERS
% ========================

paramNames = fieldnames(params);

if isempty(paramNames)
    fprintf('No parameters are being updated in this run.\n\n');
else
    fprintf('Setting model parameters...\n');

    for ii = 1:numel(paramNames)
        paramName = paramNames{ii};
        paramValue = params.(paramName);

        if ~ischar(paramValue) && ~isstring(paramValue)
            msg = sprintf(['Parameter "%s" is not a string. For physical parameters, ' ...
                           'use strings with explicit units, such as ''1.2[um]''.'], paramName);
            warning('%s', msg);
        end

        try
            model.param.set(paramName, char(paramValue));
            fprintf('  %s = %s\n', paramName, char(paramValue));
        catch ME
            errMsg = char(ME.message);
            msg = sprintf(['Failed to set parameter "%s".\n' ...
                           'Check whether this parameter exists in the COMSOL model.\n\n' ...
                           'COMSOL/MATLAB error message:\n%s'], paramName, errMsg);
            error('%s', msg);
        end
    end

    fprintf('\n');
end

%% =======================
%  RUN STUDY
% ========================

fprintf('Running study: %s\n', studyTag);

runTimer = tic;

try
    model.study(studyTag).run;
catch ME
    errMsg = char(ME.message);
    msg = sprintf(['Study run failed for study tag "%s".\n' ...
                   'Check whether the study tag exists and whether the model runs manually in COMSOL.\n\n' ...
                   'COMSOL/MATLAB error message:\n%s'], studyTag, errMsg);
    error('%s', msg);
end

runtimeSeconds = toc(runTimer);

fprintf('Study finished. Runtime: %.2f seconds.\n\n', runtimeSeconds);

%% =======================
%  EXTRACT RESULTS
% ========================

fprintf('Extracting results using mphglobal...\n');

results = struct();

for ii = 1:numel(resultExpressions)
    expr = resultExpressions{ii};
    fieldName = resultNames{ii};

    try
        value = mphglobal(model, expr);
        results.(fieldName) = value;

        fprintf('  %s -> results.%s\n', expr, fieldName);
        disp(value);

    catch ME
        errMsg = char(ME.message);
        msg = sprintf(['Failed to extract expression "%s".\n' ...
                       'Check whether the expression is valid for the solved dataset.\n' ...
                       'Reason: %s'], expr, errMsg);
        warning('%s', msg);

        results.(fieldName) = NaN;
    end
end

fprintf('\n');

%% =======================
%  SAVE RESULTS AND METADATA
% ========================

metadata = struct();

metadata.modelPath = modelPath;
metadata.studyTag = studyTag;
metadata.params = params;
metadata.resultExpressions = resultExpressions;
metadata.resultNames = resultNames;
metadata.outputFolder = outputFolder;
metadata.outputFileName = outputFileName;
metadata.runtimeSeconds = runtimeSeconds;
metadata.scriptPath = mfilename('fullpath');
metadata.time = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

outputPath = fullfile(outputFolder, outputFileName);

fprintf('Saving results and metadata to:\n%s\n\n', outputPath);

save(outputPath, 'results', 'metadata');

%% =======================
%  OPTIONAL GUI INSPECTION
% ========================

if openGuiAfterRun
    fprintf('Opening COMSOL GUI for inspection...\n');
    mphlaunch(model);
end

fprintf('Minimal MATLAB LiveLink workflow finished successfully.\n');
