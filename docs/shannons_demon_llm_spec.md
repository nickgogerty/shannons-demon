# Shannon's demon: build-and-apply specification

Audience: a language model asked to build a simulator of Shannon's demon, or to apply it to real or synthetic price data.

## 1. BLUF

- Shannon's demon is a constant-rebalanced portfolio (CRP). It holds fixed target weights across assets and restores those weights on a schedule.
- It earns growth from volatility, not from trend. The gain is the gap between the mix's arithmetic return and its geometric return.
- It works when assets are volatile, not perfectly correlated, and range-bound. It loses when one asset trends persistently, and costs erode it.
- Build it as a short function. Pass the acceptance test in section 5 before using any real data.

## 2. Definitions

- Assets: n risky assets, plus optionally cash (a price column that stays constant).
- Price relative x_t: the vector of gross returns for period t, where x_(i,t) = P_(i,t) / P_(i,t-1).
- Target weights b: nonnegative, summing to 1. No shorting or leverage unless the task says so.
- Rebalance rule: every k periods, or whenever a weight drifts beyond a set band.
- Wealth W_t: total portfolio value at time t.

## 3. Core math

Demon wealth (rebalanced every period):

    W_T = W_0 × product over t = 1..T of (b · x_t)

Buy-and-hold wealth for the same weights (no rebalancing):

    W_T(BH) = W_0 × sum over i of b_i × product over t = 1..T of x_(i,t)

Long-run growth rate of the demon, for independent and identically distributed returns:

    G(b) = E[ log(b · X) ]

The best fixed b maximises G(b). That is the log-optimal, or Kelly-type, portfolio. In practice b is chosen in advance and held fixed.

Two-asset small-return approximation (risky weight f, cash return 0):

    G(f) ≈ f·μ − ½·f²·σ²

Here μ and σ² are the mean and variance of the risky asset's simple return per period. The optimum is f* ≈ μ/σ². This understates the optimum when moves are large.

Volatility harvest (rebalancing bonus) per period, small-return approximation:

    bonus ≈ ½ × ( sum over i of b_i·σ_i² − bᵀΣb )

Σ is the covariance matrix of simple returns. The bonus is positive only when assets are not perfectly correlated. It overstates the gain for large moves. Check it against section 5 before relying on it.

## 4. Build: algorithm and reference code

Inputs: price matrix P with shape (T+1, n), target weights b, rebalance interval k (1 = every period), proportional cost c per unit of value traded, starting wealth W_0.

Steps:

1. Compute price relatives x_t = P_t / P_(t-1).
2. Set starting holdings to W_0 × b_i for each asset.
3. For each period t:
   a. Let holdings drift: holdings_i ← holdings_i × x_(i,t).
   b. Compute total wealth.
   c. On a rebalance date: target_i = total × b_i; traded = sum of |target_i − holdings_i|; total ← total − c × traded; holdings_i ← total × b_i.
   d. Record wealth as the sum of holdings.
4. Return the wealth path and turnover. Report turnover as a fraction of wealth, not in raw currency units, or long runs overflow in the report.
5. Compute the metrics in section 8 from the wealth path.

Reference code (tested; the acceptance test in section 5 passes with it):

```python
import numpy as np

def shannon_demon(prices, b, k=1, cost=0.0, w0=1.0):
    """prices: (T+1, n) asset prices; include a constant column for cash.
    b: (n,) target weights, nonnegative, summing to 1.
    k: rebalance every k periods. cost: proportional cost per unit of value traded.
    Returns the wealth path and total turnover as a multiple of starting wealth."""
    prices = np.asarray(prices, float)
    b = np.asarray(b, float)
    assert np.isclose(b.sum(), 1.0) and (b >= 0).all(), "weights must be nonnegative and sum to 1"
    x = prices[1:] / prices[:-1]              # price relatives, shape (T, n)
    holdings = w0 * b
    wealth = [w0]
    turnover = 0.0
    for t, xt in enumerate(x, start=1):
        holdings = holdings * xt              # let positions drift with prices
        total = holdings.sum()
        if t % k == 0:                        # scheduled rebalance
            target = total * b
            traded = np.abs(target - holdings).sum()
            turnover += traded / total        # fraction of wealth traded
            total -= cost * traded            # pay costs on value traded
            holdings = total * b              # restore target weights
        wealth.append(holdings.sum())
    return np.array(wealth), turnover
```

