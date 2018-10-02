function testCpy(destDir,varargin)

%create new input parser
p=inputParser();

%location to copy log file to
addRequired(p,'DestDir',@(n)validateattributes(n,{'char','string'},{'scalartext'}));
%add output data directory parameter
addParameter(p,'OutDir','',@(n)validateattributes(n,{'char'},{'scalartext'}));
%add Computer name parameter
addParameter(p,'CName','',@(n)validateattributes(n,{'char'},{'scalartext'}));
%add Sync Script directory parameter
addParameter(p,'SyncDir','',@(n)validateattributes(n,{'char'},{'scalartext'}));

%parse inputs
parse(p,destDir,varargin{:});

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

%file name for input log file
log_in_name=fullfile(OutDir,'tests.log');

%get start time
dt_start=datetime('now','Format','dd-MMM-yyyy_HH-mm-ss');

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

%open computer name file for writing
cf=fopen(comp_file,'w');

if(cf>0)
    %write name
    fprintf(cf,'%s\n',CName);
    %close file
    fclose(cf);
else
    warning('Unable to write computer name file ''%s''',comp_file);
end

%file name for output log file
log_out_name=fullfile(p.Results.DestDir,[CName '-tests.log']);

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

%open log file to add log entry
logf=fopen(log_in_name,'a+');
%set timeformat of start time
dt_start.Format='dd-MMM-yyyy HH:mm:ss';
%write start time, test type and git hash
fprintf(logf,['\n>>Copy to %s at %s\n'...
              '\tGit Hash    : %s%s\n'...
              '\tfilename    : %s\n'],CName,char(dt_start),git_status.Hash,gitdty,fullname);
%write system under test 
fprintf(logf, '\tArguments   : %s\n',extractArgs(p,ST(I).file));
%print input and output file names
fprintf(logf,['\tInput File  : %s\n'...
              '\tOutput File : %s\n'],log_in_name,log_out_name);
%print end of test marker
fprintf(logf,'===End Info===\n\n');
%close log file
fclose(logf);

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
    %no output file, just copy input
    stat=copyfile(log_in_name,log_out_name);
    %check if opperation was successful
    if(~stat)
        %give error
        error('Could not copy file');
    end
    %print success message
    fprintf('Log coppied successfully to %s\n',log_out_name);
else

    %initalize line number for error reporting
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
    
    %reopen for writing
    fout=fopen(log_out_name,'a+');
    
    %check if file was opened
    if(fout<0)
        %close input file
        fclose(fin);
        %give error
        error('Unable to open output file for writing');
    end
    
    %initalize line count for reporting
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
    fprintf('%d lines coppied\n',lnum);
    
    %close files
    fclose(fin);
    fclose(fout);

    %print success message
    fprintf('Log updated successfully to %s\n',log_out_name);
end

if(isempty(p.Results.SyncDir))
    %make sure that we are on windows
    if(ispc)
        %split the path into parts
        pparts=split(p.Results.DestDir,filesep);
        %use drive letter to create sync path
        SyncDir=fullfile(pparts(1),'sync');
    else
        error('SyncDir is only optional on Windows');
    end
else
    SyncDir=p.Results.SyncDir;
end

%compose sync command
syncCmd=sprintf('python %s --import "%s" "%s"',fullfile(SyncDir,'sync.py'),OutDir,p.Results.DestDir);

system(syncCmd,'-echo');

   
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
        