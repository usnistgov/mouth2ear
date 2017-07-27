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

%set input channel mapping to record timecode
aPR.RecorderChannelMapping=2;

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

%folder name for tx data
tx_dat_fold='tx-data';

%make data direcotry
[~,~,~]=mkdir(tx_dat_fold);

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
base_filename=sprintf('Tx_capture%s_%s',test_type,dtn);

%print name and location of run
fprintf('Storing data in:\n\t''%s''\n',fullfile(tx_dat_fold,sprintf('%s_x_of_%i.mat',base_filename,runs)));

for kk=1:runs

    %if this is the last run, adjust the run size
    if(kk==runs && kk>1)
        Sr=N-Sr*(runs-1);
    end
    
    %preallocate arrays
    underRun=zeros(1,Sr);
    overRun=zeros(1,Sr);
    recordings=cell(1,Sr);

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
        
        %save data
        recordings{k}=dat;

    end
    %save datafile
    save(fullfile(tx_dat_fold,sprintf('%s_%i_of_%i.mat',base_filename,kk,runs)),'git_status','test_type','y','recordings','dev_name','underRun','overRun','fs','-v7.3');
    
    if(kk<runs)
        %clear saved variables
        clear recordings underRun overRun
    
        %pause for 10s to let writing complete
        pause(10);
    end
end

%print out completion message
fprintf('Data collection complete you may now stop data collection on the reciving end\n');

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

%check if there was more than one run meaning that we should load in datafiles
if(runs>1)
    %preallocate arrays
    underRun=zeros(1,N);
    overRun=zeros(1,N);
    recordings=cell(1,N);
    pos=1;

    for k=1:runs

        %get run data
        run_dat=load(fullfile(tx_dat_fold,sprintf('%s_%i_of_%i.mat',base_filename,k,runs)));

        %get run length
        run_length=length(run_dat.recordings);

        %get range of values that are being set
        rng=pos+(0:(run_length-1));

        %put data in larger array
        underRun(rng)  =run_dat.underRun;
        overRun(rng)   =run_dat.overRun;
        recordings(rng)=run_dat.recordings;
        
        %add run length to position
        pos=pos+run_length;

    end
    
    %save one big file with everything
    save(fullfile(tx_dat_fold,[base_filename '_all.mat']),'git_status','test_type','y','recordings','dev_name','underRun','overRun','fs','-v7.3');
    
    %print out that the data was saved
    fprintf('Data file saved in "%s"\n',[base_filename '_all.mat']);
    
end


