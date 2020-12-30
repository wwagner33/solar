source "http://rubygems.org"

ruby "2.3.8"

#gem "rails", "~> 3.2.16"
gem 'rails', '4.0.13'
gem "rack", "~> 1.5.2"
gem "rake", "~> 10.1.1"
gem "pg", "~> 0.21.0"
gem "foreigner", "~> 1.4.0"

# gem "koala", "1.2.0" # facebook

gem "devise", "~> 3.4.1"
gem "devise-i18n", "~> 0.11.3"
gem "cancan", "~> 1.6.10"
gem "devise-encryptable", "~> 0.2.0"

gem "chronic", "0.6.1"
#gem "brazilian-rails", "~> 3.3.0"
gem 'simple_form', "~> 3.1.0"

gem "paperclip", "~> 3.4.2"
gem "will_paginate", "~> 3.0.7"
gem "jquery-rails", "~> 2.2.2"
gem "fancybox2-rails", "~> 0.2.5"

gem "haml", "~> 4.0.5"
gem "haml-rails", "~> 0.4.0", group: :development
# gem "ckeditor", "~> 4.0.11"
gem "ckeditor", ">= 4.2.4"

gem "fullcalendar-rails", "~> 1.6.4.0"
gem "momentjs-rails", "~> 2.8.3"

gem "bigbluebutton-api-ruby", "~> 1.6.0"

# platform adicionado para evitar que o unicorn tente ser executado no windows
gem "puma", "~> 4.3.5"

gem "rubyzip", "~> 1.0.0"

gem "doorkeeper", "~> 1.4.1"
gem "rack-oauth2", "~> 1.0.7"
gem "grape", "~> 0.17.0"
gem "rabl", "~> 0.13.0"
gem "grape-rabl", "~> 0.4.2"

gem "savon", "~> 2.0" # comunicação com ws

gem "roo", "~> 1.13.2"  # csv, excel
gem "prawn", "~> 2.0.1" # pdf
gem "prawn-table", "~> 0.2.2"
#gem "pdfkit" #pdf
gem "wicked_pdf", "~> 1.1.0"
gem "wkhtmltopdf-binary", "~> 0.12.3" #pdf

gem "em-websocket", "~> 0.5.1" # websocket pros fóruns

# gem "strong_parameters", "~> 0.2.3" # a partir do rails 4 ele faz parte do rails core

gem 'hairtrigger', '~> 0.2.12' # triggers

gem 'nested_form_fields', '~> 0.8.2'
gem "coffee-rails", "~> 4.2.2"

gem "rest-client", "~> 2.0.2"

gem "rufus-scheduler", "~> 3.4.2"

# fila de emails
gem "daemons"
gem "delayed_job_active_record", "~> 4.1.2"

gem "activerecord-session_store", "~> 1.1.0"

# add these gems to help with the transition:
gem 'protected_attributes', '~> 1.0.9'
#gem 'rails-observers'
gem "actionpack", "4.0.13"
gem "actionpack-page_caching", "~> 1.1.0"
gem "actionpack-action_caching", "~> 1.2.0"

gem "execjs"
gem "therubyracer", platforms: :ruby
gem "uglifier", "~> 1.3.0"
gem "sass-rails", "~> 4.0.0"
gem "compass-rails", "~> 1.1.7"

gem "htmlentities", "~> 4.3.4"
gem "newrelic_rpm"

gem "dotenv-rails"

group :development do
  gem "foreman", require: false

  gem "sshkit-sudo" # usar sudo no capistrano
  gem "capistrano"
  gem "capistrano-rails"
  gem "capistrano3-delayed-job"
  gem "capistrano-nvm"
  gem "capistrano-rvm"
  gem "capistrano3-puma"
  gem "capistrano3-nginx"
  gem 'capistrano-dotenv-tasks', require: false

  gem "rb-readline", "~> 0.5.1"
  gem "spork", "~> 0.9.2"
  # gem "thin" # server local melhor
  gem "better_errors", "~> 2.4.0"
  gem "binding_of_caller", "~> 0.8.0" # better 'better errors'
  gem "quiet_assets", "~> 1.1.0" # nao mostra log de assets em development
  gem "rack-mini-profiler", "~> 0.10.7"
  # For memory profiling (requires Ruby MRI 2.1+)
  gem "memory_profiler", "~> 0.9.10"

  # For call-stack profiling flamegraphs (requires Ruby MRI 2.0.0+)
  gem "flamegraph", "~> 0.9.5"
  gem "stackprof", "~> 0.2.11"     # For Ruby MRI 2.1+
  gem "fast_stack", "~> 0.2.0"    # For Ruby MRI 2.0

  gem "cpf_utils", "~> 1.2.1"
  gem "faker", "~> 1.8.7"
end

group :development, :test do
  gem "awesome_print"
  gem "pry-rails"
  gem "pry-rescue"
  gem "factory_girl_rails", "~> 4.2.1"
  gem "rspec-rails", "~> 3.4.0"
  gem 'test-unit', '~> 3.1.5'
  gem "rubocop", "~> 0.52.1", require: false # A Ruby static code analyzer, based on the community Ruby style guide.
end

group :test do
  gem "webrat", "0.7.3"
  gem "capybara", "~> 2.18.0"
  gem "database_cleaner", "0.7.2"
  gem "cucumber-rails", "~> 1.4.3", require: false
  gem "selenium-webdriver", "~> 2.42.0"
  gem "launchy", "2.1.0"
  gem "nokogiri", "1.10.10" # html, css parser (search)
  # gem "spreewald", "0.8.4" # collection of cucumber steps
  gem "simplecov", "~> 0.15.1", require: false # cobertura de testes
end
