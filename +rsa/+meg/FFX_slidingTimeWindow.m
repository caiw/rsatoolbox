% This script is designed to work with sliding time window analysis. It
% reads the data RDMs generated by previous steps of analysis and performs
% permutation test based on fixed effects analysis.
% The cluster level corrected results are also stored. You can observe null
% distribution for each RoI (also saved in results as a .fig).
%   Input:
%       userOptions
%       Models

% Note: May take long time per RoI if RDMs are large
% Written by IZ 05/13

function FFX_slidingTimeWindow(userOptions, model)

import rsa.*
import rsa.fig.*
import rsa.meg.*
import rsa.rdm.*
import rsa.sim.*
import rsa.spm.*
import rsa.stat.*
import rsa.util.*

close all;
returnHere = pwd; % We'll come back here later
modelName = model.name;
if userOptions.partial_correlation
    modelName = [modelName, '_partialCorr'];
end

output_path = fullfile(userOptions.rootPath, 'Results', 'FixedEffects');
promptOptions.functionCaller = 'FFX_slidingTimeWindow';
promptOptions.defaultResponse = 'S';
promptOptions.checkFiles(1).address = fullfile(output_path, [modelName '-' userOptions.maskNames{numel(userOptions.maskNames)} '-r.csv']);

overwriteFlag = overwritePrompt(userOptions, promptOptions);

