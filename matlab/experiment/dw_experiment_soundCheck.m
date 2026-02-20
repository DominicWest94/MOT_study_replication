%% Test sound level
% Copied from experiment code, so should be exactly the same as what the
% participants hear during the session
 
playTime = 20; % length of audio to play, in seconds, from end of audio

%% Initialize Sounddriver
InitializePsychSound(1);
nrchannels = 2;
fs = 48000;

% Should we wait for the device to really start (1 = yes)
% INFO: See help PsychPortAudio
waitForDeviceStart = 1;

% Open Psych-Audio port, with the follow arguments
% (1) [] = default sound device
% (2) 1 = sound playback only
% (3) 1 = default level of latency
% (4) Requested frequency in samples per second
% (5) 2 = stereo putput
pahandle = PsychPortAudio('Open', [], 1, 4, fs, nrchannels);

%% Play
% Preload sound files into matlab workspace
[audioCurrent] = audioread('stimuli\test.wav');
audioCurrent = audioCurrent(end-(fs*playTime):end,:); % select last 20 seconds
audioCurrent = audioCurrent'; % Transpose for psychtoolbox

% Fill the audio playback buffer with the audio data, doubled for stereo presentation
PsychPortAudio('FillBuffer', pahandle, audioCurrent);
WaitSecs(0.3);

% Start audio playback
tStartSoundCurrent = PsychPortAudio('Start', pahandle, 1, 0, waitForDeviceStart);
WaitSecs(playTime);

% Stop audio playback
PsychPortAudio('Stop',pahandle);

%% Close the audio device
PsychPortAudio('Close', pahandle);
