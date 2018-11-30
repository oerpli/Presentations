function blockreward_XMR()
% function blockreward_XMR()
%
% (Save this file as "blockreward_XMR.m")
%
% -------------------------------------------------------------------------------------
% Monero XMR -  Calculation of the block reward and total money supply for Monero (XMR)
% -------------------------------------------------------------------------------------
%
% This file was tested with FreeMat 4.0 (Matlab clone with GNU License) under Linux Mint 17, in Sept 2016.
%
% FreeMat Bug and workaround/fix:
% -------------------------------
% There is a FreeMat bug with the 64 bit integer type (uint64), which seems to use internally only a double data
% type that is falsely "labeled" uint64 although it only has 52 bit of precision on the mantissa... or something similar
% is done incorrectly about "uint64" in FreeMat.
% But Monero uses a full 64 bit unsigned integer data type for block reward calculation and needs all 64 bits
% in full precision.
% Hence, some extra m-functions were written here to support error-free full uint64 arithmetic for this function!
% This implies introduction of a struct that is able to perform uint64 operations properly at full precision. For this purpose,
% special functions have been written that perform certain 64bit unsigned integer arithmetics on this struct.
% (Note: I could have used a class and methods for this, but I took an "non-object-oriented" approach here, for no particular reason)
%
% Therefore, this function requires the following sub-functions, yielding accurate uint64 calculations:
% - uint64_create         --> creates a struct composed of two 32 bit unsigned integer variables making up the 64 bits for uint64.
% - uint64_plus           --> for uint64 addition of my special data type.
% - uint64_minus          --> for uint64 subtraction of my special data type.
% - uint64_bitshift_right --> for bit-shift to the right, i.e. division by 2^n followed by "floor(...)".
% - uint64_to_double      --> to convert the 64-bit struct to a double data type.
% - uint64_show.m         --> (not needed here but convenient for debugging: Prints the 64-bit struct in decimal and binary format)
%
% Monero Key Parameters:
% ----------------------
% Actual number of atomic units is M = 2^64 - 1 (This is a Monero algorithm constant used in calculation of block rewards)
% The minimum subsidy is 0.3 XMR per minute or 0.6 XMR per 2 minutes.
% Monero uses a recurrence relation: Block reward = (M - A) * 2^-20 * 10^-12 * block_time_in_minutes, i.e.
%                                    Block reward = (M - A) * 2^-20 * 10^-12 --> for 1 minute  block time,
%                                    Block reward = (M - A) * 2^-19 * 10^-12 --> for 2 minutes block time.
%                                    etc.
%     where A = current money supply [in units of "monoshis"]. Roughly 86% mined in 4 years.
%               (1 XMR = 10^12 monoshis)
%
% Due to efficient bit-true processing, I strongly suppose that the "*2^-20" or "*2^-19" operation is
% implemented in the Monero software by bitshifts. Hence, the correct formula would read:
%
%     Block reward = floor((M - A) * 2^-20) * 10^-12 --> for 1 minute  block time.
%     Block reward = floor((M - A) * 2^-19) * 10^-12 --> for 2 minutes block time.
%     etc.
%
% Terminology in this file:
% -------------------------
% - variablename_m = units in monoshis (1 monishi == 10^-12 XMR)
% - variablename_x = units in XMR (1 XMR = 10^12 monoshis)
%
%
%     ---------------------------------------------------------------------------------
% ========> HINT: To get QUICK RESULTS, set block_interval to =1024 instead of =2 <========
%     ---------------------------------------------------------------------------------
%
% --- by r/Amichateur (user at reddit.com) ---
%
% ------------------------------------------------------------------------------------------------------------
% ------------------------------------------------------------------------------------------------------------
 
%% --- PARAMETERS: ---
 
start_time = 2014.2959; % 18 April 2014 = the start date of Monero's blockchain. (usually do not change this)
 
