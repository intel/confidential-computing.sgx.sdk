# Building the Intel(R) Cryptography Primitives Library (CPL)

The ippcp library is built based on the Intel(R) Cryptography Primitives Library (CPL) open source project:
   * https://github.com/intel/cryptography-primitives
   * tag: [cryptography-primitives_2_1_0](https://github.com/intel/cryptography-primitives/tree/cryptography-primitives_2_1_0)

# Build Instructions

To build your own cryptographic library, complete the following steps:
1. Download the prebuilt mitigation tools package.
   Obtain `as.ld.objdump.{ver}.tar.gz` from [01.org](https://download.01.org/intel-sgx/latest/linux-latest/).
   Extract the package and copy the tools into `/usr/local/bin`.
2. Prepare the build environment.
   Read the Cryptography Primitives Library [BUILD.md](https://github.com/intel/cryptography-primitives/blob/cryptography-primitives_1_4_0/BUILD.md) for environment requirements and setup instructions.
3. Prepare the ipp-crypto source code.
   Run the following command in the root directory:
   ```bash
   make preparation
   ```
4. Build the ippcp library using the provided Makefile.
    1. Build with All-Loads-Mitigation
    ```bash
       $ make MITIGATION-CVE-2020-0551=LOAD
    ```
    2. Build with Branch-Mitigation
    ```bash
       $ make MITIGATION-CVE-2020-0551=CF
     ```
    3. Build with No Mitigation
    ```bash
       $ make
    ```
After a successful build, the static library `libippcp.a` and header files are copied to the appropriate directory.
Note: Run ```make clean``` before switching mitigation modes.

# Reproducible Build

For a reproducible CPL build, follow the instructions in [reproducibility README.md](../../linux/reproducibility/README.md) to generate the CPL prebuilt.

# Generating SGX Dispatcher Code

After building the library, generate the SGX dispatcher code:
```bash
$ make disp
```
The ```disp``` target in the Makefile executes the following steps:
1. Enter the IPP Custom Library Tool directory
```bash
$ cd ./ipp-crypto/tools/ipp_custom_library_tool_python
```
2. Generate a function list from the header file ippcp.h:
```bash
$ awk -F\, '/IPPAPI\(/ {print $2}' ../../../inc/ippcp.h | awk '{print $1}' > functions.txt
```
3. Generate the dispatcher code using the Custom Library Tool
```bash
$ python3 main.py -c -g -p ./ -ff functions.txt -arch intel64 -d sse42 avx2 avx512ifma -root ../../install --prefix sgx_disp_
```
4. Verify that the dispatcher code was generated successfully
```bash
$ ./build_custom_library_intel64.sh
```
5. Copy the generated dispatcher source files to the SDK directory
```bash
$ cp custom_dispatcher/intel64/*.c ../../../../../sdk/tlibcrypto/ipp/ipp_disp/intel64/
```
