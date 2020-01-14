function m2e_2loc_rx(varargin)
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

%create new input parser
p=inputParser();

%add output directory parameter
addParameter(p,'OutDir','',@(n)validateattributes(n,{'char'},{'vector','nonempty'}));

%set parameter names to be case sensitive
p.CaseSensitive= true;

%parse inputs
parse(p,varargin{:});

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
rx_dat_fold=fullfile(p.Results.OutDir,'rx-data');

%file name for log file
log_name=fullfile(p.Results.OutDir,'tests.log');

%file name for test type
test_name=fullfile(p.Results.OutDir,'test-type.txt');

%make data direcotry
[~,~,~]=mkdir(rx_dat_fold);


%get start time
dt_start=datetime('now','Format','dd-MMM-yyyy_HH-mm-ss');
%get a string to represent the current date in the filename
dtn=char(dt_start);


%open test type file
init_tstinfo=readTestState(test_name);

%width for a device prompt
dev_w=20;
%initialize prompt array
prompt={};
%initialize text box dimentions array
dims=[];
%initialize empty response array
resp={};

%add Tx radio ID prompt to dialog
prompt{end+1}='Transmit Device';
dims(end+1,:)=[1,dev_w];
resp{end+1}=init_tstinfo.TxDevice;
%add Rx radio ID prompt to dialog
prompt{end+1}='Recive Device';
dims(end+1,:)=[1,dev_w];
resp{end+1}=init_tstinfo.RxDevice;
%add radio system under test prompt
prompt{end+1}='System';
dims(end+1,:)=[1,60];
resp{end+1}=init_tstinfo.System;
%add Test location prompt
prompt{end+1}='Test Location';
dims(end+1,:)=[1,100];
resp{end+1}=init_tstinfo.Location;
%add test notes prompt
prompt{end+1}='Please enter notes on test conditions';
dims(end+1,:)=[15,100];
resp{end+1}='';

%prompt the user for test info
resp=inputdlg(prompt,'Test Info',dims,resp);
%check if anything was returned
if(isempty(resp))
    %exit program
    return;
else
    %get test state from dialog
    test_info=getTestState(prompt(1:(end-1)),resp(1:(end-1)));
    %write test state
    writeTestState(test_name,test_info);
end

%get notes from response
pre_note_array=resp{end};
%get strings from output add a tabs and newlines
pre_note_strings=cellfun(@(s)[char(9),s,newline],cellstr(pre_note_array),'UniformOutput',false);
%get a single string from response
pre_notes=horzcat(pre_note_strings{:});

%check dirty status
if(git_status.Dirty)
    %local edits, flag as dirty
    gitdty=' dty';
else
    %no edits, don't flag
    gitdty='';
end

%get call stack info to extract current filename
[ST, I] = dbstack('-completenames');
%get current filename parts
[~,n,e]=fileparts(ST(I).file);
%full name of current file without path
fullname=[n e];

%open log file
logf=fopen(log_name,'a+');
%set timeformat of start time
dt_start.Format='dd-MMM-yyyy HH:mm:ss';
%write start time, test type and git hash
fprintf(logf,['\n>>Test started at %s\n'...
              '\tTest Type  : %s\n'...
              '\tGit Hash   : %s%s\n'...
              '\tfilename   : %s\n'],char(dt_start),test_info.testType,git_status.Hash,gitdty,fullname);
%write Tx device ID
fprintf(logf, '\tTx Device  : %s\n',test_info.TxDevice);
%wriet Rx device ID
fprintf(logf, '\tRx Device  : %s\n',test_info.RxDevice);
%write system under test 
fprintf(logf, '\tSystem     : %s\n',test_info.System);
%write system under test
fprintf(logf, '\tArguments     : %s\n',extractArgs(p,ST(I).file));
%write pre test notes
fprintf(logf,'===Pre-Test Notes===\n%s',pre_notes);
%close log file
fclose(logf);

%generate base file name to use for all files
base_filename=sprintf('Rx_capture_%s',dtn);

%generate filename for good data
audio_filename=fullfile(rx_dat_fold,sprintf('%s.wav',base_filename));

%generate name for info file
info_filename=fullfile(rx_dat_fold,sprintf('Rx_info_%s.mat',dtn));

%generate filename for error data
error_filename=fullfile(rx_dat_fold,sprintf('%s_ERROR.mat',base_filename));

%add cleanup function
co=onCleanup(@()cleanFun(error_filename,info_filename,log_name));

%print name and location of run
fprintf('Storing data in:\n\t''%s''\n',audio_filename);

%create an object two write audio data to output file
RecWriter=dsp.AudioFileWriter(audio_filename,'FileFormat','WAV','SampleRate',fs,'DataType','int24');

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

%save extra info in .mat file
save(info_filename,'dev_name','git_status','overRun','pre_notes','fs');

%release the audio object
release(RecObj);

%release the file writer object
release(RecWriter);

%print completion message
fprintf('Audio data saved to:\n\t''%s''\n',audio_filename);
fprintf('Info saved to:\n\t''%s''\n',info_filename);


function cleanFun(err_name,good_name,log_name)
%check if error .m file exists
if(~exist(err_name,'file'))

    prompt='Please enter notes on test conditions';
    
    %check to see if data file is missing
    if(~exist(good_name,'file'))
        %add not to say that this was an error
        prompt=[prompt,newline,'Data file missing, something went wrong'];
    end
    
    %get post test notes
    resp=inputdlg(prompt,'Test Conditions',[15,100]);

    %open log file
    logf=fopen(log_name,'a+');

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

    %check to see if data file exists
    if(exist(good_name,'file'))
        %append post notes to .mat file
        save(good_name,'post_notes','-append');
    end
end