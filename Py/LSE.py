import numpy as np
from scipy.io.wavfile import read
from numpy.fft import fft
from numpy.matlib import repmat

def LSE(s,d,Df,Dv,maxsp):
    #Usage: [lse_f,lse_v]=LSE(s,d,Df,Dv,maxsp)
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