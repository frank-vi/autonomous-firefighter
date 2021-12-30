local CSV = require 'csv_helper'
local Q_learning = require 'q_approximation'

local BIAS = 1.0
-- learning rate
local ALPHA = 0.1
-- discount factor
local GAMMA = 0.9
-- bootstrapping factor
local LAMBDA = 0.8
-- epsilon value for greedy action selection
local EPSILON = 0.9

local REWARD = 2
local PENALTY = 3

local MAX_VELOCITY = 10

local FILENAME = 'weights.csv'
local ANALYSIS_FILENAME = "analysis.csv"

local distance = 0

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

-- 3 actions
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
		print("nearest_robot_message: ", robot.range_and_bearing[i].horizontal_bearing)
		if message.range < (previous_message.range or 0) then
			previous_message = table.copy(message)
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
	print("signal_detection_15: ", transmiter_angle)
	return 0 <= transmiter_angle and transmiter_angle < 15
end

function signal_detection_30()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	return 15 < transmiter_angle and transmiter_angle < 30
end

function signal_detection_45()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	return 30 < transmiter_angle and transmiter_angle < 45
end

function signal_detection_60()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	return 45 < transmiter_angle and transmiter_angle < 60
end

function signal_detection_75()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	return 60 < transmiter_angle and transmiter_angle < 75
end

function signal_detection_90()
	local message = nearest_robot_message()	
	
	if not next(message) then
		return 0
	end
	
	local transmiter_angle = message.horizontal_bearing
	return 75 < transmiter_angle < 90
end

local state_features = {
	signal_detection_15,
	signal_detection_30,
	signal_detection_45,
	signal_detection_60,
	signal_detection_75,
	signal_detection_90,
	function() return BIAS end
}


--------------------
-- REWARD DEFINITION
--------------------
local euclidean_distance = function(position1, position2)
	return math.sqrt(math.pow(position1.x - position2.x, 2) + math.pow(position1.y - position2.y, 2))
end

local reward = function()
	local robot_position = robot.positioning.position
	local survivor_position = { x = -1.8, y = 0.4 } 
	
	local current_distance = euclidean_distance(robot_position, survivor_position)
	
	if current_distance < distance then
		return REWARD * (distance - current_distance)
	elseif current_distance > distance then
		return PENALTY * (distance - current_distance)
	else
		return 0
	end
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
  
  print("in take: ", action_index, " - ", actions[action_index])
  local angle = actions[action_index]
  local wheels_distance = robot.wheels.axis_length
  local left_v = MAX_VELOCITY - (angle * wheels_distance / 2)
  local right_v = MAX_VELOCITY + (angle * wheels_distance / 2)
  
  left_v, right_v = limit_v(left_v, right_v)
  robot.wheels.set_velocity(left_v,right_v)
end

function init()
	action = 1
	done_steps = 0
	local weights = CSV.load(FILENAME)	
	local state_action_space = { actions = actions, state_features = state_features }
	local hyperparameters = { alpha = ALPHA, gamma = GAMMA, lambda = LAMBDA, epsilon = EPSILON, bias = BIAS }
	
	print("Actions in init: ", #state_action_space.actions)
	
	CSV.create_csv(ANALYSIS_FILENAME, { "step", "reward" })
	
	Q_learning.config(state_action_space, weights, hyperparameters)
	Q_learning.start_episode(action)
end

function step()
	if done_steps > 0 then
		local reward_from_environment = reward()
		CSV.append(ANALYSIS_FILENAME, { done_steps, reward_from_environment })
		Q_learning.evaluation(reward_from_environment)
		action = Q_learning.choose_action()
	end
	
	-- the first action is chosen by the designer,
	-- so we can immediatly execute it
	take(action)
	done_steps = done_steps + 1
end

function reset()
end

function destroy()
	local learned_weights = Q_learning.stop_episode()
	CSV.save(FILENAME, learned_weights)
end
