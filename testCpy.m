function testCpy(varargin)
% TESTCPY - copy test data to external drive
%
%   TESTCPY('DestDir',destDir,'CName',CompName,'SyncDir',sdir)   copies
%   	test data to destDir. The logs from this computer will be renamed
%   	to CompName-tests.log and stored in destDir. The sync script in
%   	sdir is used to copy the data.
%
%   TESTCPY() Same as above but the computer name and destination
%       information are read from a file saved by a previous run of TESTCPY
%       and the sync dir is assumed to be at the root of the drive where
%       destDiris located in the sync folder. The drive letter of the
%       destination is found using the disk serial number saved in the file
%       from the prevous run.
%
%   NAME                TYPE                DESCRIPTION
%
%   DestDir             char vector,string  Sync output directory. Test
%                                           files are coppied here as well
%                                           as logs.
%
%   OutDir              char vector,string  Test data output directory.
%                                           This is the directory where the
%                                           test stored data to be copied.
%                                           Defaults to the current
%                                           directory.
%
%   CName               char vector,string  The name to rename tests.log
%                                           to. The new name will be
%                                           CName-tests.log. If CName is
%                                           not given then it must have
%                                           been stored from the last run
%                                           of TESTCPY and if it is given
%                                           then it must be the same as the
%                                           stored value
%
%   SyncDir             char vector,string  Directory to find the sync.py
%                                           script in. On windows machines
%                                           this can be omitted if the sync
%                                           script is placed in the sync
%                                           folder of the root of the drive
%                                           that destDir is located on


