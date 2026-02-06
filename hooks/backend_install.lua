-- hooks/backend_install.lua
-- Installs a Homebrew formula via zerobrew
-- Uses isolated ZEROBREW_ROOT per installation for mise compatibility

function PLUGIN:BackendInstall(ctx)
    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end
    if not version or version == "" then
        error("Version cannot be empty")
    end
    if not install_path or install_path == "" then
        error("Install path cannot be empty")
    end

    local cmd = require("cmd")

    -- Find zerobrew binary: check PATH first, then mise install locations
    local zb_path = cmd.exec("which zb 2>/dev/null || true"):gsub("%s+$", "")
    if zb_path == "" then
        -- Look in common mise install locations for the cargo-installed zb
        local home = os.getenv("HOME") or ""
        local candidates = {
            home .. "/.local/share/mise/installs/cargo-https-github-com-lucasgelfond-zerobrew/latest/bin/zb",
            home .. "/.local/share/mise/installs/cargo-https-github-com-lucasgelfond-zerobrew/HEAD/bin/zb",
            home .. "/.cargo/bin/zb",
        }
        for _, candidate in ipairs(candidates) do
            local check = cmd.exec("test -x '" .. candidate .. "' && echo found || echo missing")
            if check:match("found") then
                zb_path = candidate
                break
            end
        end
    end

    if zb_path == "" then
        error([[
zerobrew (zb) not found in PATH or mise installs.

Install zerobrew first:
  mise use cargo:https://github.com/lucasgelfond/zerobrew

For more info: https://github.com/lucasgelfond/zerobrew
]])
    end

    -- Determine the actual formula name to install
    local formula
    if version == "latest" then
        -- Install the base formula (e.g., "ruby")
        formula = tool
    else
        -- Install the versioned formula (e.g., "python@3.11")
        formula = tool .. "@" .. version
    end

    -- Validate formula contains only safe characters (alphanumeric, @, -, _, .)
    if not formula:match("^[%w@%-%._]+$") then
        error("Invalid formula name: " .. formula)
    end

    -- Shell-quote paths in case they contain spaces
    local quoted_path = "'" .. install_path:gsub("'", "'\\''") .. "'"
    local quoted_zb = "'" .. zb_path:gsub("'", "'\\''") .. "'"

    -- Use --root and --prefix so zb auto-initializes into the install path
    -- (no need for global /opt/zerobrew or sudo). Pipe "Y" to accept the
    -- auto-init prompt if this is the first install into this root.
    local install_cmd = "echo Y | " .. quoted_zb
        .. " --root " .. quoted_path
        .. " --prefix " .. quoted_path .. "/prefix"
        .. " install " .. formula

    local result, install_err = cmd.exec(install_cmd)

    if install_err then
        error("Failed to install " .. formula .. ": " .. install_err)
    end

    -- Fix Homebrew Cellar dylib paths: bottles have install names like
    -- opt/<formula>/<version>/lib<name>.dylib, but zerobrew's opt/<formula>
    -- symlink already points to Cellar/<formula>/<version>/, making the
    -- resolved path Cellar/<formula>/<version>/<version>/lib<name>.dylib
    -- which doesn't exist. Create <version> -> . symlinks to fix this.
    local cellar_dir = quoted_path .. "/prefix/Cellar"
    local fix_cmd = "for d in " .. cellar_dir .. "/*/*; do "
        .. "v=$(basename \"$d\"); "
        .. "[ ! -e \"$d/$v\" ] && ln -s . \"$d/$v\" 2>/dev/null; "
        .. "done; true"
    cmd.exec(fix_cmd)

    return {}
end
