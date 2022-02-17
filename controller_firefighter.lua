local CSV = require 'csv_helper'
local Q_learning = require 'q_approximation'

local BIAS = 1.0
-- learning rate
local ALPHA = 0.3 -- next 0.6
-- discount factor
local GAMMA = 0.9
-- bootstrapping factor
local LAMBDA = 0.8
-- epsilon value for greedy action selection
local EPSILON = 0.1

local REWARD = 2
local PENALTY = -3

local MAX_VELOCITY = 10

local FILENAME = 'weights.csv'
local ANALYSIS_FILENAME = "analysis.csv"


local action = 1
local goal = false

local starting_position=robot.positioning.position
local survivor_position = { x = -1.8, y = 0.4 }
local previous_distance=0

local feature_activations = { 0, 0, 0, 0, 0, 0, 0}
local feature_activation_step = { 0, 0, 0, 0, 0, 0, 0}

local consecutive_reward_steps = 0
local consecutive_penalty_steps = 0

-----------------
--	ACTION SPACE
-----------------
local turn_slightly_right = 30
local turn_slightly_left = -30
local turn_right = 60
local turn_left = -60
local turn_a_lot_right = 90
local turn_a_lot_left = -90
local go_forward = 0 

local actions = {
	go_forward,
	turn_left,
	turn_right,
	turn_slightly_left,
	turn_slightly_right,
	turn_a_lot_left,
	turn_a_lot_right
}

----------------
--	STATE SPACE
----------------
local nearest_robot_message = function()
	local previous_message = { }
	for i=1, #robot.range_and_bearing do
		local message = robot.range_and_bearing[i]
		if message.range < (previous_message.range or math.huge) then
			previous_message = message
		end
	end
	return previous_message
end

function signal_detection_15()
	local message = nearest_robot_message()
	
	if not next(message) then
		return 0
	end

	local transmiter_angle = message.horizontal_bearing
	local result = 0 <= transmiter_angle and transmiter_angle <= math.pi/12
	
	if result then
		feature_activation_step[1] = 1
		feature_activations[1] = feature_activations[1] + 1
	end
	
	return result and 1 or 0
end

function signal_detection_30()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	local result = math.pi/12 <= transmiter_angle and transmiter_angle <= math.pi/6
	
	if result then
		feature_activation_step[2] = 1
		feature_activations[2] = feature_activations[2] + 1
	end
	
	return result and 1 or 0
end

function signal_detection_45()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	local result = math.pi/6 <= transmiter_angle and transmiter_angle <= math.pi/4
	
	if result then
		feature_activation_step[3] = 1
		feature_activations[3] = feature_activations[3] + 1
	end
	
	return result and 1 or 0
end

function signal_detection_60()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	local result = math.pi/4 < transmiter_angle and transmiter_angle < math.pi/3

	if result then
		feature_activation_step[4] = 1
		feature_activations[4] = feature_activations[4] + 1
	end

	return result and 1 or 0
end

function signal_detection_75()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	local result = math.pi/3 < transmiter_angle and transmiter_angle < 5/12*math.pi

	if result then
		feature_activation_step[5] = 1
		feature_activations[5] = feature_activations[5] + 1
	end

	return result and 1 or 0
end

function signal_detection_90()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	local result = 5/12*math.pi < transmiter_angle and transmiter_angle < math.pi/2

	if result then
		feature_activation_step[6] = 1
		feature_activations[6] = feature_activations[6] + 1
	end

	return result and 1 or 0
end

local state_features = {
	signal_detection_15,
	signal_detection_30,
	signal_detection_45,
	signal_detection_60,
	signal_detection_75,
	signal_detection_90,
	function()
		feature_activation_step[7] = BIAS
		feature_activations[7] = feature_activations[7] + 1
		return BIAS
	end
}


--------------------
-- REWARD DEFINITION
--------------------
local euclidean_distance = function(position1, position2)
	return math.sqrt(math.pow(position1.x - position2.x, 2) + math.pow(position1.y - position2.y, 2))
end

local reward = function()
	local robot_position = nearest_robot_message()
	local current_distance = robot_position.range
	local reward = 0
	
	if next(robot_position) and previous_distance ~= nil then
		local is_closer = current_distance < previous_distance
		local direction = robot_position.horizontal_bearing
		local in_survivor_direction = -math.pi/18 <= direction and direction <= math.pi/18
		
		if in_survivor_direction and is_closer then
			direction_reward = 100
			position_reward = 100
		else
			direction_reward = -100
			position_reward = (current_distance > previous_distance) and -100 or 0
		end
		
		reward=position_reward+direction_reward
	end
	previous_distance = current_distance
	
	return reward
end


local take = function(action_index)
	function limit_v(left_v, right_v)
		function limit(value)
			if (value > MAX_VELOCITY) then
				value = MAX_VELOCITY
			end

			if (value < - MAX_VELOCITY) then
				value = - MAX_VELOCITY
			end
			return value
		end
		return limit(left_v), limit(right_v)
	end
  
  local angle = actions[action_index]
  local wheels_distance = robot.wheels.axis_length
  local left_v = MAX_VELOCITY - (angle * wheels_distance / 2)
  local right_v = MAX_VELOCITY + (angle * wheels_distance / 2)
  
  left_v, right_v = limit_v(left_v, right_v)
  robot.wheels.set_velocity(left_v,right_v)
end

function printable_vector(vector)
	local stringify = "[ "
	for i=1, #vector do
		stringify = stringify .. vector[i] .. " "
	end
	return stringify .. "]"
end


function init()
	done_steps = 0
	previous_distance=nearest_robot_message().range
	
	local weights = CSV.load(FILENAME)
	local state_action_space = { actions = #actions, state_features = state_features }
	local hyperparameters = { alpha = ALPHA, gamma = GAMMA, lambda = LAMBDA, epsilon = EPSILON }
	
	CSV.create_csv(ANALYSIS_FILENAME, { "step", "reward" })
	CSV.create_csv("features_activation.csv", { "step", "features", "action" })
	
	Q_learning.config(state_action_space, weights, hyperparameters, 1)
	Q_learning.start_episode()
end

function goal_state()
	local m = nearest_robot_message().range
	return (m or 20) < 20
end

function step()
	local reward_from_environment = reward()

	if done_steps > 0 then
		CSV.append(ANALYSIS_FILENAME, { done_steps, reward_from_environment })
		CSV.append("features_activation.csv", { done_steps, printable_vector(feature_activation_step), action })
		feature_activation_step = { 0, 0, 0, 0, 0, 0, 0 }
	end

	goal, action = Q_learning.q_step_argos(reward_from_environment, goal_state, done_steps)

	if not goal then
		take(action)
		done_steps = done_steps + 1
	else
		destroy()
		os.exit()
	end
end

function reset()
end

function destroy()
	for i=1, #feature_activations do
		print("Feature: " .. i .. ", activations: ", feature_activations[i])
	end
	local learned_weights = Q_learning.stop_episode()
	CSV.save(FILENAME, learned_weights)
end
