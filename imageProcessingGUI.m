function imageProcessingGUI
% IMAGEPROCESSINGGUI
% Simple GUI that:
%  - Loads an image
%  - Lets the user draw and store multiple subselections (ROIs)
%  - Has 6 sliders for image-processing parameters
%  - Lets the user choose which of 5 outputs to display
%  - Processes all stored ROIs with current parameters
%
% Requirements:
%  - Image Processing Toolbox (for rgb2gray, im2double, drawrectangle)
%  - additional functions needed: getPixelResolution, 

    % ---------------------------
    % Figure & base state
    % ---------------------------
    hFig = figure( ...
        'Name', 'Image Processing GUI', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Units', 'normalized', ...
        'Position', [0.1 0.1 0.8 0.8]);

    handles = struct();
    handles.figure = hFig;
    handles.originalImage = [];
    handles.rois = [];                 % struct array with fields: Position, ROIHandle
    handles.params =    [100   0.5    10   5000     6    1   0.5]; % seven parameters, initial as midpoint or suspected optimal
    handles.paramMins = [1,     0,    1,    1000,     1,   0,   0];   % will need to update these based on the image resolution
    handles.paramMaxs = [200,   1,    500,  10000,  16,    6,   100]; % will need to update these based on the image resolution
    handles.selectedRoiIndex = [];      % track which ROI is selected in the table
    handles.roiDefaultColor      = [0 1 0];  % green
    handles.roiHighlightColor    = [1 0 0];  % red
    handles.roiDefaultLineWidth  = 1.5;
    handles.roiHighlightLineWidth = 3;
    handles.showingROI = false;             % are we displaying a cropped ROI?
    handles.currentRoiIndexForView = [];    % which ROI is currently displayed (if any)
    handles.segmentationActive        = false;
    handles.segmentationFig           = [];
    handles.segmentationAxesOriginal  = [];
    handles.segmentationAxesOutput    = [];
    handles.segmentationRoiIndex      = [];
    handles.lastSegmentationBinary    = [];   % store latest binary seg image
    handles.pixelSizeX = NaN;     % microns per pixel (X)
    handles.pixelSizeY = NaN;     % microns per pixel (Y)
    handles.scaleBarLengthUm = 5; % scale bar length in microns
    handles.scaleBarHandle = [];
    handles.scaleBarTextHandle = [];
    

    % ---------------------------
    % Axes for image display
    % ---------------------------
    handles.imgAxes = axes( ...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.05 0.25 0.4 0.7]);
    title(handles.imgAxes, 'Image');

    % ---------------------------
    % ROI table (stores subselections)
    % ---------------------------
    handles.roiTable = uitable( ...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.05 0.05 0.4 0.15], ...
        'Data', {}, ...
        'ColumnName', {'ID','X','Y','Width','Height','Seg?'}, ...
        'ColumnEditable', false(1,6), ...
        'CellSelectionCallback', @roiTableSelectionCallback);
    


    % ---------------------------
    % Buttons: Load image & Add subselection
    % ---------------------------
    handles.loadButton = uicontrol( ...
        'Style', 'pushbutton', ...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.05 0.95 0.1 0.04], ...
        'String', 'Load Image', ...
        'FontWeight', 'bold', ...
        'FontSize', 14, ...
        'Callback', @loadImageCallback);

    handles.addRoiButton = uicontrol( ...
        'Style', 'pushbutton', ...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.18 0.95 0.12 0.04], ...
        'String', 'Add Subselection (ROI)', ...
        'FontWeight', 'bold', ...
        'FontSize', 14, ...
        'Callback', @addSubselectionCallback);

    handles.deleteRoiButton = uicontrol( ...
        'Style', 'pushbutton', ...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.31 0.95 0.1 0.04], ...
        'String', 'Delete Selected ROI', ...
        'FontWeight', 'bold', ...
        'FontSize', 14, ...
        'Callback', @deleteRoiCallback);

    handles.showFullImageButton = uicontrol( ...
        'Style', 'pushbutton', ...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.05 0.90 0.15 0.04], ...
        'String', 'Show Full Image', ...
        'FontWeight', 'bold', ...
        'FontSize', 14, ...
        'Callback', @showFullImageCallback);


    % ---------------------------
    % Sliders for 6 parameters
    % ---------------------------
    handles.slider = gobjects(1,6);
    handles.sliderLabel = gobjects(1,6);
    handles.sliderValue = gobjects(1,6);
    
    param_name=["Background Removal" "Sensitivity Threshold" "Fill" "Remove" "Smoothing" "Dilation" "Branch Size"];

    for k = 1:7
    y = 0.9 - (k-1)*0.075;

     % Label
        handles.sliderLabel(k) = uicontrol( ...
        'Style', 'text', ...
            'Parent', hFig, ...
            'Units', 'normalized', ...
            'Position', [0.50 y 0.08 0.05], ...
            'String', param_name(k), ...
            'FontSize', 14, ...
            'HorizontalAlignment', 'left');

        % Slider with custom limits
        handles.slider(k) = uicontrol( ...
            'Style', 'slider', ...
            'Parent', hFig, ...
            'Units', 'normalized', ...
            'Position', [0.58 y 0.25 0.05], ...
            'Min', handles.paramMins(k), ...
            'Max', handles.paramMaxs(k), ...
            'Value', (handles.paramMins(k) + handles.paramMaxs(k))/2, ... % center default
            'Callback', @(src,evt) sliderCallback(src, evt, k));

        % Display numeric value
        handles.sliderValue(k) = uicontrol( ...
            'Style', 'text', ...
            'Parent', hFig, ...
            'Units', 'normalized', ...
            'Position', [0.84 y 0.06 0.05], ...
            'String', sprintf('%.3f', handles.slider(k).Value), ...
            'HorizontalAlignment', 'left');
    end

    % ---------------------------
    % Manual Edit button (to the right of sliders)
    % ---------------------------
    handles.manualEditButton = uicontrol( ...
    'Style', 'pushbutton', ...
    'Parent', hFig, ...
    'Units', 'normalized', ...
    'Position', [0.88 0.63 0.10 0.06], ...  % adjust position as you like
    'String', 'Manual Edit', ...
    'FontWeight', 'bold', ...
    'Callback', @ManualEdit);

    % ---------------------------
    % Save segmentation to workspace (TEMPORARY!!)
    % ---------------------------

    handles.saveToWorkspaceButton = uicontrol( ...
    'Style', 'pushbutton', ...
    'Parent', hFig, ...
    'Units', 'normalized', ...
    'Position', [0.88 0.58 0.10 0.06], ...  % tweak as needed
    'String', 'Save to Workspace', ...
    'FontWeight', 'bold', ...
    'Callback', @saveSegmentationToWorkspaceCallback);


    % ---------------------------
    % Output selection 
    % ---------------------------
    outputNames = {'Fiber Density','Diameter','Length','Orientation'};
    handles.outputCheckbox = gobjects(1,4);

    for j = 1:4
        x = 0.5 + (j-1)*0.07;
        handles.outputCheckbox(j) = uicontrol( ...
            'Style', 'checkbox', ...
            'Parent', hFig, ...
            'Units', 'normalized', ...
            'Position', [x 0.4 0.2 0.05], ...
            'String', outputNames{j}, ...
            'Value', 1); % default: all on
    end

    % ---------------------------
    % Results table for outputs; will need to change this likely to be
    % graphical displays 
    % ---------------------------
    handles.resultsTable = uitable( ...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.50 0.05 0.45 0.28], ...
        'Data', {}, ...
        'ColumnName', {'ROI','Out1','Out2','Out3','Out4','Out5'}, ...
        'ColumnEditable', false(1,6));

    % ---------------------------
    % Process button
    % ---------------------------
    handles.processButton = uicontrol( ...
    'Style', 'pushbutton', ...
    'Parent', hFig, ...
    'Units', 'normalized', ...
    'Position', [0.80 0.35 0.1 0.04], ...   % <-- moved here
    'String', 'Run Processing', ...
    'FontWeight', 'bold', ...
    'FontSize', 14,...
    'Callback', @processButtonCallback);

    % Store handles
    guidata(hFig, handles);

    handles.startSegButton = uicontrol( ...
    'Style', 'pushbutton', ...
    'Parent', hFig, ...
    'Units', 'normalized', ...
    'Position', [0.65 0.35 0.1 0.04], ...  % adjust if you like
    'String', 'Start Segmentation', ...
    'FontWeight', 'bold', ...
    'FontSize', 14,...
    'Callback', @startSegmentationCallback);

    % =====================================================================
    % Nested callback functions
    % =====================================================================

