#!/usr/bin/env python

import argparse
import csv
import datetime
import math
import mcvqoe.hardware
import mcvqoe.gui
import os
import scipy.io.wavfile
import scipy.signal
import signal
import sys
import time
import traceback

from fractions import Fraction
from mcvqoe.misc import audio_float
from mcvqoe.sliding_delay import sliding_delay_estimates
from tkinter import scrolledtext

import matplotlib.pyplot as plt
import numpy as np   
     
def terminal_progress_update(prog_type,num_trials,current_trial,err_msg=""):
    if(prog_type=='proc'):
        if(current_trial==0):
            #we are post processing
            print('Processing test data')        
        
        print(f'Processing trial {current_trial+1} of {num_trials}')
    elif(prog_type=='test'):
        if(current_trial==0):
            print(f'Starting Test of {num_trials} trials')
        if(current_trial % 10 == 0):
            print(f'-----Trial {current_trial} of {num_trials}')
    elif(prog_type=='check-fail'):
        print(f'On trial {current_trial+1} of {num_trials} : {err_msg}')
        
    #continue test
    return True
        

class M2E:

    self.no_log = ('test', 'ri')

    def __init__(self):
        
        self.audio_file = "test.wav"
        self.audio_interface = None
        self.bgnoise_file = ""
        self.bgnoise_volume = 0.1
        self.info = {}
        self.outdir = ""
        self.ptt_wait = 0.68
        self.ptt_gap=3.1
        self.ri = None
        self.test = "m2e_1loc"
        self.trials = 100
        self.get_post_notes=None
        self.progress_update=terminal_progress_update
    
    def run(self):
        if(self.test == "m2e_1loc"):
            return self.m2e_1loc()
        elif(self.test == "m2e_2loc_tx"):
            return self.m2e_2loc_tx()
        elif(self.test == "m2e_2loc_rx"):
            return self.m2e_2loc_rx()
        else:
            raise ValueError(f'Unknown test type "{self.test}"')
    
    def param_check(self):
        """Check all input parameters for value errors"""
        
        if ((self.test!="m2e_1loc") and (self.test!="m2e_2loc_tx")
            and (self.test!="m2e_2loc_rx")):
            raise ValueError(f"\n{self.test} is an incorrect test")
        
        if (self.trials < 1):
            raise ValueError(f"\nTrials parameter needs to be more than 0")
        
        if not (os.path.isfile(self.audio_file)):
            raise ValueError(f"\nAudio file chosen does not exist")
        
        if (self.ptt_wait < 0):
            raise ValueError(f"\nptt_wait parameter must be >= 0")
        
    def m2e_1loc(self):
        """Run a m2e_1loc test"""
        #------------------[Check for correct audio channels]------------------
        if('tx_voice' not in self.audio_interface.playback_chans.keys()):
            raise ValueError('self.audio_interface must be set up to play tx_voice')
        if('rx_voice' not in self.audio_interface.rec_chans.keys()):
            raise ValueError('self.audio_interface must be set up to record rx_voice')
        #-------------------------[Get Test Start Time]-------------------------
        
        self.info['Tstart']=datetime.datetime.now()
        dtn=self.info['Tstart'].strftime('%d-%b-%Y_%H-%M-%S')
        
        #--------------------------[Fill log entries]--------------------------
        #set test name
        self.info['test']='m2e_1loc'
        #fill in standard stuff
        self.info.update(mcvqoe.write_log.fill_log(self))
        
        #-----------------------[Setup Files and folders]-----------------------
        
        #generate data dir names
        data_dir=os.path.join(self.outdir,'data')
        wav_data_dir=os.path.join(data_dir,'wav')
        csv_data_dir=os.path.join(data_dir,'csv')
        
        #create data directories 
        os.makedirs(csv_data_dir, exist_ok=True)
        os.makedirs(wav_data_dir, exist_ok=True)
        
        #generate base file name to use for all files
        base_filename='capture_%s_%s'%(self.info['Test Type'],dtn);
        
        #generate test dir names
        wavdir=os.path.join(wav_data_dir,base_filename) 
        
        #create test dir
        os.makedirs(wavdir, exist_ok=True)
        
        #generate csv name
        self.data_filename=os.path.join(csv_data_dir,f'{base_filename}.csv')
        
        #generate temp csv name
        temp_data_filename = os.path.join(csv_data_dir,f'{base_filename}_TEMP.csv')
            
        #-------------------------[Load Audio File(s)]-------------------------
        
        # Ready audio_file for play/record
        fs_file, audio_dat = scipy.io.wavfile.read(self.audio_file)
        rs_factor = Fraction(self.audio_interface.sample_rate/fs_file)
        audio_dat = audio_float(audio_dat)
        audio = scipy.signal.resample_poly(audio_dat, rs_factor.numerator, rs_factor.denominator)
        
        # Save testing audio_file to audio capture directory for future use/testing
        tx_audio = os.path.join(wavdir, '1loc_audio.wav')
        scipy.io.wavfile.write(tx_audio, self.audio_interface.sample_rate, audio)
        
        # Get bgnoise_file and resample
        if (self.bgnoise_file):
            nfs, nf = scipy.io.wavfile.read(self.bgnoise_file)
            rs = Fraction(self.audio_interface.sample_rate/nfs)
            nf = audio_float(nf)
            nf = scipy.signal.resample_poly(nf, rs.numerator, rs.denominator)

            if (nf.size != audio.size):
                nf = np.resize(nf, audio.size)
            audio = audio + nf*self.bgnoise_volume

        #------------------------[Compute check trials]------------------------
        if (self.trials > 10):
            check_trials = np.arange(0, (self.trials+1), 10)
            check_trials[0] = 1
        else:
            check_trials = np.array([1, self.trials])  
        
        #---------------[Try block so we write notes at the end]---------------
        
        try:
                
            #-------------------------[Turn on RI LED]-------------------------
            self.ri.led(1, True)
                       
            #------------------------[Initialize arrays]------------------------
            
            dly_its = []
            
            #------------------------[Measurement Loop]------------------------
            for itr in range(self.trials):
                #-----------------------[Update progress]-------------------------
                if( not self.progress_update('test',self.trials,itr)):
                    #turn off LED
                    self.ri.led(1, False)
                    print('Exit from user')
                    break
                #-----------------------[Get Trial Timestamp]-----------------------
                ts=datetime.datetime.now().strftime('%d-%b-%Y %H:%M:%S')
                
                #--------------------[Key Radio and play audio]--------------------
                
                # Press the push to talk button
                self.ri.ptt(True)
                
                # Pause the indicated amount to allow the radio to access the system
                time.sleep(self.ptt_wait)
                
                # Create audiofile name/path for recording
                audioname = 'Rx'+str(itr+1)+'.wav'
                audioname = os.path.join(wavdir, audioname)
                
                # Play/Record
                rec_chans = self.audio_interface.play_record(audio, audioname)
                
                # Release the push to talk button
                self.ri.ptt(False)
                
                #-----------------------[Pause Between runs]-----------------------
                
                time.sleep(self.ptt_gap)
                
                #-----------------------------[Data Processing]----------------------------
                
                # Check if we run statistics on this trial
                if np.any(check_trials == itr):
                    
                    # Get latest run Rx audio
                    proc_audio_sr, proc_audio = scipy.io.wavfile.read(audioname)
                    proc_audio = audio_float(proc_audio)
                    
                    # Calculate RMS of received audio
                    rms = round(math.sqrt(np.mean(proc_audio**2)), 4)
                    
                    #check if levels are low
                    if(rms<1e-3):
                        continue_test=self.progress_update('test',self.trials,itr,
                                err_msg=f'Low input levels detected. RMS = {rms}')
                        if(not continue_test):
                            #turn off LED
                            self.ri.led(1, False)
                            print('Exit from user')
                            break
                #-----------------------------[Data Processing]----------------------------
                    
                # Get latest run Rx audio
                proc_audio_sr, proc_audio = scipy.io.wavfile.read(audioname)
                proc_audio = audio_float(proc_audio)

                # Estimate the mouth to ear latency
                new_delay = sliding_delay_estimates(proc_audio, audio, self.audio_interface.sample_rate)[0]
                
                newest_delay = np.multiply(new_delay, 1e-3)
                
                dly_its.append(newest_delay)
                
        finally:
            if(self.get_post_notes):
                #get notes
                info=self.get_post_notes()
            else:
                info={}
            #finish log entry
            mcvqoe.post(outdir=self.outdir,info=info)
        
        #----------------------------[Generate Plots]------------------------------
        
        # Get mean of each row in dly_its
        its_dly_mean = np.mean(dly_its, axis=1)
        
        # Overall mean delay
        ovrl_dly = np.mean(its_dly_mean)
        
        # Get standard deviation
        std_delay = np.std(dly_its, dtype=np.float64)
        std_delay = std_delay*(1e6)
        
        # Print StD to terminal
        print("StD: %.2fus\n" % std_delay, flush=True)
        
        # Create trial scatter plot
        plt.figure() 
        x2 = range(1, len(its_dly_mean)+1)
        plt.plot(x2, its_dly_mean, 'o', color='blue')
        plt.xlabel("Trial Number")
        plt.ylabel("Delay(s)")
        
        # Create histogram for mean
        plt.figure()
        uniq = np.unique(its_dly_mean)
        dlymin = np.amin(its_dly_mean)
        dlymax = np.amax(its_dly_mean)
        plt.hist(its_dly_mean, bins=len(uniq), range=(dlymin, dlymax), rwidth=0.5)
        plt.title("Mean: %.5fs" % ovrl_dly)
        plt.xlabel("Delay(s)")
        plt.ylabel("Frequency of indicated delay")
        plt.show()
        
        with open(self.data_filename, 'w', newline='') as csv_file:
            writer = csv.writer(csv_file)
            writer.writerow(["Mean Delay Per Trial (seconds)"])
            for i in range(len(its_dly_mean)):
                writer.writerow([its_dly_mean[i]])
                  
    def m2e_2loc_tx(self):
        """Run a m2e_2loc_tx test"""
        
        
        #------------------[Check for correct audio channels]------------------
        if('tx_voice' not in self.audio_interface.playback_chans.keys()):
            raise ValueError('self.audio_interface must be set up to play tx_voice')
        if('timecode' not in self.audio_interface.rec_chans.keys()):
            raise ValueError('self.audio_interface must be set up to record timecode')
        #-------------------------[Get Test Start Time]-------------------------
        
        self.info['Tstart']=datetime.datetime.now()
        dtn=self.info['Tstart'].strftime('%d-%b-%Y_%H-%M-%S')
        
        #-----------------------[Setup Files and folders]-----------------------
        
        #generate data dir names
        data_dir=os.path.join(self.outdir,'data')
        tx_dat_fold = os.path.join(data_dir,'2loc_tx-data')

        #generate base file name to use for all files
        base_filename='capture_%s_%s'%(self.info['Test Type'],dtn);
        
        capture_dir = os.path.join(tx_dat_fold, 'Tx_'+base_filename)
        
        #create directories
        os.makedirs(capture_dir, exist_ok=True)        
        
        #generate csv name
        self.data_filename=os.path.join(csv_data_dir,f'{base_filename}.csv')
        
        #generate temp csv name
        temp_data_filename = os.path.join(csv_data_dir,f'{base_filename}_TEMP.csv')
        
        #---------------------------[Load audio file]---------------------------
        fs_file, audio_dat = scipy.io.wavfile.read(self.audio_file)
        rs_factor = Fraction(self.audio_interface.sample_rate/fs_file)
        audio_dat = audio_float(audio_dat)
        audio = scipy.signal.resample_poly(audio_dat, rs_factor.numerator, rs_factor.denominator)
        
        # Save testing audiofile to audio capture directory for future use/testing
        tx_audio = os.path.join(capture_dir, 'Tx_audio.wav')
        scipy.io.wavfile.write(tx_audio, self.audio_interface.sample_rate, audio)

        #-----------------------[Setup Background noise]-----------------------
        # Get bgnoise_file and resample
        if (self.bgnoise_file):
            nfs, nf = scipy.io.wavfile.read(self.bgnoise_file)
            rs = Fraction(fs/nfs)
            nf = audio_float(nf)
            nf = scipy.signal.resample_poly(nf, rs.numerator, rs.denominator)

            if (nf.size != audio.size):
                nf = np.resize(nf, audio.size)
            audio = audio + nf*self.bgnoise_volume

        
        #---------------[Try block so we write notes at the end]---------------
        try:
            
            #-------------------------[Turn on RI LED]-------------------------
            
            self.ri.led(1, True)
            
            #------------------------[Measurement Loop]------------------------
            
            for itr in range(self.trials):
                
                #-----------------------[Update progress]-------------------------
                if(not self.progress_update('test',self.trials,trial)):
                    #turn off LED
                    self.ri.led(1, False)
                    print('Exit from user')
                    break
                
                #--------------------[Key Radio and play audio]--------------------
                
                # Press the push to talk button
                self.ri.ptt(True)
                
                # Pause the indicated amount to allow the radio to access the system
                time.sleep(self.ptt_wait)
                
                # Create audiofile name/path for recording
                audioname = 'Tc'+str(itr+1)+'.wav'
                audioname = os.path.join(capture_dir, audioname)
                
                # Play/Record
                rec_chans = self.audio_interface.play_record(audio, audioname)
                
                # Release the push to talk button
                self.ri.ptt(False)
                
                #-----------------------[Pause Between runs]-----------------------
                
                time.sleep(self.ptt_gap)
                
                    
        finally:
            if(self.get_post_notes):
                #get notes
                info=self.get_post_notes()
            else:
                info={}
            #finish log entry
            mcvqoe.post(outdir=self.outdir,info=info)

        #-----------------------[Notify User of Completion]------------------------ 

        print('\n***Data collection complete, you may now stop data collection on the'+
              ' receiving end***\n', flush=True)
        
    def m2e_2loc_rx(self):
        
        
        #------------------[Check for correct audio channels]------------------
        if('rx_voice' not in self.audio_interface.rec_chans.keys()):
            raise ValueError('self.audio_interface must be set up to record rx_voice')
        if('timecode' not in self.audio_interface.rec_chans.keys()):
            raise ValueError('self.audio_interface must be set up to record timecode')
        
        #-------------------------[Get Test Start Time]-------------------------
        self.info['Tstart']=datetime.datetime.now()
        dtn=self.info['Tstart'].strftime('%d-%b-%Y_%H-%M-%S')
        
        #--------------------------[Fill log entries]--------------------------
        
        self.info['test']='PSuD'
        #fill in standard stuff
        self.info.update(mcvqoe.write_log.fill_log(self))
        
        #-----------------------[Setup Files and folders]-----------------------
        
        # Create rx-data folder
        rx_dat_fold = os.path.join(self.outdir, '2loc_rx-data')
        os.makedirs(rx_dat_fold, exist_ok=True)
        
        base_filename='capture_%s_%s'%(self.info['Test Type'],dtn);
        
        filename = os.path.join(rx_dat_fold, 'Rx_'+base_filename+'.wav')
        
        #---------------------------[write log entry]---------------------------
        
        mcvqoe.write_log.pre(info=self.info, outdir=self.outdir)
        
        #---------------[Try block so we write notes at the end]---------------
        try:
            #--------------------------[Record audio]--------------------------
            self.audio_interface.record(filename)
        
        finally:
            if(self.get_post_notes):
                #get notes
                info=self.get_post_notes()
            else:
                info={}
            #finish log entry
            mcvqoe.post(outdir=self.outdir,info=info)

