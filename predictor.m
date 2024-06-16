clear;
clc;

%% PARAMETERS AND DATA
% Predictor Parameters/////////////////////////////////////////////////////
xG_type = "normal"; % Decision on xG type: "normal" or "no penalty"
w_xG = 0.35; % Weight of the expected goal statistics (xG and xGA)
w_rG = 0.35; % Weight of the real goal statistics (AG and YG)
w_rival = 0.3; % Weight of the rival statistics (rival xG and rival xGA)

w_opta = 0.3; % Weight of Opta's winning probabilities on Euro 2024 team ratings

w_luck = 0.1; % Weight of luck for simulator
w_rat = (1 - w_luck) / 2; % Weight of each offensive and defensive rating for simulator
% /////////////////////////////////////////////////////////////////////////

% Reading Data/////////////////////////////////////////////////////////////
raw_data1 = readmatrix("STATS.csv");
data = raw_data1(~isnan(raw_data1));
data_reshaped = reshape(data, [53, 11]);
stat_matrix = data_reshaped(:, 2 : end - 1);

raw_data2 = readmatrix("STATS.csv", "Range", "C:C", "OutputType", "string");
qual_team_array = raw_data2([3 : 7, 9 : 13, 15 : 19, 21 : 25, 27 : 31, 33 : 37, ...
    39 : 43, 45 : 50, 52 : 57, 59 : 64]);

raw_data3 = readmatrix("EURO24.csv");
opta_data = raw_data3(~isnan(raw_data3));

raw_data4 = readmatrix("EURO24.csv", "Range", "B:B", "OutputType", "string");
euro24_team_array = raw_data4([2 : 5, 7 : 10, 12 : 15, 17 : 20, 22 : 25, 27 : 30]);
% /////////////////////////////////////////////////////////////////////////

% Data Preprocessing///////////////////////////////////////////////////////
% Mapping Statistics into [0, 100] Range===================================
num_game_array = stat_matrix(:, 1);
mapped_stat_matrix = zeros(size(stat_matrix, 1), size(stat_matrix, 2) - 1);
for stat_index = 2 : size(stat_matrix, 2)
    stat_array = stat_matrix(:, stat_index);

    % Calculating Per-Game Statistics~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if stat_index == 5 || stat_index == 8 || stat_index == 9 % Cumulative rival statistics
        stat_array(1 : 35) = stat_array(1 : 35) / 32; % Groups with 5 teams
        stat_array(36 : end) = stat_array(36 : end) / 50; % Groups with 6 teams
    else
        stat_array = stat_array ./ num_game_array;
    end
    % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    stat_min = min(stat_array);
    stat_max = max(stat_array);
    mapped_stat_array = interp1([stat_min, stat_max], [0, 100], stat_array);
    mapped_stat_matrix(:, stat_index - 1) = mapped_stat_array;
end
% =========================================================================

% Calculating Offensive & Defensive Ratings================================
off_rat_array = zeros(length(qual_team_array), 1);
def_rat_array = zeros(length(qual_team_array), 1);
for team_index = 1 : length(qual_team_array)
    % Offensive Rating Parameters~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    xG = mapped_stat_matrix(team_index, 1);
    xG_no_penalty = mapped_stat_matrix(team_index, 2);
    AG = mapped_stat_matrix(team_index, 3);
    rival_xGA = mapped_stat_matrix(team_index, 4);
    % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    % Defensive Rating Parameters~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    xGA = mapped_stat_matrix(team_index, 5);
    YG = mapped_stat_matrix(team_index, 6);
    rival_xG = mapped_stat_matrix(team_index, 7);
    rival_xG_no_penalty = mapped_stat_matrix(team_index, 8);
    % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    switch xG_type
        case "normal"
            s_xG = w_xG * xG;
            s_rival_xG = w_xG * rival_xG;
        case "no penalty"
            s_xG = w_xG * xG_no_penalty;
            s_rival_xG = w_xG * rival_xG_no_penalty;
    end
    s_off_tot = s_xG + w_rG * AG - w_rival * rival_xGA;
    off_rat_array(team_index) = s_off_tot;

    s_def_tot = s_rival_xG - w_xG * xGA - w_rG * YG;
    def_rat_array(team_index) = s_def_tot;
