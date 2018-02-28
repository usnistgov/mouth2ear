function [dly_its_mean]=test(varargin)
%TEST run a PESQ test
%
%   TEST() computes PESQ scores for the audio channel. Plays audio out the
%   first output of the chosen device and records audio from the first
%   input of the same device then computes PESQ scores for the audio
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
%                                           test. Defaults to 6
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
addParameter(p,'Trials',30,@(t)validateattributes(t,{'numeric'},{'scalar','positive'}));
%add radio port parameter
addParameter(p,'RadioPort',[],@(n)validateattributes(n,{'char','string'},{'scalartext'}));
%add background noise file parameter
addParameter(p,'BGNoiseFile',[],@(n)validateattributes(n,{'char'},{'vector'}));
%add background noise volume parameter
addParameter(p,'BGNoiseVolume',0.1,@(n)validateattributes(n,{'numeric'},{'scalar','nonempty','nonnegative'}));
%add radio temperature threshold parameter
addParameter(p,'TempTH',50,@(n)validateattributes(n,{'numeric'},{'scalar'}));
%add enable temperature threshold parameter
addParameter(p,'TempEN',true,@(t)validateattributes(t,{'numeric','logical'},{'scalar'}));
%add device volume parameter
addParameter(p,'DevVolume',-32,@(n)validateattributes(n,{'numeric'},{'scalar'}));
%add volume levels parameter
addParameter(p,'VolumeLevels',[-55:3,-10],@(n)validateattributes(n,{'numeric'},{'vector'}));
%add radio pause thereshold parameter
addParameter(p,'PauseThreshold',100,@(n)validateattributes(n,{'numeric'},{'scalar','integer','positive'}));
%add enable temperature plot parameter
addParameter(p,'TempPlot',true,@(t)validateattributes(t,{'numeric','logical'},{'scalar'}));
%add Scaling enable parameter
addParameter(p,'Scaling',true,@(t)validateattributes(t,{'numeric','logical'},{'scalar'}));


%parse inputs
parse(p,varargin{:});

%vars to save to files
save_vars={'git_status','test_type','y','recordings','dev_name','underRun',...
           'overRun','dly_its','fs','vlvls','rtemp','pscores','vol_order','vol_scl_en'};

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

%get git status
git_status=gitStatus();                                                     %#ok git_status is saved in .m file

%make plots direcotry
[~,~,~]=mkdir('plots');

%make data direcotry
[~,~,~]=mkdir('data');

%get a string to represent the current date in the filename
dtn=char(datetime('now','Format','dd-MMM-yyyy_HH-mm-ss'));

%open test type file
test_type_f=fopen('test-type.txt');

%save volume levels
vlvls=p.Results.VolumeLevels;

%check if open was successful
if(test_type_f<0)
    test_type='';
else
    %get line from file
    test_type=fgetl(test_type_f);
    %close test-type.txt file
    fclose(test_type_f);
    %check for error
    if(~ischar(test_type))
        error('Could not read test type from file');
    end
    %check for leading '#'
    if(test_type(1)=='#')
        %prompt the user for test type
        test_type=inputdlg('Please enter a test type string','Test Type',[1,50],{test_type(2:end)});
        %check if anything was returned
        if(isempty(test_type))
            test_type='';
        else
            %get test type from cell array
            test_type=test_type{1};
            %reopend and delete contents
            test_type_f = fopen('test-type.txt', 'w');
            %write new test type to file
            fprintf(test_type_f, ['#', test_type]);
            %close test-type.txt file
            fclose(test_type_f);
        end
    end
    %check if a test type was given
    if(~isempty(test_type))
        %print out test type
        fprintf('Test type : %s\n',test_type);
        %preappend underscore and trim whitespace
        test_type=['_',strtrim(test_type)];
    end
end

%open radio interface
ri=radioInterface(p.Results.RadioPort);

%generate base file name to use for all files
base_filename=sprintf('vcapture%s_%s',test_type,dtn);

%print name and location of run
fprintf('Storing data in:\n\t''%s''\n',fullfile('data',sprintf('%s.mat',base_filename)));

%turn on LED when test starts
ri.led(1,true);

%number of trials run without pausing
tcount=0;

%only print assumed device volume if scaling is enabled
if(vol_scl_en)
    %print assumed device volume for confermation
    fprintf('Assuming device volume of %.2f dB\n',p.Results.DevVolume);
end

