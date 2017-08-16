OpenOwnership Register
======================

Installation
------------

Install the version of ruby specified in ./.ruby-version using your favourite ruby version manager.

Install and run bundler

    gem install bundler
    bundle

Create `.env.local` and add in your `OPENCORPORATES_API_TOKEN`.
To get an API token go to https://opencorporates.com/users/account, click
'Get Account', click 'Sign up' under 'Public Benefit' and fill in the form
(content is not important). Someone will then approve your request and you'll
be emailed a key.

Override any other settings from `.env` in the new `.env.local` file.

Install and run mongodb, elasticsearch and mailcatcher

    brew install mongodb
    brew services start mongodb
    brew install elasticsearch
    brew services start elasticsearch
    gem install mailcatcher

Run setup command, which will create, seed and add indexes to the DB and elastic search.

    ./bin/setup

Run the tests

    rake

Run the server

    rails server

Import more data
----------------

The above will create a few example records, but you can import a subset of real data, by running:

    rake postdeploy
