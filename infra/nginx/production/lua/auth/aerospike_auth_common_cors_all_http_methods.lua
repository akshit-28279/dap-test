function returnToClientForMethodOptions ( status )
  ngx.status = status
  local origin = ngx.req.get_headers()["Origin"]  -- get origin
  allowed_origins = {"%/paytm.com","%.paytm.com","%.paytmdgt.io","%.insider.in","%.paytmmoney.com"}
  for key,value in pairs(allowed_origins)
  do
  i,j = string.find(origin, value)
   if(i and j )
   then
           ngx.header["Access-Control-Allow-Origin"] = origin
           ngx.header["Access-Control-Allow-Headers"] = ngx.req.get_headers().access_control_request_headers
           ngx.header["Access-Control-Allow-Methods"] = ngx.req.get_headers().access_control_request_method
           break
   end
  end
  ngx.exit(status)
end

function returnToClientDigilocker ( status, errorcode, message, title, oauthres )
	local resBody =  {
                error  =  message,
                status =  {
                        result =  "failure",
                        message =  {
                                title =  title,
                                message =  message
                        }
                },
                oauth_responseCode = oauthres,
                code =  status,
                errorCode = errorcode
        }
        local origin = ngx.req.get_headers()["Origin"]  -- get origin
        allowed_origins = {"%/paytm.com","%.paytm.com","%.paytmdgt.io","%.insider.in","%.paytmmoney.com"}
        for key,value in pairs(allowed_origins)
        do
        i,j = string.find(origin, value)
         if(i and j )
         then
                ngx.header["Access-Control-Allow-Origin"] = origin
                ngx.header["Access-Control-Allow-Headers"] = ngx.req.get_headers().access_control_request_headers
                ngx.header["Access-Control-Allow-Methods"] = ngx.req.get_headers().access_control_request_method
                break
         end
        end

        ngx.header.content_type = "application/json"
        ngx.var.oauthres_code = oauthres
        ngx.status = status
        ngx.say(cjson.new().encode(resBody))
        ngx.exit(status)
end

if( ngx.req.get_method() == "OPTIONS" ) then returnToClientForMethodOptions (200) end

local ssoToken = nil

if( ngx.var.arg_sso_token == nil ) then ssoToken = ngx.req.get_headers().sso_token else ssoToken = ngx.var.arg_sso_token end

if(ssoToken == nil) then ssoToken = ngx.req.get_headers()["x-user-ssotoken"] end

if( ssoToken == nil )
then
	returnToClientDigilocker(401, "GE_OA_4000", "Auth token missing", "Login Required", 434)
end

err, message , r = as.get(cluster, namespace, set, ssoToken)

if( err ~= 0 )
then
	local h, err = ngx.req.get_headers()

	ngx.req.set_header("data",ssoToken)
	ngx.req.set_header("verification_type", "oauth_token")
	ngx.req.set_header("Content-Type", "application/json")
	ngx.req.set_header("x-dap-source-api", ngx.var.uri)

	local res = ngx.location.capture("/v2/user?fetch_strategy=DEFAULT,USER_TYPE,USERID", {method = ngx.HTTP_GET, body = '', args = ngx.req.get_uri_args ()})

	ngx.req.clear_header("x-dap-source-api")

	local value=cjson.new().decode(res.body)

        local responseCode = 410
        if( value ~= nil and value.responseCode ~= nil ) then
          responseCode = value.responseCode
        end

        if res.status ~= nil and res.status >= 500 and res.status <= 599 then
                returnToClientOauth5xx(tonumber(res.status), "Something went wrong. Please try after some time!", tonumber(res.status))
        end

        if res.status ~= 200 or res.truncated or res.body == nil then
		returnToClientDigilocker(410, "GE_OA_4001", "Failed to validate user details. Please try again.", "Error", tonumber(responseCode))
	end

	if( value.userId == nil ) then
		returnToClientDigilocker(410, "GE_OA_4002", "Failed to validate user details. Please try again.", "Error", tonumber(responseCode))
	end

	for k, v in pairs(h) do
                ngx.req.set_header(k,v)
        end

	ngx.req.set_header("X-USER-ID",value.userId)

	as.put(cluster, namespace, set, ssoToken, 1, {userId = "uid_"..value.userId })

else
        local userId = ""
        if(r.userId ~= nil) then
          userId = string.gsub(r.userId,"uid_", "")
          userId = string.gsub(userId, '\"', "")
        end
        ngx.req.set_header("X-USER-ID",userId)
end

ngx.exit(ngx.OK)
