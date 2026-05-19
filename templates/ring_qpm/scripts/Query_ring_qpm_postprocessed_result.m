clear; close all; clc;

%% Query_ring_qpm_postprocessed_result.m
% Query a reusable Ring QPM jump-break post-processing output by geometry and
% mode-selection metadata.
%
% Run Batch_postprocess_ring_qpm_jump_breaks.m first. Then edit the user query
% block below. The script finds matching rows in batch_summary.csv, writes a
% compact query summary, and copies the matched case summary and figures into a
% query-specific folder.

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));

%% User query block

query = struct();
query.Radius = 50;
query.w_ln = 1.2;
query.t_ln = 0.6;
query.t_ridge = 0.4;
query.theta_deg = 60;
query.IR_pol = 'TM';
query.IR_order = 1;
query.SH_pol = 'TM';
query.SH_order = 1;
query.lambda0_IR = 1.55;

tol = 1e-3;

% Leave empty to use the newest postprocessed_jump_break_* folder under
% templates/ring_qpm/results.
post_root = '';

%% Locate post-processing output

if isempty(post_root)
    post_root = find_newest_folder(fullfile(project_root, 'results'), ...
        'postprocessed_jump_break_*');
end

summary_file = fullfile(post_root, 'batch_summary.csv');
jump_file = fullfile(post_root, 'jump_warnings.csv');
if exist(summary_file, 'file') ~= 2
    error('Cannot find batch_summary.csv in:\n%s', post_root);
end

T = readtable(summary_file);
if exist(jump_file, 'file') == 2
    J = readtable(jump_file);
else
    J = table();
end

idx = abs(T.Radius - query.Radius) <= tol & ...
    abs(T.w_ln - query.w_ln) <= tol & ...
    abs(T.t_ln - query.t_ln) <= tol & ...
    abs(T.t_ridge - query.t_ridge) <= tol & ...
    abs(T.theta_deg - query.theta_deg) <= tol & ...
    strcmpi(string(T.IR_pol), string(query.IR_pol)) & ...
    T.IR_order == query.IR_order & ...
    strcmpi(string(T.SH_pol), string(query.SH_pol)) & ...
    T.SH_order == query.SH_order & ...
    abs(T.lambda0_IR - query.lambda0_IR) <= tol;

matches = T(idx,:);
if isempty(matches)
    error('No matching postprocessed result found.');
elseif height(matches) > 1
    fprintf('Multiple matches found; using the first one.\n');
end

match = matches(1,:);
case_dir = string(match.case_dir);

query_dir = fullfile(post_root, 'queries', make_query_tag(query));
if ~exist(query_dir, 'dir')
    mkdir(query_dir);
end

copy_if_present(fullfile(case_dir, 'case_summary.txt'), fullfile(query_dir, 'case_summary.txt'));
copy_matching_files(case_dir, query_dir, '*.png');
copy_matching_files(case_dir, query_dir, '*.fig');

if ~isempty(J) && any(strcmp('case_dir', J.Properties.VariableNames))
    jump_idx = strcmp(string(J.case_dir), case_dir);
    jump_match = J(jump_idx,:);
else
    jump_match = table();
end
writetable(jump_match, fullfile(query_dir, 'jump_warnings_for_query.csv'));
writetable(match, fullfile(query_dir, 'matched_batch_summary.csv'));
write_query_summary(fullfile(query_dir, 'query_summary.txt'), query, match, jump_match);

fprintf('Matched source file:\n%s\n', string(match.source_file));
fprintf('Matched case dir:\n%s\n', case_dir);
fprintf('Query output dir:\n%s\n', query_dir);
fprintf('Jump warning count: %d\n', height(jump_match));

%% Local functions

function result_dir = find_newest_folder(root, pattern)
folders = dir(fullfile(root, pattern));
folders = folders([folders.isdir]);
if isempty(folders)
    error('No folder matching %s under %s', pattern, root);
end
[~, idx] = max([folders.datenum]);
result_dir = fullfile(folders(idx).folder, folders(idx).name);
end

function copy_matching_files(source_dir, target_dir, pattern)
files = dir(fullfile(source_dir, pattern));
for ii = 1:numel(files)
    copyfile(fullfile(files(ii).folder, files(ii).name), ...
        fullfile(target_dir, files(ii).name));
end
end

function copy_if_present(source_file, target_file)
if exist(source_file, 'file') == 2
    copyfile(source_file, target_file);
end
end

function tag = make_query_tag(q)
tag = sprintf('R%s_w%s_tln%s_tr%s_th%s_IR%s%d_SH%s%d_lam%s', ...
    num_tag(q.Radius), num_tag(q.w_ln), num_tag(q.t_ln), ...
    num_tag(q.t_ridge), num_tag(q.theta_deg), ...
    upper(q.IR_pol), q.IR_order-1, upper(q.SH_pol), q.SH_order-1, ...
    num_tag(q.lambda0_IR*1e3));
end

function s = num_tag(x)
s = sprintf('%.6g', x);
s = strrep(s, '.', 'p');
s = strrep(s, '-', 'm');
end

function write_query_summary(path, query, match, jump_match)
fid = fopen(path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Ring QPM postprocessed-result query\n\n');
fprintf(fid, 'Query geometry and mode selection:\n');
fprintf(fid, '  Radius: %.6g um\n', query.Radius);
fprintf(fid, '  w_ln: %.6g um\n', query.w_ln);
fprintf(fid, '  t_ln: %.6g um\n', query.t_ln);
fprintf(fid, '  t_ridge: %.6g um\n', query.t_ridge);
fprintf(fid, '  theta_deg: %.6g deg\n', query.theta_deg);
fprintf(fid, '  IR mode: %s%d\n', upper(query.IR_pol), query.IR_order - 1);
fprintf(fid, '  SH mode: %s%d\n', upper(query.SH_pol), query.SH_order - 1);
fprintf(fid, '  lambda0_IR: %.6g um\n\n', query.lambda0_IR);
fprintf(fid, 'Matched source file: %s\n', string(match.source_file));
fprintf(fid, 'Matched case dir: %s\n', string(match.case_dir));
fprintf(fid, 'IR jumps: %d\n', match.IR_jump_count);
fprintf(fid, 'SH jumps: %d\n', match.SH_jump_count);
fprintf(fid, 'IR segments: %d\n', match.IR_segment_count);
fprintf(fid, 'SH segments: %d\n', match.SH_segment_count);
fprintf(fid, 'Matched jump warning rows: %d\n', height(jump_match));
end
