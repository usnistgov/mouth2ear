function [dly_its, rx_rec,rx_name] = process(tx_name,varargin)
%PROCESS process rx and tx files to get mouth to ear latency for a two
%location test
%
%   PROCESS(tx_name) pdrocess a two location test with tx file named
%   tx_name. if no folder is given PROCESS automatically searches in the
%   tx-dat folder for the file. PROCESS searches for a matching rx file in
%   the rx-data folder
%
%   PROCESS(tx_name,name,value) same as above but, specify test parameters
%   using name value pairs. Posible test parameters are shown below:
%
%   NAME        TYPE            Description
%
%   rx_name     char vector     Name of rx file to use. This is used if the
%                               rx file is in a nonstandard location or
%                               with a nonstandard filename. 
%   
%   TcTol       double          Time code tollerence. This changes the
%                               thresholds for what bit periods are
%                               considered a one, zero and frame marker.
%                               For example a TcTol value of 0.05 would
%                               consider a bit period that is within +/- 5%
%                               of the nominal value to be a valid bit. The
%                               default value for TcTol is 0.2
%
%   WinArgs     cell array      Arguments for ITS_delay. The contents of
%                               WinArgs are passed to ITS_delay and control
%                               the window length and window overlap. The
%                               default is {4,2} which gives a window
%                               length of 4 seconds and a window overlap of
%                               2 seconds
%
%   OverPlay    double          Over play is the amount of extra audio to
%                               use from the rx file in seconds. The
%                               default is 1 second
%
%See also tx_script, rx_script
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

%create new input parser
p=inputParser();

%add audio object argument
addRequired(p,'tx_name',@(l)validateattributes(l,{'char'},{'vector'}));
%add output audio argument
addParameter(p,'rx_name',[],@(l)validateattributes(l,{'char'},{'vector'}));
%add timecode tollerence option
addParameter(p,'TcTol',0.2,@(l)validateattributes(l,{'numeric'},{'positive','real','scalar','<=',0.5}));
%add window size and slide arguments
addParameter(p,'winArgs', {4,2},@(l) cellfun(@(x) validateattributes(x,{'numeric'},{'positive','decreasing'}),l));
%add overplay parameter
addParameter(p,'OverPlay',1,@(l)validateattributes(l,{'numeric'},{'real','finite','scalar','nonnegative'}));
% add rx folder parameter
addParameter(p,'rx_folder', 'rx-data', @(l)validateattributes(l,{'char'},{'vector'}));
%add output directory parameter
addParameter(p,'OutDir','',@(n)validateattributes(n,{'char'},{'vector','nonempty'}));

%set parameter names to be case sensitive
p.CaseSensitive= true;

%parse inputs
parse(p,tx_name,varargin{:});

%folder name for tx data
tx_dat_fold=fullfile(p.Results.OutDir,'tx-data');

%check if folder was explicatly specified
if(any(strcmp('rx_folder',p.UsingDefaults)))
    %generate name
    rx_dat_fold=fullfile(p.Results.OutDir,'rx-data');
else
    %use the provided name
    rx_dat_fold=p.Results.rx_folder;
end

%folder name for plots
plots_fold=fullfile(p.Results.OutDir,'plots');

%folder name for processing data
proc_dat_fold=fullfile(p.Results.OutDir,'proc-data');

%make plots direcotry
[~,~,~]=mkdir(plots_fold);

%make data direcotry
[~,~,~]=mkdir(proc_dat_fold);

%tolerence for timecode variation
tc_tol=0.0001;

%split tx filename
[tx_fold,tx_name_only,~]=fileparts(p.Results.tx_name);

%check if tx_folder given
if(isempty(tx_fold))
    %add tx folder to path
    tx_name=fullfile(tx_dat_fold,p.Results.tx_name);
else
    %just use given filename
    tx_name=p.Results.tx_name;
end

%load data from transmit side
tx_dat=load(tx_name);
% Define index for non-empty recordings from tx_dat
ix = cellfun(@(x) ~isempty(x), tx_dat.recordings);
% Check for empty recordings from tx_dat
if(sum(ix)/length(ix) ~= 1)
    % Remove empty recordings from tx_dat
    tx_dat.recordings = tx_dat.recordings(ix);
    tx_dat.overRun = tx_dat.overRun(ix);
    tx_dat.underRun = tx_dat.underRun(ix);
end
%check if rx filename given
if(isempty(p.Results.rx_name))
    %split tx filename
    tx_parts=split(tx_name_only,'_');
    %check prefix
    if(~(strcmp(tx_parts{1},'Tx') && strcmp(tx_parts{2},'capture')))
        %give error
        error('Tx filename "%s" is not in the propper form. Can not determine Rx filename',p.Results.tx_name);
    end
    %check if we have a test type
    if(length(tx_parts)==7)
        tx_datestr=[tx_parts{3} '_' tx_parts{4}];
    elseif(length(tx_parts)==8)
        tx_datestr=[tx_parts{4} '_' tx_parts{5}];
    else
        tx_datestr=[tx_parts{end-1} '_' tx_parts{end}];
    end
    %attempt to get date from tx filename
    tx_date=datetime(tx_datestr,'InputFormat','dd-MMM-yyyy_HH-mm-ss');
    
    %list files in the recive folder
    names=cellstr(ls(fullfile(rx_dat_fold,'Rx_capture_*')));
    
    %check that files were found
    if(isempty(names))
        error('Files not found in Rx folder');
    end
    
    found=0;
    
    for k=1:length(names)
        %extract date string from filename
        [~,dstr]=fileparts(erase(names{k},'Rx_capture_'));
        
        %get the date in the file
        rx_date_start=datetime(dstr,'InputFormat','dd-MMM-yyyy_HH-mm-ss');
        
        %read info on the audio file
        info=audioinfo(fullfile(rx_dat_fold,names{k}));
        
        %calculate the stop time
        rx_date_end=rx_date_start+seconds(info.Duration);
        
        %check that tx date falls within rx file time
        if(tx_date>rx_date_start && tx_date<rx_date_end)
            %flag as found
            found=1;
            %set rx filename
            rx_name=fullfile(rx_dat_fold,names{k});
            %print out filename
            fprintf('Rx file found "%s"\n',rx_name);
            %exit the loop
            break;
        end
    end
    
    %check that a file was found
    if(~found)
        %file not found, give error
        error('Could not find a suitable Rx file');
    end
    
