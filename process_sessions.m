function [fullData] =  process_sessions(descr,datType, tx_path, saveDir, rerun)
%PROCESS_SESSIONS say something about this function!!

%This software was developed by employees of the National Institute of
%Standards and Technology (NIST), an agency of the Federal Government.
%Pursuant to title 17 United States Code Section 105, works of NIST
%employees are not subject to copyright protection in the United States and
%are considered to be in the public domain. Permission to freely use, copy,
%modify, and distribute this software and its documentation without fee is
%hereby granted, provided that this notice and disclaimer of warranty
%appears in all copies.
%
%THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER
%EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY
%WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED
%WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
%FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
%CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
%FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
%LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
%OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
%WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
%OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
%WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
%USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.

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