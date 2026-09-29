# Adaptive Strategy Spectrum

Bitey IA v1.34 adds a research layer inspired by the supplied eight-strategy/radar workflow, but removes unsupported claims such as guaranteed profitability or a universally winning strategy.

## Implemented in the repository

- 8 simultaneous historical strategy audits
- strict TP/SL resolution window
- unresolved simulations excluded from win rate
- strategy selection from the same symbol/timeframe/history/risk assumptions
- regime detection
- Hurst estimate
- real-time account and execution metrics
- Bitey IA read-only advisory connection
- AI_ASSIST and AI_FILTER modes
- MT4 local Risk Gate remains authoritative
- demo-only safety switch by default

## Eight models

Trend following, mean reversion, momentum, volatility breakout, session bias, divergence proxy, strict range, and fractal/HTF confirmation.

## Statistical discipline

The audit reports trades, win rate, profit factor, expectancy, average win/loss, payoff, maximum drawdown, and maximum consecutive losses.

The selector uses these metrics to create a bounded research score. It is not a profitability guarantee and it is not a substitute for walk-forward or out-of-sample validation.

## Adaptation loop

market snapshot -> regime -> 8-strategy audit -> candidate selection -> Bitey IA advisory -> local Risk Gate -> demo execution

When the regime changes, the EA refreshes the audit after the configured number of bars. The strategy can therefore change because the measured evidence changed rather than because a fixed preference was hard-coded.

## Next layer

The next implementation should add:

1. walk-forward validation;
2. out-of-sample holdout;
3. regime-specific performance buckets;
4. Monte Carlo trade-order resampling;
5. automatic report export;
6. controlled candidate configuration generation;
7. explicit human approval before live promotion.

Never treat an in-sample winner as permanently valid.
