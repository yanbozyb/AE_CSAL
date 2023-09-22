# Artifact Evaluation for "Sonic: the Next-Gen Local Disks for the Cloud" ([EuroSys 2024 AE](https://sysartifacts.github.io/eurosys2024/))

# 1. Introduction
This Artifact Evaluation is for "Sonic: the Next-Gen Local Disks for the Cloud" accepted by EuroSys 2024. The goal of this Artifact Evaluation is to help you 1) get project source code; 2) rebuild the project from scratch 3) reproduce the main experimental results of the paper. 
	
If you have any questions, please contact us via email or HotCRP.

# 2. Access Source Code (Artifact Available)
The source code of CSAL is accepted by SPDK community ([BSD 3-clause license](https://opensource.org/license/bsd-3-clause/)) and merged into SPDK main branch at [Github](https://github.com/spdk/spdk). In SPDK, CSAL is implemented as a [Flash Translation Layer](https://spdk.io/doc/ftl.html) module. You can find CSAL implementation under the folder "[spdk/lib/ftl](https://github.com/spdk/spdk/tree/master/lib/ftl)".

Note: any SPDK applications (e.g., vhost, nvmf_tgt, iscsi_tht) can use CSAL to construct a block-level cache for storage acceleration. In the following case, we will use vhost as an example that is the same as our EuroSys paper.

# 3. Build CSAL Application (Artifact Functional)
## Overview
The figure describes the high level architecture of what we will build in this guide. First, we construct a CSAL block device (the red part in figure). Second, we start a vhost target and assign this CSAL block device to vhost (the yellow part in figure). Third, we launch a virtual machine (the blue part in figure) that communicates with the vhost target. Finally, you will get a virtual disk in the VM. The virtual disk is accelerated by CSAL.

## Prerequisites
### Artifact Check-List
- OS: Linux 3.10 or higher version.
- CPU: Intel Xeon Processor Ice Lake (recommended).
- Storage:
  - NVMe QLC SSD (for capacity layer).
  - NVMe Optane SSD or SLC SSD (for cache layer).
- Memory: at least 30GB DRAM.
  
### Prepare SPDK
1. Get the source code:

```
git clone https://github.com/spdk/spdk --recursive
cd spdk  
```

2. Switch to a formal release version (e.g., v23.05)
```
git checkout v23.05
```

3. Compile SPDK
```
./configure
make
```

4. Configure huge pages
```
sudo HUGEMEM=8192 ./setup.sh
```

### Build SPDK Application with CSAL
1. Start spdk target  
2. Construct SPDK block devices  
3. Construct CSAL block device  
4. Construct vhost-blk target  
5. Assign CSAL block device to vhost-blk target  
6. Launch a virtual machine using QEMU

