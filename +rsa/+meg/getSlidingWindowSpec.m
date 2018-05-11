% [slSpec] = getSlidingWindowSpec(STCMetadatas, userOptions)
%
%
% swSpec will contain (for L and R hemispheres):
%    slSpec.L.width
%        The width of the searchlight in datapoints.
%    slSpec.L.step
%        The step of the searchlight in datapoints.
%    slSpec.L.limits
%        The limits of the searchlight window of interest in datapoints.
%    slSpec.L.windowWidth
%        The number of datapoints in the searchlight window of interest.
%    slSpec.L.windowPositions
%        A (nPositions x 2)-matrix, where each row is the left and right
%        index of a position of the sliding window, in order.
%
% Based on code by IZ 2012
% Cai Wingfield 2016-01
function swSpec = getSlidingWindowSpec(STCMetadata, userOptions)
    
    %% Common values

    % The timestep of the data in ms
    dataTimestep_data_ms = STCMetadata.tstep * 1000;

    % The time index of the first datapoint in ms
    firstPoint_data_ms = STCMetadata.tmin * 1000;

    % The number of timepoints in the data
    nTimepoints_data = (STCMetadata.tmax - STCMetadata.tmin) / STCMetadata.tstep;

    %% slSpec

    swSpec = struct();

    % The width in timepoints is...
    swSpec.width = ...
        ...% the width in ms...
        userOptions.temporalSearchlightWidth ...
        ...% divided by the timestep of the data in ms...
        / dataTimestep_data_ms;

    % The step in timepoints is...
    swSpec.step = ...
        ...% the timestep in ms...
        userOptions.temporalSearchlightTimestep ...
        ...% divided by the timestep of the data in ms...
        / dataTimestep_data_ms;

    swSpec.limits = [NaN, NaN];

    % The lower bound of the searchlight window of interest in timepoints
    % is ...
    swSpec.limits(1) = ...
        ...% the distance of the lower bound in ms from the start of the data...
        (userOptions.temporalSearchlightLimits(1) - firstPoint_data_ms) ...
        ...% divided by the timestep of the data in ms...
        / dataTimestep_data_ms;

    % The upper bound of the searchlight window of interest in timepoints
    % is...
    swSpec.limits(2) = ...
        ...% the distance of the upper bound in ms from the start of the data...
        (userOptions.temporalSearchlightLimits(2) - firstPoint_data_ms) ...
        ...% divided by the timestep of the data in ms...
        / dataTimestep_data_ms;

    % The width of the searchlight window is...
    swSpec.windowWidth = ...
        ...% the distance between the endpoints, plus one (fencepost).
        swSpec.limits(2) - swSpec.limits(1) + 1;

    % Calculate window positions

    % First window positions
    nextWindow = [swSpec.limits(1), swSpec.limits(1) + swSpec.width - 1];
    % List of window positions
    swSpec.windowPositions = nextWindow;
    % While we don't exceed the upper bound of the window...
    while nextWindow(2) + swSpec.step <= swSpec.limits(2)
        % ...move the window...
        nextWindow = nextWindow + swSpec.step;
        % ...and add it to the list of window positions.
        swSpec.windowPositions = [swSpec.windowPositions; nextWindow];
    end%while

    % Sanity check
    assert(swSpec.limits(1) >= 1 && swSpec.limits(2) <= nTimepoints_data, 'Can''t produce a valid searchlight specification for this data.');
    
end%function
