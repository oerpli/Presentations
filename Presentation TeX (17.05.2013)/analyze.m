function D = analyze()
% [a,b,c] = textread(file,'%u %d %d','commentstyle','shell');
%[a,b,c] = textread(file,'%u %d.0 %d.0','commentstyle','shell');
i = 1;
D(:,i:i+1) = read('100-1.0_sw.txt');
i = i+2;
D(:,i:i+1)= read('100-2.0_sw.txt');
i = i+2;
D(:,i:i+1) = read('100-2.2_sw.txt');
i = i+2;
D(:,i:i+1)= read('100-2.3_sw.txt');
i = i+2;
D(:,i:i+1) = read('100-2.4_sw.txt');
i = i+2;
end

function D = read(file)
[b,c] = textread(file,'%f %f','commentstyle','shell');
D = [b,c];
end
