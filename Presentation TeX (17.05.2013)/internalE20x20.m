function mD = internalE20x20(Y,X)
path = 'I:\BSc-Logs\20x20\';
mode = {'*m.txt' '*sw.txt'};

for m=Y:X
%     figure
    liste = dir([path mode{m}]);
    files = {liste.name}'
    for k=3:numel(files)
        mD(:,:,k) = FILE(fullfile(path,files{k}));
%         mD(k,:) = mean(D);
%         mD2(k,:) = mean(D.^2);
    end
%     x = [0.5:0.5:4.5];
%     plot(x,mD+100*k);hold on;
end
end

function D = FILE(x)
[t,e,m] = textread(x,'%u %f %f','commentstyle','shell');
D = [e,m];
end