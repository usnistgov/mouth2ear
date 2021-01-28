import numpy as np
import scipy.signal as sig
from numpy.fft import fft, ifft

def ITS_delay_est(x_speech,y_speech,mode, fsamp=8000, dlyBounds = [np.NINF, np.inf]):

    #Usage: Delay_est=ITS_delay_est(x_speech,y_speech,mode)
    #
    #This function estimates the delay history for the speech samples in
    #y_speech relative to the speech samples in x_speech.
    #
    #x_speech and y_speech are row vectors of speech samples
    #with sample rate 8000 samples/sec. At least 1185 samples (148 ms)
    #is required in each vector.
    #
    #mode='f','v', or 'u' for fixed delay, variable delay or unknown delay type
    #
    #fsamp is the sample rate, defaults to 8000
    #
    #dlyBounds are the 
    #Delay_est holds estimates of the delay of the speech samples in y_speech
    #relative to speech samples in x_speech. Typically y_speech contains
    #samples from the output of some system under test, and x_speech contains
    #the corresponding input samples. Delay_est then holds estimates of the
    #delay of that system under test.
    #
    #Delay_est is 2 by n, with one row for each segment of constant delay.
    #Column 0 holds the number of the last sample of a segment of constant
    #delay, column 1 holds the estimated delay for that segment. Here are two
    #examples:
    #
    #Example 1 Delay_est=[32000,17] means that a single delay estimate of 17
    #samples applies to samples with indices [0, 32000] in y_speech
    #
    #Example 2 Delay_est=[12345,-2
    # 32000,400]
    #means that for samples 0 through 12345, the delay is estimated to be -2
    #samples. For samples 12346 through 32000, the delay is estimated to be
    #400 samples.
    #
    #In addition, the output [0 0] indicates no delay estimation was possible.
    #This can happen when x_speech and y_speech contain unrelated signals,
    #or no signal at all.
    #
    #Written by Stephen Voran at the Institute for Telecommunication Sciences,
    #325 Broadway, Boulder, Colorado, USA, svoran@its.bldrdoc.gov
    #May 10,2004

    #----------------------------Parse Arguments--------------------------------
    x_speech = np.array(x_speech, dtype=np.float64)
    if len(x_speech) == 0 or x_speech.ndim != 1:
        raise ValueError("error with input x_speech")

    y_speech = np.array(y_speech, dtype=np.float64)
    if len(y_speech) == 0 or y_speech.ndim != 1:
        raise ValueError("error with input x_speech")

    if mode not in ("f", "v", "u"):
        raise ValueError("errpr with input mode")

    dlyBounds = np.array(dlyBounds, dtype=np.float64)
    if len(dlyBounds) != 2:
        raise ValueError("error with optional input")
    elif dlyBounds[1] <= dlyBounds[0]:
        raise ValueError("error with optional input")

    #----------------------Resample Arguments to 8kHz--------------------------
    if fsamp != 8000:
        xlen = len(x_speech)
        ylen = len(y_speech)
        x_speech = sig.resample(x_speech, int(xlen * 8000/fsamp))
        y_speech = sig.resample(y_speech, int(ylen * 8000/fsamp))

    #--------------------------Level Normalization-----------------------------#
    #Measure active speech level
    asl_x=active_speech_level(x_speech)
    asl_y=active_speech_level(y_speech)
    #Force active speech level to -26 dB r.e. overload
    x_speech= x_speech * 10 ** ((asl_x + 26)/ -20)
    y_speech= y_speech * 10 ** ((asl_y + 26)/ -20)
    #---------------------Coarse Average Delay Estimation----------------------#
    tau_0,rho_0,fir_coeff_63=coarse_avg_dly_est(x_speech,y_speech, dlyBounds)
    #Compensate for tau_0, comp_x_speech and comp_y_speech will have same length
    comp_x_speech,comp_y_speech=fxd_delay_comp(x_speech,y_speech,tau_0)
    #If compensation for tau_0 results in a speech vector that is shorter
    #than 1185 samples, then the input signal vectors x_speech and y_speech
    #are not sufficent for delay estimation. (They may contain unrelated
    #signals, no signal, or may simply be too short)
    if len(comp_x_speech)<1185:
        #Algorithm must terminate
        mode='t'
    #------------Do further mode determination as necessary/possible-----------#
    if mode=='u' and rho_0<.96:
        mode='v'
    #-----Fine delay estimation for the fixed and unknown delay cases----------#
    if mode=='f' or mode=='u':
        #Find fine delay
        fxd_fine_delay=fxd_fine_dly_est(comp_x_speech,comp_y_speech)
        #Find total delay
        D_fxd=tau_0+fxd_fine_delay
    #-------Additional stages for the variable and unknown delay cases---------#
    if mode=='v' or mode=='u':
        #---------------------Speech Activity Detection------------------------#
        #Identify active speech samples (active_wf is same size as y_speech,
        #1 indicates activity, 0 otherwise)
        active_wf=find_activity_wf(y_speech,fir_coeff_63)
        #Compensate the activity waveform for tau_0
        _, comp_active_wf=fxd_delay_comp(x_speech,active_wf,tau_0)
        #--------------------------Delay Tracking------------------------------#
        DCAVS=delay_tracking(comp_x_speech,comp_y_speech,comp_active_wf,150,40,200)
        #--------------------------Median Filtering----------------------------#
        SDV=median_filter(DCAVS,500,40,.1,.8)
        #---------------------Combine Results with tau_0-----------------------#
        SDV[:,1]=SDV[:,1]+tau_0  #Add in tau_0 to delay estimates
        if 0<tau_0: #If tau_0 is a positive quantity
        #then adjust locations of delay segments as well
            SDV[:,0]=SDV[:,0]+tau_0
        #Adjust final location to exactly match end of y_speech
        SDV[-1,0]=len(y_speech)-1
        #----------------------------Delay Refinement--------------------------#
        SDV=delay_refine(SDV,x_speech,y_speech,active_wf,72,.7)
        #---------------Remove Redundant Entries in SDV matrix-----------------#
        #If delay and validity do not change from segment n to n+1, then
        #segment n is redundant
        keepers=np.append(np.nonzero(np.logical_or(np.diff(SDV[:,1])!=0, np.diff(SDV[:,2])!=0))[0], np.size(SDV,0)-1)
        SDV=SDV[keepers,:]
        #Adjust final location to exactly end y_speech
        SDV[-1,0]=len(y_speech)-1
        #-----------------Round Delay Estimates to Nearest Integer-------------
        SDV[:,1]=np.round(SDV[:,1])
        #-----------------------Short Segment Correction------------------------
        if np.size(SDV,0)>1:
            SDV=short_seg_cor(SDV,x_speech,y_speech,160,280,80)
    
    #--------------------------Apply LSE if Necessary--------------------------
    if mode=='u':
        [lse_f,lse_v]=LSE(x_speech,y_speech,D_fxd,SDV,16) 

        if lse_f <= lse_v:
            mode='f' 
        else:
            mode='v'
    #---Select Output, Extrapolate Variable Delay Estimate if Necessary--------
    if mode=='v':
        Delay_est=extend_val_res(SDV)    #Extrapolate variable delay estimate
    elif mode=='f':
        Delay_est=[len(y_speech)-1, D_fxd]   #Reformat fixed delay estimate
    else:   #Mode is 't' for terminate
          #The output [0 0] indicates no delay estimation was possible
        Delay_est=[0, 0] 
    return np.array(Delay_est) * int(fsamp/8000)
    #==========================================================================

