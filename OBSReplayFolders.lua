-- description in obs
function script_description()
	 return [[Saves replays to sub-folders using the current fullscreen/focused video game executable name on Linux.

        Author: redraskal
            (original)
        Modified by: siucrae
            (adapted for linux with .so)
    ]]
end

-- add a callback for frontend events in OBS (when a replay buffer is saved)
function script_load()
	-- load the shared object (detect_game.so)
	ffi.cdef[[
		int get_running_fullscreen_game_path(char* buffer, int bufferSize)
	]]
	detect_game = ffi.load(script_path() .. "detect_game.so")
	obs.obs_frontend_add_event_callback(obs_frontend_callback)
end

-- callback to process events triggered by obs
function obs_frontend_callback(event)
	if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
		local path = get_replay_buffer_output()			-- get the path to the replay buffer output
		local folder = get_running_game_title()			-- get the game title from the shared object (detect_game.so)
		if path ~= nil and folder ~= nil then			-- if both the replay path and folder/game title are valid then move the file
			print("Moving " .. path .. " to " .. folder)	-- move the replay file to the appropriate folder
			move(path, folder)
		end
	end
end

-- retrieve the path of the latest replay buffer saved in obs
function get_replay_buffer_output()
	local replay_buffer = obs.obs_frontend_get_replay_buffer_output()	-- get the replay buffer object
	local cd = obs.calldata_create()					-- create an empty calldata object for passing data
	local ph = obs.obs_output_get_proc_handler(replay_buffer)		-- get the process handler for the replay buffer
	obs.proc_handler_call(ph, "get_last_replay", cd)			-- call the process handler to get the last saved replay
	local path = obs.calldata_string(cd, "path")				-- retrieve the path of the replay from calldata
	obs.calldata_destroy(cd)						-- clean up the calldata object
	obs.obs_output_release(replay_buffer)					-- release the replay buffer
	return path
end

-- function to get the running games title using the shared object (detect_game.so)
function get_running_game_title()
	local path = ffi.new("char[?]", 260)						-- allocate a buffer to store the game path
	local result = detect_game.get_running_fullscreen_game_path(path, 260)		-- call the function from the .so library to get the running games path

	-- if there was an error or the game path is not available then return nil
		if result ~= 0 then
			return nil
		end

	-- convert the result from C string to lua string
	result = ffi.string(path)
	local len = #result

	-- if the path length is zero/no game detected then return nil
		if len == 0 then
			return nil
		end
	
	return result
end

-- function to move the replay file to a new folder based on the game title
function move(path, folder)
	local sep = string.match(path, "^.*()/")			-- extract the directory separator from the file path
	local root = string.sub(path, 1, sep) .. folder			-- construct the new root directory for the game folder
	local file_name = string.sub(path, sep, string.len(path))	-- get the file name from the original path
	local adjusted_path = root .. file_name				-- construct the new file path with the folder
	
	-- check if the target directory exists; if not then create it
		if obs.os_file_exists(root) == false then
			obs.os_mkdir(root)
		end

	-- rename/move the file to the new location
	obs.os_rename(path, adjusted_path)
end