def main():
    
    # Create M2E object
    test_obj = M2E()
    #set end notes function
    test_obj.get_post_notes=mcvqoe.gui.post_test

    #-------------------------[Create audio interface]-------------------------
    
    test_obj.audio_interface=mcvqoe.hardware.AudioPlayer()
    
    #--------------------[Parse the command line arguments]--------------------
    
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-y', '--testtype', dest="test", default=test_obj.test, metavar="TEST",
                        help="M2E test to perform. Options are: 'm2e_1loc', 'm2e_2loc_tx', and "+
                        "'m2e_2loc_rx'. Defaults to 1 location ('m2e_1loc')")
    parser.add_argument('-a', '--audiofile', dest="audio_file", default=test_obj.audio_file,
                        metavar="FILENAME", help="Choose audiofile to use for test. Defaults to test.wav")
    parser.add_argument('-t', '--trials', type=int, default=test_obj.trials, metavar="T",
                        help="Number of trials to use for test. Defaults to 100")
    parser.add_argument('-r', '--radioport', default='', metavar="PORT",
                        help="Port to use for radio interface. Defaults to the first"+
                        " port where a radio interface is detected")
    parser.add_argument('-z', '--bgnoisefile', dest="bgnoise_file", default='', help="If this is"+
                        " non empty then it is used to read in a noise file to be mixed with the "+
                        "test audio. Default is no background noise")
    parser.add_argument('-v', '--bgnoisevolume', dest="bgnoise_volume", type=float,
                        default=test_obj.bgnoise_volume, help="Scale factor for background"+
                        " noise. Defaults to 0.1")
    parser.add_argument('-w', '--pttwait', dest="ptt_wait", type=float, default=test_obj.ptt_wait,
                        metavar="T", help="The amount of time to wait in seconds between pushing the"+
                        " push to talk button and starting playback. This allows time "+
                        "for access to be granted on the system. Default value is 0.68 seconds")
    parser.add_argument('-b', '--blocksize', type=int, default=test_obj.audio_interface.blocksize, metavar="SZ",
                        help="Block size for transmitting audio, must be a power of 2 "+
                        "(default: %(default)s)")
    parser.add_argument('-q', '--buffersize', type=int, default=test_obj.audio_interface.buffersize, metavar="SZ",
                        help="Number of blocks used for buffering audio (default: %(default)s)")
    parser.add_argument('-o', '--overplay', type=float, default=test_obj.audio_interface.overplay, metavar="DUR",
                        help="The number of seconds to play silence after the audio is complete"+
                        ". This allows for all of the audio to be recorded when there is delay"+
                        " in the system")
    parser.add_argument('-d', '--outdir', default=test_obj.outdir, metavar="DIR",
                        help="Directory that is added to the output path for all files")
    
    args = parser.parse_args()
    
    # Set M2E object variables to terminal arguments
    for k, v in vars(args).items():
        if hasattr(test_obj, k):
            setattr(test_obj, k, v)
    
    # Check for value errors with M2E instance variables
    test_obj.param_check()
    
    #---------------------[Set audio interface properties]---------------------
    test_obj.audio_interface.blocksize=args.blocksize
    test_obj.audio_interface.buffersize=args.buffersize
    test_obj.audio_interface.overplay=args.overplay
    
    #set correct channels    
    if(test_obj.test == "m2e_1loc"):
        test_obj.audio_interface.playback_chans={'tx_voice':0}
        test_obj.audio_interface.rec_chans={'rx_voice':0}
    elif(test_obj.test == "m2e_2loc_tx"):
        test_obj.audio_interface.playback_chans={'tx_voice':0}
        test_obj.audio_interface.rec_chans={'timecode':1}
    elif(test_obj.test == "m2e_2loc_rx"):
        test_obj.audio_interface.playback_chans={}
        test_obj.audio_interface.rec_chans={'rx_voice':0,'timecode':1}
    
    #---------------------------[Open RadioInterface]---------------------------
    
    with mcvqoe.hardware.RadioInterface(args.radioport) as test_obj.ri:

        #------------------------------[Get test info]------------------------------
        test_obj.info=mcvqoe.gui.pretest(args.outdir,
                    check_function=lambda : mcvqoe.hardware.single_play(
                                                    test_obj.ri,test_obj.audio_interface,
                                                    ptt_wait=test_obj.ptt_wait))
        #------------------------------[Run Test]------------------------------
        test_obj.run()
        print(f'Test complete, data saved in \'{test_obj.data_filename}\'')


    
if __name__ == "__main__":
    
    main()