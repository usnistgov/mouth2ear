function [rx_name] = findRx(tx_name)
%folder name for rx data
rx_dat_fold='rx-data';

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
    names=cellstr(ls(fullfile('rx-data','Rx_capture_*')));
    
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
        info=audioinfo(fullfile('rx-data',names{k}));
        
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