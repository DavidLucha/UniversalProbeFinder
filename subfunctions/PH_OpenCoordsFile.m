function [sProbeCoords,strFile,strPath] = PH_OpenCoordsFile(strDefaultPath,strName,sAtlas)
	%open a histology coordinates file and adds the file type to the sProbeCoords field .Type
	
	%% pre-allocate output
	sProbeCoords = [];
	if ~exist('strName','var') || isempty(strName)
		strPrompt = 'Select aligned slice or probe coordinate file';
	else
		strPrompt = ['Select aligned slice or probe coordinate file for ' strName];
	end
	
	%% select file
	try
		strOldPath = cd(strDefaultPath);
	catch
		strOldPath = cd();
	end
	PH_ConsolePrompt('Select FILE',strPrompt,cd(),'AP_histology v2: AP_histology_processing.mat (in ap_histology_tiffs). Also: old probe_ccf.mat, SHARP-track, UPF ProbeLocationFile*.mat');
	[strFile,strPath]=uigetfile('ProbeTracks.mat',strPrompt);
	cd(strOldPath);
	if isempty(strFile) || (numel(strFile)==1 && strFile==0)
		return;
	end
	
	%% load
	sLoad = load(fullpath(strPath,strFile));
	if isfield(sLoad,'sSliceData') && isstruct(sLoad.sSliceData)
		%transform from aligned data file
		sProbeCoords = SF_SliceFile2TracksFile(sLoad.sSliceData,sAtlas);
		sProbeCoords.Type = 'native';
	elseif isfield(sLoad,'sProbeCoords') && isstruct(sLoad.sProbeCoords)
		sProbeCoords = sLoad.sProbeCoords;
		sProbeCoords.Type = 'native';
	elseif isfield(sLoad,'probe_ccf') && isstruct(sLoad.probe_ccf) && isfield(sLoad.probe_ccf,'points')
		%AP_histology (pre-v2: standalone probe_ccf.mat)
		sProbeCoords.cellPoints = {sLoad.probe_ccf.points};
		sProbeCoords.Type = 'AP_histology_old';
	elseif isfield(sLoad,'AP_histology_processing') && isstruct(sLoad.AP_histology_processing)
		%AP_histology (v2, post-2026-02-23): no probe_ccf.mat is saved.
		%Reconstruct the legacy probe_ccf struct from the annotations stored
		%in AP_histology_processing.mat. The two lines below are identical to
		%the pre-v2 AP_histology branch above, so all downstream processing
		%(PH_ExtractProbeCoords, PH_Points2vec, ...) is unchanged.
		%
		%REQUIREMENT: in the v2 AP_histology Annotator, draw each probe tract
		%as a Line annotation labelled 'Probe 1', 'Probe 2', ... across every
		%slice on which it is visible. See AP_histology_processing2probe_ccf.
		probe_ccf = AP_histology_processing2probe_ccf(sLoad.AP_histology_processing);
		sProbeCoords.cellPoints = {probe_ccf.points};
		sProbeCoords.Type = 'AP_histology';
	elseif isfield(sLoad,'pointList') && isstruct(sLoad.pointList) && isfield(sLoad.pointList,'pointList')
		%sharp track
		sProbeCoords.cellPoints = sLoad.pointList.pointList(:,1);
		sProbeCoords.Type = 'SHARP-track';
	elseif isfield(sLoad,'sAP') && isstruct(sLoad.sAP) && isfield(sLoad.sAP,'sSources') && isstruct(sLoad.sAP.sSources) && isfield(sLoad.sAP.sSources,'sProbeCoords') && isstruct(sLoad.sAP.sSources.sProbeCoords)
		%acquipix
		sProbeCoords = sLoad.sAP.sSources.sProbeCoords;
		sProbeCoords.Type = 'native';
	else
		try
			error([mfilename ':FileTypeNotRecognized'],'File is of unknown format');
		catch ME
			strStack = sprintf('Error in %s (Line %d)',ME.stack(1).name,ME.stack(1).line);
			errordlg(sprintf('%s\n%s',ME.message,strStack),'Probe coord error')
			return;
		end
	end
	
	%add source
	sProbeCoords.folder = strPath;
	sProbeCoords.name = strFile;
