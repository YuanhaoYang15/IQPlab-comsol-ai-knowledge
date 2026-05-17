%% LiveLink Module 05B: Overlap post-processing
% This script loads saved overlap-check results and makes diagnostic plots.
% It does NOT run COMSOL.
%
% Update:
%   The overlap heatmap can be reordered by real(neff) in descending order.
%   After sorting, axis index 1 corresponds to the highest-real-neff
%   selected mode, index 2 to the next highest-real-neff mode, and so on.
%
% Input folder expected:
%   local_outputs/mode_family_overlap_check_YYYYMMDD_HHMMSS/
%       overlap_pairs.csv
%       overlap_matrix.csv
%       overlap_best_matches.csv

clear; clc; close all;

%% ===================== 1. User configuration =====================
thisFile = mfilename('fullpath');
if isempty(thisFile)
    templateDir = pwd;
else
    templateDir = fileparts(thisFile);
end
repoRoot = fileparts(templateDir);

cfgPost = struct();

% Leave empty to automatically use newest overlap output folder.
cfgPost.resultDir = '';

% Sorting option for heatmap axes.
%
% Options:
%   'neff_descend'
%       Sort previous and current modes separately by real(neff), high to low.
%
%   'mode_index'
%       Use the saved COMSOL mode index order.
%
cfgPost.heatmapSortMode = 'neff_descend';

% Heatmap tick label style.
%
% Options:
%   'rank'
%       Tick labels are 1, 2, 3, ...
%       These are sorted-mode ranks after applying cfgPost.heatmapSortMode.
%
%   'mode_index'
%       Tick labels are the original COMSOL mode indices after sorting.
%
%   'mode_index_neff'
%       Tick labels include both original COMSOL mode index and real(neff).
%
cfgPost.heatmapTickLabelMode = 'rank';

cfgPost.plotOverlapMatrix = true;
cfgPost.plotBestOverlap = true;
cfgPost.plotPairTableScatter = true;

% Save sorted overlap matrix and mode-order tables.
cfgPost.saveSortedOutputs = true;

%% ===================== 2. Locate and load results =====================
if isempty(cfgPost.resultDir)
    outputRoot = fullfile(repoRoot, 'local_outputs');
    cfgPost.resultDir = find_newest_folder( ...
        outputRoot, 'mode_family_overlap_check_*');
end

pairFile = fullfile(cfgPost.resultDir, 'overlap_pairs.csv');
bestFile = fullfile(cfgPost.resultDir, 'overlap_best_matches.csv');

if exist(pairFile, 'file') ~= 2
    error('ModeFamily:PairFileNotFound', ...
        'Cannot find overlap pair table:\n  %s', pairFile);
end

if exist(bestFile, 'file') ~= 2
    error('ModeFamily:BestFileNotFound', ...
        'Cannot find best-match table:\n  %s', bestFile);
end

pairTable = readtable(pairFile);
bestTable = readtable(bestFile);

fprintf('Loaded overlap results from:\n  %s\n', cfgPost.resultDir);
fprintf('Number of pairwise overlap rows: %d\n', height(pairTable));

%% ===================== 3. Build sorted overlap matrix =====================
[overlapMatrixSorted, prevModeTable, currModeTable] = ...
    build_sorted_overlap_matrix(pairTable, cfgPost);

if cfgPost.saveSortedOutputs
    sortedMatrixFile = fullfile(cfgPost.resultDir, ...
        'overlap_matrix_sorted.csv');
    prevOrderFile = fullfile(cfgPost.resultDir, ...
        'overlap_prev_mode_order_sorted.csv');
    currOrderFile = fullfile(cfgPost.resultDir, ...
        'overlap_curr_mode_order_sorted.csv');

    writematrix(overlapMatrixSorted, sortedMatrixFile);
    writetable(prevModeTable, prevOrderFile);
    writetable(currModeTable, currOrderFile);

    fprintf('Sorted overlap matrix saved to:\n  %s\n', sortedMatrixFile);
    fprintf('Previous-mode sorted order saved to:\n  %s\n', prevOrderFile);
    fprintf('Current-mode sorted order saved to:\n  %s\n', currOrderFile);
end

%% ===================== 4. Plots =====================
if cfgPost.plotOverlapMatrix
    figure;
    imagesc(overlapMatrixSorted);
    axis image;
    colorbar;
    clim([0, 1]);

    xlabel('Current mode, sorted by real(n_{eff})');
    ylabel('Previous mode, sorted by real(n_{eff})');
    title('Normalized field-overlap matrix');

    xticks(1:height(currModeTable));
    yticks(1:height(prevModeTable));

    xticklabels(make_axis_labels(currModeTable, cfgPost));
    yticklabels(make_axis_labels(prevModeTable, cfgPost));

    set(gca, 'TickLabelInterpreter', 'none');
