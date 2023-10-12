 #e ngx_lua settings
lua_package_path '$prefix/lua/?.lua;;';
rewrite_by_lua_no_postpone on;

limit_req_zone $binary_remote_addr zone=frequent:20m rate=4000r/s;
limit_req_zone $binary_remote_addr zone=mnp:20m rate=500r/s;
limit_req_zone $binary_remote_addr zone=userplans:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=cst:20m rate=25r/s;
limit_req_zone $binary_remote_addr zone=helpsection:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=subscription:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=monitoring:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=ebps:20m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ebpsv1:20m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ebpsv4:20m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ebpsv5:20m rate=10r/s;
limit_req_zone $binary_remote_addr zone=userdiy:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=managefee:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=cstnav:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=localisation:20m rate=4000r/s;
limit_req_zone $binary_remote_addr zone=loyalty:20m rate=40r/s;
limit_req_zone $binary_remote_addr zone=cstmanager:20m rate=25r/s;
limit_req_zone $binary_remote_addr zone=cstcare:20m rate=25r/s;
limit_req_zone $binary_remote_addr zone=loyalty-cards:20m rate=30r/s;
limit_req_zone $binary_remote_addr zone=paytm-prime:20m rate=1000r/s;
limit_req_zone $binary_remote_addr zone=mw:20m rate=25r/s;
limit_req_zone $binary_remote_addr zone=primesellerpanel:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=cstmanagerpanel:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=markAsPaid:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=bbps:20m rate=25r/s;
limit_req_zone $binary_remote_addr zone=notificationStatus:20m rate=25r/s;
limit_req_zone $binary_remote_addr zone=forms:20m rate=200r/s;
limit_req_zone $binary_remote_addr zone=bills:20m rate=1000r/s;
limit_req_zone $binary_remote_addr zone=digitalrecharge:20m rate=4000r/s;
limit_req_zone $binary_remote_addr zone=ffrorderactions:20m rate=2000r/s;
limit_req_zone $binary_remote_addr zone=aggregateTransaction:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=billpay-platform:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=billpay:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=digitaltickets:20m rate=200r/s;
limit_req_zone $binary_remote_addr zone=billpay-oauth:20m rate=10r/s;
limit_req_zone $binary_remote_addr zone=donation:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=customerbills:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=customerbilldownload:20m rate=300r/s;
limit_req_zone $binary_remote_addr zone=donationContrib:20m rate=100r/s;
limit_req_zone $binary_remote_addr zone=billerservice:20m rate=200r/s;
limit_req_zone $binary_remote_addr zone=recharge_saga:20m rate=4000r/s;
limit_req_zone $binary_remote_addr zone=recharges_bff:20m rate=4000r/s;
limit_req_zone $binary_remote_addr zone=chatregistersendbirdip:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=chatgetuserinfoip:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=chatgetuserinfov2ip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatregistersendbird:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatgetuserinfo:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatgetuserinfov2:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=chatgroupsip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatgroups:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=chatgroupsoperationsip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatgroupsoperations:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=chatusertokenip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatusertoken:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=chatreplymessageip:15m rate=15r/m;
limit_req_zone $http_sso_token zone=chatreplymessagesso:15m rate=15r/m;
limit_req_zone $binary_remote_addr zone=chatsplitip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatsplit:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=chatregisternotifyip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatregisternotify:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=chatbetaip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=chatbeta:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=getUserInfoip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=getUserInfo:20m rate=20r/m;
limit_req_zone $binary_remote_addr zone=getUserPayInfoip:20m rate=20r/m;
limit_req_zone $http_sso_token zone=getUserPayInfo:20m rate=20r/m;

limit_req_status 429;

init_by_lua_block {
        common_functions = require "auth/common_functions"
        cjson = require "cjson.safe"
        as = require "as_lua"
        err, message, cluster = as.connect("dap-aerospike.prod.paytmdgt.io", 3000)
        namespace = "apiproxy"
        set = "sso_token"
}

log_format education_forms_log_format '$remote_addr - $remote_user [$time_local] '
                         	    '"$request" $status $body_bytes_sent $request_length '
                      		    '"$http_referer" "$http_user_agent" '
                     		    '"$http_x_forwarded_for" ';

server {
  listen 81;
  if ($allowed_verb = 0){
    return 405;
  }
  server_name digitalproxy.paytm.com;
  location / {
    return 301 https://$host$request_uri;
  }
}

server {
  server_name digitalproxy.paytm.com ;
  root /var/www/market-dgapiproxy/releases/current/public/;
  index index.html index.htm;

  access_log /var/log/nginx/dgapiproxy.access.log main if=$loggable;
  error_log  /var/log/nginx/dgapiproxy.error.log;

  recursive_error_pages on;
  error_page 503 @maintenance;

  location @maintenance {
    if (-f $document_root/system/maintenance.json) {
      error_page 405 =  /system/maintenance.json;
      rewrite  ^(.*)$  /system/maintenance.json break;
    }
  }

  log_by_lua_file lua/datadog/api_latency.lua;
  #log_by_lua_file lua/datadog/apiproxy_api_latency.lua;

  rewrite ^/shop/user/checksession$ /v1/user/checksession break;
  include conf.d/ngx_auth_dgapi;
  include conf.d/ngx_noauth_dgapi;
  include conf.d/ngx_auth_channelsapi;
  include conf.d/ngx_noauth_channelsapi;
  include conf.d/ngx_auth_chatapi;
  include conf.d/ngx_noauth_chatapi;
  include conf.d/ngx_noauth_prodeosapi;
  include conf.d/ngx_auth_miniappsapi;
  include conf.d/ngx_noauth_miniappsapi;
  include conf.d/ngx_auth_moviesapi;
  include conf.d/ngx_auth_bank_statement_analysisapi;
  include conf.d/ngx_auth_healthapi;
  include conf.d/ngx_noauth_healthapi;
  include conf.d/ngx_auth_adsapi;
  include conf.d/ngx_auth_feedsapi;
  include conf.d/ngx_noauth_feedsapi;

  location / {
      default_type application/json;
      return 200 '{"status":200,"message":"null"}';
  }

}
