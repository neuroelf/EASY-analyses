function [d, smcc, sim1, sim2] = easy_dice(im1, im2, sk, sim1, sim2)
%EASY_DICE  Compute DICE coefficient.
%   D = EASY_DICE(IM1, IM2) computes the DICE coefficient for images
%   IM1 and IM2.
%
%   [1] https://en.wikipedia.org/wiki/Sørensen?Dice_coefficient

% default smoothing kernel as a fraction of the image size
SKDEFAULT = 1 / 20;

% tests
if ~isequal(size(im1), size(im2))
    error('easyStudyError:invalidSizes', 'Images must match in size.');
end
if ~islogical(im1)
    im1 = any(im1 > 0, 3);
end
if ~islogical(im2)
    im2 = any(im2 > 0, 3);
end

% computation
s1 = sum(im1(:));
s2 = sum(im2(:));
d = 2 * sum(im1(:) & im2(:)) / (s1 + s2);

% we're done
if nargout < 2
    return;
end

% convolve images
if nargin < 5 || ~isa(sim1, 'double') || ~isa(sim2, 'double') || isempty(sim1) || ~isequal(size(sim1), size(sim2))
    
    % smoothing kernel size from default
    if nargin < 3 || ~isa(sk, 'double') || numel(sk) ~= 1
        sk = SKDEFAULT * sqrt(size(im1, 1) * size(im1, 2));
    end

    % get gaussian kernel
    f = sk / sqrt(8 * log(2));
    md = round(6 * max(1, log2(f)) * f);
    ed = exp(- (-md:md) .^ 2 ./ (2 * f .^ 2));
    ed = ed ./ sum(ed);
    ed(ed < 1e-6) = [];

    % reduce SUPER large data
    while numel(ed) > 400 || any(size(im1) > 1024)
        ed = ed(1:2:2*floor(numel(ed)/2)) + ed(2:2:end);
        im1 = im1(1:2:2*floor(size(im1,1)/2), 1:2:2*floor(size(im1,2)/2)) + ...
            im1(2:2:end, 1:2:2*floor(size(im1,2)/2)) + ...
            im1(1:2:2*floor(size(im1,1)/2), 2:2:end) + im1(2:2:end, 2:2:end);
        im2 = im2(1:2:2*floor(size(im2,1)/2), 1:2:2*floor(size(im2,2)/2)) + ...
            im2(2:2:end, 1:2:2*floor(size(im2,2)/2)) + ...
            im2(1:2:2*floor(size(im2,1)/2), 2:2:end) + im2(2:2:end, 2:2:end);
    end

    sim1 = convn(convn(double(im1), ed', 'same'), ed, 'same');
    sim2 = convn(convn(double(im2), ed', 'same'), ed, 'same');
end

% cross correlation
smcc = corrcoef([sim1(:), sim2(:)]);
smcc = 0.5 * log((1 + smcc(2)) ./ (1 - smcc(2)));
