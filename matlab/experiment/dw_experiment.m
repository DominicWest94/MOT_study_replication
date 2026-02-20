function dw_experimentV4

%% Multiple Object Tracking (MOT) During Speech Processing

% Dominic   West/dominicwest94@gmail.com/May 2025 (Based on a script kindly
% supplied by Harrison Ritz, March 2015 (harrison.ritz@gmail.com))

% Requires participants to track 2:6 objects while listening to
% speech; based on Ritz, H., Wild, C J., & Johnsrude, I S. (2022). 
% Parametric Cognitive Load Reveals Hidden Costs in the Neural 
% Processing of Perfectly Intelligible Degraded Speech. The Journal of 
% Neuroscience, 42(23), 4619-4628.

%%% PROCEDURE %%%
% Participants attend to either the MOT task (TRACK) or the audiobook 
% (LISTEN) for 6 blocks of 48 trials. During TRACK trials, participants  
% track [1 3 4 6] dots. During LISTEN trials, participants indicate when
% they hear an artifically inserted repeated sentence in the audiobook.

%%% CONDITION COUNTER-BALANCING %%%
% Task condition randomisation occurs within each block (6 blocks total).
% Because the inserted sentence-repeats occur only every ~60 seconds, the
% generated task sequence first assigns all trials containing a repeat as
% LISTEN trials, then assigns the remaining LISTEN trials, and finally
% assigns the other 50% of the trials as TRACK trials. This is to ensure
% that repeat sentences occur during LISTEN trials whilst ensuring task
% condition is pseudo-randomised.

