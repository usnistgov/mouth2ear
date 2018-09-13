function [dly_its]=test(varargin)
%TEST run a mouth to ear latency test
%
%   TEST() runs a mouth-to-ear latency test. This test will run 100 trials
%   playing test.wav into the radio.
%
%   TEST(name,value) same as above but specify test parameters as name
%   value pairs. Possible name value pairs are shown below:
%
%   NAME                TYPE                Description
%   
%   AudioFile           char vector         audio file to use for test.
%                                           Defaults to test.wav
%
%   Trials              double              Number of trials to use for
%                                           test. Defaults to 100
%
%   RadioPort           char vector,string  Port to use for radio
%                                           interface. Defaults to the
%                                           first port where a radio
%                                           interface is detected
%
%   BGNoiseFile         char vector         If this is non empty then it is
%                                           used to read in a noise file to
%                                           be mixed with the test audio.
%                                           Default is no background noise
%
%   BGNoiseVolume       double              scale factor for background
%                                           noise. defaults to 0.1


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

%add optional filename parameter
addParameter(p,'AudioFile','test.wav',@(n)validateattributes(n,{'char'},{'vector','nonempty'}));
%add number of trials parameter
addParameter(p,'Trials',100,@(t)validateattributes(t,{'numeric'},{'scalar','positive'}));
%add radio port parameter
addParameter(p,'RadioPort',[],@(n)validateattributes(n,{'char','string'},{'scalartext'}));
%add background noise file parameter
addParameter(p,'BGNoiseFile',[],@(n)validateattributes(n,{'char'},{'vector'}));
%add background noise volume parameter
addParameter(p,'BGNoiseVolume',0.1,@(n)validateattributes(n,{'numeric'},{'scalar','nonempty','nonnegative'}));
%add audio skip parameter to skip audio at the beginning of the clip
addParameter(p,'AudioSkip',0,@(t)validateattributes(t,{'numeric'},{'scalar','nonnegative'}));
%add ptt wait parameter
addParameter(p,'PTTWait',0.68,@(t)validateattributes(t,{'numeric'},{'scalar','positive'}));



%parse inputs
parse(p,varargin{:});

%vars to save to files
save_vars={'git_status','y','recordings','dev_name','underRun',...
           'overRun','dly_its','st_dly','fs','test_info','p',...
        ...%save pre test notes, post test notes will be appended later
           'pre_notes'};

%read audio file
[y,fs]=audioread(p.Results.AudioFile);

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

%check if a noise file was given
if(~isempty(p.Results.BGNoiseFile))
    %read background noise file
    [nf,nfs]=audioread(p.Results.BGNoiseFile);
    %check if sample rates match
    if(nfs~=fs)
        %resample if nessicessary
        nf=resample(nf,fs/nfs,1);
    end
    %extend noise file to match y
    nf=repmat(nf,ceil(length(y)/length(nf)),1);
    %add noise file to sample
    y=y+p.Results.BGNoiseVolume*nf(1:length(y));
end

%remove first part of audio file if AudioSkip is given
if(p.Results.AudioSkip>0)
    %remove audio from file
    y=y(round(p.Results.AudioSkip*fs):end);
    %check if any aduio is remaining
    if(isempty(y))
        %no audio left, give error
        error('AudioSkip is too large, no audio left to play');
    end
end

%create an object for playback and recording
aPR=audioPlayerRecorder(fs);

%set bit depth
aPR.BitDepth='24-bit integer';

%chose which device to use
dev_name=choose_device(aPR);

%print the device used
fprintf('Using "%s" for audio test\n',dev_name);

%get git status
git_status=gitStatus();

%folder name for data
dat_fold='data';

%folder name for plots
plots_fold='plots';

%file name for log file
log_name='tests.log';

%file name for test type
test_name='test-type.txt';

%make plots direcotry
[~,~,~]=mkdir(plots_fold);

%make data direcotry
[~,~,~]=mkdir(dat_fold);

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

%add test type prompt to dialog
prompt{end+1}='Test Type';
dims(end+1,:)=[1,50];
resp{end+1}=init_tstinfo.testType;
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
%add test notes prompt
prompt{end+1}='Please enter notes on test conditions';
dims(end+1,:)=[15,100];
resp{end+1}='';

%dummy struct for sys_info
test_info=struct('testType','');

