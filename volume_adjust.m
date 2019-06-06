function [opt,pmean,volume]=volume_adjust(varargin)
%VOLUME_ADJUST determine optimal volume for a test steup
%
%	[opt,pmean,volume]=VOLUME_ADJUST() will play and record audio in the
%   system to get the optimal volume
%
%	VOLUME_ADJUST(name,value) same as above but specify test parameters as
%	name value pairs. Possible name value pairs are shown below
%
%   NAME                TYPE                Description
%
%   AudioFile           char vector         audio file to use for test. If
%                                           a cell array is given then the
%                                           test is run in succession for
%                                           each file in the array.
%
%   Trials              positive int        Number of trials to run for
%                                           each sample volume.
%
%   SMax				positive integer	Maximum number of sample
%                                           volumes to use. Default 30
%
%   RadioPort           char vector,string  Port to use for radio
%                                           interface. Defaults to the
%                                           first port where a radio
%                                           interface is detected
%
%   Volumes             double vector       Instead of using the golden
%                                           ratio algorithm to determine
%                                           what volumes to sample at,
%                                           explicitly set the volume
%                                           sample points. When this is
%                                           given no optimal volume is
%                                           calculated. Default is an empty
%                                           vector
%
%   DevVolume           double              Volume setting on the device.
%                                           This tells VOLUME_ADJUST what
%                                           the output volume of the audio
%                                           device is. This is taken into
%                                           account when the scaling is
%                                           done for the trials. Default is
%                                           0 dB
%
%   Scaling				logical	 			Scale the clip volume to
%                                           simulate adjusting the device
%                                           volume to the desired level. If
%                                           this is false then the user
%                                           will be prompted every time the
%                                           volume needs to be changed.
%                                           Defaults to true.
%
%   Lim					double vector		TLim must be a 2 element
%                                           numeric vector that is
%                                           increasing. Lim sets the volume
%                                           limits to use for the test in
%                                           dB. Lim defaults to [-40,0].
%
%	OutDir				char vector			Directory that is added to the
%                                           output path for all files
%
%	PTTGap				double				Time to pause after completing
%                                           one trial and starting the
%                                           next. Defaults to 3.1


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

%% ========================[Parse Input Arguments]========================

%create new input parser
p=inputParser();

%add optional filename parameter
addParameter(p,'AudioFile','test.wav',@validateAudioFiles);
%add number of trials per volume level parameter
addParameter(p,'Trials',40,@(t)validateattributes(t,{'numeric'},{'scalar','positive','integer'}));
%add sample limit parameter
addParameter(p,'SMax',30,@(t)validateattributes(t,{'numeric'},{'scalar','positive'}));
%add radio port parameter
addParameter(p,'RadioPort',[],@(n)validateattributes(n,{'char','string'},{'scalartext'}));
%add volumes parameter
addParameter(p,'Volumes',[],@(n)validateattributes(n,{'numeric'},{'vector'}));
%add device volume parameter
addParameter(p,'DevVolume',0,@(n)validateattributes(n,{'numeric'},{'scalar'}));
%add Scaling enable parameter
addParameter(p,'Scaling',true,@(t)validateattributes(t,{'numeric','logical'},{'scalar'}));
%add Limits parameter
addParameter(p,'Lim',[-40,0],@(t)validateattributes(t,{'numeric','logical'},{'vector','size',[1,2],'increasing'}));
%add output directory parameter
addParameter(p,'OutDir','',@(n)validateattributes(n,{'char'},{'scalartext'}));
%add ptt gap parameter
addParameter(p,'PTTGap',3.1,@validate_delay);

%parse inputs
parse(p,varargin{:});

%% ======================[List Vars to save in file]======================
%This is a list of all the files to save in data files. This is don both
%for a normal test run and if an error is encountered. This list is here so
%there is only one place to add new variables that need to be saved in the
%file

save_vars={'git_status','y','recordings','dev_name','underRun',...
            'overRun','fs','volume','opt','a','b','dly_its','rtemp',...
            'pscores','vol_scl_en','clipi',...
        ...%save pre test notes, post test notes will be appended later
           'pre_notes'};


%% ===================[Read in Audio file(s) for test]===================

%check if audio file is a cell array
if(iscell(p.Results.AudioFile))
    %yes, copy
    AudioFiles=p.Results.AudioFile;
else
    %no, create cell array
    AudioFiles={p.Results.AudioFile};
end

%cell array of audio clips to use
y=cell(size(AudioFiles));

%sample audio sample rate to use
fs=48e3;

