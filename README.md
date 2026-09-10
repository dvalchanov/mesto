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

Open <http://mesto.localhost>. The direct Rails endpoint remains available at <http://localhost:3000>. Analysis jobs use the `analysis` queue. Shared remote downloads and bulk imports use the separate `ingestion` queue; the bounded, per-identifier NAG exception runs as part of the analysis so its outcome belongs to that report revision.

The product name defaults to `Mesto` and the canonical production host defaults to `mesto.bg`; both can be configured with `PRODUCT_NAME` and `APP_HOST`. Bulgarian is the default locale and the interface also has English translations.

The programmable five-row wordmark, variants, motion behavior, and usage rules are documented in [`docs/brand/mesto-logo.md`](docs/brand/mesto-logo.md).

### Exercise the property graph with real public data

Prepare the six AGKK district archives: parcel, building and individual-object geometry plus the matching `собственост ПИ`, `собственост сгради`, and `собственост СОС` rights snapshots. Development imports do not require a production permission approval:

```sh
bin/rails db:migrate
bin/rails cadastre:catalog
bin/rails 'cadastre:sync_sofia_district[Студентски]'
bin/rails data_sources:prepare_spatial
bin/dev
```

Open <http://mesto.localhost> and submit `68134.1609.3263.1.10`. The cadastral object, building, parcel, rights rows, company EIK, source dates, and document descriptions come from the official AGKK OpenData archives. The exact EIK is then checked against the official VIES service. In development, the first search also performs four bounded NAG lookups for the exact parcel/building/object identifiers and caches their snapshots for later reports. No demo mode is needed.

The UI deliberately calls this a cadastral right-holder snapshot, not verified ownership. It is not a current Property Register title/encumbrance check. Masked natural-person rows are counted during import but are not retained by Mesto.

### Optional synthetic contract-provider demo

The Registry Agency integrations remain unavailable until an approved contract feed is configured. The opt-in synthetic provider is only for exercising future Commercial/Property Register payloads and historical manager/owner UI states:

```sh
MESTO_REGISTRY_DEMO=true bin/dev
```

Demo providers accept only that configured identifier and EIK `000000000`. They refuse to initialize in production. Override the identifier only when matching real cadastral hierarchy data is already imported locally:

```sh
MESTO_REGISTRY_DEMO=true MESTO_REGISTRY_DEMO_IDENTIFIER=68134.1607.1254.1.5 bin/dev
```

## Data-source modes

`DATA_SOURCE_MODE=live` uses the allowlisted official hosts in `config/data_sources.yml`. `DATA_SOURCE_MODE=fixture` reads offline files from `spec/fixtures/data_sources`; this is the automatic test default. Production must not use fixture mode because fixtures are representative test data, not live facts.

Report generation reads cadastral and spatial coverage from the prepared database; it never downloads KAIS, ArcGIS, SofiaPlan, or Overpass datasets during a user request. NAG is the deliberate exception: when enabled, the first search for an exact identifier executes bounded register lookups through `ImportNagRegistryJob`, persists normalized acts and reusable source snapshots, and later reports reuse fresh snapshots. Every report revision records a separate set of `SourceRun` rows with source URL, source-data date, retrieval time, checksum, dataset revision, geographic coverage, and calculation basis. Refreshing a report preserves earlier revisions instead of deleting their evidence. Raw source responses are not stored unless `STORE_RAW_SOURCE_RESPONSES=true`; it defaults to false and should stay false in production.

Current integrations:

