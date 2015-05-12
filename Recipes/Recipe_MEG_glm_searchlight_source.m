% TODO: Documentation
%
% Cai Wingfield 2010-05, 2010-08, 2015-03, 2015-04
% update by Li Su 3-2012, 11-2012
% updated Fawad 12-2013, 02-2014, 10-2014

toolboxRoot = '/imaging/cw04/code/rsagroup-rsatoolbox/';
addpath(genpath(toolboxRoot));

import rsa.*
import rsa.util.*
import rsa.par.*
import rsa.meg.*

userOptions = defineUserOptions();

prints('Starting RSA analysis "%s".', userOptions.analysisName);


%% %%%%%%%%%%%%%%%%%%%%%%%%
prints('Preparing model RDMs...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%

models = constructModelRDMs(userOptions);


%% %%%%%%%%%%%%%%%%%%%
prints('Preparing masks...');
%%%%%%%%%%%%%%%%%%%%%%

usingMasks = ~isempty(userOptions.maskNames);
if usingMasks
    slMasks = MEGMaskPreparation_source(userOptions);
    % For this searchlight analysis, we combine all masks into one
    slMasks = combineVertexMasks_source(slMasks, 'combined_mask', userOptions);  
else
    slMasks = allBrainMask(userOptions);
end


%% Compute some constats
nSubjects = numel(userOptions.subjectNames);
adjacencyMatrices = calculateMeshAdjacency(userOptions.targetResolution, userOptions.sourceSearchlightRadius, userOptions, 'hemis', 'LR');


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%
prints('Starting parallel toolbox...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if userOptions.flush_Queue
    flushQ();
end

if userOptions.run_in_parallel
    p = initialise_CBU_Queue(userOptions);
end


%% %%%%%%%%%%%%%%%%%%
prints('Loading brain data...');
%%%%%%%%%%%%%%%%%%%%%

[meshPaths, STCMetadatas] = MEGDataPreparation_source( ...
    betaCorrespondence(), ...
    userOptions, ...
    'mask', slMasks);


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
prints('Searchlight Brain RDM Calculation...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[RDMsPaths, slSTCMetadatas] = MEGSearchlightRDMs_source( ...
    meshPaths, ...
    slMasks, ...
    ...% Assume that both hemis' adjacency matrices are the same so only use one.
    adjacencyMatrices.L, ...
    STCMetadatas, ...
    userOptions);


%% %%%%%
prints('Averaging searchlight RDMs...');
%%%%%%%%

averageRDMPaths = averageSearchlightRDMs(RDMsPaths, userOptions);


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
prints('GLM-fitting models to searchlight RDMs...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[glm_paths, lagSTCMetadatas] = searchlight_dynamicGLM_source( ...
    averageRDMPaths, ...
    models, ...
    slSTCMetadatas, ...
    userOptions, ...
    'lag', 30);

find_maximum_glm_weights( ...
    glm_paths, ...
    lagSTCMetadatas, ...
    userOptions);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
prints('Thresholding GLM values...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[h0_paths, h0_pooled_paths] = searchlight_GLM_permutation_source( ...
    averageRDMPaths, ...
    models, ...
    slSTCMetadatas, ...
    lagSTCMetadatas, ...
    ...%TODO make this into optional argument
    30, ...
    userOptions);


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
prints('Cleaning up...');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Close the parpool
if userOptions.run_in_parallel
    delete(p);
end

% Sending an email
if userOptions.recieveEmail
    setupInternet();
    setupEmail(userOptions.mailto);
end

prints( ...
    'RSA COMPLETE!');
