classdef QSTserial < handle
    
    properties (SetAccess = private)
        s
        existPort     = false
        existThermode = false
    end
    
    methods

        function obj = QSTserial(port)
                   
            % check if port is available
            if ~ismember(port,seriallist)
                warning('Serial port "%s" is not available',port)
                return
            end
            
            % close and delete all serial port objects on PORT
            tmp = instrfind('port',port);
            if ~isempty(tmp)
              fclose(tmp);
                delete(tmp)
            end
            
            % open connection
            obj.s = serial(port,...
                'BaudRate',         115200,...
                'Terminator',       'CR',...
                'InputBufferSize',  4096);
            fopen(obj.s);
            obj.existPort = true;
            
            % disable display of temperatures
            obj.query('F')
            
            % check if thermode is connected
            if mean(obj.temperature) > 650
                warning('Thermode on "%s" is not connected',port)
            else
                obj.existThermode = true;
            end
        end
        
        function varargout = query(obj,string,timeout)
            if ~exist('timeout','var')
                timeout = .03;
            end
            obj.fprintfd(string,.001)
            java.lang.Thread.sleep(timeout*1000)
            n = obj.s.BytesAvailable;
            if n
                varargout{1} = fread(obj.s,n,'char');
                varargout{1} = char(varargout{1}(2:end))';
            elseif ~n && nargout
                varargout{1} = '';
            else
                varargout = {};
            end
        end
        
        function out = queryN(obj,string,nBytes)
            obj.fprintfd(string,.001)
            out = fread(obj.s,nBytes+1,'char');
            out = char(out(2:end))';
        end
        
        function bench(obj,query)
            if ~exist('query','var')
                query = 'H';
            end
            if obj.s.BytesAvailable > 0
                fread(obj.s,obj.s.BytesAvailable);
            end
            figure
            hold on
            for jj = 1:100
                t = nan(1,300);
                d = nan(1,300);
                fprintf(obj.s,query);
                tic
                for ii = 1:length(t)
                    t(ii) = toc;
                    d(ii) = obj.s.BytesAvailable;
                end
                stairs(t*1000,d)
                fread(obj.s,obj.s.BytesAvailable);
            end
            xlabel('time (ms)')
            ylabel('Bytes')
            tmp = find(d==d(end),1)+1;
            fprintf('%f ms per Byte\n',t(tmp)/d(tmp)*1000)
        end
            
        function out = battery(obj)
            out = sscanf(obj.queryN('B',13),'%*fv %d%%');
        end
        
        function help(obj)
            disp(obj.query('H',.14))
        end
        
        function fprintfd(obj,string,delay)
            for ii = 1:length(string)
                tic
                fwrite(obj.s,string(ii));
                t = (delay-toc)*1000;
                if t > 0
                    java.lang.Thread.sleep(t)
                end
            end
            fwrite(obj.s,'\n');
        end
        
        function out = temperature(obj)
            out = str2num(obj.queryN('E',23)); %#ok<ST2NM>
        end
            
    end
end