end
% =========================================================================

% Mapping Offensive & Defensive Ratings====================================
min_off_rat = min(off_rat_array);
max_off_rat = max(off_rat_array);
mapped_off_rat_array = interp1([min_off_rat, max_off_rat], [0, 100], off_rat_array);

min_def_rat = min(def_rat_array);
max_def_rat = max(def_rat_array);
mapped_def_rat_array = interp1([min_def_rat, max_def_rat], [0, 100], def_rat_array);
% =========================================================================

% Germany Offensive & Defensive Ratings====================================
min_win_prop = min(opta_data);
max_win_prop = max(opta_data);
mapped_opta_data = interp1([min_win_prop, max_win_prop], [0, 100], opta_data);

germany_rat = mapped_opta_data(euro24_team_array == "ALMANYA");

qual_team_array = ["ALMANYA"; qual_team_array];
mapped_off_rat_array = [germany_rat; mapped_off_rat_array];
mapped_def_rat_array = [germany_rat; mapped_def_rat_array];
% =========================================================================

% EURO 2024 Team Statistics================================================
[~, euro24_team_index_array] = ismember(euro24_team_array, qual_team_array);
euro24_off_rat_array = mapped_off_rat_array(euro24_team_index_array);
euro24_def_rat_array = mapped_def_rat_array(euro24_team_index_array);

euro24_off_rat_array = (1 - w_opta) * euro24_off_rat_array + w_opta * mapped_opta_data;
euro24_def_rat_array = (1 - w_opta) * euro24_def_rat_array + w_opta * mapped_opta_data;