- SofiaPlan API: ingestion jobs download configured GeoJSON datasets, filter whole features to the supporting-data boundary, validate them, and publish them transactionally. The pinned source dates remain distinct from Mesto's retrieval dates.
- SofiaPlan ArcGIS: background ingestion stores development potential layer `31` and functional zoning layer `33` locally. Reports intersect every matching planning polygon with the full parcel polygon.
- OpenStreetMap: background ingestion stores mapped schools and kindergartens for the supporting-data boundary. Reports calculate and label straight-line distance from the selected building/location point.
- NAG registers: the bounded adapter searches only the exact parcel/building/object identifiers for the report. Development enables this on first search and reuses successful snapshots for 24 hours or failed snapshots for 15 minutes. Production keeps it off until `NAG_PERMISSION_STATUS=approved` and `NAG_ON_DEMAND_INGESTION_ENABLED=true` are set explicitly. A successful check means the bounded request completed; it is not represented as an area-wide or historically complete feed.
- Cadastre: dedicated ingestion jobs download AGKK parcel, building, and individual-object archives plus the three matching rights workbooks from an explicit source catalog. Reports perform exact local lookups only. The rights importer retains companies and public/legal organizations, omits masked natural persons, and never re-labels the snapshot as a Property Register result.
- VIES: an exact EIK established by a property-related record is checked through the official European Commission service. Only the dated VAT-validity result and returned company name are retained; the returned address is discarded. VIES is not used as evidence of property or company ownership.

Only HTTPS hosts explicitly allowlisted in `config/data_sources.yml` can be fetched. User input never controls a remote URL.

### AGKK cadastral open data

Property identity and hierarchy facts come from AGKK's `самостоятелни обекти`, `сгради`, and `поземлени имоти` archives. Exact company/public-body rights come from the separate `собственост СОС`, `собственост сгради`, and `собственост ПИ` XLSX archives. Archive selection comes from `CadastreSourceArchive`, independently of NAG. A source archive may still be district-wide because that is the smallest upstream unit; persistence is filtered to cadastral objects already inside the configured supporting-data boundary. Parent parcel and building archives are catalogued explicitly.

Archives are streamed into a size-bounded temporary file while calculating SHA-256, staged under a checksum-addressed key in private S3, imported into PostGIS, and deleted from the Heroku filesystem in an `ensure` block. Only after database publication succeeds does Mesto update the small `latest` S3 manifest. Failed candidates expire after two days and the previous validated object gets a 14-day rollback window; the current artifact is retained for audit and database reconstruction. The importer records source checksum, ETag/Last-Modified when supplied, importer version, coverage-scope digest, row outcomes, validation errors, and the last successful import. PostgreSQL advisory locks prevent concurrent publication of the same source/scope, and a failed transaction leaves the last successful records intact.

SofiaPlan, SofiaPlan ArcGIS, and OpenStreetMap background imports use the same archive contract. Their normalized GeoJSON is serialized canonically, compressed with deterministic gzip metadata, and staged before publication. Production ingestion requires `SOURCE_ARCHIVE_BUCKET` by default; development and tests use a no-op store unless a bucket is configured. AWS credentials use the normal SDK credential chain and must not be committed.

Development uses the explicit `malinova_dolina` profile in `config/coverage_profiles.yml`: a search polygon plus a 2 km supporting-data buffer. Test uses synthetic fixture coverage and blocks external network access. Production uses an enabled Sofia district catalog; entries cannot be enabled until their permission status is approved.

Prepare and import development cadastral coverage explicitly:

```sh
bin/rails cadastre:catalog
bin/rails cadastre:sync_profile
```

The rights importer reads the official XLSX columns for cadastral identifier, right type/description, holder type/name/identifier, and source-document type/description. A checksum-valid EIK creates an exact company node; municipalities, the state, and other non-person organizations use a separate organization node. Rows marked as natural persons are omitted before persistence. The resulting relationship remains explicitly limited: it is a dated cadastral-register snapshot, not a current ownership, title, seller-authority, history, or encumbrance check.

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

Import the configured datasets. Imports upsert stable feature IDs, preserve freshness, account for filtered/rejected rows, and skip an unchanged source/version/scope checksum. Stale rows are retained until a validated explicit prune is implemented for that source:

```sh
bin/rails data_sources:prepare_spatial
bin/rails sofiaplan:sync
bin/rails 'sofiaplan:sync[schools]'
bin/rails arcgis:sync
bin/rails openstreetmap:sync
```

Rebuild normalized data from the latest retained S3 artifacts without contacting an upstream provider:

```sh
bin/rails 'cadastre:replay_retained[CATALOG_ENTRY_ID]'
bin/rails 'sofiaplan:replay_retained[schools]'
bin/rails 'arcgis:replay_retained[functional_zoning]'
bin/rails openstreetmap:replay_retained
```