Years = 40; % simulation time, shall be a multiple of 4 to account for leap years
Years =  4; % simulation time, shall be a multiple of 4 to account for leap years
Years = 12; % simulation time, shall be a multiple of 4 to account for leap years
%           % Note: The missing leap years 2100, 2200, 2300, 2500 etc. are ignored - i.e. this file falsely
%           %       assumes that these are leap years.
 
 
%% --- SYSTEM CONSTANTS OF THE MONERO PROTOCOL: ---
 
block_interval = 1024; % in minutes (Monero first used 1 minute, now uses 2 minutes as of Sept 2016)
block_interval = 32; % in minutes (Monero first used 1 minute, now uses 2 minutes as of Sept 2016)
block_interval = 2; % in minutes (Monero first used 1 minute, now uses 2 minutes as of Sept 2016)
%                   % HINT: For speeding up calculation of this simulation, a larger value like 4, 8, 16, 32, 64 or 1024 can be used,
%                   %       yielding only extremely marginally different results that are not visible in the plots!
% ------------------------------------------------------------------------------------------------------------
%         END OF CONFIGURATION AREA - DO NOT CHANGE ANYTHING BELOW THIS LINE
% ------------------------------------------------------------------------------------------------------------
%M_m = uint64(2^64 - 1);% This yields zero - a bug in FreeMat!!! % <--- comment out because of the FreeMat bug with uint64
M_u64_m = uint64_create(2^32-1, 2^32-1);% This is a binary integer number with 64 ones in my own format, code for FreeMat bug.
 
 
%% --- PRE-CALCULATIONS: ---
 
br_min_x = 0.3*block_interval;% minimum block reward in XMR units - the "TAIL EMISSION" (starting some time around the year 2022/2023)
%                             % (0.3 XMR per block for 1 minute block time, or 0.6 XMR for 2 minutes block time)
 
% Additionally, calculate 10^12 * bt_min_x, the minimum block reward (in units of monoshis) in the special
% uint64 format used because of the FreeMat bug:
%
% 0.3 * 10^12 = binary "00000000000000000000000001000101 11011001011001001011100000000000" <--- 1 min block time
%             = decimal                               69                       3647256576
% 0.6 * 10^12 = binary "00000000000000000000000010001011 10110010110010010111000000000000" <--- 2 min block time
%             = decimal                              139                       2999545856
% 1.2 * 10^12 = binary "00000000000000000000000100010111 01100101100100101110000000000000" <--- 4 min block time
%             = decimal                              279                       1704124416
% 2.4 * 10^12 = binary "00000000000000000000001000101110 11001011001001011100000000000000" <--- 8 min block time
%             = decimal                              558                       3408248832
% 4.8 * 10^12 = binary "00000000000000000000010001011101 10010110010010111000000000000000" <--- 16 min block time
%             = decimal                             1117                       2521530368
% 9.6 * 10^12 = binary "00000000000000000000100010111011 00101100100101110000000000000000" <--- 32 min block time
%             = decimal                             2235                        748093440
%19.2 * 10^12 = binary "00000000000000000001000101110110 01011001001011100000000000000000" <--- 64 min block time
%             = decimal                             4470                       1496186880
%307.2* 10^12 = binary "00000000000000010001011101100101 10010010111000000000000000000000" <--- 1024 min block time
%             = decimal                            71525                       2464153600
switch block_interval
    case 1
        br_min_u64_m = uint64_create(   69, 3647256576);% code for FreeMat bug
        twenty = 20;% original exponent value for block reward calculation for original 1 minute interval % code for FreeMat bug
        plot_interval_days = 1;
    case 2
        br_min_u64_m = uint64_create(  139, 2999545856);% code for FreeMat bug
        twenty = 19;% lower negative exponent for higher block reward % code for FreeMat bug
        plot_interval_days = 1;
    case 4
        br_min_u64_m = uint64_create(  279, 1704124416);% code for FreeMat bug
        twenty = 18;% lower negative exponent for higher block reward % code for FreeMat bug
        plot_interval_days = 1;
    case 8
        br_min_u64_m = uint64_create(  558, 3408248832);% code for FreeMat bug
        twenty = 17;% lower negative exponent for higher block reward % code for FreeMat bug
        plot_interval_days = 1;
    case 16
        br_min_u64_m = uint64_create( 1117, 2521530368);% code for FreeMat bug
        twenty = 16;% lower negative exponent for higher block reward % code for FreeMat bug
        plot_interval_days = 1;
    case 32
        br_min_u64_m = uint64_create( 2235,  748093440);% code for FreeMat bug
        twenty = 15;% lower negative exponent for higher block reward % code for FreeMat bug
        plot_interval_days = 1;
    case 64
        br_min_u64_m = uint64_create( 4470, 1496186880);% code for FreeMat bug
        twenty = 14;% lower negative exponent for higher block reward % code for FreeMat bug
        plot_interval_days = 2;% plot more granular - otherwise the plot will not work because of non-integer vector indices
    case 1024
        br_min_u64_m = uint64_create(71525, 2464153600);% code for FreeMat bug
        twenty = 10;% lower negative exponent for higher block reward % code for FreeMat bug
        plot_interval_days = 32;% plot more granular - otherwise the plot will not work because of non-integer vector indices
    otherwise
        error(['The parameter "block_interval" must be =1 or =2, or optionally 4, 8, 16, 32, 64 or 1024. No other values.'])
        return
