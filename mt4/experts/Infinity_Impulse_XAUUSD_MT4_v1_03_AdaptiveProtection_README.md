# Infinity Impulse XAUUSD v1.03 AdaptiveProtection

Experimental fork of `Infinity_Impulse_XAUUSD_MT4_v1_02.mq4`. The v1.02 source is not modified.

## Scope retained
- XAUUSD/GOLD only (broker suffixes are accepted when the symbol contains XAU or GOLD).
- Original Bollinger breakout + EMA entry signal, timeframe, entry window, ATR SL/TP, spread filters and broker margin check retained.
- Existing lock, ATR trailing and TP extension remain; trailing tightens when price pulls back materially from its favorable peak. SL modifications are monotonic (the EA only accepts a more protective SL).

## v1.03 changes
- Persist favorable peak price distance in MT4 Global Variables (`INFP_<ticket>`) and recover it after EA restart.
- Persist initial stop distance/risk (`INFR_<ticket>`) and remove tracking keys after the trade closes.
- Adaptive entry-risk multiplier based on up to the last 10 closed trades for this symbol/magic; it can reduce the next entry budget, never increase it above the configured budget. It also scales down when open risk uses 50%/75% of the configured aggregate cap.
- Strict minimum-lot handling: broker minimum is rejected if its modeled stop risk exceeds the approved risk budget. The input multiplier is clamped to at most 1.0.
- Early loss cut after the configured minimum age when net loss reaches the configured percentage of initial modeled risk.
- Persistent negative-duration timer; default initial wait 30 minutes, shortened by 5 minutes for each consecutive closed loss, floor 5 minutes. Duration exit is limited to small losses (default 35% of initial modeled risk); larger losses are left to the broker SL / other protections.
- Profit lock estimates net peak after entry/estimated exit commission, negative swap and a close-side slippage reserve before converting the retained net-profit target into an SL.
- Add-on opens now obey the same aggregate open-risk cap; failed add-on opens do not consume the parent add-on counter.

## Explicit limitation
News protection is not enabled: no compatible, validated news-calendar feed was present in the Infinity source. The EA logs this limitation rather than pretending to protect around events.

## Validation status
Source created and committed to the experimental branch. It has **not** been compiled in MetaEditor and has **not** been backtested. Validate broker symbol naming, commission model, stop/freeze levels, minimum lot, and close behavior in Strategy Tester/demo before any live use. No profitability claim is made.
