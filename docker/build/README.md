# Build and run with Docker

Files in this directory demonstrate how to build and install the SGX SDK and PSW, and run SGX applications in Docker containers.

## Quick Start

###  Prerequisites
1. Install [Docker and Compose](https://docs.docker.com/) and configure them properly following their respective installation guide.
2. If running an older Linux* kernel version ([`< 5.11`](https://git.kernel.org/torvalds/c/5583ff677b3108cde989b6d4fd1958e091420c0c)), install the legacy [SGX Flexible Launch Control driver](https://github.com/intel/confidential-computing.tee.dcap/tree/DCAP_1.23.101/driver/linux). **Note**: See below to run with the Legacy Launch Control driver. 
3. In the root directory of this repo, prepare source code and download prebuilt binaries:
```
$ make preparation
```

### Run with Docker Compose
This will start AESM and an SGX sample on one terminal using docker-compose.
```
$ ./build_compose_run.sh
```

## Dockerfile

The Dockerfile specifies 3 image build targets:
1. builder: Builds PSW and SDK debian installers from source.
2. aesm_deb: Takes the PSW debian installer from builder to install and run the AESM daemon.
3. sample_deb: Takes the SDK installer and the PSW debian installer from builder to install. Then builds and runs an SGX SDK sample (`SAMPLE_NAME`, default `SampleEnclave`).

- [build_and_run_aesm_deb_docker.sh](./build_and_run_aesm_deb_docker.sh): Shows how to build and run the AESM image in Docker. This will start the AESM service listening to a named socket, located in /var/run/aesmd in the container and mounted in Docker volume aesmd-socket.
- [build_and_run_sample_deb_docker.sh](./build_and_run_sample_deb_docker.sh): Shows how to build and run an SGX SDK sample inside a Docker container with a locally built SGX sample image.
- [build_compose_run.sh](./build_compose_run.sh): Shows how to use docker-compose to build and run both AESM and sample containers.

## Legacy Launch Control driver and kernel for SGX

All SGX applications need access to the SGX device nodes exposed by the kernel space driver. Depending on the driver or kernel you are using, the SGX device nodes may have different names and locations. Therefore, you need to ensure those nodes are mapped and mounted inside the containers properly.


[SGX kernel patches](https://git.kernel.org/pub/scm/linux/kernel/git/tip/tip.git/log/?h=x86/sgx) are upstream now and included in main line kernel release 5.11 or later.
The [Flexible Launch Control driver](https://github.com/intel/SGXDataCenterAttestationPrimitives/tree/master/driver) is developed to imitate the kernel patches as closely as possible. It can be used for distros with kernels older than 5.11.

The sample scripts and Compose files are compatible with the Flexible Launch Control driver or a custom built kernel with SGX support. To use the Legacy Launch Control driver, make following modifications:
1. Replace "/dev/sgx_enclave" device with "/dev/isgx" and **remove** "/dev/sgx_provision" device for AESM in docker-compose.yml and build_and_run_aesm_deb_docker.sh
2. Replace "/dev/sgx_enclave" with "/dev/isgx" for the sample container in docker-compose.yml and build_and_run_sample_deb_docker.sh

**Note**: When you switch between drivers, make sure you uninstall the previous driver and reboot the system before installing the other one.

**Note**: Earlier versions of the Flexible Launch Control driver and kernel patches may expose the SGX device as a single node at "/dev/sgx".

## Experimental: Build and run TDX QGS in docker container
###  Prerequisites
Besides the [Prerequisites](#prerequisites), you need to have docker version >= 20.04 to support host-gateway used in build_and_run_qgs_docker.sh. And Legacy Launch Control driver is not supported.

### Run with Docker directly
This will start QGS on one terminal directly.
```
$ ./build_and_run_qgs_docker.sh
```
It will listen on docker volume /var/lib/docker/volumes/qgs-socket. In order to connect to QGS in this configuration, you need to run QEMU with `quote-generation-service=unix:/var/lib/docker/volumes/qgs-socket/_data/qgs.socket` option and use TDVMCall mode(which is the default mode if you installed with rpm/deb package) to get quote within TD guest.
