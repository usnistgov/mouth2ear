function [rx_name] = findRx(tx_name,rx_dat_fold)
%FINDRX find the rx filename for a given tx filename
%
%   rx_name=FINDRX(tx_name) search the rx-data folder for a rx file that
%   corosponds to the same time that the file given by tx_name was recorded
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

%split tx filename
[~,tx_name_only,~]=fileparts(tx_name);

%split tx filename
    tx_parts=split(tx_name_only,'_');
    %check prefix
    if(~(strcmp(tx_parts{1},'Tx') && strcmp(tx_parts{2},'capture')))
        %give error
        error('Tx filename "%s" is not in the propper form. Can not determine Rx filename',p.Results.tx_name);
    end
    %check if we have a test type
    if(length(tx_parts)==7)
        tx_datestr=[tx_parts{3} '_' tx_parts{4}];
    elseif(length(tx_parts)==8)
        tx_datestr=[tx_parts{4} '_' tx_parts{5}];
    end
    %attempt to get date from tx filename
    tx_date=datetime(tx_datestr,'InputFormat','dd-MMM-yyyy_HH-mm-ss');
    
    %list files in the recive folder
    names=cellstr(ls(fullfile(rx_dat_fold,'Rx_capture_*')));
    
    %check that files were found
    if(isempty(names))
        error('Files not found in Rx folder');
    end
    
    found=0;
    
    for k=1:length(names)
        %extract date string from filename
        [~,dstr]=fileparts(erase(names{k},'Rx_capture_'));
        
        %get the date in the file
        rx_date_start=datetime(dstr,'InputFormat','dd-MMM-yyyy_HH-mm-ss');
        
        %read info on the audio file
        info=audioinfo(fullfile(rx_dat_fold,names{k}));
        
        %calculate the stop time
        rx_date_end=rx_date_start+seconds(info.Duration);
        
        %check that tx date falls within rx file time
        if(tx_date>rx_date_start && tx_date<rx_date_end)
            %flag as found
            found=1;
            %set rx filename
            rx_name=fullfile(rx_dat_fold,names{k});
            %print out filename
            fprintf('Rx file found "%s"\n',rx_name);
            %exit the loop
            break;
        end
    end
    
    %check that a file was found
    if(~found)
        %file not found, give error
        error('Could not find a suitable Rx file');
    end