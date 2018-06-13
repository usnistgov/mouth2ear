%RX_SCRIPT run the receive side of a two location mouth to ear latency test
%
%RX_SCRIPT records the test audio and timecode audio on the receive end.
%The audio is saved to a timestamped file in the rx-dat folder. Additional
%test parameters such as the device used, git revision hash and the number
%of buffer over runs are stored in a .mat file.
%
%The audio file is saved as a 24-bit sterio WAV file sampled at 48 kHz. The
%receive auido is in channel one and the receive timecode audio is in
%channel 2. The file is streamed to disk with AudioFileWriter. This means
%that RX_SCRIPT does not have memory require requirements that grow with
%time but it is limited by the maximum file size for the chosen file
%system. Streaming to disk also means that in the case of an unexpected
%termination of the program there should be recoverable audio.
%
%RX_SCRIPT decides to terminate recordings based on timecode audio levels.
%Input average audio levels of more than 4% full scale are considered
%active. The audio levels are not checked for the first 3 seconds of the
%recording. The average is taken over sections of 1024 samples or, at a
%48 khz sample rate, about 20 ms.
%
%See also tx_script, process


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

%get git status
git_status=gitStatus();
    
%folder name for tx data
rx_dat_fold='rx-data';

%make data direcotry
[~,~,~]=mkdir(rx_dat_fold);


%get start time
dt_start=datetime('now','Format','dd-MMM-yyyy_HH-mm-ss');
%get a string to represent the current date in the filename
dtn=char(dt_start);

%width for a device prompt
dev_w=20;
%initialize prompt array
prompt={};
%initialize text box dimentions array
dims=[];

%add Tx radio ID prompt to dialog
prompt{end+1}='Transmit Device';
dims(end+1,:)=[1,dev_w];
%add Rx radio ID prompt to dialog
prompt{end+1}='Recive Device';
dims(end+1,:)=[1,dev_w];
%add radio system under test prompt
prompt{end+1}='System';
dims(end+1,:)=[1,60];
%add test notes prompt
prompt{end+1}='Please enter notes on test conditions';
dims(end+1,:)=[15,100];

%construct empty response convert to char so inputdlg doesn't wine
resp=cellfun(@char,cell(size(prompt)),'UniformOutput',false);

%prompt the user for test info
resp=inputdlg(prompt,'Test Info',dims,resp);
%check if anything was returned
if(isempty(resp))
    %exit program
    return;
end

%get notes from response
pre_note_array=resp{end};
%get strings from output add a tabs and newlines
pre_note_strings=cellfun(@(s)[char(9),s,newline],cellstr(pre_note_array),'UniformOutput',false);
%get a single string from response
pre_notes=horzcat(pre_note_strings{:});

%open log file
logf=fopen('tests.log','a+');
%set timeformat of start time
dt_start.Format='dd-MMM-yyyy HH:mm:ss';
%write start time, test type and git hash
fprintf(logf,['\n>>Rx Two Loc Test started at %s\n'...
              '\tGit Hash   : %s\n'],char(dt_start),git_status.Hash);
%write Tx device ID
fprintf(logf, '\tTx Device  : %s\n',resp{1});
%wriet Rx device ID
fprintf(logf, '\tRx Device  : %s\n',resp{2});
%write system under test 
fprintf(logf, '\tSystem     : %s\n',resp{end-1});
%write pre test notes
fprintf(logf,'===Pre-Test Notes===\n%s',pre_notes);
%close log file
fclose(logf);

%generate base file name to use for all files
filename=sprintf('Rx_capture_%s.wav',dtn);

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

%we are done, beep to let the user know
beep

%get post test notes
resp=inputdlg('Please enter notes on test conditions','Test Conditions',[15,100]);

%open log file
logf=fopen('tests.log','a+');

%check if dialog was cancled
if(~isempty(resp))
    %get notes from response
    post_note_array=resp{1};
    %get strings from output add a tabs and newlines
    post_note_strings=cellfun(@(s)[char(9),s,newline],cellstr(post_note_array),'UniformOutput',false);
    %get a single string from response
    post_notes=horzcat(post_note_strings{:});

    %write start time to file with notes
    fprintf(logf,'===Post-Test Notes===\n%s',post_notes);
end
%print end of test marker
fprintf(logf,'===End Test===\n\n');
%close log file
fclose(logf);

%generate name for info file
info_name=sprintf('Rx_info_%s.mat',dtn);

%save extra info in .mat file
save(fullfile(rx_dat_fold,info_name),'dev_name','git_status','overRun','pre_notes','post_notes','fs');

%release the audio object
release(RecObj);

%release the file writer object
release(RecWriter);

%print completion message
fprintf('Audio data saved to:\n\t''%s''\n',fullfile(rx_dat_fold,filename));
fprintf('Info saved to:\n\t''%s''\n',fullfile(rx_dat_fold,info_name));

