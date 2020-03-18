# frozen_string_literal: true

require 'ruby-progressbar'

module Visualizers
  class Verbose < Visualizer
    attr_accessor :max_width

    def begin
      @max_width = 0
      rooms.each do |r|
        w = r.to_s.size
        @max_width = w if w > @max_width
      end

      puts
      progressbar.total = rooms.count
    end

    def update
      progressbar.refresh
    end

    def end
      progressbar.refresh
    end

    def message(message)
      progressbar.log message
    end

    def room_begin(room)
      progressbar.log format('%<room>s: begun',
                             room: room.to_s.rjust(max_width))
    end

    def room_fail(room, reason)
      progressbar.log format('%<room>s: errored, %<reason>s',
                             room: room.to_s.rjust(max_width),
                             reason: reason)
    end

    def room_end(room)
      progressbar.log format('%<room>s: done',
                             room: room.to_s.rjust(max_width))
      progressbar.increment
    end

    def room_message(room, message)
      progressbar.log format('%<room>s: %<message>s',
                             room: room.to_s.rjust(max_width),
                             message: message)
    end

    def progressbar
      @progressbar ||= ProgressBar.create \
        format: '%c/%C %t (%p%%) |%B| %a',
        title: 'Processed'
    end
  end
end
