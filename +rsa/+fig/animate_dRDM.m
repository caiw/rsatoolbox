function animate_dRDM( dRDM, output_dir )
    
    import rsa.*
    import rsa.fig.*
    
    animation_frame_delay = 0.1; % Delay in seconds between successive frames
    figure_size           = [10, 10, 1080, 1080];
    rank_transform        = true;
    rdm_colormap          = @bipolar;
    show_colorbar         = true;
    
    n_frames = numel(dRDM);
    
    for frame = 1:n_frames
        % square rdm
        dRDM(frame).RDM = squareform(dRDM(frame).RDM);
        
        rsa.fig.display_RDM(dRDM(frame).RDM, ...
            'title',    dRDM(frame).Name, ...
            'colorbar', show_colorbar, ...
            'rank01',   rank_transform, ...
            'colormap', rdm_colormap, ...
            'size',     figure_size);
        
        this_figure = gcf;

        f = getframe(this_figure);

        % All models
        if frame == 1
            [image_stack, map] = rgb2ind(f.cdata, 256, 'nodither');
            image_stack(1,1,1,n_frames) = 0;
        else
            image_stack(:,:,1,frame) = rgb2ind(f.cdata, map, 'nodither');
        end%if

        close;

    end

    % Save animated gifs
    anigif_save_path = fullfile(output_dir, 'animated.gif');
    imwrite(image_stack, map, anigif_save_path, 'DelayTime', animation_frame_delay, 'LoopCount', inf);

end
