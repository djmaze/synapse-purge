class SynapseClient
  STATUS_CHECK_DELAY_IN_SECONDS = 0.5

  def initialize(url:, username:, password:)
    @client = MatrixSdk::Client.new url
    @client.login username, password, no_sync: true
  end

  def enqueue_room_purge(room_id, since)
    result = @client.api.request :post, :client_r0, "/admin/purge_history/#{URI.encode room_id}",
      body: {purge_up_to_ts: since.to_i * 1000}
    result[:purge_id]
  end

  def wait_for_purge_completion(purge_id)
    while true
      break if get_purge_status(purge_id) != 'active'
      sleep STATUS_CHECK_DELAY_IN_SECONDS
    end
  end

  def get_purge_status(purge_id)
    result = @client.api.request :get, :client_r0, "/admin/purge_history_status/#{purge_id}"
    result[:status]
  end
end