end% switch
 
 
%% --- CHECK: ---
if Years/4 ~= round(Years/4),
    disp('ERROR: "Years" must be a multiple of 4 in this simulation');
    return
end
 
 
%% --- INIT: ---
block = 0;% initialize the block height (=block count)
first_block_when_BR_gets_capped = inf;% "BR gets capped" refers to the moment when the tail emission is reached.
total_money_supply_when_BR_gets_capped_x = inf;% "BR gets capped" refers to the moment when the tail emission is reached.
simu_block_cnt = Years*365.25*(24*60/block_interval);% nb of blocks to be simulated
 
XMR_tot_m = 0; % total Monero money supply in "monoshis" at a given moment (block height)
XMR_tot_u64_m = uint64_create(0,0); % money supply in monoshis, code for FreeMat bug
 
br_vector_x      = NaN*ones(1,simu_block_cnt);% block reward of each block in XMR, starting with block 1
XMR_tot_vector_x = NaN*ones(1,simu_block_cnt);% total money supply in XMR, starting with block 1
 
%% --- SIMULATION RUN: ---
for y = [1:simu_block_cnt],% loop over the blocks, over one or several 4-year periods
    block = block + 1;% next block (first block is block=1)
    % Calculate block reward ("br") of this block:
    % Convert from atomic units ("monoshis") to XMR by dividing by 10^12:
    % br_m = floor( (M_m - XMR_tot_m) * 2^-20 * block_interval); % <--- comment out because of the FreeMat bug with uint64
    br_u64_m = uint64_bitshift_right(uint64_minus(M_u64_m, XMR_tot_u64_m),twenty);% instead use this code, code for FreeMat bug
    %br_m = uint64_to_double(br_u64_m, 1);% br in monoshi units in double format, code for FreeMat bug - with precision check flag=1
    br_m = uint64_to_double(br_u64_m, 0);% br in monoshi units in double format, code for FreeMat bug
    %                                 % Note: If this conversion to double causes some loss of precision, it does not matter here
    %                                 %       (will only happen for block_interval=1024 in the beginning, where it has no
    %                                 %       effect at all to the end-result).
    br_x = br_m / 10^12;% br in XMR units
    if br_x < br_min_x,
        br_x = br_min_x;
        br_m = br_min_x * 10^12;
        br_u64_m = br_min_u64_m;% code for FreeMat bug
        first_block_when_BR_gets_capped = min(block, first_block_when_BR_gets_capped);
        total_money_supply_when_BR_gets_capped_x = min(XMR_tot_vector_x(block-1), total_money_supply_when_BR_gets_capped_x);
    end
    br_vector_x(block) = br_x;
    XMR_tot_m = XMR_tot_m + br_m;
    XMR_tot_u64_m = uint64_plus(XMR_tot_u64_m, br_u64_m);% code for FreeMat bug
    XMR_tot_vector_x(block) = XMR_tot_m / 10^12;
