import argparse
import csv
import datetime
import git
import math
import os
import scipy.io.wavfile
import scipy.signal
import signal
import sys
import test_info_gui
import time
import write_log

from audio_player import AudioPlayer
from fractions import Fraction
from misc import audio_float
from play_record import play_record
from radio_interface import RadioInterface
from sliding_delay import sliding_delay_estimates
from tkinter import scrolledtext

import matplotlib.pyplot as plt
import numpy as np
import sounddevice as sd     

class M2E:
    
    def __init__(self):
        
        self.audio_file = "test.wav"
        self.audio_player = None
        self.bgnoise_file = ""
        self.bgnoise_volume = 0.1
        self.blocksize = 512
        self.buffersize = 20
        self.fs = int(48e3)
        self.info = {}
        self.outdir = ""
        self.overplay = 1.0
        self.ptt_wait = 0.68
        self.radioport = ""
        self.ri = None
        self.test = "m2e_1loc"
        self.trials = 100
    
    def __enter__(self):
        
        return self
    
    def __enter__(self, exc_type, exc_value, exc_traceback):
    
        print(f"\n{exc_traceback}\n")
    
    def info_adder(self):
        """Add relevant information to info dictionary"""
        
        for i in self.__dict__:
            if (i != "info"):
                self.info[i] = self.__dict__[i]
    
    def param_check(self):
        """Check all input parameters for value errors"""
        
        if ((self.test!="m2e_1loc") and (self.test!="m2e_2loc_tx")
            and (self.test!="m2e_2loc_rx")):
            raise ValueError(f"\n{self.test} is an incorrect test")
        
        if (self.blocksize <= 0):
            raise ValueError(f"\nBlocksize must be greater than zero")
        
        if (self.buffersize < 1):
            raise ValueError(f"\nBuffersize must be at least 1")
        
        if (self.trials < 1):
            raise ValueError(f"\nTrials parameter needs to be more than 0")
        
        if not (os.path.isfile(self.audio_file)):
            raise ValueError(f"\nAudio file chosen does not exist")
        
        if (self.ptt_wait < 0):
            raise ValueError(f"\nptt_wait parameter must be >= 0")
        
        if (self.overplay < 0):
            raise ValueError(f"\nOverplay parameter must be >= 0")
        
    def m2e_1loc(self):
        """Run a m2e_1loc test"""
        
        # Signal handler for graceful shutdown in case of SIGINT(User ctrl^c)
        signal.signal(signal.SIGINT, self.sig_handler)
        
        # Initialize 1loc_data folder
        datadir = os.path.join(self.outdir, '1loc_data')
        os.makedirs(datadir, exist_ok=True)
        
        # Compute check trials       
        if (self.trials > 10):
            check_trials = np.arange(0, (self.trials+1), 10)
            check_trials[0] = 1
        else:
            check_trials = np.array([1, self.trials])      
      
        # Create audio capture directory with test date/time
        td = self.info.get("Time").strftime("%d-%b-%Y_%H-%M-%S")
        capture_dir = os.path.join(datadir, '1loc_capture_'+td)
        os.makedirs(capture_dir, exist_ok=True)
            
        # Ready audio_file for play/record
        fs_file, audio_dat = scipy.io.wavfile.read(self.audio_file)
        rs_factor = Fraction(self.fs/fs_file)
        audio_dat = audio_float(audio_dat)
        audio = scipy.signal.resample_poly(audio_dat, rs_factor.numerator, rs_factor.denominator)
        
        # Save testing audio_file to audio capture directory for future use/testing
        tx_audio = os.path.join(capture_dir, '1loc_audio.wav')
        scipy.io.wavfile.write(tx_audio, self.fs, audio)
        
        # Get bgnoise_file and resample
        if (self.bgnoise_file):
            nfs, nf = scipy.io.wavfile.read(self.bgnoise_file)
            rs = Fraction(self.fs/nfs)
            nf = audio_float(nf)
            nf = scipy.signal.resample_poly(nf, rs.numerator, rs.denominator)
            
        # Add bgnoise_file
        if (self.bgnoise_file):
            if (nf.size != audio.size):
                nf = np.resize(nf, audio.size)
            audio = audio + nf*self.bgnoise_volume
            
        # Notify user of start
        print(f"Storing audio data in \n\t{capture_dir}\n", flush=True)
        
        # Create audioplayer object
        ap = AudioPlayer(fs=self.fs, blocksize=self.blocksize, buffersize=self.buffersize, overplay=self.overplay)
        
        # Open Radio Interface
        with RadioInterface(self.radioport) as ri:
            ri.led(1, True)
            dly_its = []
            
            # Play/Record Loop
            try:
                for itr in range(1, self.trials+1):
                    
                    # Press the push to talk button
                    ri.ptt(True)
                    
                    # Pause the indicated amount to allow the radio to access the system
                    time.sleep(self.ptt_wait)
                    
                    # Create audiofile name/path for recording
                    audioname = '1loc_Rx'+str(itr)+'.wav'
                    audioname = os.path.join(capture_dir, audioname)
                    
                    # Play/Record
                    filename = ap.play_rec_mono(audio, filename=audioname)
                    
                    # Release the push to talk button
                    ri.ptt(False)
                    
                    # Add a pause after playing/recording to remove run to run dependencies
                    time.sleep(3.1)
                    
                    #-----------------------------[Data Processing]----------------------------
                    
                    # Get latest run Rx audio
                    proc_audio_sr, proc_audio = scipy.io.wavfile.read(filename)
                    proc_audio = audio_float(proc_audio)
                    
                    # Check if we run statistics on this trial
                    if np.any(check_trials == itr):
                        
                        print("\nRun %s of %s complete :" % (itr, self.trials), flush=True)
                        
                        # Calculate RMS of received audio
                        rms = round(math.sqrt(np.mean(proc_audio**2)), 4)
                        
                        # Calculate Maximum of received audio
                        mx = round(np.max(proc_audio), 4)
                        
                        # Print RMS and Maximum
                        print("\tMax : %s\n\tRMS : %s\n\n" % (mx, rms), flush=True)
                    
                    # Find delay for plots
                    new_delay = sliding_delay_estimates(proc_audio, audio, self.fs)[0]
                    
                    newest_delay = np.multiply(new_delay, 1e-3)
                    
                    dly_its.append(newest_delay)
                    
            except Exception:
                e = sys.exc_info()
                print(f"Error Return Type: {type(e)}")
                print(f"Error Class: {e[0]}")
                print(f"Error Message: {e[1]}")
                print(f"Error Traceback: {traceback.format_tb(e[2])}")
                # Gather posttest notes and write everything to log
                post_dict = test_info_gui.post_test()
                write_log.post(post_dict)
            
        #-----------------------[Notify User of Completion]------------------------ 

        print("\nData collection completed\n", flush=True)
        
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
        
        # Write to csv file
        csv_path = os.path.join(capture_dir, td+'.csv')
        
        with open(csv_path, 'w', newline='') as csv_file:
            writer = csv.writer(csv_file)
            writer.writerow(["Mean Delay Per Trial (seconds)"])
            for i in range(len(its_dly_mean)):
                writer.writerow([its_dly_mean[i]])
             
            
    def m2e_2loc_tx(self):
        """Run a m2e_2loc_tx test"""
        
        # Signal handler for graceful shutdown in case of SIGINT
        signal.signal(signal.SIGINT, self.sig_handler)
        
        # Create tx-data folder
        tx_dat_fold = os.path.join(self.outdir,'2loc_tx-data')
        os.makedirs(tx_dat_fold, exist_ok=True)
        
        # Compute check trials
        if (self.trials > 10):
            check_trials = np.arange(0, self.trials+1, 10)
            check_trials[0] = 1
        else:
            check_trials = np.array([1, self.trials])
            
        # Create audio capture directory with current date/time
        td = self.info.get("Time").strftime("%d-%b-%Y_%H-%M-%S")
        capture_dir = os.path.join(tx_dat_fold, 'Tx_capture_'+td)
        os.makedirs(capture_dir, exist_ok=True)
        
        # Ready audio_file for play/record
        fs_file, audio_dat = scipy.io.wavfile.read(self.audio_file)
        rs_factor = Fraction(self.fs/fs_file)
        audio_dat = audio_float(audio_dat)
        audio = scipy.signal.resample_poly(audio_dat, rs_factor.numerator, rs_factor.denominator)
        
        # Save testing audiofile to audio capture directory for future use/testing
        tx_audio = os.path.join(capture_dir, 'Tx_audio.wav')
        scipy.io.wavfile.write(tx_audio, self.fs, audio)
        
        # Get bgnoise_file and resample
        if (self.bgnoise_file):
            nfs, nf = scipy.io.wavfile.read(self.bgnoise_file)
            rs = Fraction(fs/nfs)
            nf = audio_float(nf)
            nf = scipy.signal.resample_poly(nf, rs.numerator, rs.denominator)
            
        # Add bgnoise_file
        if (self.bgnoise_file):
            if (nf.size != audio.size):
                nf = np.resize(nf, audio.size)
            audio = audio + nf*self.bgnoise_volume
        
        # Notify user of start
        print(f"Storing audio data in \n\t{capture_dir}\n", flush=True)
        
        # Create audioplayer object
        ap = AudioPlayer(fs=self.fs, blocksize=self.blocksize, buffersize=self.buffersize, overplay=self.overplay)
        
        # Open Radio Interface
        with RadioInterface(self.radioport) as ri:
            ri.led(1, True)
            
            # Play/Record Loop
            try:
                for itr in range(1, self.trials+1):
                    
                    # Press the push to talk button
                    ri.ptt(True)
                    
                    # Pause the indicated amount to allow the radio to access the system
                    time.sleep(self.ptt_wait)
                    
                    # Create audiofile name/path for recording
                    audioname = 'Tc'+str(itr)+'.wav'
                    audioname = os.path.join(capture_dir, audioname)
                    
                    # Play/Record
                    filename = ap.play_rec_mono(audio, filename=audioname)
                    
                    # Release the push to talk button
                    ri.ptt(False)
                    
                    # Add a pause after playing/recording to remove run to run dependencies
                    time.sleep(3.1)
                    
                    #-----------------------------[Data Processing]----------------------------
                    
                    # Check if we run statistics on this trial
                    if np.any(check_trials == itr):
                        
                        print("\nRun %s of %s complete :" % (itr, self.trials), flush=True)
                        
                        proc_audio_sr, proc_audio = scipy.io.wavfile.read(filename)
                        proc_audio = audio_float(proc_audio)
                        
                        # Calculate RMS of received audio
                        rms = round(math.sqrt(np.mean(proc_audio**2)), 4)
                        
                        # Calculate Maximum of received audio
                        mx = round(np.max(proc_audio), 4)
                        
                        # Print RMS and Maximum
                        print("\tMax : %s\n\tRMS : %s\n\n" % (mx, rms), flush=True)
                        
            except Exception:
                e = sys.exc_info()
                print(f"Error Return Type: {type(e)}")
                print(f"Error Class: {e[0]}")
                print(f"Error Message: {e[1]}")
                print(f"Error Traceback: {traceback.format_tb(e[2])}")
                # Gather posttest notes and write everything to log
                post_dict = test_info_gui.post_test()
                write_log.post(post_dict)

        #-----------------------[Notify User of Completion]------------------------ 

        print('\n***Data collection complete, you may now stop data collection on the\n'
              +'   receiving end***\n', flush=True)
        
    def m2e_2loc_rx(self):
        
        # Create rx-data folder
        rx_dat_fold = os.path.join(self.outdir, '2loc_rx-data')
        os.makedirs(rx_dat_fold, exist_ok=True)
        
        # Create proper time/date syntax
        td = self.info.get("Time").strftime("%d-%b-%Y_%H-%M-%S")
        filename = os.path.join(rx_dat_fold, 'Rx_capture_'+td+'.wav')
        
        # Notify user of start
        print(f"Storing audio data in \n\t{rx_dat_fold}\n", flush=True)
        
        try:
            
            # Create AudioPlayer instance and begin recording
            recorder = AudioPlayer()
            recorder.record_stereo(filename=filename)
        
        except KeyboardInterrupt:
            print(f"\n")
        except Exception as e:
            # Gather posttest notes and write everything to log
            post_dict = test_info_gui.post_test()
            write_log.post(post_dict)
            
    def sig_handler(self, signal, frame):
        """Catch user's exit (CTRL+C) from program and collect post test notes."""
        # Gather posttest notes and write everything to log
        post_dict = test_info_gui.post_test()
        write_log.post(post_dict)
        sys.exit(1)

