require 'spec_helper'

describe "openstack_lb" do 
  default_params = {
    :controller_virtual_ip => '10.0.0.1',
    :controller_state => 'MASTER',
    :controller_names => [
      'controller-001', 'controller-002', 'controller-003',
    ],
    :controller_ipaddresses => [ '10.0.0.2', '10.0.0.3', '10.0.0.4' ],
  }

  let :facts do
    { :osfamily => 'Debian',
      :concat_basedir => '/tmp',
      :fqdn => 'testfqdn.example.com'
    }
  end

  context "MASTER without swift VIP" do
    let(:params) { default_params }

    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__script('haproxy').with_no_weight('true') }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_priority(101) }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_state('MASTER') }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_nopreempt(false) }
    it { should_not contain_keepalived__vrrp__instance('openstack-swift') }
  end

  context "BACKUP without swift VIP" do
    let :params do
      default_params.merge({
        :controller_state => 'BACKUP',
      })
    end

    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__script('haproxy').with_no_weight('true') }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_priority(100) }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_state('BACKUP') }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_nopreempt(false) }
    it { should_not contain_keepalived__vrrp__instance('openstack-swift') }
  end

  context "AUTO without swift VIP" do
    let :params do
      default_params.merge({
        :controller_state => 'AUTO',
      })
    end
    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__script('haproxy').with_no_weight('true') }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_priority(100) }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_state('BACKUP') }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_nopreempt(true) }
    it { should_not contain_keepalived__vrrp__instance('openstack-swift') }
  end

  context "MASTER with swift VIP" do
    let :params do
      default_params.merge({
        :swift_enabled => true,
        :swift_proxy_state => 'MASTER',
      })
    end
    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__script('haproxy').with_no_weight('true') }
    it { should contain_keepalived__vrrp__instance('openstack-main') }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_priority(101) }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_state('MASTER') }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_nopreempt(false) }
  end

  context "BACKUP with swift VIP" do
    let :params do
      default_params.merge({
        :swift_enabled => true,
        :swift_proxy_state => 'BACKUP',
      })
    end

    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__script('haproxy').with_no_weight('true') }
    it { should contain_keepalived__vrrp__instance('openstack-main') }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_priority(100) }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_state('BACKUP') }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_nopreempt(false) }
  end

  context "AUTO with swift VIP" do
    let :params do
      default_params.merge({
        :swift_enabled => true,
        :swift_proxy_state => 'AUTO',
      })
    end
    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__script('haproxy').with_no_weight('true') }
    it { should contain_keepalived__vrrp__instance('openstack-main') }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_priority(100) }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_state('BACKUP') }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_nopreempt(true) }
  end

  context "HAProxy w/normal Keystone" do
    let(:params) { default_params }

    it { should contain_class('haproxy') }
    it { should contain_haproxy__balancermember('galera_primary_main').with({
      :server_names => 'controller-001',
      :ipaddresses => '10.0.0.2',
      :options => 'check port 9200 inter 2000 rise 2 fall 5',
    })}
    it { should contain_haproxy__balancermember('galera_backup_main').with({
      :server_names => ['controller-002', 'controller-003'],
      :ipaddresses => ['10.0.0.3', '10.0.0.4'],
      :options => 'check port 9200 inter 2000 rise 2 fall 5 backup',
    })}

    it { should contain_haproxy__balancermember('keystone_public_internal_primary').with({
      :server_names => ['controller-001', 'controller-002', 'controller-003'],
      :ipaddresses => ['10.0.0.2', '10.0.0.3', '10.0.0.4'],
    })}

    it { should_not contain_haproxy__balancermember('keystone_public_internal_backup') }
  end

  context "HAProxy w/separate Keystone" do
    let :params do
      default_params.merge({
        :keystone_names => ['keystone-001', 'keystone-002', 'keystone-003'],
        :keystone_ipaddresses => ['192.168.0.1', '192.168.0.2', '192.168.0.3'],
      })
    end

    it { should contain_class('haproxy') }
    it { should contain_haproxy__balancermember('galera_primary_main').with({
      :server_names => 'controller-001',
      :ipaddresses => '10.0.0.2',
      :options => 'check port 9200 inter 2000 rise 2 fall 5',
    })}
    it { should contain_haproxy__balancermember('galera_backup_main').with({
      :server_names => ['controller-002', 'controller-003'],
      :ipaddresses => ['10.0.0.3', '10.0.0.4'],
      :options => 'check port 9200 inter 2000 rise 2 fall 5 backup',
    })}

    it { should contain_haproxy__balancermember('keystone_public_internal_primary').with({
      :server_names => ['keystone-001', 'keystone-002', 'keystone-003'],
      :ipaddresses => ['192.168.0.1', '192.168.0.2', '192.168.0.3'],
    })}

    it { should_not contain_haproxy__balancermember('keystone_public_internal_backup') }
  end

  context "HAProxy w/separate Keystone & backup Keystone" do
    let :params do
      default_params.merge({
        :keystone_names => ['keystone-001', 'keystone-002', 'keystone-003'],
        :keystone_ipaddresses => ['192.168.0.1', '192.168.0.2', '192.168.0.3'],
        :keystone_backup_names => ['keystone-004', 'keystone-005', 'keystone-006'],
        :keystone_backup_ipaddresses => ['192.168.1.1', '192.168.1.2', '192.168.1.3'],
      })
    end

    it { should contain_class('haproxy') }
    it { should contain_haproxy__balancermember('galera_primary_main').with({
      :server_names => 'controller-001',
      :ipaddresses => '10.0.0.2',
      :options => 'check port 9200 inter 2000 rise 2 fall 5',
    })}
    it { should contain_haproxy__balancermember('galera_backup_main').with({
      :server_names => ['controller-002', 'controller-003'],
      :ipaddresses => ['10.0.0.3', '10.0.0.4'],
      :options => 'check port 9200 inter 2000 rise 2 fall 5 backup',
    })}

    it { should contain_haproxy__listen('keystone_public_internal_cluster').with({
      :options => {
        'option' => [ 'tcpka', 'httpchk', 'tcplog', 'allbackups'],
        'balance' => 'source',
      }
    })}

    it { should contain_haproxy__balancermember('keystone_public_internal_primary').with({
      :server_names => ['keystone-001', 'keystone-002', 'keystone-003'],
      :ipaddresses => ['192.168.0.1', '192.168.0.2', '192.168.0.3'],
    })}

    it { should contain_haproxy__balancermember('keystone_public_internal_backup').with({
      :server_names => ['keystone-004', 'keystone-005', 'keystone-006'],
      :ipaddresses => ['192.168.1.1', '192.168.1.2', '192.168.1.3'],
    })}

    it { should contain_haproxy__listen('keystone_admin_cluster').with({
      :options => {
        'option' => [ 'tcpka', 'httpchk', 'tcplog', 'allbackups'],
        'balance' => 'source',
      }
    })}

    it { should contain_haproxy__balancermember('keystone_admin_primary').with({
      :server_names => ['keystone-001', 'keystone-002', 'keystone-003'],
      :ipaddresses => ['192.168.0.1', '192.168.0.2', '192.168.0.3'],
    })}

    it { should contain_haproxy__balancermember('keystone_admin_backup').with({
      :server_names => ['keystone-004', 'keystone-005', 'keystone-006'],
      :ipaddresses => ['192.168.1.1', '192.168.1.2', '192.168.1.3'],
    })}

  end

end