try
    %% Clear the workspace and set directories
    clearvars;
    close all;
    sca;
    
    direxp = 'C:\Experiments\Dominic\exp2';
    cd(direxp)
    stimFolder = 'stimuli\';
    chapterList = dir('stimuli\audio*.wav');
    
    %% Get participant info
    
    prompt = {'Participant #', 'Block', 'Age', 'Sex'};
    answer = inputdlg(prompt, 'Participant Info',1,{'99','1','23','F'});
    participantNumber = str2double(answer{1});
    block = str2double(answer{2});
    age = str2double(answer{3});
    sex = answer{4};

    % Prepare data file
    data = {'Participant','Age','Sex','Block','Trial','Attend','MOT_file','Targets','Targets_idx','Num_dots','Audio_onset','Trial_onset','MOT_onset','Query_onset','ITI_Onset','Correct_response','Keypress','Keytime','Acc','RT'};
    
    % Consult existing block files for this participant to avoid repeats
    [usedChapters, usedMOTgroups] = get_used_assignments(direxp, participantNumber);

    % Define full candidate sets for blocks 1..6
    allChapters = 1:6;
    allMOTgroups = "MOTlocs_" + string(1:6);

    % Determine available options for this block
    if block == 7
        % Practice block: fixed assets
        chapter  = 7;
        MOTgroup = 'MOTlocs_7';
    else
        % Remaining chapters (1..6) not yet used
        availChapters = setdiff(allChapters, usedChapters);
        % Remaining MOT groups (MOTlocs_1..6) not yet used
        availMOT = setdiff(allMOTgroups, usedMOTgroups);

        % Safety: if something went out of sync (e.g., rerun a finished block),
        % reset availability so the run can proceed (still random, best effort).
        if isempty(availChapters), availChapters = allChapters; end
        if isempty(availMOT),      availMOT      = allMOTgroups; end

        % Deterministic randomness given participant+block
        rng(participantNumber + block, 'twister');
        chapter  = availChapters(randi(numel(availChapters)));
        MOTgroup = char(availMOT(randi(numel(availMOT))));
    end

    locList = dir(fullfile(stimFolder, MOTgroup, '*.mat'));

    %% Open screen, reset random
    % Screen('Preference','SkipSyncTests', 1);
    % window=Screen('OpenWindow', 0, [], [0,0,1024,768]);
    window=Screen('OpenWindow', 1, []); % 1 = participant monitor, 2 = experimenter monitor
    
    % Set the maximum priority number
    topPriorityLevel = MaxPriority(window);
    Priority(topPriorityLevel);
    
    rng(participantNumber + block,'twister'); % resets the random number generator, using seed based on participant number
    
    %% Experiment Parameters
    nTrials = 48;       % number of trials/block
    dotNum = [1,3,4,6]; % load conditions
    probeNum = 3;       % number of probes

    % for practice block
    if block == 7
        nTrials = 6;
    end
    
    % timing parameters
    fixlen =    0.3;      % ITI
    targetDur = 1.8;      % duration of target cues
    trackDur =  5.0;      % duration of tracking in seconds
    pauseDur =  0.1;      % time between end of movie and probe
    respDur =   2.8;      % time to respond to probe
    
    % display parameters
    trackSize = [700,700];  % size of tracking space
    objSize = 14;           % size, in pixels, of dot
    dist = 12;              % number distractors
    frameRate = 60;     % frames per second
    fixSize = 4;        % size of the fixation box (well, half of it - the distance from the middle to edge horizontally/vertically)
    qFrame = 1;         % width of frame around each tracking quadrant
    
    % screen stuff
    rect = Screen('Rect',window);
    xMid = rect(3)/2;
    yMid = rect(4)/2;
    white = [255,255,255];
    black=[0,0,0];
    grey = [128,128,128];
    red = [255,0,0];
    blue = [0,128,255];
    yellow = [255,255,0];
    backgroundColour = [100,100,100];
    Screen('TextFont', window, 'Arial');
    fixCol = yellow;
    frameCol = grey;
    trackRect = [xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2];
    
    % set variables for key codes
    KbName('UnifyKeyNames')
    escapeKey = KbName('ESCAPE');
    kb1 = KbName('1!');
    kb2 = KbName('2@');
    kb3 = KbName('3#');
    kb = vertcat([kb1,1],[kb2,2],[kb3,3]);
    accuracy = nan(1,nTrials);
    
    % timestamps of sentence repeats - final row is practice audio
    repeatsTimes = [57 126 200 261 315 375 430 483 545 612; 59 121 198 260 307 375 437 482 562 608;...
        63 121 185 244 305 373 435 494 555 601; 62 127 183 244 304 379 424 495 550 602;...
        67 126 188 245 312 366 424 485 549 612; 64 131 192 255 306 364 434 483 552 604;...
        22 42 60 0 0 0 0 0 0 0];
    
    % randomise MOT order
    assert(numel(locList) >= nTrials, ...
        'Not enough MOT *.mat files in %s for nTrials=%d', MOTgroup, nTrials);
    
    MOTlist = randperm(numel(locList), nTrials);
    counter = 1;
    
    %% Initialise EEG triggers
    % configure serial port for triggers
    [handle, errmsg] = IOPort('OpenSerialPort', 'COM3', ' BaudRate=115200 DataBits=8 StopBits=1 Parity=None');
    
    triggerEEGOnset = uint8(255);
    triggerEEGOffset = uint8(250);
    triggerConditionAudio = uint8(95);
    triggerConditionVisual = uint8(105);
    triggerMOTLoad1 = uint8(115);
    triggerMOTLoad3 = uint8(116);
    triggerMOTLoad4 = uint8(117);
    triggerMOTLoad6 = uint8(118);
    triggerChapter1 = uint8(135);
    triggerChapter2 = uint8(145);
    triggerChapter3 = uint8(155);
    triggerChapter4 = uint8(165);
    triggerChapter5 = uint8(175);
    triggerChapter6 = uint8(185);
    triggerSpeechOnset = uint8(195);
    triggerSpeechOffset = uint8(205);
    triggerResponseScreenOnset = uint8(215);
    triggerResponsePressOnset = uint8(225);
    triggerMOTOnset = uint8(235);
    triggerMOTOffset = uint8(245);
    
    %% Set up sound
    % Initialize Sounddriver
    InitializePsychSound(1);
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
    pahandle = PsychPortAudio('Open', [], 1, 4, fs, 2);
    
    %% Start Screen
    Screen('FillRect',window,backgroundColour);
    
    inst1 = 'You will see several dots and be asked to either TRACK or LISTEN';
    inst1W=TextBounds(window,inst1);
    inst2 = 'If TRACK, keep track of the red dots and select the target when asked';
    inst2W=TextBounds(window,inst2);
    inst3 = 'If LISTEN, focus on the audiobook and listen for a repeated sentence';
    inst3W=TextBounds(window,inst3);
    inst4 = 'Press any key to start';
    inst4W=TextBounds(window,inst4);
    
    Screen('DrawText',window,inst1,xMid-(inst1W(3)-inst1W(1))/2,yMid-100,white);
    Screen('DrawText',window,inst2,xMid-(inst2W(3)-inst2W(1))/2,yMid-50,white);
    Screen('DrawText',window,inst3,xMid-(inst3W(3)-inst3W(1))/2,yMid-0,white);
    Screen('DrawText',window,inst4,xMid-(inst4W(3)-inst4W(1))/2,yMid+50,white);
    
    Screen('Flip',window);
    KbStrokeWait;
    
    %% BLOCK
    
    % calculate full trial length (including ITI)
    trialDur = fixlen+targetDur+trackDur+pauseDur+respDur;
    
    % 'chapter' already selected above; proceed
    
    repeatsChapter = repeatsTimes(chapter,:);

    % get MOT load sequence
    dotSequence = repmat(dotNum, 1, ceil(nTrials / length(dotNum)));
    dotSequence = dotSequence(randperm(numel(dotSequence)));
    
    % Convert repeat timestamps into trial indices
    allRepeatTrials = ceil(repeatsChapter / trialDur);
    allRepeatTrials = allRepeatTrials(allRepeatTrials > 0 & allRepeatTrials <= nTrials); % valid trial range
    allRepeatTrials = unique(allRepeatTrials); % remove duplicates
    
    % Initialize task condition sequence: 1 = LISTEN, 2 = TRACK
    taskSequence = zeros(1, nTrials);
    taskSequence(allRepeatTrials) = 1; % assign repeat trials to LISTEN
    
    % Determine how many additional LISTEN trials are needed to reach 50%
    targetNumListen = nTrials / 2;
    remainingListen = targetNumListen - numel(allRepeatTrials);
    
    % Randomly assign remaining LISTEN trials from unassigned trials
    if remainingListen > 0
        availableTrials = find(taskSequence == 0);
        remainingListenTrials = randsample(availableTrials, remainingListen);
        taskSequence(remainingListenTrials) = 1;
    end
    
    % Assign remaining unassigned trials to TRACK
    taskSequence(taskSequence == 0) = 2;
    
    % get correct response sequence (valid resp: 1:3)
    resp = randsample(vertcat(ones(nTrials/probeNum,1),ones(nTrials/probeNum,1)*2,ones(nTrials/probeNum,1)*3),nTrials);
    
    % send trigger to start EEG recording
    IOPort('Write',handle,triggerEEGOnset);
    
    % preload sound files into matlab workspace
    if block == 7
        audioName = 'test.wav';
    else
        audioName = chapterList(chapter).name;
    end

    audioCurrent = audioread(fullfile(direxp,stimFolder,audioName));
    audioCurrent = audioCurrent'; % transpose for psychtoolbox
    
    % fill the audio playback buffer with the audio data, doubled for stereo presentation
    PsychPortAudio('FillBuffer', pahandle, audioCurrent);
    
    % blank screen while waiting
    Screen('FillRect',window,backgroundColour);
    Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
    Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]); % draw fixation box
    
    fixOn = Screen('Flip',window); % present fixation
    
    % Send trigger based on audiobook chapter
    switch chapter
        case 1
            IOPort('Write',handle,triggerChapter1);
        case 2
            IOPort('Write',handle,triggerChapter2);
        case 3
            IOPort('Write',handle,triggerChapter3);
        case 4
            IOPort('Write',handle,triggerChapter4);
        case 5
            IOPort('Write',handle,triggerChapter5);
        case 6
            IOPort('Write',handle,triggerChapter6);
    end
    
    % Start audio playback
    tStartAudio = PsychPortAudio('Start', pahandle, 1, 0, waitForDeviceStart);
    
    % Send trigger at sound onset
    IOPort('Write',handle,triggerSpeechOnset);
    
    %% TRIALS
    for trial=1:nTrials
    
        % trial parameters
        attend = taskSequence(trial);   % set attend (1 = speech, 2 = mot)
        numTrack = dotSequence(trial);  % set number of targets
        corr_resp = resp(trial);
    
        numDots = numTrack+dist;       % number of dots in total
        
        targets = randsample(numDots,numTrack);                     % pick targets from the dots
        corr = datasample(targets,1);                               % pick a target to be queried
        foils = randsample(setxor(1:numDots,targets), probeNum-1);  % pick dots that are not targets to be foils
        
        % Load mot object locations
        % I make the movies with MOTmovie (via
        % MOTmaker), and it will give me a 4D matrix: frame by object by XY
        % coordinates. I save this list of locs to a mat file for faster loading.
        % Again, its at a trial level (otherwise you'd make the
        % location matrix at the beginning of each trial), but its cleaner and it easily lets
        % you see the locations of the objects for item effects (heaven
        % forbid). I made the movies 60fps, but I can use any
        % fps below that, it just wont make it through the entire movie       
    
        % Send trigger based on attention condition
        if attend == 1
            IOPort('Write',handle,triggerConditionAudio);
        elseif attend == 2
            IOPort('Write',handle,triggerConditionVisual);
        end
        
        % Send trigger based on MOT load
        switch numTrack
            case 1
                IOPort('Write',handle,triggerMOTLoad1);
            case 3
                IOPort('Write',handle,triggerMOTLoad3);
            case 4
                IOPort('Write',handle,triggerMOTLoad4);
            case 6
                IOPort('Write',handle,triggerMOTLoad6);
        end
    
        % MOT file
        motfile = locList(MOTlist(counter)).name;
        load(fullfile(locList(MOTlist(counter)).folder,motfile),'locs');
        counter = counter+1;
        
        %% MOVIE
        
        %% Present Objects  
        
        Screen('FillRect',window,backgroundColour); % drawing the target cues
        Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
        
        temp = ones(4, numDots); % pre-allocate temp
        for o=1:numDots % make a matrix of object locations, columns are different objects, rows are each object's xy coords
            temp(:,o)= [locs(1,1,o,1)+trackRect(1)-objSize; locs(1,2,o,1)+trackRect(2)-objSize; locs(1,1,o,1)+trackRect(1)+objSize; locs(1,2,o,1)+trackRect(2)+objSize];
        end
        Screen('FillOval',window,white,temp,objSize); % draw the objects
        
        Screen('FrameRect',window,frameCol,trackRect,qFrame);
        
        % draw targets
        
        if attend == 2
            temp = ones(4,length(targets));
            for t=1:length(targets)
                temp(:,t) = [locs(1,1,targets(t),1)+trackRect(1)-objSize; locs(1,2,targets(t),1)+trackRect(2)-objSize; locs(1,1,targets(t),1)+trackRect(1)+objSize; locs(1,2,targets(t),1)+trackRect(2)+objSize];
            end
            Screen('FillOval',window,red,temp,objSize);
        end
        
        % It seems to be preferable to make a matrix of object
        % locations and drawing them all at once rather than looping
        % through drawing each oval      
        
        Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]); % draw fixation box
        
        % draw TRACK or LISTEN
        Screen('TextSize', window, 36);
        if attend == 2
            Screen('DrawText', window, 'TRACK',xMid-73, yMid-52, blue);
        else
            Screen('DrawText', window, 'LISTEN',xMid-78, yMid+6, blue);
        end
        
        % present targets 300ms after the start of the audio. timing using 
        % audio instead of fixation presentation to ensure the MOT section
        % aligns precisely with the audiobook without altering the timing 
        % of any trial section (although this may slightly extend the ITI,
        % it is better to slightly alter the ITI than any other section of
        % the trial)
        targOnset = Screen('Flip',window, tStartAudio + fixlen + (trial-1)*trialDur);
        
        Screen('FillRect',window,backgroundColour);
        Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
        
        temp = [locs(1,1,o,1)+trackRect(1)-objSize; locs(1,2,o,1)+trackRect(2)-objSize; locs(1,1,o,1)+trackRect(1)+objSize; locs(1,2,o,1)+trackRect(2)+objSize];
        Screen('FillOval',window,white,temp,objSize);
        
        Screen('FrameRect',window,frameCol,trackRect,qFrame);
    
        % present first frame of the MOT movie
        movOnset = Screen('Flip',window, targOnset + targetDur);
        
        % send trigger at MOT onset
        IOPort('Write',handle,triggerMOTOnset);
            
        %% tracking movie begin
    
        for frame = 1:frameRate*trackDur
            
            Screen('FillRect',window,backgroundColour);
            Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
            
            temp = ones(4, numDots);
            for o=1:numDots
                temp(:,o)= [locs(1,1,o,frame)+trackRect(1)-objSize; locs(1,2,o,frame)+trackRect(2)-objSize; locs(1,1,o,frame)+trackRect(1)+objSize; locs(1,2,o,frame)+trackRect(2)+objSize];
            end
            Screen('FillOval',window,white,temp,objSize);
            
            Screen('FrameRect',window,frameCol,trackRect,qFrame);
            Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]); % draw fixation box
            
            Screen('Flip',window);
            
        end
    
        % send trigger at MOT offset
        IOPort('Write',handle,triggerMOTOffset);
        
        %% display probe
        Screen('FillRect',window,backgroundColour);
        Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
        
        temp = ones(4, numDots);
        for o=1:numDots
            temp(:,o)= [locs(1,1,o,frame)+trackRect(1)-objSize; locs(1,2,o,frame)+trackRect(2)-objSize; locs(1,1,o,frame)+trackRect(1)+objSize; locs(1,2,o,frame)+trackRect(2)+objSize];
        end
        Screen('FillOval',window,white,temp,objSize);
        
        Screen('FrameRect',window,frameCol,trackRect,qFrame);
        Screen('TextSize', window, 14);
        
        % if attend mot, query probes (one is target), otherwise query gist
        if attend == 2
            f = 1; %keep track of how many foils
            for p = 1:probeNum
                if p == corr_resp
                    temp = [locs(1,1,corr,frame)+trackRect(1)-objSize; locs(1,2,corr,frame)+trackRect(2)-objSize; locs(1,1,corr,frame)+trackRect(1)+objSize; locs(1,2,corr,frame)+trackRect(2)+objSize];
                    Screen('FillOval',window,blue,temp,objSize);
                    Screen('DrawText',window,num2str(p),temp(1,1)+objSize-4, temp(2,1)+objSize-9,white);
                else
                    temp = [locs(1,1,foils(f),frame)+trackRect(1)-objSize; locs(1,2,foils(f),frame)+trackRect(2)-objSize; locs(1,1,foils(f),frame)+trackRect(1)+objSize; locs(1,2,foils(f),frame)+trackRect(2)+objSize];
                    Screen('FillOval',window,blue,temp,objSize);
                    Screen('DrawText',window,num2str(p),temp(1,1)+objSize-4,temp(2,1)+objSize-9, white);
                    f = f+1;
                end
            end
    
            Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]); % draw fixation box
            
        else
            Screen('TextSize', window, 32);
            
            Screen('DrawText', window,'REPEAT?',xMid-60, yMid-23, blue);
            Screen('DrawText', window,'1|YES',xMid/2 -42, yMid+150, yellow);
            Screen('DrawText', window,'2|NO',xMid*1.5 - 33, yMid+150, yellow);
        end
            
        % present probes, with short pause
        probeOnset = Screen('Flip',window, movOnset + trackDur + pauseDur);
    
        % send trigger at probe screen
        IOPort('Write',handle,triggerResponseScreenOnset);
        
        %% get response
        
        % load ITI screen
        Screen('FillRect',window,backgroundColour);
        Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
        Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]); % draw fixation box
        
        % reset response variables
        keyPress = 0;
        respOnset = NaN;
        RT = 0;
        
        % Wait for keypress within response window
        while GetSecs <= probeOnset + respDur
            [pressed, now, keyCode] = KbCheck;
            
            if keyCode(escapeKey)
                ShowCursor;
                sca;
                PsychPortAudio('Close', pahandle);
                IOPort('CloseAll');
                return
            end
        
            if pressed
                pressedKeys = find(keyCode);
                validKeys = intersect(pressedKeys, kb(:,1));
        
                if ~isempty(validKeys)
                    keyPress = kb(kb(:,1) == validKeys(1), 2); % map to 1/2/3
                    respOnset = now;
                    RT = respOnset - probeOnset;
                    IOPort('Write',handle,triggerResponsePressOnset);
                    break % stop after first valid press
                end
            end
        end
        
        %% Show ITI screen while file things
        
        fixOn = Screen('Flip',window, probeOnset + respDur); % present fixation
        
        % if attending to MOT, match response to correct response
        % if attending to speech, match response to presence of repeat
        
        % Set correct response for LISTEN trials
        if attend == 1
            corr_resp = 2 - ismember(trial, allRepeatTrials);  % 1=YES, 2=NO
        end
        
        % Evaluate accuracy
        accuracy(trial) = (keyPress == corr_resp);

        % Save results            'Participant','Age','Block','Trial','Attend','MOT_file','Targets','Targets_idx','Num_dots','Audio_onset','Trial_onset','MOT_onset','Query_onset','ITI_Onset','Correct_response','Keypress','Keytime','Acc','RT
        data(1+trial,:) = [{participantNumber},{age},{sex},{block},{trial},{attend},{motfile},{numTrack},{targets},{numDots},{tStartAudio},{targOnset},{movOnset},{probeOnset},{fixOn},{corr_resp},{keyPress},{respOnset},{accuracy(trial)},{RT}];
        clear locs

        fprintf('\nBlock: %d, Trial: %d, Correct: %d', block,trial,accuracy(trial));
    end
    
    % Stop audio playback
    PsychPortAudio('Stop',pahandle);
    
    % Send trigger at sound offset
    IOPort('Write',handle,triggerSpeechOffset);
    
    WaitSecs(0.1);
    
    % send trigger to stop EEG recording
    IOPort('Write',handle,triggerEEGOffset);
    
    %% End screen

    % Save as .mat file
    logfile = sprintf('subj%02d_b%d.mat', participantNumber, block);
    % Build meta (store the assignments in the same file you already save)
    meta.participantNumber = participantNumber;
    meta.block             = block;
    meta.chapter           = chapter;     % 1..6 (or 7 for practice)
    if block == 7
        meta.audioName = 'test.wav';
    else
        meta.audioName = chapterList(chapter).name;
    end
    meta.MOTgroup          = MOTgroup;    % e.g., 'MOTlocs_3'
    save(logfile, 'data', 'meta');

    Screen('FillRect',window,backgroundColour);
    Screen('TextSize',window,40);
    finish = ('END');
    finishW = TextBounds(window, finish);
    Screen('DrawText',window,finish,xMid-(finishW(3)-finishW(1))/2,yMid, white);
    Screen('Flip',window);
    
    WaitSecs(3);
    
    %% Reset screens and audio
    
    % Clear the screen
    Screen('CloseAll');
    % Go back to normal priority
    Priority(0);
    % Makes it so characters typed do show up in the command window
    ListenChar(0);
    % Shows the cursor
    ShowCursor();
    % Close the audio device
    PsychPortAudio('Close', pahandle);
    
    IOPort('CloseAll');

