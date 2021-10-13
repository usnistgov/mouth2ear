#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  16 01:46:20 2021

@author: wrm3
"""
import argparse
import os
import warnings

import numpy as np
import pandas as pd
import plotly.express as px

import mcvqoe.math


# Main class for evaluating
class evaluate():
    """
    Class to evaluate mouth to ear lataency time.

    Parameters
    ----------
    test_names : str or list of str
        File names of M2E seessions part of a test.

    test_path : str
        Full path to the directory containing the sessions within a test.

    use_reprocess : bool
        Whether or not to use reprocessed data, if it exists.

    Attributes
    ----------
    full_paths : list of str
        Full file paths to the sessions.

    mean : float
        Average of all the means of the thinned session data part of the test.

    ci : numpy array
        Lower and upper confidence bound on the mean.

    common_thinning : int
        The largest thinning factor among the sessions.

    Methods
    -------
    eval()
        Determine the mouth to ear latency of a test.

    See Also
    --------
        mcvqoe.m2e.measure : Measurement class for generating M2E data.
    """

    def __init__(self,
                 test_names,
                 test_path='',
                 use_reprocess=False,
                 **kwargs):
        # If only one test, make a list for iterating
        if isinstance(test_names, str):
            test_names = [test_names]
        
        # Initialize full paths attribute
        self.full_paths = []
        self.test_names = []
        for test_name in test_names:
            # If no extension given use csv
            fname, fext = os.path.splitext(test_name)
            if fext == '':
                tname = fname + '.csv'
            else:
                tname = fname + fext
            fpath = os.path.join(test_path, 'csv', tname)
            self.full_paths.append(fpath)
            self.test_names.append(os.path.basename(fname))

        # Initialize attributes
        self.data = pd.DataFrame()
        for path, name in zip(self.full_paths, self.test_names):
            df = pd.read_csv(path)
            df['name'] = name
            self.data = self.data.append(df)
        self.mean = None
        self.ci = None
        self.common_thinning = self.find_thinning_factor()

        self.thinned_data = pd.DataFrame()
        for name in self.test_names:
            fdata = self.data[self.data['name'] == name]
            tdata = fdata[::self.common_thinning]
            
            self.thinned_data = self.thinned_data.append(tdata)
            # self.thinned_data.append(data["m2e_latency"][::self.common_thinning])
        
        # Check for kwargs
        for k, v in kwargs.items():
            if hasattr(self, k):
                setattr(self, k, v)
            else:
                raise TypeError(f"{k} is not a valid keyword argument")
    
    def find_thinning_factor(self):
        """
        Determine common thinning factor for data that removes autocorrelation.

        Returns
        -------
        int:
            Thinning factor that removes autocorrelation.

        """
        # get common thinning factor
        thinning_factor = 1
        # TODO: Make this more robust for data sets of different sizes rather than
        # Limiting to smallest data set
        sesh_counts = [np.sum(self.data['name'] == name) for name in self.test_names]
        max_lag = np.min([np.floor(N/4) for N in sesh_counts])
        
        is_lag = True
        
        while is_lag and thinning_factor <= max_lag:
            # Initialize list of lags for each data set
            lags = []
            
            for name in self.test_names:
                # Filter by session
                filt_dat = self.data[self.data['name'] == name]
                # Thin data and calculate autocorrelation
                thin_dat = filt_dat["m2e_latency"][::thinning_factor]
                autocorr_lags = mcvqoe.math.improved_autocorrelation(thin_dat)
                
                # Lag 0 always present, store if more than that
                lagged = len(autocorr_lags) > 1
                lags.append(lagged)
            if not any(lags):
                is_lag = False
            else:
                thinning_factor += 1
        if is_lag:
            warnings.warn("No common thinning factor found ")
        return thinning_factor
        
        
    def eval(self):
        """
        Evaluate mouth to ear test data provided.

        Returns
        -------
        float
            Mean of test data.
        numpy array
            Upper and lower confidence bound on the mean of the test data.

        """
        # get common thinning factor for all sessions. take the max
        # thinning_info = {}
        # for session in self.full_paths:
        #     current_session = pd.read_csv(session)
        #     for k in range(1, len(current_session["m2e_latency"])):
        #         # check for autocorrelation
        #         acorr = mcvqoe.math.improved_autocorrelation(
        #             current_session['m2e_latency'][::k])
        #         if not (len(acorr) > 1):
        #             thinning_info[session] = k
        # self.common_thinning = max(thinning_info.values())

        
        mean_cum = 0
        
        ci_dsets = []
        for name in self.test_names:
            thin_data = self.thinned_data[self.thinned_data['name'] == name]
            m2e_vals = thin_data['m2e_latency']
            ci_dsets.append(m2e_vals)
            mean_cum += np.mean(m2e_vals)

        self.mean = mean_cum/len(self.test_names)
        
        
        self.ci = mcvqoe.math.bootstrap_datasets_ci(*ci_dsets)

        return (self.mean, self.ci)
    
    def histogram(self, thinned=True, test_name=None):
        # TODO: Do this for each session
        if not thinned:
            df = self.data
        else:
            df = self.thinned_data
        fig = px.histogram(df, x='m2e_latency', color='name')
        return fig
    
    def plot(self, thinned=True, test_name=None, x=None):
        # Grab thinned or unthinned data
        if not thinned:
            df = self.data
        else:
            df = self.thinned_data
        # Filter by session name if given
        if test_name is not None:
            df_filt = pd.DataFrame()
            if not isinstance(test_name, list):
                test_name = [test_name]
            for name in test_name:
                df_filt = df_filt.append(df[df['name'] == name])
            df = df_filt
        # Set x-axis value
        if x is None:
            x = df.index
        fig = px.scatter(df, x=x, y='m2e_latency',
                         color='name')
        return fig


# Main definition
def main():
    """
    Evaluate M2E Latency with command line arguments.

    Returns
    -------
    None.

    """
    # Set up argument parser
    parser = argparse.ArgumentParser(description=__doc__)

    parser.add_argument('test_names',
                        type=str,
                        nargs="+",
                        action="extend",
                        help=("Test names (same as name of folder for wav"
                              "files)"))
    parser.add_argument('-p', '--test-path',
                        default='',
                        type=str,
                        help=("Path where test data is stored. Must contain"
                              "wav and csv directories."))
    parser.add_argument('-n', '--no-reprocess',
                        default=True,
                        action="store_false",
                        help="Do not use reprocessed data if it exists.")

    # t = evaluate(
    #     [
    #         "capture_Simulation_17-Aug-2021_11-36-54.csv",
    #         "capture_Simulation_17-Aug-2021_11-24-52.csv"
    #         ],
    #     "C:/Users/wrm3/MCV-QoE/Mouth_2_Ear/data/csv/"
    #     )

    args = parser.parse_args()
    t = evaluate(args.test_names, test_path=args.test_path,
                 use_reprocess=args.no_reprocess)

    res = t.eval()

    print(res)

    return(res)


if __name__ == "__main__":
    main()
