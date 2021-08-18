#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  16 01:46:20 2021

@author: wrm3
"""
import os
import warnings
import argparse

import numpy as np
import pandas as pd

import mcvqoe.math
import mcvqoe.simulation


# Main class for evaluating
class evaluate():
    """Class to evaluate Probability of Successful Delivery tests."""

    def __init__(self,
                 test_names,
                 test_path='',
                 **kwargs):
        # If only one test, make a list for iterating
        if isinstance(test_names, str):
            test_names = [test_names]

        # Initialize attributes
        self.thinning_data = {}
        self.full_paths = [test_path + test_name for test_name in test_names]
        self.test_info = {}

        # Check for kwargs
        for k, v in kwargs.items():
            if hasattr(self, k):
                setattr(self, k, v)
            else:
                raise TypeError(f"{k} is not a valid keyword argument")

    def eval(self):
        """
        ASDF.

        Parameters
        ----------
        threshold : TYPE
            DESCRIPTION.
        msg_len : TYPE
            DESCRIPTION.
        p : TYPE, optional
            DESCRIPTION. The default is 0.95.
        R : TYPE, optional
            DESCRIPTION. The default is 1e4.
        method : TYPE, optional
            DESCRIPTION. The default is "EWC".
        method_weight : TYPE, optional
            DESCRIPTION. The default is None.

        Returns
        -------
        None.

        """
        # Stats buffers
        means = []
        cis = []
        ks = []

        for test in self.full_paths:
            current_test = pd.read_csv(test)
            thinning_info = {}
            for k in range(1, len(current_test["m2e_latency"])):
                # check for autocorrelation
                acorr = improved_autocorrelation(current_test['m2e_latency'][::k])
                thinning_info[k] = acorr
                if not (len(acorr) > 1):
                    means.append(np.mean(current_test['m2e_latency'][::k]))
                    cis.append(mcvqoe.math.bootstrap_ci(current_test['m2e_latency'][::k])[0])
                    ks.append(k)
                    break

        data = {
            "Test": self.full_paths,
            "Thinning": ks,
            "Mean": means,
            "CI": cis}
        data = pd.DataFrame(data)

        return data


# Auxillary function definitions
def improved_autocorrelation(x):
    """Adsf."""
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


# Main definition
def main():
    """
    Evaluate M2E Latency with command line arguments.

    Returns
    -------
    None.

    """
    t = evaluate(
        [
            "capture_Simulation_17-Aug-2021_11-36-54.csv",
            "capture_Simulation_17-Aug-2021_11-24-52.csv"
            ],
        "C:/Users/wrm3/MCV-QoE/Mouth_2_Ear/data/csv/"
        )

    return(t.eval())


if __name__ == "__main__":
    main()
