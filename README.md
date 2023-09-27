# Artifact Evaluation for "Sonic: the Next-Gen Local Disks for the Cloud" ([EuroSys 2024 AE](https://sysartifacts.github.io/eurosys2024/))

## 1. Introduction
This Artifact Evaluation is for "Sonic: the Next-Gen Local Disks for the Cloud" accepted by EuroSys 2024. The goal of this Artifact Evaluation is to help you 1) get project source code; 2) rebuild the project from scratch; 3) reproduce the main experimental results of the paper. 
	
If you have any questions, please contact us via email or HotCRP.

## 2. Access Source Code
The source code of CSAL is accepted by SPDK community ([BSD 3-clause license](https://opensource.org/license/bsd-3-clause/)) and merged into SPDK main branch at [Github](https://github.com/spdk/spdk). In SPDK, CSAL is implemented as a [Flash Translation Layer](https://spdk.io/doc/ftl.html) module. You can find CSAL implementation under the folder "[spdk/lib/ftl](https://github.com/spdk/spdk/tree/master/lib/ftl)".

Note: any SPDK applications (e.g., vhost, nvmf_tgt, iscsi_tht) can use CSAL to construct a block-level cache for storage acceleration. In the following case, we will use vhost as an example that is the same as our EuroSys paper.

## 3. Kick-the-tire Instructions (10 minutes)
### Overview
The figure describes the high level architecture of what we will build in this guide. First, we construct a CSAL block device (the red part in figure). Second, we start a vhost target and assign this CSAL block device to vhost (the yellow part in figure). Third, we launch a virtual machine (the blue part in figure) that communicates with the vhost target. Finally, you will get a virtual disk in the VM. The virtual disk is accelerated by CSAL.

### Prerequisites
#### Artifact Check-List
- OS: Linux 3.10 or higher version.
- Storage:
  - NVMe QLC SSD (for capacity layer).
  - NVMe Optane SSD or SLC SSD (for cache layer).
- Memory: at least 30GB DRAM.
  
#### Prepare SPDK
1. Get the source code:
```bash
git clone https://github.com/spdk/spdk --recursive
cd spdk
# switch to a formal release version (e.g., v22.09)
git checkout v22.09
# get correct DPDK version
git submodule update --init
```

2. Compile SPDK
```bash
sudo scripts/pkgdep.sh # install prerequisites
./configure
make
```

3. Set cache device and capacity device sector size 4KB with nvme-cli, for example:
```bash
nvme format /dev/nvme4n1  -b 4096 --force
```

4. Set cache device VSS enabled with nvme-cli, for example:
```bash
nvme format /dev/nvme3 --namespace-id=1 --lbaf=4 --force --reset
```
if do not have fast NVMe device that support VSS well, you can use CSAL VSS SW emulation to run performance testing and study, this does not promise power safety and crash consistency. Solidigm already have solution to support non VSS NVMe as cache device. please stay tuned.
to build CSAL with VSS SW emulation support, please modify below makefile
```bash
vim lib/ftl/Makefile
#find below defination SPDK_FTL_VSS_EMU
ifdef SPDK_FTL_VSS_EMU
CFLAGS += -DSPDK_FTL_VSS_EMU
endif

#force enable SPDK_FTL_VSS_EMU macro by comment out the ifdef as below
#ifdef SPDK_FTL_VSS_EMU
CFLAGS += -DSPDK_FTL_VSS_EMU
#endif
```

5. Configure huge pages
```bash
sudo HUGEMEM=16384 ./scripts/setup.sh # set up 16GB huge pages
```

#### Build SPDK Application with CSAL
1. Start SPDK vhost target
```bash
# start vhost on CPU 0 and 1 (cpumask 0x3)
sudo build/bin/vhost -S /var/tmp -m 0x3
```

2. Construct CSAL block device
```bash
# Before staring the following instructions, you should get
# your NVMe devices' BDF number.

# construct capacity device NVMe0 with BDF "0000:01:00.0"
scripts/rpc.py bdev_nvme_attach_controller -b nvme0 -t PCIe -a 0000:01:00.0
# construct cache device NVMe1 with BDF "0000:02:00.0"
scripts/rpc.py bdev_nvme_attach_controller -b nvme1 -t PCIe -a 0000:02:00.0
# construct CSAL device FTL0 on top of NVMe0 and NVMe1
scripts/rpc.py bdev_ftl_create -b FTL0 -d nvme0n1 -c nvme1n1
```

3. Use RAM disks (Under Contruction, Please stay tuned for this part)
```bash
# You can use RAM disks to constuct CSAL if you do not have required
# hardware. However, RAM disks are only used for guiding how to build
# CSAL, they can not reflect real behavior of CSAL.

#make sure enough huge page is reserved for devices
echo 32768 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# construct capacity device Malloc0 with RAM disk
scripts/rpc.py bdev_malloc_create -b Malloc0 20480 4096
# construct cache device Malloc1 with RAM disk
scripts/rpc.py bdev_malloc_create -b Malloc1 5120 4096 -m 64
# construct CSAL device FTL0 on top of Malloc0 and Malloc1
scripts/rpc.py bdev_ftl_create -b FTL0 -d Malloc0 -c Malloc1
```

4. Construct vhost-blk controller with CSAL block device
```bash
# The following RPC will create a vhost-blk device exposing FTL0 device. 
# The device will be accessible to QEMU via /var/tmp/vhost.1. All the I/O
# polling will be pinned to the least occupied CPU core within given
# cpumask - in this case always CPU 0. 
scripts/rpc.py vhost_create_blk_controller --cpumask 0x1 vhost.1 FTL0
```

5. Launch a virtual machine using QEMU
```bash
qemu-system-x86_64 -m 8192 -smp 64 -cpu host -enable-kvm -hda /mnt/nvme6n1/fedora37.qcow2 -netdev user,id=net0,hostfwd=tcp::32001-:22 -device e1000,netdev=net0 -display none -vga std -daemonize -pidfile /var/run/qemu_0 -object memory-backend-file,id=mem,size=8G,mem-path=/dev/hugepages,share=on -numa node,memdev=mem -chardev socket,id=char0,path=/mnt/nvme6n1/wayne/csal/vhost.1 -device vhost-user-blk-pci,num-queues=16,id=blk0,chardev=char0
#connect your qemu VM via
ssh root@localhost -p 32001
```
notes:
   - please change -hda qemu img to your path
   - please change path to the actual vhost path from vhost app log

## 4. Evaluation Instructions
### Environment
To reproduce the same experimental results as ours, please use the following environment as far as possible.
- OS: Linux CentOS Kernel 4.19
- CPU: 2x Intel 8369B @ 2.90GHz
- Memory: 128GB DDR4 Memory
- NVMe SSDs:
  - 1x Intel P5800X 800GB NVMe SSD (for cache)
  - 1x Intel/Solidigm P5316 15.35TB NVMe SSD

Before starting the following instructions, you have to log into the VM first. ***We prepared a Virtual Machine (VM) in our cloud platform. The VM is set up with a CSAL powered virtual disks and equipped all the required hardware. You can start reproducing the performance experiments (only for figures 10, 11, 12) directly without required hardware. Please contact us for VM login in information***

### Prerequisites (16+ hours)
#### Preconditioning SSD (16+ hours)
Before starting evaluation, we should precondition the disks in order to make them enter "stable state".
The folder "precondition" in our Artifact Evaluation repository includes a script to precondition disks. You can use this configuration and follow the following instructions.
```bash
yum install fio -y
git clone https://github.com/yanbozyb/AE_CSAL.git
cd AE_CSAL
sh precondition/start.sh
```
This will take much long time to precondition virtual disks by sequentially writing whole space twice followed by randomly writes to whole space area.

#### Preparing Partitions
After preconditioning, we should prepare partitions. In our experiments, we construct 8 VMs, each is assigned a partition of CSAL device. To simplify experiments in Artifact Evaluation, we encourage users to split the virtual disk into multiple partitions (e.g., 8 partitions) and then launch multiple FIO jobs to generate workloads on each partition. In this case, each job can be considered as a tenant (i.e., VM). The following script splits "/dev/nvme3n1" into 8 partitions.
```bash
sh autopartition.sh

          Start          End    Size  Type            Name
 1          256    390625023    1.5T  Microsoft basic primary
 2    390625024    781250047    1.5T  Microsoft basic primary
 3    781250048   1171875071    1.5T  Microsoft basic primary
 4   1171875072   1562500095    1.5T  Microsoft basic primary
 5   1562500096   1953125119    1.5T  Microsoft basic primary
 6   1953125120   2343749887    1.5T  Microsoft basic primary
 7   2343749888   2734374911    1.5T  Microsoft basic primary
 8   2734374912   3124999935    1.5T  Microsoft basic primary
```

### Reproducing Figures 10, 11, 12 (2+ hours)
First, to reproduce **figure 10**, you could execute the following instructions:
```bash
sh raw/uniform/start.sh
```
The results will be generated in "raw/uniform/results_rnd_workloads" and "raw/uniform/results_rnd_workloads" folders. The output of each case should be as follows. You can find write throughput is xxx MB/s (all partitions included) in this example.
```bash
fio results
```

Second, to reproduce **figure 11**, you could execute the following instructions:
```bash
# for 4KB skewed workloads (i.e., Figure 11(a))
fio raw/skewed/fio_4k_zipf0.8.job
fio raw/skewed/fio_4k_zipf1.2.job

# for 64KB skewed workloads (i.e., Figure 11(b))
fio raw/skewed/fio_64k_zipf0.8.job
fio raw/skewed/fio_64k_zipf1.2.job
```

Third, to reproduce **figure 12**, you could execute the following instructions:
```bash
# for 64KB miaxed workloads (i.e., Figure 12(a))
fio raw/mixed/fio_rwmix_64k.job

# for 4KB miaxed workloads (i.e., Figure 12(b))
fio raw/mixed/fio_rwmix_4k.job
```

The output of each case should be as follows. The read and write results are separate. You can find write throughput is xxx MB/s (all partitions included) and read throughput is xxx MB/s in this example.
```bash
fio results
```

### Reproducing Figures 13 (1+ hours)
To reproduce **figure 13**, we should run the same workloads as figure 11.
```bash
# for 4KB skewed workloads (i.e., Figure 11(a))
fio raw/skewed/fio_4k_zipf0.8.job
fio raw/skewed/fio_4k_zipf1.2.job

# for 64KB skewed workloads (i.e., Figure 11(b))
fio raw/skewed/fio_64k_zipf0.8.job
fio raw/skewed/fio_64k_zipf1.2.job
```

We obtain the write amplification factor by dividing the total size of NAND writes by the total logical writes. Before and after each test, you can use nvme cli tool to get the current NAND writes of QLC drive. FIO will report total logical writes when finishing the tests. The example that shows how to use nvme cli tool to get NAND writes is as follows:
```bash
sudo nvme identify
```

### Reproducing Figures 14 (30+ minutes)
To reproduce **figure 14**, we should run 4k random writes workloads as follows.
```bash
fio raw/uniform/fio_rnd_4k.job
```
During the test, spdk iostat tool can be used to get CASL backend traffic.
```bash
scripts/spdk_iostat
```