if overwriteFlag
    rdms_path =fullfile(userOptions.rootPath,'RDMs',[userOptions.analysisName '_' modelName '_dataRDMs_sliding_time_window']);
    
    if ~exist(output_path,'dir')
        mkdir(output_path);
    end
    
    if ~exist([output_path, '/ClusterStats'], 'dir')
        mkdir([output_path, '/ClusterStats']);
    end
    
    fprintf('Loading all data RDMs... ');
    try
        load(rdms_path);
        disp('Done!');
    catch
        error('Cannot load data RDMs file.')
    end
    
    if isempty(gcp('nocreate')) == 0
       p = parpool; 
    end
    
    nMasks = size(allRDMs,1);
    nTimePoints = size(allRDMs,2);
    modelRDM = model.RDM;
    modelRDM_vec = vectorizeRDM(modelRDM);
    if userOptions.partial_correlation
        control_for_modelRDMs = [];
        for m = 1:size(userOptions.partial_modelNumber,2)
            control_for_modelRDMs = [control_for_modelRDMs;vectorizeRDM(model(userOptions.partial_modelNumber{m}).RDM)];
        end
    end
    for mask=1:nMasks
        clear obs_alpha simulated_alpha;
        
        thisMask = userOptions.maskNames{mask};
        %         currentTimeWindow = userOptions.maskTimeWindows{mask};
        disp([thisMask ': Testing (model, RoI) RDM pairs for significance of similarity...']);
        
        time= userOptions.STCmetaData.tmin*1000;
        for timeWindow = 1:nTimePoints
            
            RDMs = squeeze(allRDMs(mask,timeWindow,:,:))'; % changing format of RDMs to mask,subject,session
            RDMs = averageRDMs_subjectSession(RDMs, 'session');
            aRDMs = averageRDMs_subjectSession(RDMs, 'subject');
            
            % Name the RDMs being compared
            ts2=aRDMs.name;
            
            % step 1: compute r and p values %
            if userOptions.partial_correlation
                [r(timeWindow) p(timeWindow)] = partialcorr(vectorizeRDM(aRDMs.RDM)',modelRDM_vec',control_for_modelRDMs','type',userOptions.RDMCorrelationType,'rows','pairwise');
            else
                [r(timeWindow) p(timeWindow)] = corr(vectorizeRDM(aRDMs.RDM)',modelRDM_vec','type',userOptions.RDMCorrelationType,'rows','pairwise');
            end
            disp([ts2 ' ' num2str(time) ' ms r: ' num2str(r(timeWindow),6) ' p: ' num2str(p(timeWindow),6)])
            time = time + userOptions.temporalSearchlightTimestep;
            
            % step 2: threshold r map %
            if p(timeWindow) <= 0.05 && r(timeWindow) >= 0
                thresh_r(timeWindow) = r(timeWindow);
            else
                thresh_r(timeWindow) = 0;
            end
            
        end
        
        % step 3: compute cluster mass ?? % 
        where = find(thresh_r > 0);
        
        cluster = 1;
        if ~isempty(where)
            for k=1:length(where)
                if k==1 
                    obs_alpha(cluster) = thresh_r(where(k));
                elseif k>1 && r(where(k)) >= 0
                    if where(k-1)  == where(k)-1
                        obs_alpha(cluster) = obs_alpha(cluster) + thresh_r(where(k));
                    else
                        cluster = cluster+1;
                        obs_alpha(cluster) = thresh_r(where(k));
                    end
                end
            end
        else
            obs_alpha(cluster) = 0;
        end
                
        % step 4: permutation %
        disp(['Performing fixed effects permutation for ' thisMask '...']);
        for perm = 1:userOptions.significanceTestPermutations
            
            if mod(perm, floor(userOptions.significanceTestPermutations/20)) == 0, fprintf('\b.'); end%if
            
            modelRDM_vec_new = vectorizeRDM(randomizeSimMat(modelRDM));
            
            % repeat step 1, 2 and 3 
            parfor timeWindow = 1:nTimePoints
                RDMs = squeeze(allRDMs(mask,timeWindow,:,:))'; % changing format of RDMs to mask,subject,session
                RDMs = averageRDMs_subjectSession(RDMs, 'session');
                aRDMs = averageRDMs_subjectSession(RDMs, 'subject');
                
                % step 1
                [r_sim(timeWindow) p_sim(timeWindow)] = corr(vectorizeRDM(aRDMs.RDM)',modelRDM_vec_new','type',userOptions.RDMCorrelationType,'rows','pairwise');
                
                % step 2
                if p_sim(timeWindow) <= 0.05 && r_sim(timeWindow) >= 0
                    thresh_r_sim(timeWindow) = r_sim(timeWindow);
                else
                    thresh_r_sim(timeWindow) = 0;
                end
            end
            
            % step 3
            where = find(thresh_r_sim > 0);
            cluster = 1;
            if ~isempty(where)
                for k=1:length(where)
                    if k==1 
                        alpha(cluster) = thresh_r_sim(where(k));
                    elseif k>1 
                        if where(k-1)  == where(k)-1
                            alpha(cluster) = alpha(cluster) + thresh_r_sim(where(k));
                        else
                            cluster = cluster+1;
                            alpha(cluster) = thresh_r_sim(where(k));
                        end
                    end
                end
            else
                alpha(cluster) = 0;
            end
            
            simulated_alpha(perm) = max(alpha);   
            clear alpha;
        end
        disp('Done!');
        
        percent = 0.05;
        simulated_alpha = sort(simulated_alpha);
        cluster_level_threshold = simulated_alpha(ceil(size(simulated_alpha,2)*(1-percent)));
        
        % saving files
        fprintf('Saving p and r values... ');
        xlswrite(fullfile(output_path,[modelName '-' thisMask '-p.xls']), p);
        xlswrite(fullfile(output_path,[modelName '-' thisMask '-r.xls']), r);
        xlswrite(fullfile(output_path,[modelName '-' thisMask '-thresholded_r.xls']), thresh_r);
        fprintf('Saving null distribution... ');
        xlswrite(fullfile(userOptions.rootPath, 'ImageData', [modelName '-' thisMask '-ffx-nulldistribution.xls']), simulated_alpha);
        
         %% displaying results
        disp(['Cluster level threshold: ' num2str(cluster_level_threshold)]);
        
        % plotting null distribution
        disp('Plotting null distribution...');
        figure(mask);
        hist(simulated_alpha,100);
        h = findobj(gca, 'Type', 'patch');
        set(h, 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', [0 0 0]);
        hold on;
        yLimits = get(gca, 'YLim');
        plot(repmat(cluster_level_threshold,1,yLimits(1,2)), 1:yLimits(1,2), ':','color', 'red', 'LineWidth', 2 );
        text(double(cluster_level_threshold), yLimits(1,2)/2, [' \leftarrow cluster level threshold: ' num2str(cluster_level_threshold,4)], 'FontSize', 10);   
        title([thisMask ': Null distribution across ' num2str(userOptions.significanceTestPermutations) ' permutations (ffx)']);
        saveas(figure(mask),fullfile(userOptions.rootPath, 'Results', 'FixedEffects', [thisMask '_null-distribution']),'fig');
        
        disp('Observed clusters stats:')
        out = zeros(length(obs_alpha),2);
        for clust=1:length(obs_alpha)
            if  obs_alpha(clust) ==0
                p_obs = 1;
            else
                if nnz(simulated_alpha > obs_alpha(clust)) == 0
                    p_obs = 0;
                else
                    p_obs = nnz(simulated_alpha > obs_alpha(clust))/userOptions.significanceTestPermutations;
                end
            end
            disp([' - Cluster ' num2str(clust) ' - mass: ' num2str(obs_alpha(clust)) ' - p value: ' num2str(p_obs)]);
            out(clust,:) = [obs_alpha(clust), p_obs];
        end
        
        fprintf('Saving cluster stats... ');
        xlswrite(fullfile(userOptions.rootPath, 'Results', 'FixedEffects', 'ClusterStats', [modelName '-' thisMask '-clusterstats.xls']), out);
        disp('Done!');
        
    end
    
    % Close the parpool
    delete(p);
    
else
    fprintf('Permutation already performed, skip....\n');
end
