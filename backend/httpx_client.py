import httpx

# Shared persistent client for all outgoing requests
# Drastically reduces latency in the proxy by reusing connections
client = httpx.AsyncClient(
    timeout=30.0,
    limits=httpx.Limits(max_keepalive_connections=20, max_connections=50),
    follow_redirects=True,
)

async def close_client():
    await client.aclose()