def active_speech_level(x):
    #Usage: asl=active_speech_level(x)
    #This function measures the active speech levels in the speech vector x.
    #x is a vector of speech samples
    #asl is the active speech level in dB relative to overload
    #Just edit fs to operate at other sample rates
    fs=8000 #samples/second
    #code will extend each active region by tau samples (forward in time)
    tau=round(.200*fs)
    #active speech is defined to be dBth dB below max
    dBth=20
    n=len(x)
    x=x - np.mean(x) #mean removal
    x=np.abs(x)
    #calculate filter coefficient from time constant
    g=np.exp(-1/(fs*.03))
    #perform 2nd order IIR filtering
    x=sig.lfilter([(1-g)**2], [1, -2*g, g*g], x)
    at=max(x)*(10**(-dBth/20))  #calculate activity threshold

    if (at==0):
        raise ValueError('Input vector has no signal')
    active= (x > at) #find active samples
    #Extend each active interval tau samples forward in time
    trans=np.nonzero(np.abs(np.diff(active)))[0]

    for i in range(0, len(trans)):
        active[trans[i]: min(trans[i]+tau,n-1)+1] = 1

    #Test for both activity and non-zeroness to prevent log(0)
    x = x[np.logical_and(0 < x, active)]
    asl = 20 * np.mean(np.log10(x)) - 81
    return asl

#==========================================================================
def find_fir_coeffs(order,cutoff):
    #Usage: b=find_fir_coeffs(order,cutoff)
    #This function generates filter coefficients for an FIR LPF with
    #the specified order and cutoff frequency. Cutoff frequency
    #is specified relative to Nyquist frequency. b is a row vector
    #of length order+1 that holds the filter coefficients
    #Create vector that holds Hamming window of length order+1
    n=order+1
    h=0.54-0.46*np.cos(2*np.pi/(n-1) * np.arange(0,n))
    #Create vector of time-domain indices
    t=np.arange(-order*cutoff/2, (order*cutoff/2) + cutoff, cutoff)
    #Calculate sin(pi*x)/(pi*x) (sinc function) for time domain indices
    #sin(pi*0)/(pi*0) is defined to be 1
    good = t!=0
    sinxox=np.ones(order+1)

    sinxox[good] = np.sin(np.pi * t[good])/(np.pi*t[good])
    #np.sin(np.pi * t[good])/(np.pi*t[good])
    #Filter coefficients are product of window and sinc function
    b=h*sinxox
    #Normalize coefficients for unity gain in passband
    b=b/sum(b)
    return b
#==========================================================================
def coarse_avg_dly_est(x,y,b):
    #Usage: tau_0,rho_0,fir_coeff=coarse_avg_dly_est(x,y, b)
    #This function generates a coarse delay estimate from speech envelopes.
    #This is done in the fs=125 samples/sec domain. (i.e., sub-sampling by 64).
    #x and y are vectors of speech samples
    #b is tuple of a lower and uooer bound, used for filtering out invalid shifts
    #tau_0 is a delay estimate in samples
    #rho_0 is the corresponding correlation value
    #fir_coeff is a set of 401 FIR filter coefficients for a 63 Hz LPF
    fir_coeff=find_fir_coeffs(400,1/133.33) #calculate filter coeffs
    ex=sig.lfilter(fir_coeff,1,np.abs(x))  #63 Hz LPF, order 400 FIR
    ey=sig.lfilter(fir_coeff,1,np.abs(y))
    #There is no need to remove filter delay since it is the same in each
    #signal
    ex=ex[0::64] #Subsample by 64
    ey=ey[0::64]
    #zero pad so ex and ey have same length
    lx=len(ex)
    ly=len(ey)
    L=max(lx,ly)
    ex=np.append(ex, np.zeros(L-lx))
    ey=np.append(ey, np.zeros(L-ly))
    corrlen=len(ex)

    m=np.mean(ex)
    #Remove mean of ex from both ex and ey
    ex=ex-m
    ey=ey-m
    #FFT based cross correlation
    N = 2 * len(ex)
    term1 = fft(np.append(ex, np.zeros(corrlen)))
    term2 = fft(np.append(ey[::-1], np.zeros(corrlen)))

    xc= np.real(ifft(term1*term2))
    #calculate shifts in seconds
    shift=64*(corrlen-np.arange(1, len(xc)+1))
    #calculate which shifts are valid
    valid=np.logical_and((shift*8e3)>b[0], (shift*8e3)<b[1])
    #calculate which shifts are valid
    valid_shifts=shift[valid]

    check = xc[valid]
    rho = max(check)
    index = np.argmax(check)
    #Convert peak location to a shift
    tau_0=valid_shifts[index]
    #Normalize to get cross correlation value
    rho_0=rho/((corrlen-1)*np.std(ex, ddof=1)*np.std(ey, ddof=1))
    return tau_0, rho_0, fir_coeff

#==========================================================================
def fxd_delay_comp(source,distorted,delay):
    #Usage: source,distorted=delay_comp(source,distorted,delay)
    #This function compensates the source-distorted signal pair by the given
    #delay value in samples. The returned source and distorted signals will
    #have the same length.
    sstart=max(0,-delay)  #source starting point
    dstart=max(0,delay)  #distorted starting point
    #Number of samples available
    samples=min(len(source)-sstart,len(distorted)-dstart)
    #Extract proper portions
    source=source[sstart: sstart+samples]
    distorted=distorted[dstart: dstart+samples]
    return source, distorted


