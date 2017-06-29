function Delay_est=ITS_delay_est(x_speech,y_speech,mode)
%Usage: Delay_est=ITS_delay_est(x_speech,y_speech,mode)
%
%This function estimates the delay history for the speech samples in
%y_speech relative to the speech samples in x_speech.
%
%x_speech and y_speech are row or column vectors of speech samples
%with sample rate 8000 samples/sec. At least 1185 samples (148 ms)
%is required in each vector.
%
%mode='f','v', or 'u' for fixed delay, variable delay or unknown delay type
%
%Delay_est holds estimates of the delay of the speech samples in y_speech
%relative to speech samples in x_speech. Typically y_speech contains
%samples from the output of some system under test, and x_speech contains
%the corresponding input samples. Delay_est then holds estimates of the
%delay of that system under test.
%
%Delay_est is 2 by n, with one row for each segment of constant delay.
%Column 1 holds the number of the last sample of a segment of constant
%delay, column 2 holds the estimated delay for that segment. Here are two
%examples:
%
%Example 1 Delay_est=[32000,17] means that a single delay estimate of 17
%samples applies to all 32000 samples in y_speech
%
%Example 2 Delay_est=[12345,-2
% 32000,400]
%means that for samples 1 through 12345, the delay is estimated to be -2
%samples. For samples 12346 through 32000, the delay is estimated to be
%400 samples.
%
%In addition, the output [0 0] indicates no delay estimation was possible.
%This can happen when x_speech and y_speech contain unrelated signals,
%or no signal at all.
%
%Written by Stephen Voran at the Institute for Telecommunication Sciences,
%325 Broadway, Boulder, Colorado, USA, svoran@its.bldrdoc.gov
%May 10,2004

