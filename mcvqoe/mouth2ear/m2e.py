
import csv
import datetime
import math
import mcvqoe
import os
import pkg_resources
import scipy.io.wavfile
import scipy.signal
import shutil
import signal
import time

from fractions import Fraction
from mcvqoe.misc import audio_float
from mcvqoe.sliding_delay import sliding_delay_estimates

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
        

class measure:

    no_log = ('test', 'ri')

    def __init__(self):
        
        self.audio_files = [pkg_resources.resource_filename('mcvqoe','mouth2ear/audio_clips/F1_harvard1.wav'),
                            pkg_resources.resource_filename('mcvqoe','mouth2ear/audio_clips/F2_harvard2.wav'),
                            pkg_resources.resource_filename('mcvqoe','mouth2ear/audio_clips/M1_harvard10.wav'),
                            pkg_resources.resource_filename('mcvqoe','mouth2ear/audio_clips/M2_harvard6.wav'),
                            ]
        self.audio_path = ''
        self.full_audio_dir=False
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
        self.rng=np.random.default_rng()
    
    def load_audio(self,fs_test):
        """
        load audio files for use in test.
        
        this loads audio from self.audio_files and stores values in self.y,
        self.cutpoints and self.keyword_spacings
        In most cases run() will call this automatically but, it can be called
        in the case that self.audio_files is changed after run() is called

        Parameters
        ----------

        Returns
        -------

        Raises
        ------
        ValueError
            If self.audio_files is empty
        RuntimeError
            If clip fs is not 48 kHz
        """
   
        #if we are not using all files, check that audio files is not empty
        if not self.audio_files and not self.full_audio_dir:
            #TODO : is this the right error to use here??
            raise ValueError('Expected self.audio_files to not be empty')
            
        # Get bgnoise_file and resample
        if (self.bgnoise_file):
            nfs, nf = scipy.io.wavfile.read(self.bgnoise_file)
            rs = Fraction(fs_test/nfs)
            nf = audio_float(nf)
            nf = scipy.signal.resample_poly(nf, rs.numerator, rs.denominator)
            
        if(self.full_audio_dir):
            #override audio_files
            self.audio_files=[]
            #look through all things in audio_path
            for f in os.scandir(self.audio_path):
                #make sure this is a file
                if(f.is_file()): 
                    #get extension
                    _,ext=os.path.splitext(f.name)
                    #check for .wav files
                    if(ext=='.wav'):
                        #add to list
                        self.audio_files.append(f.name)
                #TODO : recursive search?

        #list for input speech
        self.y=[]
        
        for f in self.audio_files:
            #make full path from relative paths
            f_full=os.path.join(self.audio_path,f)
            # load audio
            fs_file, audio_dat = scipy.io.wavfile.read(f_full)
            #check fs
            if(fs_file != fs_test):
                rs_factor = Fraction(fs_test/fs_file)
                audio_dat = audio_float(audio_dat)
                audio = scipy.signal.resample_poly(audio_dat, rs_factor.numerator, rs_factor.denominator)
            else:
                # Convert to float sound array and add to list
                audio=mcvqoe.audio_float(audio_dat)
            
            # check if we are adding noise
            if (self.bgnoise_file):
                #add noise (repeated to audio file size) 
                audio = audio + np.resize(nf, audio.size)*self.bgnoise_volume
            
            #append audio to list
            self.y.append(audio)
            
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
        
        #-------------------------[Generate CSV header]-------------------------    
        header='Timestamp,Filename,m2e_latency,channels\n'
        dat_format='{time},{name},{m2e},{chans}\n'
        
        #---------------------[Load Audio Files if Needed]---------------------
        
        if(not hasattr(self,'y')):
            self.load_audio(self.audio_interface.sample_rate)

        #generate clip index
        self.clipi=self.rng.permutation(self.trials)%len(self.y)
        
        #-----------------------[Add Tx audio to wav dir]-----------------------
        
        #get name with out path or ext
        clip_names=[ os.path.basename(os.path.splitext(a)[0]) for a in self.audio_files]
        
        #write out Tx clips to files
        for dat,name in zip(self.y,clip_names):
            out_name=os.path.join(wavdir,f'Tx_{name}')
            scipy.io.wavfile.write(out_name+'.wav', int(self.audio_interface.sample_rate), dat)
        
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
            
            #-----------------------[write initial csv file]-----------------------
            with open(temp_data_filename,'wt') as f:
                f.write(header)
            
            #------------------------[Measurement Loop]------------------------
            for trial in range(self.trials):
                #-----------------------[Update progress]-------------------------
                if( not self.progress_update('test',self.trials,trial)):
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
                
                clip_index=self.clipi[trial]
                
                # Create audiofile name/path for recording
                audioname = f'Rx{trial+1}_{clip_names[clip_index]}.wav'
                audioname = os.path.join(wavdir, audioname)
                
                # Play/Record
                rec_chans = self.audio_interface.play_record(self.y[clip_index], audioname)
                
                # Release the push to talk button
                self.ri.ptt(False)
                
                #-----------------------[Pause Between runs]-----------------------
                
                time.sleep(self.ptt_gap)
                
                #-----------------------------[Load audio]----------------------------
                proc_audio_sr, proc_audio = scipy.io.wavfile.read(audioname)
                
                #check if we have more than one channel
                if(proc_audio.ndim !=1 ):
                    #get index of the rx_voice channel
                    voice_idx=rec_chans.index('rx_voice')
                    #get voice channel
                    proc_voice=proc_audio[:,voice_idx]
                else:
                    #only one channel, use items
                    proc_voice=proc_audio
                    
                #convert to floating point values for calculations
                proc_voice = audio_float(proc_voice)
                    
                #-----------------------------[Data Processing]----------------------------
                
                
                # Check if we run statistics on this trial
                if np.any(check_trials == trial):
                    
                    # Calculate RMS of received audio
                    rms = round(math.sqrt(np.mean(proc_voice**2)), 4)
                    
                    #check if levels are low
                    if(rms<1e-3):
                        continue_test=self.progress_update('test',self.trials,trial,
                                err_msg=f'Low input levels detected. RMS = {rms}')
                        if(not continue_test):
                            #turn off LED
                            self.ri.led(1, False)
                            print('Exit from user')
                            break
                #-----------------------------[Data Processing]----------------------------
                    
                # Estimate the mouth to ear latency
                new_delay = sliding_delay_estimates(proc_voice, self.y[clip_index], self.audio_interface.sample_rate)[0]
                
                newest_delay = np.multiply(new_delay, 1e-3)
                
                #--------------------------[Write CSV]--------------------------
                
                chan_str='('+(';'.join(rec_chans))+')'
                
                with open(temp_data_filename,'at') as f:
                    f.write(dat_format.format(
                                        time=ts,
                                        name=clip_names[clip_index],
                                        m2e=np.mean(newest_delay),
                                        chans=chan_str,
                                        ))
            
            #-----------------------------[Cleanup]-----------------------------
            
            #move temp file to real file
            shutil.move(temp_data_filename,self.data_filename)
            
            #---------------------------[Turn off RI LED]---------------------------

            self.ri.led(1,False)
            
        finally:
            if(self.get_post_notes):
                #get notes
                info=self.get_post_notes()
            else:
                info={}
            #finish log entry
            mcvqoe.post(outdir=self.outdir,info=info)
        
        
    def plot(self,name=None):
        
        if( not name):
            name=self.data_filename
        
        with open(name,'rt') as csv_f:
            #create dict reader
            reader=csv.DictReader(csv_f)
            #empty list for M2E data
            m2e_dat=[]
            #
            for row in reader:
                m2e_dat.append(float(row['m2e_latency']))

        #convert to numpy array
        m2e_dat=np.array(m2e_dat)
        
        #----------------------------[Generate Plots]------------------------------
        
        # Overall mean delay
        ovrl_dly = np.mean(m2e_dat)
        
        # Get standard deviation
        std_delay = np.std(m2e_dat, dtype=np.float64)
        std_delay = std_delay*(1e6)
        
        # Print StD to terminal
        print("StD: %.2fus\n" % std_delay, flush=True)
        
        # Create trial scatter plot
        plt.figure() 
        x2 = range(1, len(m2e_dat)+1)
        plt.plot(x2, m2e_dat, 'o', color='blue')
        plt.xlabel("Trial Number")
        plt.ylabel("Delay(s)")
        
        # Create histogram for mean
        plt.figure()
        uniq = np.unique(m2e_dat)
        dlymin = np.amin(m2e_dat)
        dlymax = np.amax(m2e_dat)
        plt.hist(m2e_dat, bins=len(uniq), range=(dlymin, dlymax), rwidth=0.5)
        plt.title("Mean: %.5fs" % ovrl_dly)
        plt.xlabel("Delay(s)")
        plt.ylabel("Frequency of indicated delay")
        plt.show()
                  
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
        
        wavdir = os.path.join(tx_dat_fold, 'Tx_'+base_filename)
        
        #create directories
        os.makedirs(wavdir, exist_ok=True)        
        
        #generate csv name
        self.data_filename=os.path.join(csv_data_dir,f'{base_filename}.csv')
        
        #generate temp csv name
        temp_data_filename = os.path.join(csv_data_dir,f'{base_filename}_TEMP.csv')
        
        #---------------------[Load Audio Files if Needed]---------------------
        
        if(not hasattr(self,'y')):
            self.load_audio(self.audio_interface.sample_rate)

        #generate clip index
        self.clipi=self.rng.permutation(self.trials)%len(self.y)
        
        #-----------------------[Add Tx audio to wav dir]-----------------------
        
        #get name with out path or ext
        clip_names=[ os.path.basename(os.path.splitext(a)[0]) for a in self.audio_files]
        
        #write out Tx clips to files
        for dat,name in zip(self.y,clip_names):
            out_name=os.path.join(wavdir,f'Tx_{name}')
            scipy.io.wavfile.write(out_name+'.wav', int(self.audio_interface.sample_rate), dat)


        
        #---------------[Try block so we write notes at the end]---------------
        try:
            
            #-------------------------[Turn on RI LED]-------------------------
            
            self.ri.led(1, True)
            
            #------------------------[Measurement Loop]------------------------
            
            for trial in range(self.trials):
                
                #-----------------------[Update progress]-------------------------
                if(not self.progress_update('test',self.trials,trial)):
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
                audioname = f'Rx{trial+1}_{clip_names[clip_index]}.wav'
                audioname = os.path.join(wavdir, audioname)
                
                # Play/Record
                rec_chans = self.audio_interface.play_record(self.y[clip_index], audioname)
                
                # Release the push to talk button
                self.ri.ptt(False)
                
                #-----------------------[Pause Between runs]-----------------------
                
                time.sleep(self.ptt_gap)
                
                #--------------------------[Write CSV]--------------------------
                
                chan_str='('+(';'.join(rec_chans))+')'
                
                with open(temp_data_filename,'at') as f:
                    f.write(dat_format.format(
                                        time=ts,
                                        name=clip_names[clip_index],
                                        m2e=np.NaN,
                                        chans=chan_str,
                                        ))
                    
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