end

if cfgPost.plotBestOverlap
    figure;
    plot(bestTable.prev_mode_index, bestTable.best_overlap, 'o-', ...
        'LineWidth', 1.5);
    grid on;
    xlabel('Previous COMSOL mode index');
    ylabel('Best overlap');
    title('Best overlap for each previous mode');
end

if cfgPost.plotPairTableScatter
    figure;
    scatter(pairTable.prev_neff_real, pairTable.curr_neff_real, ...
        50, pairTable.overlap, 'filled');
    grid on;
    colorbar;
    xlabel('Previous real(n_{eff})');
    ylabel('Current real(n_{eff})');
    title('Pairwise mode overlaps colored by overlap value');
end

%% ===================== Local helper functions =====================
function resultDir = find_newest_folder(outputRoot, pattern)
%FIND_NEWEST_FOLDER Find newest folder matching a pattern.

    folderList = dir(fullfile(outputRoot, pattern));
    folderList = folderList([folderList.isdir]);

    if isempty(folderList)
        error('ModeFamily:NoOutputFolder', ...
            'No output folder found in %s matching pattern %s', ...
            outputRoot, pattern);
    end

    [~, idx] = max([folderList.datenum]);
    resultDir = fullfile(folderList(idx).folder, folderList(idx).name);
end

function [Msorted, prevModeTable, currModeTable] = ...
    build_sorted_overlap_matrix(pairTable, cfgPost)
%BUILD_SORTED_OVERLAP_MATRIX Build overlap matrix from pair table and sort.

    prevModeTable = unique( ...
        pairTable(:, {'prev_mode_index', 'prev_neff_real'}), ...
        'rows', 'stable');

    currModeTable = unique( ...
        pairTable(:, {'curr_mode_index', 'curr_neff_real'}), ...
        'rows', 'stable');

    switch lower(cfgPost.heatmapSortMode)
        case 'neff_descend'
            prevModeTable = sortrows(prevModeTable, ...
                'prev_neff_real', 'descend');
            currModeTable = sortrows(currModeTable, ...
                'curr_neff_real', 'descend');

        case 'mode_index'
            prevModeTable = sortrows(prevModeTable, ...
                'prev_mode_index', 'ascend');
            currModeTable = sortrows(currModeTable, ...
                'curr_mode_index', 'ascend');

        otherwise
            error('ModeFamily:UnknownSortMode', ...
                'Unknown cfgPost.heatmapSortMode: %s', ...
                cfgPost.heatmapSortMode);
    end

    numPrev = height(prevModeTable);
    numCurr = height(currModeTable);

    Msorted = NaN(numPrev, numCurr);

    for ii = 1:numPrev
        prevMode = prevModeTable.prev_mode_index(ii);

        for jj = 1:numCurr
            currMode = currModeTable.curr_mode_index(jj);

            idx = pairTable.prev_mode_index == prevMode & ...
                  pairTable.curr_mode_index == currMode;

            if any(idx)
                Msorted(ii, jj) = pairTable.overlap(find(idx, 1));
            end
        end
    end

    prevModeTable.sorted_rank = (1:numPrev).';
    currModeTable.sorted_rank = (1:numCurr).';

    % Put sorted rank first for easier reading in the exported CSV files.
    prevModeTable = movevars(prevModeTable, ...
        'sorted_rank', 'Before', 1);
    currModeTable = movevars(currModeTable, ...
        'sorted_rank', 'Before', 1);
end

function labels = make_axis_labels(modeTable, cfgPost)
%MAKE_AXIS_LABELS Make heatmap tick labels.

    switch lower(cfgPost.heatmapTickLabelMode)
        case 'rank'
            labels = string(modeTable.sorted_rank);

        case 'mode_index'
            if ismember('prev_mode_index', modeTable.Properties.VariableNames)
                labels = string(modeTable.prev_mode_index);
            else
                labels = string(modeTable.curr_mode_index);
            end

        case 'mode_index_neff'
            if ismember('prev_mode_index', modeTable.Properties.VariableNames)
                labels = strings(height(modeTable), 1);
                for kk = 1:height(modeTable)
                    labels(kk) = sprintf('m%d, %.5f', ...
                        modeTable.prev_mode_index(kk), ...
                        modeTable.prev_neff_real(kk));
                end
            else
                labels = strings(height(modeTable), 1);
                for kk = 1:height(modeTable)
                    labels(kk) = sprintf('m%d, %.5f', ...
                        modeTable.curr_mode_index(kk), ...
                        modeTable.curr_neff_real(kk));
                end
            end

        otherwise
            error('ModeFamily:UnknownTickLabelMode', ...
                'Unknown cfgPost.heatmapTickLabelMode: %s', ...
                cfgPost.heatmapTickLabelMode);
    end
end
