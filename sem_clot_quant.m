%% image call and ROI definition
% call image 
file=uigetfile('*.tif'); 
data=Tiff(file);
im=read(data);

% ask for the center location of 4 locations 
figure
imshow(im);
im_c=cell(4,1); rect_out=zeros(4,4);
for i=1:length(im_c)
[im_c{i},rect_out(i,:)]=imcrop(im);
end

% QUALITY CHECK
figure
imshow(im);
hold on
for i=1:4;
plot([rect_out(i,1), rect_out(i,1)+rect_out(i,3),rect_out(i,1)+rect_out(i,3),rect_out(i,1),rect_out(i,1)],[rect_out(i,2),rect_out(i,2),rect_out(i,2)+rect_out(i,4),rect_out(i,2)+rect_out(i,4),rect_out(i,2)],'LineWidth',5)
end
figure
montage(im_c);
%% pre-processing with 2D gaussian filter and foreground enhancement
imGB=cellfun(@(x) imgaussfilt(x,2),im_c,'UniformOutput',false);

disk_diam=100;

se=strel('disk',disk_diam); % define blurring disk roughly the size of mid range fibril 
bckgrd=cellfun(@(x) imopen(x,se),imGB,'UniformOutput',false); 

im_c2=cellfun(@(x,y) x-y,imGB,bckgrd,'UniformOutput',false);

im_c3=cellfun(@imadjust,im_c2,'UniformOutput',false);

%QUALITY CHECK
figure
montage(im_c3)



%% segmentation using adaptive threshold 
close all
imth=cellfun(@(x) adaptthresh(x,0.75),im_c3,'UniformOutput',false);
imBW=cellfun(@(x,y) imbinarize(x,y),im_c3,imth,'UniformOutput',false);
B=cellfun(@labeloverlay,imGB,imBW,'UniformOutput',false);

%QUALITY CHECK
figure
montage(B);

%% manually zero out areas in background enhanced image to avoid over-segmentation -> re-run above section every time you run this one
[xx,yy]=meshgrid(1:size(im_c3{4},2),1:size(im_c3{4},1));
% close all
figure
imshow(imGB{4});
figure 
imshow(B{4})
roi=drawpolygon;

in=inpolygon(xx,yy,roi.Position(:,1),roi.Position(:,2));
in=abs(1-in);
im_c3{4}=im_c3{4}.*uint8(in);

%% smooth segmentation

%smooth segmentation with 2D convolution
imBW_sm=cellfun(@(x) ~bwareaopen(x,1000),~imBW,'UniformOutput',false); % remove segmented areas not relevant <um^2, can vary this to see if it improves segmentation)
imBW_sm=cellfun(@(x) bwareaopen(x,1000),imBW_sm,'UniformOutput',false); % fill holes <um^2, can vary this to see if it improves segmentation)

windowSize = 12; %can vary this to see if it improves 
kernel = ones(windowSize) / windowSize ^ 2;
im_blur = cellfun(@(x) conv2(x, kernel, 'same'),imBW_sm,'UniformOutput',false);
im_sm = cellfun(@(x) x > 0.5,im_blur,'UniformOutput',false); % Rethreshold blurred image to make binary again
B=cellfun(@labeloverlay,imGB,im_sm,'UniformOutput',false);

%QUALITY CHECK
figure 
montage(B)


%% dilate segmentation
strel('disk',1); %vary disk size to improve 
I_dil=cellfun(@(x) imdilate(x,se),im_sm,'UniformOutput',false);

% QUALITY CHECK
B=cellfun(@labeloverlay,imGB,I_dil,'UniformOutput',false);
figure
montage(B)

%% extracting fibers
% create skeleton
imOutd=cellfun(@(x) bwmorph(x,'remove'),I_dil,'UniformOutput',false);
% imSkel=bwmorph(I,'skel',inf);
imSkeld=cellfun(@(x) bwmorph(x,'thin',inf),I_dil,'UniformOutput',false);

% QUALITY CHECK
figure 
for i=1:4
    subplot(2,2,i)
    imshow(B{i});
    hold on
    [x,y]=find(imSkeld{i});
    scatter(y,x,3,'k');
end

%% defining branches
imBranchPtd=cellfun(@(x) bwmorph(x,'branchpoints'),imSkeld,'UniformOutput',false);
imBranchd=cellfun(@(x,y) x&~y,imSkeld,imBranchPtd,'UniformOutput',false);
imBranchLabd=cellfun(@(x) bwlabel(x,8),imBranchd,'UniformOutput',false);

% QUALITY CHECK
figure
for i=1:4
    subplot(2,2,i)
    imshow(imGB{i});
    hold on
    [x,y]=find(imSkeld{i});
    scatter(y,x,5,'k');
    [xb,yb]=find(imBranchPtd{i});
    scatter(yb,xb,'r','filled')
