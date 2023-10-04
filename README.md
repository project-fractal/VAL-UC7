# VAL-UC7 ROS2 on NOEL-V demo
This page briefly explains FRACTAL use-case 7 architecture and provides instructions for setup of the system running ROS2 nodes on NEOL-V, giving some hints and solutions to problems. Source code of SPIDER robot is not publicy availaible, therefore the implemented vehicle functions are not discussed here.

## UC7 System Architecture
![UC7 Architecture](images/arch.drawio.png?raw=true, "UC7 Architecture")
[Smart PysIcal Demonstration and Evaluation Robot (SPIDER)](https://www.v2c2.at/spider/) is a mobile hardware-in-the-loop platform for reproducable testing of sensor or vehicle functions. The SPIDER high-level software is executed on an industrial PC with Linux, using the [Robot Operating System (ROS)](https://www.ros.org/). Actuation to the robot motor controllers, servos, and the battery system is transmitted by a safety mictrocontroller via CAN.

Within the use-case a [Xilinx VCU118](https://www.xilinx.com/products/boards-and-kits/vcu118.html) FPGA is connected via ethernet to the PC. At the FPGA a [NOEL-V](https://www.gaisler.com/index.php/products/processors/noel-v) based system is used, utilizing the open source project [Isar RISC-V](https://github.com/siemens/isar-riscv), [SELENE platform](https://gitlab.com/selene-riscv-platform/). On a Debain based Linux, we are running the vehicle nodes as [ROS2](https://docs.ros.org/en/foxy/index.html) nodes. The nodes at the FPGA communicate using a [ROS Bridge](https://github.com/ros2/ros1_bridge) to the PC of the SPIDER.

## Connect FPGA Board
### Tools
**Install GRMON:** https://www.gaisler.com/index.php/downloads/debug-tools
```
# Add path to GRMON, e.g.:
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/grmon/grmon-eval-3.3.2/linux/lib64
export PATH=${PATH}:/opt/grmon/grmon-eval-3.3.2/linux/bin64
```

**Install Xilinx Vivado Lab:** https://www.xilinx.com/support/download.html
```
sudo ./installLibs.sh
sudo ./xsetup
# source Xilinx Vivado Lab
source /opt/xilinx/Vivado_Lab/2022.2/settings64.sh
# install cable drivers
cd /opt/xilinx/Vivado_Lab/2022.2/data/xicom/cable_drivers/lin64/install_script/install_drivers
sudo ./install_drivers 
```

### Program FPGA device
```
# Open Vivado Lab
# Open Hardware Manager
# Open Target / Auto Connect
# Program device with desired bitstream file
```

### Connect using GRMON
```
 grmon -u -uart /dev/ttyUSB1  # device number may change
 source eth_config.tcl        # take from selene-hardware/selene-soc/selene-xilinx-vcu118/eth_config.tcl
 grmon -u -eth 192.168.0.51
```

## Build NOEL-V with ROS2
Get the code and installation instructions from [Isar RISC-V Readme](https://github.com/siemens/isar-riscv).

**Build NOEL-V:** https://github.com/siemens/isar-riscv/blob/main/doc/NOELV.md

**Add ROS2 packages:** https://github.com/siemens/isar-riscv/blob/main/doc/ROS2.md

## Start Linux
```
do.sh linux  # in scripts folder
```
The same script can be used also for starting QEMU, compiling device tree, configuring eth on the FPGA and further. To check all functions of the sript use
```
do.sh help
```
The script might need some modification based on your repository structure

## Run ROS2
### Easy but slow
https://github.com/siemens/isar-riscv/blob/main/doc/ROS2.md#run-the-demos

Simply source the ROS2 distro and workspace and start via launch file. The *problem* with that solution is that this workflow uses python to intrerpret the launch file, taking a lot of time.

### Complicated but fast
Use file from scripts folder, first the IP adresses in the scripts need to be adapted.

```
source demo_nodes.env
./start_demo_nodes.sh
```
This script directly starts the ROS binaries without executing Python launch files. If config files are used, those needs to be moved and adjusted manually to the install folder of the workspace.

## Connect ROS2 on FGPA with other ROS2 network
The default multicast discovery of ROS2 nodes via network is not working with the FPGA. To avoid this problem, multicast needs to be deactivated and the peers need to be added manually. Cyclon DDS is used as middleware. Check the ccds-*.xml files in the script folder.

### Start at FPGA
See run ROS2 instructions above

### Start at x86
```
# source ROS distribution and workspace
export cdds_x86.xml
# launch your nodes via ROS2 launch files
```