function loadImageCallback(hObject, ~)
    handles = guidata(hObject);

    [file, path] = uigetfile( ...
        {'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.dcm', 'Image Files'; ...
         '*.*', 'All Files (*.*)'}, ...
        'Select an image');
    if isequal(file,0)
        return; % user canceled
    end

    fullName = fullfile(path, file);
    img = imread(fullName);
    prompt  = {'Enter Image Magnification, if no answer provided will assume 2500x'};
    titleDlg = 'Image Magnification';
    defAns={'2500'};
    mag=inputdlg(prompt,titleDlg,1,defAns);
    if isempty(mag)
        % User hit Cancel
        return;
    end
    mag=str2double(mag{1});
    handles.originalImage = img;
    handles.rois = [];
    set(handles.roiTable, 'Data', {});
    
    % --- Get pixel resolution from metadata ---

    [pxX, pxY] = getPixelResolution(fullName,mag);  % in microns per pixel

    % If resolution is missing or NaN, ask user
    if isnan(pxX) || isnan(pxY)
        prompt  = {'Enter pixel size in microns per pixel (X):', ...
                   'Enter pixel size in microns per pixel (Y):'};
        titleDlg   = 'Pixel Resolution Required';
        defAns = {'0.1','0.1'};  % default guess, adjust as you like

        answer = inputdlg(prompt, titleDlg, 1, defAns);
        if isempty(answer)
            % User cancelled; leave as NaN
            pxX = NaN;
            pxY = NaN;
        else
            pxX = str2double(answer{1});
            pxY = str2double(answer{2});
            if isnan(pxX) || isnan(pxY) || pxX <= 0 || pxY <= 0
                warndlg('Invalid pixel size entered. Scale bar will not be shown.', ...
                        'Invalid Input');
                pxX = NaN;
                pxY = NaN;
            end
        end
    end

    handles.pixelSizeX = pxX;    % store under handles.*
    handles.pixelSizeY = pxY;

    % Reset view mode
    handles.showingROI = false;
    handles.currentRoiIndexForView = [];

    guidata(hObject, handles);

    % Use your existing image display helper so everything is consistent
    hFigLocal = ancestor(hObject, 'figure');
    updateImageDisplay(hFigLocal);   % this will draw the image + scale bar
