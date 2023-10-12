function returnToClientForMethodOptions ( status ) 
  ngx.status = status
  local origin = ngx.req.get_headers()["Origin"]  -- get origin
  allowed_origins = {"%/paytm.com","%.paytm.com","%.paytmdgt.io","%.insider.in"}
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

local aerospike_auth_lua_file = assert(loadfile("/etc/nginx/lua/auth/aerospike_auth.lua"))
aerospike_auth_lua_file()
