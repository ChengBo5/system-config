#!/bin/bash
# Start both MCP servers in cloud mode

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Start market data server on port 8000
echo "Starting Binance Futures Market Data Server on port 8000..."
python binance_market.py --transport sse --host 0.0.0.0 --port 8000 &
MARKET_PID=$!

# Start account server on port 8001
echo "Starting Binance Futures Account Server on port 8001..."
python binance_account.py --transport sse --host 0.0.0.0 --port 8001 &
ACCOUNT_PID=$!

echo "Market Data Server PID: $MARKET_PID"
echo "Account Server PID: $ACCOUNT_PID"
echo "Servers started successfully!"
echo ""
echo "Market Data Server: http://0.0.0.0:8000"
echo "Account Server: http://0.0.0.0:8001"
echo ""
echo "Press Ctrl+C to stop all servers..."

# Wait for both processes
wait $MARKET_PID $ACCOUNT_PID
