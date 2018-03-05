local BasePlugin = require "kong.plugins.base_plugin"
local http = require 'resty.http'
local cjson = require "cjson"

local MiddlewareHandler = BasePlugin:extend()

MiddlewareHandler.PRIORITY = 1006

function MiddlewareHandler:new()
  MiddlewareHandler.super.new(self, "middleware-gim")
end

function MiddlewareHandler:access(config)
  MiddlewareHandler.super.access(self)

  local httpc = http:new()
  local headers = ngx.req.get_headers()
  ngx.req.clear_header('Host')
  headers['Content-Type'] = "application/json"
  
  -- Executa o request http
  local res, err = httpc:request_uri(config.url, {
    method = "POST",
    ssl_verify = false,
    headers = headers,
    body = string.format("{\"ApplicationKey\": %q, \"Token\": %q}", config.appKey, headers["token"])
  })
  
  -- Erro Durante o request
  if err ~= nil then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say(err)
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  
  -- Status code inesperado
  if res.status > 299 then
    ngx.status = res.status
    for key, value in pairs(res.headers) do
      ngx.header[key] = value
    end
    ngx.say(res.body)
    return ngx.exit(res.status)
  end

  -- Parseia o resultado e avalia o sucesso
  local data = cjson.decode(res.body)
  if not data["Success"] then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    for key, value in pairs(res.headers) do
      ngx.header[key] = value
    end
    ngx.say(res.body)    
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
end

return MiddlewareHandler