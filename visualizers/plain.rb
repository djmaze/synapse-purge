# frozen_string_literal: true

module Visualizers
  class Plain < Visualizer
    def begin
      STDOUT.sync = true

      puts
      puts "Purging events since #{since} (#{since.to_i * 1000}) in #{rooms.count} rooms"
      @start = Time.now
    end

    def end
      @end = Time.now
      duration = Time.at(@end - @start).utc.strftime('%H:%M:%S')

      puts "Event purge finished in #{duration} seconds"
    end

    def room_begin(room)
      puts room
    end

    def room_fail(room, reason)
      warn "#{room}: #{reason}"
    end
  end
end