end

    function addSubselectionCallback(hObject, ~)
        handles = guidata(hObject);

        if isempty(handles.originalImage)
            errordlg('Load an image first.', 'No Image');
            return;
        end

        % Let user draw a rectangular ROI
        axes(handles.imgAxes); %#ok<LAXES>
        roi = drawrectangle(handles.imgAxes);
        % Optional: wait until user double-clicks / finishes ROI
        wait(roi);

        pos = roi.Position; % [x y width height]

        % Set default visual style for ROI
        roi.Color     = handles.roiDefaultColor;
        roi.LineWidth = handles.roiDefaultLineWidth;

        newEntry = struct('Position', pos, 'ROIHandle', roi);

        if isempty(handles.rois)
            handles.rois = newEntry;
        else
            handles.rois(end+1) = newEntry; %#ok<AGROW>
        end

        % Update ROI table
        n = numel(handles.rois);
        data = cell(n,6);
        for i = 1:n
            p = handles.rois(i).Position;
            data{i,1} = i;
            data{i,2} = p(1);
            data{i,3} = p(2);
            data{i,4} = p(3);
            data{i,5} = p(4);

        % Segmentation checkmark
        if isfield(handles.rois(i), 'binarySegmentation') && ~isempty(handles.rois(i).binarySegmentation)
            data{i,6} = char(10003);  % Unicode checkmark ✓
        else
            data{i,6} = '';           % empty if no segmentation saved
        end
    end
    set(handles.roiTable, 'Data', data);

        guidata(hObject, handles);
    end

    function roiTableSelectionCallback(hObject, eventData)
        hFigLocal = ancestor(hObject, 'figure');
        handles = guidata(hFigLocal);

        if isempty(eventData.Indices)
            % No selection: show full image
            handles.selectedRoiIndex = [];
            handles.showingROI = false;
            handles.currentRoiIndexForView = [];
        else
            % Use the first selected row
            row = eventData.Indices(1);
            handles.selectedRoiIndex = row;
            handles.showingROI = true;
            handles.currentRoiIndexForView = row;
        end

        % Update highlighting on all ROIs
        if ~isempty(handles.rois)
            for i = 1:numel(handles.rois)
                if ~isfield(handles.rois(i), 'ROIHandle') || ~isvalid(handles.rois(i).ROIHandle)
                    continue;
                end

                if ~isempty(handles.selectedRoiIndex) && i == handles.selectedRoiIndex
                    % Highlight this ROI
                    handles.rois(i).ROIHandle.Color     = handles.roiHighlightColor;
                    handles.rois(i).ROIHandle.LineWidth = handles.roiHighlightLineWidth;
                    try
                        uistack(handles.rois(i).ROIHandle, 'top');
                    catch
                    end
                else
                    % Reset to default style
                    handles.rois(i).ROIHandle.Color     = handles.roiDefaultColor;
                    handles.rois(i).ROIHandle.LineWidth = handles.roiDefaultLineWidth;
                end
            end
        end

        guidata(hFigLocal, handles);

        % Now update what is shown in the axes (ROI crop or full image)
        updateImageDisplay(hFigLocal);
    end

    function sliderCallback(hObject, ~, idx)
        hFigLocal = ancestor(hObject, 'figure');
        handles = guidata(hFigLocal);

        val = get(hObject, 'Value');
        handles.params(idx) = val;

        % Value display formatting based on each slider's range
        if handles.paramMaxs(idx) - handles.paramMins(idx) < 5
            fmt = '%.3f';
        else
            fmt = '%.2f';
        end

        set(handles.sliderValue(idx), 'String', sprintf(fmt, val));

        guidata(hFigLocal, handles);

        % Update segmentation preview if it's active
        if handles.segmentationActive
            updateSegmentationPreview(hFigLocal);
        end
    end


    function processButtonCallback(hObject, ~)
        hFigLocal = ancestor(hObject, 'figure');
        handles = guidata(hFigLocal);

        if isempty(handles.originalImage)
            errordlg('Load an image first.', 'No Image');
            return;
        end

        if isempty(handles.rois)
            errordlg('Add at least one subselection (ROI) first.', 'No ROIs');
            return;
        end

        img = handles.originalImage;
        params = handles.params;

        % Which outputs are selected?
        activeOutputs = false(1,4);
        for j = 1:4
            activeOutputs(j) = logical(get(handles.outputCheckbox(j), 'Value'));
        end

        nROIs = numel(handles.rois);
        results = nan(nROIs, 4);

        % Process each ROI
        for i = 1:nROIs
            pos = handles.rois(i).Position; % [x y w h]

            % Convert ROI position to pixel indices
            x1 = max(1, round(pos(1)));
            y1 = max(1, round(pos(2)));
            x2 = min(size(img,2), x1 + round(pos(3)) - 1);
            y2 = min(size(img,1), y1 + round(pos(4)) - 1);

            roiImg = img(y1:y2, x1:x2, :);

            % --- Your processing function here ---
            out = processImagePlaceholder(roiImg, params);
            % results(i,:) = [out.out1, out.out2, out.out3, out.out4, out.out5];
        end

        % Prepare table data (blank entries for unselected outputs)
        data = cell(nROIs, 6);
        for i = 1:nROIs
            data{i,1} = i; % ROI index
            for j = 1:4
                if activeOutputs(j)
                    data{i,j+1} = results(i,j);
                else
                    data{i,j+1} = []; % leave blank
                end
            end
        end
        set(handles.resultsTable, 'Data', data);

        guidata(hFigLocal, handles);
    end

    function deleteRoiCallback(hObject, ~)
        hFigLocal = ancestor(hObject, 'figure');
        handles = guidata(hFigLocal);

        if isempty(handles.rois)
            errordlg('There are no ROIs to delete.', 'No ROIs');
            return;
        end

        if isempty(handles.selectedRoiIndex)
            errordlg('Select an ROI in the table first.', 'No ROI Selected');
            return;
        end

        idx = handles.selectedRoiIndex;

        if idx < 1 || idx > numel(handles.rois)
        errordlg('Selected ROI index is out of range.', 'Error');
            return;
        end

        % Delete the ROI graphic from the axes
        if isfield(handles.rois(idx), 'ROIHandle') && isvalid(handles.rois(idx).ROIHandle)
            delete(handles.rois(idx).ROIHandle);
        end

        % Remove from the ROI struct array
        handles.rois(idx) = [];

        % Rebuild the ROI table data with updated IDs
        n = numel(handles.rois);
        roiData = cell(n, 5);
        for i = 1:n
            p = handles.rois(i).Position;
            roiData{i,1} = i;      % ID
            roiData{i,2} = p(1);   % X
            roiData{i,3} = p(2);   % Y
            roiData{i,4} = p(3);   % Width
            roiData{i,5} = p(4);   % Height
        end
        set(handles.roiTable, 'Data', roiData);

        % Also remove corresponding row from results table, if present
        resultsData = get(handles.resultsTable, 'Data');
        if ~isempty(resultsData) && size(resultsData,1) >= idx
            resultsData(idx, :) = [];
            % Re-label ROI IDs in results table to stay consistent
            for i = 1:size(resultsData,1)
                resultsData{i,1} = i;  % first column is ROI index
            end
            set(handles.resultsTable, 'Data', resultsData);
        end

        % Clear current selection
        handles.selectedRoiIndex = [];

        guidata(hFigLocal, handles);
    end

    function updateImageDisplay(hFigLocal)
        handles = guidata(hFigLocal);

        if isempty(handles.originalImage)
            return;
        end

        img = handles.originalImage;

        % -------------------------
        % Case 1: Show cropped ROI
        % -------------------------
        if handles.showingROI && ...
        ~isempty(handles.currentRoiIndexForView) && ...
        handles.currentRoiIndexForView >= 1 && ...
        handles.currentRoiIndexForView <= numel(handles.rois)

            idx = handles.currentRoiIndexForView;
            pos = handles.rois(idx).Position; % [x y w h]

            % Convert ROI position to pixel indices
            x1 = max(1, round(pos(1)));
            y1 = max(1, round(pos(2)));
            x2 = min(size(img,2), x1 + round(pos(3)) - 1);
            y2 = min(size(img,1), y1 + round(pos(4)) - 1);

            roiImg = img(y1:y2, x1:x2, :);

            % Show ONLY the ROI crop (axes get cleared)
            imshow(roiImg, 'Parent', handles.imgAxes);
            title(handles.imgAxes, sprintf('ROI %d', idx));

            % Any old ROIHandle objects in handles.rois are now invalid, but
            % that's fine; we don't use them in this view.

