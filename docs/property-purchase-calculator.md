# Property-purchase calculator

The calculator is a self-contained feature in the Rails monolith. It does not change the education catalog, buyer-stage logic, recommendations, report pricing, checkout, or report access. Public entry points are `/kalkulator`, `/kalkulator/pokupka-na-imot`, and `/kalkulator/ipoteka`.

## Calculation boundary

Ruby services under `app/services/calculators` are authoritative. Browser code only handles tabs, progressive disclosure, debounced POST submissions, stale-response protection, schedule row editing, session-scoped draft restoration, and visualization. Calculations make no external network calls. A temporary draft is kept only in the current tab's browser session; durable persistence still requires the visitor to save explicitly.

Money is normalized to integer euro cents. Rates and intermediate values use `BigDecimal`; financial values are never parsed or calculated with binary floating point. Bulgarian decimal input accepts ungrouped digits or three-digit space/NBSP groups with either a comma or dot decimal separator. Mixed separators, malformed grouping, and a three-digit suffix such as `1.234` are rejected as ambiguous.

Rounding policies:

- percentage fees and installments: round half up to one euro cent per line;
- legacy BGN progressive notarial tariff: convert the EUR material interest to BGN with the full fixed rate, apply the unrounded tariff brackets and cap in BGN, then convert the final fee once and round half up to an euro cent;
- legacy BGN registration minimum: convert the minimum once with the full fixed rate and round half up to an euro cent;
- annuity payment: calculate at decimal precision, round the regular payment to cents, round monthly interest to cents, and adjust the final payment to clear the exact remaining cent balance;
- one `remaining` schedule row absorbs the price-allocation rounding difference. Percentages are never silently normalized.

## Regulatory rules

Versioned rule data lives in `config/financial_rules/bulgaria.yml`, separately from formulas. The initial rule set was checked on 2026-09-06 against primary sources:

- Sofia acquisition tax: 3% under Sofia Municipal Council ordinance, applied to the higher of agreed consideration and tax assessment;
- Registry Agency sale registration: 0.1% of the relevant material interest with the statutory BGN 10 minimum;
- Notary Chamber progressive material-interest tariff, including all bracket boundaries and the BGN 6,000 cap;
- Ministry of Finance property-transfer tax-base rule;
- NRA standard 20% VAT rate;
- official euro conversion rate of BGN 1.95583 per EUR and statutory cent rounding.

Only Sofia has an automatically verified municipal acquisition-tax rate. Another municipality remains unresolved until the visitor enters an explicitly labeled manual rate. Dates before the configured versions remain unsupported rather than receiving a guessed rule. Future dates state that unchanged rules are an assumption. Complex multi-deed or mixed-tax-treatment transactions require manual professional quotes.

Property VAT is never inferred from property type or new construction. A net property quote adds VAT only after the visitor confirms both applicability and rate. Service quotes distinguish VAT-inclusive, VAT-exclusive, uncertain, and not-applicable states. A selected blank fee remains unresolved, never zero.

## Payments and funding

Schedule percentage rows use the payable property price as their base, not costs. A credited reservation is recorded once as historical price paid and reduces the selected later installment. A reservation marked as a separate fee is added once to lifetime acquisition outlay. Payments before the plan's starting point stay in lifetime totals but are not deducted again from current cash.

The funding ledger preserves event order, including within one date. Own inflows become available only at their selected event. Mortgage capacity becomes available only at the selected event and can fund eligible seller payments, not taxes, furniture, or general cash needs. A negative cash projection is reported as missing funding. Reserve erosion is reported separately and the reserve is never added to purchase expense.

The mortgage engine models a fully drawn, constant-rate monthly annuity. It does not model approval, APR/GPR, grace periods, construction-period interest, daily lender conventions, variable-rate resets, balloon payments, or early repayment.

## Persistence and privacy

Unsaved purchase and mortgage inputs are serialized to `sessionStorage` after a visitor changes the blank calculator. This draft survives refreshes and same-tab navigation but is cleared when the tab's browser session ends. It is never placed in a cookie, sent with unrelated requests, or restored over an explicitly loaded example or saved scenario. Dynamic payment rows, disclosure state, and the active calculator section are included in the draft. Restoring a draft submits the restored values through the normal server-side calculation endpoint so Ruby remains authoritative. Once a calculator contains changed, restored, example, or saved data, a confirmed “Започни отначало” action clears its temporary draft and opens the blank calculator; it never deletes explicitly saved scenarios.

`BudgetScenario` stores normalized inputs, a calculation snapshot, engine version, financial-rule versions, and calculation time. A saved calculation can optionally reference an existing guest-owned `BuyerJourney` and its property analysis. That association never changes education progress or stage inference.

Authorization uses the existing signed guest identity cookie and server-side SHA-256 digest. Every scenario read or mutation is scoped to that digest. Random UUIDs and `noindex` are defense-in-depth, not authorization. Private scenarios are excluded from the sitemap, and public property reports do not render scenario data. Calculator parameters and snapshots are filtered from application logs. Rule changes do not mutate saved snapshots; recalculation is an explicit POST action.

## Operations

Install and prepare as for the existing application, then run:

```sh
bin/rails db:migrate
bin/rails tailwindcss:build
bin/rails zeitwerk:check
bin/rspec
bin/rubocop
```

Before public launch, a qualified Bulgarian legal/tax reviewer should confirm the encoded tariff interpretation, fee bases, VAT presentation, source currency handling, and source freshness. A lending specialist should review the mortgage disclaimers and funding-event terminology. No such professional review is claimed by the implementation.
