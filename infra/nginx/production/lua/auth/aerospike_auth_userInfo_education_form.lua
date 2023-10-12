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
8. In this type auth block we also append some additional information of user like
	customer first name,customer id, email,mobile number
9. Now only education vertical is using this information to generate invoice 

]]--

function returnToClientEdu ( status, errorcode, message, title, oauthres )
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
		ngx.header["Access-Control-Allow-Origin"] = "*"
		ngx.header["Access-Control-Allow-Headers"] = ngx.req.get_headers().access_control_request_headers
		ngx.header["Access-Control-Allow-Methods"] = ngx.req.get_headers().access_control_request_method
	  
        ngx.header.content_type = "application/json"
        ngx.status = status
        ngx.var.oauthres_code = oauthres
        ngx.say(cjson.new().encode(resBody))
        ngx.exit(status)
end

local ssoToken, formSet = nil, "education_token_form"

if( ngx.var.arg_sso_token == nil ) then ssoToken = ngx.req.get_headers().sso_token else ssoToken = ngx.var.arg_sso_token end 

if( ssoToken == nil )
then
	returnToClientEdu(401, "GE_OA_4000", "Auth token missing", "Login Required", 434)
end

err, message , r = as.get(cluster, namespace, formSet, ssoToken)

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
		returnToClientEdu(410, "GE_OA_4001", "Failed to validate user details. Please try again.", "Error", tonumber(responseCode))
	end

	if( value.userId == nil ) then
		returnToClientEdu(410, "GE_OA_4002", "Failed to validate user details. Please try again.", "Error", tonumber(responseCode))
	end
	
	for k, v in pairs(h) do
            	ngx.req.set_header(k,v)
		end	

	local userInfo, userEmail,userFirstname, userPhone = value.defaultInfo, "","",""

	if( userInfo ~= nil) then
		userEmail = userInfo.email~= nil and userInfo.email or ""
		userFirstname = userInfo.firstName~= nil and  userInfo.firstName or ""
		userPhone = userInfo.phone~= nil and userInfo.phone or ""
	end

	ngx.req.set_header("X-USER-ID",value.userId)
	ngx.req.set_header("X-USER-EMAIL",userEmail)
	ngx.req.set_header("X-USER-FIRSTNAME",userFirstname)
	ngx.req.set_header("X-USER-PHONE",userPhone)	

--	due to bug in aerospike wrapper, mobile number is getting overflown, hence commenting this line till this issue is fixed
--	as.put(cluster, namespace, formSet, ssoToken, 4, {userId = value.userId, email = userEmail, firstName = userFirstname, phone = userPhone})

else
	ngx.req.set_header("X-USER-ID",r.userId)
	ngx.req.set_header("X-USER-EMAIL",r.email)
	ngx.req.set_header("X-USER-FIRSTNAME",r.firstName)
	ngx.req.set_header("X-USER-PHONE",r.phone)
end

ngx.exit(ngx.OK)

