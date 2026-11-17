function PH_DrawAreaLabels(hAx,vecCentY,cellLabels,cellFull,vecBoundY)
	%PH_DrawAreaLabels Horizontal, non-overlapping area labels beside a probe-area bar (DLH fork)
	%   PH_DrawAreaLabels(hAx,vecCentY,cellLabels,cellFull,vecBoundY)
	%
	%Replaces UPF's rotated tick labels. Each region's acronym is written horizontally to the
	%right of the colour bar. Where labels would collide they are spread apart (least-squares:
	%each sits as close to its region centre as the minimum row spacing allows) and joined to
	%the region by a thin leader line. If more regions exist than rows fit, the thinnest ones go
	%unlabelled. Region boundaries keep a tick mark. Click a label to print its full name.
	%
	%   hAx        axes holding the area bar (a yyaxis axes, as built by PH_GenGUI)
	%   vecCentY   region centres, in the axes' y units (µm along the probe, rescaled)
	%   cellLabels acronyms, one per region
	%   cellFull   full names, one per region
	%   vecBoundY  region boundaries (numel(vecCentY)+1), same units

	%% options
	dblFontSize = 9;      %pt
	dblRowPadPx = 2;      %extra px between label rows
	dblLeaderPx = 14;     %length of the leader line
	dblTextGapPx = 3;     %gap between leader end and text
	vecLeaderCol = [0.45 0.45 0.45];

	%% clear previous labels, keep boundary tick marks without text
	delete(findall(hAx,'Tag','PH_AreaLabel'));
	yyaxis(hAx,'right');
	vecTicks = unique(vecBoundY(isfinite(vecBoundY)));
	set(hAx,'YTick',vecTicks(:)','YTickLabel',{});
	if isempty(vecCentY),return;end

	%% geometry: data units per pixel
	vecPosPx = getpixelposition(hAx);
	vecXLim = get(hAx,'XLim');
	vecYLim = get(hAx,'YLim');
	set(hAx,'XLimMode','manual'); %leader lines sit outside the bar; don't let them rescale it
	dblYPerPx = diff(vecYLim)/max(vecPosPx(4),1);
	dblXPerPx = diff(vecXLim)/max(vecPosPx(3),1);
	dblPxPerPt = get(groot,'ScreenPixelsPerInch')/72;
	dblRow = (dblFontSize*1.25*dblPxPerPt + dblRowPadPx)*dblYPerPx; %one label row, in y units

	%% choose which regions get a label (largest first if they don't all fit)
	vecCentY = vecCentY(:);
	intN = numel(vecCentY);
	if numel(vecBoundY) == intN+1
		vecSize = abs(diff(vecBoundY(:)));
	else
		vecSize = ones(intN,1);
	end
	intMaxRows = max(1,floor(diff(vecYLim)/dblRow));
	indKeep = isfinite(vecCentY);
	if sum(indKeep) > intMaxRows
		vecSizeK = vecSize; vecSizeK(~indKeep) = -inf;
		[~,vecOrd] = sort(vecSizeK,'descend');
		indKeep(:) = false;
		indKeep(vecOrd(1:intMaxRows)) = true;
	end
	vecIdx = find(indKeep);
	[vecY,vecSort] = sort(vecCentY(vecIdx));
	vecIdx = vecIdx(vecSort);

	%% place: minimise sum((L-y).^2) s.t. L(i+1)-L(i) >= dblRow, L within limits
	%substitute z = L - i*dblRow -> isotonic regression of (y - i*dblRow), then clip
	intK = numel(vecY);
	vecI = (1:intK)';
	dblLo = vecYLim(1) + dblRow/2;
	dblHi = vecYLim(2) - dblRow/2;
	vecZ = local_isotonic(vecY - vecI*dblRow);
	vecZ = min(max(vecZ, dblLo - dblRow), dblHi - intK*dblRow);
	vecLabY = vecZ + vecI*dblRow;

	%% draw
	dblX0 = vecXLim(2);                        %right edge of the bar
	dblX1 = dblX0 + dblLeaderPx*dblXPerPx;     %end of leader
	dblXT = dblX1 + dblTextGapPx*dblXPerPx;    %text start
	dblXK = dblX0 + 0.35*(dblX1-dblX0);        %kink: horizontal stub, then angle to the label
	for i=1:intK
		j = vecIdx(i);
		strAcr = char(cellLabels{j});
		strFull = char(cellFull{j});
		line(hAx,[dblX0 dblXK dblX1],[vecY(i) vecY(i) vecLabY(i)], ...
			'Color',vecLeaderCol,'LineWidth',0.5,'Clipping','off','HitTest','off', ...
			'HandleVisibility','off','Tag','PH_AreaLabel');
		text(hAx,dblXT,vecLabY(i),strAcr, ...
			'FontSize',dblFontSize,'FontWeight','bold','Interpreter','none', ...
			'HorizontalAlignment','left','VerticalAlignment','middle','Clipping','off', ...
			'HandleVisibility','off','Tag','PH_AreaLabel', ...
			'ButtonDownFcn',@(varargin) fprintf('[UPF] %s = %s\n',strAcr,strFull));
	end
end

function vecZ = local_isotonic(vecT)
	%pool-adjacent-violators: least-squares non-decreasing fit, equal weights
	intN = numel(vecT);
	vecVal = zeros(intN,1); vecW = zeros(intN,1); vecLen = zeros(intN,1);
	k = 0;
	for i=1:intN
		k = k+1; vecVal(k) = vecT(i); vecW(k) = 1; vecLen(k) = 1;
		while k > 1 && vecVal(k-1) > vecVal(k)
			vecVal(k-1) = (vecVal(k-1)*vecW(k-1) + vecVal(k)*vecW(k)) / (vecW(k-1)+vecW(k));
			vecW(k-1) = vecW(k-1) + vecW(k);
			vecLen(k-1) = vecLen(k-1) + vecLen(k);
			k = k-1;
		end
	end
	vecZ = repelem(vecVal(1:k),vecLen(1:k));
	vecZ = vecZ(:);
end
