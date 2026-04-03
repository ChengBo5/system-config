import os
import logging
from datetime import datetime
from urllib.parse import urlparse

from dotenv import load_dotenv
from binance_sdk_derivatives_trading_usds_futures import (
    DerivativesTradingUsdsFutures,
    DERIVATIVES_TRADING_USDS_FUTURES_REST_API_TESTNET_URL,
)
from binance_common.configuration import ConfigurationRestAPI

# 日志配置（各模块自行获取 logger = logging.getLogger(__name__)）
logging.basicConfig(level=logging.INFO)

# 加载环境变量
load_dotenv()

# REST API 配置
configuration_rest_api = ConfigurationRestAPI(
    api_key=os.getenv("API_KEY", ""),
    api_secret=os.getenv("API_SECRET", ""),
    timeout=3000
)

if os.getenv("TESTNET", "").lower() == "true":
    configuration_rest_api.base_path = DERIVATIVES_TRADING_USDS_FUTURES_REST_API_TESTNET_URL
    logging.info("Using TESTNET REST URL")
else:
    logging.info("Using PRODUCTION REST URL")

if os.getenv("MCP_HTTP_PROXY"):
    proxy_str = os.getenv("MCP_HTTP_PROXY")
    try:
        parsed = urlparse(proxy_str)
        configuration_rest_api.proxy = {
            "protocol": parsed.scheme,
            "host": parsed.hostname,
            "port": parsed.port
        }
        logging.info(f"Using HTTP proxy: {proxy_str}")
    except Exception as e:
        logging.warning(f"Failed to parse MCP_HTTP_PROXY: {e}")

client = DerivativesTradingUsdsFutures(config_rest_api=configuration_rest_api)

# --- 常量 ---

VALID_PERIODS = ['5m', '15m', '30m', '1h', '2h', '4h', '6h', '12h', '1d']
VALID_INTERVALS = ['1m', '3m', '5m', '15m', '30m', '1h', '2h', '4h', '6h', '8h', '12h', '1d', '3d', '1w', '1M']

# --- 工具函数 ---

def _raw_to_dict(data) -> dict:
    """将 SDK 响应对象转换为 dict，兼容多种返回格式。"""
    if hasattr(data, 'to_dict'):
        return data.to_dict()
    elif isinstance(data, dict):
        return data
    else:
        return {k: v for k, v in data.__dict__.items() if not k.startswith('_')}


def _get_attr(obj, key, default=None):
    """从对象或字典中安全获取属性值。"""
    if isinstance(obj, dict):
        return obj.get(key, default)
    return getattr(obj, key, default)


def _fmt_ts(ts_ms) -> str:
    """毫秒时间戳格式化为 'MM-DD HH:MM'。"""
    return datetime.fromtimestamp(int(ts_ms) / 1000).strftime('%m-%d %H:%M')


def _fmt_ts_long(ts_ms) -> str:
    """毫秒时间戳格式化为 'YYYY-MM-DD HH:MM:SS'。"""
    return datetime.fromtimestamp(int(ts_ms) / 1000).strftime('%Y-%m-%d %H:%M:%S')


def _validate_period(period: str) -> None:
    if period not in VALID_PERIODS:
        raise ValueError(f"Invalid period. Valid: {', '.join(VALID_PERIODS)}")


def _validate_limit(limit: int, max_limit: int = 500) -> None:
    if limit <= 0 or limit > max_limit:
        raise ValueError(f"limit must be between 1 and {max_limit}")
