#!/usr/bin/env ruby
require_relative 'kube_client'
require_relative 'route53_client'

class Watcher
  def run
    @route53_client = Route53Client.new(ENV['HOSTED_ZONE_ID'])
    logger.info(status: 'startup', hosted_zone_id: ENV['HOSTED_ZONE_ID'])
    KubeClient.new.watch_dns.each do |notice|
      new_notice(notice)
    end
  rescue => ex
    logger.error(status: 'end_watch', error: ex)
  end

  def self.logger
    @_logger ||= begin
      require 'ffx/container_logging'
      Ffx::ContainerLogging::ConfigurationService.new(app_name: 'area-53').logger
    rescue LoadError
      logger = Logger.new(STDOUT)
      logger.info(status: 'setup_log', msg: 'ffx/container_logging not present, using stdout')
      logger
    end
  end

  private

  def logger
    self.class.logger
  end

  def new_notice(notice)
    action = notice_action(notice)
    return if action.nil?

    logger.info(status: 'new_notice', action: action)
    svc = notice.object
    return if svc.metadata.annotations.domainName.nil?

    resource_value = svc.spec.clusterIP
    type = 'A'
    if svc.spec.type == 'LoadBalancer'
      if svc.status.loadBalancer.ingress.nil?
        logger.error(status: 'No domain', service: svc.metadata.name)
        return
      end
      resource_value = svc.status.loadBalancer.ingress[0]['hostname']
      type = 'CNAME'
    end

    logger.info(status: 'change_dns', domain: get_domain(svc), resource_value: resource_value, type: type, action: action)
    @route53_client.change_dns(get_domain(svc), resource_value, type, action)
  end

  def notice_action(notice)
    case notice.type
      when 'ADDED', 'MODIFIED'
        'UPSERT'
      when 'DELETED'
        'DELETE'
      else
        nil
    end
  end

  def get_domain(svc)
    domain = svc.metadata.annotations.domainName.dup
    domain << '.' unless domain[-1] == '.'
    domain << @route53_client.get_hosted_zone_name
  end
end

Watcher.new.run
