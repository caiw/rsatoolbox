% write_stc_snapshot(metadata, mesh, file_path)
%
% Writes data as an stc file using the specified metadata struct.
%
% Use this for writing a single frame's worth of data as an STC file.
%
% Does this by faking two frames of the same data.
%
% See also WRITE_STC_FILE.
%
% CW 2015-04
function write_stc_snapshot(metadata, mesh, file_path)
    metadata.data = repmat(mesh, 1, 2);
    mne_write_stc_file1(file_path, metadata);
end%function
