function computeEZTAdjMats(patient_id, seizure_id, included_channels, ...
    timeRange, winSize, stepSize, ezone_labels, earlyspread_labels, latespread_labels)
% add libraries of functions
addpath('./fragility_library/');
% addpath('/Users/adam2392/Dropbox/eeg_toolbox');

if nargin == 0
    patient_id = '005';
    seizure_id = 'seiz001';
    if strcmp(patient_id, '007')
        included_channels = [];
        ezone_labels = {'O7', 'E8', 'E7', 'I5', 'E9', 'I6', 'E3', 'E2',...
            'O4', 'O5', 'I8', 'I7', 'E10', 'E1', 'O6', 'I1', 'I9', 'E6',...
            'I4', 'O3', 'O2', 'I10', 'E4', 'Y1', 'O1', 'I3', 'I2'}; %pt1
        earlyspread_labels = {};
        latespread_labels = {};
    elseif strcmp(patient_id, '005')
        included_channels = [];
        ezone_labels = {'U4', 'U3', 'U5', 'U6', 'U8', 'U7'}; 
        earlyspread_labels = {};
         latespread_labels = {};
    elseif strcmp(patient_id, '019')
        included_channels = [];
        ezone_labels = {'I5', 'I6', 'B9', 'I9', 'T10', 'I10', 'B6', 'I4', ...
            'T9', 'I7', 'B3', 'B5', 'B4', 'I8', 'T6', 'B10', 'T3', ...
            'B1', 'T8', 'T7', 'B7', 'I3', 'B2', 'I2', 'T4', 'T2'}; 
        earlyspread_labels = {};
         latespread_labels = {}; 
     elseif strcmp(patient_id, '045') % FAILURES
        included_channels = [];
        ezone_labels = {'X2', 'X1'}; %pt2
        earlyspread_labels = {};
         latespread_labels = {}; 
      elseif strcmp(patient_id, '090') % FAILURES
        included_channels = [];
        ezone_labels = {'N2', 'N1', 'N3', 'N8', 'N9', 'N6', 'N7', 'N5'}; 
        earlyspread_labels = {};
         latespread_labels = {}; 
    end
end
if nargin < 4 % set the timeRange, winSize, stepSize if they are not set
    timeRange = [60, 10];
    winSize = 500;
    stepSize = 500;
end

%% 0: READ PATIENT ID FILE
patient = strcat('EZT', patient_id, '_', seizure_id) % patient
%- set processing data vars 
frequency_sampling = 1000; % sampling freq. at 1 kHz
BP_FILTER_RAW = 1;

% create the adjacency file directory to store the computed adj. mats
adjDir = fullfile(strcat('./adj_mats_win', num2str(winSize), ...
    '_step', num2str(stepSize)), patient);
if ~exist(adjDir, 'dir')
    mkdir(adjDir);
end

%- set file path for the patient file 
dataDir = './data/';
patient_eeg_path = strcat('./data/Seiz_Data/', strcat('EZT', patient_id));

%- apply a bandpass filter raw data? (i.e. pre-filter the wave?)
if BP_FILTER_RAW==1,
    preFiltFreq      = [1 499];   %[1 499] [2 250]; first bandpass filter data from 1-499 Hz
    preFiltType      = 'bandpass';
    preFiltOrder     = 2;
    preFiltStr       = sprintf('%s filter raw; %.1f - %.1f Hz',preFiltType,preFiltFreq);
    preFiltStrShort  = '_BPfilt';
else
    preFiltFreq      = []; %keep this empty to avoid any filtering of the raw data
    preFiltType      = 'stop';
    preFiltOrder     = 1;
    preFiltStr       = 'Unfiltered raw traces';
    preFiltStrShort  = '_noFilt';
end

