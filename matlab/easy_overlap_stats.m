function [features, stats] = easy_overlap_stats(folder, options)
%EASY_OVERLAP_STATS  Compute overlap statistics for annotators.
%   EASY_OVERLAP_STATS performs the operation in the folder where the
%   function resides.
%
%   EASY_OVERLAP_STATS(FOLDER) operates in folder FOLDER.
%
%   EASY_OVERLAP_STATS(FOLDER, OPTIONS) override default options with user
%   specified settings (given as a 1x1 struct input argument):

% defaults
MINRATERS = 5;

% use NeuroElf library
n = neuroelf;

if nargin < 1 || ~ischar(folder) || exist(folder, 'dir') ~= 7
    folder = fileparts(which('easy_overlap_stats'));
end
if nargin < 2 || ~isstruct(options) || numel(options) ~= 1
    options = struct;
end
if ~isfield(options, 'bootstrap') || ~islogical(options.bootstrap) || numel(options.bootstrap) ~= 1
    options.bootstrap = true;
end
if ~isfield(options, 'bootstris') || ~isa(options.bootstris, 'double') || numel(options.bootstris) ~= 1
    options.bootstris = [768, 1024];
end
if ~isfield(options, 'bootstrsz') || ~isa(options.bootstrsz, 'double') || numel(options.bootstrsz) ~= 1
    options.bootstrsz = 1000;
end
if ~isfield(options, 'minrates') || ~isa(options.minraters, 'double') || numel(options.minraters) ~= 1
    options.minraters = MINRATERS;
end
if ~isfield(options, 'ofolder') || ~ischar(options.ofolder) || exist(options.ofolder, 'dir') ~= 7
    options.ofolder = folder;
end
if ~isfield(options, 'studyfile') || ~ischar(options.studyfile) || exist([folder '/' options.studyfile], 'file') ~= 2
    options.studyfile = 'Annotations/study1.csv';
end

% find original images
images = n.findfiles(folder, 'ISIC_*.jpg', 'mindepth=2');

% load study file
stinfo = n.acsvread([folder '/' options.studyfile], ',', struct('headline', ''));
if numel(stinfo) ~= numel(images)
    error('easyStudyError:numberMismatch', 'Number of images mismatches study file info.');
end
stnames = {stinfo.ISIC_id};
[stnames, stidx] = sort(stnames(:));
stinfo = stinfo(stidx);

% find all masks
allmasks = n.findfiles([folder '/Annotations'], '*ISIC*.j*g');
nummasks = numel(allmasks);

% make sure to only keep masks with enough raters
for ic = 1:numel(images)
    immasks = allmasks(~cellfun('isempty', regexpi(allmasks, strrep(stnames{ic}, '_', ''))));
    raters = regexprep(immasks, '^.*ISIC_?\d+_([^_]+)_.*$', '$1');
    if numel(unique(raters)) < options.minraters
        allmasks = setdiff(allmasks, immasks);
    end
end
if isempty(allmasks)
    error('easyStudyError:noMasksRemaining', 'No masks require minimum raters criterion (=%d).', options.minraters);
end

% remove images that are not relevant
if numel(allmasks) ~= nummasks
    isicnums = regexprep(allmasks, '^.*(ISIC_?\d+)_.*$', '$1');
    if ~any(isicnums{1} == '_')
        isicnums = strrep(isicnums, 'ISIC', 'ISIC_');
    end
    [~, keepimages] = intersect(n.lsqueeze({stinfo.ISIC_id}), unique(isicnums));
    images = images(keepimages);
    stinfo = stinfo(keepimages);
    stnames = stnames(keepimages);
end

% get names of all remaining features
features = regexprep(unique(n.lsqueeze({stinfo.feature})), '[^a-zA-Z]+', '');
nfeatures = numel(features);

% create cell arrays that will hold the DICE coefficients
dicem = cell(nfeatures, nfeatures);
smccm = cell(nfeatures, nfeatures);
%ofdicem = cell(nfeatures, nfeatures);

% stats already given, and only bootstrap?
computestats = true;
if isfield(options, 'stats') && isstruct(options.stats) && numel(options.stats) == 1 && ...
    isfield(options.stats, 'raw') && isstruct(options.stats.raw) && numel(options.stats.raw) == 1 && ...
    isfield(options.stats.raw, 'dicem') && iscell(options.stats.raw.dicem) && isequal(size(dicem), size(options.stats.raw.dicem)) && ...
    isfield(options.stats.raw, 'smccm') && iscell(options.stats.raw.smccm) && isequal(size(smccm), size(options.stats.raw.smccm))
    dicem = options.stats.raw.dicem;
    smccm = options.stats.raw.smccm;
    computestats = false;
