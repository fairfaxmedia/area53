class ServiceWatcher
  def initialize(logger, route53_client)
    @logger = logger
    @kube_client = KubeClient.new(logger, 'v1', 'api')
    @route53_client = route53_client
  end

  def run
    loop do
      @logger.info(watcher: 'Service', status: 'startup', hosted_zone_id: ENV['HOSTED_ZONE_ID'])
      @kube_client.watch_services.each do |notice|
        begin
          new_notice(notice)
        rescue => ex
          @logger.error(watcher: 'Service', status: 'end_watch', error: ex)
        end
      end
      @logger.info(watcher: 'Service', status: 'end_all_watch')
    end
  end

  private

  def new_notice(notice)
    action = @route53_client.get_action(notice)
    return if action.nil?
    @logger.info(watcher: 'Service', status: 'new_notice', action: action)
    svc = notice.object

    return if (svc.metadata.annotations.dnsHostName.nil? && svc.metadata.annotations.domainName.nil?) || svc.spec.type.nil?

    if svc.status.loadBalancer.ingress.nil?
      @logger.error(watcher: 'Service', status: 'No load balancer domain', service: svc.metadata.name)
      return
    end
    resource_value = svc.status.loadBalancer.ingress[0]['hostname']
    type = 'CNAME'

    @logger.info(watcher: 'Service', status: 'change_dns', domain: get_domain(svc), resource_value: resource_value, type: type, action: action)
    @route53_client.change_dns(get_domain(svc), resource_value, type, action)
  end

  def get_domain(svc)
    delimiter = svc.metadata.annotations.dnsDashSubdomains == 'true' ? '-' : '.'
    "#{domain(svc).join(delimiter)}.#{@route53_client.get_hosted_zone_name}"
  end

  def domain(svc)
    [ (svc.metadata.annotations.dnsHostName || svc.metadata.annotations.domainName).gsub('.', '') ].tap do |d|
      d << svc.metadata.namespace if svc.metadata.namespace.present? && svc.metadata.annotations.dnsIncludeNamespace == 'true'
      d << ENV['CLUSTER_NAME'] if ENV['CLUSTER_NAME'].present? && svc.metadata.annotations.dnsIncludeCluster == 'true'
    end
  end
end
