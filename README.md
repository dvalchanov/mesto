# PropertyLens

PropertyLens is the Rails foundation for a Bulgarian property-intelligence platform. This repository intentionally contains no domain models or product features yet.

## Stack

- Ruby 3.4.7 and Rails 8.1.3.1
- PostgreSQL 17 with PostGIS 3.5
- Hotwire (Turbo and Stimulus), Importmap, and Tailwind CSS 4
- Sidekiq 8 with Redis 7.2
- RSpec, FactoryBot, Capybara, and Selenium
- RuboCop with Rails Omakase defaults

## Requirements

- Ruby 3.4.7 (see `.ruby-version`)
- Bundler
- Docker with Docker Compose
- Google Chrome for the browser-backed system specs

## Initial setup

```sh
git clone <repository-url> property-lens
cd property-lens
cp .env.example .env
```

Replace the placeholder password in `.env`, then install gems and start the local dependencies:

```sh
bundle install
docker compose up -d
bin/rails db:prepare
```

`db:prepare` creates the development and test databases, runs migrations, enables PostGIS, and writes `db/schema.rb`. The PostGIS adapter preserves spatial column definitions in the conventional Rails schema format without requiring a host `pg_dump` matching the container's PostgreSQL version.

The upstream `postgis/postgis` image is currently published for amd64, so Compose explicitly uses that platform. Docker Desktop transparently emulates it on Apple silicon.

You can also use the idempotent setup script after the dependencies are running:

```sh
bin/setup --skip-server
```

## Run the application

Run the web server, Tailwind watcher, and Sidekiq together:

```sh
bin/dev
```

PropertyLens will be available at <http://localhost:3000>.

To run processes separately:

```sh
bin/rails server
bin/rails tailwindcss:watch
bundle exec sidekiq -C config/sidekiq.yml
```

Stop the local dependencies with `docker compose down`. Add `--volumes` only when you intentionally want to delete local PostgreSQL and Redis data.

## Test and lint

```sh
bin/rspec
bin/rubocop
```

Run the same local checks as CI with:

```sh
bin/ci
```

The PostGIS integration spec verifies both `geography` and `geometry` columns through Active Record. To inspect the installed PostGIS version manually:

```sh
bin/rails runner 'puts ActiveRecord::Base.connection.select_value("SELECT PostGIS_Version()")'
```

## Configuration

Development and test read connection settings from `.env` through `dotenv-rails`. `.env` files and Rails key files are ignored; `.env.example` contains placeholders only.

Production expects environment variables or Rails credentials. At minimum, configure `DATABASE_URL`, `REDIS_URL`, and the Rails secret/credentials key used by the deployment. A normal `postgres://` or `postgresql://` `DATABASE_URL` is normalized to the `postgis` Active Record adapter by `config/database.yml`.

Active Job uses Sidekiq in development and production and Rails' test adapter in the test environment. The production Action Cable adapter also uses `REDIS_URL`.

## Continuous integration

`.github/workflows/ci.yml` provisions PostGIS and Redis services, installs the locked Ruby gems, prepares the test database, runs RSpec (including the browser system spec and PostGIS adapter check), and runs RuboCop.
