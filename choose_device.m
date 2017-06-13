function name=choose_device(apr)

    %list of sound device names to use
    device_names={'UH-7000','M-Track','Focusrite','UMC','Scarlett'};

    %get a list of the audio devices
    ad=apr.getAudioDevices();

    %get matches
    idx=find(contains(ad,device_names));

    %check if there were more than one matching device
    if(length(idx)>1)
        %type of driver to use
        %dtype='(Bit Accurate)';
        dtype='(Core Audio)';
        %print out devices found
        fprintf('Multiple devices found :\n');
        fprintf('\t%s\n',ad{idx});
        %get the matching one
        devIdxIdx=find(contains(ad(idx),dtype),1);
        %make sure one met the criteria
        if(~isempty(devIdxIdx))
            %set the new index
            idx=idx(devIdxIdx);
            %print out which is being used
            fprintf('Using "%s"\n',ad{idx});
        else
            %use the last
            idx=idx(end);
            %print which is used
            fprintf('Could not find one matching "%s" using %s\n',dtype,ad{idx});
        end
    end
    
    %return name
    name=ad{idx};

    %set device
    apr.Device=name;
    
end