function PH_UpdateProbeCoordinates(hMain,vecSphereVector,boolForceYupdate)
	%default
	if ~exist('boolForceYupdate','var') || isempty(boolForceYupdate)
		boolForceYupdate = false;
	end
	
	% Get guidata
	sGUI = guidata(hMain);
	
	%calculate vectors in different spaces
	probe_vector_sph = vecSphereVector;
	probe_vector_cart = PH_SphVec2CartVec(vecSphereVector);
	vecLocationBrainIntersection = PH_GetBrainIntersection(probe_vector_cart,sGUI.sAtlas.av);
	probe_vector_bregma = PH_SphVec2BregmaVec(vecSphereVector,vecLocationBrainIntersection,sGUI.sAtlas);
	%fprintf('PH_UpdateProbeCoordinates:\n');
	%fprintf(' Sphere: %s\n',sprintf('%d ',round(probe_vector_sph)));
	%fprintf(' Cart: %s\n',sprintf('%d ',round(probe_vector_cart)));
	%fprintf(' Brain: %s\n',sprintf('%d ',round(vecLocationBrainIntersection)));
	%fprintf(' Bregma: %s\n',sprintf('%d ',round(probe_vector_bregma)));
	
	% (if the probe doesn't intersect the brain, don't update)
	if isempty(vecLocationBrainIntersection)
		return
	end
	
	%add new vectors to current position
	sGUI.sProbeCoords.sProbeAdjusted.probe_vector_cart = probe_vector_cart;
	sGUI.sProbeCoords.sProbeAdjusted.probe_vector_sph = probe_vector_sph;
	sGUI.sProbeCoords.sProbeAdjusted.probe_vector_intersect = vecLocationBrainIntersection;
	sGUI.sProbeCoords.sProbeAdjusted.probe_vector_bregma = probe_vector_bregma;
	
	%get locations along probe
	[probe_area_ids,probe_area_boundaries,probe_area_centers] = PH_GetProbeAreas(probe_vector_cart,sGUI.sAtlas.av);
	probe_area_idx = probe_area_ids(round(probe_area_centers));
	probe_area_labels = sGUI.sAtlas.st.acronym(probe_area_idx);
	probe_area_full = sGUI.sAtlas.st.name(probe_area_idx);
	
	%add locations to GUI data
	sGUI.sProbeCoords.sProbeAdjusted.probe_area_ids_per_depth = probe_area_ids;
	sGUI.sProbeCoords.sProbeAdjusted.probe_area_labels_per_depth = sGUI.sAtlas.st.acronym(probe_area_ids);
	sGUI.sProbeCoords.sProbeAdjusted.probe_area_full_per_depth = sGUI.sAtlas.st.name(probe_area_ids);
	
	sGUI.sProbeCoords.sProbeAdjusted.probe_area_boundaries = probe_area_boundaries;
	sGUI.sProbeCoords.sProbeAdjusted.probe_area_centers = probe_area_centers;
	sGUI.sProbeCoords.sProbeAdjusted.probe_area_ids = probe_area_idx;
	sGUI.sProbeCoords.sProbeAdjusted.probe_area_labels = probe_area_labels;
	sGUI.sProbeCoords.sProbeAdjusted.probe_area_full = probe_area_full;
	
	%table; [ML AP ML-deg AP-deg depth length]
	ML = probe_vector_bregma(1);
	AP = probe_vector_bregma(2);
	AngleML = probe_vector_bregma(3);
	AngleAP = probe_vector_bregma(4);
	Depth = probe_vector_bregma(5);
	ProbeLength = probe_vector_bregma(6);
	sGUI.sProbeCoords.sProbeAdjusted.stereo_coordinates = table(ML,AP,AngleML,AngleAP,Depth,ProbeLength);
	
	%area per cluster
	if isfield(sGUI.sClusters,'Clust') && isfield(sGUI.sClusters.Clust,'Depth')
		vecDepth = [sGUI.sClusters.Clust.Depth];
		if numel(vecDepth) ~= numel(sGUI.sClusters.Clust)
			errordlg('Empty cluster entries found');
			error([mfilename ':EmptyEntries'],'Empty cluster entries found');
		end
	else
		vecDepth = [];
	end
	if ~isempty(vecDepth)
		[vecClustAreaId,cellClustAreaLabel,cellClustAreaFull] = PF_GetAreaPerCluster(sGUI.sProbeCoords,vecDepth);
		sGUI.sProbeCoords.sProbeAdjusted.cluster_id = [sGUI.sClusters.Clust.cluster_id];
		sGUI.sProbeCoords.sProbeAdjusted.probe_area_ids_per_cluster = vecClustAreaId;
		sGUI.sProbeCoords.sProbeAdjusted.probe_area_labels_per_cluster = cellClustAreaLabel;
		sGUI.sProbeCoords.sProbeAdjusted.probe_area_full_per_cluster = cellClustAreaFull;
		sGUI.sProbeCoords.sProbeAdjusted.probe_depth_per_cluster = vecDepth;
	else
		sGUI.sProbeCoords.sProbeAdjusted.cluster_id = [];
		sGUI.sProbeCoords.sProbeAdjusted.probe_area_ids_per_cluster = [];
		sGUI.sProbeCoords.sProbeAdjusted.probe_area_labels_per_cluster = {};
		sGUI.sProbeCoords.sProbeAdjusted.probe_area_full_per_cluster = {};
		sGUI.sProbeCoords.sProbeAdjusted.probe_depth_per_cluster = [];
	end
	
	% update gui
	set(sGUI.handles.probe_vector_cart,'XData',probe_vector_cart(:,1), ...
		'YData',probe_vector_cart(:,2),'ZData',probe_vector_cart(:,3));
	set(sGUI.handles.probe_intersect,'XData',vecLocationBrainIntersection(1), ...
		'YData',vecLocationBrainIntersection(2),'ZData',vecLocationBrainIntersection(3));
	set(sGUI.handles.probe_tip,'XData',probe_vector_cart(1,1), ...
		'YData',probe_vector_cart(1,2),'ZData',probe_vector_cart(1,3));
	guidata(hMain, sGUI);
	
	
	% Update the text
	probe_text = ['Brain intersection at: ' ....
		num2str(roundi(probe_vector_bregma(1),1)) ' ML, ', ...
		num2str(roundi(probe_vector_bregma(2),1)) ' AP; ', ...
		'Probe depth ' num2str(roundi(probe_vector_bregma(5),1)) ', ' ...
		num2str(roundi(probe_vector_bregma(3),1)) char(176) ' ML angle, ' ...
		num2str(roundi(probe_vector_bregma(4),1)) char(176) ' AP angle, ' ...
		'Probe length ' num2str(round(probe_vector_bregma(6))) ' microns, ' ...
		num2str(round(sGUI.step_size*100)) '% step size' ...
		];
	%DLH fork: soft check of the fit against the micromanipulator reading. The shank can't
	%stretch, so length / nominal length is the atlas-vs-brain scale along the track. With that
	%scale the tip should sit about scale x insertion depth below the brain entry; what is left
	%is offset error (zeroing, dimpling, drift, atlas vs real entry point), expected to stay
	%within a few hundred um. Insertion depth and warning threshold: configPF.ini
	%(dblInsertDepthUm, dblDepthWarnUm); read once per MATLAB session (clear functions to reload).
	[dblInsertUm,dblWarnUm] = local_insert_depth();
	dblScale = probe_vector_bregma(6) / sGUI.sProbeCoords.ProbeLengthMicrons;
	dblDeltaUm = probe_vector_bregma(5) - dblScale*dblInsertUm;
	strCheck = sprintf(' | stretch %.3f | tip %+d %sm vs %d%s%.3f', dblScale, round(dblDeltaUm), ...
		char(181), round(dblInsertUm), char(215), dblScale);
	vecTextCol = [0 0 0];
	if abs(dblDeltaUm) > dblWarnUm
		strCheck = [strCheck ' - CHECK'];
		vecTextCol = [0.8 0.35 0];
	end
	probe_text = [probe_text strCheck];
	set(sGUI.probe_coordinates_text,'String',probe_text,'ForegroundColor',vecTextCol);
	
	% Update the probe areas
	dblProbeLength = probe_vector_bregma(6);
	dblVoxelSize = mean(sGUI.sAtlas.VoxelSize);
	dblRescaling = dblProbeLength / (sGUI.sProbeCoords.ProbeLengthOriginal*dblVoxelSize);
	yyaxis(sGUI.handles.axes_probe_areas,'right');
	vecLocY = ([1:length(probe_area_ids)]*dblVoxelSize)/dblRescaling;
	set(sGUI.handles.probe_areas_plot,'YData',vecLocY,'CData',probe_area_ids(:));
	%set(sGUI.handles.axes_probe_areas,'YTick',probe_area_centers*dblVoxelSize,'YTickLabels',probe_area_labels);
	
	%DLH fork: labels are drawn by PH_DrawAreaLabels after the YLim update below
	%set(sGUI.handles.axes_probe_areas,'YTick',probe_area_boundaries(2:end)*dblVoxelSize,'YTickLabels',probe_area_full);
	%set(sGUI.handles.axes_probe_areas,'YTickLabelRotation',70,'TickLabelInterpreter','none');
	
	yyaxis(sGUI.handles.axes_probe_areas2,'right');
	set(sGUI.handles.probe_areas_plot2,'YData',vecLocY,'CData',probe_area_ids(:));
	%set(sGUI.handles.axes_probe_areas2,'YTick',probe_area_centers*dblVoxelSize,'YTickLabels',probe_area_labels,'TickLabelInterpreter','none');
	
	%save current data
	sGUI.output.probe_vector = probe_vector_cart;
	sGUI.output.probe_areas = probe_area_ids;
	sGUI.output.probe_intersect = vecLocationBrainIntersection;
	
	%if probe length has changed
	vecOldLim = get(sGUI.handles.probe_zeta,'YLim');
	if boolForceYupdate || abs(vecOldLim(2) - dblProbeLength) > 0.1
		%update ylims
		boolUpdateYLim = true;
		set(sGUI.handles.axes_probe_areas,'YLim',[0 dblProbeLength]);
		set(sGUI.handles.axes_probe_areas2,'YLim',[0 dblProbeLength]);
		
		%rescale correlation image, zeta points and rate
		n_corr_groups = numel(sGUI.handles.probe_xcorr_im.YData);
		depth_group_edges = linspace(0,dblProbeLength,n_corr_groups+1);
		depth_group_centers = depth_group_edges(1:end-1)+(diff(depth_group_edges)/2);
		set(sGUI.handles.probe_xcorr_im,'XData',depth_group_centers,'YData',depth_group_centers);
		
		dblDepthUpdate = dblProbeLength/vecOldLim(2);
		if isfield(sGUI.handles.probe_clust_points,'YData') || isprop(sGUI.handles.probe_clust_points,'YData')
			set(sGUI.handles.probe_clust_points,'YData',sGUI.handles.probe_clust_points.YData*dblDepthUpdate);
		end
		if isfield(sGUI.handles.probe_zeta_points,'YData') || isprop(sGUI.handles.probe_zeta_points,'YData')
			set(sGUI.handles.probe_zeta_points,'YData',sGUI.handles.probe_zeta_points.YData*dblDepthUpdate);
		end
	else
		boolUpdateYLim = false;
	end
	
	%DLH fork: horizontal, non-overlapping acronyms with leader lines on both area bars
	%(replaces full names rotated 70deg at the boundaries). Click a label for its full name.
	vecAreaCentUm = probe_area_centers*dblVoxelSize;
	vecAreaBoundUm = probe_area_boundaries*dblVoxelSize;
	PH_DrawAreaLabels(sGUI.handles.axes_probe_areas,vecAreaCentUm,probe_area_labels,probe_area_full,vecAreaBoundUm);
	PH_DrawAreaLabels(sGUI.handles.axes_probe_areas2,vecAreaCentUm,probe_area_labels,probe_area_full,vecAreaBoundUm);
	
	%% plot boundaries
	%extract boundaries
	matAreaColors = sGUI.cmap(probe_area_ids,:);
	vecBoundY = dblVoxelSize*find(~all(diff(matAreaColors,1,1) == 0,2));
	vecColor = [0.5 0.5 0.5 0.5];
	
	%plot
	cellHandleName = {'probe_clust_bounds','probe_zeta_bounds','probe_xcorr_bounds'};
	cellAxesHandles = {sGUI.handles.probe_clust,sGUI.handles.probe_zeta,sGUI.handles.probe_xcorr};
	for intPlot=1:numel(cellHandleName)
		delete(sGUI.handles.(cellHandleName{intPlot}));
		hAx = cellAxesHandles{intPlot};
		if strcmpi(hAx.Visible,'off'),continue;end
		if boolUpdateYLim,set(hAx,'YLim',[0 dblProbeLength]);end
		if intPlot==3
			if boolUpdateYLim,set(hAx,'XLim',[0 dblProbeLength]);end
			vecLimX = get(hAx,'xlim');
			boundary_lines2 = line(hAx,repmat(vecBoundY,1,2)',repmat(vecLimX,numel(vecBoundY),1)','Color',vecColor,'LineWidth',1);
		else
			boundary_lines2 = [];
		end
		vecLimX = get(hAx,'xlim');
		boundary_lines = line(hAx,repmat(vecLimX,numel(vecBoundY),1)',repmat(vecBoundY,1,2)','Color',vecColor,'LineWidth',1);
		sGUI.handles.(cellHandleName{intPlot}) = cat(1,boundary_lines,boundary_lines2);
	end
	
	% Upload gui_data
	guidata(hMain, sGUI);
	
	
	%% update slice
	PH_UpdateSlice(hMain);
	
end

function [dblInsertUm,dblWarnUm] = local_insert_depth()
	%DLH fork: insertion depth along the probe axis (L&N reading) and the |tip offset| above
	%which the coordinates text turns orange. Defaults 5600 and 300 um if configPF.ini lacks them.
	persistent dblIns dblWarn
	if isempty(dblIns)
		dblIns = 5600; dblWarn = 300;
		try
			v = PF_getIniVar('dblInsertDepthUm'); if ischar(v), v = str2double(v); end; if isnumeric(v) && isscalar(v) && v > 0, dblIns = double(v); end
			v = PF_getIniVar('dblDepthWarnUm'); if ischar(v), v = str2double(v); end; if isnumeric(v) && isscalar(v) && v > 0, dblWarn = double(v); end
		catch
		end
	end
	dblInsertUm = dblIns; dblWarnUm = dblWarn;
end
