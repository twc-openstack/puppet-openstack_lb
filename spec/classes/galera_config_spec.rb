require 'spec_helper'

describe 'openstack_lb::galera_config' do
  let :params do 
    { :config => { 
        'test1' => {
          'virtual_ip' => '10.0.0.1',
          'dest_names' => [ 'h1', 'h2', 'h3'],
          'dest_ipaddresses' => [ '10.0.0.2', '10.0.0.3', '10.0.0.4' ],
        },
        'test2' => {
          'virtual_ip' => '10.1.0.1',
          'dest_names' => [ 'g1', 'g2', 'g3'],
          'dest_ipaddresses' => [ '10.1.0.2', '10.1.0.3', '10.1.0.4' ],
        }
      }
    }
  end


  it 'setup multiple galera_config resources' do 
    should contain_openstack_lb__galera_proxy('test1')
    should contain_openstack_lb__galera_proxy('test2')
  end
end
