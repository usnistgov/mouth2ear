#!/usr/bin/env python

import argparse
import csv
import mcvqoe
import os.path
import scipy.io.wavfile
import sys
import tempfile

from .m2e import measure
    
def main():
    #---------------------------[Create Test object]---------------------------

    #create object here to use default values for arguments
    test_obj=measure()

    #-----------------------[Setup ArgumentParser object]-----------------------
    
    parser = argparse.ArgumentParser(
        description=__doc__)
    parser.add_argument('datafile', default=None,type=str,
                        help='CSV file from test to reprocess')
    parser.add_argument('outfile', default=None, type=str, nargs='?',
                        help='file to write reprocessed CSV data to. Can be the same name as datafile to overwrite results. if omitted output will be written to stdout')
    parser.add_argument('--audio-path',type=str,default=None,metavar='P',dest='audio_path',
                        help='Path to audio files for test. Will be found automatically if not given')
                                                              
    #-----------------------------[Parse arguments]-----------------------------

    args = parser.parse_args()
    
    with tempfile.TemporaryDirectory() as tmp_dir:
        
        if(args.outfile=='--'):
            #print results, don't save file
            out_name=os.path.join(tmp_dir,'tmp.csv')
            print_outf=True
        elif(args.outfile):
            out_name=args.outfile
            print_outf=False
        else:
            #split data file path into parts
            d,n=os.path.split(args.datafile)
            #construct new name for file
            out_name=os.path.join(d,'R'+n)
            print_outf=False

        print(f'Loading test data from \'{args.datafile}\'',file=sys.stderr)
        #read in test data
        test_dat=test_obj.load_test_data(args.datafile,audio_path=args.audio_path)

        print(f'Reprocessing test data to \'{out_name}\'',file=sys.stderr)
            
        test_obj.post_process(test_dat,out_name,test_obj.audio_path)
            
        if(print_outf):
            with open(out_name,'rt') as out_file:
                dat=out_file.read()
            print(dat)
            
        print(f'Reprocessing complete for \'{out_name}\'',file=sys.stderr)

#main function 
if __name__ == "__main__":
    main()