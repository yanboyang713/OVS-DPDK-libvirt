#!/bin/bash -x



# Variables #
SOCK_DIR=/usr/local/var/run/openvswitch
HUGE_DIR=/dev/hugepages
MEM=3072M


function start_test {
    sudo mkdir -p $HUGE_DIR
    sudo umount $HUGE_DIR
    echo "Lets bind the ports to the kernel first"
    sudo $DPDK_DIR/tools/dpdk-devbind.py --bind=$KERNEL_NIC_DRV $DPDK_PCI1 $DPDK_PCI2
    sudo mount -t hugetlbfs nodev $HUGE_DIR

    sudo modprobe uio
    sudo rmmod igb_uio.ko
    sudo insmod $DPDK_IGB_UIO
    sudo $DPDK_BIND_TOOL --bind=igb_uio $DPDK_PCI1 $DPDK_PCI2

    sudo rm /usr/local/etc/openvswitch/conf.db
    sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema

    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="$DPDK_LCORE_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="$DPDK_SOCKET_MEM"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"

    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sleep 22
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0 -- set Bridge br0 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $DPDK_NIC1 -- set Interface $DPDK_NIC1 type=dpdk options:dpdk-devargs=$DPDK_PCI1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Interface $DPDK_NIC1 type=dpdk

# if flow setting the VNI , create vxlan port as below
    #sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=100.0.0.2 options:key=flow
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=10.0.0.2 options:key=1000
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC1 -- set Interface $VHOST_NIC1 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC2 -- set Interface $VHOST_NIC2 type=dpdkvhostuser

    echo "creating the external bridge"
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-phy
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-phy -- set Bridge br-phy datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set bridge br-phy other_config:hwaddr=00:00:64:00:00:01
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-phy $DPDK_NIC2 -- set Interface $DPDK_NIC2 type=dpdk options:dpdk-devargs=$DPDK_PCI2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Interface $DPDK_NIC2 type=dpdk

    sudo ip addr add 10.0.0.1/24 dev br-phy
    sudo ip link set br-phy up
    sudo iptables -F
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 10.0.0.1/24 br-phy
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 0.0.0.0 br0
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br0 10.0.0.1 00:00:64:00:00:01
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy 10.0.0.2 00:00:64:00:00:02
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy 10.0.0.20 20:20:10:10:10:10

    echo "Add necessary rules for the bridges"
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-phy

# set up the tunnel with VNI
#    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,nw_src=192.168.1.101,nw_dst=192.168.3.101,action=set_tunnel:1001,output:2 #Encap
#    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,nw_src=192.168.10.101,nw_dst=192.168.30.101,action=set_tunnel:1000,output:2 #Encap

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,action=output:3
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=3,action=output:1 # bidi
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,action=output:4
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=4,action=output:2 # bidi

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy idle_timeout=0,in_port=1,action=output:LOCAL
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy idle_timeout=0,in_port=LOCAL,action=output:1


    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
#    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br-phy
#    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br-phy
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."
    sleep 5
    echo "launching the VM"
    sudo taskset 0x00000030 sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm1 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp 2 -drive file=$VM_IMAGE -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC1 -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac=01:00:00:00:00:01,netdev=mynet1,mrg_rxbuf=off -chardev socket,id=char1,path=$SOCK_DIR/$VHOST_NIC2 -netdev type=vhost-user,id=mynet2,chardev=char1,vhostforce -device virtio-net-pci,mac=01:00:00:00:00:02,netdev=mynet2,mrg_rxbuf=off --nographic -snapshot -vnc :5

}

function kill_switch {
    echo "Killing the switch.."
    sudo $OVS_DIR/utilities/ovs-appctl -t ovs-vswitchd exit
    sudo $OVS_DIR/utilities/ovs-appctl -t ovsdb-server exit
    sleep 1
    sudo pkill -9 ovs-vswitchd
    sudo pkill -9 ovsdb-server
    sudo umount $HUGE_DIR
    sudo pkill -f qemu-system-x86_64*
    sudo rm -rf /usr/local/var/run/openvswitch/*
    sudo rm -rf /usr/local/var/log/openvswitch/*
    sudo pkill -f pmd*
}

function menu {
        echo "launching Switch.."
        kill_switch
        start_test
}
