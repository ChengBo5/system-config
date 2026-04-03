import logging
from typing import List, Optional, Annotated
from pydantic import BaseModel, Field
from mcp.server.fastmcp import FastMCP

from binance_sdk_derivatives_trading_usds_futures.rest_api.models.enums import (
    NewOrderSideEnum,
    NewOrderTimeInForceEnum,
    NewOrderPositionSideEnum,
    NewAlgoOrderSideEnum,
    NewAlgoOrderPositionSideEnum,
    NewAlgoOrderTimeInForceEnum,
    NewAlgoOrderWorkingTypeEnum,
)
from _common import (
    client,
    _raw_to_dict, _get_attr,
)

logger = logging.getLogger(__name__)


# --- Pydantic Models ---

class FuturesAccountBalance(BaseModel):
    """期货账户余额"""
    asset: str = Field(description="资产名称，如 USDT")
    balance: float = Field(description="总余额")
    available_balance: float = Field(description="可用余额")
    unrealized_profit: float = Field(default=0.0, description="全仓未实现盈亏")
    model_config = {"extra": "ignore"}

class PositionInfo(BaseModel):
    """持仓信息"""
    symbol: str = Field(description="交易对，如 BTCUSDT")
    direction: str = Field(description="持仓方向：'long'（多头）或 'short'（空头）")
    entry_price: float = Field(description="开仓均价")
    quantity: float = Field(description="持仓数量（正数多头，负数空头）")
    mark_price: float = Field(description="标记价格")
    unrealized_profit: float = Field(description="未实现盈亏")
    leverage: int = Field(description="实际杠杆倍数")

class OpenOrderInfo(BaseModel):
    """挂单信息"""
    order_id: str = Field(description="订单 ID")
    symbol: str = Field(description="交易对")
    side: str = Field(description="方向：BUY / SELL")
    order_type: str = Field(description="订单类型：LIMIT / MARKET 等")
    price: Optional[float] = Field(default=None, description="委托价格（市价单为空）")
    quantity: Optional[float] = Field(default=None, description="委托数量")
    status: str = Field(description="订单状态：NEW / PARTIALLY_FILLED 等")

class NewOrderResult(BaseModel):
    """下单结果"""
    order_id: int = Field(description="订单 ID")
    symbol: str = Field(description="交易对")
    side: str = Field(description="方向：BUY / SELL")
    type: str = Field(description="订单类型")
    quantity: Optional[float] = Field(default=None, description="委托数量")
    price: Optional[float] = Field(default=None, description="委托价格")
    status: str = Field(description="订单状态")

class CancelOrderResult(BaseModel):
    """撤单结果"""
    order_id: int = Field(description="被撤销的订单 ID")
    symbol: str = Field(description="交易对")
    status: str = Field(description="撤单后状态，通常为 CANCELED")

class LeverageResult(BaseModel):
    """杠杆设置结果"""
    symbol: str = Field(description="交易对")
    leverage: int = Field(description="设置后的杠杆倍数")


# --- 账户查询工具 ---

def get_balance(
    placeholder: Annotated[str, Field(description="占位参数，传任意字符串即可，如 'ok'")],
) -> FuturesAccountBalance:
    """
    获取期货账户USDT余额。
    只返回USDT资产信息。
    """
    try:
        response = client.rest_api.futures_account_balance_v3()
        data = response.data()
        raw_list = data if isinstance(data, list) else [data]
        for item in raw_list:
            item_dict = _raw_to_dict(item)
            if item_dict.get("asset") == "USDT":
                return FuturesAccountBalance(
                    asset="USDT",
                    balance=float(item_dict.get("balance", 0)),
                    available_balance=float(item_dict.get("availableBalance", 0)),
                    unrealized_profit=float(item_dict.get("crossUnPnl", 0))
                )
        raise RuntimeError("未找到USDT资产")
    except Exception as e:
        raise RuntimeError(f"获取余额失败: {e}")


