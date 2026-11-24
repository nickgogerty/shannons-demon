"""Acceptance tests from docs/shannons_demon_llm_spec.md, section 5."""
import numpy as np
import pytest

from shannons_demon import alternating_prices, buy_and_hold, shannon_demon


def test_worked_example_wealth_at_t20():
    w, _ = shannon_demon(alternating_prices(20), [0.5, 0.5])
    assert abs(w[-1] - 3.2473) < 0.001


def test_worked_example_per_period_growth():
    w, _ = shannon_demon(alternating_prices(20), [0.5, 0.5])
    assert abs((w[-1] / w[0]) ** (1 / 20) - 1.0607) < 0.0005


def test_stock_buy_and_hold_ends_at_one():
    bh = buy_and_hold(alternating_prices(20), [1.0, 0.0])
    assert abs(bh[-1] - 1.0) < 1e-12


def test_optimal_risky_weight_is_one_half():
    p = alternating_prices(20)
    grid = np.linspace(0.0, 1.0, 101)
    finals = [shannon_demon(p, [f, 1 - f])[0][-1] for f in grid]
    assert int(np.argmax(finals)) == 50  # index 50 is f = 0.5


def test_random_path_growth_near_theory():
    rng = np.random.default_rng(0)
    T = 2000
    steps = np.where(rng.random(T) < 0.5, 2.0, 0.5)
    p = np.column_stack([np.concatenate([[1.0], np.cumprod(steps)]), np.ones(T + 1)])
    w, _ = shannon_demon(p, [0.5, 0.5])
    # Sampling noise over 2,000 periods; the reference run gave about 1.0632.
    assert abs((w[-1] / w[0]) ** (1 / T) - 1.0607) < 0.005


def test_costs_reduce_growth():
    rng = np.random.default_rng(1)
    T = 500
    steps = np.where(rng.random(T) < 0.5, 2.0, 0.5)
    p = np.column_stack([np.concatenate([[1.0], np.cumprod(steps)]), np.ones(T + 1)])
    free, _ = shannon_demon(p, [0.5, 0.5], cost=0.0)
    paid, _ = shannon_demon(p, [0.5, 0.5], cost=0.001)
    assert paid[-1] < free[-1]


def test_rebalance_interval_length():
    w, _ = shannon_demon(alternating_prices(20), [0.5, 0.5], k=5)
    assert len(w) == 21


def test_invalid_weights_rejected():
    with pytest.raises(AssertionError):
        shannon_demon(alternating_prices(5), [0.7, 0.7])
