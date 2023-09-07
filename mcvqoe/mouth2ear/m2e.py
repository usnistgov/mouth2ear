import os

from collections import namedtuple
from fractions import Fraction

import mcvqoe.mouth2ear.m2e_eval as evaluation
import mcvqoe.base
import mcvqoe.delay
import numpy as np
import pkg_resources
import scipy.signal
from mcvqoe.base.terminal_user import terminal_progress_update
from mcvqoe.delay.ITS_delay import active_speech_level

# version import for logging purposes
from .version import version


class measure(mcvqoe.base.Measure):
    # on load conversion to datetime object fails for some reason
    # TODO : figure out how to fix this, string works for now but this should work too:
    # row[k]=datetime.datetime.strptime(row[k],'%d-%b-%Y_%H-%M-%S')
    data_fields = {
        "Timestamp": str,
        "Filename": str,
        "m2e_latency": float,
        "channels": mcvqoe.base.parse_audio_channels,
    }

    no_log = ("test", "rng")
    
    measurement_name = "M2E"

    def __init__(self, **kwargs):

        self.audio_files = [
            pkg_resources.resource_filename("mcvqoe.mouth2ear", "audio_clips/F1_harvard_phrases.wav"),
            pkg_resources.resource_filename("mcvqoe.mouth2ear", "audio_clips/F2_harvard_phrases.wav"),
            pkg_resources.resource_filename("mcvqoe.mouth2ear", "audio_clips/M1_harvard_phrases.wav"),
            pkg_resources.resource_filename("mcvqoe.mouth2ear", "audio_clips/M2_harvard_phrases.wav"),
        ]
        self.audio_path = ""
        self.full_audio_dir = False
        self.audio_interface = None
        self.bgnoise_file = ""
        self.bgnoise_snr = 50
        self.dev_dly = float(31e-3)
        self.info = {}
        self.outdir = ""
        self.ptt_wait = 0.68
        self.ptt_gap = 3.1
        self.ri = None
        self.test = "1loc"
        self.trials = 100
        self.get_post_notes = None
        self.progress_update = terminal_progress_update
        self.rng = np.random.default_rng()
        self.save_tx_audio = True
        self.save_audio = True

        for k, v in kwargs.items():
            if hasattr(self, k):
                setattr(self, k, v)
            else:
                raise TypeError(f"{k} is not a valid keyword argument")

    def csv_header_fmt(self):
        """
        generate header and format for .csv files.

        This generates a header for .csv files along with a format (that can be
        used with str.format()) to generate each row in the .csv.

        Parameters
        ----------

        Returns
        -------
        hdr : string
            csv header string
        fmt : string
            format string for data lines for the .csv file
        """
        hdr = ",".join(self.data_fields.keys()) + "\n"
        fmt = "{" + "},{".join(self.data_fields.keys()) + "}\n"

        return (hdr, fmt)

    def load_audio(self):
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

        # check if we have an audio interface (running actual test)
        if self.audio_interface:
            # get sample rate, we'll use this later
            fs_test = self.audio_interface.sample_rate
        else:
            # set to none for now, we'll get this from files
            fs_test = None

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
                # check if we have a sample rate
                if not fs_test:
                    # no, set from file
                    fs_test = fs_file
                    # set audio
                    audio = audio_dat
                else:
                    # yes, resample to desired rate
                    rs_factor = Fraction(fs_test / fs_file)
                    audio = scipy.signal.resample_poly(audio_dat, rs_factor.numerator, rs_factor.denominator)
            else:
                # set audio
                audio = audio_dat

            # check if we are adding noise
            if self.bgnoise_file:

                # measure amplitude of signal and noise
                sig_level = active_speech_level(audio, self.audio_interface.sample_rate)
                noise_level = active_speech_level(nf, self.audio_interface.sample_rate)

                # calculate noise gain required to get desired SNR
                noise_gain = sig_level - (self.bgnoise_snr + noise_level)

                # set noise to the correct level
                noise_scaled = nf * (10 ** (noise_gain / 20))

                # add noise (repeated to audio file size)
                audio = audio + np.resize(noise_scaled, audio.size)

            # append audio to list
            self.y.append(audio)

        # check if we have an audio interface (running actual test)
        if not self.audio_interface:
            # create a named tuple to hold sample rate
            FakeAi = namedtuple("FakeAi", "sample_rate")
            # create a fake one
            self.audio_interface = FakeAi(sample_rate=fs_test)

    def param_check(self):
        """Check all input parameters for value errors"""

        if (self.test != "1loc") and (self.test != "2loc_tx") and (self.test != "2loc_rx"):
            raise ValueError(f"\n{self.test} is an incorrect test")

        if self.trials < 1:
            raise ValueError("\nTrials parameter needs to be more than 0")

        if self.ptt_wait < 0:
            raise ValueError("\nptt_wait parameter must be >= 0")

    def process_audio(self, clip_index, fname, rec_chans):
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
        
        fs, rec_dat = mcvqoe.base.audio_read(fname)

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
        (_, dly) = mcvqoe.delay.ITS_delay_est(self.y[clip_index], voice_dat, "f", fs=self.audio_interface.sample_rate)

        # ----------------------------[calculate M2E]----------------------------

        estimated_m2e_latency = dly / self.audio_interface.sample_rate

        # If not simulation, subtract device delay from M2E Latency
        # If a simulation, m2e latency will be whatever is loaded into device delay
        # TODO: Possibility this is ran while not in sim. Does that matter?
        if (estimated_m2e_latency == 0) or (estimated_m2e_latency == self.dev_dly):
            pass
        else:
            # Not a simulation, subtract device delay
            estimated_m2e_latency = estimated_m2e_latency - self.dev_dly

        # -----------------------------[Return Info]-----------------------------

        return {
            "m2e_latency": estimated_m2e_latency,
            "channels": mcvqoe.base.audio_channels_to_string(rec_chans),
        }
    
    def post_write(self, test_folder=""):
        """Overwrites measure class post_write() in order to print M2E results in
        tests.log
        """
        
        if self.get_post_notes:
            # get notes
            info = {}
            info.update(self.get_post_notes())
            eval_obj = evaluation.evaluate(test_names=self.data_filename)
            info["mean"], info["ci"] = eval_obj.eval()
        else:
            info = {}
            
        # finish log entry
        self.post(info=info, outdir=self.outdir, test_folder=test_folder)
        
    def post(self, info={}, outdir="", test_folder=""):
        """
        Take in a QoE measurement class info dictionary to write post-test to tests.log.
        Specific to M2E
        ...
    
        Parameters
        ----------
        info : dict
            The <measurement>.info dictionary.
        outdir : str
            The directory to write to.
        """
    
        # Add 'outdir' to tests.log path
        log_datadir = os.path.join(outdir, "tests.log")
        
        # Write to outer tests.log
        with open(log_datadir, "a") as file:
            if "Error Notes" in info:
                notes = info["Error Notes"]
                header = "===Test-Error Notes==="
            else:
                header = "===Post-Test Notes==="
                notes = info.get("Post Test Notes", "")
    
            # Write header
            file.write(header + "\n")
            # Write notes
            file.write("".join(["\t" + line + "\n" for line in notes.splitlines(keepends=False)]))
            # Write results
            file.write("===M2E Results===" + "\n")
            file.write("\t" + f"Mouth-To-Ear Latency Estimate: {info['mean']}, 95% Confidence Interval: " +
                       f'{np.array2string(info["ci"], separator=", ")} seconds' + "\n")
            # Write end
            file.write("===End Test===\n\n")
            
        # Add test's specific log file to folder if given
        if test_folder != "":
            
            # Add "test_folder" to tests.log path
            log_datadir = os.path.join(test_folder, "tests.log")
            
            # Write ending log entry into specific tests.log
            with open(log_datadir, "a") as file:
                if "Error Notes" in info:
                    notes = info["Error Notes"]
                    header = "===Test-Error Notes==="
                else:
                    header = "===Post-Test Notes==="
                    notes = info.get("Post Test Notes", "")
        
                # Write header
                file.write(header + "\n")
                # Write notes
                file.write("".join(["\t" + line + "\n" for line in notes.splitlines(keepends=False)]))
                # Write results
                file.write("===M2E Results===" + "\n")
                file.write("\t" + f"Mouth-To-Ear Latency Estimate: {info['mean']}, 95% Confidence Interval: " +
                           f'{np.array2string(info["ci"], separator=", ")} seconds' + "\n")
                # Write end
                file.write("===End Test===\n\n")