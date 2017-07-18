
%use a sample rate of 48 kHz
fs=48e3;

%create an object for playback and recording
RecObj=audioDeviceReader(fs,'NumChannels',2,'BitDepth','24-bit integer');

%chose which device to use
dev_name=choose_device(RecObj);

%print the device used
fprintf('Using "%s" for audio test\n',dev_name);

%get buffer size
bsz=RecObj. SamplesPerFrame;
    
%folder name for tx data
rx_dat_fold='rx-data';

%make data direcotry
[~,~,~]=mkdir(rx_dat_fold);

%get datestr for file name
dtn=datestr(datetime,'dd-mmm-yyyy_HH-MM-SS');

%generate base file name to use for all files
filename=sprintf('capture_%s_%s.wav',dev_name,dtn);

%create an object two write audio data to output file
RecWriter=dsp.AudioFileWriter(fullfile(rx_dat_fold,filename),'FileFormat','WAV','SampleRate',fs,'DataType','int24');

%print instructions
fprintf('Recording data. Turn down timecode audio volume to stop.\n\n');

%zerro  over runs
overRun=0;

%flag to tell when to quit
done=0;

%number of loops to wait before checking loudness
wait=round(3*fs/bsz); %about 3 seconds

%loop while plot is open
while(~done)
    %read audio data
    [datout,or]=RecObj();

    %write audio data
    RecWriter(datout);
    
    %check if wait time has expired
    if(wait==0)
        %check timecode audio levels
        if(mean(abs(datout(:,2)))<0.04)
            %low audio levels, we are done here
            done=1;
        end
    else
        %subtract one from the wait counter
        wait=wait-1;
    end
    
    %add over runs
    overRun=overRun+or;
end


%check for buffer over runs
if(any(overRun))
    fprintf('There were %i buffer over runs\n',sum(overRun));
else
    fprintf('There were no buffer over runs\n');
end

%release the audio object
release(RecObj);

%release the file writer object
release(RecWriter);

%print completion message
fprintf('Recording complete! data saved to:\n\t''%s''\n',fullfile(rx_dat_fold,filename));