Imports retain existing records by default. Preview the explicit, recoverable pruning operation before confirming it:

```sh
bin/rails cadastre:prune_outside_scope
bin/rails 'cadastre:prune_outside_scope[DELETE]'
```

Inspect boundaries, freshness, row outcomes, completeness, and permission states with `bin/rails coverage:status`. `sidekiq-cron` runs `RefreshPreparedDataJob` every Sunday at 03:00 Europe/Sofia. Successful checks download the source to compare its checksum; an old successful import is not treated as permanently fresh.

Recurring jobs are defined in `config/initializers/sidekiq.rb`. Every Sidekiq startup creates or updates those definitions in Redis and removes stale Mesto-owned cron entries, so a deploy is enough to apply schedule changes. Keep at least one Sidekiq worker running; Heroku Scheduler and manual schedule setup are not required.

Run any valid cadastral identifier synchronously from the command line:

```sh
bin/rails 'mesto:analyze[68134.1000.2000.1.5]'
```

For the requested live acceptance lookup, replace the example with the acceptance identifier and keep `DATA_SOURCE_MODE=live`.

## Payment prototype

The only catalog product is `full_property_report`, priced server-side at 2,490 euro cents. The browser never submits price or currency. With `PAYMENT_PROVIDER=fake` and `FAKE_PAYMENTS_ENABLED=true`, checkout exposes success, failure, and cancellation controls without card fields. Success is idempotent and unlocks the report for anyone holding its public UUID URL.

Checkout is offered only when every currently supported, applicable source check completed successfully and the resulting report contains a meaningful paid section. Contract-only Commercial Register enrichment, restricted Property Register automation, and VIES when no exact EIK exists are explicitly non-blocking and are labelled separately in the source list. A failed or unavailable supported source leaves the partial findings visible, marks dependent calculations as unavailable instead of zero, and disables checkout.

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
- NAG public HTML/Kendo contracts are undocumented and are not treated as a complete area feed. Development can exercise exact-identifier checks end to end; production remains disabled until permission is approved explicitly.
- AGKK archive availability and reuse permissions must be reviewed before enabling production-wide ingestion. Similar identifiers are never used to infer a match; all hierarchy records and geometry are joined by exact cadastral identifiers.
- SofiaPlan amenity datasets currently available through the catalog are dated; every date is displayed, and snapshots older than two years are never presented as current amenity counts.
- The fallback MapLibre demo style is not a production tile service.
- Reports are link-based and have no accounts, emails, PDF export, document uploads, valuation, listing imports, or LLM-generated conclusions.

The remaining external dependencies are product/legal: approve NAG production access and obtain contractual Commercial Register access. Property Register automation remains restricted to authorized public institutions; AGKK right-holder snapshots are intentionally kept distinct from a current title or encumbrance reference.

## Education catalog and anonymous journeys

Bulgarian educational content, source metadata, deterministic recommendation rules, and checklist definitions live in `content/education`. Validate keys, slugs, required sections, source references, and allowlisted rule conditions with:

```sh
bin/rails education:validate
```

Personal learning plans do not require an account. A random guest identity is stored in a signed, HTTP-only, same-site cookie; only its SHA-256 digest is stored with server-side journey rows. Public report tokens do not authorize access to a journey. Private buyer stage, financing context, labels, and progress are never rendered into shared reports.

Anonymous journeys default to 180 days from last activity. Configure `ANONYMOUS_JOURNEY_RETENTION_DAYS`. `sidekiq-cron` runs the cleanup daily at 04:00 Europe/Sofia; it can also be invoked manually with:

```sh
bin/rails education:prune_anonymous_journeys
```

Professional review metadata remains `pending` until a real qualified review is recorded. Educational pages explain current source coverage and never treat a missing public result as proof that a document does not exist.

Administrative-act references now distinguish an identifier printed in the record (`document`) from the identifier merely used to query a registry (`search_query`). Only the former can support a building milestone. Pre-existing references are deliberately left unclassified and therefore do not support milestone inference until the relevant analysis is refreshed.