%-----------------------------Speech Input---------------------------------
%Transpose x_speech to form a column vector if necessary
if size(x_speech,2)>1
x_speech=x_speech';
end
%Transpose y_speech to form a column vector if necessary
if size(y_speech,2)>1
y_speech=y_speech';
end
%--------------------------Level Normalization-----------------------------
%Measure active speech level
asl_x=active_speech_level(x_speech);
asl_y=active_speech_level(y_speech);
%Force active speech level to -26 dB r.e. overload
x_speech=x_speech*10^(-(asl_x+26)/20);
y_speech=y_speech*10^(-(asl_y+26)/20);
%---------------------Coarse Average Delay Estimation----------------------
[tau_0,rho_0,fir_coeff_63]=coarse_avg_dly_est(x_speech,y_speech);
%Compensate for tau_0, comp_x_speech and comp_y_speech will have same
%length
[comp_x_speech,comp_y_speech]=fxd_delay_comp(x_speech,y_speech,tau_0);
%If compensation for tau_0 results in a speech vector that is shorter
%than 1185 samples, then the input signal vectors x_speech and y_speech
%are not sufficent for delay estimation. (They may contain unrelated
%signals, no signal, or may simply be too short)
if length(comp_x_speech)<1185
%Algorithm must terminate
mode='t';
end
%------------Do further mode determination as necessary/possible-----------
if mode=='u' & rho_0<.96
mode='v';
end
%-----Fine delay estimation for the fixed and unknown delay cases----------
if mode=='f' | mode=='u'
%Find fine delay
fxd_fine_delay=fxd_fine_dly_est(comp_x_speech,comp_y_speech);
%Find total delay
D_fxd=tau_0+fxd_fine_delay;
end
%-------Additional stages for the variable and unknown delay cases---------
if mode=='v' | mode=='u'
%---------------------Speech Activity Detection------------------------
%Identify active speech samples (active_wf is same size as y_speech,
%1 indicates activity, 0 otherwise)
active_wf=find_activity_wf(y_speech,fir_coeff_63);
%Compensate the activity waveform for tau_0
[junk,comp_active_wf]=fxd_delay_comp(x_speech,active_wf,tau_0);
%--------------------------Delay Tracking------------------------------
DCAVS=delay_tracking(comp_x_speech,comp_y_speech,comp_active_wf,150,40,200);
%--------------------------Median Filtering----------------------------
SDV=median_filter(DCAVS,500,40,.1,.8);
%---------------------Combine Results with tau_0-----------------------
SDV(:,2)=SDV(:,2)+tau_0; %Add in tau_0 to delay estimates
if 0<tau_0 %If tau_0 is a positive quantity
%then adjust locations of delay segments as well
SDV(:,1)=SDV(:,1)+tau_0;
end
%Adjust final location to exactly match end of y_speech
SDV(end,1)=length(y_speech);
%----------------------------Delay Refinement--------------------------
SDV=delay_refine(SDV,x_speech,y_speech,active_wf,72,.7);
%---------------Remove Redundant Entries in SDV matrix-----------------
%If delay and validity do not change from segment n to n+1, then
%segment n is redundant
keepers=[find( (diff(SDV(:,2))~=0) | (diff(SDV(:,3))~=0));size(SDV,1)];
SDV=SDV(keepers,:);
%Adjust final location to exactly end y_speech
SDV(end,1)=length(y_speech);
%-----------------Round Delay Estimates to Nearest Integer-------------
SDV(:,2)=round(SDV(:,2));
%-----------------------Short Segment Correction------------------------
if size(SDV,1)>1
SDV=short_seg_cor(SDV,x_speech,y_speech,160,280,80);
end
end
%--------------------------Apply LSE if Necessary--------------------------
if mode=='u'
[lse_f,lse_v]=LSE(x_speech,y_speech,D_fxd,SDV,16);
if lse_f <= lse_v
mode='f';
else
mode='v';
end
end
%---Select Output, Extrapolate Variable Delay Estimate if Necessary--------
if mode=='v'
Delay_est=extend_val_res(SDV); %Extrapolate variable delay estimate
elseif mode=='f'
Delay_est=[length(y_speech) D_fxd];%Reformat fixed delay estimate
else %Mode is 't' for terminate
%The output [0 0] indicates no delay estimation was possible
Delay_est=[0 0];
end
%==========================================================================
function asl=active_speech_level(x)
%Usage: asl=active_speech_level(x)
%This function measures the active speech levels in the speech vector x.
%
%x is a column vector of speech samples
%asl is the active speech level in dB relative to overload
%Just edit fs to operate at other sample rates
fs=8000; %samples/second
%code will extend each active region by tau samples (forward in time)
tau=round(.200*fs);
%active speech is defined to be dBth dB below max
dBth=20;
n=length(x);
x=x-mean(x); %mean removal
x=abs(x);
%calculate filter coefficient from time constant
g=exp(-1/(fs*.03));
%perform 2nd order IIR filtering
x=IIRfilter((1-g)^2,[1 -2*g g*g]',x);
at=max(x)*(10^(-dBth/20)); %calculate activity threshold
if at==0
error('Input vector has no signal')
end
active=x>at; %find active samples
%Extend each active interval tau samples forward in time
trans=find(abs(diff(active)));
for i=1:length(trans)
active(trans(i):min(trans(i)+tau,n))=1;
end
%Test for both activity and non-zeroness to prevent log(0)
x=x( find( 0<x & active ));
asl=20*mean(log10(x))-81;
%==========================================================================
function [tau_0,rho_0,fir_coeff]=coarse_avg_dly_est(x,y)
%Usage: [tau_0,rho_0,fir_coeff]=coarse_avg_dly_est(x,y)
%This function generates a coarse delay estimate from speech envelopes.
%This is done in the fs=125 samples/sec domain. (i.e., sub-sampling by 64).
%x and y are column vectors of speech samples
%tau_0 is a delay estimate in samples
%rho_0 is the corresponding correlation value
%fir_coeff is a set of 401 FIR filter coefficients for a 63 Hz LPF
fir_coeff=find_fir_coeffs(400,1/133.33); %calculate filter coeffs
rx=abs(x); %rectify
ry=abs(y);
ex=IIRfilter(fir_coeff',1,abs(x)); %63 Hz LPF, order 400 FIR
ey=IIRfilter(fir_coeff',1,abs(y));
%There is no need to remove filter delay since it is the same in each
%signal
ex=ex(1:64:end); %Subsample by 64
ey=ey(1:64:end);
%Zero pad so ex and ey have same length
lx=length(ex);
ly=length(ey);
L=max(lx,ly);
ex=[ex;zeros(L-lx,1)];
ey=[ey;zeros(L-ly,1)];
corrlen=length(ex);
m=mean(ex);
%Remove mean of ex from both ex and ey
ex=ex-m;
ey=ey-m;
%FFT based cross correlation
xc=real(ifft(fft([ex;zeros(corrlen,1)]) ...
.*fft([flipud(ey);zeros(corrlen,1)])));
[rho,index]=max(xc);
%Convert peak location to a shift
tau_0=64*(corrlen-index);
%Normalize to get cross correlation value
rho_0=rho/((corrlen-1)*std(ex)*std(ey));
%==========================================================================
function SDVout=delay_refine(SDVin,x_speech,y_speech,active_wf,range,cor_th)
%Usage: SDVout=delay_refine(SDVin,x_speech,y_speech,active_wf,range,cor_th)
%This function refines the input delay matrix SDVin, to generate SDVout.
%SDVin and SDVout are in the fs=8000 domain and have one row per segment
%of constant delay.
%Column 1, Sample number of last sample of constant delay segment
%Column 2, estimated Delay of segment
%Column 3, Validity of delay estimation segment (0 for invalid, 1 for valid)
%
%x_speech and y_speech are column vectors of speech samples
% with sample rate 8000 samples/sec. (x_speech is associated with system
% under test input, y_speech is associated with system under test output)
%active_wf has the same size as y_speech. 1 indicates speech activity,
% 0 otherwise.
%range gives the search range for this stage in samples
%cor_th is the correlation threshold for refinement
%Rectify speech
x_speech=abs(x_speech);
y_speech=abs(y_speech);
%Copy all data, function will refine it where possible
SDVout=SDVin;
%Find number of segments of constant delay
nsegs=size(SDVin,1);
%Loop over all segments
for i=1:nsegs
%Find first sample of current segment (first segment is special case)
if i==1
start=1;
else
start=SDVin(i-1,1)+1;
end
%Extract last sample of current segment
stop=SDVin(i,1);
%Extract delay of current segment
delay=SDVin(i,2);
%Attempt refinement only if there is at least 10 ms of active speech
%in the segment and segment has a valid delay estimate
if 80 <= sum(active_wf(start:stop)) & SDVin(i,3)==1
%If segment length is at least 200 ms, use fft-based correlation
if 1600 <= (stop-start+1)
%Find delay compensated starting sample in x_speech
sstart=start-delay;
%If it is before the start of x_speech, it will be necessary to
%modify the starting place in both x_speech and y_speech
if sstart<1
%Number of samples involved in the modifications
trim=1-sstart;
%First sample of x_speech for this segement
sstart=sstart+trim;
%First sample of y_speech for this segement
start=start+trim;
end
%Find delay compensated ending sample in x_speech
sstop=min(stop-delay,length(x_speech));
%If there is at least 10 ms in both the x_speech segment and
%the y_speech segment after these adjustments
if (80 <= sstop-sstart+1) & (80 <= stop-start+1)
%Perform FFT-based cross correlation on appropriate
%portions of x_speech and y_speech
[un_corr,denom]=fft_xc(x_speech(sstart:sstop), ...
y_speech(start:stop),-range,range);
%Locate peak in unnormalized correlation
[peak,loc]=max(un_corr);
%If correlation value meets or exceeds threshold, or the
%segment is longer than 1 second
if (cor_th <= peak/denom) | (8000 < stop-start+1)
%Apply the refinement
SDVout(i,2)=delay+(loc-range-1);
end
end
%Segment is less than 200 ms long, use direct-form correlation
else
%Find starting sample in x_speech, compensated for
%delay and search range
sstart=start-delay-range;
%If it is before the start of x_speech, it will be necessary to
%modify the starting place in both x_speech and y_speech
if sstart<1
%Number of samples involved in the modifications
trim=1-sstart;
%First sample of x_speech for this segement
sstart=sstart+trim;
%First sample of y_speech for this segement
start=start+trim;
end
%Find ending sample in x_speech, compensated for
%delay and search range
sstop=stop-delay+range;
%If it is beyond the end of x_speech, it will be necessary to
%modify the ending place in both x_speech and y_speech
if length(x_speech)<sstop
%Number of samples involved in the modifications
trim=sstop-length(x_speech);
%Last sample of x_speech for this segement
sstop=sstop-trim;
%Last sample of y_speech for this segement
stop=stop-trim;
end
%If there is at least 10 ms in the y_speech segment after
%these adjustments
if 80 < stop-start+1
%Perform direct-form cross correlation on appropriate
%portions of x_speech and y_speech
[un_corr,denom]=non_fft_xc_all(x_speech(sstart:sstop), ...
y_speech(start:stop));
%Locate peak in unnormalized correlation
[peak,loc]=max(un_corr);
%If correlation value meets or exceeds threshold
if cor_th <= peak/denom
%Apply the refinement
SDVout(i,2)=delay+(range-loc+1);
end
end
end
end
end
%==========================================================================
function DCAVS=delay_tracking(x,y,active_wf,winlen,winstep,range);
%Usage: DCAVS=delay_tracking(x,y,active_wf,winlen,winstep,range);
%This function does delay tracking (delay in speech signal y relative to x)
%winlen is the length of window used for the delay estimation alg (in ms)
%winstep is the step size between windows (in ms)
%range is the half-width of the search range (in ms);
%DCAVS is a nwins by 5 matrix, where nwins is the number of delay
%estimation windows that can be fit into y
%Column 1 holds Delay values (in the 16:1 subsampled domain)
%Column 2 holds the corresponding Correlation values
%Column 3 holds the corresponding Activity levels values
%Column 4 holds the corresponding Validities (1 for valid delay estimate,
% 0 otherwise)
%Column 5 holds the Sample number in y (in the 16:1 subsampled domain)
%that is at the center of each window
%Create coefficients for an FIR LPF with 129 taps and a delay of
%64 samples. Response is -51 dB at 250 Hz.
fir_coeffs=find_fir_coeffs(128,1/32);
%Rectify and filter
x=IIRfilter(fir_coeffs',1,[abs(x);zeros(64,1)]);
%Remove filter delay and subsample by 16
x=x(65:16:end);
nx=length(x);
%Rectify and filter
y=IIRfilter(fir_coeffs',1,[abs(y);zeros(64,1)]);
%Remove filter delay and subsample by 16
y=y(65:16:end);
%Subsample activity waveform
active_wf=active_wf(1:16:end);
%Force subsampled activity waveform to have same length as subsampled y
ny=length(y);
len_diff=length(active_wf)-ny;
if 0<len_diff
active_wf=active_wf(1:ny); %Trim final samples
elseif len_diff<0
active_wf=[active_wf;zeros(len_diff,1)]; %Zero pad
end
%Convert parameters from ms to samples (in the subsampled domain)
winlen=round(winlen/2);
winstep=round(winstep/2);
range=round(range/2);
%Find total number of window positions that can be placed on y
nwins= floor((ny-winlen)/winstep)+1;
DCAVS=zeros(nwins,5);
%Find locations of centers of windows (sample number in subsampled domain)
first=(winlen+1)/2;
last=first+winstep*(nwins-1);
DCAVS(:,5)=[first:winstep:last]';
for i=1:nwins %Loop over all windows
start=1+(i-1)*winstep; %First sample in window
stop=start+winlen-1; %Last sample in window
%Find activity level in window
DCAVS(i,3)=sum(active_wf(start:stop))/winlen;
%Assume delay estimation is doable unless one of tests that
%follows fails
doable=1;
if start-range < 1 | min(nx,ny) < stop+range
%Not enough samples to do delay estimation
doable=0;
elseif std(y(start:stop))==0 | std(x(start-range:stop+range))==0
%No variation in samples
doable=0;
end
if doable
%Perform direct-form cross correlation
[xc,denom]=non_fft_xc(x(start-range:stop+range), ...
y(start-range:stop+range),-range,range);
%Identify peak
[maxrho,index]=max(xc);
%Calculate corresponding delay in samples
DCAVS(i,1)=(index-range-1);
%Calculate corresponding correlation value
DCAVS(i,2)=maxrho/denom;
%Mark that window as having a valid delay estimate
DCAVS(i,4)=1;
end
end
%==========================================================================
function SDVout=extend_val_res(SDVin);
%Usage: SDVout=extend_val_res(SDVin)
%This function extrapolates valid results to cover areas where there are
%none. SDVin and SDVout are Delay history matrices in the fs=8000 domain:
%Column 1, Sample number of last sample of constant delay segment
%Column 2, estimated Delay of segment
%Column 3, Validity of delay estimation segment
% (0 for invalid, 1 for valid)
%
%For interior invalid regions, the function splits the region in half and
%extrapolates each neighboring valid region to cover half of the invalid
%region. For exterior invalid regions, the function extrapolates the
%single neighboring valid region
%Find number of segments
nsegs=size(SDVin,1);
%Copy input data to output data
SDVout=SDVin;
%If there is more than one segment, then loop over all segments
if 1< nsegs
for i=1:nsegs
%If the current segment is not valid
if SDVout(i,3)==0
%Leading invalid segment case
if i==1
SDVout(1,2)=SDVout(2,2);
%Trailing invalid segment case
elseif i==nsegs
SDVout(nsegs,2)=SDVout(nsegs-1,2);
%Interior invalid segment case
else
%Half the width of the invalid segment
hw=round((SDVout(i,1)-SDVout(i-1,1))/2);
%Extend previous segment to cover first
SDVout(i-1,1)=SDVout(i-1,1)+hw;
%Copy delay of following segment to cover second half
SDVout(i,2)=SDVout(i+1,2);
end
end
end
%Find segments associated with changes in delay
keepers=[(find(diff(SDVout(:,2))~=0));nsegs];
%Retain only those segments
SDVout=SDVout(keepers,[1 2]);
else
SDVout=SDVout(1,[1 2]);
end
%==========================================================================
function [un_corr,denom]=fft_xc(x,y,min_d,max_d)
%Usage: [un_corr,denom]=fft_xc(x,y,min_d,max_d)
%This function does an fft-based cross correlation on the waveforms in the
%column vectors x and y. These two vectors need not have the same length,
%but the resulting delay estimated is defined relative to zero time offset
%of x(1) and y(1).
%
%If possible, an unnormalized correlation value is returned for all delay
%values from min_d to max_d, inclusive. (If this is not possible, it is
%an error condition)
%
%Thus un_corr is a length max_d-min_d+1 column vector. When it is divided
%by denom (typically after finding a max), correlation values result.
%un_corr(1) corresponds to min_d, un_corr(end) corresponds to max_d
%The legal search window is approximately +/- min(length(x),length(y).
%Pad with zeros so x and y have same length
lx=length(x);
ly=length(y);
L=max(lx,ly);
x=[x;zeros(L-lx,1)];
y=[y;zeros(L-ly,1)];
corrlen=length(x);
%Remove the mean of x from each signal
m=mean(x);
x=x-m;
y=y-m;
%Perform FFT-based cross correlation
xc=real(ifft(fft([x;zeros(corrlen,1)]).*fft([flipud(y);zeros(corrlen,1)])));
xc=flipud(xc); %reverse the column vector, top to bottom
%Test to see if requested values of delay are available
if corrlen+min_d+1<1 | 2*corrlen < corrlen+max_d+1
error('Not enough input samples to calculate requested delay values.')
end
%Extract requested values of delay
un_corr=xc(corrlen+min_d+1:corrlen+max_d+1);
%Calculate the denominator
denom=(corrlen-1)*std(x)*std(y);
%==========================================================================
function active_x=find_activity_wf(x,fir_coeff)
%Usage: active_x=find_activity_wf(x,fir_coeff)
%This function generates an output column vector (active_x) that shows the
%speech activity waveform of the input column vector (x).
%Speech activity is defined via a smoothed speech envelope with nominal
%bandwidth of 63 Hz. The required FIR filter coefficients are given in
%fir_coef. Samples of the envelope that are within 35 dB of
%the envelope peak are associated with active speech. Each interval of
%activity is extended by tau samples forward and backward in time.
th=35; %Threshold for activity detection in dB below peak
tau=800; %Number of samples to extend each active segment in each direction
nx=length(x);
%FIR filter rectified speech
x=IIRfilter(fir_coeff',1,[abs(x);zeros(200,1)]);
x=x(201:end); %Remove filter delay
%Find samples that are above threshold,1 means active, 0 means not active
active_x = (x >= 10^(th/20));
%Extend all active regions by tau samples in each direction
trans=find(abs(diff(active_x))); %List of transition points
for j=1:length(trans) %Loop over all transitions
%Extend activity in each direction
active_x(max(trans(j)-tau,1):min(trans(j)+tau,nx))=1;
end
%==========================================================================
function b=find_fir_coeffs(order,cutoff)
%Usage: b=find_fir_coeffs(order,cutoff)
%This function generates filter coefficients for an FIR LPF with
%the specified order and cutoff frequency. Cutoff frequency
%is specified relative to Nyquist frequency. b is a row vector
%of length order+1 that holds the filter coefficients
%Create column vector that holds Hamming window of length order+1
n=order+1;
h=0.54-0.46*cos(2*pi*[0:n-1]/(n-1));
%Create column vector of time-domain indices
t=[-order*cutoff/2:cutoff:order*cutoff/2];
%Calculate sin(pi*x)/(pi*x) (sinc function) for time domain indices
%sin(pi*0)/(pi*0) is defined to be 1
good=find(t~=0);
sinxox=ones(1,order+1);
sinxox(good)=sin(pi*t(good))./(pi*t(good));
%Filter coefficients are product of window and sinc function
b=h.*sinxox;
%Normalize coefficients for unity gain in passband
b=b/sum(b);
%==========================================================================
function [ptr,seg_type]=find_smallest_seg(SDVLS)
%This function finds the smallest segment that has status 0 and reports
%the segment type. SDVLS is a matrix with one row per segment of constant
%delay. The 5 columns are:
%Column 1, Sample number of last sample of constant delay segment
%Column 2, estimated Delay of segment
%Column 3, Validity of delay estimation segment (0=invalid, 1=valid)
%Column 4, Length of segment in samples
%Column 5, Status of segment (0=needs to be considered, 1=should be
% ignored)
%
%ptr points to the row in SDVLS that has the smallest segment with
%status 0. If all segments have status 0 , then ptr=0. If there is a tie
%for shortest segment, the first segment to occur is reported
%
%seg_type indicates the type of segment ptr points to:
%'IV' segment with invalid delay estimate
%'IS' isolated, valid but neighbors on each side are invalid
%'LT' lefthand tail, the segment to the left of an LT segment is either
% invalid or does not exist, but segment to right is valid
%'RT' righthand tail, the segment to the right of an RT segment is either
% invalid or does not exist, but segment to left is valid
%'BI' blip, segment and both neighbors are valid. Both neighbors share a
% common delay value which is different from the delay value of the BI
% segment
%'SP' step, segment and both neighbors are valid and all 3 have different
% delay values
%'xx' is returned when ptr=0, i.e. there is no result to report.
%Initialize ptr
ptr=0;
%Find number of segments
nsegs=(size(SDVLS,1));
%Create list of all segments with status=0
goodlist=find(SDVLS(:,5)==0);
%If no such segment, function is done
if isempty(goodlist)
ptr=0;
seg_type='xx';
%There is one or more segments with status=0
else
%Find the shortest such segment
[dud,loc]=min(SDVLS(goodlist,4));
%Set ptr accordingly
ptr=goodlist(loc);
%If segment is invalid, mark it as such and function is finished
if SDVLS(ptr,3)==0
seg_type='IV';
%Special case for first segment
elseif ptr==1
%If segment to right is valid
if SDVLS(ptr+1,3)==1
%First segment is a left tail
seg_type='LT';
else
%Otherwise first segment is isolated
seg_type='IS';
end
%Special case for last segment
elseif ptr==nsegs
%If segment to left is valid
if SDVLS(ptr-1,3)==1
%Last segment is a right tail
seg_type='RT';
else
%Otherwise last segment is isolated
seg_type='IS';
end
%All remaining segments have two neighbors
else
%Check validity of segment to left of current segment
lv=SDVLS(ptr-1,3);
%Check validity of segment to right of current segment
rv=SDVLS(ptr+1,3);
%Use these two validities to identify appropriate segment type
if lv==1 & rv==0
seg_type='RT';
elseif lv==0 & rv==1
seg_type='LT';
elseif lv==0 & rv==0
seg_type='IS';
%Both neighbors are valid, so current segment is either a blip
%or a step
else
%If neighbors have the same delay, current segment is a blip
if SDVLS(ptr-1,2)==SDVLS(ptr+1,2)
seg_type='BI';
%Otherwise current segment is a step
else
seg_type='SP';
end
end
end
end
%==========================================================================
function [source,distorted]=fxd_delay_comp(source,distorted,delay)
%Usage: [source,distorted]=delay_comp(source,distorted,delay)
%This function compensates the source-distorted signal pair by the given
%delay value in samples. The returned source and distorted signals will
%have the same length.
sstart=max(1,1-delay); %source starting point
dstart=max(1,1+delay); %distorted starting point
%Number of samples available
samples=min(length(source)-sstart+1,length(distorted)-dstart+1);
%Extract proper portions
source=source(sstart:sstart+samples-1);
distorted=distorted(dstart:dstart+samples-1);
%==========================================================================
function D=fxd_fine_dly_est(x,y);
%Usage: D=fxd_fine_dly_est(x,y);
%This function performs an FFT-based cross correlation on the rectified
%speech signals and then processes the results to find a delay estimate
%x and y are column vectors of speech samples
%D is the estimated delay
range=128; %half width of range of samples to analyze in this stage
%number of samples to feed into filter while waiting for it to stabilize
headlen=500;
%number of samples (a tail) long enough to cover the longest filter delay
taillen=200;
%find cross correlation of rectified speech
[xc,denom]=fft_xc(abs(x),abs(y),-(range+headlen),range+taillen);
%extract relevant portion
txc=xc(headlen+1:headlen+1+2*range);
%find max
[maxrho,index]=max(txc);
maxrho=maxrho/denom;
if .73<maxrho %For high correlations, no smoothing is required
D=index-1-range; %Calculate delay estimate
elseif .67<maxrho %For medium correlations, some smoothing helps
m=64;
flen=3*m;
fir_coeff=find_fir_coeffs(flen,1/m); %Filter lengths are even
sxc=IIRfilter(fir_coeff',1,xc);
%smoothed version of cross-correlation function with filter delay
%removed
sxc=sxc(headlen+(flen/2)+1:headlen+(flen/2)+1+2*range);
[dud,index]=max(sxc);
D=index-range-1; %Calculate delay estimate
else %For lower correlations, more smoothing helps
m=128;
flen=3*m;
fir_coeff=find_fir_coeffs(flen,1/m); % filter lengths are even
sxc=IIRfilter(fir_coeff',1,xc); %More Transparent
%smoothed version of cross-correlation function with filter delay
%removed
sxc=sxc(headlen+(flen/2)+1:headlen+(flen/2)+1+2*range);
[dud,index]=max(sxc);
D=index-range-1; %Calculate delay estimate
end
%==========================================================================
function y=IIRfilter(b,a,x)
%Usage: y=IIRfilter(b,a,x)
%This function implements an IIR filter in direct form:
%a(1)*y(n) = b(1)*x(n) + b(2)*x(n-1) + ... + b(nb+1)*x(n-nb)
% - a(2)*y(n-1) - ... - a(na+1)*y(n-na)
%x and y are column vectors and have the same length
%a and b are column vectors of filter coefficients as defined above
%For FIR filtering, set a=1.
%Note that use of the built-in Matlab function “filter” will result
%in much faster execution
%Normalize b coefficients and reverse their order top to bottom
b=flipud(b/a(1));
%Normalize a coefficients, remove a(1) and reverse the order of
%the remaining coefficients, top to bottom
a=flipud(a(2:end)/a(1));
%Check vector lengths
na=length(a);
nb=length(b);
n=length(x);
%If no "a" coefficients remain, this is the FIR case
if na==0
%Initialize x and y
x=[zeros(nb-1,1);x];
y=zeros(n,1);
%Loop over all samples in y
for i=1:n
y(i)=x(i:i+nb-1)'*b;
end
%If "a" coefficients remain, this is the IIR case
else
%Initialize x and y
m=max(na,nb);
x=[zeros(m,1);x];
y=zeros(n+m,1);
%Loop over all relevant samples in y
for i=m+1:m+n
y(i)=x(i-nb+1:i)'*b - y(i-na:i-1)'*a;
end
%Extract relevant portion of y
y=y(m+1:end);
end
%==========================================================================
function [lse_f,lse_v]=LSE(s,d,Df,Dv,maxsp);
%Usage: [lse_f,lse_v]=LSE(s,d,Df,Dv,maxsp)
%This function calculates log-spectra error for fixed and variable delay
%estimates.
%
%s is a column vector of source speech samples (system under test input)
%d is a column vector of distorted speech samples (system under test
%output) s and d should have no delay compensation applied
%Df is a fixed scalar delay value
%Dv is a delay history matrix where each row corresponds to a segment of
%constant delay and
%Column 1 holds number of last sample in segment
%Column 2 holds delay value for segment
%Column 3 holds 1 to indicate valid delay estimate for the segment,
% and holds 0 otherwise
%max sp tells the max spacing between LSE computation locations in ms
%lse_f and lse_v are the fixed and variable LSE results in dB
%
%If the lengths of s and d are such that delay compensation by either
%Df or Dv leaves insufficent signal for LSE calculations, then this
%function returns lse_f=lse_v=0.
%Length of LSE window in samples
lsewin=128;
%Convert from ms to samples
maxsp=round(maxsp*8);
%Find list of segment numbers that are valid
goodlist=find(Dv(:,3));
%Find number of valid segments in Dv
nsegs=length(goodlist);
%Will hold center locations of LSE windows in d
dlocs=[];
%Will hold analogous center locations of LSE windows in s, according to
%the variable delay estimate
slocs_var=[];
%Loop over all segments
for i=1:nsegs
%If it is the first segment in Dv
if goodlist(i)==1
%Starting sample number must be 1
start=1;
else
%Otherwise it is 1 more than last sample of previous segment
start=Dv(goodlist(i)-1,1)+1;
end
%Find last sample of segment
stop=Dv(goodlist(i),1);
%Find delay of the segment
segdel=Dv(goodlist(i),2);
%Find center of segment
center=round((stop+start)/2);
%Total number of LSE windows that will fit on this segment is 2*hn+1
hn=floor((stop-center-320-lsewin/2)/maxsp);
%Calculate the window location(s)
if hn>=1
locs=center+[-hn:1:hn]'*maxsp;
else
locs=center;
end
%Append locations to the list of LSE window center locations in d
dlocs=[dlocs;locs];
%Append locations to the list of LSE window center locations in s,
%compensate for segment delay
slocs_var=[slocs_var;locs-segdel];
end
%Create list of corresponding centers of LSE windows in s,
%according to the fixed delay estimate
slocs_fxd=dlocs-Df;
%Find 4 constants
L=round(lsewin/2);
R=lsewin-L-1;
len_d=length(d);
len_s=length(s);
%Find locations of window centers that will result in windows that do
%not extend beyond the ends of s or d
goodlocs=find( 1<=(dlocs-L) & (dlocs+R)<=len_d & 1<=(slocs_var-L) & ...
(slocs_var+R)<=len_s & 1<=(slocs_fxd-L) & (slocs_fxd+R)<=len_s);
%Retain only such locations
dlocs=dlocs(goodlocs);
slocs_var=slocs_var(goodlocs);
slocs_fxd=slocs_fxd(goodlocs);
nlocs=length(dlocs);
%If there are locations for LSE calculations
if 0<nlocs
%Build matrices of speech samples from the desired locations
%Each column contains speech samples for a given LSE window
D=zeros(lsewin,nlocs);
Sv=zeros(lsewin,nlocs);
Sf=zeros(lsewin,nlocs);
for i=1:nlocs
D(:,i)=d(dlocs(i)-L:dlocs(i)+R);
Sf(:,i)=s(slocs_fxd(i)-L:slocs_fxd(i)+R);
Sv(:,i)=s(slocs_var(i)-L:slocs_var(i)+R);
end
%Generate column vector with periodic Hanning window, length is lsewin
win=.5*(1-cos(2*pi*[0:lsewin-1]'/lsewin));
%Repeat this window in each column of the matrix Win.
%(Win is lsewin by nlocs.)
Win=repmat(win,1,nlocs);
%Multiply by window and peform FFT on each column of each speech matrix
D=fft(D.*Win);
Sf=fft(Sf.*Win);
Sv=fft(Sv.*Win);
%Extract magnitude of unique half of FFT result
D=abs(D(1:(lsewin/2)+1,:));
Sf=abs(Sf(1:(lsewin/2)+1,:));
Sv=abs(Sv(1:(lsewin/2)+1,:));
%Limit results below at 1 to prevent log(0). This is below the 10 dB
%clamping threshold used below, so these clamped samples will not be
%used
D=max(D,1);
Sf=max(Sf,1);
Sv=max(Sv,1);
%Take log and clamp results below at 10 dB. Speech peaks will
%typically be around 100 dB, so this limits dynamic range to about 90
%dB and prevents low level segments from inappropriately dominating the
%LSE results
D=max(10,20*log10(D) );
Sf=max(10,20*log10(Sf) );
Sv=max(10,20*log10(Sv) );
%Calculated LSE: inner mean is across frequency, outer mean is across
%LSE windows (i.e. across time)
lse_f=mean(mean(abs(D-Sf)));
lse_v=mean(mean(abs(D-Sv)));
%LSE calculations are not possible
else
lse_f=0;
lse_v=0;
end
%==========================================================================
function SDV=median_filter(DCAVS,twinlen,winstep,activity_th,cor_th);
%Usage: SDV=median_filter(DCAVS,twinlen,winstep,activity_th,cor_th);
%This function does the median filtering on the results in the DCAVS
%matrix. The DCAVS matrix is defined in the delay_tracking function.
%
%twinlen is the length of the median filtering window in ms
%winstep tell how many ms each step in DCAVS matrix corresponds to worth
%activity_th is the activity threshold required for a sample to be included
% in the median filter
%cor_th is the correlation threshold required for a sample to be for
% included in the median filtering
%
%Results are returned in the matrix SDV. Each row of SDV describes a
%segment of constant delay. SDV is in the fs=8000 domain.
%Column 1, Sample number of last sample of constant delay segment
%Column 2, estimated Delay of segment
%Column 3, Validity of delay estimate (0 for invalid, 1 for valid)
%
%SDV(end,1) is given by the center of the final window (DCAVS(end,5)),
%converted from the fs=500 domain to the fs=8000 domain. Note that in
%general, this will not be exactly the same as the length of the
%speech signal y (output from system under test).
%
%If no valid information can be extracted from DCAVS, the result is a delay
%of zero everywhere.
%Extract number of time samples available
nwins=size(DCAVS,1);
%Create a temporary matrix. It has 1 row for each row of DCAVS.
%Column 1 will hold delay estimates
%Column 2 will hold is 1 if that estimate is valid, 0 otherwise
%Column 3 will hold the distorted speech envelope sample number
%(in the fs=500 domain) associated with the delay estimate
T=[zeros(nwins,2),DCAVS(:,5)];
%Find half-width of median filtering window in samples
htwinlen=round(twinlen/(2*winstep));
%Good is a column vector with length nwins. It has a 1 where a
%delay estimate has correlation that meets or exceeds threshold,
%activity that meets or exceeds threshold, and is mathematically valid.
%It has a zero elsewhere.
good=(cor_th<=DCAVS(:,2) & activity_th<=DCAVS(:,3) & DCAVS(:,4));
%Loop over all samples
for i=1:nwins
%Check number of samples between sample and last sample
nsmp=min(i-1,nwins-i);
%Find final half-width of median filtering window (cannot exceed the
%number of remaining samples)
fhtwinlen=min(htwinlen,nsmp);
start=i-fhtwinlen; %First sample in current window
stop=i+fhtwinlen; %Last sample in current window
%If there is a least one good sample in the window
if sum(good(start:stop))>=1;
%Form list of absolute indices of good samples
goodlist=start+find(good(start:stop))-1;
%Perform median filtering on the good samples
%Note on median function: When presented with an even number of
%samples, this median function returns the average of the two
%central samples. e.g. median([1 2 3 4])=2.5
T(i,1)=median(DCAVS(goodlist,1));
%Mark that a valid result has been calculated
T(i,2)=1;
end
end
%Find how many valid results have been calculated
nvalres=sum(T(:,2));
%If no valid results have been calculated, report zero delay everywhere
if nvalres==0
SDV=[DCAVS(end,5),0,0];
else
%List only results that describe a change in delay or a change in
%validity, plus the final result
keepers=[find( (diff(T(:,1))~=0) | (diff(T(:,2))~=0) );nwins];
%Keep only those results
SDV=T(keepers,[3 1 2]);
end
%Convert final results from fs=500 samples/sec domain to the
%fs=8000 samples/sec domain
SDV(:,2)=SDV(:,2)*16; %Convert delay estimates
SDV(:,1)=(SDV(:,1)-1)*16+1+8; %Convert sample values
%==========================================================================
function [xcs,denom,ystart,ystop]=non_fft_xc(x,y,min_d,max_d)
%Usage: [xcs,denom,ystart,ystop]=non_fft_xc(x,y,min_d,max_d)
%This function enables delay estimation by calculating the cross
%correlation between two vectors of speech samples x and y at the
%specified shifts. x and y need not have the same length. Zero delay
%is associated with the case where x(1) aligns with y(1). x and y may
%be row or column vectors. Cross correlations are performed at all
%delays between min_d and max_d (given in samples) inclusive. If the
%length of x or y prevents this, an error is generated.
%xcs is a column vector and holds unnormalized correlation values for all
% requested delays
%denom is the normalization factor so that xcs/denom will be true
%correlation values.
%Note that length(xcs)=max_d-min_d+1. xcs(1) is associated with min_d,
%xcs(end) is associated with max_d.
%Note also that this function always uses a fixed segement of samples of y.
%The number of samples in this fixed segment is maximized given the
%constraints imposed by the lengths of x and y as well as the values of
%min_d and max_d.
%ystart and y stop are the first and last samples of y that are used in
%the fixed segment.
%Find number of shifts
nshifts=max_d-min_d+1;
%Initialze correlation results variable
xcs=zeros(nshifts,1);
%Find two lengths
nx=length(x);
ny=length(y);
%Find segment of y that can be used
ystart=max(1,max_d+1); %ystart is first sample of y to use
if ny - min_d <= nx
ystop=ny; %ystop is last sample of y to use
else
ystop=nx+min_d;
end
%Generate error if there is no useable segment of y
if ystop<ystart
error('Not enough input samples to calculate all delay values.')
end
%Extract segment of y
temp_y=y(ystart:ystop);
%Find number of samples in segment
m=ystop-ystart+1;
%Loop over all shifts
for i=1:nshifts
%Update current delay value
cd=min_d+i-1;
xstart=ystart-cd;
%Extract proper segment of x
temp_x=x(xstart:xstart+m-1);
%Form partial denominator of correlation so it can be tested
%to prevent divide by zero
denom=temp_x'*temp_x;
if denom>0
%Correlation
xcs(i)=(temp_x'*temp_y)/sqrt(denom);
else
%When segment of x has no signal, correlation is zero
xcs(i)=0;
end
end
%Find the fixed portion of the denominator
denom=sqrt(temp_y'*temp_y);
%==========================================================================
function [un_corr,denom]=non_fft_xc_all(x,y)
%This function applies a direct-form cross correlation to the column
%vectors of speech samples x and y. This correlation is done for all
%possible shifts that use all of y.
%The unnormalized correlation values are returned in un_cor, and the
%denominator is returned in denom.
%It is required that length(x)>=length(y).
%Find lengths
nx=length(x);
ny=length(y);
%Find number of possible shifts
nshifts=nx-ny+1;
%Initialize results variable
un_corr=zeros(nshifts,1);
%Loop over all possible shifts
for i=1:nshifts
temp_x=x(i:i+ny-1);
%Form partial denominator of correlation so it can be tested
%to prevent divide by zero
denom=temp_x'*temp_x;
if denom>0
%Correlation
un_corr(i)=(temp_x'*y)/sqrt(denom);
else
%When segment of x has no signal, correlation is zero
un_corr(i)=0;
end
end
%Find fixed portion of denominator
denom=sqrt(y'*y);
%==========================================================================
function SDVout=short_seg_cor(SDVin,x_speech,y_speech,len_t,len_b,len_s)
%Usage: SDVout=short_seg_cor(SDVin,x_speech,y_speech,len_t,len_b,len_s)
%This function tests all pulses (also called blips), steps and tails in
%an estimated delay history and removes them when appropriate
%
%x_speech and y_speech are are column vectors that hold system under test
% input and output speech samples (without any delay compensation)
%len_t is the length in ms of the longest tail that should be removed
%len_b is the length in ms of the longest blip that should be removed
%len_s is the length in ms of the longest step that should be removed
%SDVin and SDVout are Delay history matricies in the fs=8000 domain. There
%is one row per segment of constant delay
%Column 1, Sample number of last sample of constant delay segment
%Column 2, estimated Delay of segment
%Column 3, Validity of delay estimation for segment
% (0 for invalid, 1 for valid)
%Convert from ms to samples
len_t=8*len_t;
len_b=8*len_b;
len_s=8*len_s;
%Find number of segments of constant delay
nsegs=size(SDVin,1);
%Find length of each segment
seglens=diff([0;SDVin(:,1)]);
%Append two columns to SDVin. SDVin now has
%Column 1, Sample number of last sample of constant delay segment
%Column 2, estimated Delay of segment
%Column 3, Validity of delay estimation segment (0=invalid, 1=valid)
%Column 4, Number of samples in segment
%Column 5, Status of segment (0=needs to be considered, 1=should be
%ingnored) Start with all zeros.
SDVin=[SDVin,seglens,zeros(nsegs,1)];
%Find location and type of the shortest segment with status 0 in SDVin
[ptr,seg_type]=find_smallest_seg(SDVin);
%If there is such a segment
if ptr~=0;
%Extract its length
current_seg_len=SDVin(ptr,4);
else
%Otherwise create a fictitious segment length that is long enough
%to prevent entering the "while loop" that follows
current_seg_len=max([len_t len_b len_s])+1;
end
%While the shortest segment qualifies for consideration under at least
%one of the three length thresholds
while current_seg_len<=max([len_t len_b len_s])
%Find number of segments in current version of SDVin
n=size(SDVin,1);
%If current segment is a left tail and conforms with tail threshold
if seg_type=='LT' & current_seg_len <= len_t
%Join current segment to right neighbor segment
%to create new combined segment
SDVin=SDVin(setdiff(1:n,ptr),:);
%(Setdiff is the set difference function. As called above, it
%returns a length n-1 vector containing 1,2,...ptr-1, ptr+1, ...n)
%Set status on the new combined segment to 0 so it receives
%further consideration
SDVin(ptr,5)=0;
%Store the length of the new combined segment
SDVin(ptr,4)=SDVin(ptr,4)+current_seg_len;
%If current segment is a right tail and conforms with tail threshold
elseif seg_type=='RT' & current_seg_len <= len_t
%Join current segment to left neighbor segment
%to create new combined segment
current_seg_end=SDVin(ptr,1);
SDVin=SDVin(setdiff(1:n,ptr),:);
SDVin(ptr-1,1)=current_seg_end;
%Set status on the new combined segment to 0 so it receives
%further consideration
SDVin(ptr-1,5)=0;
%Store the length of the new combined segment
SDVin(ptr-1,4)=SDVin(ptr-1,4)+current_seg_len;
%If current segment is a blip and conforms with blip threshold
elseif seg_type=='BI' & current_seg_len <= len_b
%Join current segment and left neighbor to right neighbor segment
%to create new combined segment
left_neb_len=SDVin(ptr-1,4);
SDVin=SDVin(setdiff(1:n,[ptr-1 ptr]),:);
%Set status on the new combined segment to 0 so it receives
%further consideration
SDVin(ptr-1,5)=0;
%Store the length of the new combined segment
SDVin(ptr-1,4)=SDVin(ptr-1,4)+current_seg_len+left_neb_len;
%If current segment is a step and conforms with step threshold
elseif seg_type=='SP' & current_seg_len <= len_s
%Join current segment to left or right neighbor or leave it
%as is. Choice of these 3 actions depends on correlation results
%-----------------------Preparations-------------------------------
start=SDVin(ptr-1,1)+1;%First sample of current segment
stop=SDVin(ptr,1); %Last sample of current segment
L_dly=SDVin(ptr-1,2); %Delay of segment left of current segment
C_dly=SDVin(ptr,2); %Delay of current segment
R_dly=SDVin(ptr+1,2); %Delay of segment right of current segment
%Correlation at delay of left neighbor
lcorr=single_corr(x_speech,y_speech,start,stop,L_dly);
%Correlation at delay of right neighbor
rcorr=single_corr(x_speech,y_speech,start,stop,R_dly);
%Correlation at delay of current segment
ccorr=single_corr(x_speech,y_speech,start,stop,C_dly);
%Which of these 3 correlations is largest?
[dud,loc]=max([lcorr rcorr ccorr]);
%If correlation at delay of left neighbor is largest
if loc==1
%Join current segment to left neighbor segment
%to create new combined segment
current_seg_end=SDVin(ptr,1);
SDVin=SDVin(setdiff(1:n,ptr),:);
SDVin(ptr-1,1)=current_seg_end;
%Set status on the new combined segment to 0 so it receives
%further consideration
SDVin(ptr-1,5)=0;
%Store the length of the new combined segment
SDVin(ptr-1,4)=SDVin(ptr-1,4)+current_seg_len;
%If correlation at delay of right neighbor is largest
elseif loc==2
%Join current segment to right neighbor segment
%to create new combined segment
SDVin=SDVin(setdiff(1:n,ptr),:);
%Set status on the new combined segment to 0 so it receives
%further consideration
SDVin(ptr,5)=0;
%Store the length of the new combined segment
SDVin(ptr,4)=SDVin(ptr,4)+current_seg_len;
else
%Don't change the step, but change its status to 1 for no
%further consideration
SDVin(ptr,5)=1;
end
%For all other segment types, this function makes no changes.
else
%Change status to 1 for no further consideration
SDVin(ptr,5)=1;
end
%Find location and type of the shortest segment with status 0 in SDVin
[ptr seg_type]=find_smallest_seg(SDVin);
%If there is such a segment
if ptr~=0;
%Extract its length
current_seg_len=SDVin(ptr,4);
else
%Otherwise create a fictitious segment length that is long enough
%to terminate the "while loop"
current_seg_len=max([len_t len_b len_s])+1;
end
%End of while loop
end
%SDVout contains just the first 3 columns of SDVin
SDVout=SDVin(:,1:3);
%Identify the segments that reflect a change in delay or validity
keepers=[find( (diff(SDVout(:,2))~=0) | ...
(diff(SDVout(:,3))~=0));size(SDVout,1)];
%Retain only those segments
SDVout=SDVout(keepers,:);
%==========================================================================
function rho=single_corr(x_speech,y_speech,start,stop,delay)
%Usage: rho=single_corr(x_speech,y_speech,start,stop,delay)
%This function calculates a single correlation value between
%a segment of x_speech and y_speech. The goal is to use the
%samples of y_speech from "start" to "stop" inclusive and the
%corresponding portion of x_speech, but shifted forward in time
%by the number of samples specified in "delay."
%These segments may be shortened as necessary if not enough
%samples are available.
%The correlation is direct-form and is performed by the
%function non_fft_xc_all
%First sample of x_speech that will be used
sstart=start-delay;
lefttrim=0;
%If that sample does not exist
if sstart<1
%It is necessary to shift the start of the correlation window
lefttrim=1-sstart;
sstart=1;
end
%Last sample of x_speech that will be used
sstop=stop-delay;
ns=length(x_speech);
righttrim=0;
%If that sample does not exist
if sstop>ns
%It is necessary to shift the end of the correlation window
righttrim=sstop-ns;
sstop=ns;
end
%Extract speech from correlation window and rectify
x=abs(x_speech(sstart:sstop));
y=abs(y_speech(start+lefttrim:stop-righttrim));
%Perform unnormalized correlation
[rho,denom]=non_fft_xc_all(x,y);
%Normalize to find correlation value
rho=rho/denom;