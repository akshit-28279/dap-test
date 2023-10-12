local function format_logger_data(logger, message)
    if (logger == nil) then
      return
    end
  
    --local maskUri = uri.gsub(uri, "account/([0-9a-zA-Z]*)/", "account/uniquenumber/")
    --ngx.log(ngx.ERR, message.location_name)
  
    local maskedLocationName, n, err = ngx.re.gsub(message.location_name, "/account/([0-9a-zA-Z]*)/", "/account/uniquenumber/", "i")
    --ngx.log(ngx.ERR, maskedLocationName, n, err)
  
    local default_tags = ",server_name:"..message.server_name
  
    if message.time and maskedLocationName then
      if message.vertical then
        logger:histogram("app.uri.latency", message.time * 1000 , "uri:"..maskedLocationName..",vertical:"..message.vertical)
      end
  
      --ngx.log(ngx.ERR, "app.uri.latency:", message.time, ":", maskedLocationName);
  
      logger:histogram("app.uri.latency", message.time * 1000 , "uri:"..maskedLocationName)
    end
  
    local genericStatus, n, err = ngx.re.gsub(message.status, "\\B\\d+", "XX", "i")
    if not err and genericStatus then
      logger:counter("app.uri.status", 1, 1, "status-uri:"..message.status.."-"..maskedLocationName..",status:"..genericStatus..default_tags..",uri:"..maskedLocationName..default_tags)
    end
  
    if message.status then
      logger:counter("app.uri.status_code", 1, 1, "status_code:"..message.status..",uri:"..maskedLocationName..default_tags)
    end
  
    if message.appErrorCode and string.len(message.appErrorCode) ~= 0 then
      logger:counter("app.uri.error_code", 1, 1, "app_error_code:"..message.appErrorCode..",uri:"..maskedLocationName..default_tags)
    end
  
    if message.vertical then
      logger:counter("app.uri.vertical", 1, 1, "vertical:"..message.vertical..",status_code:"..message.status..",uri:"..maskedLocationName)
    end
  
    if message.ff_service_id then
      logger:counter("app.uri.ff_status", 1, 1, "ff_service_id:"..message.ff_service_id..",ff_dest_status:"..message.ff_dest_status)
    end
  end
  
  local function create_logger(conf)
    --return "ABC"
    local statsd_logger = require "ngx_lua_datadog"
    --local statsd_logger = require "statd_logger"
    local logger, err = statsd_logger:new(conf)
    if err then
      ngx.log(ngx.ERR, "failed to create Statsd logger: ", err, " Conf:"..conf.host..":"..tostring(conf.port))
    end
    return logger
  end
  
  local function push_data(premature, message)
    local app_name = "Lua_stats_App_Education_Oms" --os.getenv('DATADOG_APP_NAME')
    local disable_datadog = os.getenv('DISABLE_DATADOG')
    local disable_telegraf = os.getenv('DISABLE_TELEGRAF')
    --ngx.log(ngx.ERR, app_name)
    --ngx.log(ngx.ERR, disable_datadog)
    --ngx.log(ngx.ERR, disable_telegraf)
  
    if app_name == nil then
      ngx.log(ngx.NOTICE, "Empty Datadog App Name, skip logging")
      return
    end
  
    --if not disable_telegraf then
      local telegraf_conf = {
        host = "127.0.0.1",
        port = 8130,
        namespace = app_name,
        timeout = 1
      }
      local telegraf_logger = create_logger(telegraf_conf)
      format_logger_data(telegraf_logger, message)
    --end
  
  end
  
  local function formatTags(msg)
    if msg.vertical then
      msg.vertical = string.gsub(msg.vertical, ",[0-9a-zA-Z]*", "")
    end
  end
  
  local message = {}
  
  --ngx.log(ngx.ERR, "HI")
  
  --if (ngx.var.location_name and ngx.var.location_name ~= "") then
  --  message["location_name"] = ngx.var.location_name
  --else
  --  message["location_name"] = ngx.var.uri
  --end
  
  message["location_name"] = ngx.var.uri
  message["uri_args"] = ngx.req.get_uri_args()
  message["server_name"] = ngx.var.host
  message["time"] = tonumber(ngx.var.upstream_response_time) or tonumber(ngx.var.request_time)
  message["sourceIp"] = ngx.var.remote_addr
  --message["appErrorCode"] = ngx.var.sent_http_app_err_code
  message["status"] = ngx.var.status
  message["status_code"] = ngx.var.status_code
  --message["vertical"] = ngx.var.sent_http_x_fs_ids
  --message["ff_service_id"] = ngx.var.sent_http_ff_service_id
  --message["ff_dest_status"] = ngx.var.sent_http_ff_dest_status
  --ngx.log(ngx.ERR, message)
  
  local ok, err = ngx.timer.at(0, push_data, message)
  if not ok then
    ngx.log(ngx.ERR, "Failed to create timer: ", err)
    return
  end