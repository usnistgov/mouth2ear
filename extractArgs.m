function [str]=extractArgs(parser,fname)

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
%sort order for arguments, only applys to optional or required arguments
argSort=zeros(size(argNames));

%get arguments from function mfile
%his is a klugy way to do it but the parser object provides no information
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
        %add comma to seperate arguments
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
            %use empyt bracies
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
        %add semicolin at the end of a row
        strs(end,:)={';'};
        %concatinate into a string
        str=horzcat(dlm(1),strs{:});
        %replace trailing semicolin with closing bracket
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
    