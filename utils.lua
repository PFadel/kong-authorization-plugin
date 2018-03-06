local _M = {}

function _M.set_config_defaults(config, headers)    
  -- Seta variáveis de API caso elas não tenham sido passadas
  if not config.apiKey then
    if not headers["apiKey"] then
      return false
    end
    config.apiKey = headers["apiKey"]
  end
  
  if not config.appKey then
    if not headers["appKey"] then
      return false
    end
    config.appKey = headers["appKey"]
  end

  return true
end

return _M