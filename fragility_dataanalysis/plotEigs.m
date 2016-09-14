%%% RUN once to generate finaldata.mat
%%% Won't run if it is already generated
clear all;
close all;

% define w0/w and sigma for the frequency range to grid search over
w0 = 1;
w = linspace(-1, w0, 101); 
% sigma = linspace(0, sigma0, 100);
sigma0 = 1.1;
sigma = sqrt(sigma0^2 - w.^2); % move to the unit circle 1, for a plethora of different radial frequencies
b = [0; 1];
perturbationType = 'R';
pat_id = 'pt1'; sz_id = 'sz2';
% pat_id = 'JH105';
% sz_id = 'sz1';
patient = strcat(pat_id, sz_id);
if strcmp(pat_id, 'pt1')
    included_channels = [1:36 42 43 46:69 72:95];
    ezone_labels = {'POLPST1', 'POLPST2', 'POLPST3', 'POLAD1', 'POLAD2'}; %pt1
    ezone_labels = {'POLATT1', 'POLATT2', 'POLAD1', 'POLAD2', 'POLAD3'}; %pt1
    earlyspread_labels = {'POLATT3', 'POLAST1', 'POLAST2'};
    latespread_labels = {'POLATT4', 'POLATT5', 'POLATT6', ...
                        'POLSLT2', 'POLSLT3', 'POLSLT4', ...
                        'POLMLT2', 'POLMLT3', 'POLMLT4', 'POLG8', 'POLG16'};
elseif strcmp(pat_id, 'pt2')
    included_channels = [1:19 21:37 43 44 47:74 75 79]; %pt2
    ezone_labels = {'POLMST1', 'POLPST1', 'POLTT1'}; %pt2
    earlyspread_labels = {'POLTT2', 'POLAST2', 'POLMST2', 'POLPST2', 'POLALEX1', 'POLALEX5'};
elseif strcmp(pat_id, 'JH105')
    included_channels = [1:4 7:12 14:19 21:37 42 43 46:49 51:53 55:75 78:99]; % JH105
    ezone_labels = {'POLRPG4', 'POLRPG5', 'POLRPG6', 'POLRPG12', 'POLRPG13', 'POLG14',...
        'POLAPD1', 'POLAPD2', 'POLAPD3', 'POLAPD4', 'POLAPD5', 'POLAPD6', 'POLAPD7', 'POLAPD8', ...
        'POLPPD1', 'POLPPD2', 'POLPPD3', 'POLPPD4', 'POLPPD5', 'POLPPD6', 'POLPPD7', 'POLPPD8', ...
        'POLASI3', 'POLPSI5', 'POLPSI6', 'POLPDI2'}; % JH105
end
%% Define epileptogenic zone
dataDir = fullfile('./adj_mats_500_05/', patient);
fid = fopen(strcat('./data/',patient, '/', patient, '_labels.csv')); % open up labels to get all the channels
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

%% Initialize Variables
% initialize avge fragility, fragility/time/channel, colsum, rowsum
% heatmaps
matFiles = dir(fullfile(dataDir, '*.mat'));
matFiles = {matFiles.name};                     % cell array of all mat file names in order
matFiles = natsortfiles(matFiles);

timeRange = length(matFiles);

timeIndices = [];                               % vector to store time indices of each window of data
avge_minPerturb = zeros(timeRange,1);     % store the avge fragility from all channels @ each time
ezone_minPerturb_fragility = zeros(timeRange,1); % from only ezone channels

minPerturb_time_chan = zeros(length(included_channels), ... % fragility at each time/channel
                    timeRange);
colsum_time_chan = zeros(length(included_channels), ... % colsum at each time/channel
                    timeRange);
rowsum_time_chan = zeros(length(included_channels), ... % rowsum at each time/channel
                    timeRange);

