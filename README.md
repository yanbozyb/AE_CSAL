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
# switch to a formal release version (e.g., v23.05)
git checkout v23.05
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

## 4. Evaluation Instructions
### Environment
To reproduce the same experimental results as ours, please use the following environment as far as possible.
- OS: Linux CentOS Kernel 4.19
- CPU: 2x Intel 8369B @ 2.90GHz
- Memory: 128GB DDR4 Memory
- NVMe SSDs:
  - 1x Intel P5800X 800GB NVMe SSD (for cache)
  - 1x Intel/Solidigm P5316 15.35TB NVMe SSD

***We prepared a Virtual Machine (VM) in our cloud platform. The VM is set up with a CSAL powered virtual disks and equipped all the required hardware. You can start reproducing the performance experiments (only for figures 10, 11, 12) directly without required hardware. Please contact us for VM login in information***

### Prerequisites (6+ hours)
#### Preconditioning SSD (6+ hours)
To make SSD enter stable state, we should precondition QLC SSDs by sequentially fill whole space twice and then randomly write the whole space once. The folder "precondition" in this Github repository includes configuration needed for FIO benchmark tool. You can use this configuration and follow the following instructions.
```bash
git clone xxxx
cd xxxx
fio xxxx
```
#### Preparing Partitions
After preconditioning, we should prepare partitions. In our experiments, we construct 8 VMs, each is assigned a partition of CSAL device. To simplify experiments in Artifact Evaluation, we encourage users to split the virtual disk into multiple partitions and then launch multiple FIO jobs to generate workloads on each partition. In this case, each job can be considered as a tenant (i.e., VM). The following instructions split the whole virtual disk into 8 partitions using *fdisk*.
```bash
fdisk /dev/vdb
xxxx
```

### Reproducing Figures 10, 11, 12 (3+ hours)
First, to reproduce **figure 10**, you could execute the following instructions:
```bash
# for sequential workloads (i.e., Figure 10(a))
fio raw/uniform/fio_seq_4k.job
fio raw/uniform/fio_seq_8k.job
fio raw/uniform/fio_seq_16k.job
fio raw/uniform/fio_seq_32k.job
fio raw/uniform/fio_seq_64k.job
fio raw/uniform/fio_seq_128k.job

# for random workloads (i.e., Figure 10(b))
fio raw/uniform/fio_rnd_4k.job
fio raw/uniform/fio_rnd_8k.job
fio raw/uniform/fio_rnd_16k.job
fio raw/uniform/fio_rnd_32k.job
fio raw/uniform/fio_rnd_64k.job
fio raw/uniform/fio_rnd_128k.job
```

The output of each case should be as follows. You can find write throughput is xxx MB/s (all partitions included) in this example.
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
