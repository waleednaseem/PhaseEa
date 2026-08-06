# Phase — Project Brief

## What
RSI-based **regime Expert Advisor** for MetaTrader 5. Detects bullish/bearish phases from RSI band occupancy, paints chart visuals, and places live bounce trades.

## Core goals
1. CB sticky regime: bull hold ≥40 after >65 break / bear fail ≤65 after <40 break
2. RSI(14); BUY green / SELL red / END grey on flips
3. History strips + body boxes + Phase_RSI levels
4. Bounce entries in regime + Div/regime exits

## Non-goals
Docker, modifying sibling EAs, martingale/trailing.