% loop through mat files and open them upbcd
iTime = 1; % time pointer for heatmaps
tic;
for i=1:length(matFiles)
    %%- 01: Extract File and Information
    matFile = matFiles{i};
    data = load(fullfile(dataDir, matFile));
    data = data.data;
    
    theta_adj = data.theta_adj;
    timewrtSz = data.timewrtSz;
    index = data.index;
    if (i == 1) % only set these variables once -> save time
        timeStart = data.timeStart / 1000;
        timeEnd = data.timeEnd / 1000;
        seizureTime = data.seizureTime / 1000;
        winSize = data.winSize;
        stepSize = data.stepSize;
    end
    
    % store all the time indices with respect to seizure
    timeIndices = [timeIndices; timewrtSz];
    
    %%- 02:Compute Minimum Norm Perturbation
    % determine which indices have eigenspectrums that are stable
    max_eig = max(abs(eig(theta_adj)));
    if (max_eig < sigma0) % this is a stable eigenspectrum
        N = size(theta_adj, 1); % number of rows
        del_size = zeros(N, length(w));
        del_table = cell(N, length(w));
        minPerturb_table = zeros(N, 1);
 
        %%- grid search over sigma and w for each row to determine, what is
        %%- the fragility.
        for iNode=1:N
            ek = [zeros(iNode-1, 1); 1; zeros(N-iNode,1)]; % unit vector at this node
            A = theta_adj; 
            
            for iW=1:length(w) % loop through frequencies
                lambda = sigma(iW) + 1i*w(iW);

                % row perturbation inversion
                if (perturbationType == 'R')
                    C = ek'*inv(A - lambda*eye(N));                
                elseif (perturbationType == 'C')
                    C = inv(A - lambda*eye(N))*ek; 
                end
                Cr = real(C);
                Ci = imag(C);
                B = [Ci; Cr];
                
                del = B'*inv(B*B')*b;
                
                del_size(iNode, iW) = norm(del); % store the l2-norm of the perturbation
                del_table{iNode, iW} = del;
            end
            
            % store fragility, for each node at a certain time point
            minPerturb_time_chan(iNode, iTime) = min(del_size(iNode,:));
            
            % find column for each row of minimum norm perturbation
            [r, c] = ind2sub([N length(w)], find(del_size == min(del_size(iNode, :))));
            r = r(1); c = c(1);
            ek = [zeros(r-1, 1); 1; zeros(N-r, 1)]; % unit vector at this row
            
            % store the minimum norm perturbation for each node
            minPerturb_table(iNode) = del_size(iNode, c);
        end % end of loop through channels
        
        %%- 03: Store Results (colsum, rowsum, perturbation,
        % store col/row sum of adjacency matrix
        colsum_time_chan(:, iTime) = sum(theta_adj, 1);
        rowsum_time_chan(:, iTime) = sum(theta_adj, 2);
        
        % update list of average fragility at this time point
        avge_minPerturb(iTime) = mean(minPerturb_table);
        ezone_minPerturb_fragility(iTime) = mean(minPerturb_table(ezone_indices));
        
        % update pointer for the fragility heat map
        iTime = iTime+1;
        
%         %%- Plot 1 time point
%         plotPoints = 1:size(theta_adj,1);
%         plotPoints(ezone_indices) = [];
%         figure;
%         subplot(311);
%         titleStr = ['Eigenspectrum of A\b=x for ', patient];
%         plot(eig(theta_adj), 'ko'); hold on;
%         plot(sigma, w, 'ro')
%         title(titleStr);
%         xlabel('Real'); ylabel('Imaginary');
%     
%         subplot(312);
%         imagesc(theta_adj); 
%         colorbar(); colormap('jet');
%         xlabel('Electrodes Affecting Other Channels');
%         ylabel('Electrodes Affected By Other Channels');
%         
%         subplot(313);
%         plot(plotPoints, fragility_table(plotPoints), 'ko'); hold on;
%         plot(ezone_indices, fragility_table(ezone_indices), 'ro');
%         title(['Fragility Per Electrode at ', num2str(timeSStart - currenttime), ' seconds before seizure']);
%         xlabel(['Electrodes (n=', num2str(N),')']);
%         ylabel(['Minimum Norm Perturbation at Certain w']);
        max_eig
        i
        max(imag(eig(theta_adj)))
    end
end
toc

xIndices = 1:(size(minPerturb_time_chan,2)-20);
save(fullfile(dataDir,'finaldata', strcat(patient,'final_data.mat')), 'avge_minPerturb', 'ezone_minPerturb_fragility', ...
                                'minPerturb_time_chan', 'colsum_time_chan', 'rowsum_time_chan');

fig = {};
% chanticks = 5:5:85;
LT = 1.5;
FONTSIZE=18;

% reset where everything is
avge_minPerturb = avge_minPerturb(xIndices);
ezone_minPerturb_fragility = ezone_minPerturb_fragility(xIndices);
minPerturb_time_chan = minPerturb_time_chan(:,xIndices);
colsum_time_chan = colsum_time_chan(:,xIndices);
rowsum_time_chan = rowsum_time_chan(:,xIndices);

%%- PLOT THE HEATMAP OF FRAGILITY 
fig{end+1} = figure(1);
imagesc(minPerturb_time_chan); hold on;
c = colorbar(); colormap('jet'); set(gca,'box','off')
XLim = get(gca, 'xlim'); XLowerLim = XLim(1); XUpperLim = XLim(2);
% set title, labels and ticks
xticks = (timeStart - seizureTime) : 5 : (timeEnd - seizureTime);
titleStr = {'Minimum Norm Perturbation For All Channels', ...
    'Time Locked To Seizure'};
title(titleStr, 'FontSize', FONTSIZE+2);
ylabel(c, 'Minimum L2-Norm Perturbation');
xlabel('Time (sec)', 'FontSize', FONTSIZE);  ylabel('Electrode Channels', 'FontSize', FONTSIZE);
set(gca, 'FontSize', FONTSIZE-3, 'LineWidth', LT);
set(gca, 'XTick', (XLowerLim+0.5:10:XUpperLim+0.5)); set(gca, 'XTickLabel', xticks); % set xticks and their labels
set(gca, 'YTick', [1, 5:5:length(included_channels)]);
xlim([XLowerLim XUpperLim+1]); % increase the xlim by 1, to mark regions of EZ
% add the labels for the EZ electrodes (rows)
% set(gca, 'clim', [0 0.35]);

plot(repmat(XUpperLim+1, length(ezone_indices),1), ezone_indices, '*r');
for i=1:length(ezone_labels)
    x1 = XLowerLim + 0.01;
    x2 = XUpperLim - 0.01;
    x = [x1 x2 x2 x1 x1];
    y1 = ezone_indices(i)-0.5;
    y2 = ezone_indices(i)+0.5;
    y = [y1 y1 y2 y2 y1];
    plot(x, y, 'r-', 'LineWidth', 2.5);
end
legend('EZ Electrodes');


% PLOT COLSUM: how this channel affects all other channels
fig{end+1} = figure;
imagesc(colsum_time_chan); hold on;
c = colorbar(); colormap('jet'); set(gca,'box','off')
XLim = get(gca, 'xlim'); XLowerLim = XLim(1); XUpperLim = XLim(2);

xticks = (timeStart - seizureTime) : 5 : (timeEnd - seizureTime);
titleStr = {'Column Sum of Matrix A For Each Channel', ...
    'Time Locked To Seizure'};
title(titleStr, 'FontSize', FONTSIZE+2);
ylabel(c, 'Column Sum');
xlabel('Time (sec)', 'FontSize', FONTSIZE);  ylabel('Electrode Channels', 'FontSize', FONTSIZE);
set(gca, 'FontSize', FONTSIZE-3, 'LineWidth', LT);
set(gca, 'XTick', (XLowerLim+0.5:10:XUpperLim+0.5)); set(gca, 'XTickLabel', xticks); % set xticks and their labels
set(gca, 'YTick', [1, 5:5:length(included_channels)]);
xlim([XLowerLim XUpperLim+1]); % increase the xlim by 1, to mark regions of EZ
% add the labels for the EZ electrodes (rows)
plot(repmat(XUpperLim+1, length(ezone_indices),1), ezone_indices, '*r');
for i=1:length(ezone_labels)
    x1 = XLowerLim + 0.01;
    x2 = XUpperLim - 0.01;
    x = [x1 x2 x2 x1 x1];
    y1 = ezone_indices(i)-0.5;
    y2 = ezone_indices(i)+0.5;
    y = [y1 y1 y2 y2 y1];
    plot(x, y, 'r-', 'LineWidth', 2.5);
end
legend('EZ Electrodes');


% PLOT ROWSUM: how all channels affect this channel
fig{end+1} = figure;
imagesc(rowsum_time_chan); hold on;
c = colorbar(); colormap('jet'); set(gca,'box','off')
titleStr = {'Row Sum of Matrix A For Each Channel', ...
    'Time Locked To Seizure'};
title(titleStr, 'FontSize', FONTSIZE+2);
ylabel(c, 'Row Sum');
xlabel('Time (sec)', 'FontSize', FONTSIZE);  ylabel('Electrode Channels', 'FontSize', FONTSIZE);
set(gca, 'FontSize', FONTSIZE-3, 'LineWidth', LT);
set(gca, 'XTick', (XLowerLim+0.5:10:XUpperLim+0.5)); set(gca, 'XTickLabel', xticks); % set xticks and their labels
set(gca, 'YTick', [1, 5:5:length(included_channels)]);
xlim([XLowerLim XUpperLim+1]); % increase the xlim by 1, to mark regions of EZ
% add the labels for the EZ electrodes (rows)
plot(repmat(XUpperLim+1, length(ezone_indices),1), ezone_indices, '*r');
for i=1:length(ezone_labels)
    x1 = XLowerLim + 0.01;
    x2 = XUpperLim - 0.01;
    x = [x1 x2 x2 x1 x1];
    y1 = ezone_indices(i)-0.5;
    y2 = ezone_indices(i)+0.5;
    y = [y1 y1 y2 y2 y1];
    plot(x, y, 'r-', 'LineWidth', 2.5);
end
legend('EZ Electrodes');

% PLOT average fragility 
fig{end+1} = figure;
plot(avge_minPerturb, 'ko'); hold on; set(gca,'box','off')
plot(ezone_minPerturb_fragility, 'r*');
titleStr = {'Averaged Minimum Norm Perturbation Across All Channels', ...
    'Time Locked To Seizure'};
title(titleStr, 'FontSize', FONTSIZE+2);
xlabel('Time (sec)', 'FontSize', FONTSIZE);  
ylabel('Minimum L2-Norm Perturbation', 'FontSize', FONTSIZE);
set(gca, 'FontSize', FONTSIZE-3, 'LineWidth', LT);
legend('All Channels', 'EZ Channels');
set(gca, 'XTick', (XLowerLim+0.5:10:XUpperLim+0.5)); set(gca, 'XTickLabel', xticks); 

%% Compute Fragility Ranking
% for the minPerturb_time_chan = x. (max(col(x)) - x) / max(col(x)) =>
% fragility weight on each electrode

fragility_rankings = zeros(size(minPerturb_time_chan,1),size(minPerturb_time_chan,2));
% loop through each channel
for i=1:size(minPerturb_time_chan,1)
    for j=1:size(minPerturb_time_chan, 2) % loop through each time point
        fragility_rankings(i,j) = (max(minPerturb_time_chan(:,j)) - minPerturb_time_chan(i,j)) ...
                                    / max(minPerturb_time_chan(:,j));
    end
end

% how all channels affect this channel
fig{end+1} = figure;
imagesc(fragility_rankings); hold on;
c = colorbar(); colormap('jet'); set(gca,'box','off')
titleStr = {'Fragility Ranking Of Each Channel', ...
    'Time Locked To Seizure'};
title(titleStr, 'FontSize', FONTSIZE+2);
ylabel(c, 'Fragility Ranking');
xlabel('Time (sec)', 'FontSize', FONTSIZE);  ylabel('Electrode Channels', 'FontSize', FONTSIZE);
set(gca, 'FontSize', FONTSIZE-3, 'LineWidth', LT);
set(gca, 'XTick', (XLowerLim+0.5:10:XUpperLim+0.5)); set(gca, 'XTickLabel', xticks); % set xticks and their labels
set(gca, 'YTick', [1, 5:5:length(included_channels)]);
xlim([XLowerLim XUpperLim+1]); % increase the xlim by 1, to mark regions of EZ
% add the labels for the EZ electrodes (rows)
plot(repmat(XUpperLim+1, length(ezone_indices),1), ezone_indices, '*r');
for i=1:length(ezone_labels)
    x1 = XLowerLim + 0.01;
    x2 = XUpperLim - 0.01;
    x = [x1 x2 x2 x1 x1];
    y1 = ezone_indices(i)-0.5;
    y2 = ezone_indices(i)+0.5;
    y = [y1 y1 y2 y2 y1];
    plot(x, y, 'r-', 'LineWidth', 2.5);
end
legend('EZ Electrodes');


