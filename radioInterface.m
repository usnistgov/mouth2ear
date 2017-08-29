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
            
            if(nargin < 1)
                %get all serial port names
                ports=seriallist();
                %flag to denote if a device has been found
                found=0;
                %turn off warnings
                ws=warning('off');
                %loop through all ports
                for k=1:length(ports)
                    try
                        %get serial port object
                        obj.sobj=serial(ports{k});                          %#ok this needs to be in a loop
                        %set terminator to CR/LF
                        obj.sobj.Terminator='CR/LF';
                        %set timeout to 0.5s
                        obj.sobj.Timeout=0.5;
                        %open port
                        fopen(obj.sobj);
                        %get devtype
                        dt=obj.devtype();
                        %check if devtype is good
                        if(startsWith(dt,'MCV radio interface'))
                            found=1;
                            break;
                        else
                            %close serial port
                            fclose(obj.sobj);
                            %delete serial port
                            delete(obj.sobj);
                        end
                    catch
                    end
                end
                %restore warning state
                warning(ws);
                
                %check if a port was found
                if(~found)
                    %give error
                    error('No radio interface found');
                end
            else
            
                %get serial port
                obj.sobj=serial(port);
                
                %set terminator to CR/LF
                obj.sobj.Terminator='CR/LF';
                
                %open serial port
                fopen(obj.sobj);
            end
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
        
        function led(obj,num,state)
% LED turn on or off LED's on the radio interface board
%
% LED(num,state) changes the state of the LED given by num. If state is
% true turn the LED on if state is false turn the LED off
            
            if(state)
                fprintf(obj.sobj,'%s\n','LED ON');
            else
                fprintf(obj.sobj,'%s\n','LED OFF');
            end 
        end
        
        function [dt]=devtype(obj)
% DEVTYPE get the devicetype string from the radio interface
%
% dt=DEVTYPE() where dt is the devicetype string
            
            %check if there are bytes in the buffer
            if(obj.sobj.BytesAvailable>0)
                %read all bytes in buffer
                fread(obj.sobj,obj.sobj.BytesAvailable);
            end
            %send devtype command
            fprintf(obj.sobj,'%s\n','devtype');
            %get a line for the echo
            fgetl(obj.sobj);
            %get a blank line
            fgetl(obj.sobj);
            %get devtype line
            dt=fgetl(obj.sobj);
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

