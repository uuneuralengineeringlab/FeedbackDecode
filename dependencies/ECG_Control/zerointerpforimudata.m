tnhh = [133289008 135100672];
tnhv = [135960000 138254784];
tnou = [139464544 141655408];

dyhh = [179537312 181257936];
dyhv = [182804288 184529824];
dyou = [185510944 187351328];
dnhh = [190542032 192346800];
dnhv = [193226912 195050464];
dnou = [204872128 206687760];
%% taska
[~, idx1] = min(abs(data(1,:) - tnhh(1)));
[~, idx2] = min(abs(data(1,:) - tnhh(2)));

tnhhdata = data(:,idx1:idx2);

[~, idx1] = min(abs(data(1,:) - tnhv(1)));
[~, idx2] = min(abs(data(1,:) - tnhv(2)));

tnhvdata = data(:,idx1:idx2);

[~, idx1] = min(abs(data(1,:) - tnou(1)));
[~, idx2] = min(abs(data(1,:) - tnou(2)));

tnoudata = data(:,idx1:idx2);

%% deka
[~, idx1] = min(abs(data(1,:) - dnhh(1)));
[~, idx2] = min(abs(data(1,:) - dnhh(2)));

dnhhdata = data(:,idx1:idx2);

[~, idx1] = min(abs(data(1,:) - dnhv(1)));
[~, idx2] = min(abs(data(1,:) - dnhv(2)));

dnhvdata = data(:,idx1:idx2);

[~, idx1] = min(abs(data(1,:) - dnou(1)));
[~, idx2] = min(abs(data(1,:) - dnou(2)));

dnoudata = data(:,idx1:idx2);

[~, idx1] = min(abs(data(1,:) - dyhh(1)));
[~, idx2] = min(abs(data(1,:) - dyhh(2)));

dyhhdata = data(:,idx1:idx2);

[~, idx1] = min(abs(data(1,:) - dyhv(1)));
[~, idx2] = min(abs(data(1,:) - dyhv(2)));

dyhvdata = data(:,idx1:idx2);

[~, idx1] = min(abs(data(1,:) - dyou(1)));
[~, idx2] = min(abs(data(1,:) - dyou(2)));

dyoudata = data(:,idx1:idx2);


%% interpolate to fill in zeros (should address data acq in fbd to reduce this)
testdata = tnhhdata(:,1:20);
fixeddata = testdata;
for row = 2:31
    idx = find(testdata(row,:) == 0);
    a=diff(idx);  % get the differences of indices
    
    
    b=find([a inf]>1);
    c=diff([0 b]);  % length of the sequences
    if length(c) >1
        d=cumsum(c);  % endpoints of the sequences
        for dd=1:length(d)
            if d(dd) - c(dd) ~= 1 || d(dd) == length(testdata)
                fixeddata(row, d(dd) - c(dd) - 1:d(dd) + 1) = linspace(testdata(row, d(dd) - c(dd) - 1),testdata(row, d(dd) + 1), c(dd) + 2);
            end
        end
    else
        if idx ~= 1 || idx ~= length(testdata)
            fixeddata(row, idx-1:idx+1) = linspace(testdata(row, idx-1),testdata(row, idx+1), 3);
        end
    end
end

% A = [0 0 1 1 1 0 0 0 1 1 1] ;
% idx = find(A==0) ;  % get the indices of 0
% a=diff(idx);  % get the differences of indices
% b=find([a inf]>1);
% c=diff([0 b]);  % length of the sequences
% d=cumsum(c); %  endpoints of the sequences
% % Run loop to extract zeros into iwant
% iwant = cell(length(d),1) ;
% iwant{1} = A(1:idx(d(1))) ;
% for i = 2:length(d)
%     iwant{i} = A(idx(d(i-1)+1:d(i))) ;
% end