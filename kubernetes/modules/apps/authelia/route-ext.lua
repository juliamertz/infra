local theme_url = '/themepark/css/base/authelia/rose-pine-moon.css'
local css_link = '<link rel="stylesheet" type="text/css" href="' .. theme_url .. '">'

function envoy_on_response(res)
	local content_type = res:headers():get 'content-type' or 'none'

	if string.match(content_type, 'text/html') then
		local body = res:body()
		if body then
			local original = body:getBytes(0, body:length())
			local modified = string.gsub(original, '</head>', css_link .. '</head>')
			body:setBytes(modified)
			res:headers():replace('content-length', tostring(#modified))
		end
	end
end
