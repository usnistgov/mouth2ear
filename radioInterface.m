classdef radioInterface < handle
    %RADIOINTERFACE class to interface to raido Push To Talk button
    
    properties (Access = private)
        sobj
    end
    
   properties (Dependent)
      pttState
   end
    
    methods
        %constructor, must be passed a serial port name
        function obj = radioInterface(port)
% RADIOINTERFACE creat a radio interface object
%
% obj = RADIOINTERFACE('port')
%   Create a RADIOINTERFACE object using the specified serial port
            
            if(nargin < 1 || isempty(port))
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
            
            %determine LED state string
            if(state)
                ststr='on';
            else
                ststr='off';
            end 
            %send command
            fprintf(obj.sobj,'%s\n',sprintf('LED %i %s\n',num,ststr));
        end
        
        function [dt]=devtype(obj)
% DEVTYPE get the devicetype string from the radio interface
%
% dt=DEVTYPE() where dt is the devicetype string
            
            %flush input from buffer
            flushinput(obj.sobj);
            
            %send devtype command
            fprintf(obj.sobj,'%s\n','devtype');
            %get a line for the echo
            fgetl(obj.sobj);
            %get devtype line
            dt=fgetl(obj.sobj);
        end
        
        function value = get.pttState(obj)
            %flush input from buffer
            flushinput(obj.sobj)
            %send ptt command with no arguments
            fprintf(obj.sobj,'%s\n','ptt');
            %get echoed line
            fgetl(obj.sobj);
            %get response line
            resp=fgetl(obj.sobj);
            %get state from response
            state=textscan(resp,'PTT status : %s');
            %check that state was parsed correctly
            if(all(size(state)==[1 1]))
                switch(state{1}{1})
                    case 'on'
                        value=true;
                    case 'off'
                        value=false;
                    otherwise
                        value=NaN;
                end
            else
                value=NaN;
            end
        end
        
        function [ext,int]=temp(obj)
            %flush input from buffer
            flushinput(obj.sobj)
            
            %send temp command
            fprintf(obj.sobj,'%s\n','temp');
            %get a line for the echo
            fgetl(obj.sobj);
            
            %get internal temp line
            intl=fgetl(obj.sobj);
            %get external temp line
            extl=fgetl(obj.sobj);
            
            %parse internal temperature
            int=sscanf(intl,'int = %f C');
            %parse external temp value
            extr=sscanf(extl,'ext = %d');
            %B value of thermistor
            B=3470;
            %compute external temperature
            ext=B/log(10e3/((2^12-1)/extr-1)/(10e3*exp(-B/(273.15+25))))-273.15;
        end
        
        %delete method
        function delete(obj)
            %check if serial port is open
            if(isvalid(obj.sobj))
                %check if port is open
                if(strcmp(obj.sobj.status,'open'))
                    try
                        %closeout command, turn off LEDS and ptt
                        fprintf(obj.sobj,'%s\n','closeout');
                    catch  %#ok just ignore errors so we can finish cleanup
                    end
                    %close serial port
                    fclose(obj.sobj);
                end
                %delete serial object
                delete(obj.sobj);
            end
        end
    end
    
end

