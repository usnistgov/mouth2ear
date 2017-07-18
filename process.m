

%folder name for tx data
tx_dat_fold='tx-data';

%folder name for rx data
rx_dat_fold='rx-data';

%tolerence for timecode variation
tc_tol=0.0001;

%load data from transmit side
tx_dat=load(fullfile(tx_dat_fold,'capture_UMC ASIO Driver_13-Jul-2017_13-06-16_1_of_1.mat'));

%load data from recive side
[rx_dat,rx_fs]=audioread(fullfile(rx_dat_fold,'Capture_13-Jul-2017.wav'));

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
        mfdr{k}
    end
    
    %calculate first rx sample to use
    first=mfr(1,2)-mfr(1,1)+1;
    
    %calculate last rx sample to use
    last=mfr(end,2)+length(tx_dat.recordings{k})-mfr(end,1);
    
    %get rx recording data from big array
    rx_rec{k}=rx_dat(first:last,1);
    
    %calculate delay
    dly_its{k}=ITS_delay_wrapper(rx_rec{k},tx_dat.y',rx_fs);
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

%add mean and standard deveation in title
title(sprintf('Mean : %.2f %s  StD : %.1f %s',dly_m_e,dly_u,st_dev_e,st_u));

%plot histogram
histogram(dly_its_mean,300,'Normalization','probability');

%print plot to .png
print(fullfile('plots',[base_filename '.png']),'-dpng','-r600');

