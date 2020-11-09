classdef radioInterface < handle
    %RADIOINTERFACE class to interface to radio push-to-talk button
    %
    %   RADIOINTERFACE('PORT') creates a RADIOINTERFACE object using the
    %   serial port specified by PORT. The port must be connected to a
    %   microcontroller with the radio interface firmware.
    %
    %   RADIOINTERFACE() same as above but use the first detected
    %   microcontroller.
    %
    %RADIOINTERFACE Methods:
    %   ptt         - change the push-to-talk status
    %   led         - turn on or off LED's on the radio interface board
    %   devtype     - get the device type string
    %   getVersion  - get the version from device
    %   getID       - get unique ID from device
    %   ptt_delay   - key radio after a delay
    %   
    %
    %RADIOINTERFACE Properties:
    %   pttState -  push-to-talk status
    %   WaitState - waiting status of push-to-talk logic
    
%This software was developed by employees of the National Institute of
%Standards and Technology (NIST), an agency of the Federal Government.
%Pursuant to title 17 United States Code Section 105, works of NIST
%employees are not subject to copyright protection in the United States and
%are considered to be in the public domain. Permission to freely use, copy,
%modify, and distribute this software and its documentation without fee is
%hereby granted, provided that this notice and disclaimer of warranty
%appears in all copies.
%
%THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER
%EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY
%WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED
%WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
%FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
%CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
%FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
%LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
%OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
%WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
%OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
%WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
%USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.

    properties (Access = private)
% SOBJ - internal serial object to communicate with the radio interface.
        sobj
    end
    
   properties (Dependent,SetAccess = private)
% PTTSTATE - read the status of the push-to-talk outputs. PTTSTATE returns
% an array with a logical for each radio. If the value is True than the
% push-to-talk signal is pushed, false than it is not.
       pttState
% WAITSTATE - read the status of the push-to-talk logic of the radio
% interface. Returns one of the following :
%   'Idle'        - No pending PTT events exist
%   'Signal Wait' - The radio interface is waiting for the start signal
%   'Delay'       - The radio interface is waiting for the delay to expire
      WaitState
   end
    
    methods
        %constructor, must be passed a serial port name
        function obj = radioInterface(port)
% RADIOINTERFACE create a radio interface object
%
% obj = RADIOINTERFACE('port') Create a RADIOINTERFACE object using the
%               specified serial port
%
% obj = RADIOINTERFACE() same as above but use the first available
%               radiointerface device found
%
            
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
                    catch   % something went wrong with this port skip to the next one
                        %check if port is open
                        if(strcmp(obj.sobj.status,'open'))
                            %close port and continue
                            fclose(obj.sobj);
                        end
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
        
        function ptt(obj,state,num)
% PTT - change the push-to-talk status of the radio interface
%
%   PTT(state) if state is true then the PTT is set to transmit. if state is
%               false then the radio is set to not transmit
%
%   PTT(state,num) same as above but control the ptt of radio number num
%               instead of radio number 1
%
            
            %check if three arguments were given
            if(nargin<3)
                %default num to 1
                num=1;
            end
            
            %check what the state is 
            if(state)
                %state is on
                state='on';
            else
                %state is off
                state='off';
            end
            
            %send command
            obj.command('ptt %u %s',num,state);
        end
        
        function led(obj,num,state)
% LED - turn on or off LED's on the radio interface board
%
% LED(num,state) changes the state of the LED given by num. If state is
%               true turn the LED on if state is false turn the LED off
%

            %determine LED state string
            if(state)
                ststr='on';
            else
                ststr='off';
            end 
            %send command
            obj.command('LED %i %s',num,ststr);
        end
        
        function [dt]=devtype(obj)
% DEVTYPE - get the devicetype string from the radio interface
%
% dt = DEVTYPE() where dt is the devicetype string
%

            %flush input from buffer
            flushinput(obj.sobj);
            
            %send devtype command
            obj.command('devtype');
            %get devtype line
            dt=fgetl(obj.sobj);
        end
        
        function value = get.pttState(obj)
% returns the pttState for a radioInterface object. This is called
% automatically when pttState is accessed

            %flush input from buffer
            flushinput(obj.sobj)
            %send ptt command with no arguments
            obj.command('ptt');
            %get response line
            resp=fgetl(obj.sobj);
            %parse number of PTT outputs
            num=textscan(resp,'%u PTT outputs:');
            %preallocate value
            value=NaN(1,num{1});
            %loop through all outputs
            for k=1:num{1}
                %get response line
                resp=fgetl(obj.sobj);
                %get state from response
                state=textscan(resp,sprintf('PTT%i status : %%s',k));
                %check that state was parsed correctly
                if(all(size(state)==[1 1]))
                    switch(state{1}{1})
                        case 'on'
                            value(k)=true;
                        case 'off'
                            value(k)=false;
                        otherwise
                            value(k)=NaN;
                    end
                else
                    value(k)=NaN;
                end
            end
        end
        
        function value = get.WaitState(obj)
