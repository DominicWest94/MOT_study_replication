function dw_sentenceMemory
%% Sentence Recognition + Confidence Rating (figure-based)
% Dominic West / Dec 2025
%
% Stage 1: YES/NO recognition using left/right arrow keys
% Stage 2: Confidence using number keys 1–5
% Sentences are participant-specific and loaded from:
%   subjXXX_sentencePool.mat
%
% Output: subjXXX_sentenceMemory.mat

try
    %% -------------------------
    %  Participant Info
    %  -------------------------
    prompt = {'Participant #', 'Age', 'Sex'};
    answer = inputdlg(prompt, 'Sentence Memory Task', 1, {'99','23','F'});
    if isempty(answer), return; end

    participantNumber = str2double(answer{1});
    age               = str2double(answer{2});
    sex               = answer{3};

    %% -------------------------
    %  Load sentence pool for this participant
    %  -------------------------
    subjRoot = fullfile('/Users/dominicwest/Documents/Code/MOT_study_replication/matlab/experiment/output_data_behavioural', sprintf('subj%02d', participantNumber));

    poolFile = fullfile(subjRoot, sprintf('subj%02d_sentencePool.mat', participantNumber));
    if ~isfile(poolFile)
        error('Sentence pool file not found: %s. Run dw_buildSentencePool first.', poolFile);
    end

    S = load(poolFile);

    % Expect variables: audioSent, load1Sent, load3Sent, load4Sent, load6Sent, foilSent
    requiredFields = {'audioSent','load1Sent','load3Sent','load4Sent','load6Sent','foilSent'};
    for f = 1:numel(requiredFields)
        if ~isfield(S, requiredFields{f})
            error('Field %s is missing from %s', requiredFields{f}, poolFile);
        end
    end

    audioSent = S.audioSent;
    load1Sent = S.load1Sent;
    load3Sent = S.load3Sent;
    load4Sent = S.load4Sent;
    load6Sent = S.load6Sent;
    foilSent  = S.foilSent;

    %% -------------------------
    %  Build trials from pool
    %  -------------------------
    trials = struct('condition', {}, 'sentence', {}, 'isOld', {});
    addBlock('AUDIO', audioSent, 1);
    addBlock('LOAD1', load1Sent, 1);
    addBlock('LOAD3', load3Sent, 1);
    addBlock('LOAD4', load4Sent, 1);
    addBlock('LOAD6', load6Sent, 1);
    addBlock('FOIL',  foilSent,  0);

    nTrials = numel(trials);

    if nTrials == 0
        error('No sentences available for this participant in %s', poolFile);
    end

    % Randomise trial order
    rng(participantNumber + 1000, 'twister');
    trials = trials(randperm(nTrials));

    % --------- FOR TESTING ONLY (run a subset of trials) ---------
    % If you want to quickly test the script, uncomment these lines:
    % maxTestTrials = 3;
    % nTrials = min(nTrials, maxTestTrials);
    % trials  = trials(1:nTrials);
    % -------------------------------------------------------------

    %% -------------------------
    %  Figure Setup (classic figure)
    %  -------------------------
    fig = figure('Color',[0.2 0.2 0.2], ...
                 'MenuBar','none', ...
                 'ToolBar','none', ...
                 'NumberTitle','off', ...
                 'Name','Sentence Task', ...
                 'WindowKeyPressFcn',[]);
    set(fig,'Units','normalized','Position',[0 0 1 1]); % fill screen-ish

    % Background axes (hidden)
    ax = axes('Parent',fig, ...
              'Position',[0 0 1 1], ...
              'Visible','off'); %#ok<NASGU>

    % Sentence text (upper-centre)
    hSentence = annotation(fig,'textbox', ...
        'Units','normalized', ...
        'Position',[0.1 0.45 0.8 0.3], ... % top-middle region
        'String','', ...
        'Color',[1 1 1], ...
        'FontSize',28, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', ...
        'EdgeColor','none', ...
        'Interpreter','none');

    % Prompt / questions (below sentence)
    hPrompt = annotation(fig,'textbox', ...
        'Units','normalized', ...
        'Position',[0.1 0.1 0.8 0.3], ... % below sentence
        'String','', ...
        'Color',[1 1 1], ...
        'FontSize',24, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','top', ...
        'EdgeColor','none', ...
        'Interpreter','none');

    %% -------------------------
    %  Instructions
    %  -------------------------
    instr = sprintf([ ...
        'Sentence Memory Test\n\n' ...
        '1) Read the sentence.\n' ...
        '2) Press LEFT ARROW (YES) or RIGHT ARROW (NO).\n' ...
        '3) Then rate your confidence using keys 1–5.\n\n' ...
        'Press ANY KEY to begin.' ]);

    set(hSentence,'String',instr);
    set(hPrompt,'String','');
    drawnow;

    % Wait for ANY key to start
    startFlag = false;
    set(fig,'WindowKeyPressFcn',@(src,event) startKey(event));

    while ishghandle(fig) && ~startFlag
        pause(0.01);
    end

    if ~ishghandle(fig)
        % Window was closed manually
        return;
    end

    % disable callback after continuing
    set(fig,'WindowKeyPressFcn',[]);

    %% -------------------------
    %  Data storage
    %  -------------------------
    dataHeader = {'Participant','Age','Sex','Trial',...
                  'Condition','Sentence','IsOld',...
                  'CorrectResp','RespLabel','RT1',...
                  'Confidence','RT2',...
                  'Accuracy','Timestamp'};

    data = cell(nTrials+1, numel(dataHeader));
    data(1,:) = dataHeader;

    %% -------------------------
    %  TRIAL LOOP
    %  -------------------------
    for t = 1:nTrials

        if ~ishghandle(fig)
            error('Figure was closed during the task.');
        end

        tr = trials(t);

        %% Stage 1 — Recognition (YES/NO)
        set(hSentence,'String',tr.sentence);

        % Question 1 under the sentence
        q1 = sprintf([ ...
            'Did you hear this?\n\n' ...
            'YES (Left arrow)                      NO (Right arrow)']);
        set(hPrompt,'String',q1);
        drawnow;

        % Correct response: YES for old sentences, NO for foils
        if tr.isOld == 1
            correctResp = 1;   % YES
        else
            correctResp = 2;   % NO
        end

        responded1  = false;
        respLabel1  = '';
        RT1         = NaN;

        startTime1 = tic;
        set(fig,'WindowKeyPressFcn',@(src,event) recogKey(event));

        while ishghandle(fig) && ~responded1
            pause(0.01);
        end

        if ~ishghandle(fig)
            error('Window closed during recognition.');
        end

        %% Stage 2 — Confidence (1–5)
        set(fig,'WindowKeyPressFcn',[]);  

        q2 = sprintf([ ...
            'How confident are you in your answer?\n\n' ...
            '1   2   3   4   5\n' ...
            'Not confident          Very confident']);
        set(hPrompt,'String',q2);
        drawnow;

        responded2 = false;
        confidence = NaN;
        RT2        = NaN;

        startTime2 = tic;
        set(fig,'WindowKeyPressFcn',@(src,event) confKey(event));

        while ishghandle(fig) && ~responded2
            pause(0.01);
        end

        if ~ishghandle(fig)
            error('Window closed during confidence rating.');
        end

        %% Compute accuracy
        if strcmp(respLabel1,'YES')
            respCode1 = 1;
        else
            respCode1 = 2;
        end

        acc = double(respCode1 == correctResp);

        %% Save trial
        data(t+1,:) = {participantNumber, age, sex, t, ...
                       tr.condition, tr.sentence, tr.isOld, ...
                       correctResp, respLabel1, RT1, ...
                       confidence, RT2, ...
                       acc, datetime("now")};

        %% ITI (500 ms)
        set(fig,'WindowKeyPressFcn',[]);
        set(hSentence,'String','');
        set(hPrompt,'String','');
        drawnow;
        pause(0.5);

    end

    %% End message
    if ishghandle(fig)
        set(hSentence,'String','End of task. Thank you!');
        set(hPrompt,'String','');
        drawnow;
        pause(2);
    end

    %% Save & close
    outfile = fullfile(subjRoot, sprintf('subj%03d_sentenceMemory.mat', participantNumber));
    save(outfile, 'data');

    if ishghandle(fig)
        close(fig);
    end

