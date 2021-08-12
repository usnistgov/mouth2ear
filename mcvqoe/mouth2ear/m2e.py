import csv
import datetime
import json
import math
import os
import shutil
import signal
import time
from fractions import Fraction

#version import for logging purposes
from .version import version

import matplotlib.pyplot as plt
import mcvqoe.base
import mcvqoe.delay
import numpy as np
import pkg_resources
import scipy.signal
from mcvqoe.base.terminal_user import terminal_progress_update
from mcvqoe.timing import require_timecode


class measure:

    no_log = ("test", "ri")

    def __init__(self, **kwargs):

        self.audio_files = [
            pkg_resources.resource_filename(
                "mcvqoe.mouth2ear", "audio_clips/F1_harvard_phrases.wav"
            ),
            pkg_resources.resource_filename(
                "mcvqoe.mouth2ear", "audio_clips/F2_harvard_phrases.wav"
            ),
            pkg_resources.resource_filename(
                "mcvqoe.mouth2ear", "audio_clips/M1_harvard_phrases.wav"
            ),
            pkg_resources.resource_filename(
                "mcvqoe.mouth2ear", "audio_clips/M2_harvard_phrases.wav"
            ),
        ]
        self.audio_path = ""
        self.full_audio_dir = False
        self.audio_interface = None
        self.bgnoise_file = ""
        self.bgnoise_volume = 0.1
        self.info = {}
        self.outdir = ""
        self.ptt_wait = 0.68
        self.ptt_gap = 3.1
        self.ri = None
        self.test = "m2e_1loc"
        self.trials = 100
        self.get_post_notes = None
        self.progress_update = terminal_progress_update
        self.rng = np.random.default_rng()
        self.save_tx_audio=True
        self.save_audio=True

        for k, v in kwargs.items():
            if hasattr(self, k):
                setattr(self, k, v)
            else:
                raise TypeError(f"{k} is not a valid keyword argument")

    def csv_header_fmt(self):
        """
        generate header and format for .csv files.
        
        This generates a header for .csv files along with a format (that can be
        used with str.format()) to generate each row in the .csv. For m2e this
        is a static return, a function is used here for consistency with other
        measurements.
        
        Parameters
        ----------
        
        Returns
        -------
        hdr : string
            csv header string
        fmt : string
            format string for data lines for the .csv file
        """
        hdr = "Timestamp,Filename,m2e_latency,channels\n"
        fmt = "{Timestamp},{Filename},{m2e_latency},{channels}\n"
        
        return (hdr, fmt)

    def load_audio(self, fs_test):
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
        """

        # if we are not using all files, check that audio files is not empty
        if not self.audio_files and not self.full_audio_dir:
            # TODO : is this the right error to use here??
            raise ValueError("Expected self.audio_files to not be empty")

        # Get bgnoise_file and resample
        if self.bgnoise_file:
            nfs, nf = mcvqoe.base.audio_read(self.bgnoise_file)
            rs = Fraction(fs_test / nfs)
            nf = scipy.signal.resample_poly(nf, rs.numerator, rs.denominator)

        if self.full_audio_dir:
            # override audio_files
            self.audio_files = []
            # look through all things in audio_path
            for f in os.scandir(self.audio_path):
                # make sure this is a file
                if f.is_file():
                    # get extension
                    _, ext = os.path.splitext(f.name)
                    # check for .wav files
                    if ext == ".wav":
                        # add to list
                        self.audio_files.append(f.name)
                # TODO : recursive search?

        # list for input speech
        self.y = []

        for f in self.audio_files:
            # make full path from relative paths
            f_full = os.path.join(self.audio_path, f)
            # load audio
            fs_file, audio_dat = mcvqoe.base.audio_read(f_full)
            # check fs
            if fs_file != fs_test:
                rs_factor = Fraction(fs_test / fs_file)
                audio = scipy.signal.resample_poly(
                    audio_dat, rs_factor.numerator, rs_factor.denominator
                )
            else:
                # Convert to float sound array and add to list
                audio = audio_dat

            # check if we are adding noise
            if self.bgnoise_file:
                # add noise (repeated to audio file size)
                audio = audio + np.resize(nf, audio.size) * self.bgnoise_volume

            # append audio to list
            self.y.append(audio)

    def run(self):
        if self.test == "m2e_1loc":
            return self.m2e_1loc()
        elif self.test == "m2e_2loc_tx":
            return self.m2e_2loc_tx()
        elif self.test == "m2e_2loc_rx":
            return self.m2e_2loc_rx()
        else:
            raise ValueError(f'Unknown test type "{self.test}"')

    def param_check(self):
        """Check all input parameters for value errors"""

        if (
            (self.test != "m2e_1loc")
            and (self.test != "m2e_2loc_tx")
            and (self.test != "m2e_2loc_rx")
        ):
            raise ValueError(f"\n{self.test} is an incorrect test")

        if self.trials < 1:
            raise ValueError(f"\nTrials parameter needs to be more than 0")

        if self.ptt_wait < 0:
            raise ValueError(f"\nptt_wait parameter must be >= 0")

    def m2e_1loc(self):
        """Run a m2e_1loc test"""
        # ------------------[Check for correct audio channels]------------------
        if "tx_voice" not in self.audio_interface.playback_chans.keys():
            raise ValueError("self.audio_interface must be set up to play tx_voice")
        if "rx_voice" not in self.audio_interface.rec_chans.keys():
            raise ValueError("self.audio_interface must be set up to record rx_voice")
        # -------------------------[Get Test Start Time]-------------------------

        self.info["Tstart"] = datetime.datetime.now()
        dtn = self.info["Tstart"].strftime("%d-%b-%Y_%H-%M-%S")

        # --------------------------[Fill log entries]--------------------------
        # set test name
        self.info["test"] = "M2E"
        # fill in standard stuff
        self.info.update(mcvqoe.base.write_log.fill_log(self))

        # -----------------------[Setup Files and folders]-----------------------

        # generate data dir names
        data_dir = os.path.join(self.outdir, "data")
        wav_data_dir = os.path.join(data_dir, "wav")
        csv_data_dir = os.path.join(data_dir, "csv")

        # create data directories
        os.makedirs(csv_data_dir, exist_ok=True)
        os.makedirs(wav_data_dir, exist_ok=True)

        # generate base file name to use for all files
        base_filename = "capture_%s_%s" % (self.info["Test Type"], dtn)

        # generate test dir names
        wavdir = os.path.join(wav_data_dir, base_filename)

        # create test dir
        os.makedirs(wavdir, exist_ok=True)

        # generate csv name
        self.data_filename = os.path.join(csv_data_dir, f"{base_filename}.csv")

        # generate temp csv name
        temp_data_filename = os.path.join(csv_data_dir, f"{base_filename}_TEMP.csv")

        # -------------------------[Generate CSV header]-------------------------
        
        header,dat_format=self.csv_header_fmt()

        # ---------------------[Load Audio Files if Needed]---------------------

        if not hasattr(self, "y"):
            self.load_audio(self.audio_interface.sample_rate)

        # generate clip index
        self.clipi = self.rng.permutation(self.trials) % len(self.y)

        # -----------------------[Add Tx audio to wav dir]-----------------------
    
        # get name with out path or ext
        clip_names = [os.path.basename(os.path.splitext(a)[0]) for a in self.audio_files]

        if(self.save_tx_audio and self.save_audio):
            # write out Tx clips to files
            for dat, name in zip(self.y, clip_names):
                out_name = os.path.join(wavdir, f"Tx_{name}")
                mcvqoe.base.audio_write(
                    out_name + ".wav", int(self.audio_interface.sample_rate), dat
                )

        # ------------------------[Compute check trials]------------------------
        
        trial_check = np.zeros(self.trials,dtype=bool)
        
        if self.trials > 10:
            #check every 10th trial
            trial_check[0::10] = True
        else:
            #just check at the beginning and the end
            trial_check[0]=True
            trial_check[self.trials]=True


        # ---------------------------[write log entry]---------------------------
        
        mcvqoe.base.write_log.pre(info=self.info, outdir=self.outdir)
        
        # ---------------[Try block so we write notes at the end]---------------

        try:

            # -------------------------[Turn on RI LED]-------------------------
            self.ri.led(1, True)

            # -----------------------[write initial csv file]-----------------------
            with open(temp_data_filename, "wt") as f:
                f.write(header)

            # ------------------------[Measurement Loop]------------------------
            for trial in range(self.trials):
                # -----------------------[Update progress]-------------------------
                if not self.progress_update("test", self.trials, trial):
                    # turn off LED
                    self.ri.led(1, False)
                    print("Exit from user")
                    break
                # -----------------------[Get Trial Timestamp]-----------------------
                ts = datetime.datetime.now().strftime("%d-%b-%Y %H:%M:%S")

                # --------------------[Key Radio and play audio]--------------------

                # Press the push to talk button
                self.ri.ptt(True)

                # Pause the indicated amount to allow the radio to access the system
                time.sleep(self.ptt_wait)

                clip_index = self.clipi[trial]

                # Create audiofile name/path for recording
                audioname = f"Rx{trial+1}_{clip_names[clip_index]}.wav"
                audioname = os.path.join(wavdir, audioname)

                # Play/Record
                rec_chans = self.audio_interface.play_record(self.y[clip_index], audioname)

                # Release the push to talk button
                self.ri.ptt(False)

                # -----------------------[Pause Between runs]-----------------------

                time.sleep(self.ptt_gap)

                # -----------------------------[Data Processing]----------------------------

                trial_dat = self.process_audio(
                                                clip_index,
                                                audioname,
                                                rec_chans,
                                                trial_check[trial],
                                                trial,
                                               )
                
                #add extra info
                trial_dat['Timestamp'] = ts
                trial_dat['Filename'] = clip_names[clip_index]
                
                # -------------------[Delete file if needed]-------------------
                if(not self.save_audio):
                    os.remove(audioname)
                    
                # --------------------------[Write CSV]--------------------------

                with open(temp_data_filename, "at") as f:
                    f.write(
                        dat_format.format(**trial_dat)
                    )

            # -----------------------------[Cleanup]-----------------------------

            # move temp file to real file
            shutil.move(temp_data_filename, self.data_filename)

            # ---------------------------[Turn off RI LED]---------------------------

            self.ri.led(1, False)

        finally:
            if self.get_post_notes:
                # get notes
                info = self.get_post_notes()
            else:
                info = {}
            # finish log entry
            mcvqoe.base.write_log.post(outdir=self.outdir, info=info)

    def process_audio(self, clip_index,fname, rec_chans, check=False, t_num=-1):
        """
        estimate mouth to ear latency for an audio clip.

        Parameters
        ----------
        clip_index : int
            index of the matching transmit clip. can be found with find_clip_index
        fname : str
            audio file to process
        rec_chans : list of strs
            List of audio channel types as returned by `play_record`.
        check : bool, default=False
            If True, run some checks on the audio and complain if levels are low.
        t_num : int, default=-1
            If a check fails, this is used to give info on which trial failed.

        Returns
        -------
        dict
            returns a dictionary with estimated values
            
        See Also
        --------
        mcvqoe.hardware.audio_player : Hardware implementation of play_record.
        mcvqoe.hardware.QoEsim : Simulation implementation of play_record.

        """
        
        # -----------------------------[Load audio]----------------------------
        fs,rec_dat = mcvqoe.base.audio_read(fname)

        # check if we have more than one channel
        if rec_dat.ndim != 1:
            # get index of the rx_voice channel
            voice_idx = rec_chans.index("rx_voice")
            # get voice channel
            voice_dat = rec_dat[:, voice_idx]
        else:
            # only one channel
            voice_dat = rec_dat
            
        # Estimate the mouth to ear latency
        (_, dly) = mcvqoe.delay.ITS_delay_est(
            self.y[clip_index], voice_dat, "f", fs=self.audio_interface.sample_rate
        )
        
        # -----------------------------[Trial Check]----------------------------

        # Check if we run statistics on this trial
        if check:

            # Calculate RMS of received audio
            rms = round(math.sqrt(np.mean(voice_dat ** 2)), 4)

            # check if levels are low
            if rms < 1e-3:
                continue_test = self.progress_update(
                    "check-fail",
                    self.trials,
                    t_num,
                    msg=f"Low input levels detected. RMS = {rms}",
                )
                if not continue_test:
                    # turn off LED
                    self.ri.led(1, False)
                    raise SystemExit()
                    
        #----------------------------[calculate M2E]----------------------------
        
        estimated_m2e_latency = dly / self.audio_interface.sample_rate
        
        #-----------------------------[Return Info]-----------------------------
        
        return {
                'm2e_latency' : estimated_m2e_latency,
                'channels' : mcvqoe.base.audio_channels_to_string(rec_chans),
                }

    def plot(self, name=None):

        if not name:
            name = self.data_filename

        with open(name, "rt") as csv_f:
            # create dict reader
            reader = csv.DictReader(csv_f)
            # empty list for M2E data
            m2e_dat = []
            #
            for row in reader:
                m2e_dat.append(float(row["m2e_latency"]))

        # convert to numpy array
        m2e_dat = np.array(m2e_dat)

        # ----------------------------[Generate Plots]------------------------------

        # Overall mean delay
        ovrl_dly = np.mean(m2e_dat)

        # Get standard deviation
        std_delay = np.std(m2e_dat, dtype=np.float64)
        std_delay = std_delay * (1e6)

        # Print StD to terminal
        print("StD: %.2fus\n" % std_delay, flush=True)

        # Create trial scatter plot
        plt.figure()
        x2 = range(1, len(m2e_dat) + 1)
        plt.plot(x2, m2e_dat, "o", color="blue")
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

        # ------------------[Check for correct audio channels]------------------
        if "tx_voice" not in self.audio_interface.playback_chans.keys():
            raise ValueError("self.audio_interface must be set up to play tx_voice")
        #we need to be recording a timecode
        require_timecode(self.audio_interface)
        # -------------------------[Get Test Start Time]-------------------------

        self.info["Tstart"] = datetime.datetime.now()
        dtn = self.info["Tstart"].strftime("%d-%b-%Y_%H-%M-%S")

        # --------------------------[Fill log entries]--------------------------
        # set test name, needs to match log_search.datafilenames
        self.info["test"] = "Tx Two Loc Test"
        # fill in standard stuff
        self.info.update(mcvqoe.base.write_log.fill_log(self))

        # -----------------------[Setup Files and folders]-----------------------

        # generate data dir names
        data_dir = os.path.join(self.outdir, "data")
        tx_dat_fold = os.path.join(data_dir, "2loc_tx-data")

        # generate base file name to use for all files
        base_filename = "capture_%s_%s" % (self.info["Test Type"], dtn)

        wavdir = os.path.join(tx_dat_fold, "Tx_" + base_filename)

        # create directories
        os.makedirs(wavdir, exist_ok=True)
        
        #Put .csv files in wav dir
        csv_data_dir = wavdir

        # generate csv name
        self.data_filename = os.path.join(csv_data_dir, f"{base_filename}.csv")

        # generate temp csv name
        temp_data_filename = os.path.join(csv_data_dir, f"{base_filename}_TEMP.csv")

        # ---------------------[Load Audio Files if Needed]---------------------

        if not hasattr(self, "y"):
            self.load_audio(self.audio_interface.sample_rate)

        # generate clip index
        self.clipi = self.rng.permutation(self.trials) % len(self.y)

        # -----------------------[Add Tx audio to wav dir]-----------------------

        # get name with out path or ext
        clip_names = [os.path.basename(os.path.splitext(a)[0]) for a in self.audio_files]

        # write out Tx clips to files
        for dat, name in zip(self.y, clip_names):
            out_name = os.path.join(wavdir, f"Tx_{name}")
            mcvqoe.base.audio_write(out_name + ".wav", int(self.audio_interface.sample_rate), dat)
            
        # -------------------------[Generate CSV header]-------------------------
        
        header,dat_format=self.csv_header_fmt()

        # ---------------------------[write log entry]---------------------------

        mcvqoe.base.write_log.pre(info=self.info, outdir=self.outdir)
        
        # ---------------[Try block so we write notes at the end]---------------
        try:

            # -----------------------[write initial csv file]-----------------------
            with open(temp_data_filename, "wt") as f:
                f.write(header)
                
            # -------------------------[Turn on RI LED]-------------------------

            self.ri.led(1, True)

            # ------------------------[Measurement Loop]------------------------

            for trial in range(self.trials):

                # -----------------------[Update progress]-------------------------
                if not self.progress_update("test", self.trials, trial):
                    # turn off LED
                    self.ri.led(1, False)
                    print("Exit from user")
                    break
                # -----------------------[Get Trial Timestamp]-----------------------
                ts = datetime.datetime.now().strftime("%d-%b-%Y %H:%M:%S")

                # --------------------[Key Radio and play audio]--------------------

                # Press the push to talk button
                self.ri.ptt(True)

                # Pause the indicated amount to allow the radio to access the system
                time.sleep(self.ptt_wait)

                clip_index = self.clipi[trial]

                # Create audiofile name/path for recording
                audioname = f"Rx{trial+1}_{clip_names[clip_index]}.wav"
                audioname = os.path.join(wavdir, audioname)

                # Play/Record
                rec_chans = self.audio_interface.play_record(self.y[clip_index], audioname)

                # Release the push to talk button
                self.ri.ptt(False)

                # -----------------------[Pause Between runs]-----------------------

                time.sleep(self.ptt_gap)

                # --------------------------[Write CSV]--------------------------

                chan_str = "(" + (";".join(rec_chans)) + ")"

                with open(temp_data_filename, "at") as f:
                    f.write(
                        dat_format.format(
                            Timestamp=ts,
                            Filename=clip_names[clip_index],
                            m2e_latency=np.NaN,
                            channels=chan_str,
                        )
                    )
                    
            # -----------------------------[Cleanup]-----------------------------

            # move temp file to real file
            shutil.move(temp_data_filename, self.data_filename)

            # ---------------------------[Turn off RI LED]---------------------------

            self.ri.led(1, False)
            
            # -----------------------[Notify User of Completion]------------------------

            self.progress_update('status', self.trials, self.trials, 
                msg="Data collection complete, you may now stop data collection on"
                + " the receiving end",
            )

        finally:
            if self.get_post_notes:
                # get notes
                info = self.get_post_notes()
            else:
                info = {}
            # finish log entry
            mcvqoe.base.write_log.post(outdir=self.outdir, info=info)


    def m2e_2loc_rx(self):

        # ------------------[Check for correct audio channels]------------------
        if "rx_voice" not in self.audio_interface.rec_chans.keys():
            raise ValueError("self.audio_interface must be set up to record rx_voice")
        #we need to be recording a timecode
        require_timecode(self.audio_interface)

        # -------------------------[Get Test Start Time]-------------------------
        self.info["Tstart"] = datetime.datetime.now()
        dtn = self.info["Tstart"].strftime("%d-%b-%Y_%H-%M-%S")

        # --------------------------[Fill log entries]--------------------------

        # set test name, needs to match log_search.datafilenames
        self.info["test"] = "Rx Two Loc Test"
        # fill in standard stuff
        self.info.update(mcvqoe.base.write_log.fill_log(self))

        # -----------------------[Setup Files and folders]-----------------------

        # Create rx-data folder
        data_dir = os.path.join(self.outdir, "data")
        rx_dat_fold = os.path.join(data_dir, "2loc_rx-data")
        os.makedirs(rx_dat_fold, exist_ok=True)

        base_filename = "capture_%s_%s" % (self.info["Test Type"], dtn)

        self.data_filename = os.path.join(rx_dat_fold, "Rx_" + base_filename + ".wav")
        
        info_name = os.path.join(rx_dat_fold, "Rx_" + base_filename + ".json")

        # ---------------------------[write log entry]---------------------------

        mcvqoe.base.write_log.pre(info=self.info, outdir=self.outdir)

        # ---------------[Try block so we write notes at the end]---------------
        try:
            # ----------------------[Send progress update]---------------------
            self.progress_update('status', 1, 0, 
                                 msg='Two location receive recording running')

            # --------------------------[Record audio]--------------------------
            rec_names=self.audio_interface.record(self.data_filename)
            
            # ------------------------[Save audio info]------------------------
            
            with open(info_name,'wt') as info_f:
                json.dump({'channels':rec_names},info_f)
                
        finally:
            if self.get_post_notes:
                # get notes
                info = self.get_post_notes()
            else:
                info = {}
            # finish log entry
            mcvqoe.base.write_log.post(outdir=self.outdir, info=info)
