function serverPerturbationScript(patient, radius, winSize, stepSize, frequency_sampling)
addpath('../fragility_library/');
addpath(genpath('../eeg_toolbox/'));
addpath('../');
perturbationTypes = ['R', 'C'];
w_space = linspace(-1, 1, 101);

if nargin == 0 % testing purposes
    patient='EZT007seiz001';
    % window paramters
    radius = 1.1;
    winSize = 250; % 500 milliseconds
    stepSize = 250; 
    frequency_sampling = 500; % in Hz
end
timeRange = [60 0];

patient_id = patient(1:strfind(patient, 'seiz')-1);
seizure_id = strcat('_', patient(strfind(patient, 'seiz'):end));
seeg = 1;
if isempty(patient_id)
    patient_id = patient(1:strfind(patient, 'sz')-1);
    seizure_id = patient(strfind(patient, 'sz'):end);
    seeg = 0;
end

%% DEFINE CHANNELS AND CLINICAL ANNOTATIONS
if strcmp(patient_id, 'EZT007')
    included_channels = [1:16 18:53 55:71 74:78 81:94];
    ezone_labels = {'O7', 'E8', 'E7', 'I5', 'E9', 'I6', 'E3', 'E2',...
        'O4', 'O5', 'I8', 'I7', 'E10', 'E1', 'O6', 'I1', 'I9', 'E6',...
        'I4', 'O3', 'O2', 'I10', 'E4', 'Y1', 'O1', 'I3', 'I2'}; %pt1
    earlyspread_labels = {};
    latespread_labels = {};
elseif strcmp(patient_id, 'EZT005')
    included_channels = [1:21 23:60 63:88];
    ezone_labels = {'U4', 'U3', 'U5', 'U6', 'U8', 'U7'}; 
    earlyspread_labels = {};
     latespread_labels = {};
elseif strcmp(patient_id, 'EZT019')
    included_channels = [1:5 7:22 24:79];
    ezone_labels = {'I5', 'I6', 'B9', 'I9', 'T10', 'I10', 'B6', 'I4', ...
        'T9', 'I7', 'B3', 'B5', 'B4', 'I8', 'T6', 'B10', 'T3', ...
        'B1', 'T8', 'T7', 'B7', 'I3', 'B2', 'I2', 'T4', 'T2'}; 
    earlyspread_labels = {};
     latespread_labels = {}; 
 elseif strcmp(patient_id, 'EZT045') % FAILURES 2 EZONE LABELS?
    included_channels = [1 3:14 16:20 24:28 30:65];
    ezone_labels = {'X2', 'X1'}; %pt2
    earlyspread_labels = {};
     latespread_labels = {}; 
  elseif strcmp(patient_id, 'EZT090') % FAILURES
    included_channels = [1:25 27:42 44:49 51:73 75:90 95:111];
    ezone_labels = {'N2', 'N1', 'N3', 'N8', 'N9', 'N6', 'N7', 'N5'}; 
    earlyspread_labels = {};
     latespread_labels = {};
elseif strcmp(patient_id, 'EZT108')
    included_channels = [];
    ezone_labels = {'F2', 'V7', 'O3', 'O4'}; % marked ictal onset areas
    earlyspread_labels = {};
    latespread_labels = {};
elseif strcmp(patient_id, 'EZT120')
    included_channels = [];
    ezone_labels = {'C7', 'C8', 'C9', 'C6', 'C2', 'C10', 'C1'};
    earlyspread_labels = {};
    latespread_labels = {};
elseif strcmp(patient_id, 'Pat2')
    included_channels = [];
    ezone_labels = {};
    earlyspread_labels = {};
    latespread_labels = {};
elseif strcmp(patient_id, 'Pat16')
    included_channels = [];
    ezone_labels = {};
    earlyspread_labels = {};
    latespread_labels = {};
elseif strcmp(patient_id, 'pt7')
    included_channels = [1:17 19:35 37:38 41:62 67:109];
    ezone_labels = {};
    earlyspread_labels = {};
    latespread_labels = {};
elseif strcmp(patient_id, 'pt1')
    included_channels = [1:36 42 43 46:69 72:95];
    ezone_labels = {'POLATT1', 'POLATT2', 'POLAD1', 'POLAD2', 'POLAD3'}; %pt1
    earlyspread_labels = {'POLATT3', 'POLAST1', 'POLAST2'};
    latespread_labels = {'POLATT4', 'POLATT5', 'POLATT6', ...
                        'POLSLT2', 'POLSLT3', 'POLSLT4', ...
                        'POLMLT2', 'POLMLT3', 'POLMLT4', 'POLG8', 'POLG16'};