%This software was developed by employees of the National Institute of
%Standards and Technology (NIST), an agency of the Federal Government.
%Pursuant to title 17 United States Code Section 105, works of NIST
%employees are not subject to copyright protection in the United States and
%are considered to be in the public domain. Permission to freely use, copy,
%modify, and distribute this software and its documentation without fee is
%hereby granted, provided that this notice and disclaimer of warranty
%appears in all copies.
%
%THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER
%EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY
%WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED
%WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
%FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
%CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
%FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
%LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
%OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
%WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
%OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
%WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
%USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.


    if(~ispc)
        %give warning for non windows
        warning('Nonwindows detected may not work correctly');
    end

    %create new input parser
    p=inputParser();

    %location to copy log file to
    addParameter(p,'DestDir',[],@(n)validateattributes(n,{'char','string'},{'scalartext'}));
    %add output data directory parameter
    addParameter(p,'OutDir','',@(n)validateattributes(n,{'char'},{'scalartext'}));
    %add Computer name parameter
    addParameter(p,'CName','',@(n)validateattributes(n,{'char'},{'scalartext'}));
    %add Sync Script directory parameter
    addParameter(p,'SyncDir','',@(n)validateattributes(n,{'char'},{'scalartext'}));
    %add dry run parameter
    addParameter(p,'DryRun',false,@(l)validateattributes(l,{'logical','numeric'},{'scalar'}));

    %parse inputs
    parse(p,varargin{:});

    %get git status
    git_status=gitStatus();

    %check if OutDir was given
    if(isempty(p.Results.OutDir))
        %use current directory
        OutDir=pwd();
    else
        %use OutDir parameter
        OutDir=p.Results.OutDir;
    end

    %filename for computer name
    comp_file=fullfile(OutDir,'ComputerName.txt');
    
    %filename for copy settings
    set_file=fullfile(OutDir,'CopySettings.json');

    %file name for input log file
    log_in_name=fullfile(OutDir,'tests.log');

    %get start time
    dt_start=datetime('now','Format','dd-MMM-yyyy_HH-mm-ss');

    if(exist(set_file,'file'))
        if(exist(comp_file,'file'))
            error('Found both ''%s'' and ''%s'' please delete one');
        end
        %read data from file
        file_dat=fileread(set_file);
        
        set_struct=jsondecode(file_dat);
        %TODO: error checking for struct fields
        
        drives=list_drives();
        %find the index of the drive in the array
        idx=strcmp(drives{:,'Serial'},set_struct.DriveSerial);
        
        %make sure drive was found
        if(~any(idx))
            error('Could not find drive with serial ''%s''',set_struct.DriveSerial);
        end
        
         dest_drive_prefix=drives.Row{idx};
        
    else
        %open computer name file
        cf=fopen(comp_file,'r');

        if(cf>=0)
            CName='';

            while(isempty(CName))
                %get a line from the file
                CName=fgetl(cf);

                %check if CName is numeric
                if(isnumeric(CName))
                    error('End of file reached, no computer name found');
                end

                %trim whitespace
                CName=strtrim(CName);
            end
            %close file
            fclose(cf);

            %check if CName parameter is not empty
            if(~isempty(p.Results.CName))
                %check to make sure they match
                if(~strcmp(CName,p.Results.CName))
                    error('CName does not match the name, ''%s'', in ''%s''',CName,comp_file);
                end
            end
        else
            CName=strtrim(p.Results.CName);
        end

        if(isempty(CName))
            error('Invalid computer name');
        end
        
        if(isempty(p.Results.DestDir))
            error('DestDir must be given if ''%s'' does not exist',set_file);
        end
        
        %split into parts
        dest_parts=regexp(p.Results.DestDir,'[\\/]','split');
        
        dest_drive_prefix=dest_parts{1};
        
        %check for drive letter
        [s,e]=regexp(dest_drive_prefix,'[A-Z]+:');
        
        if(s~=1 || e~=length(dest_parts{1}))
            error('Could not find drive letter in ''%s''',dest_drive_prefix);
        end
        
        %get serial number for drive
        drive_ser=drive_serial(dest_drive_prefix);
        
        %set drive relative path
        rel_path=fullfile(dest_parts{2:end});
       

        set_struct=struct('ComputerName',CName,'DriveSerial',drive_ser,'Path',rel_path); 
    end

    if(~p.Results.DryRun)
        %open settings file for writing
        sf=fopen(set_file,'w');
    else
        %write to stdout
        sf=1;
        %notify user
        fprintf('Writing to settings file ''%s'':\n',set_file);
    end

    if(sf>0)
        %write info in json format
        fwrite(sf,jsonencode(set_struct));
        
        if(~p.Results.DryRun)
            %close file
            fclose(sf);
        else
            %add a couple of newlines for spacing
            fprintf('\n\n');
        end

        %check if computer name file exists
        if(exist(comp_file,'file'))
            fprintf('Removing computer name file ''%s''\n',comp_file);
            if(~p.Results.DryRun)
                delete(comp_file);
            end
        end
    else
        warning('Unable to write settings file ''%s''',set_file);
    end
    
    
    %file name for output log file
    log_out_name=fullfile(dest_drive_prefix,set_struct.Path,[set_struct.ComputerName '-tests.log']);

    %check dirty status
    if(git_status.Dirty)
        %local edits, flag as dirty
        gitdty=' dty';
    else
        %no edits, don't flag
        gitdty='';
    end

    %get call stack info to extract current filename
    [ST, I] = dbstack('-completenames');
    %get current filename parts
    [~,n,e]=fileparts(ST(I).file);
    %full name of current file without path
    fullname=[n e];

    
    if(~p.Results.DryRun)
        %open log file to add log entry
        logf=fopen(log_in_name,'a+');
    else
        %write to stdout
        logf=1;
        %notify user
        fprintf('Writing to log file ''%s'':\n',log_in_name);
    end
    
    %set time format of start time
    dt_start.Format='dd-MMM-yyyy HH:mm:ss';
    %write start time, test type and git hash
    fprintf(logf,['\n>>Copy to %s at %s\n'...
                  '\tGit Hash    : %s%s\n'...
                  '\tfilename    : %s\n'],set_struct.ComputerName,char(dt_start),git_status.Hash,gitdty,fullname);
    %write system under test 
    fprintf(logf, '\tArguments   : %s\n',extractArgs(p,ST(I).file));
    %print input and output file names
    fprintf(logf,['\tInput File  : %s\n'...
                  '\tOutput File : %s\n'],log_in_name,log_out_name);
    %print end of test marker
    fprintf(logf,'===End Info===\n\n');
    
    
    if(~p.Results.DryRun)
        %close log file
        fclose(logf);
    end

    fin=fopen(log_in_name,'r');
    fout=fopen(log_out_name,'r');

    %check if input file was not opened
    if(fin<0)
        %check if output file was opened
        if(fout>0)
            fclose(fout);
        end
        %give error
        error('Could not open input log');
    end

    %check if output file was not opened
    if(fout<0)
        %close input file
        fclose(fin);
        
        if(~p.Results.DryRun)
            %no output file, just copy input
            stat=copyfile(log_in_name,log_out_name);
            %check if operation was successful
            if(~stat)
                %give error
                error('Could not copy file');
            end
        end
        %print success message
        fprintf('Log copied successfully to %s\n',log_out_name);
    else

        %initialize line number for error reporting
        lnum=0;

        while(true)
            %get a line from the files
            lin=fgetl(fin);
            lout=fgetl(fout);

            %increment line number
            lnum=lnum+1;

            %check for end of output file
            if(iseof(lout))
                %exit loop
                break;
            end

            %check for end of input file
            if(iseof(lin))
                %close files
                fclose(fin);
                fclose(fout);
                %give error
                error('Input file is shorter than output');
            end

            %compare lines
            if(~strcmp(lin,lout))
                %close files
                fclose(fin);
                fclose(fout);
                %give error
                error('Files differ at line %d, can not copy',lnum);
            end
        end

        %close output file
        fclose(fout);

        if(~p.Results.DryRun)
            %reopen for writing
            fout=fopen(log_out_name,'a+');

            %check if file was opened
            if(fout<0)
                %close input file
                fclose(fin);
                %give error
                error('Unable to open output file for writing');
            end
        else
            %write to stdout
            fout=1;
            %notify user
            fprintf('Writing new lines to log file ''%s''\n',log_out_name);
        end
            

        %initialize line count for reporting
        lnum=0;

        while(~iseof(lin))
            %write line to file
            fprintf(fout,'%s\n',lin);
            %get next line
            lin=fgetl(fin);
            %increment line number
            lnum=lnum+1;
        end

        %print line count
        fprintf('%d lines copied\n',lnum);

        %close files
        fclose(fin);
        
        if(~p.Results.DryRun)
            fclose(fout);
        end

        %print success message
        fprintf('Log updated successfully to %s\n',log_out_name);
    end

    if(isempty(p.Results.SyncDir))
        %use drive letter to create sync path
        SyncDir=fullfile(dest_drive_prefix,'sync');
    else
        SyncDir=p.Results.SyncDir;
    end

    %get path to sync script
    SyncScript=fullfile(SyncDir,'sync.py');

    %check if sync script exists
    if(~exist(SyncScript,'file'))
        %give error
        error('Sync script not found at ''%s''',SyncScript);
    end    

    %compose sync command
    syncCmd=sprintf('python %s --import "%s" "%s" --cull',SyncScript,OutDir,p.Results.DestDir);

    if(~p.Results.DryRun)
        stat=system(syncCmd,'-echo');

        %check if status is not ok
        if(stat~=0)
            error('Failed to run sync script. exit status %i',stat)
        end
    else
        fprintf('Calling sync command:\n\t''%s''\n',syncCmd);
    end