#==========================================================================
def fxd_fine_dly_est(x,y):
    #Usage: D=fxd_fine_dly_est(x,y) 
    #This function performs an FFT-based cross correlation on the rectified
    #speech signals and then processes the results to find a delay estimate
    #x and y are  vectors of speech samples
    #D is the estimated delay
    ran=128 #half width of range of samples to analyze in this stage
    #number of samples to feed into filter while waiting for it to stabilize
    headlen=500
    #number of samples (a tail) long enough to cover the longest filter delay
    taillen=200
    #find cross correlation of rectified speech
    xc,denom=fft_xc(np.abs(x),np.abs(y),-(ran+headlen),ran+taillen)
    #extract relevant portion
    txc=xc[headlen:headlen+1+2*ran]
    #find max
    maxrho = max(txc)
    index = np.argmax(txc)
    
    maxrho=maxrho/denom 
    if .73<maxrho: #For high correlations, no smoothing is required
        D=index-ran  #Calculate delay estimate
    else:
        if .67<maxrho: #For medium correlations, some smoothing helps
            m=64
        else: #For lower correlations, more smoothing helps
            m=128 
        flen=3*m 
        fir_coeff=find_fir_coeffs(flen,1/m)  #Filter lengths are even
        sxc=sig.lfilter(fir_coeff,1,xc) 
        #smoothed version of cross-correlation function with filter delay
        #removed
        sxc=sxc[int(headlen+(flen/2)):int(headlen+(flen/2)+1+2*ran)]
        index = np.argmax(sxc) 
        D=index-ran  #Calculate delay estimate
    return D

#==========================================================================
def fft_xc(x,y,min_d,max_d):
    #Usage: un_corr,denom=fft_xc(x,y,min_d,max_d)
    #This function does an fft-based cross correlation on the waveforms in the
    #vectors x and y. These two vectors need not have the same length,
    #but the resulting delay estimated is defined relative to zero time offset
    #of x(1) and y(1).
    #
    #If possible, an unnormalized correlation value is returned for all delay
    #values from min_d to max_d, inclusive. (If this is not possible, it is
    #an error condition)
    #
    #Thus un_corr is a length max_d-min_d+1 vector. When it is divided
    #by denom (typically after finding a max), correlation values result.
    #un_corr(1) corresponds to min_d, un_corr(end) corresponds to max_d
    #The legal search window is approximately +/- min(length(x),length(y).
    #Pad with zeros so x and y have same length
    lx=len(x)
    ly=len(y)
    L=max(lx,ly)
    x=np.append(x, np.zeros(L-lx))
    y=np.append(y, np.zeros(L-ly))
    corrlen=len(x)
    #Remove the mean of x from each signal
    m=np.mean(x)
    x=x-m
    y=y-m
    #Perform FFT-based cross correlation
    term1 = fft(np.append(x, np.zeros(corrlen)))
    term2 = fft(np.append(y[::-1], np.zeros(corrlen)))
    xc=np.real(ifft(term1 * term2))
    xc=xc[::-1] #reverse the vector
    #Test to see if requested values of delay are available
    if corrlen+min_d+1<1 or 2*corrlen < corrlen+max_d+1:
        error('Not enough input samples to calculate requested delay values.')
    #Extract requested values of delay
    un_corr=xc[corrlen+min_d:corrlen+max_d+1]
    #Calculate the denominator
    denom=(corrlen-1)*np.std(x, ddof=1)*np.std(y, ddof=1) 
    return un_corr,denom
#==========================================================================
def find_activity_wf(x,fir_coeff):
    #Usage: active_x=find_activity_wf(x,fir_coeff)
    #This function generates an output vector (active_x) that shows the
    #speech activity waveform of the input vector (x).
    #Speech activity is defined via a smoothed speech envelope with nominal
    #bandwidth of 63 Hz. The required FIR filter coefficients are given in
    #fir_coef. Samples of the envelope that are within 35 dB of
    #the envelope peak are associated with active speech. Each interval of
    #activity is extended by tau samples forward and backward in time.
    th=35  #Threshold for activity detection in dB below peak
    tau=800  #Number of samples to extend each active segment in each direction
    nx=len(x)
    #FIR filter rectified speech
    x=sig.lfilter(fir_coeff,1,np.append(np.abs(x), np.zeros(200)))
    x=x[200:] #Remove filter delay
    #Find samples that are above threshold,1 means active, 0 means not active
    active_x = x >= 10 ** (th/20.)
    #Extend all active regions by tau samples in each direction
    trans=np.nonzero(np.abs(np.diff(active_x)))[0] #List of transition points
    for j in range(0, len(trans)): #Loop over all transitions
        #Extend activity in each direction
        active_x[max(trans[j]-tau,0):min(trans[j]+tau,nx-1)+1]=1
    return active_x
#==========================================================================
def delay_tracking(x,y,active_wf,winlen,winstep,ran):
    #Usage: DCAVS=delay_tracking(x,y,active_wf,winlen,winstep,range) 
    #This function does delay tracking (delay in speech signal y relative to x)
    #winlen is the length of window used for the delay estimation alg (in ms)
    #winstep is the step size between windows (in ms)
    #range is the half-width of the search range (in ms) 
    #DCAVS is a nwins by 5 matrix, where nwins is the number of delay
    #estimation windows that can be fit into y
    #Column 0 holds Delay values (in the 16:1 subsampled domain)
    #Column 1 holds the corresponding Correlation values
    #Column 2 holds the corresponding Activity levels values
    #Column 3 holds the corresponding Validities (True for valid delay estimate,
    # False otherwise)
    #Column 4 holds the Sample number in y (in the 16:1 subsampled domain)
    #that is at the center of each window
    #Create coefficients for an FIR LPF with 129 taps and a delay of
    #64 samples. Response is -51 dB at 250 Hz.
    fir_coeffs=find_fir_coeffs(128,1/32) 
    #Rectify and filter
    x=sig.lfilter(fir_coeffs,1,np.append(np.abs(x), np.zeros(64)))
    #Remove filter delay and subsample by 16
    x=x[64::16] 
    nx=len(x) 
    #Rectify and filter
    y=sig.lfilter(fir_coeffs,1,np.append(np.abs(y), np.zeros(64)))
    #Remove filter delay and subsample by 16
    y=y[64::16] 
    #Subsample activity waveform
    active_wf=active_wf[0::16] 
    #Force subsampled activity waveform to have same length as subsampled y
    ny=len(y) 
    len_diff=len(active_wf)-ny 
    if 0<len_diff:
        active_wf=active_wf[0:ny]  #Trim final samples
    elif len_diff<0:
        active_wf=np.append(active_wf, np.zeros(len_diff))   #Zero pad
    #Convert parameters from ms to samples (in the subsampled domain)
    winlen=round(winlen/2) 
    winstep=round(winstep/2) 
    ran=round(ran/2) 
    #Find total number of window positions that can be placed on y
    nwins= np.floor((ny-winlen)/winstep)+1 
    DCAVS=np.zeros((int(nwins),5)) 
    #Find locations of centers of windows (sample number in subsampled domain)
    first=(winlen+1)/2 -1
    last=first+winstep*(nwins-1)
    DCAVS[:,4]=np.arange(first, last+winstep, winstep)
    for i in range(0, int(nwins)):  #Loop over all windows
        start=i*winstep   #First sample in window
        stop=start+winlen   #Last sample in window
        #Find activity level in window
        DCAVS[i,2]=sum(active_wf[start:stop])/winlen 
        #Assume delay estimation is doable unless one of tests that
        #follows fails
        doable=True
        if start-ran < 0 or min(nx,ny) < stop+ran:
            #Not enough samples to do delay estimation
            doable=False
        elif np.std(y[start:stop+1], ddof=1)==0 or np.std(x[start-ran:stop+ran+1], ddof=1)==0:
            #No variation in samples
            doable=False        
        if doable:
            #Perform direct-form cross correlation
            xc,denom=non_fft_xc(x[start-ran:stop+ran], y[start-ran:stop+ran],-ran,ran)
            #Identify peak
            maxrho,index=np.max(xc), np.argmax(xc) 
            #Calculate corresponding delay in samples
            #USED TO BE  A MINUS ONE HERE
            DCAVS[i,0]=index-ran
            #Calculate corresponding correlation value
            DCAVS[i,1]=maxrho/denom
             #Mark that window as having a valid delay estimate
            DCAVS[i,3]=True
    return DCAVS
 #==========================================================================