end


function probe_ccf = AP_histology_processing2probe_ccf(AP_histology_processing)
	%AP_histology_processing2probe_ccf Reconstruct a legacy AP_histology
	%	"probe_ccf" struct array from a v2 (post-2026-02-23) AP_histology
	%	"AP_histology_processing" struct.
	%
	%	v2 AP_histology no longer saves probe_ccf.mat. Probe tracts are
	%	instead stored as generic annotations in AP_histology_processing.mat
	%	under .annotation, with per-slice CCF coordinates split into the
	%	fields .vertices_ccf(slice).ap / .ml / .dv. This function collects
	%	those back into the N x 3 .points matrix (column order [AP,DV,ML],
	%	CCF voxel indices, DV-sorted) that the legacy probe_ccf struct held
	%	and that UniversalProbeFinder consumes.
	%
	%	REQUIREMENT: in the v2 AP_histology Annotator, draw each probe as a
	%	Line annotation labelled 'Probe 1', 'Probe 2', ... The trailing
	%	integer in the label sets the probe index/order. Annotations whose
	%	label does not contain 'probe' (case-insensitive) are ignored, so
	%	other anatomical annotations in the same file are safely skipped.
	
	%check for annotations
	if ~isfield(AP_histology_processing,'annotation') || isempty(AP_histology_processing.annotation)
		error('PH_OpenCoordsFile:NoAnnotations', ...
			'AP_histology_processing contains no annotations.');
	end
	annotation = AP_histology_processing.annotation;
	cellLabels = {annotation.label};
	
	%select probe annotations by label
	vecProbeIdx = find(contains(cellLabels,'probe','IgnoreCase',true));
	if isempty(vecProbeIdx)
		error('PH_OpenCoordsFile:NoProbeAnnotations', ...
			['No annotations labelled "Probe N" were found in the ' ...
			'AP_histology file. Available labels: %s'],strjoin(cellLabels,', '));
	end
	
	%order probes by the trailing integer in the label (Probe 1, Probe 2, ...)
	vecProbeNum = nan(size(vecProbeIdx));
	for intProbe=1:numel(vecProbeIdx)
		cellTok = regexp(cellLabels{vecProbeIdx(intProbe)},'(\d+)\s*$','tokens','once');
		if ~isempty(cellTok)
			vecProbeNum(intProbe) = str2double(cellTok{1});
		end
	end
	if all(~isnan(vecProbeNum))
		[~,vecReorder] = sort(vecProbeNum);
		vecProbeIdx = vecProbeIdx(vecReorder);
	end
	
	%reassemble points for each probe
	probe_ccf = struct('points',cell(numel(vecProbeIdx),1));
	for intProbe=1:numel(vecProbeIdx)
		sAnnotation = annotation(vecProbeIdx(intProbe));
		matPoints = zeros(0,3);
		if isfield(sAnnotation,'vertices_ccf') && ~isempty(sAnnotation.vertices_ccf)
			for intSlice=1:numel(sAnnotation.vertices_ccf)
				vecAP = sAnnotation.vertices_ccf(intSlice).ap(:);
				vecDV = sAnnotation.vertices_ccf(intSlice).dv(:);
				vecML = sAnnotation.vertices_ccf(intSlice).ml(:);
				if isempty(vecAP)
					continue;
				end
				%legacy probe_ccf.points column order is [AP,DV,ML]
				matPoints = [matPoints; vecAP vecDV vecML]; %#ok<AGROW>
			end
		end
		
		%drop any vertices that fell outside the atlas (NaN)
		matPoints = matPoints(all(~isnan(matPoints),2),:);
		
		%sort by DV so the probe runs top->bottom (matches pre-v2 pipeline)
		if ~isempty(matPoints)
			[~,vecDVSort] = sort(matPoints(:,2));
			matPoints = matPoints(vecDVSort,:);
		else
			warning('PH_OpenCoordsFile:EmptyProbe', ...
				'Probe annotation "%s" yielded no valid CCF points.', ...
				cellLabels{vecProbeIdx(intProbe)});
		end
		
		probe_ccf(intProbe).points = matPoints;
	end
end