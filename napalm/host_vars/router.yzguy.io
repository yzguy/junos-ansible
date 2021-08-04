---
interfaces:
  'ge-0/0/0':
    description: PC1
    mode: access
    vlans:
      - wired
  'ge-0/0/1':
    mode: access
    vlans:
      - lab
  'ge-0/0/2':
    mode: trunk
    vlans:
      - wired
      - wireless
      - guest
      - lab
    native_vlan: native

vlans:
  - name: native
    vlan_id: 100

  - name: wired
    vlan_id: 10

  - name: wireless
    vlan_id: 20

  - name: guest
    vlan_id: 30

  - name: lab
    vlan_id: 40
