-- q-value estimate for all actions
local q = { }

-- A **vector** of connection weights.
-- each weight is associated to a feature (of (s, a) pair)
-- actions x (unbiased + biased) state features --> #state-action features
local weights = { }

-- A **column vector** of eligibility traces, one for each component of weights vector 
local eligibility_traces = { }

-- learning hyperparameters
local hyperparameters = { }

local actions = { }

local state_features = { }

local random_weights = function()
	local random_w = { }
	for i=1, #actions do
		random_w[i] = { }
		for j=1, #state_features do
			random_w[i][j] = robot.random.uniform()
			print("random_weights: ", random_w[i][j])
		end
	end
	return random_w
end

local config = function(state_action_space, weights_vector, q_hyperparameters)
	weights = weights_vector
	hyperparameters = q_hyperparameters
	
--	print("Actions in config: ", #state_action_space.actions)
	actions = state_action_space.actions
	state_features = state_action_space.state_features
	
	if not next(weights) then
		weights = random_weights()
--		print("in config: ", #weights, " - ", #weights[1])
	end
	
	for i=1, #actions do
		q[i] = 0
	end
end

-- associated to 
local active_features = function(action)
	local active_features = { }
	
	if action ~= choosed_action then
		return active_features
	end
	
	for i=1, #state_features do
		local value = state_features[i]()
		if value > 0 then
			active_features[i] = value
		end
	end
	
	return active_features
end

local null_eligibility_traces = function()
	print("null_eligibility_traces: ", #weights)
	for action_index=1, #weights do
		eligibility_traces[action_index] = { }
		for state_feature_index=1, #weights[action_index] do
			eligibility_traces[action_index][state_feature_index] = 0
		end
	end
end

local eligibility_traces_update = function(action_active_features)
	for state_feature_index, state_feature_value in pairs(action_active_features) do
		local previous_value = eligibility_traces[choosed_action][state_feature_index]
		eligibility_traces[choosed_action][state_feature_index] = previous_value + state_feature_value -- e_i = e_i + 1
	end
end

local exploitation_eligibility_traces = function()
	local learning_parameter = hyperparameters.gamma*hyperparameters.lambda
	for action_index=1, #eligibility_traces do
		for state_feature_index=1, #eligibility_traces[action_index] do
			local value = eligibility_traces[action_index][state_feature_index]
			eligibility_traces[action_index][state_feature_index] = learning_parameter*value
		end
	end
end

local start_episode = function(initial_action)
	null_eligibility_traces()
	choosed_action = initial_action
	action_active_features = active_features(choosed_action)
	-- for first step where action is given by designer
	eligibility_traces_update(action_active_features)
end


local combination = function(action_active_features, action)
	local sum = 0
	local action_weights = weights[action]
	
	for state_feature_index, state_feature_value in pairs(action_active_features) do
		sum = sum + state_feature_value*action_weights[state_feature_index]
	end
	return sum
end

local action_with_q_max = function()
	local action = 1
	local current_q = -math.huge
	for i=1, #q do
		if q[i] > current_q then
			current_q = q[i]
			action = i
		end
	end
	return action
end

local epsilon_greedy_strategy = function()
	local sample = robot.random.uniform()
	if sample < 1 - hyperparameters.epsilon then
		for i=1, #actions do
			q[i] = combination(action_active_features, i)
		end
		choosed_action = action_with_q_max()
		exploitation_eligibility_traces()
	else
		choosed_action = robot.random.uniform_int(1, #actions)
		null_eligibility_traces()
	end
	return choosed_action
end


local approximation = function(action)
	local action_active_features = active_features(action)
	local action_q_value = combination(action_active_features, action)
	return action_q_value
end

local weights_update = function(delta)
	local learned_delta = hyperparameters.alpha*delta
	for action_index=1, #weights do
		for state_feature_index=1, #weights[action_index] do
			local value = weights[action_index][state_feature_index]
			local eligibility_trace = eligibility_traces[action_index][state_feature_index]
			weights[action_index][state_feature_index] = value + learned_delta*eligibility_trace
		end
	end
end

local evaluation = function(reward)
	eligibility_traces_update(action_active_features)
	for i=1, #actions do
		q[i] = (i == choosed_action) and
					combination(action_active_features, i) or 
					approximation(i)
	end
	local q_max = math.max(table.unpack(q))
	local delta = reward + hyperparameters.gamma*q_max - q[choosed_action]
	weights_update(delta)
end

function stop_episode()
	return weights
end

return {
	config = config,
	random_weights = random_weights,
	start_episode = start_episode,
	choose_action = epsilon_greedy_strategy,
	evaluation = evaluation,
	stop_episode = stop_episode
}