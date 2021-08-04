# JunOS Network Automation With Ansible

Ansible can use two connections for JunOS:

* network_cli
* NETCONF

More details about connections [here](https://docs.ansible.com/ansible/latest/network/user_guide/platform_junos.html)

## Modules

Commonly users will use modules to perform tasks, for example `junos_command`. If you chain these together, you can manage a lot of the configuration.
Fortunately, there are a lot of modules, and some are full featured. However, some are not as full featured, and can be very limiting.

An example of using a module

```
- name: Replace JUNOS vlan
  junipernetworks.junos.junos_vlans:
    config:
    - name: vlan-1
      vlan_id: 10
    - name: vlan-3
      vlan_id: 30
    state: replaced
```

[Source](https://docs.ansible.com/ansible/latest/collections/junipernetworks/junos/junos_vlans_module.html#ansible-collections-junipernetworks-junos-junos-vlans-module)

More information about Juniper Collections, Roles, and Modules can be found [here](https://www.juniper.net/documentation/us/en/software/junos-ansible/ansible/topics/concept/junos-ansible-modules-overview.html)

By using normal Ansible features such as variables you can use a module, but provide it with data based on whatever grouping you might use (role, datacenter, etc.)
It is common to write a playbook that does a specific task, for example to configure specific VLANs on devices. The playbook is run as a one off task, much like a script,
and many of these purpose built playbooks will be accumulated to accomplish specific tasks when necessary.

## NAPALM

By using [NAPALM](https://napalm.readthedocs.io/en/latest/), but more formally it's [Ansible Modules](https://github.com/napalm-automation/napalm-ansible), you can manage the
device's entire configuration, or even parts of it by simply rendering a template, and passing it to a `napalm_install_config` module. This advantage of this method is that you
can fully implement the configuration, you do not need to rely on specific modules to be implemented, and to have those modules have the features you need.

Using this approach can be incremental, starting with managing small pieces of configuration, then growing to eventually managing the whole configuration. It also allows you to
use the same basic process across different manufacturers. For example, you can define the NTP servers for all devices, then depending on the device you can take that data and
render it in a config template that is relevant to that OS.

When using Ansible installed into virtualenv, need to set python path in ansible.cfg. This will ensure packages in venv are used

## Setup

* Create a virtualenv

```
virtualenv venv
source venv/bin/activate
pip install -y requirements.txt
```

* Install Ansible collections from Galaxy

```
ansible-galaxy collection install -r requirements.yml
```

### Examples

Examples have been broken down to show using modules and using NAPALM.

[Modules](./modules/README.md) focuses on using modules in a playbook, then moves on using modules within roles. The latter demonstrates how variables can be used within groups/hosts to dynamically configure devices.

[NAPALM](./napalm/README.md) will focus on using the roles pattern to dynamically generate configuration from templates, then pass the rendered template to NAPALM, and finally NAPALM will work to apply the configuration to the device(s).

### Questions/Suggestions

If you have any questions or suggestions, feel free to open an issue.