% READ EEG FILE Mat File
% files to process
data = load(fullfile(patient_eeg_path, patient));
recording_start = 0;
onset_time = data.seiz_start_mark;
offset_time = data.seiz_end_mark;
recording_duration = size(data.data, 2);
num_channels = size(data.data, 1);
%% 1. Extract EEG and Perform Analysis
% 1A. extract eeg 
eeg = data.data;
% 1B. apply band notch filter
eeg = buttfilt(eeg,[59.5 60.5], frequency_sampling,'stop',1);
% 1C. only get columns of interest and time points of interest
seizureStart = (onset_time - recording_start); % time seizure starts
seizureEnd = (offset_time - recording_start); % time seizure ends
file_length = length(eeg); 

% window parameters - overlap, #samples, stepsize, window pointer
preseizureTime = timeRange(1); % e.g. 60 seconds 
postseizureTime = timeRange(2); % e.g. 10 seconds
dataStart = seizureStart - preseizureTime*frequency_sampling;  % current data window                      % where to grab data (milliseconds)

% begin computation and time it
tic;
index = 1;
limit = seizureStart + postseizureTime*frequency_sampling; % go to seizure start, or + 10 seconds

disp(['The range locked to seizure to look over is', num2str(-timeRange(1)), ...
    ' until ', num2str(timeRange(2))]); 
disp(['Total number of channels ', num2str(num_channels)]);
disp(['Length of to be included channels ', num2str(length(included_channels))]);
disp(['Seizure starts at ', num2str(limit), ' milliseconds']);


tic;
dataWindow = dataStart;
dataRange = limit-dataWindow
for i=1:dataRange/stepSize  % loop through the datawindows and compute adjacency matrices
    dataWindow = dataStart + (i-1)*stepSize;
    
    fileName = strcat(patient, '_before', num2str(i), '.mat');
    
    
    % step 1: extract the data and apply the notch filter. Note that column
    %         #i in the extracted matrix is filled by data samples from the
    %         recording channel #i.
    tmpdata = eeg(:, dataWindow + 1:dataWindow + winSize);

    % step 2: compute some functional connectivity 
    % linear model: Ax = b; A\b -> x
    b = tmpdata(:); % define b as vectorized by stacking columns on top of another
    b = b(num_channels+1:end); % only get the time points after the first one
    
    tmpdata = tmpdata';
    tic;
    % build up A matrix with a loop modifying #time_samples points and #chans at a time
    A = zeros(length(b), num_channels^2);               % initialize A for speed
    N = 1:num_channels:size(A,1);                       % set the indices through rows
    A(N, 1:num_channels) = tmpdata(1:end-1,:);          % set the first loop
    
    for iChan=2 : num_channels % loop through columns #channels per loop
        rowInds = N+(iChan-1);
        colInds = (iChan-1)*num_channels+1:iChan*num_channels;
        A(rowInds, colInds) = tmpdata(1:end-1,:);
    end
    toc;
    
    % A is a sparse matrix, so store it as such
    A = sparse(A);

    % create the reshaped adjacency matrix
    tic;
    theta = A\b;                                                % solve for x, connectivity
    theta_adj = reshape(theta, num_channels, num_channels)';    % reshape fills in columns first, so must transpose
    imagesc(theta_adj)
    toc;
    
    %% save the theta_adj made
    %- save the data into a struct into a mat file
    %- save the data into a struct into a mat file - time all in
    %milliseconds
    data = struct();
    data.theta_adj = theta_adj;
    data.seizureTime = seizureStart;
    data.seizureEnd = seizureEnd;
    data.winSize = winSize;
    data.stepSize = stepSize;
    data.timewrtSz = dataWindow - seizureStart;
    data.timeStart = seizureStart - preseizureTime*frequency_sampling;
    data.timeEnd = seizureStart + postseizureTime*frequency_sampling;
    data.index = i;
    data.included_channels = included_channels;
    data.ezone_labels = ezone_labels;
    data.earlyspread_labels = earlyspread_labels;
    data.latespread_labels = latespread_labels;
    
    save(fullfile(adjDir, fileName), 'data');
end
end