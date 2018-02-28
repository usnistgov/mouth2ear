function tx_script(varargin)
%TX_SCRIPT run the transmit side of a two location mouth to ear latency
%test
%
%   TX_SCRIPT() runs the transmit side of a two location mouth-to-ear
%   latency test. This test will run 100 trials playing test.wav into the
%   radio.
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
%See also rx_script, process
%

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

%parse inputs
parse(p,varargin{:});


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

%run size
Sr=min(p.Results.Trials,max_size);

%calculate the number of runs that will be required
runs=ceil(p.Results.Trials/Sr);

%get git status
git_status=gitStatus();                                                     %#ok git_status is saved in .m file

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
base_filename=sprintf('Tx_capture%s_%s',test_type,dtn);

%print name and location of run
fprintf('Storing data in:\n\t''%s''\n',fullfile(tx_dat_fold,sprintf('%s_x_of_%i.mat',base_filename,runs)));

%turn on LED when test starts
ri.led(1,true);

%turn on LED when test starts
ri.led(1,true);

try
    for kk=1:runs

        %if this is the last run, adjust the run size
        if(kk==runs && kk>1)
            Sr=p.Results.Trials-Sr*(runs-1);
        end

        %preallocate arrays
        underRun=zeros(1,Sr);
        overRun=zeros(1,Sr);
        recordings=cell(1,Sr);

        for k=1:Sr

            %push the push to talk button
            ri.ptt(true);

            %pause to let the radio key up
            % 0.65 - access time limit UHF
            % 0.68 - access time limit VHF
            pause(0.68);

            %play and record audio data
            [dat,underRun(k),overRun(k)]=play_record(aPR,y);

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
catch err
    %save all data 
    save(fullfile('data',sprintf('%s_ERROR.mat',base_filename)),'git_status','test_type','y','recordings','st_dly','dev_name','underRun','overRun','fs','dly_its','err','-v7.3');
    %rethrow error
    rethrow(err);
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

%turn off LED when test stops
ri.led(1,false);

%close radio interface
delete(ri);

%check if there was more than one run meaning that we should load in datafiles
if(runs>1)
    %preallocate arrays
    underRun=zeros(1,p.Results.Trials);
    overRun=zeros(1,p.Results.Trials);
    recordings=cell(1,p.Results.Trials);
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


beep;
pause(1);
beep;
