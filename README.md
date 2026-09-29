# Bitey IA ↔ AI Trading Bot Bridge

This repository is the MetaTrader 4 trading module connected to Bitey IA.

## Boundary

- **Bitey IA**: market analysis and structured advisory signal.
- **AI Trading Bot / MT4**: local indicators, strategy state and final Risk Gate.
- **MT4**: broker communication and order execution.
- **Bitey IA never executes MT4 orders.**

## Read-only flow

`MT4 snapshot → POST /api/v2/trading/analyze → structured signal → local Risk Gate → optional execution`

The first integration is deliberately analysis-only. If the API is unavailable or returns an invalid signal, the bridge defaults to **HOLD** and `risk_allowed=false`.

## MT4 configuration

In MetaTrader 4, add the Bitey backend host to:

**Tools → Options → Expert Advisors → Allow WebRequest for listed URL**

The EA should call `mt4/include/AI_Bridge.mqh` and keep its existing local Risk Gate authoritative.

Recommended endpoint:

`https://<bitey-render-host>/api/v2/trading/analyze`

Optional server authentication:

- Render environment variable: `TRADING_MODULE_TOKEN`
- MT4 request header: `X-Trading-Module-Token`

Do not commit the token to GitHub.

## Signal contract

See `bridge/schemas/trading_signal.schema.json`.

## Safety

This bridge does not contain `OrderSend` and does not bypass the EA Risk Gate. A failed API request, malformed response, low confidence or rejected risk state must remain non-executable.

## Next integration stages

1. Connect v1.33/v1.34 EA snapshot generation.
2. Log AI signal + local Risk Gate decision to CSV.
3. Add backtest comparison: local-only vs AI-assisted.
4. Demo-only execution.
5. Only after explicit validation, consider live execution.


## Controlled optimization architecture

The next layer is a research loop, not autonomous live trading:

`baseline -> hypothesis -> candidate EA -> backtest -> validation -> out-of-sample -> demo`

Bitey may use an external AI model as a bounded second opinion for code review, market-regime analysis, and backtest-result interpretation. The external model does not receive broker credentials, does not place orders, and does not bypass the MT4 Risk Gate.

The current v1.33 baseline is preserved as the comparison point. Candidate versions must be evaluated under the same risk settings before promotion.

See `docs/optimization-loop.md` and `bridge/schemas/optimization_experiment.schema.json`.


## v1.34 adaptive spectrum

The repository now contains `mt4/experts/AI_Trading_Bot_v1.34_Bitey.mq4` plus modular engines:

- `mt4/include/Market_Regime.mqh`: regime detection and Hurst estimate.
- `mt4/include/Trading_Metrics.mqh`: real-time account/trading metrics.
- `mt4/include/Strategy_Spectrum.mqh`: eight-strategy historical audit and bounded selector.
- `docs/adaptive-spectrum.md`: statistical protocol and validation roadmap.

The eight research models are trend following, mean reversion, momentum, volatility breakout, session bias, divergence proxy, strict range, and fractal/HTF confirmation.

Each simulated trade must resolve through TP or SL within a configured horizon. Unresolved cases are excluded instead of being counted as wins. The selector considers expectancy, profit factor, win rate and drawdown.

### Bitey IA modes

- `AI_OFF`: local strategy spectrum only.
- `AI_ASSIST`: Bitey advises/logs; local Risk Gate remains authoritative.
- `AI_FILTER`: Bitey must return matching direction, sufficient confidence and risk approval before an order is permitted.

The EA defaults to `AI_ASSIST` and `InpEnableExecution=false`. Execution therefore requires an explicit configuration change and subsequent validation. The EA also writes `BiteyAdaptiveReport.tch` into the MT4 Files directory as a plain-text research artifact (the `.tch` extension is only a project artifact format; it is not encryption).

This is an adaptive research architecture, not a claim that the selected strategy will be profitable. Walk-forward and out-of-sample validation remain mandatory before any live promotion.
