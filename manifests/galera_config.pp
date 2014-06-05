# == Class: openstack_lb::galera_config
#
# This allows configuring galera proxies via Hiera.
#
# === Parameters
#
# [*config*]
#   This is a hash of galera proxies that should be configured.  Default is the
#   value of the 'openstack_lb::galera_config' Hiera variable, or false if not
#   specified.
#
# === Hiera
#
# [*openstack_lb::galera_config*]
#   This should be a hash of parameters that will be passed to the
#   'openstack_lb::galera_proxy defined type'
#
class openstack_lb::galera_config (
  $config = hiera('openstack_lb::galera_config', false),
) {
  if $config {
    create_resources('::openstack_lb::galera_proxy', $config)
  }
}
