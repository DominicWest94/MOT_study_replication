function dw_buildSentencePool(participantNumber)
% dw_buildSentencePool
%
% Build per-participant sentence lists for the sentence memory task.
%
% For the given participant:
%  - Reads subjXXX_b*.mat block logs (data, meta).
%  - Uses meta.chapter to load chapter-level stim files.
%  - Uses stim.orth, stim.wordOnsets, stim.wordOffsets (64 Hz) to segment
%    the transcript into sentences.
%  - Maps sentences to experimental trials based on timing.
%  - Assigns each sentence to one of: AUDIO, LOAD1, LOAD3, LOAD4, LOAD6.
%  - Only includes sentences that fall fully within a single trial window.
%  - Samples up to 10 sentences per condition.
%  - Adds hard-coded foil sentences.
%  - Saves subjXXX_sentencePool.mat with:
%        audioSent, load1Sent, load3Sent, load4Sent, load6Sent, foilSent.

%% -------------------------
%  USER: PATHS & SETTINGS
%  -------------------------

% behavioural data from exp
rootDir = '/Users/dominicwest/Documents/Uni/PhD/MATLAB/MOT_study_replication';
logDir = fullfile(rootDir, sprintf('/output_data_behavioural/subj%02d', participantNumber));

% chapter stim files
stimDir = fullfile(rootDir, '/modelling');

% define how to map chapter numbers to stim files.
% For example, if files are 'chapter1_stim.mat', 'chapter2_stim.mat', etc:
chapterStimPattern = fullfile(stimDir, 'audio_%d_new_GPT.mat');

% Sample rate of wordOnsets/Offsets (Hz)
fs = 64;

% How many sentences per condition to sample
nPerCond = 10;

%% -------------------------
%  HARD-CODED FOIL SENTENCES
%  -------------------------
% USER: fill these with 10 foil sentences from a chapter not used in exp
foilSent = { ...
    'and I am sure that it was really the sob of a woman' ...
    'He rang the bell and asked Barrymore whether he could account for our experience' ...
    'She was a large, impassive, heavy-featured woman with a stern set expression of mouth' ...
    'But her telltale eyes were red and glanced at me from between swollen lids' ...
    'It was he who had been the first to discover the body of Sir Charles' ...
    'The cabman had described a somewhat shorter man, but such an impression might easily have been erroneous' ...
    'Sir Henry had numerous papers to examine after breakfast, so that the time was propitious for my excursion' ...
    'Well, surely his own wife ought to know where he is' ...
    'Was he the agent of others or had he some sinister design of his own?' ...
    'Suddenly my thoughts were interrupted by the sound of running feet behind me'};

%% -------------------------
%  Locate block log files
%  -------------------------
pat = fullfile(logDir, sprintf('subj%02d_b*.mat', participantNumber));
files = dir(pat);

if isempty(files)
    error('No block files found for participant %02d in %s', participantNumber, logDir);
end

%% -------------------------
%  Storage for sentences by condition
%  -------------------------
audioList = {};
load1List = {};
load3List = {};
load4List = {};
load6List = {};

% Cache for chapter sentence metadata so we only segment once per chapter
maxChap = 20; % arbitrary upper bound
chapterSentences = cell(maxChap, 1);  % each entry will be a struct array