catch ME
    ShowCursor;
    sca;
    Priority(0);
    IOPort('CloseAll');
    PsychPortAudio('Stop',pahandle);
    PsychPortAudio('Close', pahandle);
    top = ME.stack(1);
    fprintf(2,'Error in (line %d): %s\n', ...
        top.line, ME.message);
    rethrow(ME)
end
end

function [usedChapters, usedMOTgroups] = get_used_assignments(direxp, participantNumber)
    usedChapters  = [];
    usedMOTgroups = strings(0,1);

    pat = fullfile(direxp, sprintf('subj%02d_b*.mat', participantNumber));
    files = dir(pat);

    for k = 1:numel(files)
        S = load(fullfile(files(k).folder, files(k).name));
        if isfield(S, 'meta')
            % Chapter: only count 1..6 (ignore practice row 7)
            if isfield(S.meta, 'chapter') && ~isempty(S.meta.chapter) ...
               && isnumeric(S.meta.chapter) && isscalar(S.meta.chapter) ...
               && S.meta.chapter >= 1 && S.meta.chapter <= 6
                usedChapters(end+1,1) = S.meta.chapter; %#ok<AGROW>
            end

            % MOT group: accept char or string; only count MOTlocs_1..6
            if isfield(S.meta, 'MOTgroup') && ~isempty(S.meta.MOTgroup) ...
               && (ischar(S.meta.MOTgroup) || isstring(S.meta.MOTgroup))
                mg = string(S.meta.MOTgroup);
                if startsWith(mg,"MOTlocs_") && mg ~= "MOTlocs_7"
                    usedMOTgroups(end+1,1) = mg; %#ok<AGROW>
                end
            end
        end
    end

    usedChapters  = unique(usedChapters(:))';
    usedMOTgroups = unique(usedMOTgroups(:))';
end
