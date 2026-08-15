# Deriv Bot Pro - Project Intentions

Deriv Bot Pro is intended to become a trading platform with two clearly separated products:

1. Options Trading
2. MT5 Trading

These two trading modes must not be mixed together. They serve different users, use different execution flows, and need different screens, settings, and risk controls.

## 1. Options Trading

Options Trading is for users who want to trade Deriv options contracts directly from the bot.

The user links their Deriv account in the bot. After the account is linked, the bot should be able to execute supported Deriv options trades directly through the Deriv API.

The user should be able to choose which options strategy they want to trade, for example:

- Accumulators
- Rise/Fall
- Over/Under
- Matches/Differs
- Even/Odd

Each options strategy should have its own settings, risk rules, and execution logic. The user should not be forced into Accumulators only.

The Options Trading flow should look like this:

```text
User links Deriv account
        |
        v
User chooses Options Trading
        |
        v
User chooses contract type
        |
        v
User sets stake, risk, recovery, and limits
        |
        v
Bot analyzes market
        |
        v
Bot places Deriv options trade directly
```

The Options Trading side should focus on Deriv contracts only. It should not ask the user to connect MT5.

## 2. MT5 Trading

MT5 Trading is a separate mode for users who want to trade forex, synthetic indices, commodities, or other MT5 markets from inside the bot.

MT5 users should not need to manually trade on the MT5 terminal/site after linking their MT5 bridge. The bot should become the control panel for MT5 trading.

The user should be able to connect their MT5 account to the bot through an MT5 bridge, then choose:

- Manual trading
- Auto trading

### Manual MT5 Trading

In manual mode, the bot should not place trades automatically.

Instead, the bot should:

- Watch the markets selected by the user
- Analyze the market
- Detect trading signals
- Alert the user when a signal is available
- Let the user decide whether to place the trade

Manual mode should be useful for traders who want signals, but still want control before entry.

### Auto MT5 Trading

In auto mode, the bot should place MT5 trades automatically when the user's selected conditions are met.

The user should be able to configure:

- MT5 account bridge
- Markets to trade
- Lot size
- Stop loss
- Take profit
- Maximum number of open trades at a time
- Signal confidence threshold
- Manual or automatic execution
- Daily loss limits
- Recovery limits

The MT5 Trading flow should look like this:

```text
User connects MT5 bridge
        |
        v
User chooses MT5 Trading
        |
        v
User selects Manual or Auto mode
        |
        v
User selects markets and risk settings
        |
        v
Bot analyzes selected markets
        |
        +--> Manual mode: show signal alert
        |
        +--> Auto mode: place MT5 trade through bridge
```

## MT5 Position Management

The MT5 section of the bot should show the user's open MT5 positions.

For every open MT5 position, the bot should show:

- Symbol
- Buy or sell direction
- Lot size
- Entry price
- Current profit or loss
- Stop loss
- Take profit

The user should be able to:

- Close an open position
- Modify stop loss
- Modify take profit

This should happen from inside the bot, not by sending the user back to the MT5 terminal.

## Important Product Boundary

Options Trading and MT5 Trading are separate.

Options Trading:

- Uses linked Deriv account
- Trades Deriv options contracts
- Includes Accumulators, Rise/Fall, Over/Under, Matches/Differs, Even/Odd
- Executes directly through Deriv options APIs where supported

MT5 Trading:

- Uses linked MT5 bridge
- Trades MT5 markets
- Supports manual signal alerts
- Supports automatic trade execution
- Shows open positions
- Allows closing and modifying MT5 positions

The UI should make this distinction obvious.

## Risk Management Intentions

The bot should never blindly martingale without limits.

The user may configure recovery factors, but the bot must enforce:

- Maximum daily loss
- Maximum open trades
- Maximum recovery levels
- Stop-after-loss rules
- Higher confidence requirement after a loss
- News/economic calendar guard
- Manual override

The bot should not promise guaranteed wins. It should try to reduce risk, wait for better conditions, and stop when configured limits are reached.

## LLM Usage

The LLM should not be responsible for instant trade execution decisions.

The live execution path should be deterministic and fast.

The LLM can be used for:

- Market explanation
- Signal explanation
- News interpretation
- Strategy review
- Post-trade analysis
- Parameter suggestions

The bot's execution engine should make fast decisions using deterministic rules, market data, and user settings.

## Current Direction

The project should move toward a simple user experience:

```text
Choose trading product:
  1. Options Trading
  2. MT5 Trading

If Options:
  Link Deriv account
  Choose options contract type
  Configure risk
  Start bot

If MT5:
  Connect MT5 bridge
  Choose manual or auto
  Select markets
  Configure lot, SL, TP, max open trades
  Start alerts or auto trading
```

This README is the product intention document. Future code changes should follow this separation.
