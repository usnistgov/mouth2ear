function Delays=sliding_delay_estimates(infile,winLength,winStep)

%This function performs a sequence of windowed time delay estimates
%between two channels of a stereo
%.wav file. Results are plotted as figure 1, and are also returned to the
%calling code in the column vector variable named 'Delays.'
%
%Written by Stephen Voran at the Institute for Telecommunication Sciences,
%325 Broadway, Boulder, Colorado, USA, svoran@its.bldrdoc.gov
%March 30, 2016
%
%Use:  Delays=sliding_delay_estimates(infile,winLength,winStep)
%
%infile is a string naming the desired stereo .wav file (including path if not local).
%File must use sample rate 8, 16, 24, 32, or 48k.
%File should have SUT input on Left Channel and SUT output on Right Channel
%
%winLength is an optional window length value, defaults to 4 seconds if not
%specified. This means each time delay estimate will use 4 seconds of
%signal.
%
%winStep is optional window step value, defaults to 2 second if not
%specified.  This means the windows move forward 2 seconds for each
%subsequent time delay estimate.
%
%delays holds one delay estimate in ms for each time window,
%resolution of these estimates is 0.125 ms (i.e. 1 smp at fs=8000)
%accuraccy of these estimates will depend on the level of background noise 
%and speech distortion in the .wav file
%
%Notes:  requires access to ITS_delay_est.m, written at ITS
%        requires access to resample function included in Matlab Signal Processing Toolbox

%-----set default values of inputs-----
if nargin==1
    winLength=4;
    winStep=2;
elseif nargin==2
    winStep=2;
end

%-----read .wav file and test sample rate-----
[x,fs]=audioread(infile);
if ~any(fs==[48000 32000 24000 16000 8000])
    error('Audio file must use sample rate 8, 16, 24, 32, or 48k')
end


N=size(x,1); %number of samples available
Nwin=round(winLength*fs); %number of samples needed for each window
Nstep=round(winStep*fs);  %number of sampels to advance between windows

firstSmp=1;
lastSmp=firstSmp+Nwin-1;

Delays=[]; %Will hold delay estimates
Times=[];  %Will hold time of center of window

%-----Loop to perform all possible time delay estimates-----
while lastSmp<=N
    ref=x(firstSmp:lastSmp,1); %extract left channel signal (SUT input)
    test=x(firstSmp:lastSmp,2); %extract right channel signal (SUT ouput)

    %-----Apply our delay estimation tool to extracted portions of signal-----    
    temp=ITS_delay_est(resample(ref,1,fs/8000),resample(test,1,fs/8000),'f');
    
    %-----Store results-----
    Delays=[Delays;temp(2)];
    Times=[Times;(firstSmp+lastSmp)/2];
    
    %-----Move window location ahead-----
    firstSmp=firstSmp+Nstep;
    lastSmp=lastSmp+Nstep;    
end

Delays=Delays/8; %convert from samples to ms
Times=Times/fs; %convert from samples to seconds

%check if output arguments were given
if(nargout==0)
    %if no arguments given, plot
    plot(Times,Delays,'o-')
    xlabel('Time (Sec)')
    ylabel('Delay Estimate (mS)')
    title('Estimated Delay vs Location in File')
    grid
end
