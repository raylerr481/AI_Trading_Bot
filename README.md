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
