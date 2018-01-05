function rx_vol()

%use a sample rate of 48 kHz
fs=48e3;

%create an object for playback and recording
RecObj=audioDeviceReader(fs,'NumChannels',2,'BitDepth','24-bit integer');

%create a loudness meter object
lm=loudnessMeter();

%chose which device to use
dev_name=choose_device(RecObj);

%print the device used
fprintf('Using "%s" for audio test\n',dev_name);


%set number of channesl to one
RecObj.NumChannels=1;

%zerro  over runs
overRun=0;

%declare done as global
global done;

%flag to tell when to quit
done=0;

%generate new figure
figure('CloseRequestFcn',@figure_close);

%loop while plot is open
while(~done)
    %read audio data
    [datout,or]=RecObj();
   
    lm(datout);
    
    lm.visualize();
    
    %force drawing
    drawnow();
    
    %add over runs
    overRun=overRun+or;
end


%check for buffer over runs
if(any(overRun))
    fprintf('There were %i buffer over runs\n',sum(overRun));
else
    fprintf('There were no buffer over runs\n');
end

end


function figure_close(src,~)
    global done;
    
    %set flag
    done=1;
    
    %close figure
    delete(src);
end
