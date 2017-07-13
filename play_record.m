function [y,underRun,overRun]=play_record(apr,x,varargin)
    

    %create new input parser
    p=inputParser();

    %add audio object argument
    addRequired(p,'apr',@(l)validateattributes(l,{'audioPlayerRecorder'},{'scalar'}));
    %add output audio argument
    addRequired(p,'x',@(l)validateattributes(l,{'numeric'},{'real','finite'}));
    %add overplay parameter
    addParameter(p,'OverPlay',0.1,@(l)validateattributes(l,{'numeric'},{'real','finite','scalar','nonnegative'}));

    %add window length argument
    addOptional(p,'winLength',4,@(l)validateattributes(l,{'numeric'},{'scalar','positive'}));

    %set parameter names to be case sensitive
    p.CaseSensitive= true;

    %parse inputs
    parse(p,apr,x,varargin{:});

    %reshape x into a column vector
    x=reshape(p.Results.x,[],1);

    %get buffer size
    bsz=p.Results.apr.BufferSize;
    
    %get sample rate
    fs=p.Results.apr.SampleRate;

    %calculate the number of loops needed
    runs=ceil(length(x+p.Results.OverPlay*fs)/bsz);
    
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
    
    