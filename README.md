# PropertyLens

PropertyLens is a Sofia-first Rails prototype that helps a buyer understand what public information can be found for a Bulgarian cadastral identifier. A visitor can submit a parcel, building, or individual-object identifier, follow real analysis stages, inspect a useful free preview, complete a test checkout, and unlock the full report through its unguessable public URL.

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
docker compose up -d
bin/rails db:prepare
```

PostGIS is required. `db:prepare` enables it and creates geography/geometry columns plus GiST indexes. The Compose image is `postgis/postgis:17-3.5`.

## Run the app

Run Rails, the Tailwind watcher, and Sidekiq together:

```sh
bin/dev
```

Or run them separately:

```sh
bin/rails server
bin/rails tailwindcss:watch
bundle exec sidekiq -C config/sidekiq.yml
```

Open <http://localhost:3000>. Analysis jobs use the `analysis` queue and dataset imports use `imports`.

The visible product name is configured once with `PRODUCT_NAME`; code and routes retain the PropertyLens working name. Bulgarian is the default locale and the interface also has English translations.

## Data-source modes

`DATA_SOURCE_MODE=live` uses the allowlisted official hosts in `config/data_sources.yml`. `DATA_SOURCE_MODE=fixture` reads offline files from `spec/fixtures/data_sources`; this is the automatic test default. Production must not use fixture mode because fixtures are representative test data, not live facts.

Every request becomes an independent `SourceRun` with status, source URL, retrieval time, known validity date, checksum, and a sanitized error when needed. Raw source responses are not stored unless `STORE_RAW_SOURCE_RESPONSES=true`; it defaults to false and should stay false in production.

Current integrations:

- SofiaPlan API: live version/catalog clients and GeoJSON download/import. The deterministic prototype configuration pins schools `166` (2018-08-08), kindergartens `142` (2018-08-08), parks and gardens `235` (2020-09-14), metro stations `47` (2021-03-08), and significant flood-risk areas `51` (2018-06-18). Old dates are preserved and shown, never treated as current.
- SofiaPlan ArcGIS: a generic paginated Feature Layer client queries development potential layer `31` and predominant functional zoning layer `33` by reliable location. Raw returned attributes are retained as provenance instead of assuming field meanings.
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
bin/rails 'property_lens:analyze[68134.1000.2000.1.5]'
```

For the requested live acceptance lookup, replace the example with the acceptance identifier and keep `DATA_SOURCE_MODE=live`.

## Payment prototype

The only catalog product is `full_property_report`, priced server-side at 2,490 euro cents. The browser never submits price or currency. With `PAYMENT_PROVIDER=fake` and `FAKE_PAYMENTS_ENABLED=true`, checkout exposes success, failure, and cancellation controls without card fields. Success is idempotent and unlocks the report for anyone holding its public UUID URL.

Fake payment mutation routes are disabled in production unless `FAKE_PAYMENTS_ENABLED=true` is explicitly set. A future real gateway can implement `Payments::Gateway`, use the existing generic `Order` fields, and replace the configured gateway without changing report access. No Stripe-specific objects or terminology are present.

## Map configuration

Set `MAP_STYLE_URL` to a compatible MapLibre style JSON URL. Development falls back to MapLibre demo tiles. Select a licensed production tile/style provider before launch. The report does not render a random Sofia map when location resolution fails; it shows an explicit unavailable state. Radius calculations disclose when only a centroid, rather than parcel geometry, is available.

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

Coverage includes identifier parsing, source clients/parsers, GeoJSON import, ArcGIS pagination, deterministic metrics/questions, PostGIS radii/intersections/touches, independent source failure, report states, all fake-payment outcomes, idempotency, and the end-to-end Capybara journey.

## Known limitations

- Municipal coverage is Sofia-first. Valid non-Sofia identifiers receive an honest limited-coverage report.
- NAG public HTML/Kendo contracts are undocumented and may change. A failed public form is marked unavailable rather than worked around with browser automation or fabricated data.
- AGKK open-data coverage depends on a district being identified and its archive being available. Similar identifiers are never used to infer a match; all hierarchy records and geometry are joined by exact cadastral identifiers.
- SofiaPlan amenity datasets currently available through the catalog are dated; every date is displayed.
- The fallback MapLibre demo style is not a production tile service.
- Reports are link-based and have no accounts, emails, PDF export, document uploads, valuation, listing imports, or LLM-generated conclusions.

The highest-value next step is scheduling archive refreshes for all launch districts and importing fresher municipal amenity datasets, while preserving the same exact-identifier and per-source provenance rules.
