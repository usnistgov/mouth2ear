function [Delays,Times]=sliding_delay_estimates(test,ref,fs,varargin)
% SLIDING_DELAY_ESTIMATES perform sequence of windowed time delay estimates
%
%   SLIDING_DELAY_ESTIMATES(test,ref,fs) performs delay estimates between
%       ref (input to the system under test) and test (output from system
%       under test)
%
%   SLIDING_DELAY_ESTIMATES(test,ref,fs,winLength) specifies the window
%       length in seconds, winLength, instead of using the default of 4
%       seconds. The window length is the length of time to use for the
%       delay estimates
%
%   SLIDING_DELAY_ESTIMATES(test,ref,fs,winLength,winStep) specifies the
%       window step in seconds, winStep, instead of using the default of 2
%       seconds. The window step is the amount of time the window moves
%       forward for each subsequent time delay estimate.
%
%   Delays=SLIDING_DELAY_ESTIMATES(__) returns the delays as a vector
%   instead of plotting them. Delays holds one delay estimate in ms for
%   each time window. The resolution of these estimates is 1/8kHz. The
%   accuracy of these estimates depends of the level of background noise
%   and speech distortion in the input waveform
%
% Notes:  requires access to ITS_delay_est.m, written at ITS
%   requires access to resample function included in Matlab Signal Processing Toolbox
%
% Written by Stephen Voran at the Institute for Telecommunication Sciences,
% 325 Broadway, Boulder, Colorado, USA, svoran@its.bldrdoc.gov
% March 30, 2016
% Modification By Jesse Frey June, 2017

%--------------------------Legal--------------------------
%THE NATIONAL TELECOMMUNICATIONS AND INFORMATION ADMINISTRATION,
%INSTITUTE FOR TELECOMMUNICATION SCIENCES ("NTIA/ITS") DOES NOT MAKE
%ANY WARRANTY OF ANY KIND, EXPRESS, IMPLIED OR STATUTORY, INCLUDING,
%WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR
%A PARTICULAR PURPOSE, NON-INFRINGEMENT AND DATA ACCURACY.  THIS SOFTWARE
%IS PROVIDED "AS IS."  NTIA/ITS does not warrant or make any
%representations regarding the use of the software or the results thereof,
%including but not limited to the correctness, accuracy, reliability or
%usefulness of the software or the results.
%
%You can use, copy, modify, and redistribute the NTIA/ITS developed
%software upon your acceptance of these terms and conditions and upon
%your express agreement to provide appropriate acknowledgments of
%NTIA's ownership of and development of the software by keeping this
%exact text present in any copied or derivative works.
%
%The user of this Software ("Collaborator") agrees to hold the U.S.
%Government harmless and indemnifies the U.S. Government for all
%liabilities, demands, damages, expenses, and losses arising out of
%the use by the Collaborator, or any party acting on its behalf, of
%NTIA/ITS' Software, or out of any use, sale, or other disposition by
%the Collaborator, or others acting on its behalf, of products made
%by the use of NTIA/ITS' Software.



%create new input parser
p=inputParser();

%add test signal parameter
addRequired(p,'test',@(l)validateattributes(l,{'numeric'},{'real','finite','vector'}));
%add reference signal parameter
addRequired(p,'ref',@(l)validateattributes(l,{'numeric'},{'real','finite','vector'}));
%add sample rate parameter
addRequired(p,'fs',@(l)validateattributes(l,{'numeric'},{'scalar','finite'}));

%add window length argument
addOptional(p,'winLength',4,@(l)validateattributes(l,{'numeric'},{'scalar','positive'}));
%add window separation argument
addOptional(p,'winStep',2,@(l)validateattributes(l,{'numeric'},{'scalar','positive'}));

%set parameter names to be case sensitive
p.CaseSensitive= true;

%parse inputs
parse(p,test,ref,fs,varargin{:});

%sample rate to resample to
%this is the rate that ITS_delay_est expects inputs to be in
fs_re=8e3;

%calculate resample factor
n_re=fs/fs_re;

%check that resample rate is an integer
if(round(n_re)~=n_re)
    %give error for invalid sample rate
    error('fs must be an integer multiple of %i',fs_re);
end

%number of samples available in both files
N=min(length(p.Results.test),length(p.Results.ref));
%number of samples needed for each window
Nwin=round(p.Results.winLength*fs);
%number of sampels to advance between windows
Nstep=round(p.Results.winStep*fs);

firstSmp=1;
lastSmp=firstSmp+Nwin-1;

Delays=[]; %Will hold delay estimates
Times=[];  %Will hold time of center of window

%-----Loop to perform all possible time delay estimates-----
while lastSmp<=N
    %get a section of the SUT input signal
    ref=p.Results.ref(firstSmp:lastSmp); 
    %get a section of the SUT output signal
    test=p.Results.test(firstSmp:lastSmp); 

    %-----Apply our delay estimation tool to extracted portions of signal-----    
    temp=ITS_delay_est(resample(ref,1,n_re),resample(test,1,n_re),'f');
    
    %-----Store results-----
    Delays=[Delays;temp(2)];
    Times=[Times;(firstSmp+lastSmp)/2];
    
    %-----Move window location ahead-----
    firstSmp=firstSmp+Nstep;
    lastSmp=lastSmp+Nstep;    
end

%convert from samples to ms
Delays=Delays/8;
%convert from samples to seconds
Times=Times/fs; 

%check if output arguments were given
if(nargout==0)
    %if no arguments given, plot
    plot(Times,Delays,'o-')
    xlabel('Time (Sec)')
    ylabel('Delay Estimate (mS)')
    title('Estimated Delay vs Location in File')
    grid
end
