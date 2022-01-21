local validator = require 'validator'
local Algebra = require 'algebra'
local Matrix = Algebra.Matrix
local Vector = Algebra.Vector

------------------------------------------------------
------------------------------------------------------
--	Q(λ) with Linear Function Approximation Algorithm
------------------------------------------------------
------------------------------------------------------

local alpha = 0
local gamma = 0
local lambda = 0
local epsilon = 0

local theta = { }
local actions = 0
local choosed_action = 0
local state_features = { }
local eligibility_traces = { }

local active_state_features = { }

local first_step = true

----------------------------------------------------------------------
--	Determine state-action features from state-features for a state S
----------------------------------------------------------------------
local observe_active_state_features = function()
	local fn = function(state_feature) return state_feature() end
	return Vector.map(state_features, fn)
end

local print_vector = function(vector)
	local stringify = "[ "
	for i=1, #vector do
		stringify = stringify .. i .. "=" .. vector[i] .. ", "
	end
	print(stringify .. " ]")
end

local print_matrix = function(matrix)
	for r=1, #matrix do
		print_vector(matrix[r])
	end
end

---------------------------------------
--	Update rules of eligibility traces
---------------------------------------
local null_eligibility_traces = function()
	eligibility_traces = Matrix.create(actions, #state_features)
end

local accumulating_eligibility_traces = function(action, active_state_features)
	for feature_index=1, #eligibility_traces[action] do
		if active_state_features[feature_index] > 0 then
			local previous_eligibility_value = eligibility_traces[action][feature_index]
			eligibility_traces[action][feature_index] = previous_eligibility_value + 1
		end
	end
end

local exploitation_eligibility_traces = function()
	local exploitation_fn = function(eligibility_value)
		return gamma*lambda*eligibility_value
	end
	eligibility_traces = Matrix.map(eligibility_traces, exploitation_fn)
end


------------------------------
--	All operations on actions
------------------------------
--	Single action with max Q-value
local max_action_and_q = function(theta, active_state_features)
	local q_values = Matrix.vector_product(theta, active_state_features)
	local max_qs = Vector.max(q_values)
	local sample = robot.random.uniform_int(1, #max_qs)
	local action = max_qs[sample]
	return action, q_values[action]
end


-------------------------------
--	All operations on Q-values
-------------------------------
--	Q-value for a given action: based only on state-feature present in s,a
local q_value = function(action, active_state_features)
	return Vector.scalar_product(active_state_features, theta[action])
end


-------------------------------------
-- All operations on weights - theta
-------------------------------------
local theta_update = function(delta)
	local e_fn = function(eligibility_value)
		return alpha*delta*eligibility_value
	end
	--print_matrix(eligibility_traces)
	local eligibility_contribution = Matrix.map(eligibility_traces, e_fn)
	theta = Matrix.addition(eligibility_contribution, theta)
end

local random_weights = function()
	function random_generator(r, c)
		return robot.random.uniform()
	end
	return Matrix.create(actions, #state_features, random_generator)
end


-----------------------------
-- The kernel of the LFA-Q(λ)
-----------------------------
local config = function(state_action_space, weights, hyperparameters, initial_action)
	validator.check_state_action_space(state_action_space)
	validator.check_weights(weights, state_action_space)
	validator.check_hyperparameters(hyperparameters)
	validator.check_initial_action(initial_action, state_action_space)
	
	alpha = hyperparameters.alpha
	gamma = hyperparameters.gamma
	lambda = hyperparameters.lambda
	epsilon = hyperparameters.epsilon
	actions = state_action_space.actions
	state_features = state_action_space.state_features
	theta = next(weights) and weights or random_weights()
	choosed_action = initial_action or robot.random.uniform(1, actions)
end

local start_episode = function()
	null_eligibility_traces()
	active_state_features = observe_active_state_features()
end

local learn = function(reward)
	local q_a = q_value(choosed_action, active_state_features)
	local learning_error = reward - q_a
	active_state_features = observe_active_state_features()
	local _, max_q = max_action_and_q(theta, active_state_features)
	learning_error = learning_error + gamma * max_q
	theta_update(learning_error)
end

local epsilon_greedy_strategy = function()
	local action = robot.random.uniform_int(1, actions)
	local sample = robot.random.uniform()
	if sample < 1 - epsilon then
		action, _ = max_action_and_q(theta, active_state_features)
		exploitation_eligibility_traces()
	else
		null_eligibility_traces()
	end
	return action
end

local stop_episode = function()
	return theta
end


-----------------------------------
-- Adapter for ARGoS3 control loop
-----------------------------------
local q_step_argos = function(reward)
	if first_step then
		first_step = false
		return choosed_action
	end	
	
	accumulating_eligibility_traces(choosed_action, active_state_features)
	learn(reward)
	choosed_action = epsilon_greedy_strategy()
	return choosed_action
end

return { 
	config = config,
	start_episode = start_episode,
	q_step_argos = q_step_argos,
	stop_episode = stop_episode
}
