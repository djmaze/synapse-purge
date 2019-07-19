#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'matrix_sdk'

require './purge_worker'
require './visualizer'
require './synapse_client'
require './synapse_db'

puts 'Setting up DB link...'
db = SynapseDb.new ENV.fetch('DATABASE_URL')

puts 'Setting up Synapse link...'
client = SynapseClient.new(
  url: ENV.fetch('HOMESERVER_URL'),
  token: ENV.fetch('ADMIN_TOKEN', nil),
  username: ENV.fetch('ADMIN_USERNAME', nil),
  password: ENV.fetch('ADMIN_PASSWORD', nil)
)

# Read environment variables
days = ENV.fetch('DAYS_TO_KEEP', 120).to_i
since = Time.now - (24 * 60 * 60 * days)
max_active = ENV.fetch('MAX_ACTIVE_PURGES', 5).to_i
verbose = ENV.fetch('VERBOSE', 0).to_i == 1
ignore_local = ENV.fetch('IGNORE_LOCAL', 1).to_i == 1

puts 'Fetching rooms from DB...'
rooms = db.rooms

purge_client = PurgeWorker.new client, rooms,
                               ignore_local: ignore_local,
                               max_active: max_active,
                               since: since

purge_client.visualizer = Visualizers::Verbose.new(purge_client) if verbose

puts 'Starting purge...'
purge_client.run

client.logout
