require "test_helper"

class ServerActionLogTest < ActiveSupport::TestCase
  setup do
    app = apps(:smol_roda)
    action = ServerActions::CreateApp.create!(server: app.server, actionable: app)

    list = Ssh::Command.new("dokku --quiet apps:list")
    list.start
    list.append_output(:stdout, "smol-roda\n")
    list.append_output(:stdout, "other-app\n")
    list.finish(0)

    restart = Ssh::Command.new("dokku ps:restart smol-roda")
    restart.start
    restart.append_output(:stderr, "restart failed\n")
    restart.finish(1)

    interrupted = Ssh::Command.new("dokku ps:report smol-roda")
    interrupted.start

    @log = action.create_log!(ssh_commands: [list, restart, interrupted]).reload
  end

  test "to_s renders each command as readable text" do
    assert_equal <<~LOG.chomp, @log.to_s
      $ dokku --quiet apps:list
      smol-roda
      other-app

      $ dokku ps:restart smol-roda
      restart failed
      Exit code: 1

      $ dokku ps:report smol-roda
    LOG
  end

  test "text_output joins the output of every command" do
    assert_equal "smol-roda\nother-app\nrestart failed\n", @log.text_output
  end

  test "empty log renders as empty text" do
    @log.update!(ssh_commands: [])

    assert_equal "", @log.reload.to_s
    assert_equal "", @log.text_output
  end
end
