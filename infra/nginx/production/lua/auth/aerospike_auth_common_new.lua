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

function returnToClientForMethodOptions ( status ) 
  ngx.status = status
  local origins = {
    ["https://beta.paytm.com"] = true,
    ["https://paytm.com"] = true,
    ["http://fe.paytm.com"] = true
  }
  local origin = ngx.req.get_headers()["Origin"]  -- get request origin

  ngx.header["Access-Control-Allow-Origin"] = origins[origin] and origin or nil
    -- ngx.header["Access-Control-Allow-Origin"] = "*"
  ngx.header["Access-Control-Allow-Headers"] = ngx.req.get_headers().access_control_request_headers
  ngx.header["Access-Control-Allow-Methods"] = ngx.req.get_headers().access_control_request_method
  ngx.exit(status)
end


if( ngx.req.get_method() == "OPTIONS" ) then returnToClientForMethodOptions (200) end

local aerospike_auth_lua_file = assert(loadfile("/etc/nginx/lua/auth/aerospike_auth_userInfo.lua"))
aerospike_auth_lua_file()