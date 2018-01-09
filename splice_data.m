function splice_data(Test_info)

test_loc_type = Test_info.Type;
disp(['Processing ' test_loc_type])

if(strcmpi(test_loc_type,'1loc'))
    procPath = Test_info.procPath;
    proc_rx_Path = Test_info.procRxPath;
    csv_Path = Test_info.csvPath;
    file_list = Test_info.fileList;
elseif(strcmpi(test_loc_type,'2loc'))
    procPath = Test_info.procPath;
    tx_path = Test_info.txPath;
    rx_path = Test_info.rxPath;
    proc_rx_Path = Test_info.procRxPath;
    proc_tx_Path = Test_info.procTxPath;
    csv_Path = Test_info.csvPath;
    file_list = Test_info.fileList;
    
    
    % if tx directory doen't exist, make it
    if(~exist(proc_tx_Path,'dir'))
        mkdir(proc_tx_Path)
    end
    
    addpath(tx_path);
    % tx directory
    tx_dir = dir(tx_path);
    % tx file names
    tx_names = {tx_dir.name};
    
    addpath(rx_path);
    
else
    error('Invalid Test Type....')
end

% if rx directory doen't exist, make it
if(~exist(proc_rx_Path,'dir'))
    mkdir(proc_rx_Path)
end


% if csv directory doen't exist, make it
if(~exist(csv_Path,'dir'))
    mkdir(csv_Path)
end

% Number of file types
n_types = length(file_list);

% Sampling Rate
fs = 48000;
% Load transmite recording
load([procPath, '\Tx_audio.mat'])
% Save wav file to processed rx folder
audiowrite([proc_rx_Path, '\Tx_audio.wav'],y,fs);

for i = 1:n_types
    %% Set up processed rx files
    disp(['Processing ' file_list{i}])
    % Load processed Rx data
    load([procPath, '\' file_list{i} '-full.mat'])
    % Size of processed data
    [m,~] = size(data);                                                    %#ok loaded from file
    for j = 1:m
        % Delay values for that session
        session_dat = data{j,2};
        % csv directory
        csv_dir = [csv_Path '\' file_list{i}];
        if(~exist(csv_dir, 'dir'))
            mkdir(csv_dir)
        end
        % Name of csv file to store delay values
        csv_file = [csv_dir '\session_' num2str(j) '.csv'];
        % Store delay values in csv
        csvwrite(csv_file, session_dat');
        
        % Session recordings
        session_recs = data{j,3};
        % number of recordings
        [~,nRecs] = size(session_recs);
        % directory to store session wav files
        wdir = [proc_rx_Path, '\', file_list{i}, '\session_', num2str(j)];
        % if directory doen't exist, make it
        if(~exist(wdir,'dir'))
            mkdir(wdir)
        end
        for k = 1:nRecs
           % Name of wav file
           wav_file = [wdir, '\rx', num2str(k), '.wav'];
           % Save recording as wav file
           audiowrite(wav_file, session_recs(:,k),fs);
        end
        
    end
   
    if(strcmpi(test_loc_type,'2loc'))
        %% Set Up Processed tx files
        % Test type directory
        tdir = [proc_tx_Path, '\', file_list{i}];
        % if directory doesn't exist, make it
        if(~exist(tdir,'dir'))
            mkdir(tdir)
        end
        % Description tx files contain
        descr = [file_list{i}, '_'];
        % Identify tx files matching description
        f_ix = cellfun(@(x) contains(x,descr),tx_names);
        % List of tx files
        tx_files = tx_names(f_ix);
        % Rx file dir
        rdir = [tdir, '\rx_sessions'];
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
            for k=1:length(recordings)                                     %#ok loaded from file
                wav_file = [sdir, '\tx', num2str(k), '.wav'];
                audiowrite(wav_file,recordings{k}, fs);
            end
            
            % Identify corresponding rx file
            rx_name = findRx([tx_path '\' tx_files{j}],rx_path);
            copyfile(rx_name,rdir);
            rx_name = strrep(rx_name,[rx_path '\'],'');
            movefile([rdir '\' rx_name], [rdir, '\rx-session_', num2str(j), '.wav']);
        end
    end
end