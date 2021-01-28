import numpy as np
import scipy.signal as sig
from ITS_delay_est import ITS_delay_est

def sliding_delay_estimates(test,ref,fs,winLength=4,winStep=2):
    # SLIDING_DELAY_ESTIMATES perform sequence of windowed time delay estimates
    #
    #   SLIDING_DELAY_ESTIMATES(test,ref,fs) performs delay estimates between
    #       ref (input to the system under test) and test (output from system
    #       under test)
    #
    #   SLIDING_DELAY_ESTIMATES(test,ref,fs,winLength) specifies the window
    #       length in seconds, winLength, instead of using the default of 4
    #       seconds. The window length is the length of time to use for the
    #       delay estimates
    #
    #   SLIDING_DELAY_ESTIMATES(test,ref,fs,winLength,winStep) specifies the
    #       window step in seconds, winStep, instead of using the default of 2
    #       seconds. The window step is the amount of time the window moves
    #       forward for each subsequent time delay estimate.
    #
    #   Delays=SLIDING_DELAY_ESTIMATES(__) returns the delays as a vector
    #   instead of plotting them. Delays holds one delay estimate in ms for
    #   each time window. The resolution of these estimates is 1/8kHz. The
    #   accuracy of these estimates depends of the level of background noise
    #   and speech distortion in the input waveform
    #
    # Notes:  requires access to ITS_delay_est.m, written at ITS
    #   requires access to resample function included in Matlab Signal Processing Toolbox
    #
    # Written by Stephen Voran at the Institute for Telecommunication Sciences,
    # 325 Broadway, Boulder, Colorado, USA, svoran@its.bldrdoc.gov
    # March 30, 2016
    # Modification By Jesse Frey June, 2017

    #--------------------------Legal--------------------------
    #THE NATIONAL TELECOMMUNICATIONS AND INFORMATION ADMINISTRATION,
    #INSTITUTE FOR TELECOMMUNICATION SCIENCES ("NTIA/ITS") DOES NOT MAKE
    #ANY WARRANTY OF ANY KIND, EXPRESS, IMPLIED OR STATUTORY, INCLUDING,
    #WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR
    #A PARTICULAR PURPOSE, NON-INFRINGEMENT AND DATA ACCURACY.  THIS SOFTWARE
    #IS PROVIDED "AS IS."  NTIA/ITS does not warrant or make any
    #representations regarding the use of the software or the results thereof,
    #including but not limited to the correctness, accuracy, reliability or
    #usefulness of the software or the results.
    #
    #You can use, copy, modify, and redistribute the NTIA/ITS developed
    #software upon your acceptance of these terms and conditions and upon
    #your express agreement to provide appropriate acknowledgments of
    #NTIA's ownership of and development of the software by keeping this
    #exact text present in any copied or derivative works.
    #
    #The user of this Software ("Collaborator") agrees to hold the U.S.
    #Government harmless and indemnifies the U.S. Government for all
    #liabilities, demands, damages, expenses, and losses arising out of
    #the use by the Collaborator, or any party acting on its behalf, of
    #NTIA/ITS' Software, or out of any use, sale, or other disposition by
    #the Collaborator, or others acting on its behalf, of products made
    #by the use of NTIA/ITS' Software.

    #add test signal parameter
    test = np.array(test, dtype=np.float64)
    if np.any(np.isinf(test)):
        raise ValueError("Error with input test")
    #add reference signal parameter
    ref = np.array(ref, dtype=np.float64)
    if np.any(np.isinf(ref)):
        raise ValueError("Error with input ref")
    #add sample rate parameter
    if np.isinf(fs):
        raise ValueError("Error with input fs")
    #add window length argument
    if winLength <= 0:
        raise ValueError("Error with input winLength") 
    #add window separation argument
    if winLength <= 0:
        raise ValueError("Error with input winStep")

    #sample rate to resample to
    #this is the rate that ITS_delay_est expects inputs to be in
    fs_re=8e3 

    #calculate resample factor
    n_re=fs/fs_re 

    #check that resample rate is an integer
    if(round(n_re)!=n_re):
        #give error for invalid sample rate
        raise ValueError('fs must be an integer multiple of %i' %fs_re) 


    #number of samples available in both files
    N=min(len(test),len(ref)) 
    #number of samples needed for each window
    Nwin=round(winLength*fs) 
    #number of sampels to advance between windows
    Nstep=round(winStep*fs) 

    firstSmp=0
    lastSmp=firstSmp+Nwin-1 

    Delays=[]  #Will hold delay estimates
    Times=[]   #Will hold time of center of window

    #-----Loop to perform all possible time delay estimates-----
    while lastSmp<N:
        #get a section of the SUT input signal
        tempRef=ref[firstSmp:lastSmp+1]
        #get a section of the SUT output signal
        tempTest=test[firstSmp:lastSmp+1]
        #-----Apply our delay estimation tool to extracted portions of signal-----    
        temp=ITS_delay_est(sig.resample_poly(tempRef,1,n_re),sig.resample_poly(tempTest,1,n_re),'f')
        
        #-----Store results-----
        Delays=np.append(Delays, temp[1])
        Times=np.append(Times, 1+ (firstSmp+lastSmp)/2)
        
        #-----Move window location ahead-----
        firstSmp=firstSmp+Nstep
        lastSmp=lastSmp+Nstep
    
    #convert from samples to ms
    Delays=Delays/8 
    #convert from samples to seconds
    Times=Times/fs  

    #check if output arguments were given

    return Delays, Times
