# Introduction

# Class used to manage server load-balancers in a high-availability OpenStack
# deployment.
#
# Module Dependencies
#  puppet-sysctl
#  puppet-keepalived
#  puppet-haproxy
#
# Example Usage
# node 'slb01' {
#   class {'openstack_lb':
#     controller_virtual_ip   => '10.10.10.10',
#     swift_proxy_virtual_ip  => '11.11.11.11',
#     controller_interface    => 'eth0',
#     swift_proxy_interface   => 'eth0',
#     controller_state        => 'MASTER',
#     swift_proxy_state       => 'BACKUP',
#     controller_names        => ['control01, control02, control03'],
#     controller_ipaddresses  => ['1.1.1.1, 2.2.2.2, 3.3.3.3'],
#     controller_vrid         => '40',
#     swift_vrid              => '41',
#     swift_proxy_names       => ['swift01, swift02'],
#     swift_proxy_ipaddresses => ['4.4.4.4, 5.5.5.5'],
#   }
# }
#
# The controller and swift state variables default to auto, which means that
# nothing should need to be done in most cases.  What this translates to in
# practice is that all VRRP instances will be set to an initial state of BACKUP
# and set to not preempt an existing master.

class openstack_lb (
  $controller_virtual_ip,
  $controller_state            = 'AUTO',
  $controller_names,
  $controller_ipaddresses,
  $controller_vrid             = '50',
  $swift_vrid                  = '51',
  $controller_interface        = 'eth0',
  $keystone_names              = false,
  $keystone_ipaddresses        = false,
  $keystone_backup_ipaddresses = false,
  $keystone_backup_names       = false,
  $swift_enabled               = false,
  $swift_proxy_virtual_ip      = undef,
  $swift_proxy_state           = 'AUTO',
  $swift_proxy_names           = undef,
  $swift_proxy_ipaddresses     = undef,
  $swift_proxy_interface       = $controller_interface_real,
  $no_weight                   = true,
  $galera_create_main          = true,
  $stats_net                   = undef,
) {

  $controller_interface_real = $controller_interface

  include keepalived

  if ($controller_state == 'MASTER') {
    $controller_priority = '101'
    $controller_state_real = $controller_state
  } elsif ($controller_state == 'AUTO') {
    $controller_priority = 100
    $controller_state_real = 'BACKUP'
    $controller_nopreempt = true
  } else {
    $controller_priority = '100'
    $controller_state_real = 'BACKUP'
  }

  if ($swift_proxy_state == 'MASTER') {
    $swift_proxy_priority = '101'
    $swift_proxy_state_real = $swift_proxy_state
  } elsif ($swift_proxy_state == 'AUTO') {
    $swift_proxy_priority = 100
    $swift_proxy_state_real = 'BACKUP'
    $swift_nopreempt = true
  } else {
    $swift_proxy_priority = '100'
    $swift_proxy_state_real = 'BACKUP'
  }

  if $keystone_names and ! $keystone_ipaddresses {
    fail('Parameter $keystone_names was given, but $keystone_ipaddresses was not!')
  }
  if $keystone_ipaddresses and ! $keystone_names {
    fail('Parameter $keystone_ipaddresses was given, but $keystone_names was not!')
  }

  if $keystone_ipaddresses and $keystone_names {
    $ks_ips_real = $keystone_ipaddresses
    $ks_names_real = $keystone_names
  } else {
    $ks_ips_real = $controller_ipaddresses
    $ks_names_real = $controller_names
  }

  if $keystone_backup_names and ! $keystone_backup_ipaddresses {
    fail('Parameter $keystone_backup_names was given, but $keystone_backup_ipaddresses was not!')
  }
  if $keystone_backup_ipaddresses and ! $keystone_backup_names {
    fail('Parameter $keystone_backup_ipaddresses was given, but $keystone_backup_names was not!')
  }

  sysctl::value { 'net.ipv4.ip_nonlocal_bind': value => '1' }

  keepalived::vrrp::instance { 'openstack-main':
    virtual_router_id => $controller_vrid,
    interface         => $controller_interface_real,
    virtual_ipaddress => $controller_virtual_ip,
    state             => $controller_state_real,
    priority          => $controller_priority,
    track_script      => ['haproxy'],
    nopreempt         => $controller_nopreempt,
  } -> Class['::haproxy']

  if $swift_enabled {
    keepalived::vrrp::instance { 'openstack-swift':
      virtual_router_id => $swift_vrid,
      interface         => $swift_proxy_interface,
      virtual_ipaddress => $swift_proxy_virtual_ip,
      state             => $swift_proxy_state_real,
      priority          => $swift_proxy_priority,
      track_script      => ['haproxy'],
      nopreempt         => $swift_nopreempt,
    } -> Class['::haproxy']
  }

  keepalived::vrrp::script { 'haproxy':
    script    => 'killall -0 haproxy',
    no_weight => $no_weight,
  }

  $global = {
      log => '/dev/log local0 notice',
  }

  include haproxy::params
  class { 'haproxy':
    global_options   => merge($::haproxy::params::global_options, $global),
    defaults_options => {
      'log'     => 'global',
      'option'  => 'redispatch',
      'retries' => '3',
      'timeout' => [
        'http-request 10s',
        'queue 1m',
        'connect 10s',
        'client 1m',
        'server 1m',
        'check 10s',
      ],
      'maxconn' => '8000'
    },
  }

  if $galera_create_main {
    ::openstack_lb::galera_proxy { 'main':
      virtual_ip       => $controller_virtual_ip,
      dest_names       => $controller_names,
      dest_ipaddresses => $controller_ipaddresses,
    }
  }

  haproxy::listen { 'rabbit_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '5672',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'mode'    => 'tcp',
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'rabbit;':
    listening_service => 'rabbit_cluster',
    ports             => '5672',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'keystone_public_internal_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '5000',
    options   => {
      'option'     => ['tcpka', 'httpchk /v2.0', 'tcplog', 'allbackups'],
      'balance'    => 'source',
      'http-check' => 'expect status 200',
    }
  }

  haproxy::balancermember { 'keystone_public_internal_primary':
    listening_service => 'keystone_public_internal_cluster',
    ports             => '5000',
    server_names      => $ks_names_real,
    ipaddresses       => $ks_ips_real,
    options           => "check inter 2000 rise 2 fall 5",
  }

  if $keystone_backup_ipaddresses and $keystone_backup_names {
    haproxy::balancermember { 'keystone_public_internal_backup':
      listening_service => 'keystone_public_internal_cluster',
      ports             => '5000',
      server_names      => $keystone_backup_names,
      ipaddresses       => $keystone_backup_ipaddresses,
      options           => "check inter 2000 rise 2 fall 5 backup",
    }
  }

  haproxy::listen { 'keystone_admin_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '35357',
    options   => {
      'option'     => ['tcpka', 'httpchk /v2.0', 'tcplog', 'allbackups'],
      'balance'    => 'source',
      'http-check' => 'expect status 200',
    }
  }

  haproxy::balancermember { 'keystone_admin_primary':
    listening_service => 'keystone_admin_cluster',
    ports             => '35357',
    server_names      => $ks_names_real,
    ipaddresses       => $ks_ips_real,
    options           => "check inter 2000 rise 2 fall 5",
  }

  if $keystone_backup_ipaddresses and $keystone_backup_names {
    haproxy::balancermember { 'keystone_admin_backup':
      listening_service => 'keystone_admin_cluster',
      ports             => '35357',
      server_names      => $keystone_backup_names,
      ipaddresses       => $keystone_backup_ipaddresses,
      options           => "check inter 2000 rise 2 fall 5 backup",
    }
  }

  haproxy::listen { 'nova_osapi_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8774',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'nova_osapi':
    listening_service => 'nova_osapi_cluster',
    ports             => '8774',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'neutron_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '9696',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'neutron_api':
    listening_service => 'neutron_api_cluster',
    ports             => '9696',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'cinder_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8776',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'cinder_api':
    listening_service => 'cinder_api_cluster',
    ports             => '8776',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'ceilometer_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8777',
    options   => {
      'option'     => ['tcpka', 'tcplog', 'httpchk HEAD /'],
      'http-check' => 'expect status 401',
      'balance'    => 'source'
    }
  }

  haproxy::balancermember { 'ceilometer_api':
    listening_service => 'ceilometer_api_cluster',
    ports             => '8777',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'glance_registry_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '9191',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'glance_registry':
    listening_service => 'glance_registry_cluster',
    ports             => '9191',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'glance_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '9292',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'glance_api':
    listening_service => 'glance_api_cluster',
    ports             => '9292',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'heat_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8004',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'heat_api':
    listening_service => 'heat_api_cluster',
    ports             => '8004',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'heat_api_cfn_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8000',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'heat_api_cfn':
    listening_service => 'heat_api_cfn_cluster',
    ports             => '8000',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'heat_api_cloudwatch_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8003',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'heat_api_cloudwatch':
    listening_service => 'heat_api_cloudwatch_cluster',
    ports             => '8003',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  # Note: Failures were experienced when the balance-member was named Horizon.
  haproxy::listen { 'dashboard_cluster_http':
    ipaddress => $controller_virtual_ip,
    ports     => '80',
    options   => {
      'option'  => ['forwardfor', 'httpchk', 'httpclose'],
      'mode'    => 'http',
      'cookie'  => 'SERVERID insert indirect nocache',
      'capture' => 'cookie vgnvisitor= len 32',
      'balance' => 'source',
      'rspidel' => '^Set-cookie:\ IP='
    }
  }

  # Note: Failures were experienced when the balance-member was named Horizon.
  haproxy::balancermember { 'dashboard_http':
    listening_service => 'dashboard_cluster_http',
    ports             => '80',
    server_names      => $keystone_names,
    ipaddresses       => $keystone_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
    define_cookies    => true
  }

  # Uncomment if using NoVNC
  haproxy::listen { 'novnc_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '6080',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'balance' => 'source'
    }
  }

  # Uncomment if using NoVNC
  haproxy::balancermember { 'novnc':
    listening_service => 'novnc_cluster',
    ports             => '6080',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }


  haproxy::listen { 'nova_memcached_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '11211',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'nova_memcached':
    listening_service => 'nova_memcached_cluster',
    ports             => '11211',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  if $stats_net {
    haproxy::listen { 'stats':
      ipaddress => $swift_proxy_virtual_ip,
      ports     => '9000',
      options   => {
        'mode' => 'http',
        'acl' => "local_net src $stats_net",
        'stats' => [
          'uri /',
          'refresh 60s',
          'show-node',
          'show-legends',
          'http-request allow if local_net',
          'http-request deny',
          'admin if local_net',
        ]
      }
    }
  }

  if $swift_enabled {

    haproxy::listen { 'swift_proxy_cluster':
      ipaddress => $swift_proxy_virtual_ip,
      ports     => '8080',
      options   => {
        'option'  => ['tcpka', 'tcplog'],
        'balance' => 'source'
      }
    }

    haproxy::balancermember { 'swift_proxy':
      listening_service => 'swift_proxy_cluster',
      ports             => '8080',
      server_names      => $swift_proxy_names,
      ipaddresses       => $swift_proxy_ipaddresses,
      options           => 'check inter 2000 rise 2 fall 5',
    }

    haproxy::listen { 'swift_memcached_cluster':
      ipaddress => $swift_proxy_virtual_ip,
      ports     => '11211',
      options   => {
        'option'  => ['tcpka', 'tcplog'],
        'balance' => 'source'
      }
    }

    haproxy::balancermember { 'swift_memcached':
      listening_service => 'swift_memcached_cluster',
      ports             => '11211',
      server_names      => $swift_proxy_names,
      ipaddresses       => $swift_proxy_ipaddresses,
      options           => 'check inter 2000 rise 2 fall 5',
    }

  }

  # Borrowed from Michael Chapman's openstacklib module
  # Openstack services depend on being able to access db and mq, so make
  # sure our VIPs and LB are active before we deal with them.
  Haproxy::Listen<||> -> Anchor <| title == 'mysql::server::start' |>
  Haproxy::Listen<||> -> Anchor <| title == 'rabbitmq::begin' |>
  Haproxy::Balancermember<||> -> Anchor <| title == 'mysql::server::start' |>
  Haproxy::Balancermember<||> -> Anchor <| title == 'rabbitmq::begin' |>
  Service<| title == 'haproxy' |> -> Anchor <| title == 'rabbitmq::begin' |>
  Service<| title == 'haproxy' |> -> Anchor <| title == 'mysql::server::start' |>
}
