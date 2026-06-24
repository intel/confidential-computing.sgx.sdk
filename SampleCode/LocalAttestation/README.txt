---------------------------
The project aims to demo SGX local attestation flow. 

------------------------------------
How to Build the Sample Code
------------------------------------
1. Install Intel(R) Software Guard Extensions (Intel(R) SGX) SDK for Linux* OS
2. Enclave test key(two options):
    a. Install openssl first, then the project will generate a test key<EnclaveInitiator_private_test.pem>/<EnclaveResponder_private_test.pem> automatically when you build the project.
    b. Rename your test key(3072-bit RSA private key) to <EnclaveInitiator_private_test.pem>/<EnclaveResponder_private_test.pem> and put it under the <EnclaveInitiator>/<EnclaveResponder> folder.
3. Build the project with the prepared Makefile:
        a. Hardware Mode, Debug build:
		$ make
        b. Hardware Mode, Pre-release build:
		$ make SGX_PRERELEASE=1 SGX_DEBUG=0
        c. Hardware Mode, release build:
		$ make SGX_DEBUG=0
        d. Simulation Mode, Debug build:
		$ make SGX_MODE=SIM
        e. Simulation Mode, Pre-release build:
		$ make SGX_MODE=SIM SGX_PRERELEASE=1 SGX_DEBUG=0
        f. Simulation Mode, Release build:
		$ make SGX_MODE=SIM SGX_DEBUG=0
        g. Use Local Attestation 2.0 protocol, Hardware Mode, Debug build:
        $ make LAv2=1
           Note: Local Attestation 2.0 protocol will be used if 'LAv2' is defined.


When build is successful, you can find executable binaries in "bin" sub-folder.
 
------------------------------------
How to Execute the Sample Code
------------------------------------
1. Install SGX driver and PSW for Linux* OS
2. If you want to try local attestation flow from two process, you can goto "bin" sub-folder
   a. run "./appresponder".
      It would launch a process to act as local attestation responder.
   b. run "./appinitiator"
      It would launch a process to act as local attestation initator.
3. If you want to try local attestation flow from one process, you can goto "bin" sub-folder and run "./app"

------------------------------------
AES-GCM IV Management Best Practice
------------------------------------
This sample demonstrates a best practice for preventing AES-GCM IV (nonce) reuse
when the same session key (AEK) is used for both request and response messages.

AES-GCM is broken if the same (key, IV) pair is ever used twice. In a bidirectional
protocol where one key encrypts both directions, a naive counter starting at 0 on
both sides would produce colliding IVs (e.g., both sides use IV=1 for their first
message).

This sample avoids the collision by reserving bit 31 of the 32-bit IV counter as a
direction bit:
  - Request IVs:  bit 31 = 0  (counter range 0x00000000 to 0x7FFFFFFD)
  - Response IVs: bit 31 = 1  (counter | 0x80000000)

The responder sets the response IV as (counter + 1) | 0x80000000, and the initiator
verifies this exact value before accepting a response. This guarantees request and
response IVs are drawn from disjoint spaces, so the (AEK, IV) pair is never reused
regardless of how many messages are exchanged.

When the counter reaches 0x7FFFFFFE (2^31 - 2), the initiator closes the session and
establishes a new one before sending further messages, preventing counter exhaustion.

------------------------------------
How to Get Signed Enclave's MRSIGNER
------------------------------------
1. Install Intel(R) Software Guard Extensions (Intel(R) SGX) SDK for Linux* OS
2. Execute blow command to get your signed enclave's MRSIGNER: 
    <SGX_SDK Installation Path>/bin/x64/sgx_sign dump -enclave <Signed Enclave> -dumpfile mrsigner.txt
3. Find the signed enclave's MRSIGNER in the mrsigner.txt(mrsigner->value:)
