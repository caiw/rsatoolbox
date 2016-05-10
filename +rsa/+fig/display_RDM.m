% Displays an RDM.
%
%   display_RDM(RDM, ...
%                  ['rank01', false], ...
%                  ['title', ''], ...
%                  ['colormap', @jet], ...
%                  ['showcolorbar', false], ...
%                  ['size', [10, 10, 640, 480]])
%
% CW 2016-05
function display_RDM( RDM, varargin )

    import rsa.*
    import rsa.fig.*
    import rsa.rdm.*
    import rsa.util.*

	%% Parse inputs
    
    name_rank01    = 'rank01';
    check_rank01   = @islogical;
    default_rank01 = false;
    
    name_colorbar    = 'colorbar';
    check_colorbar   = @islogical;
    default_colorbar = false;
    
    name_colormap = 'colormap';
    check_colormap = @(x) (isa(x,'function_handle'));
    default_colormap = @jet;
    
    name_title = 'title';
    check_title = @ischar;
    default_title = '';
    
    name_size = 'size';
    check_size = @(x)( isa(x, 'double') && numel(x) == 4);
    default_size = [10, 10, 640, 480];
    
    % TODO: clims

    ip = inputParser;
    ip.CaseSensitive = false;
    ip.StructExpand  = false;
    
    addParameter(ip, name_rank01, default_rank01, check_rank01);
    addParameter(ip, name_colorbar, default_colorbar, check_colorbar);
    addParameter(ip, name_colormap, default_colormap, check_colormap);
    addParameter(ip, name_title, default_title, check_title);
    addParameter(ip, name_size, default_size, check_size);
    
    parse(ip, varargin{:});
    
    rank01       = ip.Results.(name_rank01);
    showcolorbar = ip.Results.(name_colorbar);
    colormap_fh  = ip.Results.(name_colormap);
    title_text   = ip.Results.(name_title);
    figure_size  = ip.Results.(name_size);
    

    %% handle RDM types
    RDM = rsa.rdm.squareRDM(RDM);
    
    % rank transform and scale into 0,1?
    if rank01
        RDM = rsa.util.scale01( ...
            rsa.util.rankTransform_equalsStayEqual( ...
            RDM));
    end
    
    % Set up figure
    h = figure;
    
    % set figure background colour to be white
    set(h, 'Color', 'w');
    
    imagesc(RDM);
    
    colormap(colormap_fh());
    
    if showcolorbar
        colorbar;
    end
    
    if ~isempty(title_text)
       title(sprintf('\b%s', title_text), 'FontSize', 30); 
    end
    
    set(h, 'Position', figure_size);
    
    axis square off;

end