try
    %get number of volume levels to test at
    numLevels=length(vlvls);
    
    %preallocate arrays
    underRun=zeros(numLevels,p.Results.Trials);
    overRun=zeros(numLevels,p.Results.Trials);
    recordings=cell(numLevels,p.Results.Trials);
    dly_its=cell(numLevels,p.Results.Trials);
    rtemp=zeros(numLevels,p.Results.Trials);
    pscores=zeros(numLevels,p.Results.Trials);

    %randomize volume level order
    vol_order=randperm(numLevels);
    
    for kk=vol_order
        
        %check if we are scaling or using device volume
        if(vol_scl_en)
            %print message with volume level
            fprintf('scaling volume to %f dB\n',vlvls(kk));

            %scale audio to volume level
            y_scl=(10^((vlvls(kk)-p.Results.DevVolume)/20))*y;
        else
            %beep to get the users attention
            beep;
            
            %turn on other LED because we are waiting
            ri.led(2,true);
            
            %prompt user to set new volume
            nv=input(sprintf('Set audio device volume to %f dB and press enter\nEnter actual volume if %f dB was not used\n',vlvls(kk),vlvls(kk)));
            
            %check if value was given
            if(~isempty(nv))
                %set actual volume
                vlvls(kk)=nv;
            end
            
            %set scaled version to original
            y_scl=y;
            
            %turn off other LED
            ri.led(2,false);
            
        end
            
        for k=1:p.Results.Trials

            %push the push to talk button
            ri.ptt(true);

            %pause to let the radio key up
            % 0.65 - access time limit UHF
            % 0.68 - access time limit VHF
            pause(0.68);

            %play and record audio data
            [dat,underRun(kk,k),overRun(kk,k)]=play_record(aPR,y_scl);

            %un-push the push to talk button
            ri.ptt(false);

            %add a pause after play_record to remove run to run dependencys
            pause(3.1);

            if(mod(k,10)==0)
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
            
            %calculate delay
            dly_its{kk,k}=1e-3*ITS_delay_wrapper(dat,y_scl',fs);
            
            %calculate PESQ score
            pscores(kk,k)=pesq_wrapper(fs,y,dat);
            
            %save data
            recordings{kk,k}=dat;
            
            %increment trial count
            tcount=tcount+1;

            %get radio temp
            rtemp(kk,k)=ri.temp;
            
            %save temperatur for loop
            temp=rtemp(kk,k);
            
            %check if temperature exceeds threshold
            while(p.Results.TempEN && temp>p.Results.TempTH)
                %beep to notify user
                beep;
                %turn on LED to notify user
                ri.led(2,true);
                %print message
                fprintf('Radio overheat detected!\nRadio temp = %.2f\nWhen radio is cool press enter to continue\n',rtemp(kk,k));
                %pause to fix problem
                pause;
                %reset trial count
                tcount=0;
                %turn off LED
                ri.led(2,false);
                %read new temp
                temp=ri.temp;
            end
            
            %check trial count
            if(tcount>=p.Results.PauseThreshold)
                %beep to notify user
                beep;
                %turn on LED to notify user
                ri.led(2,true);
                %print message
                fprintf('Pause Threshold reached. Swap radios and press enter\n');
                %pause to swap radios
                pause;
                %reset trial count
                tcount=0;
                %turn off LED
                ri.led(2,false);
            end
        end
    end
    %save datafile
    save(fullfile('data',sprintf('%s.mat',base_filename)),save_vars{:},'-v7.3');
        
catch err
    %save all data 
    save(fullfile('data',sprintf('%s_ERROR.mat',base_filename)),save_vars{:},'err','-v7.3');
    %rethrow error
    rethrow(err);
end

%turn off LED when test stops
ri.led(1,false);

%close radio interface
delete(ri);

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

%new figure
figure;

hold on;

dly_its_mean=cellfun(@mean,dly_its);

[dly_its_mean_u,~,dlyu]=engunits(dly_its_mean,'time','latex');

%plot delay points for each volume level
plot(vlvls,dly_its_mean_u,'b.')

%plot average delay for each volume level
plot(vlvls,mean(dly_its_mean_u,2),'r')

xlabel('Volume Level [dB]');
ylabel(sprintf('Delay [%ss]',dlyu));

%check if we should plot temperature
if(p.Results.TempPlot)
    %linear radio temperature
    lrtemp=rtemp.';
    lrtemp=lrtemp(:);
    %trial number vector
    trial=1:length(lrtemp);
    %volume index from trial
    vidx=((trial-1)/30)+1;
    %give a second y axis
    yyaxis right
    %plot temperature vs volume
    plot(vlvls(floor(vidx))+mean(diff(vlvls))*(vidx-floor(vidx)),lrtemp)
    %label axis
    ylabel('Radio Temperature [C]');
end


%figure for pesq scores
figure;

hold on;

%plot pesq scores for each volume level
plot(vlvls,pscores,'b.')

%plot average delay for each volume level
plot(vlvls,mean(pscores,2),'r')

hold off;

xlabel('Volume Level [dB]');
ylabel('PESQ score');
