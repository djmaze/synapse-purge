#!/usr/bin/env ruby

require 'bundler/setup'
require 'dotenv/load'
require 'matrix_sdk'
require 'ruby-progressbar'

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
days = ENV.fetch('DAYS_TO_KEEP', 120).to_i
since = Time.now - (24 * 60 * 60 * days)
max_active = ENV.fetch('MAX_ACTIVE_PURGES', 5).to_i

puts 'Fetching rooms from DB...'
rooms = db.rooms
max_active = rooms.count if max_active <= 0

progressbar = ProgressBar.create \
  format: '%c/%C %t (%p%%) |%B| %a',
  title: 'Purged'
progressbar.total = rooms.count

header = "Purging events since #{since} (#{since.to_i * 1000}) in #{rooms.count} rooms...\n"
total = header

# STDOUT.sync = true

max_width = 0
purges = rooms.map do |r|
  w = r.to_s.size
  max_width = w if w > max_width
  { room: r, id: nil, status: :not_started }
end

iter = 0
loop do
  iter += 1
  unstarted = purges.select { |p| p[:status] == :not_started }.count
  active = purges.select { |p| p[:status] == :active }.count

  total = header + "\n" \
    + purges.map do |p|
      "%<room>#{max_width}s => %<status>s %<message>s" % {
        room: p[:room].to_s,
        status: p[:status],
        message: p[:message]
      }
    end.join("\n") + "\n\n"

  Gem.win_platform? ? (system 'cls') : (system 'clear')
  progressbar.log total

  break if active.zero? && unstarted.zero?

  if active < max_active && unstarted > 0
    entry = purges.select { |p| p[:status] == :not_started }.first
    room = entry[:room]

    begin
      purge_id = client.enqueue_room_purge(room.id, since)
      entry[:id] = purge_id
      entry[:status] = :active
    rescue MatrixSdk::MatrixRequestError => e
      # warn "error purging #{room}: #{e.message}"
      entry[:status] = :skipped
      entry[:message] = e.message

      progressbar.increment
    rescue MatrixSdk::MatrixConnectionError => e
      # Connection error, shift to end
      entry[:message] = e.to_s
      # else
      # client.wait_for_purge_completion(purge_id)
    end

    purges.delete entry
    purges << entry
  end

  if (iter % 5).zero?
    purges.each do |p|
      next unless p[:status] == :active

      begin
        p[:status] = client.get_purge_status(p[:id])

        progressbar.increment if p[:status] != :active
      rescue StandardError
      end
    end
  end

  sleep 1
end

client.logout
