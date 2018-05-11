% TODO: Documentation
%
% Cai Wingfield 2010-05, 2010-08, 2015-03
% update by Li Su 3-2012, 11-2012
% updated Fawad 12-2013, 02-2014, 10-2014

toolboxRoot = '/imaging/cw04/code/rsagroup-rsatoolbox/';
addpath(genpath(toolboxRoot));

rsa.util.prints('Starting RSA.');

userOptions = defineUserOptions();

rsa.util.prints('Starting RSA analysis "%s".', userOptions.analysisName);


%% %%%%%%%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Preparing model RDMs...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%

models = rsa.constructModelRDMs(userOptions);
% Only using one model at a time for searchlight analysis.
model = models(1);


%% %%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Preparing masks...');
%%%%%%%%%%%%%%%%%%%%%%

usingMasks = ~isempty(userOptions.maskNames);
if usingMasks
    slMasks = rsa.meg.MEGMaskPreparation_source(userOptions);
    % For this searchlight analysis, we combine all masks into one
    slMasks = rsa.meg.combineVertexMasks_source(slMasks, 'combined_mask', userOptions);  
else
    slMasks = rsa.meg.allBrainMask(userOptions);
end


%% Compute some constats
nSubjects = numel(userOptions.subjectNames);
adjacencyMatrix = rsa.meg.calculateMeshAdjacency(userOptions.targetResolution, userOptions.sourceSearchlightRadius, userOptions);


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Starting parallel toolbox...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if userOptions.flush_Queue
    rsa.par.flushQ();
end

if userOptions.run_in_parallel
    p = rsa.par.initialise_CBU_Queue(userOptions);
end


%% %%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Loading brain data...');
%%%%%%%%%%%%%%%%%%%%%

[meshPaths, STCMetadatas] = rsa.meg.MEGDataPreparation_source( ...
    betaCorrespondence(), ...
    userOptions, ...
    'mask', slMasks);


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Searchlight Brain RDM Calculation...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[RDMsPaths, slSTCMetadatas, slSpecs] = rsa.meg.MEGSearchlightRDMs_source( ...
    meshPaths, ...
    slMasks, ...
    adjacencyMatrix, ...
    STCMetadatas, ...
    userOptions);


%% %%%%%
rsa.util.prints( ...
    'Averaging searchlight RDMs...');
%%%%%%%%

averageRDMPaths = rsa.meg.averageSearchlightRDMs(RDMPaths, userOptions);


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
   'Searchlight Brain Model comparison...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parfor subject_i = 1:nSubjects
   
   % Work on each hemisphere separately
   for chi = 'LR'
       rsa.util.prints('Working on subject %d, %s side', subject_i, chi);

       % TODO: fix the use of sl metadatas and sl specs here
       [mapPaths(subject_i).(chi)] = rsa.meg.searchlightMapping_source( ...
           subject_i, ...
           chi, ...
           RDMPaths(subject_i).(chi), ...
           ...% Use the mask for this hemisphere only
           slMasks([slMasks.chi] == chi), ...
           model, ...
           [], ...
           adjacencyMatrix, ...
           STCMetadatas.(chi), ...
           userOptions ...
       );
   end
end


%% %%%%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Performing random permutations...');
%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(userOptions.groupStats, 'FFX')
    % fixed effect test
    rsa.util.prints('Fixed Effects Analysis:');
    tic
    rsa.util.prints('Averaging RDMs across subjects and performing permutation tests to calculate p-values...');
    rsa.meg.FFX_permutation(model, slMasks, userOptions)
    toc
else
    % random effect test
    rsa.util.prints('Random Effects Analysis:');
    tic
    rsa.util.prints('Performing permutation tests over all subjects (random effect) to calculate p-values...');
    rsa.meg.RFX_permutation(model,userOptions);
    toc 
end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Spatiotemporal Clustering...' );
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

jobSize = userOptions.jobSize;
number_of_permutations = userOptions.significanceTestPermutations;

tic
parfor j = 1:number_of_permutations/jobSize
    range = (j-1)*jobSize+1:j*jobSize;
    rsa.meg.MEGFindCluster_source(model, range, slMasks, userOptions);
end
toc


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Computing cluster level p values...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tic
rsa.stat.get_cluster_p_value(model, userOptions);
toc


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rsa.util.prints( ...
    'Cleaning up...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Close the parpool
if userOptions.run_in_parallel
    delete(p);
end

if (userOptions.deleteTMaps_Dir || userOptions.deleteImageData_Dir || userOptions.deletePerm)
    rsa.util.deleteDir(userOptions, model);
end

% Sending an email
if userOptions.recieveEmail
    rsa.par.setupInternet();
    rsa.par.setupEmail(userOptions.mailto);
end

rsa.util.prints( ...
    'RSA COMPLETE!');

