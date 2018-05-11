% overwritePrompt is a function which prompts the user, either at the command
% line or (when it's implemented) via a GUI dialogue box.  The user will be
% notified if they are liable to overwrite pre-existing data and will be given
% the options to go ahead, to quit, or to skip this section.  This also allows
% an interrupted analysis to be resumed.
%
% overwriteFlag = overwritePrompt(userOptions, promptOptions)
%
%        userOptions --- The options struct.
%                userOptions.analysisName
%                        A string which is prepended to the saved files.
%                userOptions.rootPath
%                        A string describing the root path where files will be
%                        saved (inside created directories).
%                userOptions.forcePromptReply --- USE WITH CAUTION!
%                        A way to automatically reply in a certain way to the
%                        overwrite prompt. Defaults to nothing. Only works with
%                        text-based prompt so far...
%                userOptions.dialogueBox
%                        A boolean value. If true, the text-based prompt is
%                        replaced by a graphical box. Defaults to false.
%
%        promptOptions --- Further options, including:
%                promptOptions.quantification
%                        A string which describes how the presence or
%                        absence of specified files should be checked.
%                        Available options:
%                        'existential' --- Prompt if any of the listed
%                                          files already exist.
%                        'universal'   --- Prompt if all of the listed
%                                          files aready exist.
%                promptOptions.checkFiles
%                        A list of files to check.
%                promptOptions.defaultResponse
%                        How to interpret just an enter?
%                promptOptions.functionCaller
%                        The name of the function which is calling this.
%                promptOptions.quiet
%                        If true, prints only necessary things.
%  
% Cai Wingfield 2009-11, 2010-06, 2015-05
% Updated by Li Su 02-2012
%__________________________________________________________________________
% Copyright (C) 2010 Medical Research Council
function overwriteFlag = overwritePrompt(userOptions, promptOptions)

    import rsa.*
    import rsa.util.*

    %% Set defaults and check options struct
    if ~isfield(userOptions, 'analysisName'), error('overwritePrompt:NoAnalysisName', 'analysisName must be set. See help'); end%if
    if ~isfield(userOptions, 'rootPath'), error('overwritePrompt:NoRootPath', 'rootPath must be set. See help'); end%if
    userOptions = setIfUnset(userOptions, 'dialogueBox', false);

    promptOptions = setIfUnset(promptOptions, 'checkFiles', []);
    promptOptions = setIfUnset(promptOptions, 'quantification', 'existential');

    % A flag desribing whether or not every listed file already exists.
    allFilesExist = true;
    % A flag descibing wheter or not any listed file already exists.
    anyFilesExist = false;
    % A flag describing whether any data may be (over)written.
    overwriteFlag = false;

    %% Check which files exist

    for file_i = 1:numel(promptOptions.checkFiles)
        if exist(promptOptions.checkFiles(file_i).address, 'file')
            anyFilesExist = true;
        else
            allFilesExist = false;
        end
    end%for

    %% Check if prompt is needed
    if strcmpi(promptOptions.quantification, 'universal') && allFilesExist
        promptNeeded = true;
    elseif strcmpi(promptOptions.quantification, 'existential') && anyFilesExist
        promptNeeded = true;
    else
        promptNeeded = false;
    end

    %% Do prompt (if needed)

    % If there are files which will eventually be saved but which already 
    % exist, prompt the user to ask what to do.
    if promptNeeded

        % Set some defaults
        if ~isfield(promptOptions, 'defaultResponse'), promptOptions.defaultResponse = 'S'; end
        if ~isfield(promptOptions, 'functionCaller'), promptOptions.functionCaller = '[last function called]'; end

        %% Get their response to the question

        if userOptions.dialogueBox
            %% Graphical version in here!

            options.Interpreter = 'tex'; % Why would we ever NOT want TeX?!

            % For the graphic version, the defults are a word, whereas for the textual version they're a single character
            % We have to convert them from letters to words, and then back again later.
            if strcmpi(promptOptions.defaultResponse, 'A'), options.Default = 'Abort'; ...
            elseif strcmpi(promptOptions.defaultResponse, 'S'), options.Default = 'Skip'; ...
            elseif strcmpi(mptOptions.defaultResponse, 'R'), options.Default = 'Rerun'; ...
            else options.Default = 'Skip';
            end % Just another quick default-set if there's a mistake somewhere

            % This will produce a pop-up dialogue box with a descriptive message in and wait for the user's response, storing it in "reply"
            dialogueMessage = [ ...
                'The function "' promptOptions.functionCaller '" has already been run under the analysisName "' userOptions.analysisName '", and rerunning it may result in data loss. What would you like to do?']; % This message will be wrapped appropriately to fit in the dialogue box
            reply = questdlg(dialogueMessage,'Warning: data may be overwritten!', 'Abort', 'Skip', 'Rerun', options);
            clear options;

            % Now converting the words back into letters
            if strcmpi(reply, 'Abort'), reply = 'A'; ...
            elseif strcmpi(reply, 'Skip'), reply = 'S'; ...
            elseif strcmpi(reply, 'Rerun'), reply = 'R';
            end

        else

            %% Textual version in here!

            % These are just for displaying the default value NICELY :P
            aFlag = ''; aSpace = '';
            sFlag = ''; sSpace = '';
            rFlag = ''; rSpace = '';
            if strcmpi(promptOptions.defaultResponse, 'A')
                aFlag = '*';
                aSpace = ' ';
            elseif strcmpi(promptOptions.defaultResponse, 'S')
                sFlag = '*';
                sSpace = ' ';
            elseif strcmpi(promptOptions.defaultResponse, 'R')
                rFlag = '*';
                rSpace = ' ';
            end%if

            % Here we present to the user a textual message in the command window as the prompt
            % Response again stored in "reply"

            promptString = [ ...
                    '---------\n' ...
                    '  WARNING: You have already run "' promptOptions.functionCaller '"\n' ...
                    '           under "' userOptions.analysisName '" and data has been\n' ...
                    '           saved.  Would you like to overwrite this data?\n' ...
                    '            ' aFlag '[A]bort, ' sFlag '[S]kip, ' rFlag '[R]erun >> '];
            quietPromptString = sprintf('Rerun %s?', promptOptions.functionCaller);

            % Check if there's a forced reply, and that it's not '' (which
            % means no forced reply).
            if isfield(userOptions, 'forcePromptReply') && ~isempty(userOptions.forcePromptReply) % The prompt is forced according to preferences...
                reply = userOptions.forcePromptReply;
                if promptOptions.quiet
                    fprintf([quietPromptString, ' [', reply, ']\n']);
                else
                    fprintf([promptString '[forced reply: "' reply '"]\n']);
                end
            else % Get the user to answer the prompt...
                if promptOptions.quiet
                    reply = input(quietPromptString, 's');
                else
                    reply = input(promptString, 's');
                end
            end%if

        end%if

        %% Now deal with the user's response to the prompt

        if isempty(reply)
            % If they jump through, go with the default
            if ~promptOptions.quiet
                fprintf('\n');
                prints('You didn''t enter anything! Default option selected: [%s]', promptOptions.defaultResponse);
            end
            reply = promptOptions.defaultResponse;

        elseif ~strcmpi(reply, 'A') && ~strcmpi(reply, 'S') && ~strcmpi(reply, 'R')
            % If they enter something which doesn't make sense, go with the default
            if ~promptOptions.quiet
                fprintf('\n');
                prints('"%s" is for... Nothing! You didn''t input a valid', reply);
                prints('option. Default option selected: [%s]', promptOptions.defaultResponse);
            end
            reply = promptOptions.defaultResponse;
        end%if


        if strcmpi(reply, 'A')
            % Abort: (no graphical version for this yet)
            errors('"A" is for "Abort": Data not overwritten!');

            overwriteFlag = false;

        elseif strcmpi(reply, 'S')
            % Skip:
            if userOptions.dialogueBox
                %% Graphical version in here!

                options.Interpreter = 'tex';
                options.Default = 'OK';

                questdlg('Skip: Data not overwritten.','Skip:', 'Yep','OK',options);

                clear options;

            else
                % Textual version in here!
                prints('"S" is for "Skip": Data not overwritten.');
            end%if

            overwriteFlag = false;

        elseif strcmpi(reply, 'R') %&& existFlag
            % Rerun
            if userOptions.dialogueBox
                % Graphical version in here!

                options.Interpreter = 'tex';
                options.Default = 'OK';

                questdlg('Rerun: Data will be overwritten.','Rerun:', 'Good','OK',options);

                clear options;
            else
                % Textual version in here!
                prints('"R" is for "Rerun": Data will be overwritten.');
            end%if

            overwriteFlag = true;
        end%if

    else

        overwriteFlag = true;

    end%if

end%function
