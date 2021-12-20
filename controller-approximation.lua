q = {}
weights = {}
eligibility = {}
features_a = {}

gamma = ...
lambda = ...
epsilon = ...

first_step = true

MAX_DISTANCE = 0.7
MAX_VELOCITY = 10
FILENAME = "weights.csv"

local bias = 1.0

local features = {
	is_obstacle_detected
}

local actions = { 
	{ left = MAX_VELOCITY, right = MAX_VELOCITY }, -- forward
	{ left = 0, right = MAX_VELOCITY }, -- left
	{ left = MAX_VELOCITY, right = 0 }, -- right
	{ left = -MAX_VELOCITY, right = -MAX_VELOCITY } -- backward
}

function eligibility_init()
	for i=1, #features do
		eligibility[i] = 0
	end
end

function weights_update() -- TODO check the theta update rule
	for i=1, #weights do
		local learning_value = alpha*delta*eligibility[i]
		
		for j=1, #weights[i] do
			weights[i][j] = weights[i][j] + learning_value
		end
	end
end

function eligibility_update()
	for i=1, #features_a do
		eligibility[i] = (eligibility[i] or 0) + 1
	end
end

function is_obstacle_detected()
	for i=1, #robot.proximity do
		if (robot.proximity[i] > MAX_DISTANCE) then
			return 1
		end
	end
	return 0
end

function get_features(a)
	local vector = {}
	for i=1, #features do
		local feature_value = features[i]()
		if (feature_value == 1) then
			vector[i] = feature_value
		end
	end
	vector[#features + 1] = bias
	return vector
end

function q_approximation(features_a, a)
	local sum = 0
	for feature_index, feature_value in pairs(features_a) do
		sum = sum + weights[feature_index][a]*feature_value
	end
	return sum
end

function init()
	-- TODO load weights on disk
	eligibility_init()
	weigth_init()
	a = get_action()
end

function optimal_action()
	local action = 1
	local current_q = 0
	for i=1, #q do
		if q[i] > current_q then
			current_q = q[i]
			action = i
		end
	end
	return action
end

function get_action()
	local random_n = robot.random.uniform()
	if random_n < 1- epsilon then
		for k=1, #actions do
			if k == a then
				q[k] = q_a
			else
				local features_k = {}
				local features_k[#features + 1] = bias
				q[k] = q_approximation(features_k, k)
			end
		end
		
		a = optimal_action()
		
		for i=1, #eligibility do
			eligibility[i] = gamma*lambda*eligibility[i]
		end
	else
		a = robot.random.uniform(1, #actions)
		eligibility_init()
	end
end

function take_action(a)
	velocity = actions[a]
	robot.wheels.set_velocity(velocity.left, velocity.right)
end

function step()
	if not first_step then
		reward = get_reward() -- TODO
		features_a = get_features()
		q_a = q_approximation(features_a, a)
		delta = reward - q_a
		
		for k=1, #actions do
			if k == a then
				q[k] = q_a
			else
				local features_k = {}
				local features_k[#features + 1] = bias
				q[k] = q_approximation(features_k, k)
			end
		end
		
		delta = delta + gamma*optimal_action()
		weights_update()
		
		a = get_action()
	end

	eligibility_update()
	take_action(a)
	first_step = false
end

function reset()
	
end

function destroy()
	-- TODO save weights on disk
end
