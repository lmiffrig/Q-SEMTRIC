function [density,diameter,orientation,statsd_rem]=QSEMTRIC(BW,br_L);
warning('off');
density = numel(find(BW))/numel(BW);

%% extracting fibers
% create skeleton
imSkeld=bwmorph(BW,'thin',inf);
imOutd=bwmorph(BW,'remove');


%% defining branches
imBranchPtd=bwmorph(imSkeld,'branchpoints');

% dilate branch point logical
se=strel('disk',2);
imBranchDil=imdilate(imBranchPtd,se);
% remove dilated branch points from skeletal images 
imBranchd= imSkeld&~imBranchDil;

% label branches 
imBranchLabd = bwlabel(imBranchd,8);

% determine length of branches

statsd=regionprops(imBranchLabd,'Area','PixelIdxList');

% find branches less than the length set by the suser and remove them
smBrd=find(vertcat(statsd.Area)<br_L);

for k = 1:length(smBrd)
    imBranchLabd(imBranchLabd == smBrd(k)) = 0;
end


%% fiber characteristic extraction and display
statsd_rem=regionprops(imBranchLabd,'Area','PixelIdxList','Orientation','MajorAxisLength','MinorAxisLength','Centroid');
statsd_rem=statsd_rem((vertcat(statsd_rem.Area)>0));
for i=1:numel(statsd_rem)
    [r,c]=ind2sub(size(imBranchLabd),statsd_rem(i).PixelIdxList(1));
    statsd_rem(i).BranchID=imBranchLabd(r,c);
end
clear c
%% Find branch diameters and local tangent orientations 
vec_s=cell(length(statsd_rem),1);

for i=1:length(statsd_rem)
        [vec_s{i}(:,1), vec_s{i}(:,2)]=ind2sub(size(imBranchLabd),statsd_rem(i).PixelIdxList);
end



[im_bd(:,1),im_bd(:,2)]=ind2sub(size(imBranchLabd),find(imOutd));
pt_theta=[];
br_id=[];
 for n=1:length(vec_s)
     
            x=vec_s{n}(:,2);
            y=vec_s{n}(:,1);
            % find 5 closest points on line segment
            [~,idx]=pdist2(vec_s{n},vec_s{n},'euclidean','Smallest',5);
            
            for i=1:size(idx,2)
                % determine which orientation to choose based on the angle
                % defined by the end points 
                theta(i)=atan2(y(idx(1,i))-y(idx(5,i)),x(idx(1,i))-x(idx(5,i)))*180/pi;
                theta(i) = mod(theta(i) + 90, 180) - 90; % Normalize theta to the range of -90 to 90
                if abs(theta(i))<=45
                    %fit line to the five points 
                    c(i,:)=polyfit(x(idx(:,i)),y(idx(:,i)),1);
                    % define a line with each point and the associated tangent orhogonal
                    k=1:0.1:size(imOutd,2);
                    h=-1/c(i,1).*(k-x(i))+y(i);
                    % sort points on line and associated distance in ascending distance from point on branch
                    [dis]=pdist2([x(i) y(i)],[k.' h.'],'euclidean');
                    [~,idx2]=sort(dis);
                    k=round(k(idx2));
                    h=round(h(idx2));
                    dis=dis(idx2);
                    % check to see which points are also contained in the segment edge array
                    zz=ismember([k.' h.'],[im_bd(:,2) im_bd(:,1)],'rows');
                    % find the first instance this occurs
                    if mean(zz)>0
                        zz_i=find(zz);
                        xmin{n}(i)=k(zz_i(1));
                        ymin{n}(i)=h(zz_i(1));
                        min_d{n}(i)=dis(zz_i(1));
                    else 
                        xmin{n}(i)=NaN;
                        ymin{n}(i)=NaN;
                        min_d{n}(i)=NaN;
                    end
                    theta_n=atan(c(i,1));
                else 
                    %fit line to the five points 
                    c(i,:)=polyfit(y(idx(:,i)),x(idx(:,i)),1);
                    % define a line with each point and the associated tangent orhogonal
                    k=1:0.1:size(imOutd,2);
                    h=-1/c(i,1).*(k-y(i))+x(i);
                    % sort points on line and associated distance in ascending distance from point on branch
                    [dis]=pdist2([y(i) x(i)],[k.' h.'],'euclidean');
                    [~,idx2]=sort(dis);
                    k=round(k(idx2));
                    h=round(h(idx2));
                    dis=dis(idx2);
                    % check to see which points are also contained in the segment edge array
                    zz=ismember([k.' h.'],[im_bd(:,1) im_bd(:,2)],'rows');
                    % find the first instance this occurs
                    if mean(zz)>0
                        zz_i=find(zz);
                        ymin{n}(i)=k(zz_i(1));
                        xmin{n}(i)=h(zz_i(1));
                        min_d{n}(i)=dis(zz_i(1)); % this represents half the diameter in pixel dimensions
                    else 
                        ymin{n}(i)=NaN;
                        xmin{n}(i)=NaN;
                        min_d{n}(i)=NaN;
                    end
                    theta_n=atan(1/c(i,1));
                end
                pt_theta=[pt_theta; x(idx(1,i)) y(idx(1,i)) c(i,:) theta(i) theta_n*180/pi];
                br_id   =[br_id; n];
            end
            
 end

diameter=[br_id fliplr(cell2mat(vec_s)) cell2mat(min_d).'];
orientation=[fliplr(cell2mat(vec_s)) pt_theta(:,end)];

% bin_sz=0.25; % in microns
% offset=0.1; %proportion of overlapping bins
% clear idx
% % wt_or_25_10=cell(12,4);
% %  xv=cell(12,4);
% % yv=cell(12,4);
% 
% % for i=1:12;
% % for j=1:4;
% % define xand y grid lines to create
% xbin2=[1:offset*100:size(imGB,2) size(imGB,2)];
% ybin2=[1:offset*100:size(imGB,1) size(imGB,1)];
% %define x and y grid lines using offset
% xbin=repmat(xbin2,length(ybin2),1);
% ybin=repmat(ybin2.',1,length(xbin2));
% xv=cell(size(xbin));
% yv=cell(size(ybin));
% in=cell(size(xbin));
% wt_or_25_10=NaN(size(xv));
% for q=1:(size(xbin,1)-1); % can redefine xv and yv using the bin size if decide to use an offset to define the edges
%     for t=1:(size(xbin,2)-1);
%         xv{q,t}=[xbin(q,t) xbin(q,t)+bin_sz*100 xbin(q,t)+bin_sz*100 xbin(q,t)]; %defines x location of vertices for inpolygon function
%         yv{q,t}=[ybin(q,t) ybin(q,t) ybin(q,t)+bin_sz*100 ybin(q,t)+bin_sz*100]; % defines y location of vertices for inpolygon function
%         if ~isempty(xv{q,t})
%             [in{q,t}]=inpolygon(pt_theta(:,1),pt_theta(:,2),[xv{q,t} xv{q,t}(1)],[yv{q,t} yv{q,t}(1)]);
%             idx{q,t}=find(in{q,t});
%             if length(idx{q,t})==1;
%                 wt_or_25_10(q,t)=pt_theta(idx{q,t},end);
%             else
%                 wt_or_25_10(q,t)=mean(pt_theta(idx{q,t},end));
%             end
%         end
%     end
% end
end