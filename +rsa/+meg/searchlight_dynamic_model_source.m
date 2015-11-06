% [glm_paths, lagSTCMetadata] = ...
%     searchlightGLM(RDMPaths, dynamic_model, dataSTCMetadata, userOptions ...
%                   ['lag', <lag_in_ms>])
%
% dynamic_model: Is a n_timepoints-long struct with field .RDM
%
% dataSTCMetadata: Contains info about timing and vertices for the data, 
%                  it's necessary for applying appropriate lags to the
%                  model.
%
% lag: The lag offset for the model time courses in ms. Must be
%      non-negative.
%
% Cai Wingfield 2015-11
function [searchlight_paths, lagSTCMetadatas] = searchlight_dynamic_model_source(RDMPaths, dynamic_model, slSTCMetadatas, userOptions, varargin)

    import rsa.*
    import rsa.meg.*
    import rsa.rdm.*
    import rsa.stat.*
    import rsa.util.*
    
    %% Parse inputs
    
    % 'lag'
    nameLag = 'lag';
    checkLag = @(x) (isnumeric(x) && (x >= 0));
    defaultLag = 0;
    
    % 'file-prefix'
    nameFilePrefix = 'fileprefix';
    checkFilePrefix = @(x) (ischar(x));
    defaultFilePrefix = '';
    
    % Set up parser
    ip = inputParser;
    ip.CaseSensitive = false;
    ip.StructExpand  = false;
    
    % Parameters
    addParameter(ip, nameLag, defaultLag, checkLag);
    addParameter(ip, nameFilePrefix, defaultFilePrefix, checkFilePrefix);
    
    % Parse the inputs
    parse(ip, varargin{:});
    
    % Get some nicer variable names
    
    % The lag in ms
    lag_in_ms = ip.Results.(nameLag);
    
    % The file name prefix
    file_name_prefix = ip.Results.(nameFilePrefix);
    
    
    %% Set up values to be returned, whether or not any work is really done.
    
    for chi = 'LR'
        
        %% Where to save results
        
        % Directory
        searchlight_mesh_dir = fullfile(userOptions.rootPath, 'Meshes');
        gotoDir(searchlight_mesh_dir);
        
        % The same paths will be used for mat files and stc files, the only
        % differences being the extension.
        
        % Paths
        searchlight_paths.(chi) = fullfile(searchlight_mesh_dir, ...
            sprintf('%ssearhclight_mesh_betas-%sh', file_name_prefix, lower(chi)));
        
        
        %% Prepare lag for the models

        % The models are assumed to have the same number of timepoints as the
        % data, and the timepoints are assumed to be corresponding.

        % The timepoints in the model timelines and the timepoints in the data
        % timelines are assumed to be corresponding at 0 lag, though the models
        % will be  offset by the specified lag.

        % Remember that STCmetadata.tstep measures lag in SECONDS, so we
        % must convert it to miliseconds.
        timestep_in_ms = slSTCMetadatas.(chi).tstep * 1000;
        % And then to timepoints.
        lag_in_timepoints = round(lag_in_ms / timestep_in_ms);


        %% Prepare lag STC metadata
    
        lagSTCMetadatas.(chi).tstep = slSTCMetadatas.(chi).tstep;
        lagSTCMetadatas.(chi).vertices = slSTCMetadatas.(chi).vertices;
        lagSTCMetadatas.(chi).tmax = slSTCMetadatas.(chi).tmax;
        % tmin is increased by...
        lagSTCMetadatas.(chi).tmin = slSTCMetadatas.(chi).tmin + ...
            ...% timesteps equal to...
            (lagSTCMetadatas.(chi).tstep * ( ...
                ...% the fixed lag we apply.
                lag_in_timepoints));
        
    end
    
    
    %% Check for overwrites
    
    promptOptions.functionCaller = 'searchlight_dynamic_model_source';
    file_i = 1;
    for chi = 'LR'
        fileNames = fieldnames(searchlight_paths);
        for file_name_i = 1:numel(fileNames)
            fileName = fileNames{file_name_i};
            promptOptions.checkFiles(file_i).address = [searchlight_paths.(fileName).(chi) '.mat'];
            file_i = file_i + 1;
        end
    end
    % Some of the file names are templates, so we don't want these 'files'
    % failing to be detected to result in rerunning in every case.
    promptOptions.quantification = 'existential';
    promptOptions.defaultResponse = 'R';
    
    overwriteFlag = overwritePrompt(userOptions, promptOptions);
    
    
    %% Begin

    if overwriteFlag
    
        [n_timepoints_models] = numel(dynamic_model);

        for chi = 'LR'

            prints('Loading RDM mesh from "%s"...', RDMPaths.(chi));

            slRDMs = directLoad(RDMPaths.(chi));

            prints('Applying lag to dynamic model timelines...');

            [n_vertices, n_timepoints_data] = size(slRDMs);
            
            n_timepoints_overlap = n_timepoints_data - lag_in_timepoints;

            prints('Working at a lag of %dms, which corresponds to %d timepoints at this resolution.', lag_in_ms, lag_in_timepoints);

            % Preallocate.
            sl_r_mesh = nan(n_vertices, n_timepoints_overlap);

            % Tell the user what's going on.
            prints('Performing dynamic searchlight in %sh hemisphere...', lower(chi));

            parfor t = 1:n_timepoints_overlap
                prints('Working on timepoint %d/%d...', t, n_timepoints_overlap);

                for v = 1:n_vertices
                    sl_r_mesh(v, t) = corr(dynamic_model, slRDMs(v, t + lag_in_timepoints).RDM');
                end%for:v
            end%for:t


            %% Save results
            prints('Saving searchlight results for %sh hemisphere to "%s"...', lower(chi), searchlight_mesh_dir);
            save('-v7.3', searchlight_paths.betas.(chi), 'sl_r_mesh');

        end%for:chi
    end%if
end%function
