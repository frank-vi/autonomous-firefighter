local PropertyValidator = { }

local check_elements_of_row = function(weights, row, columns)
	local message_weight_as_number = "The weight at row %d and column %d must be a number"
	for column=1, columns do
		assert(type(weights[row][column]) == 'number', string.format(message_weight_as_number, row, column))
	end
end

local is_weights_well_defined = function(weights, state_action_space)
	local number_of_rows_message = "The weights must have the number of rows equal to the number of actions"
	local number_of_columns_message = "The weights must have the number of columns equal (for each row)" ..
								"to the number of state_features.\n The wrong row is %d!"
	
	local actions = state_action_space.actions
	local state_features = #state_action_space.state_features
	
	if next(weights) then
		assert(#weights == actions, number_of_rows_message)
		
		for a=1, #weights do
			assert(#weights[a] == state_features, string.format(number_of_columns_message, a))
			check_elements_of_row(weights, a, state_features)
		end
	end
	return true
end

local is_integer = function(number)
	return type(number) == 'number' and
			math.floor(number) == number
end

local check_type_state_features = function(state_features)
	local message = "The %d-th state-feature must be a function"
	for sf=1, #state_features do
		assert(type(state_features[sf]) == 'function', string.format(message, sf))
	end
end

function PropertyValidator.check_state_action_space(state_action_space)
	assert(type(state_action_space) == 'table', "The state_action_space must be a non-empty table")
	assert(is_integer(state_action_space.actions), "The state_action_space must have an integer property named actions")
	assert(type(state_action_space.state_features) == 'table', "The state_action_space must have a property named state_features")
	assert(next(state_action_space.state_features), "The property state_features must be a non-empty table")
	check_type_state_features(state_action_space.state_features)
end

function PropertyValidator.check_weights(weights, state_action_space)
	assert(type(weights) == 'table', "The weights must be a table")
	assert(not next(weights) or is_weights_well_defined(weights, state_action_space), "The weights should be a matrix or empty (to be setting in random way)")
end

function PropertyValidator.check_hyperparameters(hyperparameters)
	local message_missing = "The hyperparameter %s is necessary for learning"
	local message_value = "The hyperparameter %s must be in [0,1]"
	assert(type(hyperparameters) == 'table', "The hyperparameters must be a table")
	assert(type(hyperparameters.alpha) == 'number', string.format(message_missing, "alpha"))
	assert(type(hyperparameters.gamma) == 'number', string.format(message_missing, "gamma"))
	assert(type(hyperparameters.lambda) == 'number', string.format(message_missing, "lambda"))
	assert(type(hyperparameters.epsilon) == 'number', string.format(message_missing, "epsilon"))
	assert(0 <= hyperparameters.alpha and hyperparameters.alpha <= 1, string.format(message_value, "alpha"))
	assert(0 <= hyperparameters.gamma and hyperparameters.gamma <= 1, string.format(message_value, "gamma"))
	assert(0 <= hyperparameters.lambda and hyperparameters.lambda <= 1, string.format(message_value, "lambda"))
	assert(0 <= hyperparameters.epsilon and hyperparameters.epsilon <= 1, string.format(message_value, "epsilon"))
end

function PropertyValidator.check_initial_action(initial_action, state_action_space)
	local message_value = "The initial_action must be in [%d, %d]"
	if initial_action then
		assert(is_integer(initial_action), "The initial_action must be an integer")
		assert(0 < initial_action and initial_action <= state_action_space.actions, string.format(message_value, 1, state_action_space.actions))
	end
	return true
end

return PropertyValidator