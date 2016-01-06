% Cai Wingfield 2016-01
function averageRDMPaths = averageSlidingWindowRDMs(RDMPaths, userOptions)

    import rsa.util.*
    
    % Paths
    file_i = 1;
    for chi = 'LR'
        averageRDMPaths.(chi) = fullfile(userOptions.rootPath, 'RDMs', ['average_', lower(chi), 'h.mat']);
        promptOptions.checkFiles(file_i).address = averageRDMPaths.(chi);
        file_i = file_i + 1;
    end
    
    promptOptions.functionCaller = 'averageSlidingWindowRDMs';
    promptOptions.defaultResponse = 'S';
    
    overwriteFlag = overwritePrompt(userOptions, promptOptions);
    
    if overwriteFlag

        nSubjects = numel(userOptions.subjectNames);
        for chi = 'LR'

            nTimepoints = NaN;
            
            % TODO: Why is this needed?
            clear average_slRDMs;

            for subject_i = 1:nSubjects

                this_subject_name = userOptions.subjectNames{subject_i};

                prints('Loading sliding window RDMs for subject %s (%d/%d) %sh...', this_subject_name, subject_i, nSubjects, lower(chi));
                this_subject_slRDMs = directLoad(RDMPaths(subject_i).(chi), 'swRDMs');

                % For the first subject, we initialise the average and the
                % nan-counter with some sizes.
                if subject_i == 1
                    nTimepoints = numel(this_subject_slRDMs);
                    average_slRDMs(1:nTimepoints) = struct('RDM', zeros(size(this_subject_slRDMs(1,1).RDM)));
                    nan_counts(1:nTimepoints) = struct('mask', zeros(size(this_subject_slRDMs(1,1).RDM)));
                end

                prints('Adding RDMs at all timepoints...');

                parfor t = 1:nTimepoints
                    nan_locations = isnan(this_subject_slRDMs(t).RDM);
                    this_subject_slRDMs(t).RDM(nan_locations) = 0;
                    average_slRDMs(t).RDM = average_slRDMs(t).RDM + this_subject_slRDMs(t).RDM;
                    nan_counts(t).mask = nan_counts(t).mask + nan_locations;
                end%for
            end%for:subject

            prints('Averaging RDMs at all vertices...');

            % replace nan counts by non-nan counts
            for t = 1:nTimepoints
                non_nan_counts = nSubjects - nan_counts(t).mask;
                average_slRDMs(t).RDM = average_slRDMs(t).RDM ./ non_nan_counts;
            end

            prints('Saving average sliding window RDMs to "%s"...', averageRDMPaths.(chi));
            save('-v7.3', averageRDMPaths.(chi), 'average_slRDMs');

        end%for:chi

    else
        prints('Average RDMs already calculated.  Skipping...');
    end
    
end%function
