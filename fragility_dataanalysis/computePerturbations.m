%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: computePerturbations
% DESCRIPTION: This function takes adjacency matrices and computes the
% minimum l2-norm perturbation required to destabilize the system.
% 
% INPUT:
% - patient_id = The id of the patient (e.g. pt1, JH105, UMMC001)
% - seizure_id = the id of the seizure (e.g. sz1, sz3)
% - w_space = the frequency space on unit disc that we want to search over
% - radius = the radius of disc that we want to perturb eigenvalues to
% - perturbationType = 'R', or 'C' for row or column perturbation
% 
% OUTPUT:
% - None, but it saves a mat file for the patient/seizure over all windows
% in the time range -> adjDir/final_data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function computePerturbations(patient_id, seizure_id, w_space, radius, perturbationType)
if nargin == 0
    patient_id = 'pt1';
    seizure_id = 'sz2';
    radius = 1.1;
    w_space = linspace(-1, 1, 101);
    perturbationType = 'R';
end

%% 0: Initialize All Necessary Vars and Dirs
sigma = sqrt(radius^2 - w.^2); % move to the unit circle 1, for a plethora of different radial frequencies
b = [0; 1];
patient = strcat(patient_id, seizure_id);

%- initialize directories and labels
adjDir = fullfile(strcat('./adj_mats_win', num2str(winSize), ...
    '_step', num2str(stepSize)), patient);
%- set file path for the patient file 
dataDir = './data/';
patient_eeg_path = strcat('./data/', patient);
patient_label_path = fullfile(dataDir, patient, strcat(patient, '_labels.csv'));

fid = fopen(patient_label_path); % open up labels to get all the channels
labels = textscan(fid, '%s', 'Delimiter', ',');
labels = labels{:}; labels = labels(included_channels);
fclose(fid);
                       
% define cell function to search for the EZ labels
cellfind = @(string)(@(cell_contents)(strcmp(string,cell_contents)));
ezone_indices = zeros(length(ezone_labels),1);
for i=1:length(ezone_labels)
    indice = cellfun(cellfind(ezone_labels{i}), labels, 'UniformOutput', 0);
    indice = [indice{:}];
    test = 1:length(labels);
    if ~isempty(test(indice))
        ezone_indices(i) = test(indice);
    end
end

earlyspread_indices = zeros(length(earlyspread_labels),1);
for i=1:length(earlyspread_labels)
    indice = cellfun(cellfind(earlyspread_labels{i}), labels, 'UniformOutput', 0);
    indice = [indice{:}];
    test = 1:length(labels);
    if ~isempty(test(indice))
        earlyspread_indices(i) = test(indice);
    end
end
earlyspread_indices(earlyspread_indices==0) =  [];

latespread_indices = zeros(length(latespread_labels),1);
if strcmp(pat_id, 'pt1')
    for i=1:length(latespread_labels)
        indice = cellfun(cellfind(latespread_labels{i}), labels, 'UniformOutput', 0);
        indice = [indice{:}];
        test = 1:length(labels);
        if ~isempty(test(indice))
            latespread_indices(i) = test(indice);
        end
    end
end

%% 1: Read in Data and Initialize Variables For Analysis
matFiles = dir(fullfile(adjDir, '*.mat'));
matFiles = {matFiles.name};         % cell array of all mat file names in order
matFiles = natsortfiles(matFiles);  % 3rd party - natural sorting order
data = load(fullfile(adjDir, patient, matFiles{2}));    % load in example preprocessed mat
data = data.data;
included_channels = data.included_channels;

%- initialize matrices for colsum, rowsum, and minimum perturbation
timeRange = length(matFiles);               % the number of mat files to analyze
colsum_time_chan = zeros(length(included_channels), ... % colsum at each time/channel
                    timeRange);
rowsum_time_chan = zeros(length(included_channels), ... % rowsum at each time/channel
                    timeRange);
