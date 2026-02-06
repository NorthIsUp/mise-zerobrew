-- hooks/backend_exec_env.lua
-- Sets up environment variables for zerobrew-installed tools
--
-- Because mise overwrites (not appends) non-PATH env vars across tools,
-- we scan ALL installed zerobrew prefixes and return combined values.
-- Every tool's BackendExecEnv returns the same comprehensive set, so it
-- doesn't matter which one "wins" -- they all contain all paths.

function PLUGIN:BackendExecEnv(ctx)
    local cmd = require("cmd")
    local file = require("file")

    -- Find all installed zerobrew prefixes
    local home = os.getenv("HOME") or ""
    local installs_dir = home .. "/.local/share/mise/installs"
    local raw = cmd.exec("ls -d " .. installs_dir .. "/zerobrew-*/*/prefix 2>/dev/null || true")

    local prefixes = {}
    for line in raw:gmatch("[^\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(prefixes, trimmed)
        end
    end

    -- Collect paths by type
    local bin_paths = {}
    local lib_paths = {}
    local include_paths = {}
    local pkgconfig_paths = {}

    for _, prefix in ipairs(prefixes) do
        local bin_dir = file.join_path(prefix, "bin")
        local lib_dir = file.join_path(prefix, "lib")
        local include_dir = file.join_path(prefix, "include")
        local pkgconfig_dir = file.join_path(prefix, "lib", "pkgconfig")

        if file.exists(bin_dir) then
            table.insert(bin_paths, bin_dir)
        end
        if file.exists(lib_dir) then
            table.insert(lib_paths, lib_dir)
        end
        if file.exists(include_dir) then
            table.insert(include_paths, include_dir)
        end
        if file.exists(pkgconfig_dir) then
            table.insert(pkgconfig_paths, pkgconfig_dir)
        end
    end

    -- Build env vars
    local env_vars = {}

    -- PATH (mise appends this properly)
    for _, p in ipairs(bin_paths) do
        table.insert(env_vars, { key = "PATH", value = p })
    end

    -- Colon-separated library paths
    if #lib_paths > 0 then
        local lib_joined = table.concat(lib_paths, ":")
        table.insert(env_vars, { key = "LIBRARY_PATH", value = lib_joined })
        if RUNTIME.osType == "Darwin" then
            table.insert(env_vars, { key = "DYLD_LIBRARY_PATH", value = lib_joined })
        elseif RUNTIME.osType == "Linux" then
            table.insert(env_vars, { key = "LD_LIBRARY_PATH", value = lib_joined })
        end
    end

    -- Colon-separated include paths
    if #include_paths > 0 then
        local include_joined = table.concat(include_paths, ":")
        table.insert(env_vars, { key = "C_INCLUDE_PATH", value = include_joined })
        table.insert(env_vars, { key = "CPLUS_INCLUDE_PATH", value = include_joined })
    end

    -- Colon-separated pkg-config paths
    if #pkgconfig_paths > 0 then
        table.insert(env_vars, { key = "PKG_CONFIG_PATH", value = table.concat(pkgconfig_paths, ":") })
    end

    -- Space-separated compiler/linker flags
    if #lib_paths > 0 then
        local ldflags = {}
        for _, p in ipairs(lib_paths) do
            table.insert(ldflags, "-L" .. p)
        end
        table.insert(env_vars, { key = "LDFLAGS", value = table.concat(ldflags, " ") })
    end

    if #include_paths > 0 then
        local cppflags = {}
        for _, p in ipairs(include_paths) do
            table.insert(cppflags, "-I" .. p)
        end
        table.insert(env_vars, { key = "CPPFLAGS", value = table.concat(cppflags, " ") })
    end

    return {
        env_vars = env_vars,
    }
end
