# OpenOwnership Register

The application can be run in a local development environment or through
Docker.

## Installation

Install the version of ruby specified in ./.ruby-version using your favourite ruby version manager.

Install and run bundler

    gem install bundler
    bundle

Create `.env.local` and add in your `OPENCORPORATES_API_TOKEN`. To get an API token go to https://opencorporates.com/users/account, click 'Get Account', click 'Sign up' under 'Public Benefit' and fill in the form (content is not important). Someone will then approve your request and you'll be emailed a key.

Override any other settings from `.env` in the new `.env.local` file.

### Running locally

Install and run mongodb, elasticsearch and mailcatcher

    brew install mongodb
    brew services start mongodb
    brew install elasticsearch
    brew services start elasticsearch
    gem install mailcatcher

Run setup command, which will create, seed and add indexes to the DB and elasticsearch

    ./bin/setup

Run the tests

    rake

Run the server

    rails server

### Running with Docker

Build and start the containers

    compose/up

Shell into the app

    compose/shell

In the shell, run the tests

    rake

The server will already be running

## Import more data

The above will create a few example records, but you can import a subset of real data, by running:

    rake postdeploy

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