def get_positions(
    placeholder: Annotated[str, Field(description="占位参数，传任意字符串即可，如 'ok'")],
) -> List[PositionInfo]:
    """
    获取当前期货持仓。
    只返回非零持仓。
    """
    try:
        response = client.rest_api.position_information_v3()
        data = response.data()
        positions = []
        for pos_data in data:
            position_amt = float(_get_attr(pos_data, 'position_amt', 0))
            if position_amt == 0:
                continue
            notional = float(_get_attr(pos_data, 'notional', 0))
            initial_margin = float(_get_attr(pos_data, 'initial_margin', 0))
            leverage = round(abs(notional / initial_margin)) if initial_margin != 0 else 0
            positions.append(PositionInfo(
                symbol=str(_get_attr(pos_data, 'symbol', '')),
                direction="long" if position_amt > 0 else "short",
                entry_price=float(_get_attr(pos_data, 'entry_price', 0)),
                quantity=position_amt,
                mark_price=float(_get_attr(pos_data, 'mark_price', 0)),
                unrealized_profit=float(_get_attr(pos_data, 'un_realized_profit', 0)),
                leverage=leverage
            ))
        return positions
    except Exception as e:
        raise RuntimeError(f"获取持仓信息失败: {e}")


def get_open_orders(
    placeholder: Annotated[str, Field(description="占位参数，传任意字符串即可，如 'ok'")],
    symbol: Annotated[Optional[str], Field(description="交易对，不传则返回全部")] = None,
) -> List[OpenOrderInfo]:
    """获取当前普通挂单。不含条件单。"""
    try:
        response = client.rest_api.current_all_open_orders(symbol=symbol)
        data = response.data()
        if not data:
            return []
        orders = []
        for order_data in data:
            d = _raw_to_dict(order_data)
            orders.append(OpenOrderInfo(
                order_id=str(d.get("orderId", "")),
                symbol=d.get("symbol", ""),
                side=d.get("side", ""),
                order_type=d.get("type", ""),
                price=float(d["price"]) if d.get("price") else None,
                quantity=float(d["origQty"]) if d.get("origQty") else None,
                status=d.get("status", "")
            ))
        return orders
    except Exception as e:
        raise RuntimeError(f"获取挂单失败: {e}")


# --- 交易工具（写操作，请谨慎使用） ---

def set_leverage(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    leverage: Annotated[int, Field(description="杠杆倍数（1-125）")]
) -> LeverageResult:
    """设置指定交易对的杠杆倍数。"""
    try:
        if leverage < 1 or leverage > 125:
            raise ValueError("杠杆倍数必须在 1-125 之间")
        if leverage > 20:
            logger.warning(f"检测到高杠杆 {leverage}x，风险等级：高")
        response = client.rest_api.change_initial_leverage(symbol=symbol, leverage=leverage)
        data = response.data()
        return LeverageResult(
            symbol=str(_get_attr(data, 'symbol', symbol)),
            leverage=int(_get_attr(data, 'leverage', leverage))
        )
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"设置 {symbol} 杠杆失败: {e}")


def place_order(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    side: Annotated[str, Field(description="'BUY' 开多/平空，'SELL' 开空/平多")],
    order_type: Annotated[str, Field(description="'MARKET' 或 'LIMIT'。条件止损用 place_algo_order")],
    quantity: Annotated[Optional[float], Field(description="下单数量（基础资产单位）")] = None,
    price: Annotated[Optional[float], Field(description="限价价格，LIMIT 时必填")] = None,
    position_side: Annotated[Optional[str], Field(description="'LONG'/'SHORT'（双向模式）或不填（单向模式）")] = None,
    time_in_force: Annotated[Optional[str], Field(description="限价单有效期：'GTC'(默认)/'IOC'/'FOK'")] = None,
    reduce_only: Annotated[Optional[str], Field(description="'true' 仅减仓")] = None,
) -> NewOrderResult:
    """
    下市价单或限价单。用 cancel_order 撤销。
    警告：真实交易，请核对参数。
    """
    try:
        if order_type.upper() not in ("MARKET", "LIMIT"):
            raise ValueError("order_type 必须为 'MARKET' 或 'LIMIT'")
        kwargs = {
            "symbol": symbol,
            "side": NewOrderSideEnum(side.upper()),
            "type": order_type.upper(),
        }
        if quantity is not None:
            kwargs["quantity"] = quantity
        if price is not None:
            kwargs["price"] = price
        if position_side is not None:
            kwargs["position_side"] = NewOrderPositionSideEnum(position_side.upper())
        if time_in_force is not None:
            kwargs["time_in_force"] = NewOrderTimeInForceEnum(time_in_force.upper())
        elif order_type.upper() == "LIMIT":
            kwargs["time_in_force"] = NewOrderTimeInForceEnum("GTC")
        if reduce_only is not None:
            kwargs["reduce_only"] = reduce_only
        logger.info(f"正在下单: {kwargs}")
        response = client.rest_api.new_order(**kwargs)
        data = response.data()
        d = _raw_to_dict(data)
        return NewOrderResult(
            order_id=int(d.get("orderId", 0)),
            symbol=d.get("symbol", symbol),
            side=d.get("side", side),
            type=d.get("type", order_type),
            quantity=float(d["origQty"]) if d.get("origQty") else quantity,
            price=float(d["price"]) if d.get("price") else price,
            status=d.get("status", "NEW")
        )
    except Exception as e:
        raise RuntimeError(f"{symbol} 下单失败: {e}")