%read in audio files and perform checks
for k=1:length(AudioFiles)
    %read audio file
    [y{k},fs_file]=audioread(AudioFiles{k});
    
    %check fs and resample if nessicessary
    if(fs_file~=fs)
        %calculate resample factors
        [prs,qrs]=rat(fs/fs_file);
        %resample to 48e3
        y{k}=resample(y{k},prs,qrs);
    end
    
    %reshape y to be a column vector/matrix
    y{k}=reshape(y{k},sort(size(y{k}),'descend'));
    
    %check if there is more than one channel
    if(size(y{k},2)>1)
        %warn user
        warning('audio file has %i channels. discarding all but channel 1',size(y,2));
        %get first column
        y{k}=y{k}(:,1);
    end
    
end


%% ========================[Setup Playback Object]========================

%create an object for playback and recording
aPR=audioPlayerRecorder(fs);

%save scaling status
vol_scl_en=p.Results.Scaling;

%set bit depth
aPR.BitDepth='24-bit integer';

%chose which device to use
dev_name=choose_device(aPR);

%print the device used
fprintf('Using "%s" for audio test\n',dev_name);


%% ===========================[Read git status]===========================
%get git status
git_status=gitStatus();

%% ==================[Initialize file and folder names]==================

%folder name for data
dat_fold=fullfile(p.Results.OutDir,'data');

%folder name for plots
plots_fold=fullfile(p.Results.OutDir,'plots');

%file name for log file
log_name=fullfile(p.Results.OutDir,'tests.log');

%file name for test type
test_name=fullfile(p.Results.OutDir,'test-type.txt');

%make plots direcotry
[~,~,~]=mkdir(plots_fold);

%make data direcotry
[~,~,~]=mkdir(dat_fold);


%% =========================[Get Test Start Time]=========================
%get start time
dt_start=datetime('now','Format','dd-MMM-yyyy_HH-mm-ss');
%get a string to represent the current date in the filename
dtn=char(dt_start);


%% ==================[Get Test info and notes from user]==================

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

%use empty test notes
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

%% ===============[Parse User response and write log entry]===============

%get notes from response
pre_note_array=resp{end};
%get strings from output add a tabs and newlines
pre_note_strings=cellfun(@(s)[char(9),s,newline],cellstr(pre_note_array),'UniformOutput',false);
%get a single string from response
pre_notes=horzcat(pre_note_strings{:});

if(iscell(git_status))
    gstat=git_status{1};
else
    gstat=git_status;
end

%check dirty status
if(gstat.Dirty)
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
    '\tfilename   : %s\n'],char(dt_start),test_info.testType,gstat.Hash,gitdty,fullname);
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


%% =======================[Filenames for data files]=======================

%generate base file name to use for all files
base_filename=sprintf('capture%s_%s',test_type_str,dtn);

%generate filename for good data
data_filename=fullfile(dat_fold,sprintf('%s.mat',base_filename));

%generate filename for error data
error_filename=fullfile(dat_fold,sprintf('%s_ERROR.mat',base_filename));

%generate filename for temporary data
temp_filename=fullfile(dat_fold,sprintf('%s_TEMP.mat',base_filename));


%% ======================[Generate oncleanup object]======================

%add cleanup function
co=onCleanup(@()cleanFun(error_filename,data_filename,log_name));

%% ========================[Open Radio Interface]========================

%open radio interface
ri=radioInterface(p.Results.RadioPort);

%% ========================[Notify user of start]========================
%print name and location of file
fprintf('Storing data in:\n\t''%s''\n',fullfile('data',sprintf('%s.mat',base_filename)));

%only print assumed device volume if scaling is enabled
if(vol_scl_en)
    %print assumed device volume for confermation
    fprintf('Assuming device volume of %.2f dB\n',p.Results.DevVolume);
end

%turn on LED when test starts
ri.led(1,true);

