function [varargout] = ITS_delay_wrapper(varargin)
%SLIDING_DELAY_ESTIMATES wrapper function for sliding_delay_estimates
    
    %generate cell array for output arguments
    varargout=cell(1,nargout);
    %get old path
    oldpath=path();
    %add directory to path
    path('./ITS_delay',oldpath);
    try
        [varargout{:}]=sliding_delay_estimates(varargin{:});
    catch e
        %restore path
        path(oldpath);
        %rethrow error
        rethrow(e)
    end
    %restore path
    path(oldpath);
end

