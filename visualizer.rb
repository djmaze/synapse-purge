# frozen_string_literal: true

class Visualizer
  attr_reader :worker

  def initialize(worker)
    @worker = worker
  end

  def begin; end

  def update; end

  def end; end

  def message(message); end

  def room_begin(room); end

  def room_fail(room, reason); end

  def room_end(room); end

  def room_message(room, message); end

  protected

  def rooms
    worker.rooms
  end
end

module Visualizers
  autoload :Dummy, './visualizers/dummy'
  autoload :Plain, './visualizers/plain'
  autoload :Verbose, './visualizers/verbose'
end