minPerturb_time_chan = zeros(length(included_channels), ... % fragility at each time/channel
                    timeRange);
timeIndices = [];             % vector to store time indices (secs) of each window of data

% loop through mat files and open them upbcd
iTime = 1; % time pointer for heatmaps
tic; % start counter
for i=1:length(matFiles) % loop through each adjacency matrix
    %%- 01: Extract File and Information
    matFile = matFiles{i};
    data = load(fullfile(dataDir, matFile));
    data = data.data;
    
    theta_adj = data.theta_adj;
    timewrtSz = data.timewrtSz / 1000; % in seconds
    index = data.index;
    if (i == 1) % only set these variables once -> save time in seconds
        timeStart = data.timeStart / 1000;
        timeEnd = data.timeEnd / 1000;
        seizureTime = data.seizureTime / 1000;
    end
    % store all the time indices with respect to seizure
    timeIndices = [timeIndices; timewrtSz];
    
    %%- 02:Compute Minimum Norm Perturbation
    % determine which indices have eigenspectrums that are stable
    max_eig = max(abs(eig(theta_adj)));
    if (max_eig < sigma0) % this is a stable eigenspectrum
        N = size(theta_adj, 1); % number of rows
        del_size = zeros(N, length(w));
        
        %%- grid search over sigma and w for each row to determine, what is
        %%- the min norm perturbation
        for iNode=1:N
            ek = [zeros(iNode-1, 1); 1; zeros(N-iNode,1)]; % unit vector at this node
            A = theta_adj; 
            
            for iW=1:length(w_space) % loop through frequencies
                lambda = sigma(iW) + 1i*w_space(iW);

                % row perturbation inversion
                if (perturbationType == 'R')
                    C = ek'*inv(A - lambda*eye(N));  
                    
                    if size(C,1) > 1
                        size(C)
                        disp('Could be an error in setting Row and Col Pert.');
                    end
                elseif (perturbationType == 'C')
                    C = inv(A - lambda*eye(N))*ek; 
                    if size(C,2) > 1
                        size(C)
                        disp('Could be an error in setting Row and Col Pert.');
                    end
                end
                Cr = real(C);
                Ci = imag(C);
                B = [Ci; Cr];
                
                % compute perturbation necessary
                del = B'*inv(B*B')*b;
                
                % store the l2-norm of the perturbation
                del_size(iNode, iW) = norm(del); 
            end
            % store minimum perturbation, for each node at a certain time point
            minPerturb_time_chan(iNode, iTime) = min(del_size(iNode,:));
        end % end of loop through channels
        
        %%- 03: Store Results (colsum, rowsum, perturbation,
        % store col/row sum of adjacency matrix
        colsum_time_chan(:, iTime) = sum(theta_adj, 1);
        rowsum_time_chan(:, iTime) = sum(theta_adj, 2);
        
        % update pointer for the fragility heat map
        iTime = iTime+1;
        disp(['On ', num2str(i), ' out of ', num2str(length(matFiles)), ' to analyze.']);
    end
end
toc

%% 3. Compute fragility rankings per column by normalization
fragility_rankings = zeros(size(minPerturb_time_chan,1),size(minPerturb_time_chan,2));
for i=1:size(minPerturb_time_chan,1)      % loop through each channel
    for j=1:size(minPerturb_time_chan, 2) % loop through each time point
        fragility_rankings(i,j) = (max(minPerturb_time_chan(:,j)) - minPerturb_time_chan(i,j)) ...
                                    / max(minPerturb_time_chan(:,j));
    end
end

%- make processed file dir, if not saved yet.
if ~exist(fullfile(adjDir, 'finaldata'), 'dir')
    mkdir(fullfile(adjDir, 'finaldata'));
end
save(fullfile(adjDir,'finaldata', strcat(patient,'final_data.mat')),...
 'minPerturb_time_chan', 'colsum_time_chan', 'rowsum_time_chan', 'fragility_rankings');
end