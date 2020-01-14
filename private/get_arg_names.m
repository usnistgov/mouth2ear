function [requiredInputs,parameterInputs,optionInputs] = get_arg_names(filePath)
% GET_ARG_NAMES - Get any possible inputs to the file at filePath.
%

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

% Open function file
fid = fopen(filePath);

% Set flag for when parse function has been called
parseFlag = 0;

% Counters for number of each input type seen
nRI = 0;
nPI = 0;
nOI = 0;

% Expression for identifying new parameter
paramExp = 'addParameter(';
% Expression for identifying new option
optionExp = 'addOption(';
% Expression for identifying new required
requiredExp = 'addRequired(';
% Expression for identifying initial function line
functionExp = 'function';
% Flag for marking initial function line as seen (to avoid nested
% functions)
functionFlag = 0;
% Expression for identifying parse line
parseExp = 'parse(';

% Initialize cell arrays for storing different input types
requiredInputs = cell(0);
parameterInputs = cell(0);
optionInputs = cell(0);

while(~parseFlag)
    % Get line
    strLine = fgetl(fid);
    
    if(strLine == -1)
        % File over...set  parseFlag to 1 to exit
        parseFlag = 1;
    end
    
    % Check if line is empty or starts with a comment
    if(~isempty(strLine) && ~strcmp(strLine(1),'%'))
        % Not comment line good to go
        
        if(~functionFlag)
            % Haven't seen function yet
            % Find if function def is on this line
            funcIx = strfind(strLine,functionExp);
            if(funcIx)
                % If it is grab remainder of line after function
               rem = strLine((funcIx+length(functionExp)):end);
               % Find end parentheses of line: )
               endParanLocs = strfind(rem,')');
               % Find beginning parentheses of line: (
               begParanLocs = strfind(rem,'(');
               % Grab everything between last pair of parentheses
               backupParams = rem((begParanLocs(end)+1):(endParanLocs(end)-1));
               % Set function flag
               functionFlag = 1;
            end
        else
            % Find locations of parameter expression
            paramIx = strfind(strLine, paramExp);
            
            if(paramIx)
                % For each occurrence of parameter expression
                for i = 1:length(paramIx)
                    % Increment number of parameters seen
                    nPI = nPI+1;
                    % Grab remainder of line after paramIx(i)
                    rem = strLine((paramIx(i)+length(paramExp)):end);
                    % Find commas location after parameter expression
                    commLoc = strfind(rem,',');
                    % Save section of line between next two commas as parameter
                    parameterInputs{nPI} = strrep(strrep(rem((commLoc(1)+1):(commLoc(2)-1)),' ', ''), '''', '');
                end
            end
            
            %  Find locations of option expression
            optionIx = strfind(strLine, optionExp);
            if(optionIx)
                % For each occurrence of option expression
                for i = 1:length(optionIx)
                    % Increment number of options seen
                    nOI = nOI + 1;
                    % Grab remainder of line after optionIx(i)
                    rem = strLine((optionIx(i)+length(optionExp)):end);
                    % Find commas after option expression
                    commLoc = strfind(rem, ',');
                    % Save section of line between next two commas as option
                    optionInputs{nOI} = strrep(strrep(rem((commLoc(1)+1):(commLoc(2)-1)),' ', ''), '''', '');
                end
            end
            
            % Find locations of required expression
            requiredIx = strfind(strLine,requiredExp);
            if(requiredIx)
                % For each occurrence of required expression on line
                for i = 1:length(requiredIx)
                    % Increment number of requireds seen
                    nRI = nRI + 1;
                    % Grab remainder of line
                    rem = strLine((requiredIx(i)+length(requiredExp)):end);
                    % Find commas after expression
                    commLoc = strfind(rem, ',');
                    % Find end parentheses after expression
                    endParanLoc = strfind(rem, ')');
                    if(length(commLoc)>1)
                        % If multiple commas:
                        if(commLoc(1)<endParanLoc(1) && endParanLoc(1) < commLoc(2))
                            % Have multiple commas, but end parentheses between
                            % them...Likely have multiple inputs on one line
                            requiredInputs{nRI} = strrep(strrep(rem((commLoc(1)+1):(endParanLoc(1)-1)),' ', ''), '''', '');
                        else
                            % Have multiple commas w/o end parentheses
                            % between them. Likely have required input with
                            % extra input
                            requiredInputs{nRI} = strrep(strrep(rem((commLoc(1)+1):(commLoc(2)-1)),' ', ''), '''', '');
                        end
                    else
                        % Only one comma: no other inputs, input is between
                        % first comma and end parentheses
                        requiredInputs{nRI} = strrep(strrep(rem((commLoc+1):(endParanLoc-1)),' ', ''), '''', '');
                    end
                end
            end
            
            % Find locations of parse line
            parseIx = strfind(strLine,parseExp);
            if(parseIx)
                % If parse expression present set parseFlag
                parseFlag = 1;
            end
        end
    end
end
% If never found any inputs or parse lines and grabbed the function line
if((sum([nRI nOI, nPI]) == 0 || ~parseFlag) && functionFlag)
    requiredInputs = strsplit(backupParams,',');
end
fclose(fid);
