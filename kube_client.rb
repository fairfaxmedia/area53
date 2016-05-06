require 'kubeclient'
TOKEN_PATH = ENV['TOKEN_PATH'] || '/var/run/secrets/kubernetes.io/serviceaccount/token'

class KubeClient
  def watch_dns
    client.watch_services(label_selector: 'dns=route53')
  end

  private

  def client
    @_client ||= create_client
  end

  def create_client
    auth_options = {
        bearer_token_file: TOKEN_PATH
    }
    ssl_options = {
        verify_ssl: OpenSSL::SSL::VERIFY_NONE
    }
    server = "https://#{ENV['KUBERNETES_SERVICE_HOST']}:#{ENV['KUBERNETES_PORT_443_TCP_PORT']}/api"
    Watcher.logger.info(status: 'create_client', server: server, ssl_options: ssl_options)
    Kubeclient::Client.new(server, 'v1', auth_options: auth_options, ssl_options: ssl_options)
  end
end