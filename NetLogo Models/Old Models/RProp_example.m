%% Let's start with a network
% I want my network to mimic the real one, so let's do something simple, 3
% inputs, 2 outputs, the goal is to pick one and then the other
% alternating.

I = [0 0 0];
T = [0 0
    0 0
    0 0];
O = [0 0];

cur_reward = true; % Flips from -1 to 1 randomly
R_value = 1; % Reward

%% Let's do our game loop

for tick = 1:300
    % Flip the reward position (maybe)
    if randi(100) < 5
        cur_reward = ~cur_reward;
    end
end


%%%%%%
