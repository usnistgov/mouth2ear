classdef radioInterface < handle
    %RADIOINTERFACE class to interface to raido Push To Talk button
    
    properties (Access = private)
        sobj
    end
    
    methods
        %constructor, must be passed a serial port name
        function obj = radioInterface(port)
% RADIOINTERFACE creat a radio interface object
%
% obj = RADIOINTERFACE('port')
%   Create a RADIOINTERFACE object using the specified serial port
            
            
            %get serial port
            obj.sobj=serial(port);
            
            %open serial port
            fopen(obj.sobj);
        end
        %function to key or un-key the radio
        function ptt(obj,state)      
% PTT change the push to talk status of the radio interface
%
% PTT(state) if state is true then the PTT is set to transmit. if state is
% false then the radio is set to not transmit
            
            
            %check what the state is 
            if(state)
                fprintf(obj.sobj,'%s\n','ptt on');
            else
                fprintf(obj.sobj,'%s\n','ptt off');
            end
        end
        
        %delete method
        function delete(obj)
            %check if serial port is open
            if(isvalid(obj.sobj))
                %close serial port
                fclose(obj.sobj);
                %delete serial object
                delete(obj.sobj);
            end
        end
    end
    
end

