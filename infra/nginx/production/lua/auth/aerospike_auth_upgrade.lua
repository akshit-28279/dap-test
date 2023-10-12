--[[
This module is responsible for handling the subrequest to the session validation module in the app. The module
acts as the middle layer between the front end and internal servies like oauth, favourites, etc. thus bypassing 
the cart and shop apps completely

Steps for the same
1. Extract sso_token from query params and headers.
2. If token is not there send 401 with Auth Token Missing Error
3. check in aerospike if sso_token data is saved or not
4. If data is there then set the header and proxy pass the request
5. If record not found in erospike call Auth API.
6. Set the headers and proxy pass the request.
7. Save the same in Aerospike for specific TTL ( 15 minutes )

]]--

function returnToClientUpgrade ( status, errorcode, message, title ,statusCode, oauthres )
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
                code =  statusCode,
                errorCode = errorcode 
        }  
        ngx.header.content_type = "application/json"
        ngx.status = status
        ngx.var.oauthres_code = oauthres
        ngx.say(cjson.new().encode(resBody))
        ngx.exit(status)
end

local ssoToken = nil

if( ngx.var.arg_sso_token == nil ) then ssoToken = ngx.req.get_headers().sso_token else ssoToken = ngx.var.arg_sso_token end 

if( ssoToken == nil )
then
	returnToClientUpgrade(412, "GE_OA_4000", "Please update your app to access Automatic Payments.", "Authentication error", 400, 434)
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
		returnToClientUpgrade(410, "GE_OA_4001", "Failed to validate user details. Please try again.", "Error", 410, tonumber(responseCode))
	end

	if( value.userId == nil ) then
		returnToClientUpgrade(410, "GE_OA_4002", "Failed to validate user details. Please try again.", "Error", 410, tonumber(responseCode))
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