end

% for each image
if computestats
    for ic = 1:numel(images)

        % isic number
        [~, imname] = fileparts(images{ic});
        imnum = imname(6:12);
        fprintf('Processing masks for ISIC image %s...\n', imnum);

        % index
        imidx = find(strcmpi(stnames, imname));
        if numel(imidx) ~= 1
            error('easyStudyError:imageNotFound', 'ISIC image %s not found.', imname);
        end

    %     % image feature
    %     imfeat = regexprep(stinfo(imidx).feature, '[^a-zA-Z]+', '');
    %     imfeati = find(strcmp(features, imfeat));
    %     if isempty(imfeati)
    %         warning('easyStudyWarning:featureNotFound', 'Feature %s not in list.', imfeat);
    %         continue;
    %     end
    %     
        % find annotations masks related to that image for main/all features
        fmasks = n.findfiles([folder '/Annotations'], ['*ISIC*' imnum '*_*.j*g']);
        frater = regexprep(fmasks, '^.*_ISIC_?\d+_([a-zA-Z]+)_.*\.jpe?g$', '$1');
        ffeats = regexprep(fmasks, '^.*_ISIC_?\d+_[a-zA-Z]+_(.*)\.jpe?g$', '$1');
    %     amasks = n.findfiles([folder '/Annotations'], ['*ISIC*' imnum '*.j*g']);
    %     amasks = setdiff(amasks, fmasks);
    %     afeats = unique(regexprep(amasks, '^.*_ISIC_?\d+_[a-zA-Z]+_(.*)\.jpe?g$', '$1'));
    %     
        % load image masks and get feature indices
        fmasksi = fmasks;
        feati = zeros(numel(fmasks), 1);
        for i1 = numel(fmasks):-1:1
            featfi = find(strcmp(features, ffeats{i1}));
            if isempty(featfi)
                fmasks(i1) = [];
                fmasksi(i1) = [];
                feati(i1) = [];
                continue;
            end
            fmasksi{i1} = imread(fmasks{i1});
            feati(i1) = featfi;
        end
    %     amasksi = amasks;
    %     for i1 = 1:numel(amasks)
    %         amasksi{i1} = imread(amasks{i1});
    %     end

        % iterate over all masks
        for i1 = 2:numel(fmasks)
            for i2 = 1:(i1-1)

                % skip for same rater!
                if strcmpi(frater{i1}, frater{i2})
                    continue;
                end

                % compute DICE and smoothed cross-corr
                [d, smcc] = easy_dice(fmasksi{i1}, fmasksi{i2});
                dicem{feati(i1),feati(i2)}(end+1) = d;
                smccm{feati(i1),feati(i2)}(end+1) = smcc;
                if feati(i1) ~= feati(i2)
                    dicem{feati(i2),feati(i1)}(end+1) = d;
                    smccm{feati(i2),feati(i1)}(end+1) = smcc;
                end
            end
        end
    end
end

% create output
stats = struct( ...
    'raw', struct( ...
        'dicem', {dicem}, ...
        'smccm', {smccm}));

% return if no boot strapping is requested
if ~options.bootstrap
    return;
end

% stats already given, and only bootstrap?
computebstrap = true;
if isfield(options, 'stats') && isstruct(options.stats) && numel(options.stats) == 1 && ...
    isfield(options.stats, 'null') && isstruct(options.stats.null) && numel(options.stats.null) == 1 && ...
    isfield(options.stats.null, 'dicen') && iscell(options.stats.null.dicen) && isequal(size(dicem), size(options.stats.null.dicen)) && ...
    isfield(options.stats.null, 'smccn') && iscell(options.stats.null.smccn) && isequal(size(smccm), size(options.stats.null.smccn))
    dicen = options.stats.null.dicen;
    smccn = options.stats.null.smccn;
    computebstrap = false;
end

