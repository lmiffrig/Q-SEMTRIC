function SEMClotGUI()
    % Create the main figure
    hFig = figure('Name', 'Image Processing GUI', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 800, 600]);

    % Upload button
    uicontrol('Style', 'pushbutton', 'String', 'Upload Image', ...
              'Position', [20, 700, 100, 30], 'Callback', @uploadImage);

    % Axes for displaying the image
    hAxes = axes('Parent', hFig, 'Position', [0.2, 0.2, 0.6, 0.6]);

    
    % Button to define ROIs
    uicontrol('Style', 'pushbutton', 'String', 'Define ROIs', ...
              'Position', [20, 600, 100, 30], 'Callback', @defineROIs);

    % Storage for ROIs
    rois = [];

    % Function to define ROIs
    function defineROIs(~, ~)
        % Get the current image displayed
        img = getimage(hAxes);
        if isempty(img)
            errordlg('No image loaded. Please upload an image first.', 'Error');
            return;
        end
        
        % Allow user to select multiple ROIs
        roi = drawrectangle('Color', 'r', 'LineWidth', 2);
        wait(roi); % Wait for the user to finish drawing
        
        % Store the position of the ROI
        rois = [rois; roi.Position]; % Append new ROI position
        fprintf('ROI defined at: [%.2f, %.2f, %.2f, %.2f]\n', roi.Position);
        
        % Update sliders based on the number of ROIs
        updateSliders();
    end

    % Function to update sliders based on the number of ROIs
    function updateSliders()
        numROIs = size(rois, 1);
        for i = 1:numROIs
            % Adjust slider values or create new sliders as needed
            % This is a placeholder for further implementation
            fprintf('Adjusting sliders for ROI %d\n', i);
        end
    end

    % Dropdown for selecting ROIs
    uicontrol('Style', 'popupmenu', 'String', {'Select ROI'}, ...
              'Position', [20, 150, 100, 30], 'Callback', @selectROI);

    % Function to select ROI
    function selectROI(src, ~)
        selectedIndex = src.Value;
        if selectedIndex > 1
            selectedROI = rois(selectedIndex - 1, :);
            % fprintf('Selected ROI: [%.2f, %.2f, %.2f, %.2f]\n', selectedROI);
            % Here you can implement further processing for the selected ROI
        else
            fprintf('No ROI selected.\n');
        end
    end

    % Update the dropdown menu with ROI options
    function updateROIDropdown()
        numROIs = size(rois, 1);
        roiStrings = arrayfun(@(x) sprintf('ROI %d', x), 1:numROIs, 'UniformOutput', false);
        set(findobj('Style', 'popupmenu', 'String', {'Select ROI'}), 'String', ['Select ROI'; roiStrings']);
    end

    % Sliders for image processing parameters
    sliders = zeros(1, 6);
    for i = 1:6
        sliders(i) = uicontrol('Style', 'slider', 'Min', 0, 'Max', 100, ...
                                'Value', 50, 'Position', [20, 500 - (i-1)*50, 100, 20], ...
                                'Callback', @(src, event) updateParameter(i, src.Value));
        uicontrol('Style', 'text', 'String', sprintf('Parameter %d', i), ...
                  'Position', [130, 500 - (i-1)*50, 100, 20]);
    end

    % Dropdown for selecting output parameters
    uicontrol('Style', 'popupmenu', 'String', {'Output 1', 'Output 2', 'Output 3', ...
              'Output 4', 'Output 5'}, 'Position', [20, 100, 100, 30], ...
              'Callback', @selectOutput);

    % Function to upload image
    function uploadImage(~, ~)
        [fileName, pathName] = uigetfile({'*.jpg;*.png;*.bmp;*.TIF', 'Image Files (*.jpg, *.png, *.bmp, *.TIF)'});
        if isequal(fileName, 0)
            return; % User canceled
        end
        img = imread(fullfile(pathName, fileName));
        imshow(img, 'Parent', hAxes);
    end

    % Function to update parameters based on slider value
    function updateParameter(paramIndex, value)
        % Here you can implement the logic to process the image based on the slider value
        fprintf('Parameter %d updated to %.2f\n', paramIndex, value);
    end

    % Function to select output parameter
    function selectOutput(src, ~)
        selectedOutput = src.String{src.Value};
        fprintf('Selected output: %s\n', selectedOutput);
    end
end