end

% dilate branch point logical
se=strel('disk',2);
imBranchDil=cellfun(@(x) imdilate(x,se),imBranchPtd,'UniformOutput',false);



% remove dilated branch points from skeletal images 
imBranchd=cellfun(@(x,y) x&~y,imSkeld,imBranchDil,'UniformOutput',false);

% relabel branches with dilated branch points removed
imBranchLabd=cellfun(@(x) bwlabel(x,8),imBranchd,'UniformOutput',false);

% determine length of branches
statsd=cellfun(@(x) regionprops(x,'Area','PixelIdxList'),imBranchLabd,'UniformOutput',false);

% find branches less than 0.25 um in length and remove them
smBrd=cellfun(@(x) find(vertcat(x.Area)<50),statsd,'UniformOutput',false);

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

% QUALITY CHECK
% plot individual branches with the small ones removed 
figure
for j=1:4
    subplot(2,2,j)
    imshow(imGB{j});
    hold on
    idx=unique(imBr_remd{j});
    idx=idx(2:end);
    col=jet(length(idx));
    n=randperm(length(col));
    for i=1:length(idx);
        [x,y]=find(imBr_remd{j}==idx(i));
        scatter(y,x,[],col(n(i),:),'filled');
    end
end

%% fiber characteristic extraction and display
statsd_rem=cellfun(@(x) regionprops(x,'Area','PixelIdxList','Orientation','MajorAxisLength','MinorAxisLength','Centroid'),imBr_remd,'UniformOutput',false);
idx0=cellfun(@(x) find(vertcat(x.Area)),statsd_rem,'UniformOutput',false);
statsd_rem=cellfun(@(x,y) x(y),statsd_rem,idx0,'UniformOutput',false);

%% outputs

% fiber absolute length 
FibL=cellfun(@(x) vertcat(x.Area),statsd_rem,'UniformOutput',false);

% fiber major axis length 
FibAxL=cellfun(@(x) vertcat(x.MajorAxisLength),statsd_rem,'UniformOutput',false);

% fiber orientation
FibOr=cellfun(@(x) vertcat(x.Orientation),statsd_rem,'UniformOutput',false);

%% Displacy fiber vector characteristics 
% as individidual results from each of the ROIs
t=tiledlayout(2,2);
for i=1:4
    nexttile
    histogram(FibAxL{i}/100,'binwidth',0.25)
    xlim([0.0500    4.4500])
    ylim([0 140])
    ylabel('Frequency')
    xlabel('Length (um)')
end
title(t,'Major Axis Length')
t.Padding='compact';
t.TileSpacing='compact';

% as composite results differentiation by color 
figure
hold on
histogram(cell2mat(FibAxL)/100,'BinWidth',0.25)
ylabel('Frequency')
xlabel('Length (um)')
title(t,'Major Axis Length')    

t=tiledlayout(2,2);
for i=1:4
    nexttile
    histogram(FibOr{i},'binwidth',5)
    ylabel('Frequency')
    xlabel('Angle (degrees)')
end
title(t,'FiberOrientation')
t.Padding='compact';
t.TileSpacing='compact';

% as composite results differentiation by color 
figure
hold on
histogram(cell2mat(FibOr),'BinWidth',5)
ylabel('Frequency')
xlabel('Angle (degrees)')
title(t,'Fiber Orientation')    

% radial projection of length and orientation
figure
for j=1:4
    subplot(2,2,j);
    col=jet(length(FibAxL{j}));
    n=randperm(length(col));
    for i=1:length(FibAxL{j})
        plot([0 abs(FibAxL{j}(i)*cos(FibOr{j}(i)))],[0 FibAxL{j}(i)*sin(FibOr{j}(i))],'LineWidth',3,'Color',col(n(i),:))
        hold on
    end
    for q=1:10
     plot(q*25*cos(linspace(0,2*pi,100)),q*25*sin(linspace(0,2*pi,100)),'k');
    end
    axis equal
    xlim([0 250])
    ylim([-250 250])
end

%% fiber diameter determination
% define segment r,c locations
for j=1:4
    for i=1:length(statsd_rem{j})
        [vec_s{j}{i}(:,1), vec_s{j}{i}(:,2)]=ind2sub(size(imBr_remd{j}),statsd_rem{j}(i).PixelIdxList);
    end
end 

