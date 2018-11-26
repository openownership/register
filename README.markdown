# OpenOwnership Register

## Setup

Install the version of ruby specified in `.ruby-version` using your favourite ruby version manager.

Install and run bundler:

```bash
gem install bundler
bundle
```

Create an `.env.local` and add in the various required env vars from `.env` – generally, you can use config values from the Heroku app `openownership-register-staging`.

For data stores and other local services, you can use Docker Compose:

```bash
docker-compose up -d
```

Alternatively, you can use your own local method for running these services. See the `docker-compose.yml` file for the required services and versions, and the `.env` file for expected config.

Run the setup command, which will create, seed and add indexes to the DB and elasticsearch

```bash
bin/setup
```

Then you're ready to use the usual `rails` commands (like `rails serve`) to run / work with the app.

To run tests:

```bash
bundle exec rspec
```

## Import more data

The above will create a few example records, but you can import a subset of real data, by running:

```bash
rake postdeploy
```

## Writing an importer

Importers are intended to run multiple times and so must be idempotent. If the source data itself is idempotent (i.e. it doesn't matter which order records are imported), then importers can be parallelised.

## Running a PSC import on production

Below are the sets of steps required to run a full PSC import on production.

**Initial assumptions / prerequisites:**

- Track each PSC import in a separate ticket on JIRA (may need scheduling into a sprint, etc.) – this is where stats, timestamps, special instructions, etc. can be noted down.
- No other import is currently running or has been triggered to run.
- No worker dyno is currently running.
- All Heroku stuff below can be carried out in the Heroku console for the [production app](https://dashboard.heroku.com/apps/openownership-register)
- To access a Rails console to the production app you can run:
  - `heroku run --app openownership-register bin/rails c`

**Before triggering the import:**

1. Make a backup of the MongoDB database via the mLabs console (from the Heroku console).
1. Upgrade the `openredis` instance to the `Large` plan in the Heroku console (give this a few mins to get set up and for dyno(s) to restart).
1. Note down the current `Entity.count` and `Relationship.count` via the Rails console.
1. Open the Papertrail console (via the Heroku console) to monitor logs.
1. Open the [sidekiq admin panel](https://register.openownership.org/admin/sidekiq) to monitor the background jobs.
   - The login details for this can be found via the Config Vars for the production app, in the Heroku console.

**Trigger, run and monitor the import:**

1. Trigger the import:
   - `heroku run --app openownership-register bin/rails psc:trigger`
1. Now turn on **1** worker dyno, making sure it's a `performance-l`.
1. Note down the time the worker was started.
1. Monitor the status of the import via the Sidekiq admin panel + Papertrail logs.
   - Look for failed jobs, or errors in the log, etc.
   - The full import takes roughly 20 hours, so don't need to constantly monitor things!

**After the import has completed:**

Once all jobs have been processed in the Sidekiq admin panel…

1. Shut down the worker dyno in the Heroku console so no workers are running.
1. Downgrade the `openredis` instance to the `Micro` plan.
1. From the logs, note down the timestamp when the last worker job finished and note down how long the whole import took.
1. Note down the new `Entity.count` and `Relationship.count` and note down the differences (can share these with the team on Slack if substantial).
1. Run the `EntityIntegrityChecker` – see below for instructions – and then note down the final results from the logs.

## The `EntityIntegrityChecker`

… is used to detect various potential issues with entities in the database.

Currently, all issues detected + a final summary are outputted to the log.

It doesn't perform any fixes, but it can be used as the basis for a script / rake task that performs fixes as it emits issues, to be handled separately. See examples under `lib/tasks/migrations`.

Most of the checks are specific to _legal entities_, but some may also be for _natural persons_. Where a check is for both a `type` value will be outputted in the individual log lines.

To run the checker in production:

```bash
heroku run:detached -s performance-m --app openownership-register time bin/rails runner "EntityIntegrityChecker.new.check_all"
```
