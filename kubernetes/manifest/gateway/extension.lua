---@diagnostic disable: lowercase-global

---@param tbl table
---@param item unknown
---@return boolean
local function table_contains(tbl, item)
	local normalized = string.lower(item)
	for _, val in ipairs(tbl) do
		if string.lower(val) == normalized then
			return true
		end
	end
	return false
end

---@meta envoy

---@class StreamHandle
---@field headers fun(self): Headers
---@field body fun(self): string|nil
---@field bodyChunks fun(self): fun(): string
---@field trailers fun(self): Headers
---@field log fun(self, level: integer, message: string)
---@field logTrace fun(self, message: string)
---@field logDebug fun(self, message: string)
---@field logInfo fun(self, message: string)
---@field logWarn fun(self, message: string)
---@field logErr fun(self, message: string)
---@field logCritical fun(self, message: string)
---@field metadata fun(self): table
---@field streamInfo fun(self): StreamInfo
---@field connection fun(self): Connection
---@field respond fun(self, headers: table, body: string|nil)

---@class Headers
---@field get fun(self, name: string): string|nil
---@field add fun(self, name: string, value: string)
---@field replace fun(self, name: string, value: string)
---@field remove fun(self, name: string)

---@class StreamInfo
---@field protocol fun(self): string
---@field dynamicMetadata fun(self): DynamicMetadata

---@class DynamicMetadata
---@field get fun(self, filter: string): table
---@field set fun(self, filter: string, key: string, value: any)

---@class Connection
---@field ssl fun(self): SSL|nil

---@class SSL
---@field peerCertificatePresented fun(self): boolean
---@field uriSanLocalCertificate fun(self): table
---@field uriSanPeerCertificate fun(self): table

local crawler_user_agents = {
	'AhrefsBot',
	'Amazonbot',
	'Applebot',
	'Bytespider',
	'ClaudeBot',
	'CCBot',
	'DuckAssistBot',
	'Google-CloudVertexBot',
	'GoogleOther',
	'GPTBot',
	'Meta-ExternalAgent',
	'PetalBot',
	'TikTokSpider',
}

---@param request_handle StreamHandle
function envoy_on_request(request_handle)
  --- Block known crawlers
	local user_agent = request_handle:headers():get 'user-agent' or ''
	if table_contains(crawler_user_agents, user_agent) then
		request_handle:respond({ [':status'] = '403' }, 'Forbidden')
	end

  --- Enforce HTTPS at gateway level
	local proto = request_handle:headers():get 'x-forwarded-proto'
	if proto == 'http' then
		local host = request_handle:headers():get ':authority'
		local path = request_handle:headers():get ':path'
		request_handle:respond({ [':status'] = '301', ['location'] = 'https://' .. host .. path }, '')
	end
end

---@param response_handle StreamHandle
function envoy_on_response(response_handle)
	response_handle:headers():add('server', 'envoy')
end
