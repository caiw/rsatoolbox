% TODO: description of this module
%
% Based on scripts written by Li Su and Isma Zulfiqar.
%
% Cai Wingfield 2016-01
function [output_Rs_L, output_Rs_R] = sliding_time_window_source(swRDMsPaths, modelRDM, userOptions)

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
        
        for t = 1:n_timePoints
            dataRDM = swRDMs(t).RDM;
            output_Rs(t) = corr(dataRDM', modelRDM.RDM', 'type', userOptions.RDMCorrelationType, 'rows', 'pairwise');
        end
        
        % TODO: This isn't very elegant
        if strcmpi(chi, 'L')
            output_Rs_L = output_Rs;
        else
            output_Rs_R = output_Rs;
        end
    end
        
end%function