def main():
    
    # Create M2E object
    my_obj = M2E()

    #--------------------[Parse the command line arguments]--------------------
    
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-y', '--testtype', dest="test", default=my_obj.test, metavar="TEST",
                        help="M2E test to perform. Defaults to 1 location")
    parser.add_argument('-a', '--audiofile', dest="audio_file", default=my_obj.audio_file,
                        metavar="FILENAME", help="Choose audiofile to use for test. Defaults to test.wav")
    parser.add_argument('-t', '--trials', type=int, default=my_obj.trials, metavar="T",
                        help="Number of trials to use for test. Defaults to 10")
    parser.add_argument('-r', '--radioport', default='', metavar="PORT",
                        help="Port to use for radio interface. Defaults to the first"+
                        " port where a radio interface is detected")
    parser.add_argument('-z', '--bgnoisefile', dest="bgnoise_file", default='', help="If this is"+
                        " non empty then it is used to read in a noise file to be mixed with the "+
                        "test audio. Default is no background noise")
    parser.add_argument('-v', '--bgnoisevolume', dest="bgnoise_volume", type=float,
                        default=my_obj.bgnoise_volume, help="Scale factor for background"+
                        " noise. Defaults to 0.1")
    parser.add_argument('-w', '--pttwait', dest="ptt_wait", type=float, default=my_obj.ptt_wait,
                        metavar="T", help="The amount of time to wait in seconds between pushing the"+
                        " push to talk button and starting playback. This allows time "+
                        "for access to be granted on the system. Default value is 0.68 seconds")
    parser.add_argument('-b', '--blocksize', type=int, default=my_obj.blocksize, metavar="SZ",
                        help="Block size for transmitting audio, must be a power of 2 "+
                        "(default: %(default)s)")
    parser.add_argument('-q', '--buffersize', type=int, default=my_obj.buffersize, metavar="SZ",
                        help="Number of blocks used for buffering audio (default: %(default)s)")
    parser.add_argument('-o', '--overplay', type=float, default=my_obj.overplay, metavar="DUR",
                        help="The number of seconds to play silence after the audio is complete"+
                        ". This allows for all of the audio to be recorded when there is delay"+
                        " in the system")
    parser.add_argument('-d', '--outdir', default=my_obj.outdir, metavar="DIR",
                        help="Directory that is added to the output path for all files")
    
    args = parser.parse_args()
    
    # Set M2E object variables to terminal arguments
    for k, v in vars(args).items():
        if hasattr(my_obj, k):
            setattr(my_obj, k, v)
    
    # Check for value errors with M2E instance variables
    my_obj.param_check()
    
    # Gather pretest notes and M2E parameters
    my_obj.info = test_info_gui.pretest(my_obj.outdir)
    my_obj.info_adder()
    
    # Get ID and Version number from RadioInterface
    ri = RadioInterface(my_obj.radioport)
    my_obj.info["version"] = ri.get_version()
    my_obj.info["id"] = ri.get_id()
    del ri
    
    # Write pretest notes and info to tests.log
    write_log.pre(info_ref=my_obj.info)

    # Run chosen M2E test
    if (my_obj.test == "m2e_1loc"):
        my_obj.m2e_1loc()
    elif (my_obj.test == "m2e_2loc_tx"):
        my_obj.m2e_2loc_tx()
    elif (my_obj.test == "m2e_2loc_rx"):
        my_obj.m2e_2loc_rx()
    else:
        raise ValueError(f"\nIncorrect test type")
    
    # Gather posttest notes and write to log
    my_obj.info.update(test_info_gui.post_test())
    write_log.post(info=my_obj.info)
    
if __name__ == "__main__":
    
    main()
