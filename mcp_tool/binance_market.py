import logging
from typing import List, Annotated
from pydantic import BaseModel, Field
from mcp.server.fastmcp import FastMCP

from _common import (
    client,
    VALID_PERIODS, VALID_INTERVALS,
    _raw_to_dict,
    _fmt_ts, _fmt_ts_long,
    _validate_period, _validate_limit,
)

logger = logging.getLogger(__name__)


# --- Pydantic Models ---

class Kline(BaseModel):
    """K线数据（精简版，仅保留关键字段节省token）"""
    t: str = Field(description="开盘时间，格式 'MM-DD HH:MM'")
    h: float = Field(description="最高价")
    l: float = Field(description="最低价")
    c: float = Field(description="收盘价")

class LongShortRatio(BaseModel):
    """多空比数据"""
    long_short_ratio: float = Field(description="多空比，>1 偏多，<1 偏空")
    timestamp: str = Field(description="时间戳，格式 'MM-DD HH:MM'")

class Ticker24hr(BaseModel):
    """24小时行情统计"""
    symbol: str = Field(description="交易对")
    price_change_percent: float = Field(description="24h 涨跌幅（%）")
    last_price: float = Field(description="最新价格")
    volume: float = Field(description="24h 成交量（基础资产）")
    high_price: float = Field(description="24h 最高价")
    low_price: float = Field(description="24h 最低价")

class FundingRate(BaseModel):
    """资金费率"""
    symbol: str = Field(description="交易对")
    funding_rate: float = Field(description="当前资金费率，正值多头付费，负值空头付费")
    funding_time: str = Field(description="下次结算时间，格式 'YYYY-MM-DD HH:MM:SS'")

class OpenInterest(BaseModel):
    """持仓量"""
    symbol: str = Field(description="交易对")
    open_interest: float = Field(description="当前总持仓量")
    timestamp: str = Field(description="时间戳，格式 'YYYY-MM-DD HH:MM:SS'")

class OpenInterestStats(BaseModel):
    """持仓量历史统计"""
    open_interest_value: float = Field(description="持仓总价值（USDT）")
    timestamp: str = Field(description="时间戳，格式 'MM-DD HH:MM'")

class TakerVolume(BaseModel):
    """主动买卖量"""
    buy_ratio: float = Field(description="主动买入占比，>0.5 买方主导（偏多），<0.5 卖方主导（偏空）")
    timestamp: str = Field(description="时间戳，格式 'MM-DD HH:MM'")

class TopTraderPositionRatio(BaseModel):
    """大户持仓多空比"""
    long_short_ratio: float = Field(description="多空比，反映大户实际持仓规模的多空倾向")
    timestamp: str = Field(description="时间戳，格式 'MM-DD HH:MM'")

class TopTraderAccountRatio(BaseModel):
    """大户账户多空比"""
    long_short_ratio: float = Field(description="多空比，反映大户账户数量的多空倾向")
    timestamp: str = Field(description="时间戳，格式 'MM-DD HH:MM'")


# --- Tools ---

def get_klines(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    interval: Annotated[str, Field(description="K线周期：'1m', '5m', '15m', '1h', '4h', '1d'")],
    limit: Annotated[int, Field(description="K线数量（默认500，最大1500）")] = 500
) -> List[Kline]:
    """
    获取K线（蜡烛图）数据，用于技术分析。
    返回精简的 OHLC 数据（仅关键字段）。
    常用周期：1m, 5m, 15m, 1h, 4h, 1d
    """
    if interval not in VALID_INTERVALS:
        raise ValueError(f"Invalid interval. Valid: {', '.join(VALID_INTERVALS)}")
    _validate_limit(limit, 1500)
    logger.debug(f"Fetching klines for {symbol} interval={interval} limit={limit}")
    try:
        response = client.rest_api.kline_candlestick_data(symbol=symbol, interval=interval, limit=limit)
        raw_klines = response.data()
        return [
            Kline(
                t=_fmt_ts(kline_data[0]),
                h=float(kline_data[2]),
                l=float(kline_data[3]),
                c=float(kline_data[4])
            )
            for kline_data in raw_klines
        ]
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"Failed to get klines for {symbol}: {e}")


def get_long_short_ratio(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    period: Annotated[str, Field(description="统计周期：'5m', '15m', '30m', '1h', '2h', '4h', '6h', '12h', '1d'")],
    limit: Annotated[int, Field(description="数据条数（默认30，最大500）")] = 30
) -> List[LongShortRatio]:
    """
    获取全市场（散户）多空比，反映整体市场持仓倾向。
    >1 表示多头占优，<1 表示空头占优。
    与大户多空比对比可发现背离信号。
    """
    _validate_period(period)
    _validate_limit(limit)
    logger.debug(f"Fetching long/short ratio for {symbol} period={period} limit={limit}")
    try:
        response = client.rest_api.long_short_ratio(symbol=symbol, period=period, limit=limit)
        raw_data = response.data()
        if raw_data and isinstance(raw_data[0], dict):
            return [
                LongShortRatio(
                    long_short_ratio=float(item['longShortRatio']),
                    timestamp=_fmt_ts(item['timestamp'])
                ) for item in raw_data
            ]
        return [
            LongShortRatio(
                long_short_ratio=float(item.long_short_ratio),
                timestamp=_fmt_ts(item.timestamp)
            ) for item in raw_data
        ]
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"Failed to get long/short ratio for {symbol}: {e}")


