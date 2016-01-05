% MEGSlidingWindowRDMs_source
%
% Cai Wingfield 2016-01

% TODO: Description of this module
function RDMsPaths = MEGSlidingWindowRDMs_source(meshPaths, STCMetadatas, userOptions)

import rsa.*
import rsa.meg.*
import rsa.util.*

%% Constants

usingMasks = ~isempty(userOptions.maskNames);
nSubjects = numel(userOptions.subjectNames);


%% File paths

RDMsDir = fullfile(userOptions.rootPath, 'RDMs');

file_i = 1;
for subject_i = 1:nSubjects
    thisSubjectName = userOptions.subjectNames{subject_i};
    for chi = 'LR'
        if usingMasks
            RDMsFile = ['swRDMs_masked_', thisSubjectName, '-' lower(chi) 'h.mat'];
        else
            RDMsFile = ['swRDMs_',        thisSubjectName, '-' lower(chi) 'h.mat'];
        end
        RDMsPaths(subject_i).(chi) = fullfile(RDMsDir, RDMsFile);
        
        % We'll check all the files to be saved to see if they have already
        % been saved.
        promptOptions.checkFiles(file_i).address = RDMsPaths(subject_i).(chi);
        file_i = file_i + 1;
    end
end

promptOptions.functionCaller = 'MEGSlidingWindowRDMs_source';
promptOptions.defaultResponse = 'S';

overwriteFlag = overwritePrompt(userOptions, promptOptions);

    
%% Apply sliding window analysis

% We assume sliding window on the left and right will be the same
swSpec = getSlidingWindowSpec(STCMetadatas.L, userOptions);
    
parfor subject_i = 1:nSubjects
    thisSubjectName = userOptions.subjectNames{subject_i};

    % Work on each hemisphere separately
    for chi = 'LR'
        
        % We'll only do the searchlight if we haven't already done so,
        % unless we're being told to overwrite.
        if exist(RDMsPaths(subject_i).(chi), 'file') && ~overwriteFlag
            prints('Sliding window analysis already performed in %sh hemisphere of subject %d. Skipping.', lower(chi), subject_i);
        else
            prints('Sliding window analysis for subject %d of %d (%s)...', subject_i, nSubjects, thisSubjectName);
            
            single_hemisphere_searchlight( ...
                swSpec, ...
                meshPaths(subject_i).(chi), ...
                RDMsPaths(subject_i).(chi), ...
                RDMsDir, ...
                userOptions);

            %% Done
            prints('Done with subject %d''s %sh side.', subject_i, lower(chi));

        end%if:overwrite
    end%for:chi
end%for:subject

cd(returnHere); % And go back to where you started

end%function



%% %%%%%%%%%%%%%%%
%% Subfunctions %%
%% %%%%%%%%%%%%%%%

% Computes and saves searchlight RDMs for a single hemisphere of a single
% subject.
function single_hemisphere_searchlight(swSpec, meshPath, RDMsPath, RDMsDir, userOptions)

    import rsa.*
    import rsa.meg.*
    import rsa.rdm.*
    import rsa.stat.*
    import rsa.util.*

    maskedMeshes = directLoad(meshPath, 'sourceMeshes');

    [nV_, nT_, nConditions, nSessions] = size(maskedMeshes);

    % The number of positions the sliding window will take.
    nWindowPositions = size(swSpec.windowPositions, 1);

    %% map the volume with the searchlight

    % Preallocate looped matrices for speed
    swRDMs(1:nWindowPositions) = struct('RDM', []);

    window_i = 0;
    for window = swSpec.windowPositions'
        % thisWindow is the indices of timepoints in each window
        thisWindow = window(1):window(2);
        window_i = window_i + 1;

        searchlightPatchData = maskedMeshes(:, thisWindow, :, :); % (vertices, time, condition, session)

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

        % Average RDMs over sessions
        searchlightRDM = zeros(size(squareform(zeros(nConditions))));
        for session = 1:nSessions
            sessionRDM = pdist(squeeze(searchlightPatchData(:,:,session))',userOptions.distance);
            searchlightRDM = searchlightRDM + sessionRDM;
        end%for:sessions
        searchlightRDM = searchlightRDM / nSessions;

        % Store results to be retured.
        swRDMs(window_i).RDM = searchlightRDM;

    end%for:window
    
    
    %% Saving RDM maps

    prints('Saving data RDMs to %s.', RDMsPath);
    gotoDir(RDMsDir);
    save('-v7.3', RDMsPath, 'swRDMs');
    
end%function