end
 
% Print in console:
day_per_month = [31,28,31,30,31,30,31,31,30,31,30,31];% leap year not considered. This vector is only used for
%                                                     % informative console output, not critical at all.
first_block_when_BR_gets_capped = first_block_when_BR_gets_capped
first_block_when_BR_gets_capped_normalized_for_1min_blocks = first_block_when_BR_gets_capped * block_interval
total_money_supply_when_BR_gets_capped__in_XMR = total_money_supply_when_BR_gets_capped_x
time_when_BR_gets_capped_in_years_after_inception = (first_block_when_BR_gets_capped / (24*60/block_interval))/365.25
year_when_BR_gets_capped = time_when_BR_gets_capped_in_years_after_inception + start_time
 
[YYYY, MMMM, DDDD, hh, mm] = ymd_of_year(year_when_BR_gets_capped);
 
disp(['Time and Date when block reward gets capped (tail emission starts): ', ...
num2str(YYYY),'-',num2str(MMMM),'-',num2str(DDDD),', ',num2str(hh),':',num2str(mm)]);
 
%month_when_BR_gets_capped =  1+(year_when_BR_gets_capped-floor(year_when_BR_gets_capped))*12
%day_when_BR_gets_capped_rough_approximation = 1+(month_when_BR_gets_capped-floor(month_when_BR_gets_capped))*day_per_month(floor(month_when_BR_gets_capped))
 
%% --- PLOT: ---
x_axis = [0:(simu_block_cnt-1)] / ((24*60/block_interval)*365.25) + start_time; % in increments of block_interval, unit of years
 
% PLOT 1: Total Money Supply:
figure;
% plot with one plot per day:
plot(x_axis(1:plot_interval_days*24*60/block_interval:end), 1e-6*XMR_tot_vector_x(1:plot_interval_days*24*60/block_interval:end), 'b');
title(['Total Monero Money Supply']);
xlabel('Year');
ylabel('XMR in Millions');
% show point of BR cap:
a=axis;
axis([2009 a(2) a(3) a(4)])
if first_block_when_BR_gets_capped < inf,
    hold on;
    plot([year_when_BR_gets_capped year_when_BR_gets_capped], [a(3) a(4)], 'r');
end
grid on
 
% PLOT 2: Block Reward per block, with a block timing as set in this simulation by "block_interval":
figure;% "sleep" helps avoing that sporadically figures are empty
plot(x_axis(1:plot_interval_days*24*60/block_interval:end), br_vector_x(1:plot_interval_days*24*60/block_interval:end), 'g');
title(['Monero Block Reward'])
xlabel('Year');
ylabel('XMR');
% show point of BR cap:
a=axis;
axis([2009 a(2) a(3) a(4)])
if first_block_when_BR_gets_capped < inf,
    hold on;
    plot([year_when_BR_gets_capped year_when_BR_gets_capped], [a(3) a(4)], 'r');
end
grid on
 
% PLOT 2b: Block Reward per 10 minutes (to be able to compare with Bitcoin):
figure;% "sleep" helps avoing that sporadically figures are empty
plot(x_axis(1:plot_interval_days*24*60/block_interval:end), 10/block_interval*br_vector_x(1:plot_interval_days*24*60/block_interval:end), 'g');
title(['Monero Block Reward - Normalized Per 10 Minutes'])
xlabel('Year');
ylabel('XMR');
% show point of BR cap:
a=axis;
axis([2009 a(2) a(3) a(4)])
if first_block_when_BR_gets_capped < inf,
    hold on;
    plot([year_when_BR_gets_capped year_when_BR_gets_capped], [a(3) a(4)], 'r');
