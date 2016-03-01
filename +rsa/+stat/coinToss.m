% itWasHeads = coinToss()
% itWasHeads = coinToss(probability_of_heads)
% itWasHeads = coinToss(array_size, probability_of_heads
%
% Tosses a coin, and tells you whether it was heads or not. It's a 
% (pseudo-)fair coin unless otherwise specified.
%
% If the first argument is a matrix, itWasHeads is an array_size-size
% matrix of iid coin toss results.
%
% Good for using as conditionals.
%
%     % Randomly flip sign of x
%     if coinToss
%         x = (-1) * x;
%     end
% 
% CW 2015-04, 2016-03
function it_was_heads = coinToss(varargin)

    % If we don't specify otherwise, make it a fair coin.
    if nargin == 0
        probability_of_heads = 0.5;
        array_size = [1, 1];
    elseif nargin == 1
        if numel(varargin{1}) == 1
            % Sole argument is probability of heads
            probability_of_heads = varargin{1};
            array_size = [1, 1];
        else
            % Sole argument is array size
            probability_of_heads = 0.5;
            array_size = varargin{1};
        end
    elseif nargin == 2
        array_size           = varargin{1};
        probability_of_heads = varargin{2};
    else
        error();
    end

    % Put these edge cases in just in case the random roll comes up as
    % exactly 0 or 1, and we don't know now to treat < vs <=.
    if probability_of_heads == 0
        it_was_heads = false(array_size);
    elseif probability_of_heads == 1
        it_was_heads = true(array_size);
    else
        % rand is uniform over [0,1], so this should allow us to translate
        % from probability to threshold.
        it_was_heads = (rand(array_size) <= probability_of_heads);
    end
end%function
