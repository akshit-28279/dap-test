function returnToClient ( status, errorcode, message, title, oauthres )
	local resBody =  {
                error  =  message,
                status =  {
                        result =  "failure",
                        message =  {
                                title =  title,
                                message =  message
                        }
                },
                oauth_response_Code = oauthres,
                code =  status,
                errorCode = errorcode 
        }  
        ngx.header.content_type = "application/json"
        ngx.status = status
        ngx.var.oauthres_code = oauthres
        ngx.say(cjson.new().encode(resBody))
        ngx.exit(status)
end

function returnToClientOauth5xx ( status, message, oauthres )
	local resBody =  {
                code =  status,
                error  =  message,
                oauth_responseCode = oauthres
        }  
        ngx.header.content_type = "application/json"
        ngx.status = status
        ngx.var.oauthres_code = oauthres
        ngx.say(cjson.new().encode(resBody))
        ngx.exit(status)
end