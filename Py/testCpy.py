#!/usr/bin/env python

import os
import sys
import platform
import json
import re
import subprocess
import argparse

if platform.system()=='Windows':
    
    def get_drive_serial(drive):
        #run vol command, seems that you need shell=True. Perhaps vol is not a real command?
        result=subprocess.run(f'vol {drive}',shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        
        #check return code
        if(result.returncode):
            info=result.stderr.decode('UTF-8')
            
            if('the device is not ready' in info.lower()):
                raise RuntimeError('Device is not ready')
            else:
                raise RuntimeError(f'Could not get volume info vol returnd {res.returncode} \'{info.strip()}\'')
        
        #find drive serial number
        m=re.search('^\W*Volume Serial Number is\W*(?P<ser>(?:\w+-?)+)',result.stdout.decode('UTF-8'),re.MULTILINE)

        if(m):
            return m.group('ser')
        else:
            raise RuntimeError('Serial number not found')
        
    def list_drives():
        
        result=subprocess.run(['wmic','logicaldisk','get','name'],stdout=subprocess.PIPE)
        
        if(result.returncode):
            raise RuntimeError('Unable to list drives')
            
        drive_table=[]
            
        for line in result.stdout.decode('UTF-8').splitlines():
            #look for drive in line
            m=re.match('\A\s*(?P<drive>[A-Z]:)\s*$',line)
            #if there was a match
            if(m):
                res=subprocess.run(f'vol {m.group("drive")}',shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                
                if(res.returncode):
                    info=res.stderr.decode('UTF-8')
                    
                    if('the device is not ready' in info.lower()):
                        #drive is not ready, skip
                        continue
                    else:
                        raise RuntimeError(f'command returnd {res.returncode} for drive \'{m.group("drive")}\' \'{info.strip()}\'')
                
                #find drive label
                m_label=re.search(m.group('drive').rstrip(':')+'\W*(?P<sep>\w+)\W*(?P<label>.*?)\W*$',res.stdout.decode('UTF-8'),re.MULTILINE)
                
                if(m_label):
                    #dictionary with serial and label
                    info={'drive' : line.strip()}
                    #check if we got a label
                    if(m_label.groups('sep') == 'is'):
                        info['label']=m_label.groups('label')
                    else:
                        info['label']=''
                    
                    m_ser=re.search('^\W*Volume Serial Number is\W*(?P<ser>(?:\w+-?)+)',res.stdout.decode('UTF-8'),re.MULTILINE)
                    
                    if(m_ser):
                        info['serial']=m_ser.group('ser')
                    else:
                        info['serial']=''
                    
                    drive_table.append(info)
        
        return tuple(drive_table)
else:
    raise RuntimeError('Only Windows is supported at this {time')





#main function 
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__)
    parser.add_argument(
                        '-d', '--dest-dir', default=None,type=str,metavar='DIR',dest='destDir',
                        help='Path to store files on removable drive')
    parser.add_argument('-o', '--outdir', default='', metavar='DIR',
                        help='Directory where test output data is stored')
    parser.add_argument("-c", "--computer-name", default=None,metavar='CNAME',dest='cname',
                        help="computer name for log file renaming")
    parser.add_argument('-s', '--sync-directory', default=None,metavar='SZ',dest='syncDir',
                        help='Directory on drive where sync script is stored')
    parser.add_argument('-D', '--dry-run', action='store_true', default=False,dest='dryRun',
                        help='Go through all the motions but, don\'t copy any files')
    parser.add_argument('-f', '--force', action='store_true', default=False,
                        help='overwrite config files with values from arguments')
                        
    #parse arguments
    args = parser.parse_args()
    
    if( args.outdir ):
        OutDir=os.getcwd()
    else:
        OutDir=args.outdir
        
    set_file=os.path.join(OutDir,'CopySettings.json')
    
    log_in_name=os.path.join(OutDir,'tests.log')
    
    if(os.path.exists(set_file)):
        
        with open(set_file,'rt') as fp_set:
            set_dict=json.load(fp_set)
    
        drives=list_drives()
        
        drive_info=next((item for item in drives if item["serial"] == set_dict['DriveSerial']),None)
        
        if(not drive_info):
            raise RuntimeError(f'Could not find drive with serial {set_dict["DriveSerial"]}')
            
        #create drive prefix, add slash for path concatenation
        dest_drive_prefix=drive_info['drive']+os.sep
    else:
        if(not args.cname):
            raise RuntimeError(f'--computer-name not given and \'{set_file}\' does not exist')
        
        if(not args.destDir):
            raise RuntimeError(f'--dest-dir not given and \'{set_file}\' does not exist')
            
        #TODO : check for questionable names in path
        
        #split drive from path
        (dest_drive_prefix,rel_path)=os.path.splitdrive(args.destDir)
        
        #get serial number for drive
        drive_ser=get_drive_serial(dest_drive_prefix)
        
        #add slash for path concatenation
        dest_drive_prefix=dest_drive_prefix+os.sep
        
        #create dictionary of options, normalize paths
        set_dict={'ComputerName' : os.path.normpath(args.cname),'DriveSerial' : drive_ser,'Path' : os.path.normpath(rel_path)}
        
    with (os.fdopen(os.dup(sys.stdout.fileno()), 'w') if args.dryRun else open(set_file, 'w')) as sf:
        if(args.dryRun):
            print('Settings file:')
        json.dump(set_dict,sf)
    
    #file name for output log file
    log_out_name=os.path.join(dest_drive_prefix,set_dict['Path'],set_dict['ComputerName']+'-tests.log')
    
    #TODO : log things
        
        
    with open(log_in_name,'rt') as fin:
        if(os.path.exists(log_out_name)):
            with open(log_out_name,'rt') as fout:
                
                for line, (lin,lout) in enumerate(zip(fin,fout),start=1):
                    if(lin != lout):
                        raise RuntimeError(f'Files differ at line {line}, can not copy')
                
                #get the remaining data in the file
                out_dat=fout.read()
        else:
            if(not args.dryRun):
                #make sure that path to log file exists
                os.makedirs(os.path.dirname(log_out_name),exist_ok=True)
            #no in_dat
            in_dat=None
            
        #get remaining data in input file
        in_dat=fin.read()
                
        #check if we have more data from the input file 
        if(in_dat):
            
            #with open(log_out_name,'at') as fout:
            with (os.fdopen(os.dup(sys.stdout.fileno()), 'w') if args.dryRun else open(log_out_name,'at')) as fout:
                fout.write(in_dat)
                
            print(f'{len(in_dat.splitlines())} lines copied')
            
        else:
            if(out_dat):
                raise RuntimeError('Input file is shorter than output')
            else:
                print('Log files are identical, no lines copied')
                
    
    #print success message
    print(f'Log updated successfully to {log_out_name}\n')
    
    if(args.syncDir):
        syncDir=args.syncDir
    else:
        syncDir=os.path.join(dest_drive_prefix,'sync')
    
    print('Prefix : '+dest_drive_prefix)
    
    #create destination path
    destDir=os.path.join(dest_drive_prefix,set_dict['Path']);
        
    SyncScript=os.path.join(syncDir,'sync.py')
    
    if(not os.path.exists(SyncScript)):
        raise RuntimeError(f'Sync script not found at \'{SyncScript}\'')
        
    syncCmd=['python',SyncScript,'--import',OutDir,destDir,'--cull']
    
    if(args.dryRun):
        print('Calling sync command:\n\t'+' '.join(syncCmd))
    else:
        stat=subprocess.run(syncCmd)
        
        if(stat.returncode):
            raise RuntimeError(f'Failed to run sync script exit status {stat.returncode}')
    
    