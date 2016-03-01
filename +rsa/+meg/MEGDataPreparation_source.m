% MEGDataPreparation_source is a function designed to take MEG data and load it
% into the correct format for the rest of the toolbox to use.
%
% It is based on code by Su Li.
%
% [meshPaths, STCMetadata] = MEGDataPreparation_source(
%                                          betas,
%                                          userOptions,
%                                         ['mask', indexMask,]
%                                         ['subject_i', subject_i,]
%                                         ['chi', 'L'|'R'])
%
%       betas --- The array of beta filenames.
%               betas(condition, session).identifier is a string which referrs
%               to the filename (not including path) of the SPM beta image.
%
% REQUIRES MATLAB VERSION 7.3 OR LATER
%
% Cai Wingfield 2010-05, 2010-06, 2015-03
% updated by Li Su 2-2012
% updated by Fawad 3-12014
function [meshPaths, STCMetadatas] = MEGDataPreparation_source(betas, userOptions, varargin)

    import rsa.*
    import rsa.meg.*
    import rsa.rdm.*
    import rsa.stat.*
    import rsa.par.*
    import rsa.util.*

    %% Parse inputs

    % 'masks'
    nameMask = 'mask';
    % We don't do any validation checks on the mask
    checkMask = @(x) (true);
    defaultMask = {};

    % Set up parser
    ip = inputParser;
    ip.CaseSensitive = false;
    ip.StructExpand = false;

    % Parameters
    addParameter(ip, nameMask, defaultMask, checkMask);

    % Parse the inputs
    parse(ip, varargin{:});

    % If masks was given a default value, we're not going to do any masking.
    usingMask = ~isempty(ip.Results.mask);

    %% Begin

    % We'll return to the pwd when the function has finished
    returnHere = pwd;

    % Some conditions will have been rejected, and we'll record those in
    % this text file.
    imageDataPath = fullfile(userOptions.rootPath, 'ImageData');
    missingFilesLog = fullfile(imageDataPath, 'missingFilesLog.txt');

    % Save a separate file for each subject and each hemisphere
    file_i = 1;
    for subject_i = 1:numel(userOptions.subjectNames)
        for chi = 'LR'
           meshPaths(subject_i).(chi) = fullfile(imageDataPath, [userOptions.analysisName, '_', userOptions.subjectNames{subject_i}, '_', lower(chi), 'h_CorticalMeshes.mat']); 
           promptOptions.checkFiles(file_i).address = meshPaths(subject_i).(chi);
           file_i = file_i + 1;
        end 
    end

    % Where data will be saved
    gotoDir(imageDataPath);

    % Make this available outside.
    subjectSTCMetadatas = struct();

    promptOptions.functionCaller = 'MEGDataPreparation_source';
    promptOptions.defaultResponse = 'S';

    % We check for any existing files before the loop.
    % If the user says "skip", then we skip any files which exist and continue
    % to load others.
    overwriteFlag = overwritePrompt(userOptions, promptOptions);

    %% Loop over all subjects under consideration
    parfor subject_i = 1:numel(userOptions.subjectNames);

        %% Loop over all hemispheres under consideration
        for chi = 'LR'
            subjectSTCMetadatas(subject_i).(chi) = prepare_single_hemisphere_data(subject_i, chi, overwriteFlag, usingMask, ip.Results.mask, meshPaths, imageDataPath, missingFilesLog, betas, userOptions);
        end%for:chi
    end%for:subjects

    %% Prepare outputs

    % These should all be the same, so we can just take the first on, which
    % will contain both hemispheres.
    STCMetadatas = subjectSTCMetadatas(1);

    cd(returnHere); % Go back

end%function


%%%%%%%%%%%%%%%%%%
%% Subfunctions %%
%%%%%%%%%%%%%%%%%%

