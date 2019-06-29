# frozen_string_literal: true

require 'erb'

class SynapseClient
  STATUS_CHECK_DELAY_IN_SECONDS = 0.5

  def initialize(url:, token: nil, username: nil, password: nil)
    @client = MatrixSdk::Client.new url

    if token
      @client.access_token = token
    else
      @client.login username, password, no_sync: true
    end
  end

  def logout
    @client.logout
  end

  def enqueue_room_purge(room_id, since)
    result = @client.api.request(
      :post,
      :client_r0, "/admin/purge_history/#{ERB::Util.url_encode room_id}",
      body: { purge_up_to_ts: since.to_i * 1000 }
    )
    result[:purge_id]
  end

  def wait_for_purge_completion(purge_id)
    loop do
      break if purge_finished? purge_id

      sleep STATUS_CHECK_DELAY_IN_SECONDS
    end
  end

  def purge_running?(purge_id)
    get_purge_status(purge_id) == :active
  end

  def purge_finished?(purge_id)
    get_purge_status(purge_id) != :active
  end

  def get_purge_status(purge_id)
    result = @client.api.request(
      :get,
      :client_r0, "/admin/purge_history_status/#{purge_id}"
    )
    result[:status].to_sym
  end
end