else
    % -------------------------
    % Case 2: Show full image
    % -------------------------
    imshow(img, 'Parent', handles.imgAxes);
    title(handles.imgAxes, 'Image');
    
    % Re-create all ROI rectangle overlays on top of the full image
    if ~isempty(handles.rois)
        for i = 1:numel(handles.rois)
            p = handles.rois(i).Position;
            
            % Write text on the image indicating the ROI ID
            text(handles.imgAxes, p(1), p(2), sprintf('ROI %d', i), ...
                'Color', 'yellow', 'FontSize', 12, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            roiObj = drawrectangle(handles.imgAxes, 'Position', p);

            if ~isempty(handles.selectedRoiIndex) && i == handles.selectedRoiIndex
                roiObj.Color     = handles.roiHighlightColor;
                roiObj.LineWidth = handles.roiHighlightLineWidth;
            else
                roiObj.Color     = handles.roiDefaultColor;
                roiObj.LineWidth = handles.roiDefaultLineWidth;
            end

            handles.rois(i).ROIHandle = roiObj;
        end
    end

    % 🔹 Draw or update the 5 µm scale bar
    drawScaleBar(hFigLocal);
end

guidata(hFigLocal, handles);

    end


    function showFullImageCallback(hObject, ~)
        hFigLocal = ancestor(hObject, 'figure');
        handles = guidata(hFigLocal);

        handles.showingROI = false;
        handles.currentRoiIndexForView = [];

        guidata(hFigLocal, handles);

        updateImageDisplay(hFigLocal);
    end


    
    function startSegmentationCallback(hObject, ~)
        hFigLocal = ancestor(hObject, 'figure');
        handles = guidata(hFigLocal);

        

        if isempty(handles.originalImage)
            errordlg('Load an image first.', 'No Image');
            return;
        end

        if isempty(handles.selectedRoiIndex)
            errordlg('Select an ROI in the ROI table first.', 'No ROI Selected');
            return;
        end

        idx = handles.selectedRoiIndex;
        if idx < 1 || idx > numel(handles.rois)
            errordlg('Selected ROI index is out of range.', 'Error');
            return;
        end
  
        handles.segmentationActive   = true;
        handles.segmentationRoiIndex = idx;

        % Create or reuse the segmentation preview figure
        if isempty(handles.segmentationFig) || ~ishandle(handles.segmentationFig)
            segFig = figure( ...
                'Name', 'Segmentation Preview', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Units', 'normalized', ...
                'Position', [0.15 0.15 0.7 0.7]);



            handles.segmentationFig = segFig;

            % Two axes: original (left) and output (right)
            handles.segmentationAxesOriginal = subplot(1,2,1, 'Parent', segFig);
            handles.segmentationAxesOutput   = subplot(1,2,2, 'Parent', segFig);

            % 🔹 Add "Save Binary Image" button in the segmentation window
            handles.segmentationSaveButton = uicontrol( ...
                'Style', 'pushbutton', ...
                'Parent', segFig, ...
                'Units', 'normalized', ...
                'Position', [0.35 0.02 0.3 0.06], ...  % bottom-center, adjust if you like
                'String', 'Save Binary Image', ...
                'FontWeight', 'bold', ...
                'FontSize', 14, ...
                'UserData', hFigLocal, ...             % store main GUI figure handle
                'Callback', @saveSegmentationCallback);

        else
            segFig = handles.segmentationFig;
            figure(segFig); % bring it to front
        end

        guidata(hFigLocal, handles);

        % Initial draw
        updateSegmentationPreview(hFigLocal);
    end

    
function updateSegmentationPreview(hFigLocal)
    handles = guidata(hFigLocal);

    if ~isfield(handles, 'segmentationActive') || ~handles.segmentationActive
        return;
    end
    if isempty(handles.segmentationFig) || ~ishandle(handles.segmentationFig)
        return;
    end
    if isempty(handles.originalImage) || isempty(handles.segmentationRoiIndex)
        return;
    end

    img = handles.originalImage;
    idx = handles.segmentationRoiIndex;

    if idx < 1 || idx > numel(handles.rois)
        return;
    end

    % Crop ROI from the original image
    pos = handles.rois(idx).Position; % [x y w h]
    x1 = max(1, round(pos(1)));
    y1 = max(1, round(pos(2)));
    x2 = min(size(img,2), x1 + round(pos(3)) - 1);
    y2 = min(size(img,1), y1 + round(pos(4)) - 1);
    roiImg = img(y1:y2, x1:x2, :);

    % Ensure axes exist
    if isempty(handles.segmentationAxesOriginal) || ~ishandle(handles.segmentationAxesOriginal)
        figure(handles.segmentationFig);
        handles.segmentationAxesOriginal = subplot(1,2,1);
    end
    if isempty(handles.segmentationAxesOutput) || ~ishandle(handles.segmentationAxesOutput)
        figure(handles.segmentationFig);
        handles.segmentationAxesOutput = subplot(1,2,2);
    end

    % Show original ROI on the left
    imshow(roiImg, 'Parent', handles.segmentationAxesOriginal);
    title(handles.segmentationAxesOriginal, sprintf('ROI %d - Original', idx));

    % --- 1) Compute base segmentation from sliders ---
    baseSeg = segmentationFunctionPlaceholder(roiImg, handles.params);

    if ~islogical(baseSeg)
        baseSeg = baseSeg > 0.5;
    end

    % --- 2) Apply any stored manual edits for this ROI ---
    segImg = baseSeg;

    if isfield(handles.rois(idx), 'manualRemoveMask') && ...
       ~isempty(handles.rois(idx).manualRemoveMask) && ...
       isequal(size(handles.rois(idx).manualRemoveMask), size(segImg))
        segImg(handles.rois(idx).manualRemoveMask) = 0;
    end

    % (If you later add manualAddMask, you'd OR it in here)
    % if isfield(handles.rois(idx), 'manualAddMask'), seg(handles.rois(idx).manualAddMask) = 1; end

    % --- 3) Display final segmentation on the right ---
    imshow(labeloverlay(roiImg, segImg), [], 'Parent', handles.segmentationAxesOutput);
    title(handles.segmentationAxesOutput, 'Segmentation');

    % --- 4) Store final segmentation for this ROI + global ---
    handles.lastSegmentationBinary = segImg;
    handles.rois(idx).binarySegmentation = segImg;
    

    % Refresh ROI table "Seg?" column
    n = numel(handles.rois);
    if n > 0
        data = get(handles.roiTable, 'Data');
        if size(data,2) < 6
            data = cell(n,6);
        end
        for i = 1:n
            p = handles.rois(i).Position;
            data{i,1} = i;
            data{i,2} = p(1);
            data{i,3} = p(2);
            data{i,4} = p(3);
            data{i,5} = p(4);
            if isfield(handles.rois(i),'binarySegmentation') && ...
               ~isempty(handles.rois(i).binarySegmentation)
                data{i,6} = char(10003); % ✓
            else
                data{i,6} = '';
            end
        end
        set(handles.roiTable, 'Data', data);
    end

    guidata(hFigLocal, handles);
