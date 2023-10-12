--[[
This module is responsible for handling the subrequest to the session validation module in the app. The module
acts as the middle layer between the front end and internal servies like crm etc. thus bypassing 
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
	customer first name,customer id, email,mobile number,isFirstUser

]]--

function contains(table, val)
	for i=1,#table do
		if table[i] == val then
			return true
		end
	end
	return false

end

local ssoToken, formSet = nil, "sso_token_pfg"

if( ngx.var.arg_sso_token == nil ) then ssoToken = ngx.req.get_headers().sso_token else ssoToken = ngx.var.arg_sso_token end

if( ssoToken == nil )
then
	ngx.exit(ngx.OK)
end


local h, err = ngx.req.get_headers()

ngx.req.set_header("accesstokenauthorization",ssoToken)
ngx.req.set_header("apikeyauthorization", "Basic Y2FzX2NpbmZyYV9jc3Q6MzMzMzQzOTA2QCQqcXE6MTYwMDA4Nzk2OA==")
ngx.req.set_header("Content-Type", "application/json")

local res = ngx.location.capture("/cas/v1/s/user", {method = ngx.HTTP_GET, body = '', args = ngx.req.get_uri_args ()})

local value=cjson.new().decode(res.body)

local responseCode = 410
if( value ~= nil and value.code ~= nil ) then
    responseCode = value.code
end

if res.status ~= nil and res.status >= 500 and res.status <= 599 then
    returnToClientOauth5xx(tonumber(res.status), "Something went wrong. Please try after some time!", tonumber(res.status))
end

if res.status ~= 200 or truncated or res.body == nil then
	returnToClient(410, "GE_OA_4002", "Failed to validate user details. Please try again.", "Error", tonumber(responseCode))
end


if( value == nil or value.code == 2061 ) then
	returnToClient(401, "GE_OA_4001", "Looks like you have been signed out. Please login again and retry.", "Login Required", tonumber(responseCode))
end

if( value.user == nil ) then
	returnToClient(410, "GE_OA_4002", "Failed to validate user details. Please try again.", "Error", tonumber(responseCode))
end

for k, v in pairs(h) do
	ngx.req.set_header(k,v)
end

local userInfo, userId, userEmail, userFirstname, userPhone, maskedId = value.user, "", "", "", "", ""

if( userInfo ~= nil) then
	userId = userInfo.customer_id~= nil and userInfo.customer_id or ""
	userEmail = userInfo.email~= nil and userInfo.email or ""
	userFirstname = userInfo.first_name~= nil and  userInfo.first_name or ""
	userPhone = userInfo.mobile_number~= nil and userInfo.mobile_number or ""
	maskedId = userInfo.masked_msisdn~= nil and userInfo.masked_msisdn or ""
end

ngx.req.set_header("X-USER-ID",userId)
ngx.req.set_header("X-USER-EMAIL",userEmail)
ngx.req.set_header("X-USER-FIRSTNAME",userFirstname)
ngx.req.set_header("X-USER-PHONE",userPhone)
ngx.req.set_header("X-USER-MASKED-ID",maskedId)


ngx.exit(ngx.OK)