% Prepares the data of a single subject, and a single hemisphere.
%
% Cai Wingfield 2015-03, based on Su Li's code
function STCMetadata = prepare_single_hemisphere_data(subject_i, chi, overwriteFlag, usingMask, masks, meshPaths, imageDataPath, missingFilesLog, betas, userOptions)

    import rsa.*
    import rsa.meg.*
    import rsa.rdm.*
    import rsa.stat.*
    import rsa.par.*
    import rsa.util.*
    
    [nSessions, nConditions] = size(betas);
    
    % Figure out the subject's name
    thisSubjectName = userOptions.subjectNames{subject_i};

    % We only load the data if we haven't already done so, unless we've
    % been told to overwrite.
    if exist(meshPaths(subject_i).(chi), 'file') && ~overwriteFlag
        
        % We still need the metadata file, so we'll read the first
        % condition of the first session, and build the metadata based on
        % that.
        readPath = replaceWildcards(userOptions.betaPath, '[[betaIdentifier]]', betas(1, 1).identifier, '[[subjectName]]', thisSubjectName, '[[LR]]', lower(chi));
        prints('Subject %d (%s) %sh data already prepared. Loading just enough to get metadata [%s].', subject_i, thisSubjectName, chi, readPath);
        STCMetadata = convertToSTCMetadata( ...
            mne_read_stc_file1(readPath), ...
            usingMask, masks([masks.chi] == chi), userOptions);
    else
        prints('Loading on subject %d (%s), %s side', subject_i, thisSubjectName, chi);

        % Loop over sessions and conditions
        nan_list = [];
        for session_i = 1:nSessions
            for condition_i = 1:nConditions

                % Then read the brain data (for this session, condition)
                readPath = replaceWildcards(userOptions.betaPath, '[[betaIdentifier]]', betas(session_i, condition_i).identifier, '[[subjectName]]', thisSubjectName, '[[LR]]', lower(chi));

                dataReadSuccessfully = false;
                try
                    MEGData_stc = mne_read_stc_file1(readPath);
                    dataReadSuccessfully = true;
                catch ex
                    % when a trial is rejected due to artifact, this item
                    % is replaced by NaNs. Li Su 3-2012
                    prints('Failed to read data for condition %d from %s. Using NaNs instead.', condition_i, readPath);
                    % Log the missing file
                    dlmwrite(missingFilesLog, str2mat(replaceWildcards(betas(session_i, condition_i).identifier, '[[subjectName]]', thisSubjectName)), 'delimiter', '', '-append');
                end

                if dataReadSuccessfully
        
                    % If the vertices in the data aren't sorted for some
                    % reason, we sort them and the data now.
                    if ~issorted(MEGData_stc.vertices)
                        [MEGData_stc.vertices, sortingVector] = sort(MEGData_stc.vertices);
                        MEGData_stc.data = MEGData_stc.data(sortingVector, :);
                    end

                    % Produce downsampled metadata struct from raw struct
                    STCMetadata = convertToSTCMetadata(MEGData_stc, usingMask, masks([masks.chi] == chi), userOptions);

                    %% Every time data is read
                    
                    % We aren't guaranteed that the vertices in the data
                    % are consecutively numbered, so we have to find the
                    % indices of the mask vertices
                    maskVertices_logical = ismember(MEGData_stc.vertices, STCMetadata.vertices);

                    % Store the data in the mesh, masking and downsampling
                    % as we go.
                    sourceMeshes(:, :, condition_i, session_i) = ...
                        MEGData_stc.data( ...
                            ...% Downsample and mask space
                            maskVertices_logical, ...
                            ...% Downsample time by subsampling the timepoints
                            1:userOptions.temporalDownsampleRate:end); % (vertices, time, condition, session)
                else
                    
                    % Remember the nan at this c_i and s_i!
                    nan_list = [nan_list; [condition_i, session_i]];
                    
                end
            end%for:condition
        end%for:session
        
        n_vertices = size(sourceMeshes, 1);
        n_timepoints = size(sourceMeshes, 2);
        
        
        % Make sure it actually has NaNs in if there was an error for this
        % condition
        for cs_pair = nan_list'
           c_i = cs_pair(1);
           s_i = cs_pair(2);
           
           sourceMeshes(:, :, c_i, s_i) = NaN(n_vertices, n_timepoints);
        end
        
        % Save it!

        gotoDir(imageDataPath);
        parsave_local('-v7.3', meshPaths(subject_i).(chi), sourceMeshes);

        prints('Subject %s''s %s-hemisphere data read successfully!', thisSubjectName, chi);
        dlmwrite(missingFilesLog, '', '-append');
    end%if: proceed with load
end%function

% Converts raw STC metadata into a downsampled one
%
% Cai Wingfield 2015-03, based on Su Li's code
function STCMetadata = convertToSTCMetadata(MEGData_stc, usingMask, mask, userOptions)

    import rsa.*
    import rsa.meg.*
    import rsa.rdm.*
    import rsa.stat.*
    import rsa.par.*
    import rsa.util.*
    
    % Raw data sizes, before downsampling

    % The number of vertices and timepoints in the raw data.
    [nVertices_raw, nTimepoints_raw] = size(MEGData_stc.data);
    
    % The time index of the first datapoint, in seconds.
    firstDatapointTime_raw = MEGData_stc.tmin;
    
    % The interval between successive datapoints in  the raw data,
    % in seconds.
    timeStep_raw = MEGData_stc.tstep;
    
    %% Downsampling constants

    % Sanity checks for downsampling
    if nVertices_raw < userOptions.targetResolution
        error('MEGDataPreparation_source:InsufficientSpatialResolution', 'There aren''t enough vertices in the raw data to meet the target resolution.');
    end

    % Now the actual downsampling targets can be calculated

    % We will be downsampling in space and time, so
    % we calculate some useful things here.
    
    % The number of timepoints in the downsampled data
    nTimepoints_downsampled = numel(1:userOptions.temporalDownsampleRate:nTimepoints_raw);
    timeStep_downsampled = timeStep_raw * userOptions.temporalDownsampleRate;

    % Time time index of the first datapoint doesn't change in the 
    % downsampled data
    firstDatapointTime_downsampled = firstDatapointTime_raw;

    % The time index of the last datapoint may change in the downsampled 
    % data, so should be recalculated
    lastDatapointTime_downsampled = firstDatapointTime_downsampled + (nTimepoints_downsampled * timeStep_downsampled);

    % This metadata struct will be useful for
    % writing appropriate files in future. This new
    % metadata should reflect the resolution and
    % specifices of the data which
    % MEGDataPreparation_source produces.
    STCMetadata.tmin  = firstDatapointTime_downsampled;
    STCMetadata.tmax  = lastDatapointTime_downsampled;
    STCMetadata.tstep = timeStep_downsampled;

    %% Apply mask

    % If we're using masks, we only want to include
    % those vertices which are inside the mask.
    if usingMask
        % Make sure we're using the vertices of the
        % mask on the correct hemisphere.
        % TODO: not actually downsampling here?!?! Need to intersect with
        % TODO: 1:targetResolution
        STCMetadata.vertices = uint32(sort(mask.vertices(:)));
    else
        % If we're not using a mask, we still need to
        % downsample the mesh to the target resolution.
        % Luckily, downsampling is just a matter of
        % taking low-numbered vertices, due to the way
        % they are laid out.
        STCMetadata.vertices = uint32((1:userOptions.targetResolution)');
    end%if
end%function

% For some unknown reason this is necessary if using parfor
function parsave_local(version, path, sourceMeshes) %#ok<INUSD> It says sourceMeshes is unused, but actually it's saved
    save(version, path, 'sourceMeshes');
end%function
