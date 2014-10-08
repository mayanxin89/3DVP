function [pos, neg, spos] = kitti_data_joint(cls, data, centers, flippedpos, is_train, is_continue)

% Get training data from the KITTI dataset.

globals; 
pascal_init;

filename = [cachedir cls '_train.mat'];
if is_continue == 1 && exist(filename, 'file') ~= 0
  load(filename);
else
  % positive examples from kitti
  root_dir = KITTIroot;
  data_set = 'training';

  % get sub-directories
  cam = 2; % 2 = left color camera
  image_dir = fullfile(root_dir, [data_set '/image_' num2str(cam)]);
  label_dir = fullfile(root_dir, [data_set '/label_' num2str(cam)]);
  
  % get number of images for this dataset
  index = find(data.idx ~= -1);
  num_train = numel(index);
  
  pos = [];
  numpos = 0;
  cids = [];
  for i = 1:num_train
    fprintf('%s : parsing positives: %d/%d\n', cls, i, num_train);
    ind = index(i);
    numpos = numpos+1;
    pos(numpos).im = fullfile(image_dir, data.imgname{ind});
    info = imfinfo(pos(numpos).im);
    bbox = data.bbox(:,ind);
    pos(numpos).x1 = bbox(1);
    pos(numpos).y1 = bbox(2);
    pos(numpos).x2 = bbox(3);
    pos(numpos).y2 = bbox(4);
    pos(numpos).flip = false;
    pos(numpos).trunc = 0;
    cids(numpos) = data.idx(ind);
    if flippedpos
      oldx1 = bbox(1);
      oldx2 = bbox(3);
      bbox(1) = info.Width - oldx2 + 1;
      bbox(3) = info.Width - oldx1 + 1;
      numpos = numpos+1;
      pos(numpos).im = fullfile(image_dir, data.imgname{ind});
      pos(numpos).x1 = bbox(1);
      pos(numpos).y1 = bbox(2);
      pos(numpos).x2 = bbox(3);
      pos(numpos).y2 = bbox(4);
      pos(numpos).flip = true;
      pos(numpos).trunc = 0;
      cids(numpos) = data.idx(ind);
    end
  end
  
  % split positive examples
  num = numel(centers);
  spos = cell(1,num);
  for i = 1:num
      index = cids == centers(i);
      spos{i} = pos(index);
  end  

  % negative examples from kitti
  switch cls
      case 'car'
          str_pos = {'Car', 'Van', 'DontCare'};
      otherwise
          fprintf('undefined classes for negatives\n');
  end
  object = load('kitti_ids.mat');
  if is_train
      ids = object.ids_train;
  else
      ids = [object.ids_train object.ids_val];
  end
  neg = [];
  numneg = 0;
  for i = 1:length(ids);
    fprintf('%s : parsing negatives: %d/%d\n', cls, i, length(ids));
    numneg = numneg+1;
    neg(numneg).im = sprintf('%s/%06d.png', image_dir, ids(i));
    neg(numneg).flip = false;
    
    objects = readLabels(label_dir, ids(i));
    n = numel(objects);
    bbox = [];
    count = 0;
    for j = 1:n
        if sum(strcmp(objects(j).type, str_pos)) > 0
            count = count + 1;
            bbox(count,:) = [objects(j).x1 objects(j).y1 objects(j).x2 objects(j).y2];
        end
    end
    neg(numneg).bbox = bbox;
  end
  
  save(filename, 'pos', 'neg', 'spos');
end  