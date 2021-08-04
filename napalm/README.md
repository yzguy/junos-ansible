# Using Ansible + NAPALM

[NAPALM](https://napalm.readthedocs.io/en/latest/) itself allows you to interact with various
devices using python. This can be enormously powerful on it's own. For our purposes, we will
combine it with Ansible, utilizing the [napalm-ansible](https://github.com/napalm-automation/napalm-ansible)
collection. This collection has multiple modules, but we will only be using one: `napalm_install_config`.

This module allows us to take a rendered configuration template, and run it against the device, get a configuration
diff back, and if all looks good, we can commit and the changes will be made on the live device.

The pattern of rendering partial or whole configurations is powerful, it gives you ultimate flexibility on how you organize
your data, how to group it, and then take it and use it to build up a configuration that will resemble the actual device configuration.

You could use other modules to get data from external sources and pass it into your templates, you could use inventory sources like Netbox
to store configuration data, then use Ansible to render the config, and push it to the device.

In the case you get to the point where you are completely rendering the entire config, you could serve the rendered configurations to devices
when you ZTP them for the first time, and use Ansible to keep them up to date on an ongoing basis.

Let's take a look at how to do this.

## Structure

We are utilizing the [roles](https://docs.ansible.com/ansible/latest/user_guide/playbooks_reuse_roles.html) pattern to organize our code, giving us
automatic variable resolution, grouping, etc. Only one role will be used to build and deploy the configuration, this is in contrast to using multiple
roles if you were using just JunOS modules in your playbooks.

### Inventory

A basic inventory in Ansible is just a INI file or YAML file. I prefer to use a YAML file over INI as I find it cleaner and easier to work with. It's also possible you could write code to generate this YAML inventory file, or you could use a [inventory plugin](https://docs.ansible.com/ansible/latest/plugins/inventory.html#inventory-plugins) or create a [dynamic inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_dynamic_inventory.html#intro-dynamic-inventory).

Our inventory for this example will be `hosts.yml`, it's very basic, nothing special. If you want to see a complex inventory, you can look at [hosts-complex.yml](hosts-complex.yml). This "complex" inventory has groupings for region, datacenter, role, etc., which would be very common in a real life network.

One popular dynamic inventory would be the [Netbox Inventory](https://netbox-ansible-collection.readthedocs.io/en/latest/). An example of how to set up this dynamic inventory can be seen in [netbox_inventory.yml](netbox_inventory.yml)

```
-> ansible-inventory -i netbox_inventory.yml --list
{
    "_meta": {
        "hostvars": {
            "ap1.yzguy.io": {
                "ansible_command_timeout": 30,
                "ansible_connection": "netconf",
                "ansible_host": "192.168.221.246",
                "device_roles": [
                    "ap"
                ],
                "device_types": [
                    "uap-ac-pro"
                ],
                "dns_name": "ap1.yzguy.io",
                "domain_name": "yzguy.io",
                "firmware": null,
                "interfaces": [
                    {
                        "cable": {
                            "id": 1,
                            "label": "",
                            "url": "http://netbox.yzguy.io/api/dcim/cables/1/"
                        },
                        ...
```

### Variable Hierarchy

By utilizing groups, we can provide variables that are common to different groups. In networking this is commonly things like `datacenter`, `region`, `environment`, `row`, etc. We have the ability to put devices within groups and feed group specific variables into our templates when it is being rendered for that device.

For example, we could have two edge routers, each in their own data center, different regions, etc. They will likely share a BGP ASN, prefixes, but their DNS servers, NTP servers might be region and/or data center specific, their interfaces will be very different. We can organize all that within their respective variable files.

* `group_vars/edge.yml`

```
bgp_asn: 12345
bgp_prefixes:
  - 123.123.123.0/24
  - 222.222.0.0/16
```

* `group_vars/iad1.yml`

```
domain: iad1.us.yzguy.io
dns_servers:
  - 10.1.0.1
  - 10.1.0.2
ntp_servers:
  - 10.1.0.1
  - 10.1.0.2
```

* `group_vars/sea1.yml`

```
domain: sea1.us.yzguy.io
dns_servers:
  - 10.2.0.1
  - 10.2.0.2
ntp_servers:
  - 10.2.0.1
  - 10.2.0.2
```

* `host_vars/edge1.iad1.us.yzguy.io.yml`

```
interfaces:
  ge-0/0/0:
    description: TRANSIT
    'unit 0':
      address: 11.22.33.2/30
```

* `host_vars/edge1.sea1.us.yzguy.io.yml`

```
interfaces:
  ge-0/0/0:
    description: TRANSIT
    'unit 0':
      address: 22.33.44.2/30
```

If you use the `ansible-inventory` command, you can see all the variables that are available for each inventory host,
as well as what groups they are under.

```
-> ansible-inventory -i hosts.yml --list
{
    "_meta": {
        "hostvars": {
            "router.yzguy.io": {
                "ansible_command_timeout": 30,
                "ansible_connection": "netconf",
                "ansible_network_os": "junipernetworks.junos.junos",
                "domain_name": "yzguy.io",
                "interfaces": {
                    "ge-0/0/0": {
                        "description": "PC1",
                        "mode": "access",
                        "vlans": [
                            "wired"
                        ]
                    },
                    "ge-0/0/1": {
                        "mode": "access",
                        "vlans": [
                            "lab"
                        ]
                    },
                    ...
```

When you run the playbook, you can limit the scope of what device(s) it's run against, this is done with the `--limit` flag

```
-> ansible-playbook -i hosts-complex.yml site.yml --limit 'dub1'

PLAY [Configure] ******************************************************************

TASK [config : Commit Changes] ****************************************************
skipping: [edge1.dub1.eu.yzguy.io]
skipping: [spine01.dub1.eu.yzguy.io]
skipping: [spine02.dub1.eu.yzguy.io]
skipping: [leaf01.dub1.eu.yzguy.io]
...

-> ansible-playbook -i hosts-complex.yml site.yml --limit 'leaf*'

PLAY [Configure] ******************************************************************

TASK [config : Commit Changes] ****************************************************
skipping: [leaf01.iad1.us.yzguy.io]
skipping: [leaf01.sea1.us.yzguy.io]
skipping: [leaf01.dub1.eu.yzguy.io]

-> ansible-playbook -i hosts-complex.yml site.yml --limit 'edge1.iad1*'

PLAY [Configure] ******************************************************************

TASK [config : Commit Changes] ****************************************************
skipping: [edge1.iad1.us.yzguy.io]
```

### Templates

The biggest part of the whole process is creating the templates that you will feed data
into, then render them into configuration.

The templates are contained in `roles/config/templates`, and can be organized anyway you want, except the `baseconf.j2` file.
This file has no configuration other than including other templates, allowing you to break different configuration sections into their
own files. This helps with organization and clarify while making the templates.

The templating engine used by Ansible is called Jinja2, it is a very mature and useful template engine. You can find more about it [here](https://jinja.palletsprojects.com/en/3.0.x/). Specifics about Jinja2 won't be covered in this example.

If you use the `ansible-inventory` command to list all your devices, you can see the variables that will be available within the templates.

##### replace:

If you look at the example templates, you will see `replace:` at points. This is a JunOS specific convention that means the configuration section below it will be replaced in it's entirety with what you defined.

Example:

```
interfaces {
  replace:
  ge-0/0/0 {
    description PC1;
    unit 0 {
      family ethernet-switching {
        vlan {
          members wired;
        }
      }
    }
  }
}
```

This would replace the contents of `ge-0/0/0` with the above config on the device.

If you moved the replace above `interfaces`, like below, the contents of `interfaces` would be replaced.

```
replace:
interfaces {
  ge-0/0/0 {
    description PC1;
    unit 0 {
      family ethernet-switching {
        vlan {
          members wired;
        }
      }
    }
  }
```

Using this `replace:` in certain locations can allow you to incrementally start managing configuration sections via this process, until you get to the point where you can render and replace the entire configuration.

You can read more about `replace:` [here](https://www.juniper.net/documentation/us/en/software/junos/cli/topics/topic-map/junos-config-files-loading.html)

##### lstrp_blocks

If you look at the top of `roles/config/templates/baseconf.j2'`, you will see `#jinja2: lstrip_blocks: True`. This is done to "strip tabs and spaces from the beginning of a line to the start of a block." This is because when doing looping/conditionals in Jinja2 the indenting/spacing gets weird.

The indents are particularly important when doing network configurations, and while you can use `-` and `+` to control it, I've found it much easier to just turn `lstrip_blocks` on

More information about this can be found [here](https://blog.networktocode.com/post/whitespace-control-in-jinja-templates/)

## Put It Together

### Render and Diff

If we run our code we can see it creates a rendered configuration and loads it into the device as a candidate configuration, and writes out a diff file.

This is in essence a `load`, `show | compare` on the CLI

```
-> ansible-playbook -i hosts.yml -u admin -k site.yml
SSH password:

PLAY [Configure] *****************************************************************

TASK [config : Commit Changes] ***************************************************
skipping: [router.yzguy.io]

TASK [config : Ensure ./configs/router.yzguy.io dir exists] **********************
ok: [router.yzguy.io]

TASK [config : Render template for router.yzguy.io] ******************************
ok: [router.yzguy.io]

TASK [config : Load Config, Diff (True), Commit (False)] *************************
changed: [router.yzguy.io]

PLAY RECAP ***********************************************************************
router.yzguy.io            : ok=3    changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

If we go into the `.configs/router.yzguy.io` directory, we will see two files:

* `rendered.conf` - our rendered configuration
* `diff` - the `show | compare` output of our rendered configuration

By looking at these we can see how our template is rendering, and what changes would happen if it were to be applied.

### Commit

After we review the rendered configuration and the diff, if we decide everything looks good, we can apply it.

By setting the variable we pass in to `napalm_install_config` as a variable, with a default of `False`, we can
override it to `True` using `--extra-vars` or `-e` for short with our CLI command as seen below.

A warning message was added to make it more apparent that changes to the live device were going to happen.

```
-> ansible-playbook -i hosts.yml -u admin -k site.yml -e commit_changes=True
SSH password:

PLAY [Configure] *****************************************************************

TASK [config : Commit Changes] ***************************************************
ok: [router.yzguy.io] => {
    "msg": "[WARNING]: COMMIT_CHANGES is TRUE"
}

TASK [config : Ensure ./configs/router.yzguy.io dir exists] **********************
ok: [router.yzguy.io]

TASK [config : Render template for router.yzguy.io] ******************************
ok: [router.yzguy.io]

TASK [config : Load Config, Diff (True), Commit (True)] **************************
changed: [router.yzguy.io]

PLAY RECAP ***********************************************************************
router.yzguy.io            : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

If we look at the device after setting `commit_changes=True`, we will see that the configuration we rendered
is in fact active on the device.

```
ubnt@router> show configuration interfaces
ge-0/0/0 {
    description PC1;
    unit 0 {
        family ethernet-switching {
            vlan {
                members wired;
            }
        }
    }
}
ge-0/0/1 {
    unit 0 {
        family ethernet-switching {
            vlan {
                members lab;
            }
        }
    }
}
ge-0/0/2 {
    unit 0 {
        family ethernet-switching {
            port-mode trunk;
            vlan {
                members [ wired wireless guest lab ];
            }
            native-vlan-id native;
        }
    }
}

ubnt@router> show configuration vlans
...
guest {
    vlan-id 30;
}
lab {
    vlan-id 40;
}
native {
    vlan-id 100;
}
wired {
    vlan-id 10;
}
wireless {
    vlan-id 20;
}

{master:0}
```

The other options under `napalm_install_config` can be viewed [here](https://github.com/napalm-automation/napalm-ansible/blob/develop/napalm_ansible/modules/napalm_install_config.py#L46)

## Conclusion

This is not an exhaustive example, but it is an end to end configuration render and apply using variables that are collected dynamically based on groupings.

The example in particular focuses on `JunOS`, but can easily be swapped to include or use other network operating systems such as Arista `EOS`, or any other [supported OS by NAPALM](https://napalm.readthedocs.io/en/latest/#supported-network-operating-systems)
