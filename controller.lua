Qlearning = require "Qlearning"

MOVE_STEPS = 5
MAX_VELOCITY = 10
FILENAME = "Qtable-circuit.csv"
WHEEL_DIST = -1
MAXRANGE = 10
FIRE_THRESHOLD = 0.7
OBSTACLE_THRESHOLD = 0.7
HELP_MESSAGE = 1
FIRE_PENALTY = -10
OBSTACLE_PENALTY = -5
SPOT_PENALTY = -100
SURVIVOR_REWARD = 20
SURVIVOR_SPOT_REWARD = 100

alpha = 0.1
gamma = 0.9
epsilon = 0.9
k = 2

survivor = false

function perform_action(action)
  -- Ensure not to exceed MAX_VELOCITY
  function limit_v(left_v, right_v)
    function limit(value)
		if (value > MAX_VELOCITY) then
			value = MAX_VELOCITY
		end

		if (value < -MAX_VELOCITY) then
			value = -MAX_VELOCITY
		end
		return value
    end
    return limit(left_v), limit(right_v)
  end
  
  local angle = action_directions[action_names[action]]
  local left_v = MAX_VELOCITY - (angle * WHEEL_DIST / 2)
  local right_v = MAX_VELOCITY + (angle * WHEEL_DIST / 2)
  
  left_v, right_v = limit_v(left_v, right_v)
  robot.wheels.set_velocity(left_v, right_v)
end

function get_state()
	local new_state = 1
  
	for i = 1, #robot.motor_ground do -- 1 to 4
		if robot.motor_ground[i].value == 0 then
			new_state = new_state + math.pow(2,i-1)
		end
	end
	
	for i = 5, #robot.light + 4 do -- light 5 to 28
		if robot.light[i].value > FIRE_THRESHOLD then
			new_state = new_state + math.pow(2,i-1)
		end
	end

	for i = 29, #robot.proximity+28 do -- proximity 29 to 52
		if robot.proximity[i].value > OBSTACLE_THRESHOLD then
			new_state = new_state + math.pow(2,i-1)
		end
	end
	
	
	if is_survivor_near() then
		new_state = new_state + math.pow(2,52)
	end
  
	return new_state
end

function is_on_spot()
	local number_sensors = 0
	for i=1, #robot.motor_ground do
		if robot.motor_ground[i] == 0 then
			number_sensors = number_sensors + 1
		end
	end	
	return number_sensors >= 2
end

function is_survivor_near()
	for i = 1, #robot.range_and_bearing do
		if robot.range_and_bearing[i].range < MAXRANGE and
			robot.range_and_bearing[i].data[1]==1 then
			return true
		end
	end
	return false
end

function is_fire_near()
end

function is_obstacle_near()
end

function get_reward()
	local reward = 0
	if not survivor then
		survivor = is_survivor_near()
	end
	
	if is_fire_near() then
		-- se sbatti sul fuoco								penalità X=-10
		reward = reward + FIRE_PENALTY
	elseif is_obstacle_near() then
		-- se sbatti sugli ostacoli							penalità X=-5
		reward = reward + OBSTACLE_PENALTY
	end
	
	if survivor and not is_on_spot() then
		-- se trovi il survivor								reward Y=20
		reward = reward + SURVIVOR_REWARD
	end
	
	if is_on_spot() then
		if survivor then
			-- se trovi lo spot ed hai (trovato) il survivor	reward Y=100
			reward = reward + SURVIVOR_SPOT_REWARD
		else
			-- se trovi lo spot senza survivor					penalità X=-100
			reward = reward + SPOT_PENALTY
		end
	end
	
	return reward
end

function init()
	n_steps = 0
	local left_v = MAX_VELOCITY
	local right_v = MAX_VELOCITY
	
	WHEEL_DIST = robot.wheels.axis_length
	
	number_of_sensors = #robot.light + #robot.proximity + #robot.motor_ground + 1 -- 24+24+4+1=53 
	number_of_states = math.pow(2, #number_of_sensors) -- 2^53=9,007,199,254,740,992
	
	action_names = { "FORWARD", "BACK", "LEFT", "RIGHT" }
	action_directions = { ["FORWARD"] = 0, ["BACK"] = -math.pi, ["LEFT"] = -math.pi/4, ["RIGHT"] = math.pi/4 }
	
	old_state = get_state()
	state = old_state
	action = 1 -- forward
	
	number_of_actions = #action_names
  
	-- Dimension: 2^53 x 4 values.
	Q_table = {}
	Q_table = Qlearning.load_Q_table(FILENAME)
	robot.wheels.set_velocity(left_v, right_v)
end

function step()
	n_steps = n_steps + 1
	if n_steps % MOVE_STEPS == 0 then
		-- Update
		state = get_state()
		Q_table = Qlearning.update_Q_table(alpha, gamma, old_state, action, get_reward(), state, Q_table)

		-- Perform action
		action = Qlearning.get_random_action(epsilon, state, Q_table)
		--action = Qlearning.get_weighted_action(k, old_state, Q_table)
		perform_action(action)
		old_state = state
	end
end

function reset()
	local left_v = MAX_VELOCITY
	local right_v = MAX_VELOCITY
	action = 1
	robot.wheels.set_velocity(left_v,right_v)
	n_steps = 0
end

function destroy()
	Qlearning.save_Q_table(FILENAME, Q_table)
end
