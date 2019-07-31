function easy_annotate(folder, options)
%EASY_ANNOTATE  Annotate images with consensus of annotators.
%   EASY_ANNOTATE performs the operation in the folder where the function
%   resides.
%
%   EASY_ANNOTATE(FOLDER) operates in folder FOLDER.
%
%   EASY_ANNOTATE(FOLDER, OPTIONS) override default options with user
%   specified settings (given as a 1x1 struct input argument):
%
%   OPTIONS.colors  can be set to a Cx3 RGB ([0..255]) color set from which
%      gradients are computed (interpolating between the C colors).
%
%   OPTIONS.maxraters  specifies the number of maximum raters per image;
%      if not given, this will be auto-detected per image
%
%   OPTIONS.mcolors  can be set to a Cx3 RGB ([0..255]) color set from
%      which gradients are computed to color in the mixed-in features.
%
%   For each input image, one output images is created:
%
%   ISIC_[number]_[main_feature_name].jpg

% use NeuroElf library
n = neuroelf;

if nargin < 1 || ~ischar(folder) || exist(folder, 'dir') ~= 7
    folder = fileparts(which('easy_annotate'));
end
if nargin < 2 || ~isstruct(options) || numel(options) ~= 1
    options = struct;
end
if ~isfield(options, 'colors') || ~isa(options.colors, 'double') || size(options.colors, 1) < 2 || size(options.colors, 2) ~= 3
    options.colors = [208, 228, 240; 32, 96, 176];
end
numcols = size(options.colors, 1) - 1;
if ~isfield(options, 'colorscale') || ~isa(options.colorscale, 'double') || numel(options.colorscale) <2
    options.colorscale = log(1+(0:24)) ./ log(25);
end
options.colorscale = options.colorscale(:);
numscale = numel(options.colorscale) - 1;
if ~isfield(options, 'fullconf') || ~isa(options.fullconf, 'logical') || numel(options.fullconf) ~= 1
    options.fullconf = true;
end
if ~isfield(options, 'maxraters') || ~isa(options.maxraters, 'double') || numel(options.maxraters) ~= 1
    options.maxraters = 0;
end
if ~isfield(options, 'mcolors') || ~isa(options.mcolors, 'double') || size(options.mcolors, 1) < 2 || size(options.mcolors, 2) ~= 3
    options.mcolors = [192, 64, 64; 160, 160, 80; 64, 192, 64];
end
nummcols = size(options.mcolors, 1) - 1;
if ~isfield(options, 'studyfile') || ~ischar(options.studyfile) || exist([folder '/' options.studyfile], 'file') ~= 2
    options.studyfile = 'Annotations/study1.csv';
end
if ~isfield(options, 'ofolder') || ~ischar(options.ofolder) || exist(options.ofolder, 'dir') ~= 7
    options.ofolder = folder;
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

% find all masks to detect maxraters if necessary
if isequal(options.maxraters, 0)
    options.maxraters = zeros(numel(images), 1);
    allmasks = n.findfiles([folder '/Annotations'], '*ISIC*.j*g');
    for ic = 1:numel(images)
        immasks = allmasks(~cellfun('isempty', regexpi(allmasks, strrep(stnames{ic}, '_', ''))));
        raters = regexprep(immasks, '^.*ISIC_?\d+_([^_]+)_.*$', '$1');
        options.maxraters(ic) = numel(unique(raters));
    end
elseif numel(options.maxraters) == 1
    if isinf(options.maxraters)
        allmasks = n.findfiles([folder '/Annotations'], '*ISIC*.j*g');
        raters = regexprep(allmasks, '^.*ISIC_?\d+_([^_]+)_.*$', '$1');
        options.maxraters = numel(unique(raters));
    end
    options.maxraters = options.maxraters(ones(numel(images), 1));
end