## 5. Acceptance test (run before any real data)

Example: one risky asset doubles, then halves, alternating each period. Cash stays at 1.0. Weights 50/50, rebalance every period, no cost.

| Quantity | Expected value |
|---|---|
| Stock arithmetic mean return per period | 1.25 (+25%) |
| Stock geometric growth per period | 1.00 (0%) |
| 50/50 demon growth per period | square root of (1.5 × 0.75) = 1.0607 |
| Alternating path, t = 20: demon wealth | 3.2473 |
| Alternating path, t = 20: stock buy-and-hold | 1.0 |
| Optimal risky weight in this example | 0.5 |

Pass criteria: the demon's wealth at t = 20 is within 0.001 of 3.2473, and its per-period growth is within 0.0005 of 1.0607. A random 2× / ½× path of 2,000 periods should give growth close to 1.0607. A larger gap points to a bug or to sampling noise. In the reference run the gap was about 0.0025, which is sampling noise.

## 6. Apply: procedure for real or synthetic data

1. Define the universe and benchmarks: each asset alone, buy-and-hold of the same weights, and cash.
2. Set data rules. Use only prices known at each decision date (no look-ahead). Adjust for splits and dividends. Include assets that later failed, or state plainly that you did not.
3. Choose weights. Default: equal weight across risky assets, which avoids estimation error. Alternative: maximise mean log(b · x) on a training window, shrink toward equal weight, and cap each weight between 0 and 1.
4. Choose the rebalance rule. Test every period, weekly, monthly, quarterly, and a drift band (for example ±5 percentage points). Pick the rule that maximises net growth after costs, not gross growth.
5. Set costs. Use realistic bid-ask spread, commissions, and slippage, plus tax on realised gains in taxable accounts. Run sensitivity at 0, 5, 10, and 20 basis points one way.
6. Diagnose before backtesting. Estimate volatility, pairwise correlation, and trend (for example, the autocorrelation of each asset's returns). The demon needs volatility and low correlation. A persistent trend predicts loss.
7. Validate. Use walk-forward out-of-sample tests. Report the gap to buy-and-hold for each window. Block-bootstrap the returns to get a range for the gap.
8. Example stop rule: pause or reduce the strategy if the net gap to buy-and-hold is negative over a trailing 12-month window, or if one asset has trended persistently over that window.

## 7. When it works and when it fails

Works: volatile assets without a persistent trend; low or negative correlation; liquid assets; low costs; rebalancing often enough to keep drift small.

Fails: a one-way trend, because the demon keeps selling the winner; highly correlated assets, because there is little volatility to harvest; high costs or illiquidity; leverage, because log growth turns negative when leverage is too high, and margin calls can force sales.

The demon creates no return from nothing. Volatility pays for it. Its gain is the mirror of the drag that volatility puts on buy-and-hold.

## 8. Output contract

When asked to build:

- The function in section 4, with its docstring.
- The acceptance test in section 5, run, with the actual numbers reported.
- A list of the assumptions the code makes.

When asked to apply:

- Data source, date range, universe, and rebalance frequency.
- Weights, rebalance rule, and costs, with how each was chosen and which data window was used.
- Results net of costs: annual growth, volatility, Sharpe ratio, maximum drawdown, annual turnover, and the gap to buy-and-hold.
- Out-of-sample results labelled as out-of-sample. In-sample results labelled as in-sample.
- A plain statement of what the result does not show. This is not investment advice.

## 9. Pitfalls checklist

- Look-ahead: choosing weights or rules with data from after the decision date.
- Survivorship: a universe made only of assets that still exist today.
- Frictionless backtests: ignoring costs and taxes.
- Mixing arithmetic and geometric averages. Judge a compounding strategy by geometric growth.
- Assuming continuous rebalancing. Real rebalancing is discrete.
- Treating the alternating example as evidence. It is a teaching case.
- Ignoring the costs and margin rules of leverage.

## 10. Terms

- Constant-rebalanced portfolio (CRP): the formal name for the demon, from growth-optimal portfolio theory.
- Price relative: the ratio of a price to its prior price.
- Volatility harvest: the growth gained by rebalancing volatile assets.
- Drift: the change in portfolio weights between rebalances.
- Turnover: value traded per period, as a share of wealth.
- Log-optimal: the weights that maximise expected log wealth growth.
