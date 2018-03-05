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
  ngx.log(ngx.NOTICE, "Setting headers")
  local headers = ngx.req.get_headers()
  ngx.req.clear_header('Host')
  headers['Content-Type'] = "application/json"
  headers["authorization"] = string.format("Bearer %s", config.apiKey)

  -- Executa o request http
  ngx.log(ngx.NOTICE, "Executing http request")
  local url = string.format("%s/api/management/%s/users/%s/roles", config.url, config.appKey, headers["email"])
  ngx.log(ngx.NOTICE, string.format("URL: %s", url))
  local res, err = httpc:request_uri(url, {
    method = "GET",
    ssl_verify = false,
    headers = headers
  })

  -- Erro Durante o request
  if err ~= nil then
    ngx.log(ngx.NOTICE, string.format("Error during request: %s", err))
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say(err)
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  -- Status code inesperado
  if res.status > 299 then
    ngx.log(ngx.NOTICE, "Unexpected status code")
    ngx.status = res.status
    for key, value in pairs(res.headers) do
      ngx.header[key] = value
    end
    ngx.say(res.body)
    return ngx.exit(res.status)
  end

  ngx.log(ngx.NOTICE, "Parsing JSON response")
  -- Parseia o resultado e avalia o role
  local data = cjson.decode(res.body)
  local permission = false
  for role in data["roles"] do
    if role["roleName"] == ngx.req.url then
      permission = true
    end
  end
  
  ngx.log(ngx.NOTICE, "Checking for permissions")
  -- Quando não há permissão para a rota
  if not permission then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    for key, value in pairs(res.headers) do
      ngx.header[key] = value
    end
    ngx.say(string.format("{%q: %q}", "message", "You don't have the necessary permissions for this resource"))

    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
end

return MiddlewareHandler