def non_fft_xc(x,y,min_d,max_d):
    #Usage: xcs,denom,ystart,ystop=non_fft_xc(x,y,min_d,max_d)
    #This function enables delay estimation by calculating the cross
    #correlation between two vectors of speech samples x and y at the
    #specified shifts. x and y need not have the same length. Zero delay
    #is associated with the case where x(1) aligns with y(1). x and y may
    #be row or vectors. Cross correlations are performed at all
    #delays between min_d and max_d (given in samples) inclusive. If the
    #length of x or y prevents this, an error is generated.
    #xcs is a vector and holds unnormalized correlation values for all
    # requested delays
    #denom is the normalization factor so that xcs/denom will be true
    #correlation values.
    #Note that length(xcs)=max_d-min_d+1. xcs(1) is associated with min_d,
    #xcs(end) is associated with max_d.
    #Note also that this function always uses a fixed segement of samples of y.
    #The number of samples in this fixed segment is maximized given the
    #constraints imposed by the lengths of x and y as well as the values of
    #min_d and max_d.
    #ystart and y stop are the first and last samples of y that are used in
    #the fixed segment.
    #Find number of shifts
    nshifts=max_d-min_d+1
    #Initialze correlation results variable
    xcs=np.zeros(nshifts)
    #Find two lengths
    nx=len(x)
    ny=len(y)
    #Find segment of y that can be used
    ystart=max(0,max_d)  #ystart is first sample of y to use
    if ny - min_d < nx:
        ystop=ny #ystop is last sample of y to use
    else:
        ystop=nx+min_d
    #Generate error if there is no useable segment of y
    if ystop<ystart:
        raise ValueError('Not enough input samples to calculate all delay values.')
    #Extract segment of y
    temp_y=y[ystart:ystop]
    #Find number of samples in segment
    m=ystop-ystart
    #Loop over all shifts
    for i in range(0,nshifts):
        #Update current delay value
        cd=min_d+i
        xstart=ystart-cd
        #Extract proper segment of x
        temp_x=x[xstart:xstart+m]
        #Form partial denominator of correlation so it can be tested
        #to prevent divide by zero
        denom=np.dot(temp_x, temp_x)
        if denom>0:
            #Correlation
            xcs[i]=np.dot(temp_x, temp_y)/np.sqrt(denom)
        else:
            #When segment of x has no signal, correlation is zero
            xcs[i]=0
    #Find the fixed portion of the denominator
    denom=np.sqrt(np.dot(temp_y, temp_y))
    return xcs,denom
#=========================================================================='''
def median_filter(DCAVS,twinlen,winstep,activity_th,cor_th):
    #Usage: SDV=median_filter(DCAVS,twinlen,winstep,activity_th,cor_th) 
    #This function does the median filtering on the results in the DCAVS
    #matrix. The DCAVS matrix is defined in the delay_tracking function.
    #
    #twinlen is the length of the median filtering window in ms
    #winstep tell how many ms each step in DCAVS matrix corresponds to worth
    #activity_th is the activity threshold required for a sample to be included
    # in the median filter
    #cor_th is the correlation threshold required for a sample to be for
    # included in the median filtering
    #
    #Results are returned in the matrix SDV. Each row of SDV describes a
    #segment of constant delay. SDV is in the fs=8000 domain.
    #Column 0, Sample number of last sample of constant delay segment
    #Column 1, estimated Delay of segment
    #Column 2, Validity of delay estimate (0 for invalid, 1 for valid)
    #
    #SDV(end,1) is given by the center of the final window (DCAVS(end,5)),
    #converted from the fs=500 domain to the fs=8000 domain. Note that in
    #general, this will not be exactly the same as the length of the
    #speech signal y (output from system under test).
    #
    #If no valid information can be extracted from DCAVS, the result is a delay
    #of zero everywhere.
    #Extract number of time samples available
    nwins=np.shape(DCAVS)[0]
    #Create a temporary matrix. It has 1 row for each row of DCAVS.
    #Column 0 will hold delay estimates
    #Column 1 will hold True if that estimate is valid, False otherwise
    #Column 2 will hold the distorted speech envelope sample number
    #(in the fs=500 domain) associated with the delay estimate
    T=np.column_stack((np.zeros((nwins,2)),DCAVS[:,4]))
    #Find half-width of median filtering window in samples
    htwinlen=round(twinlen/(2*winstep)) 
    #Good is a vector with length nwins. It has a 1 where a
    #delay estimate has correlation that meets or exceeds threshold,
    #activity that meets or exceeds threshold, and is mathematically valid.
    #It has a zero elsewhere.
    good=np.logical_and.reduce((cor_th<=DCAVS[:,1], activity_th<=DCAVS[:,2], DCAVS[:,3]))
    #Loop over all samples
    for i in range(0,nwins):
        #Check number of samples between sample and last sample
        nsmp=min(i,nwins-i-1)
        #Find final half-width of median filtering window (cannot exceed the
        #number of remaining samples)
        fhtwinlen=min(htwinlen,nsmp) 
        start=i-fhtwinlen  #First sample in current window
        stop=i+fhtwinlen+1  #Last sample in current window
        #If there is a least one good sample in the window
        if sum(good[start: stop+1]) > 1:
            #Form list of absolute indices of good samples
            goodlist=start+np.nonzero(good[start:stop])[0]
            #Perform median filtering on the good samples
            #Note on median function: When presented with an even number of
            #samples, this median function returns the average of the two
            #central samples. e.g. median([1 2 3 4])=2.5
            T[i,0]=np.median(DCAVS[goodlist,0]) 
            #Mark that a valid result has been calculated
            T[i,1]=True
    #Find how many valid results have been calculated
    nvalres=sum(T[:,1]) 
    #If no valid results have been calculated, report zero delay everywhere
    if nvalres==0:
        SDV=[DCAVS[:,4],0,0] 
    else:
        #List only results that describe a change in delay or a change in
        #validity, plus the final result
        keepers=np.append(np.nonzero(np.logical_or(np.diff(T[:,0])!=0, np.diff(T[:,1])!=0)), nwins-1)
        #Keep only those results
        SDV=np.column_stack((T[keepers,2], T[keepers, 0], T[keepers, 1]))
    #Convert final results from fs=500 samples/sec domain to the
    #fs=8000 samples/sec domain
    SDV[:,1]=SDV[:,1]*16  #Convert delay estimates
    SDV[:,0]=(SDV[:,0])*16+8  #Convert sample values
    return SDV