% returns the WaitState for a radioInterface object. this is called
% automatically when WaitState is accessed

            obj.command('ptt state');
            %get response line
            resp=fgetl(obj.sobj);
            %parse PTT state
            state=textscan(resp,'PTT state : %q');
            if(isempty(state{1}))
                err_str='Error : ';
                if(startsWith(resp,err_str))
                    error(resp(length(err_str):end))
                else
                    error('Unknown response ''%'' received',resp);
                end
            end
            value=state{1}{1};
        end
        
        function delay =  ptt_delay(obj,delay,varargin)
% PTT_DELAY setup the radio interface to key the radio after a delay
%
%   PTT_DELAY(dly) set the radio to be keyed in dly seconds.
%
%   PTT_DELAY(dly,'UseSignal',true) set the radio to be keyed dly seconds
%   after the start signal is detected.
%
%   PTT_DELAY(dly,num,__) same as above but used key radio number num
%   instead of radio number one
%
%   delay=PTT_DELAY(dly,__) same as above but return the actual delay set on
%   the microcontroller. This is different because of rounding and limits on
%   the possible delay
%

            %create new input parser
            p=inputParser();

            %delay value in seconds
            addRequired(p,'delay',@(n)validateattributes(n,{'numeric'},{'scalar','real','finite','nonnegative'}));
            %radio number to use
            addOptional(p,'num',1,@(n)validateattributes(n,{'numeric'},{'scalar','integer','positive'}));
            %add use signal parameter
            addParameter(p,'UseSignal',false,@(t)validateattributes(t,{'numeric','logical'},{'scalar'}));
            
            parse(p,delay,varargin{:});
            
            %check which ptt command to use
            if(p.Results.UseSignal)
                %delay is relative to signal
                delay_type='Sdelay';
            else
                %delay is relative to when command processed
                delay_type='delay';
            end
            
            %flush input from buffer
            flushinput(obj.sobj)
            %send ptt command with no arguments
            obj.command('ptt %u %s %f',p.Results.num,delay_type,p.Results.delay);
            %get response line
            resp=fgetl(obj.sobj);
            %get actual delay
            delay=textscan(resp,'PTT in %f sec');
            %get delay value
            delay=delay{1};
            %check if data was parsed correctly
            if(isempty(delay))
                %scan for error
                err=textscan(resp,'Error : %[^\r\n]');
                %get string from data
                err=cell2mat(err{1});
                %check that error was found
                if(isempty(err))
                    %unable to parse error
                    error('Unknown Error');
                else
                    %raise error from MCU
                    error('%s',err);
                end
            end
        end
        
        function [id]=getID(obj)
% GETVERSION - return version string from microcontroller
%
%   ver=getID() - returns unique device ID from the device
            
            %flush input from buffer
            flushinput(obj.sobj)
            %send ptt command with no arguments
            obj.command('id');
            %read ID line
            id=fgetl(obj.sobj);
            %strip whitespace
            id=strtrim(id);
            
        end
        
        function [ver]=getVersion(obj)
% GETVERSION - return version string from microcontroller
%
%   ver=getVersion() - returns version string from the microcontroller.
%   This is typically vx.x with the possibility of a more informative
%   suffix
            
            %get devtype, this will have version
            devtype=obj.devtype();
            
            parts=split(devtype,':');
            
            if(length(parts)==2)
                ver=strtrim(parts{2});
            else
                ver='old';
                warning('Unexpected devtype format, old RadioInterface firmware?');
            end
        end
        
        function [ext,int]=temp(obj)
% TEMP - return the value from temperature sensors
%
%   [ext,int]=temp() - returns the temperature measured by the thermistor
%   external to the radiointerface or the temperature sensor built into the
%   MSP430

            %flush input from buffer
            flushinput(obj.sobj)
            
            %send temp command
            obj.command('temp');
            
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
% DELETE - Remove a radioInterface object from memory
%
%   DELETE(obj) deletes a serial port object and releases the associated
%   serial port
%

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
    
    methods(Access='protected')
        function command(obj,cmd,varargin)
% COMMAND - low level command function to send command to the MSP430
            
            %flush input buffer
            flushinput(obj.sobj);

            %trim extraneous white space from command
            cmd=strtrim(cmd);

            %format command string
            cmd_str=sprintf(cmd,varargin{:});

            %send command
            fprintf(obj.sobj,'%s\n',cmd_str);

            %line buffer
            l='';

            %maximum number of iterations
            mi=3;

            %turn off warnings from fgetl
            [wstate]=warning('off','MATLAB:serial:fgetl:unsuccessfulRead');

            %catch errors to make sure warning states are reset correctly
            try
                %check command responses for echo
                while(~strcmp(l,cmd_str))
                    %get response
                    l=fgetl(obj.sobj);
                    %trim whitespace from response
                    l=strtrim(l);
                    %subtract one from count
                    mi=mi-1;
                    %check if we should timeout
                    if(mi<=0)
                        %throw error
                        error('Command response timeout');
                    end
                end
            catch err
                %reset warning state
                warning(wstate);
                %rethrow error
                rethrow(err);
            end
            %reset warning state
            warning(wstate);
        end
    end
end

