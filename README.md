# Mesto

Mesto is a Sofia-first Bulgarian property intelligence product at [mesto.bg](https://mesto.bg). It helps buyers understand what public information can be found for a cadastral identifier. A visitor can submit a parcel, building, or individual-object identifier, follow real analysis stages, inspect a useful free preview, complete checkout, and unlock the full report through its unguessable public URL.

The product is an information aid, not legal due diligence. It does not verify ownership, title, mortgages, encumbrances, construction legality, formal planning compliance, or future development.

## Stack and requirements

- Ruby 3.4.7, Rails 8.1, Hotwire, Stimulus, Importmap, and Tailwind CSS 4
- PostgreSQL 17 with PostGIS 3.5
- Sidekiq 8 and Redis 7.2
- RSpec, FactoryBot, Capybara, and WebMock
- MapLibre GL for the report map

Install Ruby 3.4.7 and Docker, then:

```sh
cp .env.example .env
# Set DATABASE_PASSWORD in .env.
bundle install
bin/dev
```

PostGIS is required. `bin/dev` starts the shared Compose services if needed and runs `db:prepare`, which enables PostGIS and creates geography/geometry columns plus GiST indexes. The Compose image is `postgis/postgis:17-3.5`.

## Run the app

Run Rails, the Tailwind watcher, and Sidekiq together:

```sh
bin/dev
```

All worktrees use one shared `mesto` Compose project for PostgreSQL, Redis, and the local Caddy proxy. Starting `bin/dev` from a new worktree reuses those services and their data, prepares any pending database migrations, and runs Rails on the fixed port 3000. Conductor is configured to run only one worktree's development processes at a time so Sidekiq and Rails always use the active branch's code.

Because the database is shared between branches, a migration from one branch can leave the schema ahead of an older branch. Reset the development database when switching across incompatible migrations.

Or run them separately:

```sh
bin/rails server
bin/rails tailwindcss:watch
bundle exec sidekiq -C config/sidekiq.yml
```

Open <http://mesto.localhost>. The direct Rails endpoint remains available at <http://localhost:3000>. Analysis jobs use the `analysis` queue and dataset imports use `imports`.

The product name defaults to `Mesto` and the canonical production host defaults to `mesto.bg`; both can be configured with `PRODUCT_NAME` and `APP_HOST`. Bulgarian is the default locale and the interface also has English translations.

The programmable five-row wordmark, variants, motion behavior, and usage rules are documented in [`docs/brand/mesto-logo.md`](docs/brand/mesto-logo.md).

## Data-source modes

`DATA_SOURCE_MODE=live` uses the allowlisted official hosts in `config/data_sources.yml`. `DATA_SOURCE_MODE=fixture` reads offline files from `spec/fixtures/data_sources`; this is the automatic test default. Production must not use fixture mode because fixtures are representative test data, not live facts.

Every request becomes an independent `SourceRun` with status, source URL, retrieval time, known validity date, checksum, and a sanitized error when needed. Raw source responses are not stored unless `STORE_RAW_SOURCE_RESPONSES=true`; it defaults to false and should stay false in production.

Current integrations:

- SofiaPlan API: live version/catalog clients and GeoJSON download/import. A located analysis imports any missing configured datasets before it calculates spatial results; one failed import does not stop the other datasets. The deterministic prototype configuration pins schools `166` (2018-08-08), kindergartens `142` (2018-08-08), parks and gardens `235` (2020-09-14), metro stations `47` (2021-03-08), and significant flood-risk areas `51` (2018-06-18). Old dates are preserved and shown, never treated as current.
- SofiaPlan ArcGIS: a generic paginated Feature Layer client queries development potential layer `31` and predominant functional zoning layer `33` by reliable location. Raw returned attributes are retained as provenance instead of assuming field meanings.
- OpenStreetMap: one bounded Overpass query fetches only mapped schools and kindergartens within 2 km of the property. Results retain per-place source links and the OpenStreetMap snapshot time; this is community-maintained context rather than an official municipal register.
- NAG registers: the adapter discovers the official public search-form action and searches building permits, design visas, planning orders, and occupancy certificates by full, building, and parcel identifiers. It parses the Kendo result payload and a capped set of public detail pages. The public pages have no documented third-party API, so this integration is intentionally isolated and can become `unavailable` if the form changes. It does not bypass authentication, CAPTCHAs, or access controls and does not fetch PDFs.
- Cadastre: the default provider imports AGKK's official parcel, building, and individual-object open-data archives. It retains exact identifiers, attributes, archive dates, and vector geometry; parcel geometry is transformed from BGS2005 / CCS2005 (EPSG:7801) to WGS 84 for the report map and spatial checks. The optional AGKK WMS configuration remains overlay-only.

Only HTTPS hosts explicitly allowlisted in `config/data_sources.yml` can be fetched. User input never controls a remote URL.

### AGKK cadastral open data

Property identity and hierarchy facts come from AGKK's public `самостоятелни обекти`, `сгради`, and `поземлени имоти` archives. This includes object area and outline, attached/common parts, floor and purpose; building footprint, floors, function, and object count; parcel area, perimeter, territory type, permanent use, regulation quarter/UPI; official addresses, approval acts, technical codes, and cadastral geometry. In live mode, an analysis imports the required hierarchy for the relevant Sofia district on first use when a municipal record provides the district hint. Imported records are reused locally and refreshed by archive checksum and importer version.

To refresh a district explicitly:

```sh
bin/rails 'cadastre:sync_sofia_district[Студентски]'
```

The importer reads only the three non-ownership archives. It deliberately does not download the separate `собственост ПИ`, `собственост сгради`, or `собственост СОС` archives, and it never imports owner names. The non-ownership archives' broad cadastral ownership category may be displayed with an explicit warning that it is not a current ownership, title, seller, or encumbrance check.

## Sync and maintenance commands

Check connectivity and show useful source diagnostics:

```sh
bin/rails data_sources:check
```

List the live SofiaPlan catalog, optionally filtered:

```sh
bin/rails sofiaplan:datasets
bin/rails 'sofiaplan:datasets[kindergarten]'
```

Import the five configured GeoJSON datasets. Imports upsert stable feature IDs, remove stale features, preserve freshness, and skip an unchanged checksum:

```sh
bin/rails sofiaplan:sync
bin/rails 'sofiaplan:sync[schools]'
```

Run any valid cadastral identifier synchronously from the command line:

```sh
bin/rails 'mesto:analyze[68134.1000.2000.1.5]'
```

For the requested live acceptance lookup, replace the example with the acceptance identifier and keep `DATA_SOURCE_MODE=live`.

## Payment prototype

The only catalog product is `full_property_report`, priced server-side at 2,490 euro cents. The browser never submits price or currency. With `PAYMENT_PROVIDER=fake` and `FAKE_PAYMENTS_ENABLED=true`, checkout exposes success, failure, and cancellation controls without card fields. Success is idempotent and unlocks the report for anyone holding its public UUID URL.

Checkout is offered only when every applicable source check completed successfully and the resulting report contains a meaningful paid section. A failed or unavailable source leaves the partial findings visible, marks dependent calculations as unavailable instead of zero, and disables checkout.

Fake payment mutation routes are disabled in production unless `FAKE_PAYMENTS_ENABLED=true` is explicitly set. A future real gateway can implement `Payments::Gateway`, use the existing generic `Order` fields, and replace the configured gateway without changing report access. No Stripe-specific objects or terminology are present.

## Map configuration

Set `MAP_STYLE_URL` to a compatible MapLibre style JSON URL. The default is OpenFreeMap's OpenStreetMap-derived Liberty style, which supplies the street, label, building, and place context beneath the report overlays. Configure a hosted style provider with an appropriate service level before production launch. The report does not render a random Sofia map when location resolution fails; it shows an explicit unavailable state. Radius calculations disclose when only a centroid, rather than parcel geometry, is available.

The interactive report map overlays the exact imported AGKK hierarchy when available: the individual object, its building, its parcel, and up to 40 nearby cadastral buildings within 175 metres. The nearest imported SofiaPlan schools, kindergartens, parks, metro stations, and flood-risk areas within 1 kilometre are shown only when that source succeeded for the analysis. Existing and planned metro features are labelled separately. Optional planning, flood-risk, and administrative-act layers start hidden to keep the initial view legible. Each available category has its own toggle and popup provenance; unavailable categories are omitted rather than inferred.

## Tests and quality checks

Automated tests always use fixtures and WebMock blocks non-local network access:

```sh
bin/rspec
bin/rubocop
bin/rails zeitwerk:check
```

Run the CI sequence with:

```sh
bin/ci
```

Coverage includes identifier parsing, source clients/parsers, automatic GeoJSON import, ArcGIS pagination, missing-versus-zero spatial metrics, planned/existing transit, PostGIS radii/intersections/touches, payment gating on complete source coverage, independent source failure, report states, all fake-payment outcomes, idempotency, and the end-to-end Capybara journey.

## Known limitations

- Municipal coverage is Sofia-first. Valid non-Sofia identifiers receive an honest limited-coverage report.
- NAG public HTML/Kendo contracts are undocumented and may change. A failed public form is marked unavailable rather than worked around with browser automation or fabricated data.
- AGKK open-data coverage depends on a district being identified and its archive being available. Similar identifiers are never used to infer a match; all hierarchy records and geometry are joined by exact cadastral identifiers.
- SofiaPlan amenity datasets currently available through the catalog are dated; every date is displayed, and snapshots older than two years are never presented as current amenity counts.
- The fallback MapLibre demo style is not a production tile service.
- Reports are link-based and have no accounts, emails, PDF export, document uploads, valuation, listing imports, or LLM-generated conclusions.

The highest-value next step is scheduling archive refreshes for all launch districts and importing fresher municipal amenity datasets, while preserving the same exact-identifier and per-source provenance rules.

## Education catalog and anonymous journeys

Bulgarian educational content, source metadata, deterministic recommendation rules, and checklist definitions live in `content/education`. Validate keys, slugs, required sections, source references, and allowlisted rule conditions with:

```sh
bin/rails education:validate
```

Personal learning plans do not require an account. A random guest identity is stored in a signed, HTTP-only, same-site cookie; only its SHA-256 digest is stored with server-side journey rows. Public report tokens do not authorize access to a journey. Private buyer stage, financing context, labels, and progress are never rendered into shared reports.

Anonymous journeys default to 180 days from last activity. Configure `ANONYMOUS_JOURNEY_RETENTION_DAYS` and schedule:

```sh
bin/rails education:prune_anonymous_journeys
```

Professional review metadata remains `pending` until a real qualified review is recorded. Educational pages explain current source coverage and never treat a missing public result as proof that a document does not exist.

Administrative-act references now distinguish an identifier printed in the record (`document`) from the identifier merely used to query a registry (`search_query`). Only the former can support a building milestone. Pre-existing references are deliberately left unclassified and therefore do not support milestone inference until the relevant analysis is refreshed.
