--[[
This module is responsible for handling the subrequest to the session validation module in the app. The module
acts as the middle layer between the front end and internal servies like oauth, favourites, etc. thus bypassing 
the cart and shop apps completely

Steps for the same
1. Extract sso_token from query params and headers.
2. check in aerospike if sso_token data is saved or not
3. If data is there then set the header and proxy pass the request
4. If record not found in erospike call Auth API.
5. Set the headers and proxy pass the request.
6. Save the same in Aerospike for specific TTL ( 15 minutes )

]]--

function returnToClientForMethodOptions ( status )
	ngx.status = status
	local origin = ngx.req.get_headers()["Origin"]  -- get origin
	allowed_origins = {"%/paytm.com","%.paytm.com","%.paytmdgt.io","%.insider.in","%.amazonaws.com"}
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

if( ngx.req.get_method() == "OPTIONS" ) then returnToClientForMethodOptions (200) end

local ssoToken = nil

if( ngx.var.arg_sso_token == nil ) then ssoToken = ngx.req.get_headers().sso_token else ssoToken = ngx.var.arg_sso_token end 

function trim_func(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end
function split_func(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(t, trim_func(str))
	end
	return t
end
function returnToClientGeneric ( status, errorcode, message, displayMessage, statusCode, oauthres )
	local resBody =  {
		code = errorcode,
		status = status,
		message = message,
		displayMessage = displayMessage,
		oauth_responseCode = oauthres
	}
	ngx.header.content_type = "application/json"
	ngx.status = tonumber(statusCode)
	ngx.var.oauthres_code = oauthres
	ngx.say(cjson.new().encode(resBody))
	ngx.exit(tonumber(statusCode))
end
function ngx_exit(msg, oauthres)
	if msg ~= nil then
		msg_val = split_func(msg, ',')
		local keys={"status", "errorcode", "message", "displayCode", "statusCode"}
		values = {}
		for k, v in pairs(msg_val) do
			values[keys[k]]=v
		end
		returnToClientGeneric(values["status"], values["errorcode"], values["message"], values["displayCode"], values["statusCode"], oauthres)
	else
		ngx.exit(ngx.OK)
	end
end

if( ssoToken == nil )
then
	ngx.exit(ngx.OK)
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

	if res.status ~= 200 or res.truncated or res.body == nil then
		ngx_exit(ngx.var.msg_null_body, tonumber(responseCode))
	end

	if( value.userId == nil ) then
		ngx_exit(ngx.var.msg_null_userId, tonumber(responseCode))
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
