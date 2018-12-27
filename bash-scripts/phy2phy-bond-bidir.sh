#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh
echo $OVS_DIR $DPDK_DIR

# Variables #
HUGE_DIR=/dev/hugepages


function start_test {
    print_phy2phy_bond_banner
    set_dpdk_env
    sudo umount $HUGE_DIR
    echo "Lets bind the ports to the kernel first"
    sudo $DPDK_BIND_TOOL -u $DPDK_PCI1 $DPDK_PCI2 $DPDK_PCI3 $DPDK_PCI4
    mkdir -p $HUGE_DIR
    sudo mount -t hugetlbfs nodev $HUGE_DIR

    sudo modprobe uio
    sudo rmmod igb_uio.ko
    sudo insmod $DPDK_IGB_UIO
    sudo $DPDK_BIND_TOOL --bind=igb_uio $DPDK_PCI1 $DPDK_PCI2 $DPDK_PCI3 $DPDK_PCI4
    echo "dpdk0 - $DPDK_PCI1"
    echo "dpdk1 - $DPDK_PCI2"
    echo "dpdk2 - $DPDK_PCI3"
    echo "dpdk3 - $DPDK_PCI4"

    echo "USE ONLY NORMAL ACTION. CANNOT USE WITH SPECIFIC OF ACTIONS.."

    sudo rm /usr/local/etc/openvswitch/conf.db
    sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema

    sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="$DPDK_LCORE_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="$DPDK_SOCKET_MEM"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch .  other_config:n-handler-threads=1
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"

    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sleep 22
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0 -- set bridge br0 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 $DPDK_NIC1 -- set Interface $DPDK_NIC1 type=dpdk options:dpdk-devargs=$DPDK_PCI1
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 $DPDK_NIC2 -- set Interface $DPDK_NIC2 type=dpdk options:dpdk-devargs=$DPDK_PCI2
    #sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 $DPDK_NIC3 -- set Interface $DPDK_NIC3 type=dpdk options:dpdk-devargs=$DPDK_PCI3
    #sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 $DPDK_NIC4 -- set Interface $DPDK_NIC4 type=dpdk options:dpdk-devargs=$DPDK_PCI4
    sudo $OVS_DIR/utilities/ovs-vsctl add-bond br0 dpdkbond1 $DPDK_NIC3 $DPDK_NIC4 \
                                                    lacp=active \
                                                    -- set Interface $DPDK_NIC3 type=dpdk options:dpdk-devargs=$DPDK_PCI3 \
                                                    -- set Interface $DPDK_NIC4 type=dpdk options:dpdk-devargs=$DPDK_PCI4

    sudo $OVS_DIR/utilities/ovs-vsctl set port dpdkbond1 bond_mode=balance-slb
#   sudo $OVS_DIR/utilities/ovs-vsctl set port dpdkbond1 bond_mode=balance-tcp
#   sudo $OVS_DIR/utilities/ovs-vsctl set port dpdkbond1 bond_mode=active-backup
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 actions=NORMAL
    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show

    echo "Finished setting up the bridge, ports and flows..."
}

function kill_switch {
    echo "Killing the switch.."
    sudo $OVS_DIR/utilities/ovs-appctl -t ovs-vswitchd exit
    sudo $OVS_DIR/utilities/ovs-appctl -t ovsdb-server exit
    sleep 1
    sudo pkill -9 ovs-vswitchd
    sudo pkill -9 ovsdb-server
    sudo umount $HUGE_DIR
    sudo pkill -9 qemu-system-x86_64*
    sudo rm -rf /usr/local/var/run/openvswitch/*
    sudo rm -rf /usr/local/var/log/openvswitch/*
    sudo pkill -9 pmd*
}

function menu {
        echo "launching Switch.."
        kill_switch
        start_test
}

#The function has to get called only when its in subshell.
if [ "$OVS_RUN_SUBSHELL" == "1" ]; then
    menu
fi
