server {
  server_name oauth_proxy.paytm.com;

  open_log_file_cache max=1000 inactive=20s valid=1m min_uses=2;
  access_log /var/log/nginx/oauth_proxy.access.log main buffer=64k flush=5m;
  error_log  /var/log/nginx/oauth_proxy.error.log;

  location / {
    resolver 10.4.64.2 valid=1;
    open_log_file_cache max=1000 inactive=20s valid=1m min_uses=2;
    access_log /var/log/nginx/oauth_proxy.access.log main buffer=64k flush=5m;
    error_log  /var/log/nginx/oauth_proxy.error.log;
    proxy_read_timeout 5s;
    proxy_connect_timeout 5s;
    proxy_send_timeout 5s;
    set $url https://oauth.paytm.com;
    proxy_pass $url;
  }

  log_by_lua_file lua/datadog/api_latency.lua;

}