def get_current_price(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")]
) -> float:
    """
    获取指定交易对的最新价格。
    """
    logger.debug(f"Fetching current price for {symbol}")
    try:
        response = client.rest_api.symbol_price_ticker(symbol=symbol)
        data = response.data()
        if hasattr(data, 'actual_instance'):
            return float(data.actual_instance.price)
        return float(_raw_to_dict(data).get("price", 0))
    except Exception as e:
        raise RuntimeError(f"Failed to get price for {symbol}: {e}")


def get_24hr_ticker(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")]
) -> Ticker24hr:
    """
    获取24小时行情统计，包含涨跌幅、成交量、最高/最低价。
    """
    logger.debug(f"Fetching 24hr ticker for {symbol}")
    try:
        response = client.rest_api.ticker24hr_price_change_statistics(symbol=symbol)
        data = response.data()
        if hasattr(data, 'actual_instance'):
            data = data.actual_instance
        return Ticker24hr(
            symbol=str(data.symbol),
            price_change_percent=float(data.price_change_percent),
            last_price=float(data.last_price),
            volume=float(data.volume),
            high_price=float(data.high_price),
            low_price=float(data.low_price)
        )
    except Exception as e:
        raise RuntimeError(f"Failed to get 24hr ticker for {symbol}: {e}")


def get_funding_rate(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")]
) -> FundingRate:
    """
    获取永续合约当前资金费率。
    每8小时结算一次，正费率表示多头向空头付费（市场偏多），负费率反之。
    极端费率往往预示短期反转。
    """
    logger.debug(f"Fetching funding rate for {symbol}")
    try:
        response = client.rest_api.get_funding_rate_history(symbol=symbol, limit=1)
        data = response.data()
        if not data:
            raise ValueError(f"No funding rate data available for {symbol}")
        latest = data[0]
        return FundingRate(
            symbol=str(latest.symbol),
            funding_rate=float(latest.funding_rate),
            funding_time=_fmt_ts_long(latest.funding_time)
        )
    except Exception as e:
        raise RuntimeError(f"Failed to get funding rate for {symbol}: {e}")


def get_open_interest(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")]
) -> OpenInterest:
    """
    获取当前总持仓量（未平仓合约数）。
    持仓量越高说明市场参与度越大，配合价格变化可判断资金流向。
    """
    logger.debug(f"Fetching open interest for {symbol}")
    try:
        response = client.rest_api.open_interest(symbol=symbol)
        data = response.data()
        return OpenInterest(
            symbol=str(data.symbol),
            open_interest=float(data.open_interest),
            timestamp=_fmt_ts_long(data.time)
        )
    except Exception as e:
        raise RuntimeError(f"Failed to get open interest for {symbol}: {e}")


def get_open_interest_stats(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    period: Annotated[str, Field(description="统计周期：'5m', '15m', '30m', '1h', '2h', '4h', '6h', '12h', '1d'")],
    limit: Annotated[int, Field(description="数据条数（默认30，最大500）")] = 30
) -> List[OpenInterestStats]:
    """
    获取持仓量历史统计，用于追踪资金进出。
    OI上升 + 价格上涨 = 多头加仓（看涨确认）。
    OI上升 + 价格下跌 = 空头加仓（看跌确认）。
    OI下降 = 平仓离场，趋势可能减弱。
    """
    _validate_period(period)
    _validate_limit(limit)
    logger.debug(f"Fetching open interest stats for {symbol} period={period} limit={limit}")
    try:
        response = client.rest_api.open_interest_statistics(symbol=symbol, period=period, limit=limit)
        raw_data = response.data()
        if raw_data and isinstance(raw_data[0], dict):
            return [
                OpenInterestStats(
                    open_interest_value=float(item.get('sumOpenInterestValue', 0)),
                    timestamp=_fmt_ts(item['timestamp'])
                ) for item in raw_data
            ]
        return [
            OpenInterestStats(
                open_interest_value=float(getattr(item, 'sum_open_interest_value', 0)),
                timestamp=_fmt_ts(item.timestamp)
            ) for item in raw_data
        ]
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"Failed to get open interest stats for {symbol}: {e}")


