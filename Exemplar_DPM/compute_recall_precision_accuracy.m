% compute recall and viewpoint accuracy
function [recall, precision, accuracy, ap, aa] = compute_recall_precision_accuracy(cls, data, is_2d, K, vnum_train, vnum_test)

if nargin < 6
    vnum_test = vnum_train;
end

azimuth_interval = [0 (360/(vnum_test*2)):(360/vnum_test):360-(360/(vnum_test*2))];

% load clustering data
% object = load('../PASCAL3D/data.mat');
% data = object.data;

% read ids of validation images
globals;
pascal_init;
path_ann_view = [PASCAL3Droot '/Annotations'];
ids = textread(sprintf(VOCopts.imgsetpath, 'val'), '%s');
M = numel(ids);

% read detection results
result_dir = 'pascal3d_kmeans_1';
if is_2d
    filename = sprintf('%s/%s_2d_kmeans_%d_test.mat', result_dir, cls, K);
else
    filename = sprintf('%s/%s_3d_kmeans_%d_test.mat', result_dir, cls, K);
end
object = load(filename, 'boxes1');
dets_all = object.boxes1;
fprintf('load detection done\n');

energy = [];
correct = [];
correct_view = [];
overlap = [];
count = zeros(M,1);
num = zeros(M,1);
num_pr = 0;
for i = 1:M
    if is_2d
        fprintf('%s 2d %d train view %d test view %d: %d/%d\n', cls, K, vnum_train, vnum_test, i, M);    
    else
        fprintf('%s 3d %d train view %d test view %d: %d/%d\n', cls, K, vnum_train, vnum_test, i, M);    
    end
    % read ground truth bounding box
    rec = PASreadrecord(sprintf(VOCopts.annopath, ids{i}));
    clsinds = strmatch(cls, {rec.objects(:).class}, 'exact');
    diff = [rec.objects(clsinds).difficult];
    clsinds(diff == 1) = [];
    n = numel(clsinds);
    bbox = zeros(n, 4);
    for j = 1:n
        bbox(j,:) = rec.objects(clsinds(j)).bbox;
    end
    count(i) = size(bbox, 1);
    det = zeros(count(i), 1);
    
    % read ground truth viewpoint
    if isempty(clsinds) == 0
        filename = fullfile(path_ann_view, sprintf('%s_pascal/%s.mat', cls, ids{i}));
        object = load(filename);
        record = object.record;
        view_gt = zeros(n, 1);
        for j = 1:n
            if record.objects(clsinds(j)).viewpoint.distance == 0
                azimuth = record.objects(clsinds(j)).viewpoint.azimuth_coarse;
            else
                azimuth = record.objects(clsinds(j)).viewpoint.azimuth;
            end
            view_gt(j) = find_interval(azimuth, azimuth_interval);
        end
    else
        view_gt = [];
    end
    
    % get predicted bounding box
    dets = dets_all{i};
    
    if isempty(dets) == 0
        I = nms(dets, 0.5);
        dets = dets(I, :);    
    end    
    
    num(i) = size(dets, 1);
    % for each predicted bounding box
    for j = 1:num(i)
        num_pr = num_pr + 1;
        energy(num_pr) = dets(j, 6);        
        bbox_pr = dets(j, 1:4);
        cid = dets(j, 5);
        azimuth = data.azimuth(cid);
        view_pr = find_interval(azimuth, azimuth_interval);
        
        % compute box overlap
        if isempty(bbox) == 0
            o = boxoverlap(bbox, bbox_pr);
            [maxo, index] = max(o);
            if maxo >= 0.5 && det(index) == 0
                overlap{num_pr} = index;
                correct(num_pr) = 1;
                det(index) = 1;
                % check viewpoint
                if view_pr == view_gt(index)
                    correct_view(num_pr) = 1;
                else
                    correct_view(num_pr) = 0;
                end
            else
                overlap{num_pr} = [];
                correct(num_pr) = 0;
                correct_view(num_pr) = 0;
            end
        else
            overlap{num_pr} = [];
            correct(num_pr) = 0;
            correct_view(num_pr) = 0;
        end
    end
end
overlap = overlap';

[threshold, index] = sort(energy, 'descend');
correct = correct(index);
correct_view = correct_view(index);
n = numel(threshold);
recall = zeros(n,1);
precision = zeros(n,1);
accuracy = zeros(n,1);
num_correct = 0;
num_correct_view = 0;
for i = 1:n
    % compute precision
    num_positive = i;
    num_correct = num_correct + correct(i);
    if num_positive ~= 0
        precision(i) = num_correct / num_positive;
    else
        precision(i) = 0;
    end
    
    % compute accuracy
    num_correct_view = num_correct_view + correct_view(i);
    if num_correct ~= 0
        accuracy(i) = num_correct_view / num_positive;
    else
        accuracy(i) = 0;
    end
    
    % compute recall
    recall(i) = num_correct / sum(count);
end


ap = VOCap(recall, precision);
fprintf('AP = %.4f\n', ap);

aa = VOCap(recall, accuracy);
fprintf('AA = %.4f\n', aa);

% draw recall-precision and accuracy curve
% figure;
% hold on;
% plot(recall, precision, 'r', 'LineWidth',3);
% plot(recall, accuracy, 'g', 'LineWidth',3);
% xlabel('Recall');
% ylabel('Precision/Accuracy');
% tit = sprintf('Average Precision = %.1f / Average Accuracy = %.1f', 100*ap, 100*aa);
% title(tit);
% hold off;


function ind = find_interval(azimuth, a)

for i = 1:numel(a)
    if azimuth < a(i)
        break;
    end
end
ind = i - 1;
if azimuth > a(end)
    ind = 1;
end