else
    %split rx filename and retain folder
    rx_fold=fileparts(p.Results.rx_name);
    
    %check if rx_folder given
    if(isempty(rx_fold))
        %add folder to filename
        rx_name=fullfile(rx_dat_fold,p.Results.rx_name);
    else
        %use name as given
        rx_name=p.Results.rx_name;
    end
end
    

%load data from recive side
[rx_dat,rx_fs]=audioread(rx_name);

%decode timecode from recive waveform
[rx_time,rx_fsamp]=time_decode(rx_dat(:,2),rx_fs,'TcTol',p.Results.TcTol);

%check if test type is present in tx file
if(isfield(tx_dat,'test_type'))
    %if it exists, get it
    test_type=tx_dat.test_type;
else
    %if not use empty string
    test_type='';
end

%get the first timecode from the rx side as a string
base_filename=sprintf('Capture%s_%s',test_type,char(datetime(rx_time(1),'Format','dd-MMM-yyyy_HH-mm-ss')));

%check to see that sample rates match
if(rx_fs~=tx_dat.fs)
    %error data must have matching sample rates
    error('Recive and transmit sample rates must match')
end

%calculate extra samples needed for rx waveform
exra_samples=p.Results.OverPlay*rx_fs;

%prealocate arrays
dly_its=cell(1,length(tx_dat.recordings));
mfdr=cell(1,length(tx_dat.recordings));
tx_tc=cell(1,length(tx_dat.recordings));
rx_rec=cell(1,length(tx_dat.recordings));
good=zeros(1,length(tx_dat.recordings),'logical');

%check if we have audio clip index
if(~isfield(tx_dat,'clipi'))
    %generate clip index. wrap around after each clip is used
    clipi=mod(1:length(tx_dat.recordings),length(tx_dat.y))+1;
end

%loop through all transmit recordings
for k=1:length(tx_dat.recordings)
    %decode timecode
    [tx_tc{k},tx_frs]=time_decode(tx_dat.recordings{k},tx_dat.fs,'TcTol',p.Results.TcTol);
    
    %array for index of matching timecodes
    tc_match=zeros(size(tx_tc{k}));
    
    for kk=1:length(tx_tc{k})
        %find where timecode matches
        idx=find(rx_time==tx_tc{k}(kk));
        
        %make sure we found one match
        if(length(idx)==1)
            tc_match(kk)=idx;
        else
            tc_match(kk)=NaN;
        end
    end
    
    %find which timecodes matched
    matched=~isnan(tc_match);
    
    %get matching frame start indicies
    mfr=[tx_frs(matched),rx_fsamp(tc_match(matched))];
    
    %get diffrence between matching timecodes
    mfd=diff(mfr);
    
    %get ratio of samples between matches
    mfdr{k}=mfd(:,1)./mfd(:,2);
    
    if(~all(mfdr{k}<(1+tc_tol) & mfdr{k}>(1-tc_tol)))
        warning('Timecodes out of tolerence for run %i',k);
    else
        good(k)=true;
    end
    
    %calculate first rx sample to use
    first=mfr(1,2)-mfr(1,1)+1;
    
    %calculate last rx sample to use
    last=mfr(end,2)+length(tx_dat.recordings{k})-mfr(end,1)+exra_samples;
    
    %get rx recording data from big array
    rx_rec{k}=rx_dat(first:last,1);
    
    %check if y is a cell
    if(iscell(tx_dat.y))
        %get the correct clip from the cell array
        y=tx_dat.y{clipi(k)}';
    else
        %set y for delay use
        y=tx_dat.y';
    end
    
    %calculate delay
    dly_its{k}=ITS_delay_wrapper(rx_rec{k},y,rx_fs,p.Results.winArgs{:})*1e-3;
end

% new figure
figure

%create cell array of trial numbers
Trial=cellfun(@(a,n)(((1:length(a))-1)/length(a)+n),dly_its,num2cell(1:length(dly_its)),'UniformOutput',false);
%make vector of trial numbers
Trial=horzcat(Trial{:});

%transpose each element of dly_its for concatination
dly_its_t=cellfun(@(a)a',dly_its,'UniformOutput',false);

%create matrix of ITS_delay data
its_mat=horzcat(dly_its_t{:});

%get engineering units
[its_mat_e,~,its_mat_u]=engunits(its_mat,'time');

%plot delay dat
plot(Trial,its_mat_e(:))

%axis lables
xlabel('Trial Number');
ylabel(['Delay [' its_mat_u ']']);

%new figure
figure
% Calculate delay mean
dly_m = mean(its_mat);
% get engineering units
[dly_m_e,~,dly_u] = engunits(dly_m,'time');

% calculate standard deviation
st_dev = std(its_mat);
% get engineering units
[st_dev_e,~,st_u] = engunits(st_dev, 'time');

%plot histogram
histogram(its_mat)
%add mean and standard deveation in title
title(sprintf('Mean : %.2f %s  StD : %.1f %s',dly_m_e,dly_u,st_dev_e,st_u));

%print plot to .png
% print(fullfile(plots_fold,[base_filename '.png']),'-dpng','-r600');
