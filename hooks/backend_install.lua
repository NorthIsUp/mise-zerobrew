-- hooks/backend_install.lua
-- Installs a Homebrew formula via zerobrew.
-- Requires cargo:https://github.com/lucasgelfond/zerobrew to be installed
-- as a mise dependency (declared in metadata.lua).

--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall
--- @param ctx {tool: string, version: string, install_path: string} Context
--- @return table Empty table on success
function PLUGIN:BackendInstall(ctx)
    local tool         = ctx.tool
    local version      = ctx.version
    local install_path = ctx.install_path

    -- Validate inputs
    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end
    if not version or version == "" then
        error("Version cannot be empty")
    end
    if not install_path or install_path == "" then
        error("Install path cannot be empty")
    end

    local cmd  = require("cmd")
    local file = require("file")
    local log  = require("log")
    local json = require("json")

    -- zb is installed by mise as a dependency (github:lucasgelfond/zerobrew).
    -- Scan the mise installs dir to find zb regardless of resolved version.

    local home         = os.getenv("HOME") or ""
    local data_dir     = os.getenv("XDG_DATA_HOME") or file.join_path(home, ".local", "share")
    local installs_dir = file.join_path(data_dir, "mise", "installs")

    local install_base = ""

    local deps = {
        [1] = "github-lucasgelfond-zerobrew",
        [2] = "cargo-https-github-com-lucasgelfond-zerobrew",
    }

    for _i, dep in pairs(deps) do
        local dep_path = file.join_path(installs_dir, dep)
        if file.exists(dep_path) then
            install_base = dep_path
            break
        end
    end

    if install_base == "" then
        error(
            "zerobrew (zb) not found\n"
            .. "To use the zb plugin zerobrew must be added as a mise tool.\n"
            .. "Try: mise use 'github:lucasgelfond/zerobrew'"
        )
    end

    log.debug("zerobrew dependency install base: " .. (install_base or "not found"))
    
    -- Determine formula name
    local formula
    if version == "latest" then
        formula = tool
    else
        formula = tool .. "@" .. version
    end

    log.debug("zerobrew dependency found, installing formula: " .. formula)

    if not formula:match("^[%w@%-%._]+$") then
        error("Invalid formula name: " .. formula)
    end

    local quoted_path = "'" .. install_path:gsub("'", "'\\''") .. "'"
    local install_cmd = "zb --yes"
        .. " --root "   .. quoted_path
        .. " --prefix " .. quoted_path .. "/prefix"
        .. " install "  .. formula

    log.debug("installing: " .. install_cmd)
    local _, install_err = cmd.exec(install_cmd)
    if install_err then
        error("Failed to install " .. formula .. ": " .. install_err)
    end

    -- Fix Homebrew Cellar dylib paths: bottles have install names like
    -- opt/<formula>/<version>/lib<name>.dylib, but zerobrew's opt/<formula>
    -- symlink already points to Cellar/<formula>/<version>/, making the
    -- resolved path Cellar/<formula>/<version>/<version>/lib<name>.dylib
    -- which doesn't exist. Create <version> -> . symlinks to fix this.
    local cellar_dir = quoted_path .. "/prefix/Cellar"
    cmd.exec(
        "for d in " .. cellar_dir .. "/*/*; do "
        .. "v=$(basename \"$d\"); "
        .. "[ ! -e \"$d/$v\" ] && ln -s . \"$d/$v\" 2>/dev/null; "
        .. "done; true"
    )

    return {}
end
