--!strict
local RateLimit = {}

function RateLimit.consume(bucket, now, rate, burst)
	local tokens = if bucket
		then math.min(burst, bucket.tokens + math.max(0, now - bucket.at) * rate)
		else burst
	local allowed = tokens >= 1
	return allowed, { tokens = if allowed then tokens - 1 else tokens, at = now }
end

return RateLimit
