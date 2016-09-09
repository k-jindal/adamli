% clear all;
% close all;

% define w0/w and sigma for the frequency range to grid search over
w0 = 1;
w = linspace(-1, w0, 101); 
% sigma = linspace(0, sigma0, 100);
sigma0 = 1.1;
sigma = sqrt(sigma0^2 - w.^2); % move to the unit circle 1, for a plethora of different radial frequencies
b = [0; 1];
perturbationType = 'R';
pat_id = 'pt1';
sz_id = 'sz2';
patient = strcat(pat_id, sz_id);
included_channels = [1:36 42 43 46:54 56:69 72:95];

% define epileptogenic zone
dataDir = fullfile('./adj_mats_500_05/', patient);
fid = fopen(strcat('./data/',patient, '/', patient, '_labels.csv'));
labels = textscan(fid, '%s', 'Delimiter', ',');
labels = labels{:}; labels = labels(included_channels);
fclose(fid);
ezone_labels = {'POLPST1', 'POLPST2', 'POLPST3', 'POLAD1', 'POLAD2'}; %ptsz1

% define cell function to search for the EZ labels
cellfind = @(string)(@(cell_contents)(strcmp(string,cell_contents)));
ezone_indices = zeros(length(ezone_labels),1);
for i=1:length(ezone_labels)
    indice = cellfun(cellfind(ezone_labels{i}), labels, 'UniformOutput', 0);
    indice = [indice{:}];
    test = 1:length(labels);
    ezone_indices(i) = test(indice);
end

% initialize avge fragility, fragility/time/channel, colsum, rowsum
% heatmaps
matFiles = dir(fullfile(dataDir, '*.mat'));
matFiles = {matFiles.name};
filerange = length(matFiles);

timeRange = 35:84;
timeSStart = 85;
szIndex = 0;
timeIndices = [];
avge_fragility = zeros(filerange,1); % from all channels
ezone_avge_fragility = zeros(filerange,1); % from only ezone channels
frag_time_chan = zeros(length(included_channels), filerange);
colsum_time_chan = zeros(length(included_channels), filerange);
rowsum_time_chan = zeros(length(included_channels), filerange);

% loop through mat files and open them upbcd
iTime = 1; % time pointer for heatmaps
tic;
for i=1:filerange
    matFile = matFiles{i};
    load(fullfile(dataDir, matFile));
    
    indexTime = strfind(matFile, '_');
    indexMat = strfind(matFile, '.mat');
    currenttime = str2double(matFile(indexTime+1:indexMat-1));
    timeIndices = [timeIndices; currenttime];
    
    % set the seizure index for plotting
    if timeSStart == currenttime
        szIndex = i;
    end
    
    
    %%- determine which indices have eigenspectrums that are stable
    max_eig = max(abs(eig(theta_adj)));
    if (max_eig < sigma0) % this is a stable eigenspectrum
        N = size(theta_adj, 1); % number of rows
        del_size = zeros(N, length(w));
        del_table = cell(N, length(w));
        fragility_table = zeros(N, 1);
 
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
                
                del_size(iNode, iW) = norm(del); % store the norm of the perturbation
                del_table{iNode, iW} = del;
            end
            
            % store fragility, for each node at a certain time point
            frag_time_chan(iNode, iTime) = min(del_size(iNode,:));
            
            % find column for each row of minimum norm perturbation
            [r, c] = ind2sub([N length(w)], find(del_size == min(del_size(iNode, :))));
            r = r(1); c = c(1);
            ek = [zeros(r-1, 1); 1; zeros(N-r, 1)]; % unit vector at this row
            
            % store the fragility for each node
            fragility_table(iNode) = del_size(iNode, c);
        end % end of loop through channels
        
        % store col/row sum of adjacency matrix
        colsum_time_chan(:, iTime) = sum(theta_adj, 1);
        rowsum_time_chan(:, iTime) = sum(theta_adj, 2);
        
        % update list of average fragility at this time point
        avge_fragility(iTime) = mean(fragility_table);
        ezone_avge_fragility(iTime) = mean(fragility_table(ezone_indices));
        
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
%          
        max_eig
        i
        max(imag(eig(theta_adj)))
    end
end
toc

% chanticks = 5:5:85;
LT = 1.5;
FONTSIZE=16;
xIndices = 1:110;

%%- PLOT THE HEATMAP OF FRAGILITY 
titleStr = {'Minimum L2-Norm Perturbation For All Channels', ...
    'From 50 Seconds Preseizure to 5 Seconds Postseizure'};
xticks = (timeIndices(1) - timeSStart)-0.5:5:(timeIndices(110) - timeSStart);

figure;
imagesc(frag_time_chan(:, xIndices)); hold on;
colorbar(); colormap('jet');
XLim = get(gca, 'xlim');
XLowerLim = XLim(1);
XUpperLim = XLim(2);

% set title, labels and ticks
title(titleStr, 'FontSize', FONTSIZE+4);
xlabel('Time (sec)', 'FontSize', FONTSIZE);  ylabel('Electrode Channels', 'FontSize', FONTSIZE);
set(gca, 'FontSize', FONTSIZE-4);
colorbar(); colormap('jet');
XLim = get(gca, 'xlim');
XLowerLim = XLim(1);
XUpperLim = XLim(2);
set(gca, 'FontSize', FONTSIZE-4);
set(gca, 'XTick', [XLowerLim+0.5:5:XUpperLim]);
set(gca, 'XTickLabel', xticks);


xlim([XLowerLim 121]);
plot(repmat(121, length(ezone_indices),1), ezone_indices, '*r');
% set(gca, 'YTick', chanticks);
for i=1:length(ezone_labels)
    plot(get(gca, 'xlim')-1, [ezone_indices(i)-0.5 ezone_indices(i)-0.5], 'k', 'LineWidth', LT);
    plot(get(gca, 'xlim')-1, [ezone_indices(i)+0.5 ezone_indices(i)+0.5], 'k', 'LineWidth', LT);
end

% how this channel affects all other channels
figure;
imagesc(colsum_time_chan);
colorbar(); colormap('jet');
title('Column Sum From 50 to 1 Seconds Before Seizure For All Chans');
xlabel('Time 50->1 Second');
ylabel('Channels');
% set(gca, 'YTick', chanticks);
hold on
for i=1:length(ezone_labels)
    plot(get(gca, 'xlim'), [ezone_indices(i)-0.5 ezone_indices(i)-0.5], 'k', 'LineWidth', LT);
    plot(get(gca, 'xlim'), [ezone_indices(i)+0.5 ezone_indices(i)+0.5], 'k', 'LineWidth', LT);
end

% how all channels affect this channel
figure;
imagesc(rowsum_time_chan);
colorbar(); colormap('jet');
title('Row Sum From 50 to 1 Seconds Before Seizure For All Chans');
xlabel('Time 50->1 Second');
ylabel('Channels');
% set(gca, 'YTick', chanticks);
hold on
for i=1:length(ezone_labels)
    plot(get(gca, 'xlim'), [ezone_indices(i)-0.5 ezone_indices(i)-0.5], 'k', 'LineWidth', LT);
    plot(get(gca, 'xlim'), [ezone_indices(i)+0.5 ezone_indices(i)+0.5], 'k', 'LineWidth', LT);
end

% average fragility 
figure;
plot(avge_fragility, 'ko'); hold on;
plot(ezone_avge_fragility, 'r*');
title('Averaged Fragility From 50 seconds to 1 second before Seizure');
xlabel('50 seconds -> 1 second before seizure');
ylabel('Fragility (Minimum Norm Perturbation)');
