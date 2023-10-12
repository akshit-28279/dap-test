local function push_data(premature, message)
    local conf = { host = "127.0.0.1", port = 8130, namespace = "Lua_Stats_App.digital_apiproxy", timeout = 1}
    local statsd_logger = require "ngx_lua_datadog"
    local logger, err = statsd_logger:new(conf)

    if err then
        ngx_log(ngx.ERR, "failed to create Statsd logger: ", err)
    end

    local maskUri, n, err = ngx.re.gsub(message.uri, "[//]\\d+[//]*", "/XXXXX/", "i")
    maskUri, n, err = ngx.re.gsub(maskUri, "[//][a-zA-Z0-9\\-\\_]+[.].{22}[//]*", "/XXXXX/", "i")
    --Replace UUID from URI [Vertical:Content] [/content-comments/v1/post/ad71826f-8f7f-4ac2-ba65-34e384b7e1f1]
    maskUri, n, err = ngx.re.gsub(maskUri, "[//]\\d*\\w*-\\d*\\w*-\\d*\\w*-\\d*\\w*-\\d*\\w*[//]*", "/XXXXX/", "i")

        --ngx.log(ngx.ERR, maskUri, "remote_ip:"..message.sourceIp, "app_error_code:")
    if message.urt and maskUri then
        if message.vertical then
                logger:histogram("app.uri.latency", tonumber(message.urt)*1000 , "uri:"..maskUri..",vertical:"..message.vertical)
        end
        logger:histogram("app.uri.latency", tonumber(message.urt)*1000 , "uri:"..maskUri)
    end
    local genericStatus, n, err = ngx.re.gsub(message.status, "\\B\\d+", "XX", "i")
    --ngx.log(ngx.ERR, genericStatus, n)
    if not err and genericStatus then
        logger:counter("app.uri.status", 1, 1, "status-uri:"..message.status.."-"..maskUri..",status:"..genericStatus..",uri:"..maskUri)
    end
    if message.status then
        logger:counter("app.uri.status_code", 1, 1, "status_code:"..message.status..",uri:"..maskUri)
    end
    --logger:counter("app.uri.ip", 1, 1, "remote_ip:"..message.sourceIp)
    if message.appErrorCode and string.len(message.appErrorCode) ~= 0 then
        logger:counter("app.uri.error_code", 1, 1, "app_error_code:"..message.appErrorCode)
    end
    if message.vertical then
    --  ngx.log( ngx.ERR, "vertical", "vertical:"..message.vertical..":"..message.status)
        logger:counter("app.uri.vertical", 1, 1, "vertical:"..message.vertical..":"..message.status..",uri:"..maskUri)
    end
    if message.ff_service_id then
       logger:counter("app.uri.ff_status", 1, 1, "ff_service_id:"..message.ff_service_id..",ff_dest_status:"..message.ff_dest_status)
    end
    if message.oauthres_code then
        logger:counter("app.uri.oauthres_code", 1, 1, "oauthres_code:"..message.oauthres_code..",uri:"..maskUri)
    end
end

local message = {}
local urt = ngx.var.upstream_response_time
local sourceIp = ngx.var.remote_addr
local appErrorCode = ngx.var.sent_http_app_err_code
message["uri"] = ngx.var.uri
message["urt"] = ngx.var.upstream_response_time
message["sourceIp"] = ngx.var.remote_addr
message["appErrorCode"] = ngx.var.sent_http_app_err_code
message["status"] = ngx.var.status
message["status_code"] = ngx.var.status_code
message["vertical"] = ngx.var.sent_http_x_fs_ids
message["ff_service_id"] = ngx.var.sent_http_ff_service_id
message["ff_dest_status"] = ngx.var.sent_http_ff_dest_status
message["oauthres_code"] = ngx.var.oauthres_code
local ok, err = ngx.timer.at(0, push_data, message)
if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
end
