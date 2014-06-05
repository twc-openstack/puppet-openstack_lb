require 'spec_helper'

describe 'openstack_lb::galera' do

  let(:title) { 'test' }
  let :params do 
    { :virtual_ip => '10.0.0.1',
      :virtual_port => 5000,
      :dest_names => [
        'controller-001', 'controller-002', 'controller-003',
      ],
      :dest_ipaddresses => [ '10.0.0.2', '10.0.0.3', '10.0.0.4' ],
      :dest_port => 6000,
    }
  end

  it { should contain_haproxy__listen('galera_cluster_test').with({
    :ipaddress => '10.0.0.1',
    :ports     => 5000,
  })}

  it { should contain_haproxy__balancermember('galera_primary_test').with({
    :server_names => 'controller-001',
    :ipaddresses => '10.0.0.2',
    :options => 'check port 9200 inter 2000 rise 2 fall 5',
  })}

  it { should contain_haproxy__balancermember('galera_backup_test').with({
    :server_names => ['controller-002', 'controller-003'],
    :ipaddresses => ['10.0.0.3', '10.0.0.4'],
    :options => 'check port 9200 inter 2000 rise 2 fall 5 backup',
  })}

end
