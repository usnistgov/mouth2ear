function [fullData] =  process_sessions(descr,datType, tx_path, saveDir, rerun)
% tx_path = 'C:\MCV\device-tst\tx-data';
saveDir = 'C:\MCV\device-tst\proc-data';

% descr = 'US36-pullout-VHF-trunked';
% descr = 'US36-pullout-UHF-trunked';
% descr = 'US36-pullout-UHF-direct';
% descr = 'two-loc-2tc';
% descr = '2loc-2tc-characterization';
% descr = 'VHF-direct-NCAR';
% descr = '2loc-2tc-lab-VHF-Trunked';
% descr = '1loc-Lab-VHF-Trunked';

datName = [saveDir '\' descr, '.mat'];

if(~exist(datName)||rerun)
    disp('Extracting data...')
    [data,rx_list] = loadData(tx_path, 'descriptor', descr, 'datType', datType, 'saveDir', saveDir);
    % Save csv file with rx_files
    rx_list_name = ['rx-files_' descr '.csv'];
    fid = fopen([saveDir, '\', rx_list_name],'w');
    for file = 1:length(rx_list)
        fprintf(fid, '%s\n', rx_list{file});
    end
    fclose(fid);

else
    load(datName)
end



[nFiles,~] = size(data);

figDir = [pwd, '\figures'];
if(~exist(figDir))
   mkdir(figDir); 
end

fullData = cell2mat(data(:,2)');

[nWindows,~] = size(fullData);
timeData = fullData(:);
tit = strrep(descr, '-', ' ');

dataPlot = figure;
dataPlot.InnerPosition(3) = 1120;
subplot(1,2,1)
xV = (1:length(timeData))/nWindows;
plot(xV,timeData)
xlabel('Trial Number')
ylabel('Delay (s)')
title([tit ' Data Sessions'])

% saveas(dataPlot, [figDir, '\', descr, '.fig'])
% saveas(dataPlot, [figDir, '\', descr, '.png'])

% figDir = [pwd, '\figures'];
% if(~exist(figDir))
%    mkdir(figDir); 
% end

% dataPlot = figure;
subplot(1,2,2)
h = histogram(timeData);
% h.BinWidth = 1/20000;
mV = mean(timeData);
sV = std(timeData);
title([tit ' - Mean: ' num2str(mV) ' (s). STD: ' num2str(sV)])

saveas(dataPlot, [figDir, '\', descr, '.fig'])
saveas(dataPlot, [figDir, '\', descr, '.png'])
saveas(dataPlot, [figDir,'\', descr, 'eps'], 'epsc')