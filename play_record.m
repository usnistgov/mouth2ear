function [y,underRun,overRun]=play_record(apr,x)
    
    %reshape x into a column vector
    x=reshape(x,[],1);

    %get buffer size
    bsz=apr.BufferSize;

    %initialize recive audio buffer
    y=zeros(size(x)+[5*bsz 0]);
    
    %zerro under and over runs
    underRun=0;
    overRun=0;
    
    for k=bsz:bsz:(length(y))
        
        if(k<=length(x))
            %get a chunk of data
            datin=x((k-bsz+1):k);
        elseif((k-bsz+1)<=length(x))
            %get data to end of file
            datin=x((k-bsz+1):end);
            %add zeros to buffer size
            datin(end+1:bsz)=zeros(bsz-length(datin),1);
        else
            %no data to send, just send zeros
            datin=zeros(bsz,1);
        end
        
        %play/record audio
        [datout,ur,or]=apr(datin);

        %check if this is not the first run
        if(k~=bsz)
            %add data to array
            y((k-2*bsz+1):(k-bsz))=datout;
        end

        %add under and over runs
        underRun=underRun+ur;
        overRun=overRun+or;

    end
    
    %release the audio object
    release(apr);
    
    