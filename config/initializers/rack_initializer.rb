if Rack::Utils.respond_to?("key_space_limit=")
  Rack::Utils.key_space_limit = 12582912 #Allow for file upload to api of 12Mb  
end