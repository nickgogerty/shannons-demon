"""Shannon's demon: a constant-rebalanced portfolio (CRP).

The portfolio holds fixed target weights and restores them on a schedule.
Growth comes from volatility. See docs/shannons_demon_llm_spec.md for the
definitions, math and application procedure.
"""
from __future__ import annotations

import numpy as np


def shannon_demon(prices, b, k=1, cost=0.0, w0=1.0):
    """Simulate a constant-rebalanced portfolio.

    prices: (T+1, n) asset prices. Include a constant column for cash.
    b:      (n,) target weights, nonnegative, summing to 1.
    k:      rebalance every k periods.
    cost:   proportional cost per unit of value traded (one way).
    w0:     starting wealth.

    Returns (wealth, turnover). wealth has length T+1. turnover is total
    traded value as a multiple of wealth at each rebalance, summed over time.
    """
    prices = np.asarray(prices, float)
    b = np.asarray(b, float)
    assert np.isclose(b.sum(), 1.0) and (b >= 0).all(), "weights must be nonnegative and sum to 1"
    x = prices[1:] / prices[:-1]  # price relatives, shape (T, n)
    holdings = w0 * b
    wealth = [w0]
    turnover = 0.0
    for t, xt in enumerate(x, start=1):
        holdings = holdings * xt  # let positions drift with prices
        total = holdings.sum()
        if t % k == 0:  # scheduled rebalance
            target = total * b
            traded = np.abs(target - holdings).sum()
            turnover += traded / total
            total -= cost * traded  # pay costs on value traded
            holdings = total * b  # restore target weights
        wealth.append(holdings.sum())
    return np.array(wealth), turnover


def buy_and_hold(prices, b, w0=1.0):
    """Wealth path of buying weights b at the start and never rebalancing."""
    prices = np.asarray(prices, float)
    b = np.asarray(b, float)
    return w0 * (prices / prices[0]) @ b


def summary(wealth, periods_per_year=252):
    """Annualised growth, volatility, Sharpe ratio (risk-free rate 0) and max drawdown."""
    wealth = np.asarray(wealth, float)
    r = wealth[1:] / wealth[:-1] - 1
    years = (len(wealth) - 1) / periods_per_year
    sd = r.std(ddof=1)
    return {
        "cagr": (wealth[-1] / wealth[0]) ** (1 / years) - 1,
        "vol": sd * np.sqrt(periods_per_year),
        "sharpe": (r.mean() / sd * np.sqrt(periods_per_year)) if sd > 0 else float("nan"),
        "max_drawdown": (wealth / np.maximum.accumulate(wealth) - 1).min(),
    }


def alternating_prices(periods=20):
    """Worked example: a stock that doubles, then halves, alternating. Cash stays at 1."""
    stock = [1.0]
    for t in range(periods):
        stock.append(stock[-1] * (2.0 if t % 2 == 0 else 0.5))
    return np.column_stack([np.array(stock), np.ones(periods + 1)])


if __name__ == "__main__":
    p = alternating_prices(20)
    w, to = shannon_demon(p, [0.5, 0.5])
    bh = buy_and_hold(p, [1.0, 0.0])
    print(f"50/50 demon at t=20:        {w[-1]:.4f}")
    print(f"Stock buy-and-hold at t=20: {bh[-1]:.4f}")
    print(f"Demon growth per period:    {w[-1] ** (1 / 20):.4f}")
    print(f"Turnover (x wealth):        {to:.3f}")
