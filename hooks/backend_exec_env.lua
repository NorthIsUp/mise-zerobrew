-- hooks/backend_exec_env.lua
-- Sets up environment variables for zerobrew-installed tools,
-- mirroring what `zb init` would inject into the shell.

function PLUGIN:BackendExecEnv(ctx)
    local install_path = ctx.install_path
    local file = require("file")

    -- XDG base dirs
    local home           = os.getenv("HOME") or ""
    local xdg_data_home  = os.getenv("XDG_DATA_HOME") or file.join_path(home, ".local", "share")
    local xdg_bin_home   = os.getenv("XDG_BIN_HOME")  or file.join_path(home, ".local", "bin")

    local prefix_path = file.join_path(install_path, "prefix")
    local bin_path    = file.join_path(prefix_path, "bin")

    local env_vars = {
        { key = "ZEROBREW_DIR",    value = file.join_path(xdg_data_home, "zerobrew") },
        { key = "ZEROBREW_BIN",    value = file.join_path(xdg_bin_home, "zerobrew", "bin") },
        { key = "ZEROBREW_ROOT",   value = install_path },
        { key = "ZEROBREW_PREFIX", value = prefix_path },
        { key = "PATH",            value = bin_path },
    }

    -- pkg-config path
    local pkgconfig_path = file.join_path(prefix_path, "lib", "pkgconfig")
    if file.exists(pkgconfig_path) then
        table.insert(env_vars, { key = "PKG_CONFIG_PATH", value = pkgconfig_path })
    end

    -- library paths
    local lib_path = file.join_path(prefix_path, "lib")
    if file.exists(lib_path) then
        table.insert(env_vars, { key = "LIBRARY_PATH", value = lib_path })
        if RUNTIME.osType == "Darwin" then
            table.insert(env_vars, { key = "DYLD_LIBRARY_PATH", value = lib_path })
        elseif RUNTIME.osType == "Linux" then
            table.insert(env_vars, { key = "LD_LIBRARY_PATH", value = lib_path })
        end
    end

    -- include paths for development headers
    local include_path = file.join_path(prefix_path, "include")
    if file.exists(include_path) then
        table.insert(env_vars, { key = "C_INCLUDE_PATH",     value = include_path })
        table.insert(env_vars, { key = "CPLUS_INCLUDE_PATH", value = include_path })
    end

    -- SSL/TLS certificates (mirrors `zb init` ca-certificates logic)
    local cert_candidates = {
        file.join_path(prefix_path, "opt", "ca-certificates", "share", "ca-certificates", "cacert.pem"),
        file.join_path(prefix_path, "etc", "ca-certificates", "cacert.pem"),
        file.join_path(prefix_path, "etc", "openssl", "cert.pem"),
        file.join_path(prefix_path, "share", "ca-certificates", "cacert.pem"),
    }
    for _, cert_file in ipairs(cert_candidates) do
        if file.exists(cert_file) then
            table.insert(env_vars, { key = "CURL_CA_BUNDLE", value = cert_file })
            table.insert(env_vars, { key = "SSL_CERT_FILE",  value = cert_file })
            break
        end
    end

    local cert_dir_candidates = {
        file.join_path(prefix_path, "etc", "ca-certificates"),
        file.join_path(prefix_path, "etc", "openssl", "certs"),
        file.join_path(prefix_path, "share", "ca-certificates"),
    }
    for _, cert_dir in ipairs(cert_dir_candidates) do
        if file.exists(cert_dir) then
            table.insert(env_vars, { key = "SSL_CERT_DIR", value = cert_dir })
            break
        end
    end

    return { env_vars = env_vars }
end
