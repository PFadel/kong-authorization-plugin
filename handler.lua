local BasePlugin = require "kong.plugins.base_plugin"
local http = require 'resty.http'
local cjson = require "cjson"
local utils = require "kong.plugins.kong-authorization-plugin.utils"

local MiddlewareHandler = BasePlugin:extend()

MiddlewareHandler.PRIORITY = 1006

function MiddlewareHandler:new()
  MiddlewareHandler.super.new(self, "kong-authorization-plugin")
end

function MiddlewareHandler:access(config)
  MiddlewareHandler.super.access(self)

  local httpc = http:new()
  local headers = {}
  local req_headers = ngx.req.get_headers()
  
  if not utils.set_config_defaults(config, req_headers) then
    ngx.status = ngx.HTTP_BAD_REQUEST
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
  end

  headers['Content-Type'] = "application/json"
  headers["Authorization"] = string.format("Bearer %s", config.apiKey)

  -- Executa o request http
  local url = string.format("%s/api/management/%s/users/%s/roles", config.url, config.appKey, req_headers["email"])
  ngx.log(ngx.NOTICE, string.format("Executing http request to URL: %s", url))
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
  local expected_permission = ""
  for i, role in pairs(data["roles"]) do

    expected_permission = string.format("%s_%s_%s", ngx.var.request_method, ngx.var.host, ngx.var.request_uri)
    ngx.log(ngx.NOTICE, string.format("EXPECTED_PERMISSION: %s", expected_permission))

    if role["roleName"] == expected_permission and role["active"] then
      permission = true
    end
  end
  
  ngx.log(ngx.NOTICE, "Checking for permissions")
  -- Quando não há permissão para a rota
  if not permission then
    ngx.log(ngx.NOTICE, "Do not have permission")
    ngx.status = ngx.HTTP_UNAUTHORIZED

    ngx.log(ngx.NOTICE, "Setting headers")
    ngx.header["Cache-Control"] = res.headers["Cache-Control"]
    ngx.header["Pragma"] = res.headers["Pragma"]
    ngx.header["Date"] = res.headers["Date"]
    ngx.header["Expires"] = res.headers["Expires"]
    ngx.header['Content-Type'] = "application/json"

    ngx.log(ngx.NOTICE, "Setting body")
    ngx.say(string.format("{%q: %q}", "message", "You don't have the necessary permissions for this resource"))

    ngx.log(ngx.NOTICE, "Returning.")
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
  ngx.log(ngx.NOTICE, "Has permission.")
end

return MiddlewareHandler
