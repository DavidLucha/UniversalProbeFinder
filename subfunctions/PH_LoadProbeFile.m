function [sProbeCoords,strFile,strPath] = PH_LoadProbeFile(sAtlas,strPath,strName,strFileFull,intProbeIdx)
	%PH_LoadProbeFile Load probe file with file selection window and extract coords
	%   [sProbeCoords,strFile,strPath] = PH_LoadProbeFile(sAtlas,strPath)
	%DLH fork: optional strFileFull (no file dialog) and intProbeIdx (no probe dialog), for UPF_OpenSession
	
	if ~exist('strPath','var') || isempty(strPath) || strPath(1) == 0
		strPath = cd();
	end
	if ~exist('strName','var') || isempty(strName)
		strName = '';
	end
	
	%open file
	if ~exist('strFileFull','var'),strFileFull = '';end
	[sProbeCoords,strFile,strPath] = PH_OpenCoordsFile(strPath,strName,sAtlas,strFileFull);
	if ~isfield(sProbeCoords,'ProbeLength')
		%in microns (hardcode, sometimes kilosort2 drops channels)
		sProbeCoords.ProbeLength = 3840 ./ sAtlas.VoxelSize(end); %in native atlas size
	end
	if ~isfield(sProbeCoords,'ProbeLengthOriginal')
		sProbeCoords.ProbeLengthOriginal = sProbeCoords.ProbeLength; %initial size
	end
	if ~isfield(sProbeCoords,'ProbeLengthMicrons')
		sProbeCoords.ProbeLengthMicrons = sProbeCoords.ProbeLength * sAtlas.VoxelSize(end); %in microns
	end
	
	%select probe nr
	if isempty(sProbeCoords) || ~isfield(sProbeCoords,'cellPoints')
		sProbeCoords.folder = '';
		sProbeCoords.name = ['default'];
		sProbeCoords.cellPoints{1} = [sAtlas.Bregma; sAtlas.Bregma - [0 0 sProbeCoords.ProbeLengthMicrons]./sAtlas.VoxelSize];
		sProbeCoords.intProbeIdx = 1;
		sProbeCoords.Type = ['native'];
	else
		%transform probe coordinates
		sProbeCoords = PH_ExtractProbeCoords(sProbeCoords);
		
		%select probe
		if exist('intProbeIdx','var') && ~isempty(intProbeIdx)
			if intProbeIdx > numel(sProbeCoords.cellPoints)
				error([mfilename ':NoSuchProbe'],'Probe %d requested, but %s has %d probe track(s)',intProbeIdx,strFile,numel(sProbeCoords.cellPoints));
			end
			sProbeCoords.intProbeIdx = intProbeIdx;
		end
		if ~isfield(sProbeCoords,'intProbeIdx') || isempty(sProbeCoords.intProbeIdx)
			sProbeCoords.intProbeIdx = PH_SelectProbeNr(sProbeCoords,sAtlas);
		end
	end
	
end