try
    
    %% ========================[preallocate arrays]========================
    %give arrays dummy values so things go faster and mlint doesn't
    %complain
        
    %preallocate arrays
    underRun=zeros(p.Results.Trials,p.Results.SMax);
    overRun=zeros(p.Results.Trials,p.Results.SMax);
    recordings=cell(p.Results.Trials,p.Results.SMax);
    dly_its=cell(p.Results.Trials,p.Results.SMax);
    rtemp=zeros(p.Results.Trials,p.Results.SMax);
    volume=zeros(1,p.Results.SMax);
    pscores=zeros(p.Results.Trials,p.Results.SMax);
    pmean=zeros(p.Results.Trials,p.Results.SMax);
    
    clipi = (mod(1:p.Results.Trials,length(AudioFiles)) + 1)';
    
    %% ==================[Initialize Golden Ratio Values]==================
    
    %minimum volume
    a=p.Results.Lim(1);
    %maximum volume
    b=p.Results.Lim(2);
    
    %golden ratio
    gr = (sqrt(5) + 1) / 2;
    
    if(~isempty(p.Results.Volumes))
        volume=p.Results.Volumes;
    end
    
    %% ========================[Golden Ratio Loop]========================
    
    for k=1:p.Results.SMax
        
        %% ===================[Compute Golden Ratio Points]===================
        
        %check if volumes were given
        if(isempty(p.Results.Volumes))
            %check if k is odd
            if(mod(k,2)==1)
                %check if we have at least 2 points to evaluate
                if(k>=2)
                    %check which measurement has the higest value
                    if(pmean(k-2)>pmean(k-1))
                        b=volume(k-1);
                    else
                        a=volume(k-2);
                    end
                end
                %compute upper eval point (c)
                volume(k)=(b-(b-a)/gr);
            else
                %compute lower eval point (d)
                volume(k)=(a+(b-a)/gr);
            end
            
        end
        
        %check for convergence
        if((b-a)<2)
            %remove unused values
            underRun=underRun(:,1:(k-1));
            overRun=overRun(:,1:(k-1));
            recordings=recordings(:,1:(k-1));                                   %#ok saved in datafile
            dly_its=dly_its(:,1:(k-1));                                         %#ok saved in datafile
            rtemp=rtemp(:,1:(k-1));                                             %#ok saved in datafile
            volume=volume(1:(k-1));
            pmean=pmean(1:(k-1));
            pscores=pscores(:,1:(k-1));                                         %#ok saved in datafile
            break;
        end
        
        %% =========================[Skip Repeats]=========================
            
        %check to see if we are evaluating a value that has been done before
        idx=find(abs(volume(k)-volume(1:(k-1)))<0.0001,1);
        
        %check if value was found
        if(~isempty(idx))
            disp('Repeating volume, skipping to next iteration...')
            %copy old value
            pmean(k)=pmean(idx);
            %skip to next itteration
            continue;
        end
        
        %% ========================[Change Volume]========================
        %volume is changed by scaling the waveform or prompting the user to
        %change it in the audio device configuration
        
        
        %check if we are scaling or using device volume
        if(vol_scl_en)
            %print message with volume level
            fprintf('scaling volume to %f dB\n',volume(k));
            
            %scale audio to volume level
            y_scl = cell(length(y),1);
            for jj = 1:length(y_scl)
                y_scl{jj}=(10^((volume(k)-p.Results.DevVolume)/20))*y{jj};
            end
            
        else
            %beep to get the users attention
            beep;
            
            %turn on other LED because we are waiting
            ri.led(2,true);
            
            %get volume to set device to
            dvolume=round(volume(k));
            
            %prompt user to set new volume
            nv=input(sprintf('Set audio device volume to %f dB and press enter\nEnter actual volume if %f dB was not used\n',dvolume,dvolume));
            
            %check if value was given
            if(~isempty(nv))
                %set actual volume
                dvolume=nv;
            end
            
            %scale audio volume to make up the difference
            %scale audio to volume level
            y_scl = cell(length(y),1);
            for jj = 1:length(y_scl)
                y_scl{jj}=(10^((volume(k)-dvolume)/20))*y{jj};
            end
            
            
            %turn off other LED
            ri.led(2,false);
            
        end
        
        %% =======================[Measurement Loop]=======================
        
        for kk=1:p.Results.Trials
            
            
            %%  ================[Key Radio and Play Audio]================
            
            %push the push to talk button
            ri.ptt(true);
            
            %pause to let the radio key up
            pause(p.Results.PTTGap);
            
            %play and record audio data
            [dat,underRun(kk,k),overRun(kk,k)]=play_record(aPR,y_scl{clipi(kk)});
            
            %check for buffer over runs
            if(overRun(kk,k)~=0)
                fprintf('There were %i buffer over runs\n',overRun(kk,k));
            end
            
            %check for buffer over runs
            if(underRun(kk,k)~=0)
                fprintf('There were %i buffer under runs\n',underRun(kk,k));
            end
            
            %un-push the push to talk button
            ri.ptt(false);
            
            %get radio temp
            rtemp(kk,k)=ri.temp;
            
            %%  ==================[Clip Data Processing]==================
            
            %calculate delay
            dly_its{kk,k}=1e-3*ITS_delay_wrapper(dat,y_scl{clipi(kk)}',fs);
            
            %calculate PESQ score
            pscores(kk,k)=pesq_wrapper(fs,y{clipi(kk)},dat);
            
            %save recording
            recordings{kk,k}=dat;
            
            fprintf('Run Complete pesq = %f \n',pscores(kk,k));
            
        %% ===================[End of Measurement Loop]===================
        
        end
        
        %%  ================[Volume Level Data Processing]================
        
        %average pesq scores
        pmean(k)=mean(pscores(:,k));
        
        %print pesq scores for volume level
        fprintf('Test Complete pesq = %f dB\n',pmean(k));
    
    %% ======================[End Golden Ratio Loop]======================
    
    end
    
    if(isempty(p.Results.Volumes))
        %calculate optimal volume
        opt=(a+b)/2;
    else
        opt=NaN;
    end
    
    %%  ========================[save datafile]=========================
    
    %save datafile
    save(fullfile('data',sprintf('%s.mat',base_filename)),save_vars{:},'-v7.3');
    
    
    %%  ===========================[Catch Errors]===========================
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
    else
        %dummy var so we can save
        post_notes='';
    end
    %print end of test marker
    fprintf(logf,'===End Test===\n\n');
    %close log file
    fclose(logf);
    
    %set file status to error
    file_status='error';
    
    %start at true
    all_exist=true;
    
    %look at all vars to see if they exist
    for kj=1:length(save_vars)
        if(~exist(save_vars{kj},'var'))
            %all vars don't exist
            all_exist=false;
            %exit loop
            break;
        end
    end
    
    %check that all vars exist
    if(all_exist)
        %save all data and post notes
        save(error_filename,save_vars{:},'err','post_notes','-v7.3');
        %print out file location
        fprintf('Data saved in ''%s''\n',error_filename);
    else
        %save error post notes and file status
        save(error_filename,'err','post_notes','file_status','-v7.3');
        %print out file location
        fprintf('Dummy data saved in ''%s''\n',error_filename);
    end
    
    %check if there is a temporary data file
    if(exist(temp_filename,'file'))
        %append error and post notes to temp file
        save(temp_filename,'err','post_notes','-append');
    end
    
    
    %rethrow error
    rethrow(err);
end


%% ===========================[Close Hardware]===========================

%turn off LED when test stops
ri.led(1,false);

%close radio interface
delete(ri);


%% ======================[Check for buffer issues]======================

%check for buffer over runs
if(any(overRun))
    fprintf('There were %i buffer over runs\n',sum(sum(overRun)));
else
    fprintf('There were no buffer over runs\n');
end

%check for buffer over runs
if(any(underRun))
    fprintf('There were %i buffer under runs\n',sum(sum(underRun)));
else
    fprintf('There were no buffer under runs\n');
end

%% ===========================[Generate Plots]===========================

%create figure for plot
figure;

%sort volumes
[sv,idx]=unique(volume);

sr=pmean(idx);

plot(sv,sr);

%add text for points
text(sv,sr,cellstr(num2str(idx))','color','red');

xlabel('Audio Volume [dB]');
ylabel('PESQ score');


%% ==========================[Cleanup Function]==========================
%This is called when cleanup object co is deleted (Function exits for any
%reason other than CTRL-C). This ensures that the log entries are propperly
%closed and that there is a chance to add notes on what went wrong.

function cleanFun(err_name,good_name,log_name)
%check if error .m file exists
if(~exist(err_name,'file'))

    prompt='Please enter notes on test conditions';
    
    %check to see if data file is missing
    if(~exist(good_name,'file'))
        %add not to say that this was an error
        prompt=[prompt,newline,'Data file missing, something went wrong'];
        %no results, no default text
        def_txt='';
    else
        %load in result
        dat=load(good_name,'opt');
        %get opt from result
        def_txt=sprintf('Optimal volume = %f dB\r',dat.opt);
    end
    
    %get post test notes
    resp=inputdlg(prompt,'Test Conditions',[15,100],{def_txt});

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
    else
        %set post notes to default
        post_notes=def_txt;  
        %check if we have anything in post_notes
        if(~isempty(post_notes))
            %write post notes to file
            fprintf(logf,'===Post-Test Notes===\n\t%s',post_notes);
        end
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

%% =====================[Argument validatig functions]=====================
%some arguments require more complex validation than validateattributes can
%provide

function validateAudioFiles(fl)
validateStr=@(n)validateattributes(n,{'char'},{'vector','nonempty'});
%check if input is a cell array
if(iscell(fl))
    %validate each element in the array
    cellfun(validateStr,fl);
else
    %otherwise validate a single string
    validateStr(fl);
end
