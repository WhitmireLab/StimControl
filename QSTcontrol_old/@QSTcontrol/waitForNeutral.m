function waitForNeutral(obj)
% 
% % Get neutral Temperature setting from serial devices
% Tneutral = arrayfun(@(x) str2double(regexp(obj.s(x).query('P'),'N(\d*)',...
%     'tokens','once')),1:length(obj.s));
% 
% % Anonymous function that obtains temperature difference
% Tdelta = @() abs(Tneutral - arrayfun(@(x) ...
%     mean(str2num(obj.s(x).queryN('E',23))),1:length(obj.s)))/10;%#ok<ST2NM>
% 
% % Acceptable temperature difference
% Tcrit = 1;
% 
% % If things look good already, return to calling function
% if all(Tdelta()<Tcrit)
%     return
% end
% 
% % Set figure title
% obj.setTitle('waiting for Neutral Temperature to settle...')
% 
% % Wait for device to reach neutral temperature
% while ~all(Tdelta()<Tcrit)
%     pause(0.5)
% end
% pause(1)


% % Set figure title
% obj.setTitle()