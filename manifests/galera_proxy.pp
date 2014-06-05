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
      'balance' => 'source'
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