#==========================================================================

def delay_refine(SDVin,x_speech,y_speech,active_wf,ran,cor_th):
    #Usage: SDVout=delay_refine(SDVin,x_speech,y_speech,active_wf,range,cor_th)
    #This function refines the input delay matrix SDVin, to generate SDVout.
    #SDVin and SDVout are in the fs=8000 domain and have one row per segment
    #of constant delay.
    #Column 0, Sample number of last sample of constant delay segment
    #Column 1, estimated Delay of segment
    #Column 2, Validity of delay estimation segment (0 for invalid, 1 for valid)
    #
    #x_speech and y_speech are vectors of speech samples
    # with sample rate 8000 samples/sec. (x_speech is associated with system
    # under test input, y_speech is associated with system under test output)
    #active_wf has the same size as y_speech. 1 indicates speech activity,
    # 0 otherwise.
    #range gives the search range for this stage in samples
    #cor_th is the correlation threshold for refinement
    #Rectify speech
    x_speech=np.abs(x_speech) 
    y_speech=np.abs(y_speech) 
    #Copy all data, function will refine it where possible
    SDVout=SDVin 
    #Find number of segments of constant delay
    nsegs=np.size(SDVin, axis=0)
    #Loop over all segments
    for i in range(0, nsegs):
        #Find first sample of current segment (first segment is special case)
        if i==0:
            start=0
        else:
            start=int(SDVin[i-1,0]+1) 
        #Extract last sample of current segment
        stop=int(SDVin[i,0]) 
        #Extract delay of current segment
        delay=SDVin[i,1] 
        #Attempt refinement only if there is at least 10 ms of active speech
        #in the segment and segment has a valid delay estimate
        if 80 <= sum(active_wf[start:stop+1]) and SDVin[i,2]==1:
            #If segment length is at least 200 ms, use fft-based correlation
            if 1600 <= (stop-start+1):
                #Find delay compensated starting sample in x_speech
                sstart=start-delay
                #If it is before the start of x_speech, it will be necessary to
                #modify the starting place in both x_speech and y_speech
                if sstart<0:
                    #Number of samples involved in the modifications
                    trim=-sstart
                    #First sample of x_speech for this segement (index 0)
                    sstart=sstart+trim 
                    #First sample of y_speech for this segement
                    start=start+trim 
                #Find delay compensated ending sample in x_speech
                sstop=min(stop-delay,len(x_speech)-1)
                #If there is at least 10 ms in both the x_speech segment and
                #the y_speech segment after these adjustments
                if (80 <= sstop-sstart+1) and (80 <= stop-start+1):
                    #Perform FFT-based cross correlation on appropriate
                    #portions of x_speech and y_speech
                    sstart = int(sstart)
                    start = int(start)
                    stop = int(stop)
                    sstop = int(sstop)
                    un_corr,denom=fft_xc(x_speech[sstart:sstop+1], y_speech[start:stop+1],-ran,ran)
                    #Locate peak in unnormalized correlation
                    peak =np.max(un_corr)
                    loc = np.argmax(un_corr)
                    #If correlation value meets or exceeds threshold, or the
                    #segment is longer than 1 second
                    if (cor_th <= peak/denom) or (8000 < stop-start+1):
                        #Apply the refinement
                        SDVout[i,1]=delay+(loc-ran) 
                #Segment is less than 200 ms long, use direct-form correlation
            else:
                #Find starting sample in x_speech, compensated for
                #delay and search range
                sstart=start-delay-ran
                #If it is before the start of x_speech, it will be necessary to
                #modify the starting place in both x_speech and y_speech
                if sstart<0:
                    #Number of samples involved in the modifications
                    trim=-sstart 
                    #First sample of x_speech for this segement
                    sstart=sstart+trim 
                    #First sample of y_speech for this segement
                    start=start+trim 
                #Find ending sample in x_speech, compensated for
                #delay and search range
                sstop=stop-delay+ran
                #If it is beyond the end of x_speech, it will be necessary to
                #modify the ending place in both x_speech and y_speech
                if len(x_speech)<sstop:
                    #Number of samples involved in the modifications
                    trim=sstop-len(x_speech) 
                    #Last sample of x_speech for this segement
                    sstop=sstop-trim 
                    #Last sample of y_speech for this segement
                    stop=stop-trim 
                #If there is at least 10 ms in the y_speech segment after
                #these adjustments
                if 80 < stop-start+1:
                    sstart = int(sstart)
                    start = int(start)
                    stop = int(stop)
                    sstop = int(sstop)
                    #Perform direct-form cross correlation on appropriate
                    #portions of x_speech and y_speech
                    un_corr,denom=non_fft_xc_all(x_speech[sstart:sstop+1],
                    y_speech[start:stop+1])
                    #Locate peak in unnormalized correlation
                    peak=max(un_corr)
                    loc=np.argmax(un_corr)
                    #If correlation value meets or exceeds threshold
                    if cor_th <= peak/denom:
                        #Apply the refinement
                        SDVout[i,1]=delay+(ran-loc)
    return SDVout


#==========================================================================
def non_fft_xc_all(x,y):
    #This function applies a direct-form cross correlation to the
    #vectors of speech samples x and y. This correlation is done for all
    #possible shifts that use all of y.
    #The unnormalized correlation values are returned in un_cor, and the
    #denominator is returned in denom.
    #It is required that length(x)>=length(y).
    #Find lengths
    nx=len(x)
    ny=len(y)
    #Find number of possible shifts
    nshifts=nx-ny+1 
    #Initialize results variable
    un_corr=np.zeros(nshifts) 
    #Loop over all possible shifts
    for i in range(0, nshifts):
        temp_x=x[i:i+ny] 
        #Form partial denominator of correlation so it can be tested
        #to prevent divide by zero
        denom=np.dot(temp_x, temp_x) 
        
        if denom>0:
            #Correlation
            un_corr[i]=np.dot(temp_x, y)/np.sqrt(denom) 
        else:
            #When segment of x has no signal, correlation is zero
            un_corr[i]=0 
    #Find fixed portion of denominator
    denom=np.sqrt(np.dot(y, y)) 
    return un_corr,denom