euro24_avg_rat_array = 0.5 * euro24_off_rat_array + 0.5 * euro24_def_rat_array;
euro24_avg_rat_matrix = [(1 : length(euro24_team_array))', euro24_avg_rat_array];
euro24_avg_rat_matrix_sorted = sortrows(euro24_avg_rat_matrix, 2, "descend");
euro24_final_predictions = euro24_team_array(euro24_avg_rat_matrix_sorted(:, 1));
% =========================================================================

% Edge Values for Rating-to-Goal Mappings==================================
[O, D] = meshgrid(euro24_off_rat_array, euro24_def_rat_array);
diff_off_def_matrix = w_rat * (O - D) + randi([0, w_luck * 100], size(O));
diff_off_def_array = diff_off_def_matrix(:);

% Monte Carlo Simulation for Probability Calculation~~~~~~~~~~~~~~~~~~~~~~~
lower_bound = 21.4;
upper_bound = 1e5;

% num_iterations = 1e5;
% prob_sum = 0;
% for iter_index = 1 : num_iterations
%     diff_off_def_matrix = w_rat * (O - D) + randi([0, w_luck * 100], size(O));
%     diff_off_def_array = diff_off_def_matrix(:);
%     interval = find(diff_off_def_array > lower_bound & diff_off_def_array <= upper_bound);
%     prob = 100 * length(interval) / length(diff_off_def_array);
%     prob_sum = prob_sum + prob;
% end
% avg_prob = prob_sum / num_iterations;
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

% P0 = %24.95, P1 = %30.87, P2 = %27.02, P3 = %10.07, P4 = %5, P5 = %2.08;
edge_goal_array = [-8.77, -1.45, 7.8, 15.5, 21.4];
% =========================================================================
% /////////////////////////////////////////////////////////////////////////

%% EURO 2024 SIMULATOR
% Simulation Parameters////////////////////////////////////////////////////
euro24_group_matrix = reshape(euro24_team_array, [4, 6]);
params.euro24_team_array = euro24_team_array;
params.euro24_off_rat_array = euro24_off_rat_array;
params.euro24_def_rat_array = euro24_def_rat_array;
params.w_rat = w_rat;
params.w_luck = w_luck;
params.edge_goal_array = edge_goal_array;
% /////////////////////////////////////////////////////////////////////////

% Group Stage//////////////////////////////////////////////////////////////
group_names = ["A", "B", "C", "D", "E", "F"];
for group_index = 1 : 6
    group_name = group_names(group_index);
    teams = euro24_group_matrix(:, group_index);

    stats = zeros(4, 2);
    games = strings(6, 4);
    for match_day = 1 : 3
        game1_team_index_array = [1, match_day + 1];
        game1_team_array = teams(game1_team_index_array);
        [game1_team1_goal, game1_team2_goal] = GAME(game1_team_array(1), game1_team_array(2), params);
        stats = GroupUpdate(stats, game1_team_index_array, game1_team1_goal, game1_team2_goal);
        games(2 * match_day - 1, :) = ...
            [game1_team_array(1), game1_team1_goal, game1_team2_goal, game1_team_array(2)];
    
        game2_team_index_array = setdiff(1 : 4, game1_team_index_array);
        game2_team_array = teams(game2_team_index_array);
        [game2_team1_goal, game2_team2_goal] = GAME(game2_team_array(1), game2_team_array(2), params);
        stats = GroupUpdate(stats, game2_team_index_array, game2_team1_goal, game2_team2_goal);
        games(2 * match_day, :) = ...
            [game2_team_array(1), game2_team1_goal, game2_team2_goal, game2_team_array(2)];
    end
    final = [teams stats];
    final = sortrows(final, 2, "descend");
    EURO2024.(group_name).final = final;
    EURO2024.(group_name).games = games;
end
% /////////////////////////////////////////////////////////////////////////

% Knockout Stage///////////////////////////////////////////////////////////
% Round-16=================================================================
R16_games = strings(8, 4);

B1 = EURO2024.B.final(1, 1);
E3 = EURO2024.E.final(3, 1);
[B1_goal, E3_goal] = GAME(B1, E3, params);
R16_games(1, :) = [B1, B1_goal, E3_goal, E3];

A1 = EURO2024.A.final(1, 1);
C2 = EURO2024.C.final(2, 1);
[A1_goal, C2_goal] = GAME(A1, C2, params);
R16_games(2, :) = [A1, A1_goal, C2_goal, C2];

F1 = EURO2024.F.final(1, 1);
A3 = EURO2024.A.final(3, 1);
[F1_goal, A3_goal] = GAME(F1, A3, params);
R16_games(3, :) = [F1, F1_goal, A3_goal, A3];

D2 = EURO2024.D.final(2, 1);
E2 = EURO2024.E.final(2, 1);
[D2_goal, E2_goal] = GAME(D2, E2, params);
R16_games(4, :) = [D2, D2_goal, E2_goal, E2];

E1 = EURO2024.E.final(1, 1);
D3 = EURO2024.D.final(3, 1);
[E1_goal, D3_goal] = GAME(E1, D3, params);
R16_games(5, :) = [E1, E1_goal, D3_goal, D3];

D1 = EURO2024.D.final(1, 1);
F2 = EURO2024.F.final(2, 1);
[D1_goal, F2_goal] = GAME(D1, F2, params);
R16_games(6, :) = [D1, D1_goal, F2_goal, F2];

C1 = EURO2024.C.final(1, 1);
F3 = EURO2024.F.final(3, 1);
[C1_goal, F3_goal] = GAME(C1, F3, params);
R16_games(7, :) = [C1, C1_goal, F3_goal, F3];

A2 = EURO2024.A.final(2, 1);
B2 = EURO2024.B.final(2, 1);
[A2_goal, B2_goal] = GAME(A2, B2, params);
R16_games(8, :) = [A2, A2_goal, B2_goal, B2];

EURO2024.R16.games = R16_games;
% =========================================================================

% Quarter Final============================================================
QF_games = strings(4, 4);

B1 = EURO2024.B.final(1, 1);
A1 = EURO2024.A.final(1, 1);
[B1_goal, A1_goal] = GAME(B1, A1, params);
QF_games(1, :) = [B1, B1_goal, A1_goal, A1];

F1 = EURO2024.F.final(1, 1);
D2 = EURO2024.D.final(2, 1);
[F1_goal, D2_goal] = GAME(F1, D2, params);
QF_games(2, :) = [F1, F1_goal, D2_goal, D2];

E1 = EURO2024.E.final(1, 1);
D1 = EURO2024.D.final(1, 1);
[E1_goal, D1_goal] = GAME(E1, D1, params);
QF_games(3, :) = [E1, E1_goal, D1_goal, D1];

C1 = EURO2024.C.final(1, 1);
B2 = EURO2024.B.final(2, 1);
[C1_goal, B2_goal] = GAME(C1, B2, params);
QF_games(4, :) = [C1, C1_goal, B2_goal, B2];

EURO2024.QF.games = QF_games;
% =========================================================================

% Semi Final===============================================================
SF_games = strings(2, 4);

A1 = EURO2024.A.final(1, 1);
F1 = EURO2024.F.final(1, 1);
[A1_goal, F1_goal] = GAME(A1, F1, params);
SF_games(1, :) = [A1, A1_goal, F1_goal, F1];

D1 = EURO2024.D.final(1, 1);
C1 = EURO2024.C.final(1, 1);
[D1_goal, C1_goal] = GAME(D1, C1, params);
SF_games(2, :) = [D1, D1_goal, C1_goal, C1];

EURO2024.SF.games = SF_games;
% =========================================================================

% Final====================================================================
F1 = EURO2024.F.final(1, 1);
C1 = EURO2024.C.final(1, 1);
[F1_goal, C1_goal] = GAME(F1, C1, params);
FINAL = [F1, F1_goal, C1_goal, C1];

EURO2024.FINAL = FINAL;
% =========================================================================
% /////////////////////////////////////////////////////////////////////////

%% INNER FUNCTIONS (TOTAL OF 2)
% =========================================================================
% 1.
% =========================================================================
function [team1_goal, team2_goal] = GAME(team1, team2, params)
    euro24_team_array = params.euro24_team_array;
    euro24_off_rat_array = params.euro24_off_rat_array;
    euro24_def_rat_array = params.euro24_def_rat_array;
    w_rat = params.w_rat;
    w_luck = params.w_luck;
    edge_goal_array = params.edge_goal_array;

    team1_off_rat = euro24_off_rat_array(euro24_team_array == team1);
    team1_def_rat = euro24_def_rat_array(euro24_team_array == team1);
    team2_off_rat = euro24_off_rat_array(euro24_team_array == team2);
    team2_def_rat = euro24_def_rat_array(euro24_team_array == team2);

    team1_goal = w_rat * (team1_off_rat - team2_def_rat) + randi([0, w_luck * 100], [1, 1]);
    if team1_goal <= edge_goal_array(1)
        team1_goal = 0;
    elseif team1_goal <= edge_goal_array(2)
        team1_goal = 1;
    elseif team1_goal <= edge_goal_array(3)
        team1_goal = 2;
    elseif team1_goal <= edge_goal_array(4)
        team1_goal = 3;
    elseif team1_goal <= edge_goal_array(5)
        team1_goal = 4;
    else
        team1_goal = 5;
    end

    team2_goal = w_rat * (team2_off_rat - team1_def_rat) + randi([0, w_luck * 100], [1, 1]);
    if team2_goal <= edge_goal_array(1)
        team2_goal = 0;
    elseif team2_goal <= edge_goal_array(2)
        team2_goal = 1;
    elseif team2_goal <= edge_goal_array(3)
        team2_goal = 2;
    elseif team2_goal <= edge_goal_array(4)
        team2_goal = 3;
    elseif team2_goal <= edge_goal_array(5)
        team2_goal = 4;
    else
        team2_goal = 5;
    end
end
% =========================================================================


% =========================================================================
% 2.
% =========================================================================
function Group = GroupUpdate(Group, game_team_index_array, team1_goal, team2_goal)
    Group(game_team_index_array(1), 2) = Group(game_team_index_array(1), 2) + team1_goal - team2_goal;
    Group(game_team_index_array(2), 2) = Group(game_team_index_array(2), 2) + team2_goal - team1_goal;
    if team1_goal == team2_goal
        Group(game_team_index_array(1), 1) = Group(game_team_index_array(1), 1) + 1;
        Group(game_team_index_array(2), 1) = Group(game_team_index_array(2), 1) + 1;
    elseif team1_goal > team2_goal
        Group(game_team_index_array(1), 1) = Group(game_team_index_array(1), 1) + 3;
    else
        Group(game_team_index_array(2), 1) = Group(game_team_index_array(2), 1) + 3;
    end
end
% =========================================================================
