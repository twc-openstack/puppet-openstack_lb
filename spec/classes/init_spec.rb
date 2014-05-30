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

    context "HAProxy" do
      it { should contain_class('haproxy') }
    end

    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_priority(101) }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_state('MASTER') }
    it { should_not contain_keepalived__vrrp__instance('openstack-swift') }
  end

  context "BACKUP without swift VIP" do
    let :params do
      default_params.merge({
        :controller_state => 'BACKUP',
      })
    end

    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_priority(100) }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_state('BACKUP') }
    it { should_not contain_keepalived__vrrp__instance('openstack-swift') }
  end

  context "AUTO without swift VIP" do
    let :params do
      default_params.merge({
        :controller_state => 'AUTO',
      })
    end
    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    # This is random, but should be stable.  The priority for this was
    # determined by trying it and testing.
    it { should contain_keepalived__vrrp__instance('openstack-main').with_priority(126) }
    it { should contain_keepalived__vrrp__instance('openstack-main').with_state('MASTER') }
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
    it { should contain_keepalived__vrrp__instance('openstack-main') }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_priority(101) }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_state('MASTER') }
  end

  context "BACKUP with swift VIP" do
    let :params do
      default_params.merge({
        :swift_enabled => true,
        :swift_proxy_state => 'BACKUP',
      })
    end

    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__instance('openstack-main') }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_priority(100) }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_state('BACKUP') }
  end

  context "AUTO with swift VIP" do
    let :params do
      default_params.merge({
        :swift_enabled => true,
        :swift_proxy_state => 'AUTO',
      })
    end
    it { should contain_sysctl__value('net.ipv4.ip_nonlocal_bind') }
    it { should contain_keepalived__vrrp__instance('openstack-main') }

    # This is random, but should be stable.  The priority for this was
    # determined by trying it and testing.
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_priority(58) }
    it { should contain_keepalived__vrrp__instance('openstack-swift').with_state('MASTER') }
  end
end
