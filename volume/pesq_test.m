function [pscores]=pesq_test(varargin)
%PESQ_TEST run a PESQ test
%
%   PESQ_TEST() computes PESQ scores for the audio channel. Plays audio out
%   the first output of the chosen device and records audio from the first
%   input of the same device then computes PESQ scores for the audio
%
%   PESQ_TEST(name,value) same as above but specify test parameters as name
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
addParameter(p,'Trials',6,@(t)validateattributes(t,{'numeric'},{'scalar','positive'}));
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

%create an object for playback and recording
aPR=audioPlayerRecorder(fs);

%set bit depth
aPR.BitDepth='24-bit integer';

%chose which device to use
dev_name=choose_device(aPR);

%print the device used
fprintf('Using "%s" for audio test\n',dev_name);

%open radio interface
ri=radioInterface(p.Results.RadioPort);

%turn on LED when test starts
ri.led(1,true);

%preallocate arrays
underRun=zeros(1,p.Results.Trials);
overRun=zeros(1,p.Results.Trials);
pscores=zeros(1,p.Results.Trials);

for k=1:p.Results.Trials

    %push the push to talk button
    ri.ptt(true);

    %pause to let the radio key up
    % 0.65 - access time limit UHF
    % 0.68 - access time limit VHF
    pause(0.68);

    %play and record audio data
    [dat,underRun(k),overRun(k)]=play_record(aPR,y);    

    %calculate PESQ score
    pscores(k)=pesq_wrapper(fs,y,dat);
    
    %print out pesq Score
    fprintf('Run %i of %i complete. Pesq score : %f\n',k,p.Results.Trials,pscores(k));

    %un-push the push to talk button
    ri.ptt(false);

    %add a pause after play_record to remove run to run dependencys
    pause(3.1);

end

%turn off LED when test stops
ri.led(1,false);

%close radio interface
delete(ri);

