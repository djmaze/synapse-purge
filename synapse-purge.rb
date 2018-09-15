#!/usr/bin/env ruby

require 'bundler/setup'
require 'dotenv/load'
require 'matrix_sdk'

require './synapse_client'
require './synapse_db'

db = SynapseDb.new ENV.fetch('DATABASE_URL')
client = SynapseClient.new(
  url: ENV.fetch('HOMESERVER_URL'),
  username: ENV.fetch('ADMIN_USERNAME'),
  password: ENV.fetch('ADMIN_PASSWORD')
)
days = ENV.fetch('DAYS_TO_KEEP', 120).to_i
since = Time.now - (24*60*60*days)
rooms = db.rooms

STDOUT.sync = true
puts "Purging events since #{since.to_s} (#{since.to_i * 1000}) in #{rooms.count} rooms"

rooms.each do |room|
  puts(room)

  begin
    purge_id = client.enqueue_room_purge(room.id, since)
  rescue MatrixSdk::MatrixRequestError => e
    STDERR.puts "error purging #{room}: #{e.message}"
  else
    client.wait_for_purge_completion(purge_id)
  end
end

puts "Done."
