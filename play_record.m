function [y,underRun,overRun]=play_record(apr,x)
    
    %reshape x into a column vector
    x=reshape(x,[],1);

    %get buffer size
    bsz=apr.BufferSize;

    %calculate the number of loops needed
    runs=ceil(length(x)/bsz+5);
    
    %initialize recive audio buffer
    y=zeros((runs-1)*bsz,size(x,2));
    
    %zerro under and over runs
    underRun=0;
    overRun=0;
    
    for k=1:runs
        
        if(k*bsz<=length(x))
            %get a chunk of data
            datin=x((bsz*(k-1)+1):(bsz*k));
        elseif(k*bsz>=length(x))
            %get data to end of file
            datin=x((bsz*(k-1)+1):end);
            %add zeros to buffer size
            datin(end+1:bsz)=zeros(bsz-length(datin),1);
        else
            %no data to send, just send zeros
            datin=zeros(bsz,1);
        end
        
        %play/record audio
        [datout,ur,or]=apr(datin);

        %check if this is not the first run
        if(k>1)
            %add data to array
            y((bsz*(k-2)+1):(bsz*(k-1)))=datout;
        end

        %add under and over runs
        underRun=underRun+ur;
        overRun=overRun+or;

    end
    
    %release the audio object
    release(apr);
    
    