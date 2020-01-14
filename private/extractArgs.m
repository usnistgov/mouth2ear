function [str]=extractArgs(parser,fname)
% EXTRACTARGS - return an argument string with values given a parser object
% and filename
%
%   str=EXTRACTARGS(parser,fname) returns a string representing the
%   argument values stored in the inputParser object parser. fname is the
%   name of the file that was called and is used to figure out which
%   options are required optional or parameters


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

%get argument names from parser structure
argNames=fieldnames(parser.Results);

%argument values converted to string
%for parameters this also includes the parameter name in quotes
argStrs=cell(size(argNames));
%type of argument :
%   p   :   Parameter
%   r   :   Required
%   o   :   Optional
argTypes=blanks(length(argNames));
%sort order for arguments, only applies to optional or required arguments
argSort=zeros(size(argNames));

%get arguments from function mfile
%this is a kludgy way to do it but the parser object provides no information
[req,parm,opt]=get_arg_names(fname);

for k=1:length(argNames)
    %get value of argument
    val=parser.Results.(argNames{k});
    
    %get string for value
    valStr=val2str(val,argNames{k});

    %check if argument is a parameter
    if(any(strcmp(argNames{k},parm)))
        %convert to string with parameter name
        argStrs{k}=sprintf('''%s'',%s,',argNames{k},valStr);
        %set arg type
        argTypes(k)='p';
    else
        %add comma to separate arguments
        argStrs{k}=[valStr,','];
        %check if argument matches an optional parameter
        optm=strcmp(argNames{k},opt);
        %is this an optional
        if(any(optm))
            %set type
            argTypes(k)='o';
            %get order
            argSort(k)=find(optm);
        else
            %check if argument matches a required parameter
            reqm=strcmp(argNames{k},req);
            %is this required
            if(any(reqm))
                %set type
                argTypes(k)='r';
                %get order
                argSort(k)=find(reqm);
            else
                %Argument was not found in file
                warning('Argtype not found for ''%s''',argNames{k});
            end
        end 
    end
end

%find the index of the required arguments
req=find(argTypes=='r');
%sort based on argument sort order
[~,ordr]=sort(argSort(req));

%find index of optional arguments
opt=find(argTypes=='o');
%sort based on argument sort order
[~,ordo]=sort(argSort(opt));

%
str=horzcat(argStrs{req(ordr)},argStrs{opt(ordo)},argStrs{argTypes=='p'});

%remove trailing comma
str=str(1:end-1);


function str=val2str(val,name)
    %get length
    len=length(val);
    %check if value is empty
    if(isempty(val))
        %check if this is a cell array
        if(iscell(val))
            %use empty braces
            str='{}';
        elseif(ischar(val))
            %use empty string
            str='''''';
        else
            %use empty brackets
            str='[]';
        end
    elseif((len>1 || iscell(val)) && ~ischar(val))
        %check if this is a cell
        if(iscell(val))
            tmp=cellfun(@(v)val2str(v,name),val,'UniformOutput',false);
            %cell array delimiters
            dlm='{}';
        else
            tmp=arrayfun(@(v)val2str(v,name),val,'UniformOutput',false);
            %array delimiters
            dlm='[]';
        end
        %dummy array for strings
        strs=cell(size(tmp)*[0,1;2,0]);
        %add in strings for values
        strs(1:2:end,:)=tmp';
        %add commas between values
        strs(2:2:(end-1),:)={','};
        %add semicolon at the end of a row
        strs(end,:)={';'};
        %concatenate into a string
        str=horzcat(dlm(1),strs{:});
        %replace trailing semicolon with closing bracket
        str(end)=dlm(2);
    elseif(ischar(val))
        %string/char add quotes
        str=sprintf('''%s''',val);
    elseif(isnumeric(val))
        %numeric value, convert to number
        str=num2str(val);
    elseif(islogical(val))
        %logical value, check if true
        if(val)
            %true, return true string
            str='true';
        else
            %false, return false string
            str='false';
        end
    else
        %unknown type, can't convert
        error('Unknown value for ''%s''',name);
    end
    