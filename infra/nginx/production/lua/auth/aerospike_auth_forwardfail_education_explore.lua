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


local ssoToken, formSet = nil, "education_token_form"

if( ngx.var.arg_sso_token == nil ) then ssoToken = ngx.req.get_headers().sso_token else ssoToken = ngx.var.arg_sso_token end 

if( ssoToken == nil )
then
	ngx.exit(ngx.OK)
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

	if res.status ~= 200 or res.truncated or res.body == nil then
		ngx.exit(ngx.OK)
	end

	local value=cjson.new().decode(res.body)

	if( value.userId == nil ) then
		ngx.exit(ngx.OK)
	end
	
	for k, v in pairs(h) do
		ngx.req.set_header(k,v)
	end

	local userInfo, userEmail,userFirstname, userPhone, userDob = value.defaultInfo, "","","",""

	if(userInfo ~= nil) then
		userEmail = userInfo.email~= nil and userInfo.email or ""
		userFirstname = userInfo.firstName~= nil and  userInfo.firstName or ""
		userPhone = userInfo.phone~= nil and userInfo.phone or ""
		userDob = userInfo.dob~= nil and userInfo.dob or ""

		ngx.req.set_header("X-USER-ID",value.userId)
		ngx.req.set_header("X-USER-EMAIL",userEmail)
		ngx.req.set_header("X-USER-FIRSTNAME",userFirstname)
		ngx.req.set_header("X-USER-PHONE",userPhone)
		ngx.req.set_header("X-USER-DOB",userDob)

--		due to bug in aerospike wrapper, mobile number is getting overflown, hence commenting this line till this issue is fixed
--		as.put(cluster, namespace, formSet, ssoToken, 5, {userId = value.userId, email = userEmail, firstName = userFirstname, phone = userPhone, dob = userDob})
	end

else
    ngx.req.set_header("X-USER-ID",r.userId)
    ngx.req.set_header("X-USER-EMAIL",r.email)
    ngx.req.set_header("X-USER-FIRSTNAME",r.firstName)
    ngx.req.set_header("X-USER-PHONE",r.phone)
    ngx.req.set_header("X-USER-DOB",r.dob)
end

ngx.exit(ngx.OK)
