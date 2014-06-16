# == Define: openstack_lb::galera_proxy
#
# This defined type will allow you to define multiple listening ports and
# destinations for galera clusters.  This can be useful if you have multiple
# galera clusters, or if you just want to have different ones active for
# different services.  This will explicitly set up HAProxy in an active/passive
# configuration to avoid the issues described here:
# http://lists.openstack.org/pipermail/openstack-dev/2014-May/035264.html
#
# === Parameters
#
# [*virtual_ip*]
#   The IP address to listen on.  This will generally be one of the ones you've
#   already configured to be managed by keepalived.  Required.
#
# [*virtual_port*]
#   The TCP port to listen on.  Default: 3306.
#
# [*dest_names*]
#   The names of the servers to load balance to.  Required, but
#   strictly informational.
#
# [*dest_ipaddresses]
#   The IP addresses of the servers to load balance to.  Required.
#
# [*dest_port*]
#   The port on the destination IP addresses to load balance to.  Default: 3306.
#
define openstack_lb::galera_proxy (
  $virtual_ip,
  $virtual_port = 3306,
  $dest_names,
  $dest_ipaddresses,
  $dest_port = 3306,
) {

  haproxy::listen { "galera_cluster_${name}":
    ipaddress => $virtual_ip,
    ports     => $virtual_port,
    options   => {
      'option'  => ['httpchk'],
      'mode'    => 'tcp',
      'balance' => 'source',
      'timeout server' => "3600000",
      'timeout client' => "3600000",
    }
  }

  haproxy::balancermember { "galera_primary_${name}":
    listening_service => "galera_cluster_${name}",
    ports             => $dest_port,
    server_names      => $dest_names[0],
    ipaddresses       => $dest_ipaddresses[0],
    # Note: Checking port 9200 due to health_check script.
    options           => 'check port 9200 inter 2000 rise 2 fall 5',
  }

  haproxy::balancermember { "galera_backup_${name}":
    listening_service => "galera_cluster_${name}",
    ports             => $dest_port,
    server_names      => delete_at($dest_names, 0),
    ipaddresses       => delete_at($dest_ipaddresses, 0),
    # Note: Checking port 9200 due to health_check script.
    options           => 'check port 9200 inter 2000 rise 2 fall 5 backup',
  }
}