% %METHOD I
% % find the distance to all the boundary points on the segmented image
% [im_bd(:,1),im_bd(:,2)]=cellfun(@(x,y) ind2sub(size(x),find(y)),imBr_remd,imOutd,'UniformOutput',false);
% for i=1:4
% vec_d{i}=cellfun(@(x) pdist2(x,[im_bd{i,1} im_bd{i,2}]),vec_s{i},'UniformOutput',false);
% [min_d{i},idx_min{i}]=cellfun(@(x) min(x.'),vec_d{i},'UniformOutput',false);
% % report the median value for each branch
% med_dis{i}=cellfun(@median,min_d{i});
% % quality check for each branches point to make sure there isn't a huge
% % swing in calculated distance by point (std dev and range)
% sd_dist{i}=cellfun(@std,min_d{i});
% range_dist{i}=cellfun(@range,min_d{i});
% end

%METHOD II
% define an orthogonal line at each point at find closest point on the
% segmentation edge

% define segmentation edge points
[im_bd(:,1),im_bd(:,2)]=cellfun(@(x,y) ind2sub(size(x),find(y)),imBr_remd,imOutd,'UniformOutput',false);

% to define tangent and orthogonal line based on primary orientatoin (i.e.
% > or < 45 degrees 
tic
for j=1:length(vec_s);
    for n=1:length(vec_s{j})
            x=vec_s{j}{n}(:,2);
            y=vec_s{j}{n}(:,1);
            % find 5 closest points on line segment
            [d,idx]=pdist2(vec_s{j}{n},vec_s{j}{n},'euclidean','Smallest',5);
            
            for i=1:size(idx,2)
                % determine which orientation to choose based on the angle
                % defined by the end points 
                theta(i)=atan2(y(idx(1,i))-y(idx(5,i)),x(idx(1,i))-x(idx(5,i)))*180/pi;
                if abs(theta(i))<=45
                    %fit line to the five points 
                    c(i,:)=polyfit(x(idx(:,i)),y(idx(:,i)),1);
                    % define a line with each point and the associated tangent orhogonal
                    k=1:0.1:size(imOutd{j},2);
                    h=-1/c(i,1).*(k-x(i))+y(i);
                    % sort points on line and associated distance in ascending distance from point on branch
                    [dis]=pdist2([x(i) y(i)],[k.' h.'],'euclidean');
                    [~,idx2]=sort(dis);
                    k=round(k(idx2));
                    h=round(h(idx2));
                    dis=dis(idx2);
                    % check to see which points are also contained in the segment edge array
                    zz=ismember([k.' h.'],[im_bd{j,2} im_bd{j,1}],'rows');
                    % find the first instance this occurs
                    if mean(zz)>0
                        zz_i=find(zz);
                        xmin{j}{n}(i)=k(zz_i(1));
                        ymin{j}{n}(i)=h(zz_i(1));
                        min_d{j}{n}(i)=dis(zz_i(1));
                    else 
                        xmin{j}{n}(i)=NaN;
                        ymin{j}{n}(i)=NaN;
                        min_d{j}{n}(i)=NaN;
                    end
                else 
                    %fit line to the five points 
                    c(i,:)=polyfit(y(idx(:,i)),x(idx(:,i)),1);
                    % define a line with each point and the associated tangent orhogonal
                    k=1:0.1:size(imOutd{j},2);
                    h=-1/c(i,1).*(k-y(i))+x(i);
                    % sort points on line and associated distance in ascending distance from point on branch
                    [dis]=pdist2([y(i) x(i)],[k.' h.'],'euclidean');
                    [~,idx2]=sort(dis);
                    k=round(k(idx2));
                    h=round(h(idx2));
                    dis=dis(idx2);
                    % check to see which points are also contained in the segment edge array
                    zz=ismember([k.' h.'],[im_bd{j,1} im_bd{j,2}],'rows');
                    % find the first instance this occurs
                    if mean(zz)>0
                        zz_i=find(zz);
                        ymin{j}{n}(i)=k(zz_i(1));
                        xmin{j}{n}(i)=h(zz_i(1));
                        min_d{j}{n}(i)=dis(zz_i(1)); % this represents half the diameter in pixel dimensions
                    else 
                        ymin{j}{n}(i)=NaN;
                        xmin{j}{n}(i)=NaN;
                        min_d{j}{n}(i)=NaN;
                    end
                end
           end
       end
end
toc
 
for i=1:4
     med_dis{i}=cellfun(@nanmedian,min_d{i});
end

% QUALITY CHECK
figure
for i=1:4;
    subplot(2,2,i)
    histogram(med_dis{i}*2/100)
    ylabel('Frequency')
    xlabel('Fiber Diameter [microns]');
    set(gca,'FontSize',12)
end


figure
histogram(cell2mat(med_dis)*2/100);
    ylabel('Frequency')
    xlabel('Fiber Diameter [microns]');
    set(gca,'FontSize',12)
