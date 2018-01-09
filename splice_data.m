function splice_data(Test_info)
%SPLICE_DATA split test data into wav and csv files
%
%   SPLICE_DATA(Test_info)
%
%
%   NAME                TYPE                Description
%   
%   Test_info          struct               Contains directory information
%                                           regarding where current data is
%                                           store and where newly formatted
%                                           data should be stored
%
%   Depending on if the data was for a two location or single location test
%   different fields are required of the struct Test_info
%   --------------------------------------------------------------------
%   One Location Data:
%
%   NAME                TYPE                Description
%   Test_info.Type      char vector         Type of test, either '2loc' or
%                                           '1loc'
%
%   Test_info.procPath  char vector         Path to where processed data
%                                           from process_sessions()
%                                           function are saved as .mat
%                                           files
%
%  Test_info.procRxPath char vector         Path where spliced Rx wav files
%                                           should be saved
%
%   Test_info.csvPath   char vector         Path where spliced csv files
%                                           should be saved
%
%   Test_info.fileList  cell array          List of file names for which
%                                           data needs to be split
%   ---------------------------------------------------------------------
%   Two Location Data:
%
%   NAME                TYPE                Description
%   Test_info.Type      char vector         Type of test, either '2loc' or
%                                           '1loc'
%
%   Test_info.procPath  char vector         Path where processed data
%                                           from process_sessions()
%                                           function are saved as .mat
%                                           files
%
%   Test_info.txPath    char vector         Path where tx data from 
%                                           tx_script saved 
%
%   Test_info.rxPath    char vector         Path where rx data from
%                                           rx_script saved
%
%  Test_info.procRxPath char vector         Path where spliced Rx wav files
%                                           should be saved.
%
%  Test_info.procTxPath char vector         Path where spliced Tx wav files
%                                           should be saved
%
%   Test_info.csvPath   char vector         Path where spliced csv files
%                                           should be saved
%
%   Test_info.fileList  cell array          List of file names for which
%                                           data needs to be split

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
    load(fullfile(procPath,[file_list{i} '-full.mat']))
    % Size of processed data
    [m,~] = size(data);                                                    %#ok loaded from file
    for j = 1:m
        % Delay values for that session
        session_dat = data{j,2};
        % csv directory
        csv_dir = fullfile(csv_Path , file_list{i});
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
        wdir = fullfile(proc_rx_Path, file_list{i}, ['session_', num2str(j)]);
        % if directory doen't exist, make it
        if(~exist(wdir,'dir'))
            mkdir(wdir)
        end
        for k = 1:nRecs
           % Name of wav file
           wav_file = fullfile(wdir, ['rx', num2str(k), '.wav']);
           % Save recording as wav file
           audiowrite(wav_file, session_recs(:,k),fs);
        end
        
    end
   
    if(strcmpi(test_loc_type,'2loc'))
        %% Set Up Processed tx files
        % Test type directory
        tdir = fullfile(proc_tx_Path, file_list{i});
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
        rdir = fullfile(tdir, 'rx_sessions');
        % if directory doesn't exist, make it
        if(~exist(rdir,'dir'))
            mkdir(rdir)
        end
        
        for j = 1:length(tx_files)
            % session folder
            sdir = fullfile(tdir, ['session_', num2str(j)]);
            if(~exist(sdir,'dir'))
                mkdir(sdir)
            end
            % Load tx file
            load(fullfile(tx_path, tx_files{j}))
            for k=1:length(recordings)                                     %#ok loaded from file
                wav_file = fullfile(sdir, ['tx', num2str(k), '.wav']);
                audiowrite(wav_file,recordings{k}, fs);
            end
            
            % Identify corresponding rx file
            rx_name = findRx(fullfile(tx_path , tx_files{j}),rx_path);
            copyfile(rx_name,rdir);
            rx_name = erase(rx_name,rx_path);
            movefile(fullfile(rdir , rx_name), fullfile(rdir, ['rx-session_', num2str(j), '.wav']));
        end
    end
end