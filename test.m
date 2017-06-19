load('chirp.mat','y','fs');

%create an object for playback and recording
aPR=audioPlayerRecorder(fs);

%set bit depth
aPR.BitDepth='24-bit integer';

%chose which device to use
dev_name=choose_device(aPR);

%print the device used
fprintf('Using "%s" for audio test\n',dev_name);

%number of trials
N=800;

%run size
Sr=min(N,max_size);

%calculate the number of runs that will be required
runs=ceil(N/Sr);


%make plots direcotry
[~,~,~]=mkdir('plots');

%make data direcotry
[~,~,~]=mkdir('data');

%get datestr for file name
dtn=datestr(datetime,'dd-mmm-yyyy_HH-MM-SS');

%generate base file name to use for all files
base_filename=sprintf('capture_%s_%s',dev_name,dtn);

for kk=1:runs

    %if this is the last run, adjust the run size
    if(kk==runs && kk>1)
        Sr=N-Sr*(runs-1);
    end
    
    %preallocate arrays
    st_idx=zeros(size(y,1),Sr);
    st_dly=zeros(size(y,1),Sr);
    underRun=zeros(size(y,1),Sr);
    overRun=zeros(size(y,1),Sr);
    recordings=cell(1,Sr);

    for k=1:Sr

        %play and record audio data
        [dat,underRun(k),overRun(k)]=play_record(aPR,y);

        %get maximum values
        mx=max(dat);

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

        st_idx(:,k)=finddelay(y',dat);

        st_dly(:,k)=1/fs*st_idx(k);


        %save data
        recordings{k}=dat;

    end
    %save datafile
    save(fullfile('data',sprintf('%s_%i_of_%i.mat',base_filename,kk,runs)),'y','recordings','st_dly','dev_name','underRun','overRun','fs','-v7.3');
    
    if(kk<runs)
        %clear saved variables
        clear recordings st_dly underRun overRun
    
        %pause for 10s to let writing complete
        pause(10);
    end
end

%check if there was more than one run meaning that we should load in datafiles
if(runs>1)
    %preallocate arrays
    st_idx=zeros(size(y,1),N);
    st_dly=zeros(size(y,1),N);
    underRun=zeros(size(y,1),N);
    overRun=zeros(size(y,1),N);
    recordings=cell(1,N);

    pos=1;

    for k=1:runs

        %get run data
        run_dat=load(fullfile('data',sprintf('%s_%i_of_%i.mat',base_filename,k,runs)));

        %get run length
        run_length=length(run_dat.recordings);

        %get range of values that are being set
        rng=pos+(0:(run_length-1));

        %put data in larger array
        st_dly(rng)    =run_dat.st_dly;
        underRun(rng)  =run_dat.underRun;
        overRun(rng)   =run_dat.overRun;
        recordings(rng)=run_dat.recordings;
        
        %add run length to position
        pos=pos+run_length;

    end
    
    %save one big file with everything
    save(fullfile('data',[base_filename '_all.mat']),'y','recordings','st_dly','dev_name','underRun','overRun','fs','-v7.3');
    
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
histogram(st_dly,'Normalization','probability');

%calculate delay mean
dly_m=mean(st_dly);

%get engineering units
[dly_m_e,~,dly_u]=engunits(dly_m,'time');

%add mean in title
title(sprintf('Mean : %.2f %s',dly_m_e,dly_u));

%switch to second subplot
subplot(1,2,2);
%plot histogram
histogram(st_dly,300,'Normalization','probability');

%calculate standard deviation
st_dev=std(st_dly);

%get engineering units
[st_dev_e,~,st_u]=engunits(st_dev,'time');

%add Standard Deveation in title
title(sprintf('StD : %.1f %s',st_dev_e,st_u));

%print plot to .png
print(fullfile('plots',[base_filename '.png']),'-dpng','-r600');
