OpenOwnership Register
======================

Installation
------------

Install the version of ruby specified in ./.ruby-version using your favourite ruby version manager.

Install and run bundler

    gem install bundler
    bundle

Copy .env.example to .env

    cp .env.example .env

The only variable that needs changing in .env is `OPENCORPORATES_API_TOKEN`. You can find or create your API key at https://opencorporates.com/users/account, then copy it into your .env file.

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
