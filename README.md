# Artifact Evaluation for "Sonic: the Next-Gen Local Disks for the Cloud" ([EuroSys 2024 AE](https://sysartifacts.github.io/eurosys2024/))

## 1. Introduction
This Artifact Evaluation is for "Sonic: the Next-Gen Local Disks for the Cloud" accepted by EuroSys 2024. The goal of this Artifact Evaluation is to help you 1) get project source code; 2) rebuild the project from scratch; 3) reproduce the main experimental results of the paper. 
	
If you have any questions, please contact us via email or HotCRP.

## 2. Access Source Code (Artifact Available)
The source code of CSAL is accepted by SPDK community ([BSD 3-clause license](https://opensource.org/license/bsd-3-clause/)) and merged into SPDK main branch at [Github](https://github.com/spdk/spdk). In SPDK, CSAL is implemented as a [Flash Translation Layer](https://spdk.io/doc/ftl.html) module. You can find CSAL implementation under the folder "[spdk/lib/ftl](https://github.com/spdk/spdk/tree/master/lib/ftl)".

Note: any SPDK applications (e.g., vhost, nvmf_tgt, iscsi_tht) can use CSAL to construct a block-level cache for storage acceleration. In the following case, we will use vhost as an example that is the same as our EuroSys paper.

## 3. Build CSAL Application (Artifact Functional)
### Overview
The figure describes the high level architecture of what we will build in this guide. First, we construct a CSAL block device (the red part in figure). Second, we start a vhost target and assign this CSAL block device to vhost (the yellow part in figure). Third, we launch a virtual machine (the blue part in figure) that communicates with the vhost target. Finally, you will get a virtual disk in the VM. The virtual disk is accelerated by CSAL.

### Prerequisites
#### Artifact Check-List
- OS: Linux 3.10 or higher version.
- CPU: Intel Xeon Processor Ice Lake (recommended).
- Storage:
  - NVMe QLC SSD (for capacity layer).
  - NVMe Optane SSD or SLC SSD (for cache layer).
- Memory: at least 30GB DRAM.
  
#### Prepare SPDK
1. Get the source code:

```bash
git clone https://github.com/spdk/spdk --recursive
cd spdk
# switch to a formal release version (e.g., v23.05)
git checkout v23.05
```

2. Compile SPDK
```bash
sudo scripts/pkgdep.sh # install prerequisites
./configure
make
```

3. Configure huge pages
```bash
sudo HUGEMEM=16384 ./setup.sh # set up 16GB huge pages
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
rpc.py bdev_nvme_attach_controller -b nvme0 -t PCIe -a 0000:01:00.0
# construct cache device NVMe1 with BDF "0000:02:00.0"
rpc.py bdev_nvme_attach_controller -b NVMe1 -t PCIe -a 0000:02:00.0
# construct CSAL device FTL0 on top of NVMe0 and NVMe1
rpc.py bdev_ftl_create -b FTL0 -d NVMe0n1 -c NVMe1n1
```

3. Use RAM disks (Optional)
```bash
# You can use RAM disks to constuct CSAL if you do not have required
# hardware. However, RAM disks are only used for guiding how to build
# CSAL, they can not reflect real behavior of CSAL.

# construct capacity device Malloc0 with RAM disk
scripts/rpc.py bdev_malloc_create -b Malloc0 64 512
# construct cache device Malloc1 with RAM disk
scripts/rpc.py bdev_malloc_create -b Malloc1 64 512
# construct CSAL device FTL0 on top of Malloc0 and Malloc1
rpc.py bdev_ftl_create -b FTL0 -d Malloc0 -c Malloc1
``` 
4. Construct vhost-blk controller with CSAL block device
```bash
# The following RPC will create a vhost-blk device exposing FTL0 device. 
# The device will be accessible to QEMU via /var/tmp/vhost.1. All the I/O
# polling will be pinned to the least occupied CPU core within given
# cpumask - in this case always CPU 0. 
rpc.py vhost_create_blk_controller --cpumask 0x1 vhost.1 FTL0
```
5. Launch a virtual machine using QEMU
```bash
qemu-system-x86 xxx
```
## 4. Start Evaluation (Results Reproduced)