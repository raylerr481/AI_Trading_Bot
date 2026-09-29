# Bitey Trading Optimization Loop

## Purpose

Bitey IA can act as the research/orchestration layer for the AI Trading Bot without receiving broker execution authority.

The loop is deliberately staged:

1. **Baseline** — preserve the current EA and record its backtest metrics.
2. **Hypothesis** — Bitey proposes one bounded change.
3. **Candidate** — create a new EA version; never overwrite the baseline.
4. **Backtest** — run the candidate on the same data and risk settings.
5. **Validation** — compare net profit, profit factor, expectancy, drawdown, win rate, trade count and losing streak.
6. **Out-of-sample** — test promising candidates on a different period before demo use.
7. **Demo** — only candidates that pass validation may move to demo.
8. **Live** — requires explicit human approval; external AI never gets direct order authority.

## Current baseline

The recorded v1.33 baseline is:

- 1,481 historical bars
- 2,807,486 modeled ticks/bar states reported by MT4
- 90% modeling quality
- 0 chart mismatch errors
- Initial deposit: 1,000
- Net profit: -12.87
- Profit factor: 0.79
- Expected payoff: -0.31
- Maximum drawdown: 2.23%
- 41 trades
- 14 winners / 27 losers
- Win rate: 34.15%
- Maximum losing streak: 9

These figures are a baseline, not a claim about future performance.

## AI roles

Bitey remains the orchestrator. An external model may provide a bounded second opinion for:

- code review;
- backtest-result analysis;
- hypothesis generation;
- strategy/regime analysis.

An external model must not directly modify production code, place orders, or bypass the MT4 Risk Gate.

## Promotion rule

A candidate is not accepted because one metric improved. It must be compared against the unchanged baseline and checked for:

- sufficient trade count;
- drawdown;
- profit factor;
- expectancy;
- losing streak;
- robustness on another period;
- absence of obvious overfitting.

The optimization process must prefer small, explainable changes over large parameter searches.

## Execution boundary

The authoritative path remains:

MT4 snapshot -> Bitey analysis -> local Risk Gate -> MT4 execution.

Bitey and external models remain outside broker execution.