end
grid on
 
save workspace_xmr.mat % Activate this for DEBUGGING or for later use e.g. for plotting mixed BTC / XMR diagrams
return
 
 
% ============================================================================================================
% ============================================================================================================
function y = uint64_create(high, low)
% y is of type struct of two uint32 with names .h and .l for the upper / lower 32 bits
% low  is an integer or double representing the lower  32 bit of y
% high is an integer or double representing the higher 32 bit of y
% ------------------------------------------------------------------------------------------------------------
y.h = uint32(high);
y.l = uint32(low);
return
 
% ============================================================================================================
function y = uint64_plus(x1, x2)
% Calculate y = x1 + x2
% y, x1 and x2 are of type struct of two uint32 with names .h and .l for the upper / lower 32 bits
% ------------------------------------------------------------------------------------------------------------
tmp_h = double(x1.h) + double(x2.h);
tmp_l = double(x1.l) + double(x2.l);
if tmp_l <= 2^32-1, % no overflow from the lower part
    y.h = uint32(tmp_h);% automatically saturates at 2^32-1
    if tmp_h <= 2^32-1, % upper part does NOT saturate
        y.l = uint32(tmp_l);
    else% if upper part saturates
        y.l = uint32(2^32-1); % lower part shall also saturate
    end
    return;
else
    y.h = uint32(tmp_h + 1);% automatically saturates at 2^32-1
    if tmp_h + 1 <= 2^32-1, % upper part does NOT saturate
        y.l = uint32(tmp_l - 2^32);
    else% if upper part saturates
        y.l = uint32(2^32-1); % lower part shall also saturate
    end
    return;
end
disp(['ERROR in ',mfilename(),': The code should never arrive here!'])
return
 
% ============================================================================================================
function y = uint64_minus(x2, x1)
% Calculate y = x2 - x1
% y, x1 and x2 are of type struct of two uint32 with names .h and .l for the upper / lower 32 bits
% ------------------------------------------------------------------------------------------------------------
% if x1 >= x2 then result is zero:
if (x1.h > x2.h) || (x1.h == x2.h && x1.l >= x2.l),
    y.h = uint32(0);
    y.l = uint32(0);
    return;
end
% Case of x2 > x1:
y.h = x2.h - x1.h;
if x1.l > x2.l, % && y.h > 0,
    y.h = y.h - 1;
    y.l = uint32(2^32 + double(x2.l) - double(x1.l));
    return;
else % x2.l - x1.l >=0 and y.h >=0:
    y.l = x2.l - x1.l;
    return;
end
disp(['ERROR in ',mfilename(),': The code should never arrive here!'])
return
 
% ============================================================================================================
function y = uint64_bitshift_right(x, shift)
% Calculate y = x / 2^shift
% y and x are of type struct of two uint32 with names .h and .l for the upper / lower 32 bits
% shift is an integer number
% ------------------------------------------------------------------------------------------------------------
y.h = uint32( floor(double(x.h) / 2^shift) );
tmp = x.h - y.h * 2^shift; % this is the remainder, cannot be more than "shift" bits, i.e. max. 2^shift-1
y.l = uint32( floor(double(x.l) / 2^shift) ) + tmp * 2^(32-shift);
return
 
% ============================================================================================================
function y = uint64_to_double(x, check_flag)
% Convert x to double format
% x is of type struct of two uint32 with names .h and .l for the upper / lower 32 bits
% check_flag : if present and not =0, then function will check for lossless conversion and output a warning if applicable
% ------------------------------------------------------------------------------------------------------------
y = double(x.h)*2^32 + double(x.l);
persistent count
if (~exist('check_flag')),
    check_flag=0;
end
if (check_flag) && (x.h > 2^20-1), % Check if this conversion implies a loss in precision, assuming that double has 52 bits of mantissa
    if (isempty(count)), count = 0;
    end;
    count = count + 1;
    disp(['WARNING #',num2str(count),': The conversion to double may cause loss in precision due to droping of LSBs!'])
