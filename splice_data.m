clear all
% Data path to processed data
procPath = 'C:\MCV\device-tst\proc-data';
% Path to Save data
proc_rx_Path = 'C:\MCV\device-tst\proc-data\2loc\processed_rx';
% proc_rx_Path = 'P:\MCV\M2E Latency\Post-Processed Data\2loc\processed_rx';
% if rx directory doen't exist, make it
    if(~exist(proc_rx_Path,'dir'))
        mkdir(proc_rx_Path)
    end

proc_tx_Path = 'C:\MCV\device-tst\proc-data\2loc\processed_tx';
% proc_tx_Path = 'P:\MCV\M2E Latency\Post-Processed Data\2loc\processed_tx';
% if tx directory doen't exist, make it
    if(~exist(proc_tx_Path,'dir'))
        mkdir(proc_tx_Path)
    end
csvPath = 'C:\MCV\device-tst\proc-data\2loc\delay_values';
% csvPath = 'P:\MCV\M2E Latency\Post-Processed Data\2loc\delay_values';
% if csv directory doen't exist, make it
    if(~exist(csvPath,'dir'))
        mkdir(csvPath)
    end
% processed data directory
proc_dir = dir(procPath);
% tx data path
tx_path = 'C:\MCV\device-tst\tx-data';
% tx directory
tx_dir = dir(tx_path);
% tx file names
tx_names = {tx_dir.name};

% rx data path
rx_path = 'C:\MCV\device-tst\rx-data';

% File descriptions
two_loc_list = {'US36-pullout-VHF-trunked';
                'US36-pullout-UHF-trunked';
                'US36-pullout-UHF-direct';
                'VHF-direct-NCAR';
                '2loc-2tc-lab-UHF-Direct';
                '2loc-2tc-lab-UHF-Trunked';
                '2loc-2tc-lab-VHF-Direct';
                '2loc-2tc-lab-VHF-Trunked';
                };
% Number of file types
n_types = length(two_loc_list);
% Sampling Rate
fs = 48000; 
% Load transmite recording
load([procPath, '\Tx_audio.mat'])
% Save wav file to processed rx folder
audiowrite([proc_rx_Path, '\Tx_audio.wav'],y,fs);
for i = 1:n_types
    %% Set up processed rx files
    % Load processed Rx data
    load([procPath, '\' two_loc_list{i} '-full.mat'])
    % Size of processed data
    [m,n] = size(data);
    % Delay values for each trial in one matrix
    fullData = cell2mat(data(:,2)');
    try
        % Try to grab all recordings as columns in matrix
        fullRecs = cell2mat(data(:,3)');
    catch ME
        % If dimension mismatch
        if(strcmpi(ME.identifier, 'MATLAB:catenate:dimensionMismatch'))
            disp([ME.message '...resizing too small recordings'])
            % find max recording length
            mL = max(cellfun(@(x) size(x,1), data(:,3)));
            for j = 1:m
                % Identify session
                sesh = data{j,3};
                % Size of session
                [hN,nTrials] = size(sesh);
               if(hN~=mL)
                   % If session trial lengths not equal to max rec length
                   % append with zeros (silence)
                   hMat = zeros(mL,nTrials);
                   hMat(1:hN,:) = sesh(1:hN,:);
                   data{j,3} = hMat;
               end
            end
            % Successfully organize matrix with columns storing recordings
            fullRecs = cell2mat(data(:,3)');
        end
    end
    % Name of csv file to store delay values
    csv_file = [csvPath, '\', two_loc_list{i}, '.csv'];
    % Store delay values in csv
    csvwrite(csv_file,fullData');
    % Number of recordings
    [~,nRecs] = size(fullRecs);
    % Directory to store wav files
    wdir = [proc_rx_Path,'\',two_loc_list{i}];
    % if directory doen't exist, make it
    if(~exist(wdir,'dir'))
        mkdir(wdir)
    end
    for j = 1:nRecs
        % Name of wav file
        wav_file = [wdir, '\rx', num2str(j), '.wav'];
        % Save recording as wav file
        audiowrite(wav_file,fullRecs(:,j),fs);
    end
    
    %% Set Up Processed tx files
    % Test type directory
    tdir = [proc_tx_Path, '\', two_loc_list{i}];
    % if directory doesn't exist, make it
    if(~exist(tdir,'dir'))
        mkdir(tdir)
    end
    % Description tx files contain
    descr = [two_loc_list{i}, '_'];
    % Identify tx files matching description
    f_ix = cellfun(@(x) contains(x,descr),tx_names);
    % List of tx files
    tx_files = tx_names(f_ix);
    % Rx file dir
    rdir = [tdir, '\rx_sessions']
    % if directory doesn't exist, make it
    if(~exist(rdir,'dir'))
        mkdir(rdir)
    end
    
    for j = 1:length(tx_files)
        % session folder
        sdir = [tdir, '\session_', num2str(j)];
        if(~exist(sdir,'dir'))
            mkdir(sdir)
        end
        % Load tx file
        load([tx_path, '\', tx_files{j}])
        for k=1:length(recordings)
           wav_file = [sdir, '\tx', num2str(k), '.wav'];
           audiowrite(wav_file,recordings{k}, fs);
        end
        
        % Identify corresponding rx file
        rx_name = findRx(tx_files{j});
        copyfile(rx_name,rdir);
        rx_name = strrep(rx_name,'rx-data\','');
        movefile([rdir '\' rx_name], [rdir, '\rx-session_', num2str(j), '.wav']);
    end
end