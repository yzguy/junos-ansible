# Notes

When using Ansible installed into virtualenv, need to set python path in ansible.cfg. This will ensure packages in venv are used

#### Install ansible-galaxy modules/collections

`ansible-galaxy collection install -r requirements.yml`

#### Junos OS Platform Options

Tells us how to setup connection details for network_cli + NETCONF

https://docs.ansible.com/ansible/latest/network/user_guide/platform_junos.html

#### Notes

Some modules only work with network_cli, eg junos_ping. If we are using NETCONF mostly, we can just override per task

```
- name: Ping gateway
  junipernetworks.junos.junos_ping
    dest: 192.168.221.1
  vars:
    ansible_connection: network_cli
```

### Ansible + NAPALM

We can also use `ansible-napalm` to render the configuration, then push it to the device.

https://github.com/napalm-automation/napalm-ansible