end
return
 
% ============================================================================================================
function uint64_show(x)
% Prints x on the console, in binary and decimal format.
% x is of type struct of two uint32 with names .h and .l for the upper / lower 32 bits
% ------------------------------------------------------------------------------------------------------------
result_h='xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
result_l='xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
tmp_h = double(x.h);
tmp_l = double(x.l);
for k = [32:-1:1],
    if abs(tmp_h - 2*floor(tmp_h/2)) < 0.0001,
        result_h(k) = '0';
    else
        result_h(k) = '1';
    end
    tmp_h = floor(tmp_h / 2);
 
    if abs(tmp_l - 2*floor(tmp_l/2)) < 0.0001,
        result_l(k) = '0';
    else
        result_l(k) = '1';
    end
    tmp_l = floor(tmp_l / 2);
end
 
if double(x.h) <= 2^31-1,
    string_h = num2str(x.h);
else
    string_h = num2str(double(x.h));
end
if double(x.l) <= 2^31-1,
    string_l = num2str(x.l);
else
    string_l = num2str(double(x.l));
end
disp(['uint64 Number = 2^32 * ',string_h,' + ',string_l]);
disp(['Binary        = ',result_h,' ',result_l]);
disp(['Decimal       = ',num2str(2^32*double(x.h)+double(x.l))]);
return
 
% ============================================================================================================
 
function [y, m, d, h, minute] = ymd_of_year(x)
% x is a year in fraction representation, e.g. 2014.43805
%
% y, m, d, h, minute : are year, month, day_of_month, hour (0..23) and minute (0.0000..59.9999) of that year "x".
% y, m, d, h         : are integer.
% minute             : is fractional.
%
% Note: Years 2100, 2200, 2300, 2500 etc. are treated as leap years, although they aren't.
y = floor(x);
 
if abs( y/4 - floor(y/4) ) < 0.0001,
    feb=29;
    days_pa=366;
else
    feb=28;
    days_pa=365;
end
NbDays = [31,feb,31,30,31,30,31,31,30,31,30,31];
NbDaysAccu = [0,0,0,0,0,0,0,0,0,0,0,0];% init
Month{1}  = 'Jan'; NbDaysAccu(1) = NbDays(1);
Month{2}  = 'Feb'; NbDaysAccu(2) = NbDaysAccu(1)+NbDays(2);
Month{3}  = 'Mar'; NbDaysAccu(3) = NbDaysAccu(2)+NbDays(3);
Month{4}  = 'Apr'; NbDaysAccu(4) = NbDaysAccu(3)+NbDays(4);
Month{5}  = 'May'; NbDaysAccu(5) = NbDaysAccu(4)+NbDays(5);
Month{6}  = 'Jun'; NbDaysAccu(6) = NbDaysAccu(5)+NbDays(6);
Month{7}  = 'Jul'; NbDaysAccu(7) = NbDaysAccu(6)+NbDays(7);
Month{8}  = 'Aug'; NbDaysAccu(8) = NbDaysAccu(7)+NbDays(8);
Month{9}  = 'Sep'; NbDaysAccu(9) = NbDaysAccu(8)+NbDays(9);
Month{10} = 'Oct'; NbDaysAccu(10) = NbDaysAccu(9)+NbDays(10);
Month{11} = 'Nov'; NbDaysAccu(11) = NbDaysAccu(10)+NbDays(11);
Month{12} = 'Dez'; NbDaysAccu(12) = NbDaysAccu(11)+NbDays(12);
 
scaled_day = (x-floor(x))*days_pa; % from 0.0000 to 364..9999 (or 365.9999)
m = min(find(scaled_day<NbDaysAccu));
d_fract = NbDays(m) - (NbDaysAccu(m) - scaled_day) + 1;
d = floor(d_fract);
h_fract = (d_fract-floor(d_fract))*24;
h = floor(h_fract);
minute = (h_fract-floor(h_fract))*60;