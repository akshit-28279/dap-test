--[[
This module is responsible for handling the subrequest to the session validation module in the app. The module
acts as the middle layer between the front end and internal servies like oauth, favourites, etc. thus bypassing 
the cart and shop apps completely

]]--

function returnToClientForMethodOptions ( status ) 
  ngx.status = status
  ngx.exit(status)
end

ngx.header["Access-Control-Allow-Origin"] = "*"
ngx.header["Access-Control-Allow-Headers"] = ngx.req.get_headers().access_control_request_headers
ngx.header["Access-Control-Allow-Methods"] = ngx.req.get_headers().access_control_request_method

if( ngx.req.get_method() == "OPTIONS" ) then returnToClientForMethodOptions (200) end
