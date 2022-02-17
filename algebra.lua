local Matrix = {}
local Vector = {}

----------------------
--	Vector operations
----------------------
function Vector.map(vector, fn)
	local vector_result = { }
	for i=1, #vector do
		vector_result[i] = fn(vector[i])
	end
	return vector_result
end

function Vector.addition(vector1, vector2)
	local vector = { }
	for i=1, #vector1 do
		vector[i] = vector1[i] + vector2[i]
	end
	return vector
end

function Vector.scalar_product(vector1, vector2)
	local sum = 0
	for i=1, #vector1 do
		sum = sum + (vector1[i]*vector2[i])
	end
	return sum
end

function Vector.max(q_values)
	local max_q = q_values[1]
	local max_q_indices = { 1 }
	for i=2, #q_values do
		if q_values[i] > max_q then
			max_q = q_values[i]
			max_q_indices = { i }
		elseif q_values[i] == max_q then
			max_q_indices[#max_q_indices + 1] = i
		end
	end
	return max_q_indices
end


----------------------
--	Matrix operations
----------------------
function Matrix.create(rows, columns, value_generator)
	local matrix = {}
	for r=1, rows do
		matrix[r] = { }
		for c=1, columns do
			matrix[r][c] = value_generator and value_generator(r, c) or 0
		end
	end
	return matrix
end

function Matrix.map(matrix, fn)
	local map = function(row)
		return Vector.map(row, fn)
	end
	return Vector.map(matrix, map)
end

function Matrix.vector_product(matrix, vector)
	local mul = function(row)
		return Vector.scalar_product(row, vector)
	end
	return Vector.map(matrix, mul)
end

function Matrix.addition(matrix1, matrix2)
	local matrix = { }
	for r=1, #matrix1 do
		matrix[r] = Vector.addition(matrix1[r], matrix2[r])
	end
	return matrix
end

return {
	Vector = Vector,
	Matrix = Matrix
}
