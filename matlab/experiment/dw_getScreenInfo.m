% Gets information about screens, using PsychToolBox functions
% Dominic West/dominicwest94@gmail.com/July 2025

%% Choose screen
screens = Screen('Screens');
screenID = 2; % 1 = participant monitor, 2 = experimenter monitor

%% Get screen info 
PsychDefaultSetup(2);

% Measure screen
rect = Screen('Rect', screenID);
[wX, wY] = Screen('WindowSize', screenID);
[widthMM, heightMM] = Screen('DisplaySize', screenID);
mmPerPixel = widthMM / wX;
ppi = wX / (widthMM / 25.4);
% Get frame rate
frameRate = Screen('NominalFrameRate', screenID);

fprintf('\nScreen %d: %dx%d pixels, %.0fx%.0f mm (%.0f ppi) size, %.1f Hz\n', ...
    screenID, wX, wY, widthMM, heightMM, ppi, frameRate);

Screen('CloseAll');