%% -------------------------
%  Process each block file
%  -------------------------
for k = 1:numel(files)

    blockFile = fullfile(files(k).folder, files(k).name);
    S = load(blockFile);

    if ~isfield(S, 'meta') || ~isfield(S, 'data')
        warning('File %s missing meta or data. Skipping.', files(k).name);
        continue;
    end

    meta = S.meta;
    data = S.data;

    % Skip practice blocks / non-main chapters
    if ~isfield(meta, 'chapter') || isempty(meta.chapter) || meta.chapter < 1 || meta.chapter > 6
        continue;
    end
    chapter = meta.chapter;

    % Extract data table (skip header row)
    if size(data,1) < 2
        warning('File %s has no trial rows. Skipping.', files(k).name);
        continue;
    end

    dat = data(2:end,:);  % cell array, one row per trial

    % Columns (from original experiment script):
    % 1 Participant, 2 Age, 3 Sex, 4 Block, 5 Trial,
    % 6 Attend, 7 MOT_file, 8 Targets(#), 9 Targets_idx, 10 Num_dots,
    % 11 Audio_onset, 12 Trial_onset, 13 MOT_onset, 14 Query_onset,
    % 15 ITI_Onset, 16 Correct_response, 17 Keypress, 18 Keytime, 19 Acc, 20 RT

    trialNum = cell2mat(dat(:,5));
    attend   = cell2mat(dat(:,6));  % 1=LISTEN, 2=TRACK
    numTrack = cell2mat(dat(:,8));  % # of tracked targets (1,3,4,6)
    audioOnset = cell2mat(dat(:,11));  % Audio_onset (should be same for all trials in block)
    motOnset   = cell2mat(dat(:,13));  % MOT_onset per trial

    nTrialsBlock = numel(trialNum);

    % Build per-trial condition labels
    trialCond = cell(nTrialsBlock,1);
    for t = 1:nTrialsBlock
        if attend(t) == 1
            trialCond{t} = 'AUDIO';
        else
            switch numTrack(t)
                case 1
                    trialCond{t} = 'LOAD1';
                case 3
                    trialCond{t} = 'LOAD3';
                case 4
                    trialCond{t} = 'LOAD4';
                case 6
                    trialCond{t} = 'LOAD6';
                otherwise
                    % Unexpected load; you can decide how to handle this
                    trialCond{t} = 'UNKNOWN';
            end
        end
    end

    % Compute per-trial time windows in audiobook time (seconds)
    % Use MOT_onset relative to Audio_onset; each trial window is 5 seconds long.
    if any(audioOnset ~= audioOnset(1))
        warning('Audio_onset varies across trials in %s; using the first value.', files(k).name);
    end
    audio0 = audioOnset(1);  % reference: audiobook start time
    
    % Start and end of the 5 s MOT window in audiobook time
    windowDurSec = 5.0;  % duration of interest per trial (MOT tracking window)
    
    trialStartSec = motOnset - audio0;              % in seconds from audiobook start
    trialEndSec   = trialStartSec + windowDurSec;   % 5 s later

    %% -------------------------
    %  Load & segment chapter sentences (if not already cached)
    %  -------------------------
    if chapter > numel(chapterSentences) || isempty(chapterSentences{chapter})
        % Need to load and segment this chapter

        stimFile = sprintf(chapterStimPattern, chapter);  % e.g. chapter1_stim.mat
        if ~isfile(stimFile)
            error('Stim file %s for chapter %d not found.', stimFile, chapter);
        end

        T = load(stimFile);
        if ~isfield(T, 'stim')
            error('Stim file %s does not contain ''stim'' struct.', stimFile);
        end
        stim = T.stim;

        if ~isfield(stim,'orth') || ~isfield(stim,'wordOnsets') || ~isfield(stim,'wordOffsets')
            error('stim struct in %s missing orth/wordOnsets/wordOffsets.', stimFile);
        end

        chapterSentences{chapter} = segmentSentencesFromStim(stim, fs);
    end

    sentStruct = chapterSentences{chapter};

    %% -------------------------
    %  Map sentences to trials (condition labels)
    %  -------------------------
    for sIdx = 1:numel(sentStruct)
        tStart = sentStruct(sIdx).tStartSec;
        tEnd   = sentStruct(sIdx).tEndSec;

        % Find trials where the sentence falls fully within the trial window
        idxTrial = find(trialStartSec <= tStart & trialEndSec >= tEnd);

        if numel(idxTrial) ~= 1
            % Either no clear trial or ambiguous overlap; skip this sentence
            continue;
        end

        condLabel = trialCond{idxTrial};

        switch condLabel
            case 'AUDIO'
                audioList{end+1,1} = sentStruct(sIdx).text;
            case 'LOAD1'
                load1List{end+1,1} = sentStruct(sIdx).text;
            case 'LOAD3'
                load3List{end+1,1} = sentStruct(sIdx).text;
            case 'LOAD4'
                load4List{end+1,1} = sentStruct(sIdx).text;
            case 'LOAD6'
                load6List{end+1,1} = sentStruct(sIdx).text;
            otherwise
                % UNKNOWN or other; ignore
        end
    end
end

%% -------------------------
%  Deduplicate sentence lists (optional but sensible)
%  -------------------------
audioList = unique(audioList);
load1List = unique(load1List);
load3List = unique(load3List);
load4List = unique(load4List);
load6List = unique(load6List);

%% -------------------------
%  Sample up to nPerCond sentences per condition
%  -------------------------
rng(participantNumber + 2000, 'twister');  % deterministic sampling per participant

audioSent = sampleUpToN(audioList, nPerCond);
load1Sent = sampleUpToN(load1List, nPerCond);
load3Sent = sampleUpToN(load3List, nPerCond);
load4Sent = sampleUpToN(load4List, nPerCond);
load6Sent = sampleUpToN(load6List, nPerCond);

%% -------------------------
%  Save sentence pool
%  -------------------------
outFile = fullfile(logDir, sprintf('subj%02d_sentencePool.mat', participantNumber));
save(outFile, 'audioSent','load1Sent','load3Sent','load4Sent','load6Sent','foilSent');

fprintf('Saved sentence pool for subj%02d to %s\n', participantNumber, outFile);

end % main function


%% ========================================================================
%  Helper: segmentSentencesFromStim
%  ========================================================================
function sentences = segmentSentencesFromStim(stim, fs)
% Segment a chapter transcript into "sentence-like" chunks
% based on time and word count (no punctuation available).
%
% stim.orth       : cell array {N x 1}, each entry a quoted word.
% stim.wordOnsets : 1 x N double, onset in samples (@ fs)
% stim.wordOffsets: 1 x N double, offset in samples (@ fs)
%
% sentences is a struct array with fields:
%   .text      : concatenated words
%   .tStartSec : onset (sec)
%   .tEndSec   : offset (sec)

orth   = stim.orth;
onsets = stim.wordOnsets;
offsets= stim.wordOffsets;

N = numel(orth);
if N == 0
    sentences = struct('text',{},'tStartSec',{},'tEndSec',{});
    return;
end

% Clean words: remove outer double quotes, keep apostrophes
cleanWords = cell(N,1);
for i = 1:N
    w = orth{i};
    w = strtrim(w);
    if numel(w) >= 2 && w(1) == '"' && w(end) == '"'
        w = w(2:end-1);       % strip leading/trailing "
    else
        w(w == '"') = [];     % safety: remove any stray "
    end
    cleanWords{i} = w;
end

% Parameters for chunking
minWords    = 5;    % minimum words in a chunk
maxWords    = 20;   % hard cap on words in a chunk
minDurSec   = 1.5;  % minimum duration (sec)
maxDurSec   = 5.0;  % maximum duration (sec)
gapThreshSec= 0.75; % if gap between words > this, start new chunk

sentences = struct('text',{},'tStartSec',{},'tEndSec',{});

startIdx = 1;

while startIdx <= N

    % Skip tokens that are effectively empty (e.g. "")
    while startIdx <= N && (isempty(cleanWords{startIdx}) || all(cleanWords{startIdx} == ' '))
        startIdx = startIdx + 1;
    end
    if startIdx > N
        break;
    end

    % Start a new chunk here
    endIdx = startIdx;
    tStartSec = onsets(startIdx) / fs;

    while endIdx < N

        nextIdx = endIdx + 1;

        % Skip empty tokens when extending
        while nextIdx <= N && (isempty(cleanWords{nextIdx}) || all(cleanWords{nextIdx} == ' '))
            nextIdx = nextIdx + 1;
        end

        if nextIdx > N
            break;
        end

        tEndSec   = offsets(endIdx) / fs;
        nextOnset = onsets(nextIdx) / fs;

        durSec    = tEndSec - tStartSec;
        gapSec    = nextOnset - tEndSec;
        nWords    = nextIdx - startIdx + 1;

        % Decide whether to extend or stop
        if durSec >= maxDurSec ...
                || gapSec > gapThreshSec ...
                || nWords > maxWords
            break;  % close current chunk at endIdx
        else
            endIdx = nextIdx; % extend chunk
        end
    end

    % Finalise chunk
    tEndSec = offsets(endIdx) / fs;
    chunkWords = cleanWords(startIdx:endIdx);

    % Remove empty words in the chunk
    mask = cellfun(@(s) ~isempty(s) && ~all(s==' '), chunkWords);
    chunkWords = chunkWords(mask);

    if ~isempty(chunkWords)
        nChunkWords = numel(chunkWords);
        durSec      = tEndSec - tStartSec;

        % Only keep reasonably sized chunks
        if nChunkWords >= minWords && durSec >= minDurSec
            S.text      = strtrim(strjoin(chunkWords, ' '));
            S.tStartSec = tStartSec;
            S.tEndSec   = tEndSec;
            sentences(end+1) = S; %#ok<AGROW>
        end
    end

    % Move on to the next chunk
    startIdx = endIdx + 1;
end

end

%% ========================================================================
%  Helper: sampleUpToN
%  ========================================================================
function outList = sampleUpToN(inList, N)
% Sample up to N elements from inList (cell array of strings).
% If fewer than N available, return all of them.

inList = inList(:);
nAvail = numel(inList);

if nAvail == 0
    outList = {};
elseif nAvail <= N
    outList = inList;
else
    idx = randperm(nAvail, N);
    outList = inList(idx);
end

end