%loop while we have an empty test type
while(isempty(test_info.testType))
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
    %check if a test type was given
    if(~isempty(test_info.testType))
        %print out test type
        fprintf('Test type : %s\n',test_info.testType);
        %preappend underscore and trim whitespace
        test_type_str=['_',strtrim(test_info.testType)];
        %test_type_str set, loop will now exit
    end
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
%write pre test notes
fprintf(logf,'===Pre-Test Notes===\n%s',pre_notes);
%close log file
fclose(logf);

%generate base file name to use for all files
base_filename=sprintf('capture%s_%s',test_type_str,dtn);

%generate filename for good data
data_filename=fullfile(dat_fold,sprintf('%s.mat',base_filename));

%generate filename for error data
error_filename=fullfile(dat_fold,sprintf('%s_ERROR.mat',base_filename));

%add cleanup function
co=onCleanup(@()cleanFun(error_filename,data_filename));

%open radio interface
ri=radioInterface(p.Results.RadioPort);

%print name and location of run
fprintf('Storing data in:\n\t''%s''\n',fullfile(dat_fold,sprintf('%s.mat',base_filename)));

%turn on LED when test starts
ri.led(1,true);

if(p.Results.Trials>10)
    %generate check trials vector
    check_trials=0:10:p.Results.Trials;
    %set the first one to trial one
    check_trials(1)=1;
else
    %check at the first run and half way through
    check_trials=[1 round(p.Results.Trials/2)];
    %check if both checks are on the first run
    if(check_trials(2)==1)
        %set the second check trial to the second run
        check_trials(2)=2;
    end
end

try
    %preallocate arrays
    st_idx=zeros(1,p.Results.Trials);
    st_dly=zeros(1,p.Results.Trials);
    underRun=zeros(1,p.Results.Trials);
    overRun=zeros(1,p.Results.Trials);
    recordings=cell(1,p.Results.Trials);
    dly_its=cell(1,p.Results.Trials);

    for k=1:p.Results.Trials

            %push the push to talk button
            ri.ptt(true);
            
            %pause a bit to let the radio access the system
            pause(p.Results.PTTWait);

            %play and record audio data
            [dat,underRun(k),overRun(k)]=play_record(aPR,y);

            %un-push the push to talk button
            ri.ptt(false);

            %add a pause after play_record to remove run to run dependencys
            pause(3.1);

            %check if we should run statistics on this trial
            if(any(check_trials==k))
                fprintf('Run %i of %i complete :\n',k,p.Results.Trials);
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
    save(data_filename,save_vars{:},'-v7.3');

catch err
        
    %add error to dialog prompt
    dlgp=sprintf(['Error Encountered with test:\n'...
                  '"%s"\n'...
                  'Please enter notes on test conditions'],...
                  strtrim(err.message));
    
    %get error test notes
    resp=inputdlg(dlgp,'Test Error Conditions',[15,100]);

    %open log file
    logf=fopen(log_name,'a+');

    %check if dialog was not cancled
    if(~isempty(resp))
        %get notes from response
        post_note_array=resp{1};
        %get strings from output add a tabs and newlines
        post_note_strings=cellfun(@(s)[char(9),s,newline],cellstr(post_note_array),'UniformOutput',false);
        %get a single string from response
        post_notes=horzcat(post_note_strings{:});

        %write start time to file with notes
        fprintf(logf,'===Test-Error Notes===\n%s',post_notes);
    end
    %print end of test marker
    fprintf(logf,'===End Test===\n\n');
    %close log file
    fclose(logf);
    
    %check that all vars exist
    if(exist(char(save_vars),'var'))
        %save all data and post notes
        save(error_filename,save_vars{:},'err','post_notes','-v7.3');
        %print out file location
        fprintf('Data saved in ''%s''',error_filename);
    else
        %save all data and post notes
        save(error_filename,'err','post_notes','-v7.3');
        %print out file location
        fprintf('Dummy data saved in ''%s''',error_filename);
    end
    
    %rethrow error
    rethrow(err);
end

%turn off LED when test stops
ri.led(1,false);

%close radio interface
delete(ri);

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
print(fullfile(plots_fold,[base_filename '.png']),'-dpng','-r600');

%New figure for time plot
figure;

%create matrix of ITS_delay data
its_mat=cell2mat(dly_its);

%get engineering units
[its_mat_e,~,its_mat_u]=engunits(its_mat,'time');

%plot delay dat
plot(its_mat_e(:))

%axis lables
xlabel('Measurement number');
ylabel(['Delay [' its_mat_u ']']);

beep;
pause(1);
beep;



function cleanFun(err_name,good_name)
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

