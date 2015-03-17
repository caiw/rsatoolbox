% [smm_rs, searchlightRDMs] = searchlightMapping_MEG_source(singleSubjectMesh, indexMask, modelRDM, partialModelRDMs, adjacencyMatrix, slSpec, userOptions)
%
% Based on Li Su's script
% CW 2010-05, 2015-03
% updated by Li Su 3-2012

function [smm_rs, searchlightRDMs] = searchlightMapping_MEG_source(singleSubjectMesh, indexMask, modelRDM, partialModelRDMs, adjacencyMatrix, slSpec, userOptions)

import rsa.*
import rsa.fig.*
import rsa.meg.*
import rsa.rdm.*
import rsa.sim.*
import rsa.spm.*
import rsa.stat.*
import rsa.util.*

%% Get parameters

modelRDM_utv = squeeze(unwrapRDMs(vectorizeRDMs(modelRDM)));

if userOptions.partial_correlation
    % TODO: should be transposed?
    control_for_modelRDMs = unwrapRDMs(vectoriseRDMs(partialModelRDMs));
end

[nVertices, nTimePoints_data, nConditions, nSessions] = size(singleSubjectMesh);

% The number of positions the sliding window will take.
nWindowPositions = size(slSpec.windowPositions, 2);

%% similarity-graph-map the volume with the searchlight

% Preallocate looped matrices for speed
smm_rs = zeros([nVertices, nWindowPositions]);
searchlightRDMs(numel(indexMask.vertices), nWindowPositions) = struct();

nVerticesSearched = 0;

% Search the vertices
for v = indexMask.vertices
    
    % Determine which vertexes are within the radius of the currently-picked vertex
    verticesCurrentlyWithinRadius = [v, adjacencyMatrix(v,:)];
    
    % Restrict to verticies inside mask.
    % This also removes any nans.
    % All searchlight run as masks, including full-brain searchlights (update IZ 03/12)
    verticesCurrentlyWithinRadius = intersect(verticesCurrentlyWithinRadius, indexMask.vertices);
    
    % Search through time
    window_i = 0;
    for window = slSpec.windowPositions'
        % thisWindow is the indices of timepoints in each window
        thisWindow = window(1):window(2);
        window_i = window_i + 1;
        
        searchlightPatchData = singleSubjectMesh(verticesCurrentlyWithinRadius, thisWindow, :, :); % (vertices, time, condition, session)
        
        % Average across sessions
        
        if not(userOptions.regularized)
            
            % Median over the time window
            switch lower(userOptions.searchlightPatterns)
                case 'spatial'
                    % Spatial patterns: median over time window
                    searchlightPatchData = median(searchlightPatchData, 2); % (vertices, 1, conditions, sessions)
                    searchlightPatchData = squeeze(searchlightPatchData); % (vertices, conditions, sessions);
                case 'temporal'
                    % Temporal patterns: mean over vertices within searchlight
                    searchlightPatchData = mean(searchlightPatchData, 1); % (1, timePoints, conditions, sessions)
                    searchlightPatchData = squeeze(searchlightPatchData); % (timePionts, conditions, sessions)
                case 'spatiotemporal'
                    % Spatiotemporal patterns: all the data concatenated
                    searchlightPatchData = reshape(searchlightPatchData, [], size(searchlightPatchData, 3), size(searchlightPatchData, 4)); % (dataPoints, conditions, sessions)
            end%switch:userOptions.sensorSearchlightPatterns
            
            % Preallocate
            searchlightRDM = zeros(nConditions);
            
            for session = 1:nSessions
                searchlightRDM = searchlightRDM + squareform(pdist(squeeze(searchlightPatchData(:,:,session))',userOptions.distance));
            end%for:sessions
            
        else
            % data regularization based on algorithm by Diedrichson et al 2011 - updated 12-12 IZ
            tempMesh = reshape(searchlightPatchData, [], size(searchlightPatchData, 3), size(searchlightPatchData, 4));
            searchlightPatchData = zeros(size(tempMesh, 1), size(tempMesh, 2) * size(tempMesh, 3)); % (data, conditions, sessions)
            
            % combining session-wise trials
            kk = 1;
            for j = 1:size(tempMesh,2)
                for i = 1:nSessions
                    searchlightPatchData(:, kk) = (tempMesh(:, j, i));
                    kk = kk + 1;
                end
            end
            
            r_matrix = g_matrix(zscore(squeeze(searchlightPatchData(:,:)))', nConditions, size(currentTimeWindow,2));
            searchlightRDM = searchlightRDM + (1 - r_matrix);
            
            if isnan(searchlightRDM) % sessions and conditions should be optimal
                error('Cannot calculate covariance matrix. Try reducing number of conditions');
            end
        end
        
        searchlightRDM = searchlightRDM / nSessions;
        
        searchlightRDM = vectorizeRDM(searchlightRDM);
        
        % Locally store the full brain's worth of indexed RDMs.
        searchlightRDMs(v, window_i).RDM = searchlightRDM;
        
        % TODO: Refactor this into general method so it can be used
        % TODO: anywhere
        if strcmpi(userOptions.RDMCorrelationType, 'Kendall_taua')
            rs = rankCorr_Kendall_taua(searchlightRDM', modelRDM_utv');
        elseif userOptions.partial_correlation
            % TODO: Consider partialcorr with Kendall's tau
            rs = partialcorr(searchlightRDM', modelRDM_utv', control_for_modelRDMs', 'type', userOptions.RDMCorrelationType, 'rows','pairwise');
        else
            rs = corr(searchlightRDM', modelRDM_utv', 'type', userOptions.RDMCorrelationType, 'rows', 'pairwise');
        end
        
        smm_rs(v, window_i) = rs;
        
    end%for:window
    
    % Indicate progress every once in a while...
    nVerticesSearched = nVerticesSearched + 1;
    if mod(nVerticesSearched, 500) == 0, prints('%d vertices searched', nVerticesSearched); end%if
    
end%for:v

if userOptions.fisher
    smm_rs = fisherTransform(smm_rs);
end%if

end%function