#==========================================================================
def short_seg_cor(SDVin,x_speech,y_speech,len_t,len_b,len_s):
    #Usage: SDVout=short_seg_cor(SDVin,x_speech,y_speech,len_t,len_b,len_s)
    #This function tests all pulses (also called blips), steps and tails in
    #an estimated delay history and removes them when appropriate
    #
    #x_speech and y_speech are are vectors that hold system under test
    # input and output speech samples (without any delay compensation)
    #len_t is the length in ms of the longest tail that should be removed
    #len_b is the length in ms of the longest blip that should be removed
    #len_s is the length in ms of the longest step that should be removed
    #SDVin and SDVout are Delay history matricies in the fs=8000 domain. There
    #is one row per segment of constant delay
    #Column 0, Sample number of last sample of constant delay segment
    #Column 1, estimated Delay of segment
    #Column 2, Validity of delay estimation for segment
    # (0 for invalid, 1 for valid)
    #Convert from ms to samples
    len_t=8*len_t
    len_b=8*len_b
    len_s=8*len_s
    #Find number of segments of constant delay
    nsegs=np.size(SDVin,0) 
    #Find length of each segment
    seglens=np.diff(np.append(0, SDVin[:,0])) 
    #Append two to SDVin. SDVin now has
    #Column 0, Sample number of last sample of constant delay segment
    #Column 1, estimated Delay of segment
    #Column 2, Validity of delay estimation segment (0=invalid, 1=valid)
    #Column 3, Number of samples in segment
    #Column 4, Status of segment (0=needs to be considered, 1=should be
    #ingnored) Start with all zeros.
    SDVin=np.column_stack((SDVin, seglens, np.zeros(nsegs)))
    #Find location and type of the shortest segment with status 0 in SDVin
    ptr,seg_type=find_smallest_seg(SDVin)

    #If there is such a segment
    if ptr!=0:
        #Extract its length
        current_seg_len=SDVin[ptr,3] 
    else:
        #Otherwise create a fictitious segment length that is long enough
        #to prevent entering the "while loop" that follows
        current_seg_len=max([len_t, len_b, len_s])+1 

    #While the shortest segment qualifies for consideration under at least
    #one of the three length thresholds
    while current_seg_len<=max([len_t, len_b, len_s]):
        #Find number of segments in current version of SDVin
        n=np.size(SDVin,0) 
        #If current segment is a left tail and conforms with tail threshold
        if seg_type=='LT' and current_seg_len <= len_t:
            #Join current segment to right neighbor segment
            #to create new combined segment
            SDVin=SDVin[np.setdiff1d(range(0,n),ptr),:]
            #(Setdiff is the set difference function. As called above, it
            #returns a length n-1 vector containing 1,2,...ptr-1, ptr+1, ...n)
            #Set status on the new combined segment to 0 so it receives
            #further consideration
            SDVin[ptr,4] =False
            #Store the length of the new combined segment
            SDVin[ptr,3]=SDVin[ptr,3]+current_seg_len 
            
        #If current segment is a right tail and conforms with tail threshold
        elif seg_type=='RT' and current_seg_len <= len_t:
            #Join current segment to left neighbor segment
            #to create new combined segment
            current_seg_end=SDVin[ptr,0] 
            SDVin=SDVin[np.setdiff1d(range(0,n),ptr),:] 
            SDVin[ptr-1,0]=current_seg_end 
            #Set status on the new combined segment to 0 so it receives
            #further consideration
            SDVin[ptr-1,4]=False
            #Store the length of the new combined segment
            SDVin[ptr-1,3]=SDVin[ptr-1,3]+current_seg_len 
            
        #If current segment is a blip and conforms with blip threshold
        elif seg_type=='BI' and current_seg_len <= len_b:
            #Join current segment and left neighbor to right neighbor segment
            #to create new combined segment
            left_neb_len=SDVin[ptr-1,3] 
            SDVin=SDVin[np.setdiff1d(range(0,n),[ptr-1, ptr]),:] 
            #Set status on the new combined segment to 0 so it receives
            #further consideration
            SDVin[ptr-1,4]=False
            #Store the length of the new combined segment
            SDVin[ptr-1,3]=SDVin[ptr-1,3]+current_seg_len+left_neb_len 
            
        #If current segment is a step and conforms with step threshold
        elif seg_type=='SP' and current_seg_len <= len_s:
            #Join current segment to left or right neighbor or leave it
            #as is. Choice of these 3 actions depends on correlation results
            #-----------------------Preparations-------------------------------
            start=SDVin[ptr-1,0]+1  #First sample of current segment
            stop=SDVin[ptr,0]   #Last sample of current segment
            L_dly=SDVin[ptr-1,1]   #Delay of segment left of current segment
            C_dly=SDVin[ptr,1] #Delay of current segment
            R_dly=SDVin[ptr+1,1]   #Delay of segment right of current segment
            #Correlation at delay of left neighbor
            lcorr=single_corr(x_speech,y_speech,start,stop,L_dly) 
            #Correlation at delay of right neighbor
            rcorr=single_corr(x_speech,y_speech,start,stop,R_dly) 
            #Correlation at delay of current segment
            ccorr=single_corr(x_speech,y_speech,start,stop,C_dly) 
            #Which of these 3 correlations is largest?
            loc =np.argmax([lcorr, rcorr, ccorr]) 
            
            #If correlation at delay of left neighbor is largest
            if loc==0:
                #Join current segment to left neighbor segment
                #to create new combined segment
                current_seg_end=SDVin[ptr,0] 
                SDVin=SDVin[np.setdiff1d(range(0,n),ptr),:]
                SDVin[ptr-1,0]=current_seg_end 
                #Set status on the new combined segment to 0 so it receives
                #further consideration
                SDVin[ptr-1,4]=False
                #Store the length of the new combined segment
                SDVin[ptr-1,3]=SDVin[ptr-1,3]+current_seg_len 
            #If correlation at delay of right neighbor is largest
            elif loc==1:
                #Join current segment to right neighbor segment
                #to create new combined segment
                SDVin=SDVin[np.setdiff1d[0:n,ptr],:]
                #Set status on the new combined segment to 0 so it receives
                #further consideration
                SDVin[ptr,4]=False
                #Store the length of the new combined segment
                SDVin[ptr,3]=SDVin[ptr,3]+current_seg_len 
            else:
                #Don't change the step, but change its status to 1 for no
                #further consideration
                SDVin[ptr,4]=True 
        #For all other segment types, this function makes no changes.
        else:
            #Change status to 1 for no further consideration
            SDVin[ptr,4]=True 
        #Find location and type of the shortest segment with status 0 in SDVin
        ptr, seg_type=find_smallest_seg(SDVin) 
        #If there is such a segment
        if ptr!=0:
            #Extract its length
            current_seg_len=SDVin[ptr,3]
        else:
            #Otherwise create a fictitious segment length that is long enough
            #to terminate the "while loop"
            current_seg_len=max([len_t, len_b, len_s])+1 
        #End of while loop
    #SDVout contains just the first 3 columns of SDVin
    SDVout=SDVin[:,0:3] 
    #Identify the segments that reflect a change in delay or validity
    keepers=np.append(np.nonzero(np.logical_or(np.diff(SDVout[:,1])!=0, np.diff(SDVout[:,2])!=0)), np.size(SDVout,0)-1)
    #Retain only those segments
    SDVout=SDVout[keepers,:]
    return SDVout
