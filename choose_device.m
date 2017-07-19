function name=choose_device(apr)

    %list of sound device names to use
    device_names={'UMC'};

    %get a list of the audio devices
    ad=apr.getAudioDevices();

    %get matches
    idx=find(contains(ad,device_names));

    %check if there were more than one matching device
    if(length(idx)>1)
        %print out devices found
        fprintf('Multiple devices found :\n');
        fprintf('\t%s\n',ad{idx});
        %use the last
        idx=idx(end);
    end
    
    %return name
    name=ad{idx};

    %set device
    apr.Device=name;
    
end