elseif strcmp(patient_id, 'pt2')
    included_channels = [1:14 16:19 21:25 27:37 43 44 47:74];
    ezone_labels = {'POLMST1', 'POLPST1', 'POLTT1'}; %pt2
    earlyspread_labels = {'POLTT2', 'POLAST2', 'POLMST2', 'POLPST2', 'POLALEX1', 'POLALEX5'};
     latespread_labels = {};
elseif strcmp(patient_id, 'JH105')
    included_channels = [1:4 7:12 14:19 21:37 42 43 46:49 51:53 55:75 78:99]; % JH105
    ezone_labels = {'POLRPG4', 'POLRPG5', 'POLRPG6', 'POLRPG12', 'POLRPG13', 'POLG14',...
        'POLAPD1', 'POLAPD2', 'POLAPD3', 'POLAPD4', 'POLAPD5', 'POLAPD6', 'POLAPD7', 'POLAPD8', ...
        'POLPPD1', 'POLPPD2', 'POLPPD3', 'POLPPD4', 'POLPPD5', 'POLPPD6', 'POLPPD7', 'POLPPD8', ...
        'POLASI3', 'POLPSI5', 'POLPSI6', 'POLPDI2'}; % JH105
    earlyspread_labels = {};
     latespread_labels = {};
end

% put clinical annotations into a struct
clinicalLabels = struct();
clinicalLabels.ezone_labels = ezone_labels;
clinicalLabels.earlyspread_labels = earlyspread_labels;
clinicalLabels.latespread_labels = latespread_labels;

%% DEFINE COMPUTATION PARAMETERS AND DIRECTORIES TO SAVE DATA
patient = strcat(patient_id, seizure_id);
disp(['Looking at patient: ',patient]);

% create the adjacency file directory to store the computed adj. mats
toSaveAdjDir = fullfile(strcat('../adj_mats_win', num2str(winSize), ...
    '_step', num2str(stepSize), '_freq', num2str(frequency_sampling), '_radius', num2str(radius)), patient);
if ~exist(toSaveAdjDir, 'dir')
    mkdir(toSaveAdjDir);
end

%%- grab eeg data in different ways... depending on who we got it from
if ~seeg
    %% NIH, JHU PATIENTS
    %- set file path for the patient file 
    patient_eeg_path = strcat('../data/', patient);

    % READ EEG FILE Mat File
    % files to process
    data = load(fullfile(patient_eeg_path, patient));
    labels = data.elec_labels;
    onset_time = data.seiz_start_mark;
    offset_time = data.seiz_end_mark;
    recording_start = 0; % since they dont' give absolute time of starting the recording
    seizureStart = (onset_time - recording_start); % time seizure starts
    seizureEnd = (offset_time - recording_start); % time seizure ends
    recording_duration = size(data.data, 2);
    num_channels = size(data.data, 1);
else
    %% EZT/SEEG PATIENTS
    patient_eeg_path = strcat('../data/Seiz_Data/', patient_id);

    % READ EEG FILE Mat File
    % files to process
    data = load(fullfile(patient_eeg_path, patient));
    labels = data.elec_labels;
    onset_time = data.seiz_start_mark;
    offset_time = data.seiz_end_mark;
    recording_start = 0; % since they dont' give absolute time of starting the recording
    seizureStart = (onset_time - recording_start); % time seizure starts
    seizureEnd = (offset_time - recording_start); % time seizure ends
    recording_duration = size(data.data, 2);
    num_channels = size(data.data, 1);
end

if frequency_sampling ~=1000
    seizureStart = seizureStart * frequency_sampling/1000;
    seizureEnd = seizureEnd * frequency_sampling/1000;
end

%% 01:  RUN PERTURBATION ANALYSIS
if seizureStart < 60 * frequency_sampling
    disp('not 60 seconds of preseizure data');
    disp(patient);
    waitforbuttonpress;
end

try
    for j=1:length(perturbationTypes)
        perturbationType = perturbationTypes(j);

        toSaveFinalDataDir = fullfile(strcat('../adj_mats_win', num2str(winSize), ...
        '_step', num2str(stepSize), '_freq', num2str(frequency_sampling)), strcat(perturbationType, '_finaldata'), ...
            '_radius', num2str(radius));
        if ~exist(toSaveFinalDataDir, 'dir')
            mkdir(toSaveFinalDataDir);
        end

        perturb_args = struct();
        perturb_args.perturbationType = perturbationType;
        perturb_args.w_space = w_space;
        perturb_args.radius = radius;
        perturb_args.adjDir = toSaveAdjDir;
        perturb_args.toSaveFinalDataDir = toSaveFinalDataDir;
        perturb_args.labels = labels;
        perturb_args.included_channels = included_channels;
        perturb_args.num_channels = num_channels;
        perturb_args.frequency_sampling = frequency_sampling;

        computePerturbations(patient_id, seizure_id, perturb_args);
    end
catch e
    disp(e);
    disp([patient, ' is underdetermined in perturbation analysis, must use optimization techniques']);
end