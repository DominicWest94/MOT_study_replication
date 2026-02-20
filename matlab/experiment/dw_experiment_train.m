 function dw_experiment_train

%% Multiple Object Tracking (MOT) Training
% Dominic West/dominicwest94@gmail.com/May 2025 (Based on a script kindly
% supplied by Harrison Ritz/harrison.ritz@gmail.com)

% Train participants on MOT task; based on Wilson, D., O'Grady, M., &
% Rajsic, J. (2013). Multiple Object Tracking: Support for Hemispheric
% Independence. Journal of Vision, 13(9), 1295-1295.

%%% PROCEDURE %%%
% Participants practice MOT over 24 trials. On the first 12 trials, the
% number of targets began at one and increased (to three, four, and six)
% after each correct tracking response, or it decreased after each
% incorrect response. On the last 12 trials, the number of targets on each
% trial was randomly selected (from one, three, four, or six).

%% Clear the workspace and set directories
clearvars;
close all;
sca;

direxp = 'C:\Experiments\Dominic\exp2';
cd(direxp);
MOTFolder = '\stimuli\MOTlocs_train';

%% Get participant info
valid_file = 0;
while valid_file == 0
    
    prompt = {'Participant #'};
    answer = inputdlg(prompt, 'MOT Training Set-up',1,{'99'});
    participantNumber = str2double(answer{1});
    
    file = sprintf('targ_train_%d.csv', participantNumber);
    
    valid_file = 1;
    if fopen(file) ~= -1
        choice = questdlg('You are about to overwrite an existing data file. Are you sure you want to do this?','Error','Yes','No','No');
        if strcmp(choice, 'No') == 1
            return
        end
    end
end

[resultsFile, ~] = fopen(file,'wt');
fprintf(resultsFile,'pt,Trial,targets,num Dots,MOT filename,Correct Response,key press,acc,rt,block start,MOTstart,MOTduration\n'); % make a header row for subject file

%% Open screen, reset random
% Screen('Preference','SkipSyncTests', 1);
% window=Screen('OpenWindow', 0, [], [0,0,1024,768]);
window=Screen('OpenWindow', 1, []); % 1 = participant monitor, 2 = experimenter monitor

% Set the maximum priority number
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

rng(participantNumber,'twister'); % resets the random number generator, using seed based on participant number

%% Experiment Variables

% dots
trials = 24;            % number of trials
probeNum = 3;           % number of probes
track = [1,3,4,6];      % number of targets
ntr = 1;                % target level

% timing
trackDur = 5;           % duration of tracking in seconds
targetDur = 1.8;       % duration of target cues
pauseDur =  0.1;      % time between end of movie and probe
respDur = 2.8;          % duration of response window
fixlen = 0.3;          % pre-que fixation window (theres some loading overhead)
trialDur = 10;

% display
trackSize = [700 700];  % size of tracking space in total
fixSize = 4;            % size of the fixation box (well, half of it - the distance from the middle to edge horizontally/vertically)
qFrame = 1;             % width of frame around each tracking quadrant
objSize = 14;           % size, in pixels, of dot
dist = 12;              % number of distractors
frameRate = 60;         % frames per second

% screen stuff
rect = Screen('Rect',window); % DW - removed divide by 1
xMid = rect(3)/2;
yMid = rect(4)/2;
white = [255,255,255];
black = [0,0,0];
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
kb1 = KbName('1!');
kb2 = KbName('2@');
kb3 = KbName('3#');
kb = vertcat([kb1,1],[kb2,2],[kb3,3]);
accuracy = zeros(1,trials);

% randomize the order of the MOT movies at each speed and the correct response
stim = randperm(trials); % randomize the order of the mot files
randresp = randsample(probeNum,trials,1); % randomize correct response

% number of dots to track
numTrack = track(ntr);

