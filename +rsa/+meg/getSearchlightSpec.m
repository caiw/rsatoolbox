% [slSpecs, slSTCMetadatas] = getSearchlightSpec(STCMetadatas, userOptions)
%
% Given STCMetadatas providing a picture of the data to be searched, and
% given the specification of the searchlight in miliseconds as set in
% userOptions, this function returns a struct which describes the
% specifications of the searchlight in datapoints.  Also returned will be
% slSTCMetadatas, which is a new STC metadata struct, formatted for the
% searchlight specifications.
%
% STCMetadatas must contain at least (for L and R hemispheres):
%     STCMetadatas.L.tstep
%         The timestep of the data in seconds.
%     STCMetadatas.L.tmin
%         The time of the first datapoint in seconds.
%     STCMetadatas.L.tmax
%         The time of the last datapoint in seconds.
%
% slSTCMetadatas will contain (for L and R hemispheres):
%     slSTCMetadata.L.tstep
%         The timestep of the searchlight in seconds.
%     slSTCMetadata.L.tmin
%         The time of the first searchlight datapoint in seconds.
%     slSTCMetadata.L.tmax
%         The time of the last searchlight datapoint in seconds.
% ... and any other fields which STCMetadata had will also be copied.
%
% slSpecs will contain (for L and R hemispheres):
%    slSpecs.L.width
%        The width of the searchlight in datapoints.
%    slSpecs.L.step
%        The step of the searchlight in datapoints.
%    slSpecs.L.limits
%        The limits of the searchlight window of interest in datapoints.
%    slSpecs.L.windowWidth
%        The number of datapoints in the searchlight window of interest.
%    slSpecs.L.windowPositions
%        A (nPositions x 2)-matrix, where each row is the left and right
%        index of a position of the sliding window, in order.
%
% Based on code by IZ 2012
% Cai Wingfield 2015-03, 2015-04
function [slSpecs, slSTCMetadatas] = getSearchlightSpec(STCMetadatas, userOptions)

    % TODO: this should also accept & return sensor-space data in place of
    % TODO: sensor-space data
    
    for chi = 'LR'
    
        %% Common values

        % The timestep of the data in ms
        dataTimestep_data_ms = STCMetadatas.(chi).tstep * 1000;

        % The time index of the first datapoint in ms
        firstPoint_data_ms = STCMetadatas.(chi).tmin * 1000;

        % The number of timepoints in the data
        nTimepoints_data = (STCMetadatas.(chi).tmax - STCMetadatas.(chi).tmin) / STCMetadatas.(chi).tstep;

        %% slSpec

        slSpecs.(chi) = struct();

        % The width in timepoints is...
        slSpecs.(chi).width = ...
            ...% the width in ms...
            userOptions.temporalSearchlightWidth ...
            ...% divided by the timestep of the data in ms...
            / dataTimestep_data_ms;

        % The step in timepoints is...
        slSpecs.(chi).step = ...
            ...% the timestep in ms...
            userOptions.temporalSearchlightTimestep ...
            ...% divided by the timestep of the data in ms...
            / dataTimestep_data_ms;

        slSpecs.(chi).limits = [NaN, NaN];

        % The lower bound of the searchlight window of interest in timepoints
        % is ...
        slSpecs.(chi).limits(1) = ...
            ...% the distance of the lower bound in ms from the start of the data...
            (userOptions.temporalSearchlightLimits(1) - firstPoint_data_ms) ...
            ...% divided by the timestep of the data in ms...
            / dataTimestep_data_ms;

        % The upper bound of the searchlight window of interest in timepoints
        % is...
        slSpecs.(chi).limits(2) = ...
            ...% the distance of the upper bound in ms from the start of the data...
            (userOptions.temporalSearchlightLimits(2) - firstPoint_data_ms) ...
            ...% divided by the timestep of the data in ms...
            / dataTimestep_data_ms;

        % The width of the searchlight window is...
        slSpecs.(chi).windowWidth = ...
            ...% the distance between the endpoints, plus one (fencepost).
            slSpecs.(chi).limits(2) - slSpecs.(chi).limits(1) + 1;

        % Calculate window positions

        % First window positions
        nextWindow = [slSpecs.(chi).limits(1), slSpecs.(chi).limits(1) + slSpecs.(chi).width - 1];
        % List of window positions
        slSpecs.(chi).windowPositions = nextWindow;
        % While we don't exceed the upper bound of the window...
        while nextWindow(2) + slSpecs.(chi).step <= slSpecs.(chi).limits(2)
            % ...move the window...
            nextWindow = nextWindow + slSpecs.(chi).step;
            % ...and add it to the list of window positions.
            slSpecs.(chi).windowPositions = [slSpecs.(chi).windowPositions; nextWindow];
        end%while

        % Sanity check
        if slSpecs.(chi).limits(1) < 1 || slSpecs.(chi).limits(2) > nTimepoints_data
            error('getSearchlightSpec:InvalidSpec', 'Can''t produce a valid searchlight specification for this data.');
        end

        %% slSTCMetadata

        % Copy all existing fields from the input metadata struct
        slSTCMetadatas.(chi) = STCMetadatas.(chi);

        % Need to convert from miliseconds as defined in the userOptions struct
        % to the seconds required by the STC metadata format.
        slSTCMetadatas.(chi).tstep = userOptions.temporalSearchlightTimestep  / 1000;
        slSTCMetadatas.(chi).tmin  = userOptions.temporalSearchlightLimits(1) / 1000;
        slSTCMetadatas.(chi).tmax  = userOptions.temporalSearchlightLimits(2) / 1000;
    
    end%for:chi
end%function