catch ME
    disp(getReport(ME,'extended'));

    % cleanup
    if exist('fig','var') && ishghandle(fig)
        close(fig);
    end

    rethrow(ME);
end

%% ============================================================
%  Nested helper functions
%% ============================================================

    function addBlock(cond, list, isOld)
        idx0 = numel(trials);
        for i = 1:numel(list)
            trials(idx0+i).condition = cond;
            trials(idx0+i).sentence  = list{i};
            trials(idx0+i).isOld     = isOld;
        end
    end

    function startKey(event)
        key = event.Key;
        if strcmp(key,'escape')
            if ishghandle(fig), close(fig); end
            error('Experiment aborted at instructions screen.');
        end
        % any other key continues
        startFlag = true;
    end

    function recogKey(event)
        key = event.Key;
        switch key
            case 'leftarrow'
                respLabel1 = 'YES';
                RT1        = toc(startTime1);
                responded1 = true;

            case 'rightarrow'
                respLabel1 = 'NO';
                RT1        = toc(startTime1);
                responded1 = true;

            case 'escape'
                if ishghandle(fig), close(fig); end
                error('Experiment aborted during recognition.');
        end
    end

    function confKey(event)
        key = event.Key;
        if ismember(key, {'1','2','3','4','5'})
            confidence = str2double(key);
            RT2        = toc(startTime2);
            responded2 = true;
        elseif strcmp(key,'escape')
            if ishghandle(fig), close(fig); end
            error('Experiment aborted during confidence rating.');
        end
    end

end
