#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'uri'
require 'matrix_sdk'

require './compress_worker'
require './purge_worker'
require './synapse_client'
require './synapse_db'
require './visualizer'

puts 'Setting up DB link...'
db = SynapseDb.new ENV.fetch('DATABASE_URL')

# Read environment variables
days = ENV.fetch('DAYS_TO_KEEP', 120).to_i
since = Time.now - (24 * 60 * 60 * days)
max_active = ENV.fetch('MAX_ACTIVE_PURGES', 5).to_i
ignore_local = ENV.fetch('IGNORE_LOCAL', 1).to_i == 1
compress_binary = ENV.fetch('COMPRESS_BINARY', nil)
min_compress_count = ENV.fetch('MIN_COMPRESS_COUNT', 1000).to_i

verbose = ENV.fetch('VERBOSE', 0).to_i == 1
silent = ENV.fetch('SILENT', 0).to_i == 1

run_purge = ENV.fetch('RUN_PURGE', 1).to_i == 1
run_compress = ENV.fetch('RUN_COMPRESS', 1).to_i == 1


puts 'Fetching rooms from DB...'
rooms = db.rooms

if run_purge
  puts 'Setting up Synapse link...'
  client = SynapseClient.new(
    url: ENV.fetch('HOMESERVER_URL'),
    token: ENV.fetch('ADMIN_TOKEN', nil),
    username: ENV.fetch('ADMIN_USERNAME', nil),
    password: ENV.fetch('ADMIN_PASSWORD', nil)
  )

  purge_client = PurgeWorker.new client, rooms,
                                 ignore_local: ignore_local,
                                 max_active: max_active,
                                 since: since

  if silent
    purge_client.visualizer = Visualizers::Dummy.new(purge_client)
  elsif verbose
    purge_client.visualizer = Visualizers::Verbose.new(purge_client)
  end

  puts 'Starting purge...'
  purge_client.run

  client.logout
end

if run_compress
  raise 'No compression binary specified' unless compress_binary
  raise 'Invalid compress binary' unless File.executable?(compress_binary)
  unless Gem::Dependency.new('synapse-compress-state', '~> 0.1')
                        .match?(*`#{compress_binary} --version`.split)
    raise 'Invalid compress version given, needs at least 0.1.0'
  end

  compress_client = CompressWorker.new db, rooms,
                                       max_active: max_active,
                                       minimum_rows: min_compress_count,
                                       binary: compress_binary

  if silent
    compress_client.visualizer = Visualizers::Dummy.new(compress_client)
  elsif verbose
    compress_client.visualizer = Visualizers::Verbose.new(compress_client)
  end

  puts 'Starting compression...'
  compress_client.run
end