def cancel_order(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    order_id: Annotated[Optional[int], Field(description="订单 ID，与 client_order_id 二选一")] = None,
    client_order_id: Annotated[Optional[str], Field(description="客户端订单 ID，与 order_id 二选一")] = None,
) -> CancelOrderResult:
    """撤销普通挂单。条件单用 cancel_algo_order。"""
    try:
        if order_id is None and client_order_id is None:
            raise ValueError("必须提供 order_id 或 client_order_id 其中之一")
        logger.info(f"正在撤单: {symbol} order_id={order_id} client_order_id={client_order_id}")
        kwargs = {"symbol": symbol}
        if order_id is not None:
            kwargs["order_id"] = order_id
        if client_order_id is not None:
            kwargs["orig_client_order_id"] = client_order_id
        response = client.rest_api.cancel_order(**kwargs)
        data = response.data()
        d = _raw_to_dict(data)
        return CancelOrderResult(
            order_id=int(d.get("orderId", order_id or 0)),
            symbol=d.get("symbol", symbol),
            status=d.get("status", "CANCELED")
        )
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"撤销 {symbol} 订单失败: {e}")


def cancel_algo_order(
    placeholder: Annotated[str, Field(description="占位参数，传任意字符串即可，如 'ok'")],
    algo_id: Annotated[Optional[int], Field(description="条件单 ID，与 client_algo_id 二选一")] = None,
    client_algo_id: Annotated[Optional[str], Field(description="客户端条件单 ID，与 algo_id 二选一")] = None,
) -> dict:
    """撤销指定条件单。普通单用 cancel_order。"""
    try:
        if algo_id is None and client_algo_id is None:
            raise ValueError("必须提供 algo_id 或 client_algo_id 其中之一")
        logger.info(f"正在撤销条件单: algo_id={algo_id} client_algo_id={client_algo_id}")
        kwargs = {}
        if algo_id is not None:
            kwargs["algo_id"] = algo_id
        if client_algo_id is not None:
            kwargs["client_algo_id"] = client_algo_id
        response = client.rest_api.cancel_algo_order(**kwargs)
        data = response.data()
        d = _raw_to_dict(data)
        return {
            "algo_id": d.get("algoId", algo_id),
            "status": d.get("status", "CANCELED"),
            "code": d.get("code", 200),
            "message": d.get("msg", "success"),
        }
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"撤销条件单失败: {e}")


def cancel_all_algo_orders(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")]
) -> dict:
    """批量撤销指定交易对的所有条件单。不影响普通单。"""
    try:
        logger.info(f"正在批量撤销 {symbol} 的所有条件单")
        response = client.rest_api.cancel_all_algo_open_orders(symbol=symbol)
        data = response.data()
        d = _raw_to_dict(data)
        return {
            "symbol": symbol,
            "code": d.get("code", 200),
            "message": d.get("msg", "success"),
        }
    except Exception as e:
        raise RuntimeError(f"批量撤销 {symbol} 条件单失败: {e}")


def cancel_all_orders(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")]
) -> dict:
    """批量撤销指定交易对的所有普通挂单。不影响条件单。"""
    try:
        logger.info(f"正在批量撤销 {symbol} 的所有普通挂单")
        response = client.rest_api.cancel_all_open_orders(symbol=symbol)
        data = response.data()
        d = _raw_to_dict(data)
        return {
            "symbol": symbol,
            "code": d.get("code", 200),
            "message": d.get("msg", "success"),
        }
    except Exception as e:
        raise RuntimeError(f"批量撤销 {symbol} 普通挂单失败: {e}")


