-- Prints the numbers perf.sh needs, including p95, which wrk's own report leaves out.
local post = os.getenv("COMPAT_POST") == "1"
if post then
  wrk.method = "POST"
  wrk.headers["Content-Type"] = "application/json"
  wrk.body = '{"id":1,"content":"hello"}'
end
done = function(summary, latency, requests)
  local errors = summary.errors.connect + summary.errors.read + summary.errors.write + summary.errors.status + summary.errors.timeout
  io.write(string.format("COMPAT %d %d %d %d %d %d\n", summary.requests, summary.duration,
    latency:percentile(50), latency:percentile(95), latency:percentile(99), errors))
end
