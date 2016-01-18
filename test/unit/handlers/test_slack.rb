require_relative '../helpers'

require 'webmock/rspec'
require 'cookbook_sdk/handlers/slack'

WebMock.disable_net_connect!(:allow_localhost => true)

describe Chef::Handler::Slack do
  let(:node) do
    node = Chef::Node.new
    node.name('test')
    node.run_list('recipe[fake_cookbook::fake_recipe]')
    node
  end

  let(:url) do
    "https://hooks.slack.com/services/#{config[:token]}"
  end

  let(:config) do
    {
      :token => 'fake_token',
      :channel => '#fake_channel',
      :username => 'fake_user',
      :on_start => true,
      :on_success => true,
      :on_failure => true
    }
  end

  before do
    Chef::Handler::Slack.any_instance.stubs(:node).returns(node)
  end

  it 'should read the configuration options on initialization' do
    @slack_handler = Chef::Handler::Slack.new(config)
    expect(@slack_handler.token).to eq(config[:token])
    expect(@slack_handler.channel).to eq(config[:channel])
    expect(@slack_handler.username).to eq(config[:username])
    expect(@slack_handler.on_start).to eq(config[:on_start])
    expect(@slack_handler.on_success).to eq(config[:on_success])
    expect(@slack_handler.on_failure).to eq(config[:on_failure])
  end

  it 'should set configuration defaults when not provide on initialization' do
    @slack_handler = Chef::Handler::Slack.new(:token => 'fake_token')
    expect(@slack_handler.token).to eq('fake_token')
    expect(@slack_handler.channel).to eq('#chef')
    expect(@slack_handler.username).to eq('Chef')
    expect(@slack_handler.on_start).to eq(true)
    expect(@slack_handler.on_success).to eq(true)
    expect(@slack_handler.on_failure).to eq(true)
  end

  it 'should throw an exception when the slack token is not provided on initialization' do
    expect { Chef::Handler::Slack.new({}) }.to raise_error(ChefConfig::ConfigurationError)
  end

  describe '#report' do
    before do
      @slack_handler = Chef::Handler::Slack.new(config)
      @run_status = Chef::RunStatus.new(node, {})
    end

    describe 'when chef run is not over' do
      before do
        @run_status.start_clock
      end

      it 'should call report_start function at start of the run' do
        @slack_handler.stubs(:report_start)

        expect(@slack_handler).to receive(:report_start)
        expect(@slack_handler).not_to receive(:report_success)
        expect(@slack_handler).not_to receive(:report_failure)

        @slack_handler.run_report_unsafe(@run_status)
      end

      it 'should skip the sending of the starting message when on_start option is false' do
        new_config = config
        new_config[:on_start] = false
        @slack_handler = Chef::Handler::Slack.new(new_config)
        expect(Chef::Log).to receive(:debug).with("Slack 'start' handler is not active.")
        expect(@slack_handler).not_to receive(:send_attachment)
        expect(@slack_handler).not_to receive(:send_slack_message)

        @slack_handler.run_report_unsafe(@run_status)
      end

      it 'should send the starting message when on_start option is true' do
        stub_request(:post, url).to_return(:status => 200, :headers => {})

        expect(@slack_handler).not_to receive(:exit_without_sending)
        expect(Chef::Log).to receive(:debug).with("Slack handler sent a message to channel '#{config[:channel]}'")

        @slack_handler.run_report_unsafe(@run_status)

        payload = {
          :username => config[:username],
          :channel => config[:channel],
          :token => config[:token],
          :color => nil,
          :attachments => [{
            :pretext => 'Run at test',
            :title => 'Chef run started!',
            :title_link => nil,
            :color => nil,
            :text => "Will run #{node.run_list}",
            :fallback => "Chef run started! test will run #{node.run_list}."
          }]
        }
        expect(WebMock).to have_requested(:post, url).with(:body => { :payload => payload.to_json })
      end
    end

    describe 'when chef is over' do
      before do
        @run_status.start_clock
        @run_status.stop_clock
      end

      describe 'and run successfully' do
        it 'should call report_success function at end of the run' do
          expect(@slack_handler).not_to receive(:report_start)
          expect(@slack_handler).to receive(:report_success)
          expect(@slack_handler).not_to receive(:report_failure)

          @slack_handler.run_report_unsafe(@run_status)
        end

        it 'should skip the sending of the success message when on_success option is false' do
          new_config = config
          new_config[:on_success] = false
          @slack_handler = Chef::Handler::Slack.new(new_config)
          expect(Chef::Log).to receive(:debug).with("Slack 'success' handler is not active.")
          expect(@slack_handler).not_to receive(:send_attachment)
          expect(@slack_handler).not_to receive(:send_slack_message)

          @slack_handler.run_report_unsafe(@run_status)
        end

        it 'should send the success message when on_success option is true' do
          stub_request(:post, url).to_return(:status => 200)

          expect(@slack_handler).not_to receive(:exit_without_sending)
          expect(Chef::Log).to receive(:debug).with("Slack handler sent a message to channel '#{config[:channel]}'")

          @slack_handler.run_report_unsafe(@run_status)
          payload = {
            :username => config[:username],
            :channel => config[:channel],
            :token => config[:token],
            :color => 'good',
            :attachments => [{
              :pretext => 'Run at test',
              :title => 'Chef run successfully!',
              :title_link => nil,
              :color => 'good',
              :text => "Just run #{node.run_list} successfully in #{@run_status.elapsed_time} seconds.",
              :fallback => "Chef run successfully! test run #{node.run_list} successfully "\
                           "in #{@run_status.elapsed_time.to_i} seconds."
            }]
          }
          expect(WebMock).to have_requested(:post, url).with(:body => { :payload => payload.to_json })
        end
      end

      describe 'and failed' do
        before do
          @run_status.start_clock
          @run_status.stop_clock
          @run_status.exception = ChefConfig::ConfigurationError.new('A fake error.')
        end

        it 'should call report_failed function at end of the run' do
          expect(@slack_handler).not_to receive(:report_start)
          expect(@slack_handler).not_to receive(:report_success)
          expect(@slack_handler).to receive(:report_failure)

          @slack_handler.run_report_unsafe(@run_status)
        end

        it 'should skip the sending of the failed message when on_failure option is false' do
          new_config = config
          new_config[:on_failure] = false
          @slack_handler = Chef::Handler::Slack.new(new_config)
          expect(Chef::Log).to receive(:debug).with("Slack 'failure' handler is not active.")
          expect(@slack_handler).not_to receive(:send_attachment)
          expect(@slack_handler).not_to receive(:send_slack_message)

          @slack_handler.run_report_unsafe(@run_status)
        end

        it 'should send the failure message when on_failure option is true' do
          stub_request(:post, url).to_return(:status => 200, :headers => {})

          expect(@slack_handler).not_to receive(:exit_without_sending)
          expect(Chef::Log).to receive(:debug)
            .with("Slack handler sent a message to channel '#{config[:channel]}'").twice

          @slack_handler.run_report_unsafe(@run_status)

          # Message as attachment
          payload = {
            :username => config[:username],
            :channel => config[:channel],
            :token => config[:token],
            :color => 'danger',
            :attachments =>  [{
              :pretext => 'Run at test',
              :title => 'Chef run FAILED!',
              :title_link => nil,
              :color => 'danger',
              :text => "Running #{node.run_list} failed in #{@run_status.elapsed_time} seconds.",
              :fallback => "Chef FAILED! #{@run_status.node.name} failed to run #{node.run_list}" \
                           " in #{@run_status.elapsed_time.to_i} seconds."
            }]
          }
          expect(WebMock).to have_requested(:post, url).with(:body => { :payload => payload.to_json })

          # Exception
          payload = {
            :username => config[:username],
            :channel => config[:channel],
            :token => config[:token],
            :text => '```ChefConfig::ConfigurationError: A fake error.```'
          }
          expect(WebMock).to have_requested(:post, url).with(:body => { :payload => payload.to_json })
        end
      end
    end

    describe 'when tries to send an http request but it fails' do
      it 'should log a error when receive a http response different than 200 OK' do
        stub_request(:post, url).to_return(:status => 400)
        expect(Chef::Log).to receive(:error).with('We got an error while posting a message to Slack: 400 - ')
        @slack_handler.run_report_unsafe(@run_status)
      end

      it 'should log a error when got any exception related with the request' do
        stub_request(:post, url).to_return(:should_timeout => true)
        expect(Chef::Log).to receive(:error)
          .with('An unhandled exception occurred while posting a message to Slack: execution expired')
        @slack_handler.run_report_unsafe(@run_status)
      end
    end
  end
end