#==========================================================================
def find_smallest_seg(SDVLS):
    #This function finds the smallest segment that has status 0 and reports
    #the segment type. SDVLS is a matrix with one row per segment of constant
    #delay. The 5 columns are:
    #Column 0, Sample number of last sample of constant delay segment
    #Column 1, estimated Delay of segment
    #Column 2, Validity of delay estimation segment (0=invalid, 1=valid)
    #Column 3, Length of segment in samples
    #Column 4, Status of segment (0=needs to be considered, 1=should be
    # ignored)
    #
    #ptr points to the row in SDVLS that has the smallest segment with
    #status 0. If all segments have status 0 , then ptr=0. If there is a tie
    #for shortest segment, the first segment to occur is reported
    #
    #seg_type indicates the type of segment ptr points to:
    #'IV' segment with invalid delay estimate
    #'IS' isolated, valid but neighbors on each side are invalid
    #'LT' lefthand tail, the segment to the left of an LT segment is either
    # invalid or does not exist, but segment to right is valid
    #'RT' righthand tail, the segment to the right of an RT segment is either
    # invalid or does not exist, but segment to left is valid
    #'BI' blip, segment and both neighbors are valid. Both neighbors share a
    # common delay value which is different from the delay value of the BI
    # segment
    #'SP' step, segment and both neighbors are valid and all 3 have different
    # delay values
    #'xx' is returned when ptr=0, i.e. there is no result to report.

    #Find number of segments
    nsegs=np.size(SDVLS,0)
    #Create list of all segments with status=0
    goodlist=np.where(SDVLS[:,4] == 0)[0]
    #If no such segment, function is done
    if goodlist.size == 0:
        ptr=0
        seg_type='xx'
        #There is one or more segments with status=0
    else:
        #Find the shortest such segment
        loc=np.argmin(SDVLS[goodlist,3])
        #Set ptr accordingly
        ptr=goodlist[loc]
        #If segment is invalid, mark it as such and function is finished
        if SDVLS[ptr,3]==0:
            seg_type='IV' 
        
        #Special case for first segment
        elif ptr==0:
            #If segment to right is valid
            if SDVLS[ptr+1,2]==True:
                #First segment is a left tail
                seg_type='LT' 
            else:
                #Otherwise first segment is isolated
                seg_type='IS' 
            
        #Special case for last segment
        elif ptr+1==nsegs:
            #If segment to left is valid
            if SDVLS[ptr-1,2]==True:
                #Last segment is a right tail
                seg_type='RT' 
            else:
                #Otherwise last segment is isolated
                seg_type='IS' 
            
        #All remaining segments have two neighbors
        else:
            #Check validity of segment to left of current segment
            lv=SDVLS[ptr-1,2]
            #Check validity of segment to right of current segment
            rv=SDVLS[ptr+1,2]
            #Use these two validities to identify appropriate segment type
            if lv== True and rv==False:
                seg_type='RT' 
            elif lv==False and rv==True:
                seg_type='LT' 
            elif lv==False and rv==False:
                seg_type='IS' 
            #Both neighbors are valid, so current segment is either a blip
            #or a step
            else:
                #If neighbors have the same delay, current segment is a blip
                if SDVLS[ptr-1,1]==SDVLS[ptr+1,1]:
                    seg_type='BI' 
                
                #Otherwise current segment is a step
                else:
                    seg_type='SP' 
    return ptr,seg_type


#==========================================================================
def single_corr(x_speech,y_speech,start,stop,delay):
    #Usage: rho=single_corr(x_speech,y_speech,start,stop,delay)
    #This function calculates a single correlation value between
    #a segment of x_speech and y_speech. The goal is to use the
    #samples of y_speech from "start" to "stop" inclusive and the
    #corresponding portion of x_speech, but shifted forward in time
    #by the number of samples specified in "delay."
    #These segments may be shortened as necessary if not enough
    #samples are available.
    #The correlation is direct-form and is performed by the
    #function non_fft_xc_all
    #First sample of x_speech that will be used
    sstart=int(start-delay)
    lefttrim=0  
    #If that sample does not exist
    if sstart<0:
        #It is necessary to shift the start of the correlation window
        lefttrim=-sstart  
        sstart=0 
    #Last sample of x_speech that will be used
    sstop=int(stop-delay)  
    ns=len(x_speech)  
    righttrim=0  
    #If that sample does not exist
    if sstop>ns:
        #It is necessary to shift the end of the correlation window
        righttrim=sstop-ns  
        sstop=ns  
    #Extract speech from correlation window and rectify
    x=abs(x_speech[sstart:sstop])  
    y=abs(y_speech[int(start+lefttrim):int(stop-righttrim)])  
    #Perform unnormalized correlation
    rho,denom=non_fft_xc_all(x,y)  
    #Normalize to find correlation value
    rho=rho/denom  
    return rho

#==========================================================================
def extend_val_res(SDVin):
    #Usage: SDVout=extend_val_res(SDVin)
    #This function extrapolates valid results to cover areas where there are
    #none. SDVin and SDVout are Delay history matrices in the fs=8000 domain:
    #Column 0, Sample number of last sample of constant delay segment
    #Column 1, estimated Delay of segment
    #Column 2, Validity of delay estimation segment
    # (False for invalid, True for valid)
    #
    #For interior invalid regions, the function splits the region in half and
    #extrapolates each neighboring valid region to cover half of the invalid
    #region. For exterior invalid regions, the function extrapolates the
    #single neighboring valid region
    #Find number of segments
    nsegs=np.shape(SDVin)[0]
    #Copy input data to output data
    SDVout=SDVin
    #If there is more than one segment, then loop over all segments
    if 1< nsegs:
        for i in range(0, nsegs):
            #If the current segment is not valid
            if not SDVout[i,2]:
                #Leading invalid segment case
                if i==0:
                    SDVout[0,1]=SDVout[1,1]
                    #Trailing invalid segment case
                elif i==nsegs-1:
                    SDVout[-1,1]=SDVout[-2,1]
                    #Interior invalid segment case
                else:
                    #Half the width of the invalid segment
                    hw=round((SDVout[i,0]-SDVout[i-1,0])/2)
                    #Extend previous segment to cover first
                    SDVout[i-1,0]=SDVout[i-1,0]+hw
                    #Copy delay of following segment to cover second half
                    SDVout[i,1]=SDVout[i+1,1]
        #Find segments associated with changes in delay
        keepers=np.append(np.nonzero(np.diff(SDVout[:,1]))[0], nsegs-1)
        #Retain only those segments
        SDVout=np.column_stack((SDVout[keepers, 0], SDVout[keepers, 1]))
    else:
        SDVout=SDVout[0,[0, 1]]
    return SDVout
 #==========================================================================
