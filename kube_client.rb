require 'kubeclient'
TOKEN_PATH = ENV['TOKEN_PATH'] || '/var/run/secrets/kubernetes.io/serviceaccount/token'

class KubeClient
  def initialize(logger, version, server_suffix)
    @logger = logger
    @version = version
    @server_suffix = server_suffix
  end

  def watch_services
    client.watch_services(label_selector: 'dns=route53')
  end

  def watch_ingresses
    client.watch_entities('Ingress')
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
    server = "https://#{ENV['KUBERNETES_SERVICE_HOST']}:#{ENV['KUBERNETES_PORT_443_TCP_PORT']}/"
    @logger.info(status: 'create_client', server: server, ssl_options: ssl_options)
    Kubeclient::Client.new(server + @server_suffix, @version, auth_options: auth_options, ssl_options: ssl_options)
  end
end