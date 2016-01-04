% TODO: description of this module
%
% Based on scripts written by Li Su and Isma Zulfiqar.
%
% Cai Wingfield 2016-01
function output_Rs = sliding_time_window_source(swRDMsPaths, modelRDM, userOptions)

    import rsa.*
    import rsa.meg.*
    import rsa.rdm.*
    import rsa.stat.*
    import rsa.util.*
    
    for chi = 'LR'
        RDM_path_this_hemi = swRDMsPaths.(chi);
        swRDMs = directLoad(RDM_path_this_hemi);
        
        n_timePoints = numel(swRDMs);
        
        % preallocate
        output_Rs = nan(1,n_timePoints);
        
        parfor t = 1:n_timePoints
            dataRDM = swRDMs(t).RDM;
            output_Rs(t) = corr(dataRDM, modelRDM.RDM, 'type', userOptions.RDMCorrelationType, 'rows', 'pairwise');
        end
    end
        
end%function
