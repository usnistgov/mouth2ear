#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  16 01:46:20 2021

@author: wrm3
"""
import argparse

import numpy as np
import pandas as pd


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

        # Initialize attributes
        self.full_paths = [test_path + test_name for test_name in test_names]
        self.mean = None
        self.ci = None
        self.common_thinning = None

        # Check for kwargs
        for k, v in kwargs.items():
            if hasattr(self, k):
                setattr(self, k, v)
            else:
                raise TypeError(f"{k} is not a valid keyword argument")

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
        thinning_info = {}
        for session in self.full_paths:
            current_session = pd.read_csv(session)
            for k in range(1, len(current_session["m2e_latency"])):
                # check for autocorrelation
                acorr = improved_autocorrelation(
                    current_session['m2e_latency'][::k])
                if not (len(acorr) > 1):
                    thinning_info[session] = k
        self.common_thinning = max(thinning_info.values())

        mean_cum = 0
        thinned_data = {}

        for session in self.full_paths:
            current_session = pd.read_csv(session)
            # Thin data
            current_session = current_session[::self.common_thinning]
            mean_cum += np.mean(current_session["m2e_latency"])
            thinned_data[session] = current_session["m2e_latency"]

        self.mean = mean_cum/len(self.full_paths)
        self.ci = bootstrap_datasets_ci(*thinned_data.values())

        return (self.mean, self.ci)


# Auxillary function definitions
def improved_autocorrelation(x):
    """
    Detect lags at which there is likely autocorrelation.

    Determined according to the improved bounds given in 'Zhang NF (2006)
    Calculation of the uncertainty of the mean of autocorrelated measurements'.

    Parameters
    ----------
    x : numpy array
        Numerical data on which to detect autocorrelation.

    Returns
    -------
    numpy array
        Array of indices for lags where this is likely autocorrelation.

    """
    # Calculate sample autocorrelation estimate
    N = len(x)
    corrs = np.zeros(N)
    m = np.mean(x)
    d = x - m
    for ii in range(N):
        corrs[ii] = np.sum(d[ii:] * d[:(N-ii)])
    corrs = corrs/corrs[0]

    # Respective uncertainties
    sigmas = np.zeros(N)
    sigmas[0] = 1/np.sqrt(N)
    for ii in range(1, N):
        sigmas[ii] = np.sqrt((1 + 2 * np.sum(corrs[:ii]**2))/N)

    return np.argwhere(np.abs(corrs) > 1.96 * sigmas)


def bootstrap_datasets_ci(*datasets, R=int(1e4), alpha=0.5):
    """
    Bootstrap for averaging means from different datasets.

    Parameters
    ----------
    *datasets : numpy arrays
        Datasets from which to take sample means. In context, the datasets
        are the different M2E sessions within a test.
    R : int, optional
        Number of resamples. The default is int(1e4).
    alpha : float, optional
        Alpha level of the test. The default is 0.5.

    Returns
    -------
    ci : numpy array
        Two element array containing the upper and lower confidence bound on
        the mean.

    """
    ds = datasets
    N = len(ds[0])
    x_bars = np.zeros((len(ds), R))
    for ii, dataset in enumerate(ds):
        rs = np.random.choice(dataset, size=(N, R))
        x_bar = np.mean(rs, axis=0)
        x_bars[ii, :] = x_bar
    # Means across sessions
    x_bar_dist = np.mean(x_bars, axis=1)
    # percentiles
    ql = alpha/2
    qu = 1 - ql
    ci = np.quantile(x_bar_dist, [ql, qu])
    return ci


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