end

function saveSegmentationCallback(hObject, ~)
    mainFig = get(hObject, 'UserData');
    handles = guidata(mainFig);

    if isempty(handles.lastSegmentationBinary)
        errordlg('No segmentation available to save. Run segmentation first.', 'No Data');
        return;
    end

    idx = handles.segmentationRoiIndex;

    % Save binary segmentation internally
    handles.rois(idx).binarySegmentation = handles.lastSegmentationBinary;
    handles.rois(idx).savedParams = handles.params;

    % --- REFRESH ROI TABLE HERE ---
    n = numel(handles.rois);
    data = cell(n,6);
    for i = 1:n
        p = handles.rois(i).Position;
        data{i,1} = i;
        data{i,2} = p(1);
        data{i,3} = p(2);
        data{i,4} = p(3);
        data{i,5} = p(4);
        if isfield(handles.rois(i),'binarySegmentation') && ~isempty(handles.rois(i).binarySegmentation)
            data{i,6} = char(10003);   
        else
            data{i,6} = '';
        end
    end
    set(handles.roiTable, 'Data', data);
    % --------------------------------

    guidata(mainFig, handles);

    msgbox(sprintf('Binary segmentation stored for ROI %d.', idx), 'Saved');
end

function drawScaleBar(hFigLocal)
    handles = guidata(hFigLocal);

    % Need a valid resolution to draw a physical scale bar
    if isnan(handles.pixelSizeX) || handles.pixelSizeX <= 0
        return;
    end

    ax = handles.imgAxes;
    img = handles.originalImage;
    if isempty(img) || ~ishandle(ax)
        return;
    end

    % Delete old scale bar if it exists
    if ~isempty(handles.scaleBarHandle) && isvalid(handles.scaleBarHandle)
        delete(handles.scaleBarHandle);
    end
    if ~isempty(handles.scaleBarTextHandle) && isvalid(handles.scaleBarTextHandle)
        delete(handles.scaleBarTextHandle);
    end

    % Image size
    imgSize = size(img);
    imgH = imgSize(1);
    imgW = imgSize(2);

    % Length of scale bar in pixels (use X resolution)
    L_um = handles.scaleBarLengthUm;       % e.g. 5 microns
    pxPerUmX = 1 / handles.pixelSizeX;     % pixels per micron
    barLengthPx = L_um * pxPerUmX;

    % --- TOP RIGHT placement ---
    marginPx = 10;

    x2 = imgW - marginPx;              % right edge
    x1 = x2 - barLengthPx;             % left end of scale bar

    if x1 < marginPx
        x1 = marginPx;                 % prevent bar from overflowing left
    end

    y = marginPx + 100;                  % small offset down from the top edge

    % Draw white line
    hold(ax, 'on');
    handles.scaleBarHandle = line(ax, [x1 x2], [y y], ...
                                  'Color', 'w', ...
                                  'LineWidth', 2);

    % Label: "5 µm" just below the bar
    handles.scaleBarTextHandle = text(ax, (x1 + x2)/2, y + 200, ...
                                      sprintf('%.1f \\mum', L_um), ...
                                      'Color', 'w', ...
                                      'HorizontalAlignment', 'center', ...
                                      'VerticalAlignment', 'bottom', ...
                                      'FontSize', 14, ...
                                      'FontWeight', 'bold');

    hold(ax, 'off');

    guidata(hFigLocal, handles);
