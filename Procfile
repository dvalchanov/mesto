release: bin/rails db:prepare
web: bin/thrust bin/rails server
worker: bundle exec sidekiq -C config/sidekiq.yml
