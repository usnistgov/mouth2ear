load('chirp.mat','y','fs');

%list of sound device names to use
device_names={'UH-7000','M-Track','Focusrite','UMC204HD','Scarlett'};

%create an object for playback and recording
aPR=audioPlayerRecorder(fs);

%get a list of the audio devices
ad=aPR.getAudioDevices();

%get the first match
devIdx=find(contains(ad,device_names),1);

%set device
aPR.Device=ad{devIdx};


if(size(y,1)==1)
    dat_idx=1;
else
    dat_idx=0;
end

aPR(zeros(length(y),1));

%number of trials
N=80;

%preallocate arrays
st_idx=zeros(size(y,1),N);
st_dly=zeros(size(y,1),N);
recordings=cell(1,N);

for k=1:N

    dat=aPR(y.');

    %get maximum values
    mx=max(dat);

    
    if(dat_idx==0)
        %get index of channel to use
        dat_idx=double(mx(1)<mx(2))+1;
        %get start threshold
        st_th=0.1*mx(dat_idx);
    end

    t_r=((1:length(dat))-1)*1/fs;

    %get start index for waveform
    %st_idx(k)=find(abs(dat(:,dat_idx))>=st_th,1);
    %get start index in seconds
    %st_dly(k)=t_r(st_idx(k));

    st_idx(:,k)=finddelay(y',dat);
    
    st_dly(:,k)=1/fs*st_idx(k);
    
    %plot(t_r(1:(st_idx(k)+200)),dat(1:(st_idx(k)+200),dat_idx),st_dly(k)*[1 1],[0 mx(dat_idx)]);

    %drawnow;

    %save data
    recordings{k}=dat;
    
    %print start delay
    %fprintf('Start Delay : %f ms\n',st_dly*1e3);

end

%new figure
figure;

%split window into subplots
subplot(1,2,1);
%plot histogram
histogram(st_dly(dat_idx,:),'Normalization','probability');

%switch to second subplot
subplot(1,2,2);
%plot histogram
histogram(st_dly(dat_idx,:),300,'Normalization','probability');

%make data direcotry
[~]=mkdir('data');

%get datestr for file name
dtn=datestr(datetime,'dd-mmm-yyyy_HH-MM-SS');

%get device name that was used
dvn=device_names{find(cellfun(@(s)contains(ad{devIdx},s),device_names),1)};

%get full device name
Device_used=ad{devIdx};

%save datafile
save(fullfile('data',sprintf('capture_%s_%s.mat',dvn,dtn)),'recordings','st_dly','Device_used');