def get_taker_buy_sell_volume(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    period: Annotated[str, Field(description="统计周期：'5m', '15m', '30m', '1h', '2h', '4h', '6h', '12h', '1d'")],
    limit: Annotated[int, Field(description="数据条数（默认30，最大500）")] = 30
) -> List[TakerVolume]:
    """
    获取主动买卖量比率，反映市场主动成交方向。
    buy_ratio > 0.5 表示主动买入占优（多头压力）。
    buy_ratio < 0.5 表示主动卖出占优（空头压力）。
    """
    _validate_period(period)
    _validate_limit(limit)
    logger.debug(f"Fetching taker buy/sell volume for {symbol} period={period} limit={limit}")
    try:
        response = client.rest_api.taker_buy_sell_volume(symbol=symbol, period=period, limit=limit)
        raw_data = response.data()
        results = []
        is_dict = bool(raw_data) and isinstance(raw_data[0], dict)
        for item in raw_data:
            if is_dict:
                buy_vol = float(item.get('buyVol', 0))
                sell_vol = float(item.get('sellVol', 0))
                ts = item.get('timestamp', 0)
            else:
                buy_vol = float(getattr(item, 'buy_vol', 0))
                sell_vol = float(getattr(item, 'sell_vol', 0))
                ts = getattr(item, 'timestamp', 0)
            total = buy_vol + sell_vol
            results.append(TakerVolume(
                buy_ratio=round(buy_vol / total if total > 0 else 0.5, 4),
                timestamp=_fmt_ts(ts)
            ))
        return results
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"Failed to get taker volume for {symbol}: {e}")


def get_top_trader_account_ratio(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    period: Annotated[str, Field(description="统计周期：'5m', '15m', '30m', '1h', '2h', '4h', '6h', '12h', '1d'")],
    limit: Annotated[int, Field(description="数据条数（默认30，最大500）")] = 30
) -> List[TopTraderAccountRatio]:
    """
    获取大户账户多空比，反映做多/做空的大户账户数量比例。
    与持仓多空比配合使用可判断大户内部共识度。
    账户比偏多 + 持仓比偏多 = 大户共识做多。
    """
    _validate_period(period)
    _validate_limit(limit)
    logger.debug(f"Fetching top trader account ratio for {symbol} period={period} limit={limit}")
    try:
        response = client.rest_api.top_trader_long_short_ratio_accounts(symbol=symbol, period=period, limit=limit)
        raw_data = response.data()
        if raw_data and isinstance(raw_data[0], dict):
            return [
                TopTraderAccountRatio(
                    long_short_ratio=float(item.get('longShortRatio', 0)),
                    timestamp=_fmt_ts(item['timestamp'])
                ) for item in raw_data
            ]
        return [
            TopTraderAccountRatio(
                long_short_ratio=float(getattr(item, 'long_short_ratio', 0)),
                timestamp=_fmt_ts(item.timestamp)
            ) for item in raw_data
        ]
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"Failed to get top trader account ratio for {symbol}: {e}")


def get_top_trader_position_ratio(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    period: Annotated[str, Field(description="统计周期：'5m', '15m', '30m', '1h', '2h', '4h', '6h', '12h', '1d'")],
    limit: Annotated[int, Field(description="数据条数（默认30，最大500）")] = 30
) -> List[TopTraderPositionRatio]:
    """
    获取大户持仓多空比，反映大户实际持仓规模的多空倾向。
    比账户多空比更准确，因为它考虑了仓位大小而非仅账户数量。
    是判断"聪明钱"方向的核心指标。
    """
    _validate_period(period)
    _validate_limit(limit)
    logger.debug(f"Fetching top trader position ratio for {symbol} period={period} limit={limit}")
    try:
        response = client.rest_api.top_trader_long_short_ratio_positions(symbol=symbol, period=period, limit=limit)
        raw_data = response.data()
        if raw_data and isinstance(raw_data[0], dict):
            return [
                TopTraderPositionRatio(
                    long_short_ratio=float(item.get('longShortRatio', 0)),
                    timestamp=_fmt_ts(item['timestamp'])
                ) for item in raw_data
            ]
        return [
            TopTraderPositionRatio(
                long_short_ratio=float(getattr(item, 'long_short_ratio', 0)),
                timestamp=_fmt_ts(item.timestamp)
            ) for item in raw_data
        ]
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"Failed to get top trader position ratio for {symbol}: {e}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Binance Futures Market Data MCP Server")
    parser.add_argument("--transport", type=str, choices=["stdio", "sse"], default="stdio")
    parser.add_argument("--host", type=str, default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    mcp = FastMCP("binance-futures-market", host=args.host, port=args.port)
    mcp.tool()(get_current_price)
    mcp.tool()(get_24hr_ticker)
    mcp.tool()(get_klines)
    mcp.tool()(get_long_short_ratio)
    mcp.tool()(get_funding_rate)
    mcp.tool()(get_open_interest)
    mcp.tool()(get_open_interest_stats)
    mcp.tool()(get_taker_buy_sell_volume)
    mcp.tool()(get_top_trader_account_ratio)
    mcp.tool()(get_top_trader_position_ratio)

    if args.transport == "sse":
        logger.info(f"Starting MCP server in SSE mode on {args.host}:{args.port}")
        mcp.run(transport="sse")
    else:
        logger.info("Starting MCP server in stdio mode")
        mcp.run()
