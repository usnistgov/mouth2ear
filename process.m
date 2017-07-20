function process(tx_name,varargin)

%create new input parser
p=inputParser();

%add audio object argument
addRequired(p,'tx_name',@(l)validateattributes(l,{'char'},{'vector'}));
%add output audio argument
addOptional(p,'rx_name',[],@(l)validateattributes(l,{'char'},{'vector'}));

%set parameter names to be case sensitive
p.CaseSensitive= true;

%parse inputs
parse(p,tx_name,varargin{:});

%folder name for tx data
tx_dat_fold='tx-data';

%folder name for rx data
rx_dat_fold='rx-data';

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

%check if rx filename given
if(isempty(p.Results.rx_name))
    %split tx filename
    tx_parts=split(tx_name_only,'_');
    %check prefix
    if(~(strcmp(tx_parts{1},'Tx') && strcmp(tx_parts{2},'capture')))
        %give error
        error('Tx filename "%s" is not in the propper form. Can not determine Rx filename',p.Results.tx_name);
    end
    %attempt to get date from tx filename
    tx_date=datetime([tx_parts{3} '_' tx_parts{4}],'InputFormat','dd-MMM-yyyy_HH-mm-ss');
    
    %list files in the recive folder
    names=cellstr(ls(fullfile('rx-data','Rx_capture_*')));
    
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
        info=audioinfo(fullfile('rx-data',names{k}));
        
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
        rx_name=fullfile(rx_dat_fold,p.results.rx_name);
    else
        %use name as given
        rx_name=p.results.rx_name;
    end
end
    

%load data from recive side
[rx_dat,rx_fs]=audioread(rx_name);

%decode timecode from recive waveform
[rx_time,rx_fsamp]=time_decode(rx_dat(:,2),rx_fs);

%check to see that sample rates match
if(rx_fs~=tx_dat.fs)
    %error data must have matching sample rates
    error('Recive and transmit sample rates must match')
end

%prealocate arrays
dly_its=cell(1,length(tx_dat.recordings));
mfdr=cell(1,length(tx_dat.recordings));
rx_rec=cell(1,length(tx_dat.recordings));

%loop through all transmit recordings
for k=1:length(tx_dat.recordings)
    %decode timecode
    [tx_tc,tx_frs]=time_decode(tx_dat.recordings{k},tx_dat.fs);
    
    %array for index of matching timecodes
    tc_match=zeros(size(tx_tc));
    
    for kk=1:length(tx_tc)
        %find where timecode matches
        idx=find(rx_time==tx_tc(kk));
        
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
    end
    
    %calculate first rx sample to use
    first=mfr(1,2)-mfr(1,1)+1;
    
    %calculate last rx sample to use
    last=mfr(end,2)+length(tx_dat.recordings{k})-mfr(end,1);
    
    %get rx recording data from big array
    rx_rec{k}=rx_dat(first:last,1);
    
    %calculate delay
    dly_its{k}=ITS_delay_wrapper(rx_rec{k},tx_dat.y',rx_fs)*1e-3;
end


%new figure
figure;

%calculate mean delay for each run
dly_its_mean=cellfun(@mean,dly_its);

%calculate delay mean
dly_m=mean(dly_its_mean);

%get engineering units
[dly_m_e,~,dly_u]=engunits(dly_m,'time');

%calculate standard deviation
st_dev=std(dly_its_mean);

%get engineering units
[st_dev_e,~,st_u]=engunits(st_dev,'time');

%plot histogram
histogram(dly_its_mean,300,'Normalization','probability');

%add mean and standard deveation in title
title(sprintf('Mean : %.2f %s  StD : %.1f %s',dly_m_e,dly_u,st_dev_e,st_u));

%print plot to .png
print(fullfile('plots',[base_filename '.png']),'-dpng','-r600');

