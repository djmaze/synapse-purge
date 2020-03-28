# frozen_string_literal: true

class PurgeWorker
  attr_reader :client, :rooms, :max_active
  attr_writer :visualizer
  attr_accessor :since

  def initialize(client, rooms,
                 ignore_local: true,
                 max_active: 5,
                 since: 24 * 60 * 60)
    if ignore_local
      local_domain = MatrixSdk::MXID.new(client.client.mxid).domain
      rooms = rooms.reject do |r|
        r = MatrixSdk::MXID.new r.to_s
        r.domain == local_domain
      end
    end

    @client = client
    @rooms = rooms
    self.max_active = max_active
    @since = since
  end

  def visualizer
    @visualizer ||= Visualizers::Plain.new(self)
  end

  def max_active=(max_active)
    max_active = rooms.count if max_active <= 0

    @max_active = max_active
  end

  def run
    to_purge = rooms.dup
    active = {}
    tick = 0 # To not update the purge status too often

    visualizer.begin

    loop do
      break if active.empty? && to_purge.empty?
      tick += 1

      # Start another purge if below maximum active
      if active.count < max_active && to_purge.any?
        room = to_purge.shift

        begin
          purge_id = client.enqueue_room_purge(room, since)
          visualizer.room_begin(room)

        # HTTP 4xx means a purge is either running or not able to run,
        # so skip the current room
        rescue MatrixSdk::MatrixRequestError => e
          visualizer.room_fail(room, "#{e.class}: #{e.message}")
          visualizer.room_end(room)
          next

        # Don't skip the purge on HTTP 5XX or connection errors
        rescue MatrixSdk::MatrixConnectionError => e
          visualizer.room_fail(room, "#{e.class}: #{e.message}")
          to_purge.push(room)
          next
        rescue EOFError => e
          visualizer.room_fail(room, e.to_s)
          to_purge.push(room)
          next
        end

        # If only allowing one purge at the same time, skip the multi-purge code
        if max_active == 1
          client.wait_for_purge_completion(purge_id) { visualizer.update }
          visualizer.room_end(room)
          next
        end

        active[room] = purge_id
      end

      if tick >= 10
        tick = 0

        # Check for finished - or failed - purges
        active.each do |room, purge_id|
          if room.nil? || purge_id.nil?
            active.delete room
            next
          end

          begin
            next unless client.purge_finished?(purge_id)

            active.delete(room)
            visualizer.room_end(room)
          rescue StandardError => e
            ## Makes output a bit too spammy during connection failures or
            ## Synapse overloads
            # visualizer.room_fail room, e.to_s
            true
          end
        end
      end

      visualizer.update
      sleep 0.5
    end

    visualizer.end
  end
end
