#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  16 01:46:20 2021

@author: wrm3
"""
import argparse
import json
import os
import warnings

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go


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
                 test_names=None,
                 test_path='',
                 use_reprocess=False,
                 json_data=None,
                 **kwargs):
        if json_data is None:
            # If only one test, make a list for iterating
            if isinstance(test_names, str):
                test_names = [test_names]
            
            # Initialize full paths attribute
            self.full_paths = []
            self.test_names = []
            for test_name in test_names:
                # If no extension given use csv
                dat_path, name = os.path.split(test_name)
                fname, fext = os.path.splitext(test_name)
                
                if not dat_path and not fext == '.csv':
                    # generate using test_path
                    dat_path = os.path.join(test_path, 'csv')
                    dat_file = os.path.join(dat_path, fname + '.csv')
                else:
                    dat_file = test_name
                
                self.full_paths.append(dat_file)
                self.test_names.append(os.path.basename(fname))
    
            # Initialize attributes
            data =[]
            for path, name in zip(self.full_paths, self.test_names):
                df = pd.read_csv(path)
                # Force timestamp to be datetime
                df['Timestamp'] = pd.to_datetime(df['Timestamp'])
                df['name'] = name
                data.append(df)
            self.data = pd.concat(data, ignore_index=True)
            
        else:
            self.data, self.test_names, self.full_paths = evaluate.load_json_data(json_data)
        
        self.common_thinning = self.find_thinning_factor()
        
        self.thinned_data = self.thin_data()
        
        # Check for kwargs
        for k, v in kwargs.items():
            if hasattr(self, k):
                setattr(self, k, v)
            else:
                raise TypeError(f"{k} is not a valid keyword argument")
        
        self.mean, self.ci = self.eval()
    
    def to_json(self, filename=None):
        """
        Create json representation of m2e data

        Parameters
        ----------
        filename : str, optional
            If given save to json file. Otherwise returns json string. The default is None.

        Returns
        -------
        None.

        """
        test_info = {}
        for tname, tpath in zip(self.test_names, self.full_paths):
            test_info[tname] = tpath
        
        out_json = {
            'measurement': self.data.to_json(),
            'test_info': test_info,
            # 'test_names': self.test_names,
            # 'test_paths': self.full_paths,
                }
        
        # Final json representation of all data
        final_json = json.dumps(out_json)
        if filename is not None:
            with open(filename, 'w') as f:
                json.dump(out_json, f)
        
        return final_json
    
    @staticmethod
    def load_json_data(json_data):
        """
        Do all data loading from input json_data

        Parameters
        ----------
        json_data : TYPE
            DESCRIPTION.

        Returns
        -------
        test_names : list
            DESCRIPTION.
        test_paths : dict
            DESCRIPTION.
        data : pd.DataFrame
            DESCRIPTION.
        cps : dict
            DESCRIPTION.

        """
        # TODO: Should handle correction data too!
        if isinstance(json_data, str):
            json_data = json.loads(json_data)
        # Extract data, cps, and test_info from json_data
        data = pd.read_json(json_data['measurement'])
        
        test_info = json_data['test_info']
        
        test_names = []
        test_paths = []
        for tname, tpath in test_info.items():
            test_names.append(tname)
            test_paths.append(tpath)
        # test_names = json_data['test_names']
        # test_paths = json_data['test_paths']
        
        
        # Return normal Access data attributes from these
        return data, test_names, test_paths, 
        
    
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
            thinning_factor = np.nan
        return thinning_factor
        
    def thin_data(self):
        """
        Thin data by common thinning factor

        Returns
        -------
        thinned_data : TYPE
            DESCRIPTION.

        """
        if np.isnan(self.common_thinning):
            thin = 1
        else:
            thin = self.common_thinning
        
        thinned_data = []
        for name in self.test_names:
            fdata = self.data[self.data['name'] == name]
            tdata = fdata[::thin]
            
            thinned_data.append(tdata)
        
        return pd.concat(thinned_data)
    
    
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
    
    def filter_data(self, df, test_name, talkers):
        # Filter by session name if given
        if test_name is not None:
            df_filt = []
            if not isinstance(test_name, list):
                test_name = [test_name]
            for name in test_name:
                df_filt.append(df[df['name'] == name])
            df = pd.concat(df_filt)
        # Filter by talkers if given
        if talkers is not None:
            df_filt = []
            if isinstance(talkers, str):
                talkers = [talkers]
            for talker in talkers:
                df_filt.append(df[df['Filename'] == talker])
            df = pd.concat(df_filt)
        return df
    
    def histogram(self, thinned=True, test_name=None, talkers=None,
                  color_palette=px.colors.qualitative.Plotly,
                  title='Histogram of mouth-to-ear latency results'):
        if not thinned:
            df = self.data
        else:
            df = self.thinned_data
        
        df = self.filter_data(df, test_name=test_name, talkers=talkers)
        
        fig = px.histogram(df, x='m2e_latency', color='name',
                           labels={
                               'm2e_latency': 'Mouth-to-ear latency [s]',
                               },
                           title=title,
                           color_discrete_sequence=color_palette,
                           )
        fig.add_vline(x=self.mean, line_width=3, line_dash="dash")
        fig.add_vline(x=self.ci[0], line_width=2, line_dash="dot")
        fig.add_vline(x=self.ci[1], line_width=2, line_dash="dot")
        
        fig.add_annotation(xref='x', yref='paper',
                           x=self.mean, y=0.9,
                           text="Mean and confidence interval",
                           showarrow=True,
                           xanchor='right',
                           )

        fig.update_layout(
            legend=dict(
                orientation="h",
                xanchor="center",
                y=-0.2,
                x=0.5,
                ),
            )
        return fig
    
    def plot(self, thinned=True, test_name=None, x=None, talkers=None,
             color_palette=px.colors.qualitative.Plotly,
             title='Mouth-to-ear latency scatter plot'):
        
        # Grab thinned or unthinned data
        if not thinned:
            df = self.data
        else:
            df = self.thinned_data
        
        df = self.filter_data(df, test_name=test_name, talkers=talkers)
        
        # Set x-axis value
        if x is None:
            x = df.index
        
        fig = px.scatter(df, x=x, y='m2e_latency',
                         color='name',
                         symbol='Filename',
                         labels={
                             'm2e_latency': 'Mouth-to-ear latency [s]',
                             'index': 'Trial Number',
                             },
                         title=title,
                         color_discrete_sequence=color_palette,
                         )
        
        fig.update_layout(legend=dict(
            orientation="h",
            xanchor="center",
            y=-0.2,
            x=0.5,
            ),
        )
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

    args = parser.parse_args()
    t = evaluate(args.test_names, test_path=args.test_path,
                 use_reprocess=args.no_reprocess)

    res = t.eval()

    print(res)

    return(res)


if __name__ == "__main__":
    main()