def LSE(s,d,Df,Dv,maxsp):
    #Usage: lse_f,lse_v=LSE(s,d,Df,Dv,maxsp)
    #This function calculates log-spectra error for fixed and variable delay
    #estimates.
    #
    #s is a column vector of source speech samples (system under test input)
    #d is a column vector of distorted speech samples (system under test
    #output) s and d should have no delay compensation applied
    #Df is a fixed scalar delay value
    #Dv is a delay history matrix where each row corresponds to a segment of
    #constant delay and
    #Column 1 holds number of last sample in segment
    #Column 2 holds delay value for segment
    #Column 3 holds 1 to indicate valid delay estimate for the segment,
    # and holds 0 otherwise
    #max sp tells the max spacing between LSE computation locations in ms
    #lse_f and lse_v are the fixed and variable LSE results in dB
    #
    #If the lengths of s and d are such that delay compensation by either
    #Df or Dv leaves insufficent signal for LSE calculations, then this
    #function returns lse_f=lse_v=0.
    #Length of LSE window in samples
    lsewin=128 
    #Convert from ms to samples
    maxsp=my_round(maxsp*8) 
    #Find list of segment numbers that are valid
    goodlist=np.nonzero(Dv[:,2])[0]
    #Find number of valid segments in Dv
    nsegs=len(goodlist) 
    #Will hold center locations of LSE windows in d
    dlocs=[] 
    #Will hold analogous center locations of LSE windows in s, according to
    #the variable delay estimate
    slocs_var=[] 
    #Loop over all segments
    for i in range(0, nsegs):
        #If it is the first segment in Dv
        if goodlist[i]==0:
            #Starting sample number must be 1
            start=0
        else:
            #Otherwise it is 1 more than last sample of previous segment
            start=Dv[goodlist[i]-1,0]+1 
        #Find last sample of segment
        stop=Dv[goodlist[i],0]
        #Find delay of the segment
        segdel=Dv[goodlist[i],1] 
        #Find center of segment
        center=my_round((stop+start)/2)
        #Total number of LSE windows that will fit on this segment is 2*hn+1
        hn=np.floor((stop-center-320-lsewin/2)/maxsp) 
        #Calculate the window location(s)
        if hn>=1:
            locs=center+(np.arange(-hn,hn+1) * maxsp)
        else:
            locs=center 
        #Append locations to the list of LSE window center locations in d
        dlocs=np.append(dlocs, locs)
        #Append locations to the list of LSE window center locations in s,
        #compensate for segment delay
        slocs_var=np.append(slocs_var, locs-segdel)
    #Create list of corresponding centers of LSE windows in s,
    #according to the fixed delay estimate
    slocs_fxd=dlocs-Df
    #Find 4 constants
    L=int(my_round(lsewin/2))
    R=lsewin-L
    len_d=len(d) 
    len_s=len(s) 
    #Find locations of window centers that will result in windows that do
    #not extend beyond the ends of s or d
    goodlocs=np.nonzero(np.logical_and.reduce((0<=(dlocs-L), \
    (dlocs+R)<len_d, 0<=(slocs_var-L), (slocs_var+R)<len_s, \
    0<=(slocs_fxd-L),  (slocs_fxd+R)<len_s)))[0]
    #Retain only such locations
    dlocs=dlocs[goodlocs] 
    slocs_var=slocs_var[goodlocs] 
    slocs_fxd=slocs_fxd[goodlocs] 
    nlocs=len(dlocs) 
    #If there are locations for LSE calculations
    if 0<nlocs:
        #Build matrices of speech samples from the desired locations
        #Each column contains speech samples for a given LSE window
        D=np.zeros((lsewin,nlocs)) 
        Sv=np.zeros((lsewin,nlocs))
        Sf=np.zeros((lsewin,nlocs))
        for i in range(0, nlocs):
            D[:,i]=d[np.int_(np.arange(dlocs[i]-L,dlocs[i]+R))]
            Sf[:,i]=s[np.int_(my_round(np.arange(slocs_fxd[i]-L,slocs_fxd[i]+R)))] 
            Sv[:,i]=s[np.int_(np.arange(slocs_var[i]-L,slocs_var[i]+R))] 
        #Generate column vector with periodic Hanning window, length is lsewin
        win=.5*(1-np.cos(2*np.pi*np.arange(0,lsewin)/lsewin))
        win = win.reshape(len(win), 1)
        #Repeat this window in each column of the matrix Win.
        #(Win is lsewin by nlocs.)
        #Multiply by window and peform FFT on each column of each speech matrix
        D=fft(D*win, axis=0)
        Sf=fft(Sf*win, axis=0) 
        Sv=fft(Sv*win, axis=0)
        #Extract magnitude of unique half of FFT result
        D=np.abs(D[range(int(np.floor(lsewin/2))+1),:]) 
        Sf=np.abs(Sf[range(int(np.floor(lsewin/2))+1),:]) 
        Sv=np.abs(Sv[range(int(np.floor(lsewin/2))+1),:])
        #Limit results below at 1 to prevent log(0). This is below the 10 dB
        #clamping threshold used below, so these clamped samples will not be
        #used
        D=np.maximum(D,1) 
        Sf=np.maximum(Sf,1) 
        Sv=np.maximum(Sv,1)
        #Take log and clamp results below at 10 dB. Speech peaks will
        #typically be around 100 dB, so this limits dynamic range to about 90
        #dB and prevents low level segments from inappropriately dominating the
        #LSE results
        D=np.maximum(10,20*np.log10(D)) 
        Sf=np.maximum(10,20*np.log10(Sf)) 
        Sv=np.maximum(10,20*np.log10(Sv)) 
        #Calculated LSE: inner mean is across frequency, outer mean is across
        #LSE windows (i.e. across time)
        lse_f=np.mean(np.mean(abs(D-Sf))) 
        lse_v=np.mean(np.mean(abs(D-Sv)))
    #LSE calculations are not possible
    else:
        lse_f=0 
        lse_v=0 
    return lse_f, lse_v

# used in LSE
def my_round(x):
    def round_val(val):
        if val%1>=0.5:
            return np.ceil(val)
        else:
            return np.floor(val)
    if isinstance(x, np.ndarray):
       for i in range(len(x)):
           x[i] = round_val(x[i])
    else:
        x = round_val(x)
    return x