%% Start Screen
Screen('FillRect',window,backgroundColour);
Screen('TextSize', window, 21);
inst1 = 'You will see several dots and be asked to TRACK the red ones';
inst1W=TextBounds(window,inst1);
inst2 = 'When they stop moving select the one you were tracking with "1", "2", or "3"';
inst2W=TextBounds(window,inst2);
inst3 = 'Keep your eyes on the centre square while the dots are moving';
inst3W=TextBounds(window,inst3);
inst4 = 'Press any key to start';
inst4W=TextBounds(window,inst4);

Screen('DrawText',window,inst1,xMid-(inst1W(3)-inst1W(1))/2,yMid-100,white);
Screen('DrawText',window,inst2,xMid-(inst2W(3)-inst2W(1))/2,yMid-50,white);
Screen('DrawText',window,inst3,xMid-(inst3W(3)-inst3W(1))/2,yMid-0,white);
Screen('DrawText',window,inst4,xMid-(inst4W(3)-inst4W(1))/2,yMid+50,white);

Screen('Flip',window);
KbStrokeWait;

blockStart = GetSecs;

%% Trials
for tr = 1:trials    
    %% set up during fixation cross
    Screen('FillRect',window,backgroundColour);
    Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
    Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]); % draw fixation box
    fixOn = Screen('Flip',window, blockStart + (tr-1)*trialDur); % present fixation
    
    numDots = dist + numTrack;     % number of dots in total
    
    %% get file & correct response
    ftarg = sprintf('MOT_sp1_%.3d.mat',stim(tr));
    corr_resp = randresp(tr);
    
    %% set targets, queried target, queried foils
    targets = randsample(numDots,numTrack);
    corr = datasample(targets,1);
    foils = randsample(setxor(1:numDots,targets), probeNum-1);
    
    load(fullfile(direxp,MOTFolder,ftarg));
    
    %% MOVIE
    
    %% Present Objects
    Screen('FillRect',window,backgroundColour); % drawing the target cues
    Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
    
    temp = ones(4, numDots); %pre-allocate temp
    for o=1:numDots% make a matrix of object locations, columns are different objects, rows are each object's xy coords
        temp(:,o)= [locs(1,1,o,1)+trackRect(1)-objSize; locs(1,2,o,1)+trackRect(2)-objSize; locs(1,1,o,1)+trackRect(1)+objSize; locs(1,2,o,1)+trackRect(2)+objSize];
    end
    Screen('FillOval',window,white,temp,objSize); %draw the objects
    Screen('FrameRect',window,frameCol,trackRect,qFrame);
    
    %% Draw Targets
    temp = ones(4,length(targets));
    for t=1:length(targets)
        temp(:,t) = [locs(1,1,targets(t),1)+trackRect(1)-objSize; locs(1,2,targets(t),1)+trackRect(2)-objSize; locs(1,1,targets(t),1)+trackRect(1)+objSize; locs(1,2,targets(t),1)+trackRect(2)+objSize];
    end
    Screen('FillOval',window,red,temp,objSize);
    
    Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]); % draw fixation box
    
    Screen('TextSize', window, 36); % draw 'TRACK'
    Screen('DrawText', window, 'TRACK',xMid-73, yMid-52, blue);
        
    tTargetsOn = Screen('Flip',window,fixOn+fixlen); % present targets after 300 ms
    
    Screen('FillRect',window,backgroundColour);
    Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
    
    temp = [locs(1,1,o,1)+trackRect(1)-objSize; locs(1,2,o,1)+trackRect(2)-objSize; locs(1,1,o,1)+trackRect(1)+objSize; locs(1,2,o,1)+trackRect(2)+objSize];
    Screen('FillOval',window,white,temp,objSize);
    
    Screen('FrameRect',window,frameCol,trackRect,qFrame);
    movStart = Screen('Flip',window,tTargetsOn + targetDur);
    
    %% tracking movie begin
    for frame=1:frameRate*trackDur
        
        Screen('FillRect',window,backgroundColour);
        Screen('FillRect',window,black,[xMid-trackSize(1)/2,yMid-trackSize(2)/2,xMid+trackSize(1)/2,yMid+trackSize(2)/2]);
        
        temp = ones(4, numDots);
        for o=1:numDots
            temp(:,o)= [locs(1,1,o,frame)+trackRect(1)-objSize; locs(1,2,o,frame)+trackRect(2)-objSize; locs(1,1,o,frame)+trackRect(1)+objSize; locs(1,2,o,frame)+trackRect(2)+objSize];
        end
        Screen('FillOval',window,white,temp,objSize);
        
        Screen('FrameRect',window,frameCol,trackRect,qFrame);
        Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]); % draw fixation box
        
        % NOTE % - removed by DW
        % 'flip' timestamping has been very unreliable, this is to
        % compensate for this.. basically I use GetSecs/WaitSecs to trigger an
        % immediate 'Flip' call. Since 'Flip' and GetSecs take some time, I sample
        % their execution duration at the beginning of the experiment, and subtract this from subsequent
        % frames. I've timed my trial durations, they seem to be
        % very accurate for the most part. If you find a better way to do this
        % please let me know at harrison.ritz@gmail.com
        
        Screen('Flip',window);
        
    end
    
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
    
    f = 1; % keep track of how many foils
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
    Screen('FillRect',window,fixCol,[xMid-fixSize,yMid-fixSize,xMid+fixSize,yMid+fixSize]);
    
    probeOnset = Screen('Flip',window, movStart + trackDur + pauseDur);
    
    %% get response
    respcount = 1;
    clear key
    clear time
    
    startTime = GetSecs;
    [~,nowTime,keyCode] = KbCheck; % check for a key press
        
    while nowTime < startTime + respDur       
        [~,buttonTime,keyCode,~] = KbCheck; % check for a keypress
        
        if sum(keyCode)> 0
            key(respcount,:) = keyCode;
            time(respcount) = buttonTime;
            respcount = respcount+1;
        end     
        
        nowTime = GetSecs;
        
    end
    
    if respcount < 2
        RT = 0;
        key = 1;
        keyPress = 0;
    else
        RT = time(end)-startTime;
        keyPress = kb(kb==find(key(end,:),1),2);
    end
    
    % match response to correct response
    
    if find(key(end,:),1) == kb(corr_resp)
        accuracy(tr) = 1;
    else
        accuracy(tr) = 0;
    end
    
    movDur = probeOnset-movStart;
    fprintf(resultsFile,'%d,%d,%d,%d,%s,%d,%d,%d,%.4f,%.4f,%.4f,%.4f\n', participantNumber,tr,numTrack,numDots,ftarg,corr_resp,keyPress,accuracy(tr),RT,blockStart,movStart,movDur);
    clear locs
    
    % if last trial incorrect, bring speed down one level. if correct,
    % increase one level (adaptive staircase)
    if tr > 1
        if tr <= 12
            
            if ~accuracy(tr) && numTrack > track(1)
                ntr = ntr-1;
                
            elseif accuracy(tr) && numTrack < track(end)
                ntr = ntr+1;                    
            end
            numTrack = track(ntr);
        else
            old = numTrack;
            numTrack = track(randi([1,length(track)]));
            while numTrack == old
                numTrack = track(randi([1,length(track)]));
            end
        end
    end
    fprintf('\nTrial: %d, Correct: %d', ...
        tr,accuracy(tr));

end

fclose('all');

Screen('FillRect',window,backgroundColour);
Screen('TextSize',window,40);
finish = ('END');
finishW = TextBounds(window, finish);
Screen('DrawText',window,finish,xMid-(finishW(3)-finishW(1))/2,yMid, white);
Screen('Flip',window);

WaitSecs(3);

%% Reset screens

% Close the screen
Screen('CloseAll');

% Go back to normal priority
Priority(0);

% Makes it so characters typed do show up in the command window
ListenChar(0);

% Shows the cursor
ShowCursor();

end
