require 'chef/handler'
require 'net/http'
require 'uri'
require 'json'

class Chef
  class Handler
    # Slack Handler goal is send messages to a Slack channel with Chef run status.
    # It can be used as a start, failure or success handler.
    class Slack < Chef::Handler
      def initialize(options = {})
        @token = options[:token]
        @channel = options[:channel] || '#chef'
        @username = options[:username] || 'Chef'
        @on_start = options[:on_start].nil? ? true : options[:on_start]
        @on_success = options[:on_success].nil? ? true : options[:on_success]
        @on_failure = options[:on_failure].nil? ? true : options[:on_failure]
      end

      def report
        options = {}
        options[:pretext] = "Run at #{run_status.node.name}"

        if !run_status.is_a?(Chef::RunStatus) || elapsed_time.nil?
          report_start(options)
        elsif run_status.success?
          report_success(options)
        else
          report_failure(options)
        end
      end

      def report_start(options)
        return exit_without_sending('start') unless @on_start
        options[:title] = 'Chef run started!'
        options[:body] = "Will run #{node.run_list}"
        options[:fallback] = "Chef run started! #{run_status.node.name} will run #{node.run_list}."
        send_attachment(options)
      end

      def report_success(options)
        return exit_without_sending('success') unless @on_success
        options[:title] = 'Chef run successfully!'
        options[:color] = 'good'
        options[:body] = "Just run #{node.run_list} successfully in #{run_status.elapsed_time} seconds."
        options[:fallback] = "Chef run successfully! #{run_status.node.name} run #{node.run_list} successfully"\
                               " in #{run_status.elapsed_time.to_i} seconds."
        send_attachment(options)
      end

      def report_failure(options)
        return exit_without_sending('failure') unless @on_failure

        options[:title] = 'Chef FAILED!'
        options[:color] = 'danger'
        options[:body] = "Running #{node.run_list} failed in #{run_status.elapsed_time} seconds."
        options[:fallback] = "Chef FAILED! #{run_status.node.name} failed to run #{node.run_list}." \
                               " in #{run_status.elapsed_time.to_i} seconds."
        send_attachment(options)

        return if run_status.exception.nil?

        text = '```' + run_status.formatted_exception.encode(
          'UTF-8',
          invalid: 'replace', undef: 'replace', replace: '?'
        ) + '```'
        options[:text] = text
        send_text(options)
      end

      def send_attachment(options)
        fail 'No message defined to be send to slack' if options[:body].nil?
        params = {
          color: options[:color],
          attachments: [{
            pretext:  options[:pretext],
            title: options[:title],
            title_link: options[:title_link],
            color: options[:color],
            text: options[:body],
            fallback: options[:fallback]
          }]
        }
        send_slack_message(params)
      end

      def exit_without_sending(handler_type)
        Chef::Log.debug("Slack '#{handler_type}' handler is not active.")
      end

      def send_text(options)
        fail 'No message defined to be send to slack' if options[:text].nil?
        params = {
          text: options[:text]
        }
        send_slack_message(params)
      end

      def send_slack_message(specif_params)
        params = { username: @username, channel: @channel, token: @token }.merge(specif_params)

        uri = URI("https://hooks.slack.com/services/#{@token}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        begin
          req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
          req.set_form_data(payload: params.to_json)
          res = http.request(req)
          if res.code != '200'
            Chef::Log.error("We got an error while posting a message to Slack: #{res.code} - #{res.msg}")
          else
            Chef::Log.debug("Slack handler sent a message to channel '#{params[:channel]}'")
          end
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
               Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
          Chef::Log.error("An unhandled exception occurred while posting a message to Slack: #{e}")
        end
      end
    end
  end
end
