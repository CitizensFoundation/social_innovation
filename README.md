Social Innovation is a web based platform that enables groups of people to define their democratic ideas and together discover which are the most important ideas to implement by their instances.  People can add new ideas, add arguments for and against ideas, indicate if they support or oppose an idea, create a personal list of ideas and discuss all ideas. The end results are lists of top ideas in many categories as well as the best arguments for and against each idea. This service enables people to make up their minds about most issues in a short time.

Social Innovation (Opna lýðræðiskerfið) is a merge between:

NationBuilder by Jim Gilliam
"http://www.jimgilliam.com/":http://www.jimgilliam.com/

* Jim's Nationbuilder has itself evolved into an excellent political campaign website
"http://www.nationbuilder.com/":http://www.nationbuilder.com/

and

Open Direct Democracy by Róbert Viðar Bjarnason and Gunnar Grimsson
"http://github.com/rbjarnason/open-direct-democracy":http://github.com/rbjarnason/open-direct-democracy

Installation
============

Ruby
----

First you'll want to install your own Ruby (if you haven't already). There are
a few ways to do that. The rest of this guide assumes you use bash and RVM.

First you install RVM (Ruby Version Manager):

````bash
$ bash -s stable < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer)
````

Then reload your environment:

````bash
$ source ~/.bash_profile
````

Find out what dependencies are needed for Ruby (MRI) and install them:

````bash
$ rvm requirements
````

Install and use Ruby 1.9.3

````bash
$ rvm install 1.9.3
$ rvm use 1.9.3 --default
````

Install Bundler

````bash
$ gem install bundler
````

Install thinking-sphinx

````bash
$ sudo aptitude install sphinxsearch
````

Set up social-innovation
----------------------------

````bash
$ git clone https://github.com/rbjarnason/social-innovation.git
$ cd social-innovation
````

Install all the dependencies

````bash
$ bundle install
````

Modify database.yml and fill in your MySQL database credentials

````bash
$ $EDITOR config/database.yml
````

Then create and seed the database

````bash
bundle exec rake db:drop db:create db:schema:load tr8n:import_db db:seed --trace
````

Recreate tr8n from scratch

````bash

rake tr8n:init tr8n:import_and_setup_iso_3166
````

Run social-innovation
-------------------------

Finally, start the rails server:

````bash
$ rails server
````

Testing social-innovation
-------------------------

First set up the test database and start the test server

````bash
$ RAILS_ENV=test bundle exec rake db:drop db:create db:schema:load tr8n:init tr8n:import_and_setup_iso_3166
$ bundle exec rails server -e test
````

Then run the tests

````bash
# run all tests
$ bundle exec rake test

# run one test
$ bundle exec ruby -Ilib:test test/integration/navigation.rb
````

Deploying social-innovation
---------------------------

Install RVM, Ruby, Bundler, and thinking-sphinx on your server(s) as described
above.

Set up Phusion Passenger as described by http://www.modrails.com/install.html.

Edit config/deploy.rb to fit your server configuration.

Setup the deployment environment:

````bash
$ bundle exec cap deploy:setup
````

Then copy `config/database.yml`, `config/newrelic.yml`, and `config/facebooker.yml`
to `sites/social-innovation/shared/` on the app server(s)

Then deploy the application:

````bash
$ bundle exec cap deploy
````