end

    function ManualEdit(hObject, ~)


        % Main GUI figure handle
        hFigMain = ancestor(hObject, 'figure');
        handles = guidata(hFigMain);

        % Need an active segmentation + preview window
        if ~isfield(handles, 'segmentationActive') || ~handles.segmentationActive || ...
                isempty(handles.segmentationFig) || ~ishandle(handles.segmentationFig)
            errordlg('Start segmentation and select an ROI before manual editing.', ...
                'No Segmentation');
            return;
        end
        if isempty(handles.lastSegmentationBinary)
            errordlg('No segmentation available to edit. Run segmentation first.', ...
                'No Data');
            return;
        end

        idx = handles.segmentationRoiIndex;
        pos = handles.rois(idx).Position; % [x y w h]
        img = handles.originalImage;

        % Convert ROI position to pixel indices
        x1 = max(1, round(pos(1)));
        y1 = max(1, round(pos(2)));
        x2 = min(size(img,2), x1 + round(pos(3)) - 1);
        y2 = min(size(img,1), y1 + round(pos(4)) - 1);

        roiImg = img(y1:y2, x1:x2, :);
        if isempty(idx) || idx < 1 || idx > numel(handles.rois)
            errordlg('No valid ROI associated with this segmentation.', 'Error');
            return;
        end

        % Bring segmentation window to front
        figure(handles.segmentationFig);
        axOut = handles.segmentationAxesOutput;
        if isempty(axOut) || ~ishandle(axOut)
            errordlg('Segmentation output axes not available.', 'Error');
            return;
        end

        % Let user draw polygon on segmentation output
        axes(axOut);
        hPoly = drawpolygon(axOut, 'LineWidth', 1.5);
        wait(hPoly);  % wait for double-click/finish

        maskPoly = createMask(hPoly);
        delete(hPoly);

        % Ensure we have a manualRemoveMask for this ROI
        segImg = handles.lastSegmentationBinary;
        if ~islogical(segImg)
            segImg = segImg > 0.5;
        end

        if ~isfield(handles.rois(idx), 'manualRemoveMask') || ...
                isempty(handles.rois(idx).manualRemoveMask) || ...
                ~isequal(size(handles.rois(idx).manualRemoveMask), size(segImg))
            handles.rois(idx).manualRemoveMask = false(size(segImg));
        end

        % Accumulate removal region
        handles.rois(idx).manualRemoveMask = ...
            handles.rois(idx).manualRemoveMask | maskPoly;

        % Apply removal to current segmentation for immediate visual feedback
        segImg(maskPoly) = 0;

        % Store updated segmentation
        handles.lastSegmentationBinary      = segImg;
        handles.rois(idx).binarySegmentation = segImg;

        % Refresh ROI table's Seg? column
        n = numel(handles.rois);
        if n > 0
            data = get(handles.roiTable, 'Data');
            if size(data,2) < 6
                data = cell(n,6);
            end
            for i = 1:n
                p = handles.rois(i).Position;
                data{i,1} = i;
                data{i,2} = p(1);
                data{i,3} = p(2);
                data{i,4} = p(3);
                data{i,5} = p(4);
                if isfield(handles.rois(i),'binarySegmentation') && ...
                        ~isempty(handles.rois(i).binarySegmentation)
                    data{i,6} = char(10003); % ✓
                else
                    data{i,6} = '';
                end
            end
            set(handles.roiTable, 'Data', data);
        end

        % Update what is displayed in the segmentation window
        imshow(labeloverlay(roiImg, segImg), [], 'Parent', axOut);
        title(axOut, 'Segmentation (edited)');

        guidata(hFigMain, handles);
    end

    function saveSegmentationToWorkspaceCallback(hObject, ~)
        % Main GUI figure
        hFigMain = ancestor(hObject, 'figure');
        handles = guidata(hFigMain);

        % Need a selected ROI
        if isempty(handles.selectedRoiIndex)
            errordlg('Select an ROI in the ROI table first.', 'No ROI Selected');
            return;
        end

        idx = handles.selectedRoiIndex;

        if idx < 1 || idx > numel(handles.rois)
            errordlg('Selected ROI index is out of range.', 'Error');
            return;
        end

        % Make sure this ROI has a saved segmentation
        if ~isfield(handles.rois(idx), 'binarySegmentation') || ...
                isempty(handles.rois(idx).binarySegmentation)
            errordlg('No binary segmentation saved for this ROI.', 'No Segmentation');
            return;
        end

        BW = handles.rois(idx).binarySegmentation;

        % Suggest a default variable name like 'seg_ROI3'
        defaultVarName = sprintf('seg_ROI%d', idx);

        answer = inputdlg({'Enter variable name for workspace:'}, ...
            'Save Segmentation to Workspace', ...
            1, {defaultVarName});

        if isempty(answer)
            % User cancelled
            return;
        end

        varName = strtrim(answer{1});

        if isempty(varName) || ~isvarname(varName)
            errordlg('Invalid variable name.', 'Error');
            return;
        end

        % Assign to base workspace
        assignin('base', varName, BW);

        msgbox(sprintf('Binary segmentation for ROI %d saved as "%s" in the workspace.', ...
            idx, varName), ...
            'Saved');
