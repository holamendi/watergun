require "test_helper"

class Ssh::OutputEncodingTest < ActiveSupport::TestCase
  setup do
    @session = Ssh::Session.new(host: "example.test", user: "dokku", private_key: "test-key")
    @log_stream = LogStream.new(id: 777)
    @channel = Turbo::StreamsChannel.send(:stream_name_from, @log_stream)
    ActionCable.server.pubsub.clear_messages(@channel)
  end

  test "binary UTF-8 SSH output reaches the real Turbo broadcast codec" do
    command, messages = stream_chunks([[:stdout, "Puma ✔ ✖\n".b]])

    assert_includes messages.join, "Puma ✔ ✖"
    assert_equal "Puma ✔ ✖\n", command.text_output
    assert_equal "Puma ✔ ✖\n", persisted_output(command).first.fetch("data")
  end

  test "invalid bytes are replaced in live and persisted logs" do
    command, messages = stream_chunks([[:stdout, "bad\xFF\xC0\xAF ok\n".b]])

    assert_equal "bad��� ok\n", command.text_output
    assert_includes messages.join, "bad��� ok"
    assert_equal command.text_output, persisted_output(command).first.fetch("data")
  end

  test "UTF-8 tagged invalid bytes are replaced" do
    command, messages = stream_chunks([[:stdout, "bad\xFF\n"]])

    assert_equal "bad�\n", command.text_output
    assert_includes messages.join, "bad�"
  end

  test "split characters survive a buffer flush between every SSH byte" do
    text = "Puma ✔ ✖ 😀\n"
    chunks = text.b.bytes.map { |byte| [:stdout, byte.chr.b] }
    command, messages = stream_chunks(chunks)

    assert_equal text, command.text_output
    assert_equal text, persisted_output(command).map { |log| log.fetch("data") }.join
    assert_equal text, messages.map { |html| Nokogiri::HTML.fragment(html).css("pre").map(&:text).join }.join
    refute_includes messages.join, "�"
  end

  test "stdout and stderr decode independently" do
    chunks = [[:stdout, "\xE2".b], [:stderr, "\xE2\x9C".b], [:stdout, "\x9C\x94".b], [:stderr, "\x96".b]]
    command, messages = stream_chunks(chunks)

    assert_equal [["stdout", "✔"], ["stderr", "✖"]], command.output.map { |log| [log.stream, log.data] }
    assert_includes messages.join, "✔"
    assert_includes messages.join, "✖"
  end

  test "incomplete character is replaced only at command EOF" do
    command, messages = stream_chunks([[:stdout, "prefix \xE2\x9C".b]])

    assert_equal ["prefix ", "�"], command.output.map(&:data)
    assert_includes messages.last, "�"
    assert_equal "prefix �", persisted_output(command).map { |log| log.fetch("data") }.join
  end

  test "ASCII output and input bytes remain unchanged" do
    data = "Puma ready\r\n".b
    command, messages = stream_chunks([[:stdout, data]])

    assert_equal "Puma ready\r\n", command.text_output
    assert_equal Encoding::UTF_8, command.output.first.data.encoding
    assert command.output.first.data.valid_encoding?
    assert_includes messages.join, "Puma ready"
    assert_equal Encoding::BINARY, data.encoding
    assert_equal "Puma ready\r\n".b, data
  end

  test "live-only output is decoded without storing command logs" do
    command, messages = stream_chunks([[:stdout, "\xE2".b], [:stdout, "\x9C\x94".b]], save_output: false)

    assert_empty command.output
    assert_includes messages.join, "✔"
    refute_includes messages.join, "�"
  end

  private

  def stream_chunks(chunks, save_output: true)
    transport = mock("SSH transport")
    transport.expects(:exec!).with("dokku logs app", status: {}).multiple_yields(*chunks.map { |stream, data| [nil, stream, data] })
    @session.instance_variable_set(:@session, transport)
    buffer = Ssh::StreamBuffer.new
    command = @session.execute("dokku logs app", save_output:) do |stream, data|
      buffer.write(Ssh::Log.new(stream:, data:))
      # Force a flush after every SSH callback: a timer can split a character too.
      buffer.send(:flush) { |logs| StartLogStreamJob.new.send(:broadcast_log, @log_stream, logs) }
    end
    messages = ActionCable.server.pubsub.broadcasts(@channel).map { |payload| ActiveSupport::JSON.decode(payload) }
    [command, messages]
  end

  def persisted_output(command)
    log = server_action_runs(:deploy_success).create_log!(ssh_commands: [command])
    log.reload.ssh_commands.first.fetch("output")
  end
end