% find all masks, prepare counters, etc.
if computebstrap
    fprintf('Preparing for bootstrap...');
    fmasks = n.findfiles([folder '/Annotations'], '*ISIC*_*_*.j*g');
    allfeats = sprintf('%s|', features{:});
    fmasks(cellfun('isempty', regexp(fmasks, ...
        sprintf('^.*_ISIC_?\\d+_[a-zA-Z]+_(%s)\\.jpe?g$', allfeats(1:end-1))))) = [];
    ffeats = regexprep(fmasks, '^.*_ISIC_?\d+_[a-zA-Z]+_(.*)\.jpe?g$', '$1');
    feati = zeros(numel(ffeats), 1);
    for i1 = numel(fmasks):-1:1
        featfi = find(strcmp(features, ffeats{i1}));
        if isempty(featfi)
            fmasks(i1) = [];
            feati(i1) = [];
            continue;
        end
        feati(i1) = featfi;
    end
    featff = cell(nfeatures, 1);
    for i1 = 1:nfeatures
        featff{i1} = find(~cellfun('isempty', regexp(fmasks, ['_' features{i1} '\.'])));
    end
    frater = regexprep(fmasks, '^.*_ISIC_?\d+_([a-zA-Z]+)_.*\.jpe?g$', '$1');
    isicnum = str2double(regexprep(fmasks, '^.*ISIC_?(\d+)_.*$', '$1'));
    numimg = numel(isicnum);

    % load images
    if ~isfield(options, 'fmaski') || ~iscell(options.fmaski) || numel(options.fmaski) ~= numel(fmasks)
        fmaski = fmasks;
        fprintf(' loading masks ');
        scn = floor(numimg / 32);
        scs = scn;
        rsz = options.bootstris;
        for sc = 1:numimg
            fmaski{sc} = mean(imread(fmasks{sc}), 3);
            if size(fmaski{sc}, 1) ~= rsz(1) || size(fmaski{sc}, 2) ~= rsz(1)
                fmaski{sc} = n.image_resize(fmaski{sc}, rsz(1), rsz(2));
            end
            fmaski{sc} = (fmaski{sc} >= 0.5);
            if sc >= scn
                fprintf('.');
                scn = scn + scs;
            end
        end
    else
        fmaski = options.fmaski;
    end
    fmaskd = cell(size(fmaski));

    % sampling loop
    smpnum = options.bootstrsz .* ones(nfeatures, nfeatures);
    smpnum(cellfun('isempty', dicem)) = 0;
    totsmp = sum(smpnum(:));
    smpidx = [min(nfeatures, ceil(nfeatures .* rand(options.bootstrsz, 2))), ...
        min(numimg * numimg, ceil((numimg * numimg) .* rand(options.bootstrsz, 2)))];
    sc = 0;
    dicen = cell(nfeatures, nfeatures);
    smccn = cell(nfeatures, nfeatures);
    fprintf('\nSampling...\n');
    while any(smpnum(:) > 0)

        % re-sample random data?
        if sc >= options.bootstrsz
            fprintf('... %5.2f%% done ....\n', 100 * (totsmp - sum(smpnum(:))) / totsmp);
            smpidx = [min(nfeatures, ceil(nfeatures .* rand(options.bootstrsz, 2))), ...
                min(numimg * numimg, ceil((numimg * numimg) .* rand(options.bootstrsz, 2)))];
            sc = 0;
        end

        % increase counter
        sc = sc + 1;

        % get two features
        f1 = smpidx(sc, 1);
        f2 = smpidx(sc, 2);
        s1 = featff{f1}(1 + mod(smpidx(sc, 3), numel(featff{f1})));
        s2 = featff{f2}(1 + mod(smpidx(sc, 4), numel(featff{f2})));

        % continue if bad combo
        if strcmpi(frater{s1}, frater{s2}) || isicnum(s1) == isicnum(s2) || smpnum(f1, f2) < 1
            continue;
        end

        % compute Dice and SMCC
        [d, smcc, di1, di2] = easy_dice(fmaski{s1}, fmaski{s2}, [], fmaskd{s1}, fmaskd{s2});
        if isempty(fmaskd{s1})
            fmaskd{s1} = di1;
        end
        if isempty(fmaskd{s2})
            fmaskd{s2} = di2;
        end

        % add to arrays
        if f2 < f1
            dicen{f1,f2}(end+1) = d;
            smccn{f1,f2}(end+1) = smcc;
        else
            dicen{f2,f1}(end+1) = d;
            smccn{f2,f1}(end+1) = smcc;
        end
        smpnum(f1, f2) = smpnum(f1, f2) - 1;
        if f1 ~= f2
            smpnum(f2, f1) = smpnum(f2, f1) - 1;
        end
    end
    fprintf('Done.\n');
end
for cc = 1:numel(dicen)
    if isempty(dicen{cc})
        continue;
    end
    dicen{cc} = sort(dicen{cc});
    smccn{cc} = sort(smccn{cc});
end
stats.null = struct( ...
    'dicen', {dicen}, ...
    'smccn', {smccn});

% compute, for each element with non empty data, a Z-transformed version
dicez = dicem;
smccz = smccm;
for cc = 1:numel(dicen)
    if isempty(dicen{cc})
        continue;
    end
    dicez{cc} = n.bstrapz(dicem{cc}, dicen{cc});
    smccz{cc} = n.bstrapz(smccm{cc}, smccn{cc});
end
stats.z = struct( ...
    'dicez', {dicez}, ...
    'smccz', {smccz});