end



    % =====================================================================
    % Image Segmentation Workflow
    % =====================================================================
    function segImg = segmentationFunctionPlaceholder(roiImg, params)
        % Convert ROI to grayscale double
        if ndims(roiImg) == 3
            I = rgb2gray(roiImg);
        else
            I = roiImg;
        end
        I = im2double(I);
        % Apply 2D Gaussian filter
        Igb = imgaussfilt(I,2);

        % Background feature removal 
        disk_diam=round(params(1));

        se=strel('disk',disk_diam); % define blurring disk roughly the size of mid range fibril 
        bckgrd= imopen(Igb,se); 

        im_c2=Igb-bckgrd;

        im_c3=imadjust(im_c2);
        
        % adaptive threshold segmentation
        th=params(2);     
        imth=adaptthresh(im_c3,th);
        BW=imbinarize(im_c3,imth);

        % Fill holes in segmentation
        fl=round(params(3));
        BWfl=~bwareaopen(~BW,fl);

        % Remove disconnected pieces from segmentation
        re=round(params(4));
        BWrem=bwareaopen(BWfl,re,8); % fill holes of segmentation

        % Smooth Image Edges 
        windowSize = round(params(5));  
        kernel = ones(windowSize) / windowSize ^ 2;
        im_blur = conv2(BWrem, kernel, 'same');
        im_sm = im_blur> 0.5; % Rethreshold blurred image to make binary again
        
        % Dilation
        dil=round(params(6));
        se=strel('disk',dil); 
        I_dil=imdilate(im_sm,se);

        seg=I_dil;
        segImg = I_dil; % binary segmentation image

        idx=handles.segmentationRoiIndex;
        handles.lastSegmentationBinary= segImg;
        handles.rois(idx).binarySegmentation=seg; 
    end

    % =====================================================================
    % Diameter and Orientation Calculation
    % =====================================================================
        function runAnalysisCallback(hObject, ~)
        hFig = ancestor(hObject, 'figure');
        handles = guidata(hFig);


            
        
        
    end
    % =====================================================================
    % Quantify and export the stored parameters (binary segmentation,
    % location mapped orientation and fiber diameters) 
    % =====================================================================
    function out = processImagePlaceholder(roiImg, params)
        % Convert to grayscale double for simple example metrics
        if ndims(roiImg) == 3
            I = rgb2gray(roiImg);
        else
            I = roiImg;
        end
        I = im2double(I);
        
        idx = handles.selectedRoiIndex;

        if isempty(idx) || ~isfield(handles.rois(idx), 'binarySegmentation')
            errordlg('No segmentation saved for this ROI.', 'Missing data');
            return;
        end

        BW = handles.rois(idx).binarySegmentation;
        imOutd= bwmorph(BW,'remove');
        % imSkel=bwmorph(I,'skel',inf);
        imSkeld=bwmorph(BW,'thin',inf);
        
        imBranchPtd=cellfun(@(x) bwmorph(x,'branchpoints'),imSkeld,'UniformOutput',false);
        imBranchd=cellfun(@(x,y) x&~y,imSkeld,imBranchPtd,'UniformOutput',false);
        imBranchLabd=cellfun(@(x) bwlabel(x,8),imBranchd,'UniformOutput',false);

        se=strel('disk',2);
        imBranchDil=cellfun(@(x) imdilate(x,se),imBranchPtd,'UniformOutput',false);
        
        
        
        % remove dilated branch points from skeletal images 
        imBranchd=cellfun(@(x,y) x&~y,imSkeld,imBranchDil,'UniformOutput',false);
        
        % relabel branches with dilated branch points removed
        imBranchLabd=cellfun(@(x) bwlabel(x,8),imBranchd,'UniformOutput',false);
        
        % determine length of branches
        statsd=cellfun(@(x) regionprops(x,'Area','PixelIdxList'),imBranchLabd,'UniformOutput',false);
        
        % find branches less than the defined user length and remove them 
        smBrd=cellfun(@(x) find(vertcat(x.Area)<params(6)),statsd,'UniformOutput',false);
        
        imBr_remd=imBranchLabd;
        for j=1:4
            N=arrayfun(@(x)length(find(imBr_remd{j}==x)),unique(imBr_remd{j}),'UniformOutput',false);
            N=cell2mat(N);
            Z=unique(imBr_remd{j});
            for i=1:length(N);
                if N(i)<25
                    t=find(imBr_remd{j}==Z(i));
                    imBr_remd{j}(t)=0;
                end
            end
        end
    
        statsd_rem=cellfun(@(x) regionprops(x,'Area','PixelIdxList','Orientation','MajorAxisLength','MinorAxisLength','Centroid'),imBr_remd,'UniformOutput',false);
        idx0=cellfun(@(x) find(vertcat(x.Area)),statsd_rem,'UniformOutput',false);
        statsd_rem=cellfun(@(x,y) x(y),statsd_rem,idx0,'UniformOutput',false);


        out = regionprops(BW, 'Area', 'Perimeter');

        disp(out);
        
        % out = struct( ...
        %     'out1', meanVal, ...
        %     'out2', stdVal, ...
        %     'out3', maxVal, ...
        %     'out4', minVal, ...
        %     'out5', medianVal);
    end

end

    % =====================================================================
    % Additional functionality to perform 
    % =====================================================================