def place_algo_order(
    symbol: Annotated[str, Field(description="交易对，如 'BTCUSDT'")],
    side: Annotated[str, Field(description="'BUY' 或 'SELL'。多头止损/止盈用 'SELL'，空头用 'BUY'")],
    algo_type: Annotated[str, Field(description="'STOP_MARKET'(止损市价) / 'TAKE_PROFIT_MARKET'(止盈市价) / 'STOP'(止损限价) / 'TAKE_PROFIT'(止盈限价) / 'TRAILING_STOP_MARKET'(追踪止损)")],
    quantity: Annotated[float, Field(description="下单数量（基础资产单位）")],
    trigger_price: Annotated[Optional[float], Field(description="触发价格")] = None,
    price: Annotated[Optional[float], Field(description="限价价格，仅 STOP/TAKE_PROFIT 类型使用")] = None,
    position_side: Annotated[Optional[str], Field(description="'LONG'/'SHORT'（双向模式）或不填（单向模式）")] = None,
    working_type: Annotated[Optional[str], Field(description="'MARK_PRICE'(推荐) 或 'CONTRACT_PRICE'(默认)")] = None,
    reduce_only: Annotated[Optional[str], Field(description="'true' 仅减仓，止损止盈建议设为 true")] = None,
    time_in_force: Annotated[Optional[str], Field(description="限价单有效期：'GTC'/'IOC'/'FOK'，仅限价类型使用")] = None,
) -> dict:
    """
    下条件单（止损/止盈），触发价到达后自动执行。用 cancel_algo_order 撤销。
    条件单不会出现在 get_open_orders 中。
    警告：真实交易，请确认触发价方向与持仓匹配。
    """
    try:
        kwargs = {
            "symbol": symbol,
            "side": NewAlgoOrderSideEnum(side.upper()),
            "algo_type": "CONDITIONAL",
            "type": algo_type.upper(),
            "quantity": quantity,
        }
        if trigger_price is not None:
            kwargs["trigger_price"] = trigger_price
        if price is not None:
            kwargs["price"] = price
        if position_side is not None:
            kwargs["position_side"] = NewAlgoOrderPositionSideEnum(position_side.upper())
        if working_type is not None:
            kwargs["working_type"] = NewAlgoOrderWorkingTypeEnum(working_type.upper())
        if reduce_only is not None:
            kwargs["reduce_only"] = reduce_only
        if time_in_force is not None:
            kwargs["time_in_force"] = NewAlgoOrderTimeInForceEnum(time_in_force.upper())
        logger.info(f"正在下条件单: {kwargs}")
        response = client.rest_api.new_algo_order(**kwargs)
        data = response.data()
        d = _raw_to_dict(data)
        return {
            "algo_id": d.get("algoId") or d.get("orderId", 0),
            "symbol": d.get("symbol", symbol),
            "side": d.get("side", side),
            "algo_type": algo_type.upper(),
            "quantity": quantity,
            "trigger_price": trigger_price,
            "price": price,
            "status": d.get("status", "NEW"),
        }
    except Exception as e:
        raise RuntimeError(f"{symbol} 条件单下单失败: {e}")


# --- 服务启动入口 ---

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Binance 合约账户 MCP 服务")
    parser.add_argument("--transport", type=str, choices=["stdio", "sse"], default="stdio")
    parser.add_argument("--host", type=str, default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8001)
    args = parser.parse_args()

    mcp = FastMCP("binance-futures-account", host=args.host, port=args.port)
    mcp.tool()(get_balance)
    mcp.tool()(get_positions)
    mcp.tool()(get_open_orders)
    mcp.tool()(set_leverage)
    mcp.tool()(place_order)
    mcp.tool()(place_algo_order)
    mcp.tool()(cancel_order)
    mcp.tool()(cancel_algo_order)
    mcp.tool()(cancel_all_algo_orders)
    mcp.tool()(cancel_all_orders)

    if args.transport == "sse":
        logger.info(f"MCP 服务以 SSE 模式启动: {args.host}:{args.port}")
        mcp.run(transport="sse")
    else:
        logger.info("MCP 服务以 stdio 模式启动")
        mcp.run()
