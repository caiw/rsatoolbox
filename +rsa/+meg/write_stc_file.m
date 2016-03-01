% write_stc_file(metadata, mesh, file_path)
%
% Writes data as an stc file using the specified metadata struct.
%
% See also WRITE_STC_SNAPSHOT.
%
% CW 2015-04
function write_stc_file(metadata, mesh, file_path)
    metadata.data = mesh;
    mne_write_stc_file1(file_path, metadata);
end%function
