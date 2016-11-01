#!/usr/bin/env ruby
require_relative 'watchers/service_watcher'
require_relative 'watchers/ingress_watcher'
require_relative 'kube_client'
require_relative 'route53_client'

logger = begin
  require 'ffx/container_logging'
  Ffx::ContainerLogging::ConfigurationService.new(app_name: 'area-53').logger
rescue LoadError
  logger = Logger.new(STDOUT)
  logger.info(status: 'setup_log', msg: 'ffx/container_logging not present, using stdout')
  logger
end

route53_client = Route53Client.new(logger, ENV['HOSTED_ZONE_ID'])

service_thread = Thread.new { ServiceWatcher.new(logger, route53_client).run }
ingress_thread = Thread.new { IngressWatcher.new(logger, route53_client, ENV['ELB']).run } if ENV['ELB'].present?

service_thread.join
ingress_thread.join unless ingress_thread.nil?
