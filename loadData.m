function [data,rx_list] = loadData(varargin)
%LOADDATA Process multiple sessions worth of measurement data
%
%   loadData(name,value) specify paramters as name value pairs. Possible
%   name value pairs are shown below:
%
%   NAME                TYPE                Description
%
%   Path                char vector         File path where measurement
%                                           data to be processed is stored
%
%   datFile             char vector         Name of csv file containing
%                                           file names of the measurement
%                                           data. Supply either datFile or
%                                           descriptor, not both.
%
%   descriptor          char vector         String that is uniquely
%                                           contained within the file names
%                                           of all measurement data to be
%                                           processed. Supply either
%                                           descriptor or datFile, not
%                                           both.
%
%   datType             char vector         Either '1loc' or '2loc'
%                                           depending on if test was a
%                                           single or two location test
%                                           respectively.
%
%   saveDir             char vector         Directory in which processed
%                                           mat file should be saved.
%   

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

%% Parse inputs
p = inputParser;
default_datFile = 'na';
default_descr = 'na';
default_datType = 'na';
default_saveDir = pwd();
default_path = pwd();
default_rx_folder = 'rx-data';

% Path to pull data from
addParameter(p,'Path', default_path);
% Path where rx data stored
addParameter(p,'rx_folder', default_rx_folder);
% Option to include csv file that lists files to load and parse
addParameter(p, 'datFile', default_datFile);
% Option to identify files from descriptor in name
addParameter(p, 'descriptor', default_descr);
% Data as single loc or 2loc
addParameter(p,'datType', default_datType);
% Directory to save data in
addParameter(p,'saveDir', default_saveDir);
% Window Arguments for delays
addParameter(p,'winArgs', {4,2}, @(l) cellfun(@(x) validateattributes(x,{'numeric'},{'positive','decreasing'}),l));
parse(p,varargin{:});

% Directory where measurement data stored
Path = p.Results.Path;
% CSV file of files to load from
datFile = p.Results.datFile;
% Text descriptor of files to load
descr = p.Results.descriptor;
% Designate if data is for 1 or 2 location test
datType = p.Results.datType;
% Directory to save mat file
saveDir = p.Results.saveDir;
%% Set path and extract data file names
addpath(Path);
Dir = dir(Path);
% Toss '.' and '..'
Dir = Dir(3:end);
% Store file names in array
% fNames = extractfield(Dir,'name'); % requires mapping toolbox
fNames = {Dir.name};

if(strcmpi(datFile, 'na') && strcmpi(descr, 'na'))
    %%
    error('No csv data file or file descriptor given')
elseif(~strcmpi(datFile, 'na') && strcmpi(descr, 'na'))
    %% datFile given, descriptor not given
    % Read in desired files
    file = fopen(datFile, 'r', 'n', 'UTF-8');
    fList = textscan(file,'%s', 'Delimiter', ',');
    fclose(file);
    fList = fList{1};
    nFiles = length(fList);
    % Store index of desired files in directory (Dir)
    fIx = find(cell2mat(cellfun(@(x) ismember(x, fList), fNames, 'UniformOutput', 0)));
    
    % store data in cell array
    data = cell(nFiles,3);
    % Store rx_names in cell array
    rx_list = cell(nFiles,1);
    for i = 1:nFiles
        if(strcmpi(datType, '1loc'))
            load(fNames{fIx(i)});
            rx_list{i} = fNames{fIx(i)};
        elseif(strcmpi(datType, '2loc'))
            [dly_its,~,rx_name] = process(fNames{fIx(i)},'rx_folder',p.Results.rx_folder,'winArgs', p.Results.winArgs);
            rx_list{i} = rx_name;
        end
        % first column: file name
        data{i,1} = fNames{fIx(i)};
        % second column: delay values
        data{i,2} = cell2mat(dly_its);
        % third column: recordings
        data{i,3} = cleanRecs(recordings);
    end
    datName = strrep(datFile, '.csv','-full.mat');
elseif(strcmpi(datFile, 'na') && ~strcmpi(descr, 'na'))
    %% datFile not given, descriptor given
    % File indices that contain description
    fIx = cellfun(@(x) contains(x, descr), fNames);
    % File names that contain description
    fList = fNames(fIx);
    % Number of files
    nFiles = length(fList);
    % display number of files matching description
    disp([num2str(nFiles) ' Files found containing ' descr])
    % store data in cell array
    data = cell(nFiles,2);
    % Store rx_names in cell array
    rx_list = cell(nFiles,1);
    for i = 1:nFiles
        if(strcmpi(datType, '1loc'))
            load(fList{i});
            % Record file name 
            rx_list{i} = fList{i};
        elseif(strcmpi(datType, '2loc'))
            [dly_its, recordings,rx_name] = process(fList{i}, 'rx_folder', p.Results.rx_folder, 'winArgs', p.Results.winArgs);
            % recording file name
            rx_list{i} = rx_name;
        else
            error(['datType: ' datType ' is not a valid data type. Supply name value pair of datType'])
        end
        % first column: file name
        data{i,1} = fList{i};
        % second column: delay values
        data{i,2} = cell2mat(dly_its);
        % thrid column: recordings
        data{i,3} = cleanRecs(recordings);
    end
    datName = [descr, '-full.mat'];
else
    %% Both given
    error('Supplied both descriptor and datFile')
end

%% Save a mat file of extracted data
if(saveDir)
    saveF = [saveDir '\' datName];
else
    saveF = datName;
end
% Save full version (with recordings)
save(saveF, 'data', '-v7.3')
% toss '-full' from datName
saveF = strrep(saveF, '-full', '');
% Toss recordings from data
data = data(:,1:2);
% Save small version (without recordings)
save(saveF, 'data')

end

function recMat = cleanRecs(recordings)
% Reorganize recordings from cell array with cells containing recording
% arrays to large matrix with each column corresponding to recordings

% NOTE - recordings not guaranteed to be same length => all recordings
% shorter than the longest recording padded with zeros at end
maxLength = max(cellfun(@(y) length(y), recordings));
% Number of trials in session
nTrials = length(recordings);
% initialize recording matrix, store recordings in columns
recMat = zeros(maxLength, nTrials);
for j= 1:nTrials
    rec = recordings{j};
    recMat(1:length(rec),j) = rec;
end
end