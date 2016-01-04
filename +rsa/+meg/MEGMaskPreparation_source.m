% MEGMaskPreparation_source will load vertex masks from a directory specified in 
% userOptions and will save a struct of these masks coupled with the time-windows 
% of interest also specified in userOptions.
%
% indexMasks = MEGMaskPreparation_source(userOptions)
%
%        userOptions --- The options struct.
%                userOptions.analysisName
%                        A string which is prepended to the saved files.
%                userOptions.rootPath
%                        A string describing the root path where files will be
%                        saved (inside created directories).
%                userOptions.maskPath
%                        A string describing the path to the location of the
%                        files for the definition of RoI masks.
%                userOptions.maskNames
%                        A cell array containing strings identifying the mask
%                        names. Names can be repeated so that each one is
%                        paired with an entry of userOptions.maskTimeWindows.
%                userOptions.maskTimeWindows
%                        A cell array, the same length as
%                        userOptions.maskNames containing vectors of length 2
%                        containing the start and end of the time window of
%                        interest for the corresponding mask from
%                        userOptions.maskNames.
%
%        indexMasks --- A structured array with fields:
%                indexMasks.vertices
%                        The vertex indices in the mask.
%                indexMasks.chi
%                        Whether the mask is on the right ('R') or left
%                        ('L') hemisphere
%                indexMasks.name
%                        The name of the mask (hyphens replaced by
%                        underscores.
%
% Cai Wingfield 2010-09, 2015-03
% updated by Li Su 3-2012
% update IZ 02/12, 03/12
function [indexMasks] = MEGMaskPreparation_source(userOptions)

import rsa.*
import rsa.fig.*
import rsa.meg.*
import rsa.rdm.*
import rsa.sim.*
import rsa.spm.*
import rsa.stat.*
import rsa.util.*

returnHere = pwd; % We'll come back here later

% The analysisName will be used to label the files which are eventually saved.
MasksFilename = [userOptions.analysisName, '_Masks.mat'];
DetailsFilename = [userOptions.analysisName, '_MEGMaskPreparation_source_Details.mat'];

promptOptions.functionCaller = 'MEGMaskPreparation_source';
promptOptions.defaultResponse = 'S';
promptOptions.checkFiles(1).address = fullfile(userOptions.rootPath, 'ImageData', MasksFilename);
promptOptions.checkFiles(2).address = fullfile(userOptions.rootPath, 'Details', DetailsFilename);

overwriteFlag = overwritePrompt(userOptions, promptOptions);

if overwriteFlag

	% Data
	nMasks = numel(userOptions.maskNames);
	nTimeWindows = numel(userOptions.maskTimeWindows);
	
	% Test to see if things are broken already
	if nMasks ~= nTimeWindows 
		warning('Not same number of masks and time windows. RoI(fixed and sliding time window) require same number of masks and time windows');
	end%if
	
	%% Get Data
	
	fprintf('Building spatiotemporal masks');

    for maskNumber = 1:nMasks % For each mask...

		% Figure out which mask we're looking at
		maskName = userOptions.maskNames{maskNumber};
		
		% Load the mask
		readPath = [replaceWildcards(userOptions.maskPath, '[[maskName]]', maskName) '.label'];
        label = mne_read_label_file(readPath);
		
		% Determine if it's left or right
		suffix = maskName(end-1:end);
        maskName_noDash = dashToUnderscores(maskName); % updated by Li Su 2-2012
        
		if strcmpi(suffix, 'lh')
			chi = 'L';
		elseif strcmpi(suffix, 'rh')
			chi = 'R';
		else
			error('MEGMaskPreparation:notLhOrRh', ['The mask ' maskName ' does not end in "lh" or "rh", and as such can''t allocated to either the left- or right-hand side of the source mesh!']);
		end%if:suffix
		
		% Store in a struct
		indexMasks(maskNumber).vertices   = label.vertices + 1;
        % It's very important that the value set in .chi is either
        % the single capital character 'L' or the single character 'R'.
        % This way, we can filter the struct using:
        %     indexMasks([indexMasks.chi] == 'L')
        % The [] syntax in there requires that we have single characters,
        % else horrible things will happen because strings are just arrays
        % of chars.  We have to keep things uppercase because we must use
        % == and not strcmpi().
        % TODO: Use a Chi.L/Chi.R enum instead, to make this kind of thing 
        % TODO: more foolproof.
		indexMasks(maskNumber).chi        = chi;
        indexMasks(maskNumber).name       = maskName_noDash;
		
		fprintf('.');

    end%for:maskNumber
	
	fprintf(':\n');

	%% Save relevant info

	timeStamp = datestr(now);

	fprintf(['Saving masks to ' fullfile(userOptions.rootPath, 'ImageData', MasksFilename) '\n']);
	gotoDir(userOptions.rootPath, 'ImageData');
	save(MasksFilename, 'indexMasks');
	
	fprintf(['Saving Details to ' fullfile(userOptions.rootPath, 'Details', DetailsFilename) '\n']);
	gotoDir(userOptions.rootPath, 'Details');
	save(DetailsFilename, 'timeStamp', 'userOptions');
	
else
	fprintf(['Loading previously saved masks from ' fullfile(userOptions.rootPath, 'ImageData', MasksFilename) '...\n']);
	indexMasks = directLoad(fullfile(userOptions.rootPath, 'ImageData', MasksFilename), 'indexMasks');
end%if:overwriteFlag

cd(returnHere); % And go back to where you started
