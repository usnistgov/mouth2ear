%read audio file
[y,fs]=audioread('test.wav');

%check fs and resample if nessicessary
if(fs<44.1e3)
    %resample to 48e3
    y=resample(y,48e3/fs,1);
    %set new fs
    fs=48e3;
end

%reshape y to be a column vector/matrix
y=reshape(y,sort(size(y),'descend'));

%check if there is more than one channel
if(size(y,2)>1)
    %warn user
    warning('audio file has %i channels. discarding all but channel 1',size(y,2));
    %get first column
    y=y(:,1);
end

%maximum size for a run
max_size=2e3;

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

%get git status
git_status=gitStatus();

%make plots direcotry
[~,~,~]=mkdir('plots');

%make data direcotry
[~,~,~]=mkdir('data');

%get a string to represent the current date in the filename
dtn=char(datetime('now','Format','dd-MMM-yyyy_HH-mm-ss'));

%open test type file
test_type_f=fopen('test-type.txt');

%check if open was successful
if(test_type_f<0)
    test_type='';
else
    %get line from file
    test_type=fgetl(test_type_f);
    %check for error
    if(~ischar(test_type))
        error('Could not read test type from file');
    end
    %print out test type
    fprintf('Test type : %s\n',test_type);
    %preappend underscore and trim whitespace
    test_type=['_',strtrim(test_type)];
end

%generate base file name to use for all files
base_filename=sprintf('capture%s_%s',test_type,dtn);

%print name and location of run
fprintf('Storing data in:\n\t''%s''\n',fullfile('data',sprintf('%s_x_of_%i.mat',base_filename,runs)));

for kk=1:runs

    %if this is the last run, adjust the run size
    if(kk==runs && kk>1)
        Sr=N-Sr*(runs-1);
    end
    
    %preallocate arrays
    st_idx=zeros(1,Sr);
    st_dly=zeros(1,Sr);
    underRun=zeros(1,Sr);
    overRun=zeros(1,Sr);
    recordings=cell(1,Sr);
    dly_its=cell(1,Sr);

    for k=1:Sr

        %play and record audio data
        [dat,underRun(k),overRun(k)]=play_record(aPR,y);

        %add a pause after play_record to remove run to run dependencys
        pause(3.1);
        
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

        dly_its{k}=1e-3*ITS_delay_wrapper(dat,y',fs);
        %save data
        recordings{k}=dat;

    end
    %save datafile
    save(fullfile('data',sprintf('%s_%i_of_%i.mat',base_filename,kk,runs)),'git_stat','test_type','y','recordings','st_dly','dev_name','underRun','overRun','fs','dly_its','-v7.3');
    
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
    st_idx=zeros(1,N);
    st_dly=zeros(1,N);
    underRun=zeros(1,N);
    overRun=zeros(1,N);
    recordings=cell(1,N);
    dly_its=cell(1,N);

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
        dly_its(rng)   =run_dat.dly_its;
        
        %add run length to position
        pos=pos+run_length;

    end
    
    %save one big file with everything
    save(fullfile('data',[base_filename '_all.mat']),'git_stat','test_type','y','recordings','st_dly','dev_name','underRun','overRun','dly_its','fs','-v7.3');
    
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

%calculate mean ITS delay for each run
its_dly_mean=cellfun(@mean,dly_its);

%calculate delay mean
dly_m=mean(its_dly_mean);

%get engineering units
[dly_m_e,~,dly_u]=engunits(dly_m,'time');

%add mean in title
title(sprintf('Mean : %.2f %s',dly_m_e,dly_u));

%switch to second subplot
subplot(1,2,2);
%plot histogram
histogram(st_dly,300,'Normalization','probability');

%calculate standard deviation
st_dev=std(its_dly_mean);

%get engineering units
[st_dev_e,~,st_u]=engunits(st_dev,'time');

%add Standard Deveation in title
title(sprintf('StD : %.1f %s',st_dev_e,st_u));

%print plot to .png
print(fullfile('plots',[base_filename '.png']),'-dpng','-r600');

