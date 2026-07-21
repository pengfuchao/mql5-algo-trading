# MT5 Strategy Library — Agent Instructions

Operational rulebook for AI coding agents working in this repository.

## Scope

This repository contains MetaTrader 5 programs written in MQL5, plus the research documentation pipeline around them:

- `Indicators/`: custom indicators and indicator-to-EA interfaces
- `Strategies/`: Expert Advisors and trading strategies (see the tier table in its `README.md`: research pipeline vs teaching examples vs excluded-from-research)
- `Utilities/`: standalone examples and legacy utility scripts (frozen reference library)
- `Strategy_Ideas/`: strategy hypotheses and evaluation docs. Ideas cleared for implementation carry a **"§10 實作規劃" section — that section is the implementation contract** (deliverables, inputs, logic, edge cases, acceptance checklist) for coding agents. Read the entire idea file before implementing, and `Quant_Strategy_Development_Framework.md` for the methodology it assumes.
- `Strategy_Records/`: backtest evidence, research decisions, and per-EA behavior/interface documentation (appendix sections).
- `Strategy_Live_Candidates/`: frozen deployment cards (+ `.set` presets) for strategies that passed all backtest gates. **Never change their parameters or the referenced EA behavior without re-validation through `Strategy_Records/`.**

## Collaboration and Shared Workspace

- Multiple coding agents may use the same working directory. Follow a **one writer at a time** convention.
- Treat editing, compiling, testing, and review as explicit handoffs. Do not modify files while another agent is expected to be writing or building.
- Before editing, inspect `git status`, recent commits, and the relevant source and documentation files.
- Treat existing uncommitted changes as user-owned. Do not overwrite, revert, stage, or reformat unrelated changes.
- If unexpected changes or build artifacts appear, stop and report them before continuing.
- When the user says to first understand, inspect, review, or verify, remain read-only until implementation is explicitly requested.
- Communicate in Traditional Chinese by default while retaining standard English technical terms.

## Engineering Priorities

Use this priority order:

```text
Trading safety > Correctness > Reproducibility > Auditability > Testability > Simplicity > Performance > Features
```

Prefer small, explicit, testable changes over broad rewrites or speculative abstractions.

## Absolute Prohibitions

Never:

1. Hard-code credentials, broker passwords, account numbers, API keys, tokens, or personal secrets.
2. Claim that a strategy, indicator, buffer contract, compile result, or backtest result was verified without checking it.
3. Perform broad refactors, rename or move files, or delete existing code unless explicitly requested.
4. Create duplicate versioned files such as `*_v2.mq5`, `*_final.mq5`, `*_new.mq5`, or `*_latest.mq5` when the existing file should be updated.
5. Rewrite an entire file when a surgical edit is sufficient.
6. Silently swallow indicator, data-copy, trade execution, or position-management failures.
7. Treat profitable in-sample backtests as evidence of live-trading readiness.
8. Expand scope beyond the user request without first explaining the tradeoff.

## Development Rules

1. Prefer modern MQL5 APIs and `CTrade`; do not introduce MT4-style order APIs.
2. Create indicator handles in `OnInit()` and release them in `OnDeinit()`.
3. For trading signals, use completed bars (`shift = 1`) unless intrabar behavior is explicitly required.
4. Filter every managed position and order by symbol and `MagicNumber`.
5. Validate broker constraints before trading:
   - `SYMBOL_TRADE_STOPS_LEVEL`
   - `SYMBOL_VOLUME_MIN`
   - `SYMBOL_VOLUME_MAX`
   - `SYMBOL_VOLUME_STEP`
   - tick size and tick value
6. Separate signal generation, execution, position sizing, exits, and risk controls.
7. Check and log trade return values and `CTrade` result descriptions.
8. Avoid repainting and look-ahead bias. Document any indicator buffer that may change intrabar.
8a. **`input group` occupies an `iCustom` positional parameter slot.** Never call `iCustom` positionally against an indicator whose inputs are organised with `input group` — every parameter silently shifts by one per preceding group, with no compile error and no runtime error. Verified 2026-07-21: this invalidated the entire S1–S7 backtest series for `Strategy_SR_Channel_Breakout` (see `Strategy_Records/Strategy_SR_Channel_Breakout.md` S10). Either drive such indicators through an explicit named-parameter mechanism, or verify delivery before trusting any result.
8b. **Whenever an EA passes parameters to an indicator, both sides must log them, and the two logs must be compared before any backtest is treated as evidence.** Trade count is the cheapest canary: a baseline whose trade count moves after an interface change is a regression until proven otherwise.
9. Do not treat files under `Utilities/` as reusable include modules unless they are first converted to `.mqh` and script event handlers such as `OnStart()` are removed.
10. Do not commit generated `.ex5` binaries or local AI-tool configuration directories.

## Workflow

For non-trivial implementation:

1. State the core takeaway, assumptions, scope, implementation plan, and verification criteria.
2. Search before creating files and read the existing implementation before editing.
3. Make only changes traceable to the user's request.
4. Preserve existing architecture, naming, indicator buffer indexes, and `iCustom` parameter order unless the change explicitly requires otherwise.
5. Compile and test the affected program.
6. Review the final diff and report changed files, verification performed, and residual risks.

## Risk and Research Standards

- Default risk sizing should be based on account equity and stop-loss distance.
- State assumptions for spread, slippage, commission, swap, and execution mode.
- Backtests should include sufficient trades, out-of-sample validation, parameter sensitivity, and multiple market regimes.
- Explicitly discuss overfitting, transaction costs, and economic significance.
- Martingale, grid, hedging, and averaging strategies require explicit exposure and drawdown limits.

## Verification

For each changed `.mq5` file:

1. Compile with MetaEditor and report errors and warnings.
2. Verify indicator buffer indexes and `iCustom` parameter order when applicable.
3. Run an MT5 Strategy Tester smoke test for EAs when the terminal environment is available.
4. Confirm that only intended source and documentation files are changed.

If verification cannot be run, explain why and provide the exact command or manual MT5 procedure required.

## Documentation

- Keep the relevant directory `README.md` synchronized when adding or materially changing a program.
- **Single source of truth per item**: each strategy / idea / backlog item keeps its status in exactly one file (its own document). Directory `README.md` tables hold only a one-line pointer and must not duplicate status details that can drift.
- Document inputs, signal logic, position sizing, exits, risk controls, buffer contracts, and known limitations.
- Use Traditional Chinese for explanations where practical, while retaining standard English technical terms.

## Git and File Hygiene

- Do not use interactive Git commands.
- Do not force-push or rewrite history unless explicitly requested.
- Commit and push only when explicitly requested.
- Check `.gitignore` before creating generated outputs.
- Do not stage or revert unrelated user changes.
- Before closeout, run `git diff --check` and confirm `git status` contains only intended changes.

## Definition of Done

A task is complete only when:

- the requested behavior is implemented,
- relevant compilation or testing passed, or the blocker is clearly reported,
- documentation is synchronized when behavior or interfaces changed,
- changed files and residual risks are reported,
- no unrelated user work was modified.
