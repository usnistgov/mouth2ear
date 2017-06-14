load('chirp.mat','y','fs');

%get audio device info
ad=audiodevinfo;

%list of sound device names to use
device_names={'UH-7000','M-Track','Focusrite','UMC','Scarlett'};

input_dev_idx=0;
%find input device
for k=1:length(ad.input)
    %check if device name is what we are looking for
    if(contains(ad.input(k).Name,device_names))
        %get ID of device
        input_dev_idx=k;
        %done
        break;
    end
end

%check that input device was found
if(input_dev_idx==0)
    error('Could not find sutable input device');
end


output_dev_idx=0;
%find matching output device
for k=1:length(ad.output)
    %check if device name is what we are looking for
    if(strcmp(ad.output(k).Name,ad.input(input_dev_idx).Name))
        %get ID of device
        output_dev_idx=k;
        %done
        break;
    end
end

%check that input device was found
if(output_dev_idx==0)
    error('Could not find sutable output device');
end

%get input device id's from index
input_dev=ad.input(input_dev_idx).ID;
%get output device id's from index
output_dev=ad.output(output_dev_idx).ID;

if(size(y,1)==1)
    dat_idx=1;
else
    dat_idx=0;
end

%create audio device objects to use
p=audioplayer(y,fs,24,output_dev);
r=audiorecorder(fs,24,size(y,1),input_dev);

%number of trials
N=800;

%preallocate arrays
st_idx=zeros(size(y,1),N);
st_dly=zeros(size(y,1),N);
underRun=zeros(size(y,1),N);
overRun=zeros(size(y,1),N);
recordings=cell(1,N);

for k=1:N

    %start recording
    record(r);
    %play waveform
    playblocking(p);
    %stop recording
    stop(r)

    %get recorded data
    dat=getaudiodata(r);

    %get maximum values
    mx=max(dat);

    
    if(dat_idx==0)
        %get index of channel to use
        dat_idx=double(mx(1)<mx(2))+1;
        %get start threshold
        st_th=0.1*mx(dat_idx);
    end
    
    if(mod(k,10)==0)
        fprintf('Run %i of %i complete :\n',k,N);
        %calculate RMS
        rms=sqrt(mean(dat.^2));
        %calculate maximum
        [mx,mx_idx]=max(dat);
        %print values
        fprintf('\tMax : %.4f\n\tRMS : %.4f\n\n',mx,rms);
        %check if levels are low
        if(rms<1e-3)
            %print warning
            warning('Low levels input levels detected. RMS = %g',rms);
            %length of plot in sec
            plen=0.01;
            %generate range centered around maximum value
            rng=(mx_idx-round(plen/2*fs)):(mx_idx+round(plen/2*fs));
            if(length(rng)>length(dat))
                rng=1:length(dat);
            end
            %check that we didn't go off of the beginning of the array
            if(rng(1)<1)
                %shift range
                rng=rng-rng(1)+1;
            end
            %check that we didn't go off of the end of the array
            if(rng(end)>length(dat))
                %shift range
                rng=rng+(length(dat)-rng(end));
            end
            %new figure for plot
            figure;
            %generate time axis
            t_r=((1:length(dat))-1)*1/fs;
            %plot graph
            plot(t_r(rng),dat(rng));
            %force drawing
            drawnow;
        end
    end

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

%check for buffer over runs
if(any(overRun))
    fprintf('There were %i buffer over runs\n',sum(overRun));
else
    fprintf('There were no buffer over runs\n');
end

%check for buffer over runs
if(any(underRun))
    fprintf('There were %i buffer under runs\n',sum(underRun));
else
    fprintf('There were no buffer under runs\n');
end

%new figure
figure;

%split window into subplots
subplot(1,2,1);

%plot histogram
histogram(st_dly(dat_idx,:),'Normalization','probability');

%add mean in title
title(sprintf('Mean : %g',mean(st_dly(dat_idx,:))));

%switch to second subplot
subplot(1,2,2);
%plot histogram
histogram(st_dly(dat_idx,:),300,'Normalization','probability');

%add Standard Deveation in title
title(sprintf('StD : %g',std(st_dly(dat_idx,:))));

%get datestr for file name
dtn=datestr(datetime,'dd-mmm-yyyy_HH-MM-SS');

%get device name that was used
dvn=device_names{find(cellfun(@(s)contains(ad.input(input_dev_idx).Name,s),device_names),1)};

%make plots direcotry
[~,~,~]=mkdir('plots');

%print plot to .png
print(fullfile('plots',sprintf('capture_%s_%s.png',dvn,dtn)),'-dpng','-r600');

%make data direcotry
[~,~,~]=mkdir('data');

%name of the device that was used
Device_used=ad.input(input_dev_idx).Name;

%save datafile
save(fullfile('data',sprintf('capture_%s_%s.mat',dvn,dtn)),'recordings','st_dly','Device_used');

