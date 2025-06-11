classdef ParamManager

    properties
        handles
    end

    methods(Static)
        function obj = ParamManager()
            
        end

        function SaveHardware(obj, objs, filepath, identifier)
            
        end

        function saveJson(obj, objs, filepath, identifier)
            
        end

        function SaveCsv(obj, filepath, identifier)
            
        end

        function objs = ReadParams(obj, filepath)
            filename = 'C:\Users\labadmin\Documents\MATLAB\WidefieldImager\paramfiles\HardwareParams.json';
            jsonStr = fileread(filename);
            jsonData = jsondecode(jsonStr);
            objs = [];
            for i = 1:length(jsonData)
                hStruct = jsonData{i};
                switch lower(hStruct.DEVICE)
                    case 'camera'
                        %TODO AYE
                        continue
                    case 'daq'
                        hObj = DaqInterface('Struct', hStruct);
                    otherwise
                        disp("Unsupported hardware type. Come back later.")
                end
                objs(i) = hObj;
            end
        end

        function ReadProtocol(obj, filepath)
            return
        end
    end
end