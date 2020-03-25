# frozen_string_literal: true

require 'open3'
require 'tempfile'

class CompressWorker
  attr_reader :rooms, :db, :max_active, :minimum_rows
  attr_writer :visualizer
  attr_accessor :binary

  def initialize(db, rooms, binary:, max_active: 3, minimum_rows: 1000)
    @db = db
    @rooms = rooms
    @binary = binary

    self.max_active = max_active
    self.minimum_rows = minimum_rows
  end

  def visualizer
    @visualizer ||= Visualizers::Plain.new(self)
  end

  def max_active=(max_active)
    # Not a good idea to run too many parallel compressions,
    # the memory usage of the compressor spikes hard
    max_active = 1 if max_active <= 0
    max_active = 3 if max_active > 3

    @max_active = max_active
  end

  def minimum_rows=(minimum_rows)
    minimum_rows = 0 if minimum_rows.negative?

    @minimum_rows = minimum_rows
  end

  def run
    to_compress = rooms.dup
    active = {}

    visualizer.begin

    loop do
      break if active.empty? && to_compress.empty?

      if active.count < max_active && to_compress.any?
        room = to_compress.shift

        begin
          thread = Thread.new do
            compress_room(room)
          end
          thread.report_on_exception = false

          visualizer.room_begin room
        rescue StandardError => e
          visualizer.room_fail room, "#{e.class}: #{e.full_message}"

          to_compress.push room
          next
        end

        active[room] = thread
      end

      active.each do |room, thread|
        begin
          next if thread.alive?

          thread.value
        rescue StandardError => e
          visualizer.room_fail room, "#{e.class}: #{e.message}"
          true
        end

        visualizer.room_end room
        active.delete room
      end

      visualizer.update
      sleep 0.5
    end

    visualizer.end
  end

  private

  def compress_room(room)
    temp = Tempfile.new(['compress', '.sql'])
    temp.close

    cmd = format(
      "%<binary>s -p '%<uri>s' -r '%<room>s' -o '%<out>s' -m %<min>d -t",
      binary: @binary,
      uri: db.uri,
      room: room,
      out: temp.path,
      min: minimum_rows
    )

    out, status = Open3.capture2e(cmd)
    result = parse_compress(out, status)

    raise result[:error] if !status.success? && !result[:error].nil?

    sql = File.read temp.path
    if sql.empty?
      regained = result[:after] - result[:before]
      formatstr = if regained.zero?
                    'Skipping compression, would not regain any rows.'
                  elsif regained.negative?
                    'Skipping compression, would result in more rows.'
                  else
                    'Skipping compression, would regain %<rows>d rows.'
                  end

      visualizer.room_message room, format(
        formatstr,
        rows: regained
      )
      return
    end

    visualizer.room_message room, format(
      'Compressing %<before>d to %<after>d (%<percentage>.2f%%)',
      result
    )

    begin
      db.conn.exec sql
    rescue PG::SyntaxError
      FileUtils.copy(temp.path, '/tmp/error.sql')
      puts 'Copied broken SQL to /tmp/error.sql'

      raise
    end
  ensure
    temp.unlink
  end

  def parse_compress(output, status)
    before = output.scan(/rows in current table:\s*(\d+)/).flatten.first.to_i
    after = output.scan(/after compression:\s*(\d+)/).flatten.first.to_i
    perc = output.scan(/after compression:.*\(([0-9.]+)%\)/).flatten.first.to_f

    error = output.scan(/thread '\w+' panicked at '(.*)'/).flatten.first
    error ||= output.split.last unless status.success?

    { before: before, after: after, percentage: perc, error: error }
  end
end
