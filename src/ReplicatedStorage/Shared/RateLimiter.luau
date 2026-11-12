--!strict
-- Token bucket per key. Pure logic (the clock is passed in) so it can be unit tested
-- outside Roblox.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

export type RateLimiter = typeof(setmetatable(
	{} :: { _burst: number, _perSecond: number, _buckets: { [any]: Bucket } },
	RateLimiter
))

-- burst: calls allowed at once; perSecond: sustained refill rate.
function RateLimiter.new(burst: number, perSecond: number): RateLimiter
	assert(burst >= 1 and perSecond > 0, "RateLimiter needs burst >= 1 and perSecond > 0")
	return setmetatable({ _burst = burst, _perSecond = perSecond, _buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any, now: number): boolean
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._burst, last = now }
		self._buckets[key] = bucket
	end

	local elapsed = math.max(0, now - bucket.last)
	bucket.tokens = math.min(self._burst, bucket.tokens + elapsed * self._perSecond)
	bucket.last = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

return RateLimiter
