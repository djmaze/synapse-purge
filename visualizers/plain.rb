# frozen_string_literal: true

module Visualizers
  class Plain < Visualizer
    def begin
      STDOUT.sync = true

      puts
      puts "Processing #{rooms.count} rooms..."
      @start = Time.now
    end

    def end
      @end = Time.now
      duration = Time.at(@end - @start).utc.strftime('%H:%M:%S')

      puts "Finished in #{duration} seconds"
    end

    def message(message)
      puts message
    end

    def room_begin(room)
      puts room
    end

    def room_fail(room, reason)
      warn "#{room}: #{reason}"
    end

    def room_message(room, message)
      puts "#{room}: #{message}"
    end
  end
end
