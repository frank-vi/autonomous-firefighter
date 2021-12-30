--

local q = {}

--- Save the Q table into a csv file.
--
-- @param file_name the name of the new file (could include path).
-- @param Q_table the table to be saved.
function q.save_Q_table(file_name, Q_table)

  local file = assert(io.open(file_name, "w"), "Impossible to create the file " .. file_name .. " .")
  for i = 1, #Q_table do
    file:write(Q_table[i][1])
    for j = 2, #Q_table[1] do
      file:write(", " .. Q_table[i][j])
    end
    file:write("\n")
  end
  file:close()
  
end

--- Load Q table from a csv file.
--
-- @param file_name the name of an existing file (could include path).
-- @return the Q table.
function load_Q_table(file_name)

  local file = assert(io.open(file_name, "r"), "Impossible to open the file " .. file_name .. " .")
  local Q_table = {}
  local i = 1
  for line in file:lines() do
    Q_table[i] = {}
    local j = 1
    for value in line:gmatch("([^,%s]+)") do
      Q_table[i][j] = tonumber(value)
      j = j + 1
    end
    i = i + 1
  end
  file:close()
  
  return Q_table

end

function q.load(filename)
	function open_csv(filename)
		local file = assert(io.open(filename, "r"))
		return file
	end
	
	function create_file()
		local file = assert(io.open(filename, "w"))
		file:close()
	end
	
	local status, returned_value = pcall(open_csv, filename)
	
	if not status and string.find(returned_value, "No such file or directory") then
		create_file()
	end
	
	return load_Q_table(filename)
end


-- Write header if file is empty or if file not found else do nothing
function q.create_csv(filename, header)
	function open_csv(filename)
		local file = assert(io.open(filename, "r"))
		return file
	end
	
	function create_header(filename, header)
		local file = assert(io.open(filename, "w"))
		local header_string = header[1]
		for i=2, #header do
			header_string = header_string .. "," .. header[i]
		end
		
		file:write(header_string)
		file:write("\n")
		file:flush()
		file:close()
	end
	
	local status, returned_value = pcall(open_csv, filename)
	
	if (not status and string.find(returned_value, "No such file or directory")) or
		(status and not returned_value) then
		create_header(filename, header)
	end
end

function q.append(filename, record)
	local file = io.open(filename, "a")
	local record_string = record[1]
	for i=2, #record do
		record_string = record_string .. "," .. record[i]
	end
		
	file:write(record_string)
	file:write("\n")
	file:flush()
	file:close()	
end

return {
	save = q.save_Q_table,
	load = q.load,
	create_csv = q.create_csv,
	append = q.append
}