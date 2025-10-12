function MOT_maker

%% makes MOT stimuli
% changes the speed from 1 px/frame to n px/frame to suit conditions
% Harrison Ritz 2015


%% parameters
frameRate = 0.0167; % frame duration (sec), default 60 fps
trackSize = [700 700]; % screen size
trackDur = 5; % length of stimuli in seconds
movieLength = round(trackDur / frameRate)+1; % length of stim in frames

conditions = 1; % # of conditions
trials = 6; % # of MOTs per conditions
levels = 1; % # of speed levels

numDots = 18; % total # of objects
objSize = 14; % size of the objects
angleSD = 10;    % standard deviation of motion perturbations that occur each frame
objBuffer = 40;  % distance in pixels around an object that another object cannot enter

w = 0; % do not make a gif


%% stim builder

for l = 1:levels % for each speed level
    
    for t = 1: trials/levels*conditions % for all trials at a speed
        
        [~, locs] = MOTmovie(movieLength,numDots,trackSize,l,angleSD,objSize,objBuffer,w);
        save(sprintf('MOT_sp%d_%.3d',l,t),'locs')
        
    end
    
end





end