end
   
%function to determine if result from fgetl indicates end of file
function res=iseof(s)
    %check if s is numeric and -1
    if(isnumeric(s) && s==-1)
        %yes, return true for end of line
        res=true;
    else
        %return false for not end of line
        res=false;
    end
end
    
function serial=drive_serial(dname)

    [code,info]=system(['vol ',dname]);

    %check for error
    if(code)
        %check if drive is not ready
        if(contains(info,'The device is not ready','IgnoreCase',true))
            error('Device is not ready');
        else
            %otherwise throw error
            error('Could not get volume info vol returned %d',code);
        end
    end

    %find drive serial number
    [~,~,m]=regexp(info,'Volume Serial Number is\W*((?:\w+-?)+)');

    if(~isempty(m))
        serial=info(m{1}(1,1):m{1}(1,2));
    end

end

function drive_table=list_drives()
    
    %list all drives on the system
    [code,out]=system('wmic logicaldisk get name');
    
    %check for error
    if(code)
        error('Command returned %d',code);
    end
    %split out lines to cell arrays
    drives=strtrim(strsplit(strtrim(out),newline));
    %drop header
    drives=drives(2:end);

    %preallocate!
    label=cell(size(drives));
    serial=cell(size(drives));

    for k=1:length(drives)
        %get info on drive
        [code,info]=system(['vol ',drives{k}]);
        
        %check for error
        if(code)
            %check if drive is not ready
            if(contains(info,'The device is not ready','IgnoreCase',true))
                %drive is not ready, skip
                label{k}='';
                serial{k}='';
                continue;
            else
                %otherwise throw error
                error('command returned %d for drive ''%s''',code,drives{k});
            end
        end
        
        %find drive label
        [~,e,m]=regexp(info,[drives{k}(1:end-1) '\W*(\w+)\W*([^\n]+)']);

        %check if found
        if(~isempty(m))
            sep=info(m{1}(1,1):m{1}(1,2));
            if(strcmp(sep,'is'))
                label{k}=info(m{1}(2,1):m{1}(2,2));
            else
                label{k}='';
            end
            %remove drive lable line from string
            ser_string=info((e+2):end);
            %find drive serial number
            [~,~,m]=regexp(ser_string,'Volume Serial Number is\W*((?:\w+-?)+)');

            if(~isempty(m))
                serial{k}=ser_string(m{1}(1,1):m{1}(1,2));
            end
        end

    end

    %create table
    drive_table=table(label',serial','RowNames',drives,'VariableNames',{'Label','Serial'});
end        