% for each image
for ic = 1:numel(images)
    
    % isic number
    [~, imname] = fileparts(images{ic});
    imnum = imname(6:12);
    
    % index
    imidx = find(strcmpi(stnames, imname));
    if numel(imidx) ~= 1
        error('easyStudyError:imageNotFound', 'ISIC image %s not found.', imname);
    end
    
    % load image
    im = double(imread(images{ic}));
    sfim = [size(im, 1), size(im, 2)];
    scf = min(1, 1024 / sfim(2));
    
    % resize to make width <= 1024
    if scf < 1
        im = n.image_resize(im, round(scf * sfim(1)), round(scf * sfim(2)));
    end
    nsfim = [size(im, 1), size(im, 2)];
    
    % image feature
    imfeat = regexprep(stinfo(imidx).feature, '[^a-zA-Z]+', '');
    
    % find annotations masks related to that image for main/all features
    fmasks = n.findfiles([folder '/Annotations'], ['*ISIC*' imnum '*_' imfeat '*.j*g']);
    amasks = n.findfiles([folder '/Annotations'], ['*ISIC*' imnum '*.j*g']);
    amasks = setdiff(amasks, fmasks);
    afeats = unique(regexprep(amasks, '^.*_ISIC_?\d+_[a-zA-Z]+_(.*)\.jpe?g$', '$1'));
    
    % copy image in case it's not marked with feature
    mainim = im;
    
    % at least someone marked this feature
    ufim = [];
    ucols = zeros(0, 3);
    if ~isempty(fmasks)
        
        % load those masks
        fim = fmasks;
        for fc = 1:numel(fim)
            fim{fc} = (1/255) .* double(imread(fmasks{fc}));
            if options.fullconf
                fim{fc}(fim{fc} > 0) = 1;
            end
        end
        
        % combine masks
        try
            fim = sum(cat(4, fim{:}), 4) ./ options.maxraters(ic);
        catch
            error('easyStudyError:imageSizeMismatch', 'Annotation images don''t match in size.');
        end
        ufim = unique(fim(:));
        
        % check size
        if sfim(1) ~= size(fim, 1) || sfim(2) ~= size(fim, 2)
            error('easyStudyError:imageSizeMismatch', 'Annotation images don''t match color image size.');
        end
        if scf < 1
            fim = min(max(ufim), max(0, n.image_resize(fim, round(scf * sfim(1)), round(scf * sfim(2)))));
        end
        
        % generate color image based on color scale
        fcim = zeros([nsfim, 3]);
        ci0 = floor(numcols .* fim);
        uci0 = floor(numcols .* ufim);
        ucols = zeros(numel(ufim), 3);
        w1 = numcols .* fim - ci0;
        uw1 = numcols .* ufim - uci0;
        w0 = 1 - w1;
        uw0 = 1 - uw1;
        wi0 = floor(numscale .* fim);
        wi1 = min(wi0 + 2, numscale + 1);
        w11 = numscale .* w1 - wi0;
        w10 = 1 - w11;
        fim = reshape( ...
            w10(:) .* options.colorscale(wi0(:) + 1) + w11(:) .* options.colorscale(wi1(:)), nsfim);
        ci1 = min(ci0 + 2, numcols + 1);
        uci1 = min(uci0 + 2, numcols + 1);
        for pc = 1:3
            fcim(:, :, pc) = ...
                reshape(w0(:) .* options.colors(ci0(:) + 1, pc) + w1(:) .* options.colors(ci1(:), pc), nsfim);
        end
        for pc = 1:numel(ufim)
            ucols(pc, :) = round(uw0(pc) .* options.colors(uci0(pc) + 1, :) + uw1(pc) .* options.colors(uci1(pc), :));
        end
        
        % combine
        mainim = round((1 - fim(:, :, [1, 1, 1])) .* mainim + fim(:, :, [1, 1, 1]) .* fcim);
    end
    
    % generate color image and weight mask based on color scale
    fcim = 1.5 .* mainim;
    fciw = 1.5 .* ones(nsfim);
    
    % add other features
    cfac = nummcols / max(1, (numel(afeats) - 1));
    acols = zeros(numel(afeats), 3);
    for fc = 1:numel(afeats)
        
        % color code for this feature
        ci = (fc - 1) * cfac;
        ci0 = floor(ci);
        ci = ci - ci0;
        ci1 = min(ci0 + 2, nummcols + 1);
        ccol = (1 - ci) .* options.mcolors(ci0 + 1, :) + ci .* options.mcolors(ci1, :);
        acols(fc, :) = round(ccol);
        
        % load masks
        afmasks = amasks(~cellfun('isempty', regexp(amasks, afeats{fc})));
        fim = afmasks;
        for afc = 1:numel(fim)
            fim{afc} = (1/255) .* double(imread(afmasks{afc}));
            if options.fullconf
                fim{afc}(fim{afc} > 0) = 1;
            end
        end
        
        % combine masks
        try
            fim = sum(cat(4, fim{:}), 4) ./ max(2, numel(fim));
        catch
            error('easyStudyError:imageSizeMismatch', 'Annotation images don''t match in size.');
        end
        if scf < 1
            fim = min(max(fim(:)), max(0, n.image_resize(fim, round(scf * sfim(1)), round(scf * sfim(2)))));
        end
        
        % add to image
        try
            fcim = fcim + fim(:, :, [1, 1, 1]) .* repmat(reshape(ccol, [1, 1, 3]), nsfim);
            fciw = fciw + fim;
        catch
            fprintf('Error combining %s in %s.\n', afeats{fc}, imnum);
        end
    end
    
    % recompute image
    fcim = round(fcim ./ fciw(:, :, [1, 1, 1]));
    
    % create legend
    legim = 255 .* ones([nsfim, 3]);
    for pc = 2:numel(ufim)
        yst = 56 * (pc - 2) + 9;
        legim(yst:yst+47, 21:88, :) = 0;
        legim(yst+4:yst+43, 25:84, 1) = ucols(pc, 1);
        legim(yst+4:yst+43, 25:84, 2) = ucols(pc, 2);
        legim(yst+4:yst+43, 25:84, 3) = ucols(pc, 3);
        legtext = n.image_font(sprintf('%s - %d%%', imfeat, round(100 * ufim(pc))), 'Font', 36);
        if size(legtext, 1) > 36
            legtext(37:end, :, :) = [];
        end
        legim(yst+7:yst+42, 101:100+size(legtext, 2), :) = legtext;
    end
    for pc = 1:size(acols, 1)
        yst = 56 * (max(0, numel(ufim) - 1) + pc - 1) + 9;
        legim(yst:yst+47, 21:88, :) = 0;
        legim(yst+4:yst+43, 25:84, 1) = acols(pc, 1);
        legim(yst+4:yst+43, 25:84, 2) = acols(pc, 2);
        legim(yst+4:yst+43, 25:84, 3) = acols(pc, 3);
        legtext = n.image_font(sprintf('%s', afeats{pc}), 'Font', 36);
        if size(legtext, 1) > 36
            legtext(37:end, :, :) = [];
        end
        legim(yst+7:yst+42, 101:100+size(legtext, 2), :) = legtext;
    end
    if size(legim, 1) > nsfim(1)
        legim(nsfim(1)+1:end, :, :) = [];
    end
    if size(legim, 2) > nsfim(2)
        legim(:, nsfim(2)+1:end, :) = [];
    end
    
    % combine image
    cim = [im, mainim; fcim, legim];
    
    % write out images
    imwrite(uint8(cim), [options.ofolder '/ISIC_' imnum '_' imfeat '.jpg'], 'Quality', 90);
end
