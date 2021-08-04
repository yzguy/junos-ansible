# Using Modules

## Playbooks

A playbook is like a script, it's run top down, and you define tasks to be run. It's common to write these for specific tasks, and they are run one-off.
While these are a great start to network automation, they can be limiting.

These will be covered in a basic way to illustrate how to use the JunOS modules to apply configuration to a device

```
-> ansible-playbook -i playbooks/hosts.yml -u admin -k playbooks/apply-vlans.yml
SSH password:

PLAY [Apply VLANs to device] ******************************************************************************************************************************

TASK [Gathering Facts] ************************************************************************************************************************************
ok: [router.yzguy.io]

TASK [Create VLAN(s)] *************************************************************************************************************************************
changed: [router.yzguy.io]

PLAY RECAP ************************************************************************************************************************************************
router.yzguy.io            : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

If we go look at the device, we see these two VLANs present:

```
admin@router> show configuration vlans
VLAN1000 {
    vlan-id 1000;
}
VLAN1001 {
    vlan-id 1001;
}

{master:0}
```

**Note**: some modules do not support NETCONF, eg `junos_ping`. For this we can override the `ansible_connection` per task. Majority of the time, you will be using NETCONF.

```yaml
- name: Ping gateway
  junipernetworks.junos.junos_ping:
    dest: 192.168.221.1
  vars:
    ansible_connection: network_cli
```

## Roles

The more "scalable" way to do things in Ansible is by using [roles](https://docs.ansible.com/ansible/latest/user_guide/playbooks_reuse_roles.html). Using this pattern gives you
a ton of functionality, which you can leverage to keep things organized, to provide variables dynamically based on groups, etc. You also organize your playbooks within roles, which
are built much like a package or library in a normal programming language. These roles are reusable, they can be shared, etc.

```
-> ansible-playbook -u admin -k -i hosts.yml site.yml
SSH password:

PLAY [Configure] *****************************************************************************************************************

TASK [common : Configure Hostname] ***********************************************************************************************
ok: [firewall.yzguy.io]
ok: [router.yzguy.io]

TASK [common : Configure DNS] ****************************************************************************************************
changed: [firewall.yzguy.io]
changed: [router.yzguy.io]

PLAY RECAP ***********************************************************************************************************************
firewall.yzguy.io          : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
router.yzguy.io            : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Now looking at each device's configuration:

```
admin@router> show configuration system
host-name router;
domain-name yzguy.io;
name-server {
    9.9.9.9;
}
```

```
admin@firewall> show configuration system
host-name firewall;
domain-name yzguy.io;
name-server {
    192.168.221.2;
    192.168.221.3;
}
```

If we look at our `roles/common/defaults/main.yml`, we see the `name_servers` defined as `8.8.8.8` and `8.8.4.4`. These would be used in the event they aren't defined anywhere else.
We have also defined `name_servers` at `group_vars/all` and in `host_vars/router.yzguy.io`. The host-specific variables will take precedence when defined, and falling back to the `all`
when there isn't something more specific. We can see that one host has one set of name servers and the other has another set.

As you can see, this dynamic resolving of variables is powerful. The most common groupings we might use in a network context are:

* `region`
* `datacenter`
* `environment`
* `row`
* `rack`

In our example, it's very likely you have different DNS servers and/or NTP servers per region, per data center. You can set these within groups easily, and provide them to the same role for all devices.
