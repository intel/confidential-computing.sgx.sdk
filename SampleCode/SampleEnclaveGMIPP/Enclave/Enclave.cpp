/*
 * Copyright (C) 2011-2021 Intel Corporation. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in
 *     the documentation and/or other materials provided with the
 *     distribution.
 *   * Neither the name of Intel Corporation nor the names of its
 *     contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include "Enclave.h"
#include "Enclave_t.h" /* print_string */
#include <stdarg.h>
#include <stdio.h> /* vsnprintf */
#include <string.h>
#include "sgx_trts.h"
#include "mbusafecrt.h"

#include <ippcp.h> /* ipp library */

const unsigned int order[] = {0x39D54123, 0x53BBF409, 0x21C6052B, 0x7203DF6B, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFE};
const int ordSize = sizeof(order) / sizeof(unsigned int);

/* Bit length of the SM2 prime finite field GF(p). The SM2 curve (GB/T 32918)
 * is defined over a 256-bit prime, so this is the field-element / prime bit
 * size passed to ippsGFpGetSize (feBitSize) and ippsGFpInitFixed (primeBitSize). */
const int SM2_PRIME_BIT_SIZE = 256;

//replace free()
#ifndef SAFE_FREE
#define SAFE_FREE(ptr) do {if (NULL != (ptr)) {free(ptr); (ptr) = NULL;}} while(0);
#endif

//add a memset_s() for private key before free()
#ifndef SAEF_FREE_ECC_PRI_KEY
#define SAEF_FREE_ECC_PRI_KEY(ptr) do {int size; IppStatus status = ippStsNoErr; if ((NULL != (ptr))) {status = ippsBigNumGetSize(ordSize, &size); if (ippStsNoErr != status) {memset_s(ptr, size, 0, size);} free(ptr); (ptr) = NULL;}} while(0);
#endif

#ifndef SAFE_FREE_HEAP
#define SAFE_FREE_HEAP(ptr, size) do {if (NULL != (ptr)) {memset_s(ptr, size, 0, size); free(ptr); (ptr) = NULL;}} while(0);
#endif

#ifndef SAFE_FREE_STACK
#define SAFE_FREE_STACK(ptr, size) do {if (NULL != (ptr)) {memset_s(ptr, size, 0, size);}} while(0);
#endif

/* 
 * printf: 
 *   Invokes OCALL to display the enclave buffer to the terminal.
 */
int printf(const char* fmt, ...)
{
	char buf[BUFSIZ] = { '\0' };
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(buf, BUFSIZ, fmt, ap);
	va_end(ap);
	ocall_print_string(buf);
	return (int)strnlen(buf, BUFSIZ - 1) + 1;
}

/* SM2 EC handle encapsulating both GFp and GFpEC contexts */
typedef struct {
	IppsGFpState* pGFp;
	IppsGFpECState* pEC;
	int gfpSize;
	int ecSize;
} Sm2EcHandle;

/* Define EC over GF(p) context for SM2 */
static Sm2EcHandle* new_ECC_sm2(void)
{
	int gfpSize = 0;
	int ecSize = 0;
	IppsGFpState* pGFp = NULL;
	IppsGFpECState* pEC = NULL;
	Sm2EcHandle* handle = NULL;
	IppStatus status = ippStsNoErr;

	// Allocate the handle
	handle = (Sm2EcHandle*)malloc(sizeof(Sm2EcHandle));
	if (handle == NULL) {
		printf("Error: fail to allocate memory for Sm2EcHandle\n");
		return NULL;
	}

	// Get the size of GFp context for SM2 (256-bit prime field)
	status = ippsGFpGetSize(SM2_PRIME_BIT_SIZE, &gfpSize);
	if (status != ippStsNoErr) {
		printf("Error: fail to get size of GFp\n");
		free(handle);
		return NULL;
	}

	// Allocate the GFp context
	pGFp = (IppsGFpState*)(malloc(gfpSize));
	if (pGFp == NULL) {
		printf("Error: fail to allocate memory for GFp\n");
		free(handle);
		return NULL;
	}

	// Initialize the GFp context for SM2
	status = ippsGFpInitFixed(SM2_PRIME_BIT_SIZE, ippsGFpMethod_p256sm2(), pGFp);
	if (status != ippStsNoErr) {
		printf("Error: fail to initialize GFp\n");
		SAFE_FREE_HEAP(pGFp, gfpSize);
		free(handle);
		return NULL;
	}

	// Get the size of GFpEC context for SM2
	status = ippsGFpECGetSize(pGFp, &ecSize);
	if (status != ippStsNoErr) {
		printf("Error: fail to get size of GFpEC\n");
		SAFE_FREE_HEAP(pGFp, gfpSize);
		free(handle);
		return NULL;
	}

	// Allocate the GFpEC context for SM2
	pEC = (IppsGFpECState*)(malloc(ecSize));
	if (pEC == NULL) {
		printf("Error: fail to allocate memory for GFpEC\n");
		SAFE_FREE_HEAP(pGFp, gfpSize);
		free(handle);
		return NULL;
	}

	// Initialize the GFpEC context for SM2
	status = ippsGFpECInitStdSM2(pGFp, pEC);
	if (status != ippStsNoErr) {
		printf("Error: fail to initialize GFpEC\n");
		SAFE_FREE_HEAP(pEC, ecSize);
		SAFE_FREE_HEAP(pGFp, gfpSize);
		free(handle);
		return NULL;
	}

	// Store the contexts and sizes in the handle
	handle->pGFp = pGFp;
	handle->pEC = pEC;
	handle->gfpSize = gfpSize;
	handle->ecSize = ecSize;

	// Note: pGFp is stored as a pointer reference inside pEC (see ECP_GFP macro).
	// Both pEC and pGFp must be freed when done.

	return handle;
}

/* Free EC over GF(p) context for SM2 */
static void free_ECC_sm2(Sm2EcHandle* handle)
{
	if (handle != NULL) {
		SAFE_FREE_HEAP(handle->pEC, handle->ecSize);
		SAFE_FREE_HEAP(handle->pGFp, handle->gfpSize);
		free(handle);
	}
}

/* Define EC over GF(p) Point context */
static IppsGFpECPoint* new_ECC_Point(IppsGFpECState* pEC)
{
	int ctxSize = 0;
	IppsGFpECPoint* pPoint = NULL;
	IppStatus status = ippStsNoErr;

	status = ippsGFpECPointGetSize(pEC, &ctxSize);
	if (status != ippStsNoErr) {
		printf("Error: fail to get size of GFpECPoint\n");
		return NULL;
	}

	pPoint = (IppsGFpECPoint*)(malloc(ctxSize));
	if (pPoint == NULL) {
		printf("Error: fail to allocate memory for GFpECPoint\n");
		return NULL;
	}

	status = ippsGFpECPointInit(NULL, NULL, pPoint, pEC);
	if (status != ippStsNoErr) {
		printf("Error: fail to initialize GFpECPoint\n");
		SAFE_FREE_HEAP(pPoint, ctxSize);
		return NULL;
	}

	return pPoint;
}

/* Define Big Number context */
static IppsBigNumState* new_BN(int len, const unsigned int* pData)
{
	int ctxSize = 0;
	IppsBigNumState* pBN = NULL;
	IppStatus status = ippStsNoErr;

	status = ippsBigNumGetSize(len, &ctxSize);
	if (status != ippStsNoErr) {
		printf("Error: fail to get size of BigNum\n");
		return NULL;
	}

	pBN = (IppsBigNumState*)(malloc(ctxSize));
	if (pBN == NULL) {
		printf("Error: fail to allocate memory for BigNum\n");
		return NULL;
	}

	status = ippsBigNumInit(len, pBN);
	if (status != ippStsNoErr) {
		printf("Error: fail to initialize BigNum\n");
		SAFE_FREE_HEAP(pBN, ctxSize);
		return NULL;
	}

	if (pData)
		ippsSet_BN(IppsBigNumPOS, len, pData, pBN);

	return pBN;
}

/* Generate a secure random number */
static int secure_rand(unsigned int* pX, int size)
{
	if (sgx_read_rand((unsigned char*)pX, size) != SGX_SUCCESS) {
		printf("Error: fail to generate a secure random number\n");
		return -1;
	}

	return 0;
}

/* Define a new random BN generator instead of IPP Crypto - ippsPRNGen */
static IppStatus gen_random_BN(Ipp32u* pRand, int nBits, void* pCtx)
{
	(void)pCtx; // unused: required by the IppBitSupplier callback signature

	if (!pRand) {
		printf("Error: pRand is NULL\n");
		return ippStsNullPtrErr;
	}

	if (0 != nBits % 8) {
		printf("Error: nBits size is wrong\n");
		return ippStsSizeErr;
	}

    sgx_status_t sgx_ret = sgx_read_rand((uint8_t*)pRand, (uint32_t)nBits / 8);
	if (SGX_SUCCESS != sgx_ret) {
		printf("Error: fail to generate a pseudorandom unsigned big number of the specified bit length\n");
		return ippStsErr;
	}

	return ippStsNoErr;
}

/* SM2 generate private key and public key */
static int sm2_key_generation(IppsBigNumState** privateKey, IppsGFpECPoint** publicKey)
{
	Sm2EcHandle *ecHandle = NULL;
	IppsGFpECState *pEC = NULL;
	int nScalars = 1;
	int pBufferSize = 0;
	Ipp8u *pScratchBuffer = NULL;
	IppStatus ipp_ret = ippStsNoErr;
	int ret = 0;

	do {
		// 1. Create ECC context for SM2
		ecHandle = new_ECC_sm2();
		if (ecHandle == NULL) {
			printf("Error: fail to create ecc context for sm2\n");
			ret = -1;
			break;
		}
		pEC = ecHandle->pEC;

		// 2. Generate private key and public key
		*privateKey = new_BN(ordSize, 0);
		if (*privateKey == NULL) {
			printf("Error: fail to declare private key\n");
			ret = -2;
			break;
		}
		*publicKey = new_ECC_Point(pEC);
		if (*publicKey == NULL) {
			printf("Error: fail to declare public key\n");
			ret = -3;
			break;
		}

		// Generate private key
		ipp_ret = ippsGFpECPrivateKey(*privateKey, pEC, gen_random_BN, NULL);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to generate private key\n");
			ret = -4;
			break;
		}

		// Get scratch buffer size
		ipp_ret = ippsGFpECScratchBufferSize(nScalars, pEC, &pBufferSize);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to get the size of the scratch buffer\n");
			ret = -5;
			break;
		}
		pScratchBuffer = (Ipp8u*)malloc(pBufferSize);
		if (pScratchBuffer == NULL) {
			printf("Error: fail to allocate memory for scratch buffer\n");
			ret = -6;
			break;
		}

		// Generate public key from private key
		ipp_ret = ippsGFpECPublicKey(*privateKey, *publicKey, pEC, pScratchBuffer);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to generate public key\n");
			ret = -7;
			break;
		}
	} while(0);

	// 3. Final, release resource
	SAFE_FREE_HEAP(pScratchBuffer, pBufferSize);
	free_ECC_sm2(ecHandle);

	return ret;
}

/* SM2 sign */
static int sm2_sign(const IppsBigNumState* pMsgDigest, const IppsBigNumState* regPrivateKey, IppsBigNumState* signX, IppsBigNumState* signY)
{
	Sm2EcHandle *ecHandle = NULL;
	IppsGFpECState *pEC = NULL;
	IppsBigNumState *ephPrivateKey = NULL;
	IppsGFpECPoint *ephPublicKey = NULL;
	int nScalars = 1;
	int pBufferSize = 0;
	Ipp8u *pScratchBuffer = NULL;
	IppStatus ipp_ret = ippStsNoErr;
	int ret = 0;

	do {
		// 1. Create ECC context for SM2
		ecHandle = new_ECC_sm2();
		if (ecHandle == NULL) {
			printf("Error: fail to create ecc context for sm2\n");
			ret = -1;
			break;
		}
		pEC = ecHandle->pEC;

		// 2. Generate ephemeral private key and public key
		ret = sm2_key_generation(&ephPrivateKey, &ephPublicKey);
		if (ret != 0) {
			printf("Error: fail to generate ephemeral private key and public key\n");
			ret = -2;
			break;
		}

		// 3. Get scratch buffer size
		ipp_ret = ippsGFpECScratchBufferSize(nScalars, pEC, &pBufferSize);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to get the size of the scratch buffer\n");
			ret = -3;
			break;
		}
		pScratchBuffer = (Ipp8u*)malloc(pBufferSize);
		if (pScratchBuffer == NULL) {
			printf("Error: fail to allocate memory for scratch buffer\n");
			ret = -4;
			break;
		}

		// 4. Sign using ECC context for SM2
		ipp_ret = ippsGFpECSignSM2(pMsgDigest, regPrivateKey, ephPrivateKey, signX, signY, pEC, pScratchBuffer);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to sign the message\n");
			ret = -5;
			break;
		}
	} while(0);

	// 5. Final, remove secret and release resource
	// !!!Please clear secret including key/context related buffer/big number here!!!
	SAFE_FREE_HEAP(pScratchBuffer, pBufferSize);
	SAFE_FREE(ephPublicKey);
	SAEF_FREE_ECC_PRI_KEY(ephPrivateKey);
	free_ECC_sm2(ecHandle);

	return ret;
}

/* SM2 verify */
static int sm2_verify(const IppsBigNumState* pMsgDigest, const IppsGFpECPoint* regPublicKey, const IppsBigNumState* signX, const IppsBigNumState* signY)
{
	Sm2EcHandle *ecHandle = NULL;
	IppsGFpECState *pEC = NULL;
	int nScalars = 2; // ippsGFpECVerifySM2 computes [s]G + [t]regPublic (2 mul_point operations)
	int pBufferSize = 0;
	Ipp8u *pScratchBuffer = NULL;
	IppStatus ipp_ret = ippStsNoErr;
	IppECResult eccResult = ippECValid;
	int ret = 0;

	do {
		// 1. Create ECC context for SM2
		ecHandle = new_ECC_sm2();
		if (ecHandle == NULL) {
			printf("Error: fail to create ecc context for sm2\n");
			ret = -1;
			break;
		}
		pEC = ecHandle->pEC;

		// 2. Get scratch buffer size
		ipp_ret = ippsGFpECScratchBufferSize(nScalars, pEC, &pBufferSize);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to get the size of the scratch buffer\n");
			ret = -2;
			break;
		}
		pScratchBuffer = (Ipp8u*)malloc(pBufferSize);
		if (pScratchBuffer == NULL) {
			printf("Error: fail to allocate memory for scratch buffer\n");
			ret = -3;
			break;
		}

		// 3. Verify using ECC context for SM2
		ipp_ret = ippsGFpECVerifySM2(pMsgDigest, regPublicKey, signX, signY, &eccResult, pEC, pScratchBuffer);
		if ((ipp_ret != ippStsNoErr) || (eccResult != ippECValid)) {
			printf("Error: fail to verify the signature\n");
			ret = -4;
			break;
		}
	} while(0);

	// 4. Final, release resource
	SAFE_FREE_HEAP(pScratchBuffer, pBufferSize);
	free_ECC_sm2(ecHandle);

	return ret;
}

/* SM2 sign and verify */
int ecall_sm2_sign_verify(void)
{
	IppsBigNumState *regPrivateKey = NULL;
	IppsGFpECPoint *regPublicKey = NULL;
	int nScalars = 1;
	int pBufferSize = 0;
	Ipp8u *pScratchBuffer = NULL;
	IppsBigNumState *pMsgDigest = NULL;
	IppsBigNumState *signX = NULL, *signY = NULL;
	IppStatus ipp_ret = ippStsNoErr;
	int ret = 0;

	const char *message = "context need to be signed";
	const char *user_id = "1234567812345678";

	do {
		// 1. Generate regular private key and public key
		ret = sm2_key_generation(&regPrivateKey, &regPublicKey);
		if (ret != 0) {
			printf("Error: fail to generate regular private key and public key\n");
			ret = -2;
			break;
		}

		// 2. Create signX and signY
		signX = new_BN(ordSize, 0);
		if (signX == NULL) {
			printf("Error: fail to create signX\n");
			ret = -3;
			break;
		}
		signY = new_BN(ordSize, 0);
		if (signY == NULL) {
			printf("Error: fail to create signY\n");
			ret = -4;
			break;
		}

		// 3. Create temporary EC context for message digest calculation
		Sm2EcHandle *digestHandle = new_ECC_sm2();
		if (digestHandle == NULL) {
			printf("Error: fail to create ecc context for digest\n");
			ret = -5;
			break;
		}

		// 4. Digest message
		// Calculate Z = H256(ENTLA || IDA || a || b || xG || yG || xA || yA)
		// Calculate ZA = H256(Z||M)
		ipp_ret = ippsGFpECScratchBufferSize(nScalars, digestHandle->pEC, &pBufferSize);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to get the size of the scratch buffer\n");
			free_ECC_sm2(digestHandle);
			ret = -6;
			break;
		}
		pScratchBuffer = (Ipp8u*)malloc(pBufferSize);
		if (pScratchBuffer == NULL) {
			printf("Error: fail to allocate memory for pScratchBuffer\n");
			free_ECC_sm2(digestHandle);
			ret = -7;
			break;			
		}
		pMsgDigest = new_BN(ordSize, 0);
		if (pMsgDigest == NULL) {
			printf("Error: fail to create pointer to the resulting message digest\n");
			free_ECC_sm2(digestHandle);
			ret = -8;
			break;
		}
		ipp_ret = ippsGFpECMessageRepresentationSM2(pMsgDigest, (const Ipp8u*)message, (int)strlen(message), (const Ipp8u*)user_id, (int)strlen(user_id), regPublicKey, digestHandle->pEC, pScratchBuffer);
		free_ECC_sm2(digestHandle);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to digest message\n");
			ret = -9;
			break;
		}

		// 5. Sign using ECC context for SM2
		ret = sm2_sign(pMsgDigest, regPrivateKey, signX, signY);
		if (ret != 0) {
			printf("Error: fail to sign\n");
			ret = -10;
			break;
		}

		// 6. Verify using ECC context for SM2
		ret = sm2_verify(pMsgDigest, regPublicKey, signX, signY);
		if (ret != 0) {
			printf("Error: fail to verify\n");
			ret = -11;
			break;
		}
	} while(0);

	// 7. Final, remove secret and release resource
	// !!!Please clear secret including key/context related buffer/big number here!!!
	SAFE_FREE(signY);
	SAFE_FREE(signX);
	SAFE_FREE(pMsgDigest);
	SAFE_FREE_HEAP(pScratchBuffer, pBufferSize);
	SAFE_FREE(regPublicKey);
	SAEF_FREE_ECC_PRI_KEY(regPrivateKey);

	return ret;
}

/* SM2 compute hash */
static int sm2_compute_hash(Ipp8u* hash_data, const char* message)
{
	int ctxSize = 0;
	IppsHashState_rmf* pSM3 = NULL;
	IppStatus status = ippStsNoErr;
	int ret = 0;

	do {
		//1. Initialize
		status = ippsHashGetSize_rmf(&ctxSize);
		if (status != ippStsNoErr) {
			printf("Error: fail to get size of SM3 context\n");
			ret = -1;
			break;
		}
		pSM3 = (IppsHashState_rmf *)(malloc(ctxSize));
		if (pSM3 == NULL) {
			printf("Error: fail to allocate memory for SM3 context\n");
			ret = -2;
			break;
		}
		status = ippsHashInit_rmf(pSM3, ippsHashMethod_SM3());
		if (status != ippStsNoErr) {
			printf("Error: fail to initialize SM3 context\n");
			ret = -3;
			break;
		}

		// 2. Compute
		status = ippsHashUpdate_rmf((const Ipp8u *)message, (int)strlen(message), pSM3);
		if (status != ippStsNoErr) {
			printf("Error: fail to digest the message of specified length\n");
			ret = -4;
			break;
		}
		status = ippsHashFinal_rmf(hash_data, pSM3);
		if (status != ippStsNoErr) {
			printf("Error: fail to complete computation of the SM3 digest value\n");
			ret = -5;
			break;
		}
	} while(0);

	// 3. Final, release resource
	SAFE_FREE_HEAP(pSM3, ctxSize);

	return ret;
}

/* SM2 Key Exchange */
int ecall_sm2_key_exchange(void)
{
	IppsBigNumState *requesterRegPrivateKey = NULL, *responderRegPrivateKey = NULL, *requesterEphPrivateKey = NULL, *responderEphPrivateKey = NULL;
	IppsGFpECPoint *requesterRegPublicKey = NULL, *responderRegPublicKey = NULL, *requesterEphPublicKey = NULL, *responderEphPublicKey = NULL;
	int pSize = 0;
	IppsGFpECKeyExchangeSM2State *pKERequester = NULL, *pKEResponder = NULL;
	Sm2EcHandle *hashHandle = NULL;
	int nScalars = 2; // ippsGFpECUserIDHashSM2 / ippsGFpECKeyExchangeSM2_SharedKey require nScalars >= 2
	int pBufferSize = 0;
	Ipp8u *pScratchBuffer = NULL;
	Ipp8u sharedKeyRequester[32] = {0};
	Ipp8u sharedKeyResponder[32] = {0};
	int sharedKeyRequesterSize = 32;
	int sharedKeyResponderSize = 32;
	const char *user_id_requester = "1234567812345678";
	const char *user_id_responder = "AABBCCDDEEFFGGHH";
	int user_id_len_requester = (int)strlen(user_id_requester);
	int user_id_len_responder = (int)strlen(user_id_responder);
	Ipp8u user_id_hash_requester[32] = {0};
	Ipp8u user_id_hash_responder[32] = {0};
	Ipp8u pSSelfRequester[32] = {0};
	Ipp8u pSPeerResponder[32] = {0};
	const char* pSSelfRequesterMsg = "this is requester";
	const char* pSPeerResponderMsg = "this is responder";
	int pStatusRequester = 0, pStatusResponder = 0;
	IppStatus ipp_ret = ippStsNoErr;
	int ret = 0;

	do {
		// Requester:
		// 2. Generate requester's regular private and public key
		ret = sm2_key_generation(&requesterRegPrivateKey, &requesterRegPublicKey);
		if (ret != 0) {
			printf("Error: fail to generate requester's regular private key and public key\n");
			ret = -2;
			break;
		}

		// 3. Generate requester's ephemeral private and public key
		ret = sm2_key_generation(&requesterEphPrivateKey, &requesterEphPublicKey);
		if (ret != 0) {
			printf("Error: fail to generate requester's ephemeral private key and public key\n");
			ret = -3;
			break;
		}

		// Responder:
		// 4. Generate responder's regular private and public key
		ret = sm2_key_generation(&responderRegPrivateKey, &responderRegPublicKey);
		if (ret != 0) {
			printf("Error: fail to generate responder's regular private key and public key\n");
			ret = -4;
			break;
		}

		// 5. Generate responder's ephemeral private and public key
		ret = sm2_key_generation(&responderEphPrivateKey, &responderEphPublicKey);
		if (ret != 0) {
			printf("Error: fail to generate responder's ephemeral private key and public key\n");
			ret = -5;
			break;
		}

		// 6. Create temporary EC context for user ID hash computation
		hashHandle = new_ECC_sm2();
		if (hashHandle == NULL) {
			printf("Error: fail to create ecc context for hash\n");
			ret = -6;
			break;
		}

		// 7. Get the size of the SM2 Key Exchange ECC context
		ipp_ret = ippsGFpECKeyExchangeSM2_GetSize(hashHandle->pEC, &pSize);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to get the size of the SM2 Key Exchange ECC context\n");
			ret = -7;
			break;
		}

		// 8. Initialize the SM2 Key Exchange ECC context
		pKERequester = (IppsGFpECKeyExchangeSM2State*)malloc(pSize);
		if (pKERequester == NULL) {
			printf("Error: fail to allocate memory for pKERequester\n");
			ret = -8;
			break;
		}
		ipp_ret = ippsGFpECKeyExchangeSM2_Init(pKERequester, ippKESM2Requester, hashHandle->pEC);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to initialize requester SM2 Key Exchange ECC context\n");
			ret = -9;
			break;
		}
		pKEResponder = (IppsGFpECKeyExchangeSM2State*)malloc(pSize);
		if (pKEResponder == NULL) {
			printf("Error: fail to allocate memory for pKEResponder\n");
			ret = -10;
			break;
		}
		ipp_ret = ippsGFpECKeyExchangeSM2_Init(pKEResponder, ippKESM2Responder, hashHandle->pEC);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to initialize responder SM2 Key Exchange ECC context\n");
			ret = -11;
			break;
		}

		// 9. Compute user_id_hash_requester and user_id_hash_responder
		// Za = SM3( ENTL || ID || a || b || xG || yG || xA || yA )
		ipp_ret = ippsGFpECScratchBufferSize(nScalars, hashHandle->pEC, &pBufferSize);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to get the size of the scratch buffer\n");
			ret = -12;
			break;
		}
		pScratchBuffer = (Ipp8u*)malloc(pBufferSize);
		if (pScratchBuffer == NULL) {
			printf("Error: fail to allocate memory for pScratchBuffer\n");
			ret = -13;
			break;
		}
		ipp_ret = ippsGFpECUserIDHashSM2(user_id_hash_requester, (const Ipp8u *)user_id_requester, user_id_len_requester, requesterRegPublicKey, hashHandle->pEC, pScratchBuffer);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to compute user_id_hash_requester\n");
			ret = -14;
			break;
		}
		ipp_ret = ippsGFpECUserIDHashSM2(user_id_hash_responder, (const Ipp8u *)user_id_responder, user_id_len_responder, responderRegPublicKey, hashHandle->pEC, pScratchBuffer);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to compute user_id_hash_responder\n");
			ret = -15;
			break;
		}

		// 10. Set up the SM2 Key Exchange ECC context for further operation of the SM2 Key Exchange algorithm
		ipp_ret = ippsGFpECKeyExchangeSM2_Setup(user_id_hash_requester, user_id_hash_responder, requesterRegPublicKey, responderRegPublicKey, requesterEphPublicKey, responderEphPublicKey, pKERequester);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to set up requester SM2 Key Exchange ECC context\n");
			ret = -15;
			break;
		}
		ipp_ret = ippsGFpECKeyExchangeSM2_Setup(user_id_hash_responder, user_id_hash_requester, responderRegPublicKey, requesterRegPublicKey, responderEphPublicKey, requesterEphPublicKey, pKEResponder);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to set up responder SM2 Key Exchange ECC context\n");
			ret = -16;
			break;
		}

		// 10. Compute requester shared key
		ret = sm2_compute_hash(pSSelfRequester, pSSelfRequesterMsg);
		if (ret != 0) {
			printf("Error: fail to compute requester self conformation hash data\n");
			ret = -17;
			break;
		}
		ret = ippsGFpECKeyExchangeSM2_SharedKey(sharedKeyRequester, sharedKeyRequesterSize, pSSelfRequester, requesterRegPrivateKey, requesterEphPrivateKey, pKERequester, pScratchBuffer);
		if (ret != 0) {
			printf("Error: fail to compute requester shared key\n");
			ret = -18;
			break;
		}

		// 11. Compute responder shared key
		ret = sm2_compute_hash(pSPeerResponder, pSPeerResponderMsg);
		if (ret != 0) {
			printf("Error: fail to compute responder peer conformation hash data\n");
			ret = -19;
			break;
		}
		ret = ippsGFpECKeyExchangeSM2_SharedKey(sharedKeyResponder, sharedKeyResponderSize, pSPeerResponder, responderRegPrivateKey, responderEphPrivateKey, pKEResponder, pScratchBuffer);
		if (ret != 0) {
			printf("Error: fail to compute responder shared key\n");
			ret = -20;
			break;
		}

		// 12. Confirm if requester shared key and responder shared key are correct, then compare if they are equal
		ipp_ret = ippsGFpECKeyExchangeSM2_Confirm(pSPeerResponder, &pStatusRequester, pKERequester);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to confirm requester shared key\n");
			ret = -21;
			break;
		}
		ipp_ret = ippsGFpECKeyExchangeSM2_Confirm(pSSelfRequester, &pStatusResponder, pKEResponder);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to confirm responder shared key\n");
			ret = -22;
			break;
		}
		// pStatusRequester/pStatusResponder's value:
		// 1, successful
		// 0, bad confirmation
		if (pStatusRequester != 1 || pStatusResponder != 1 || memcmp(sharedKeyRequester, sharedKeyResponder, 32))
		{
			printf("Error: requester shared key and responder shared key are not equal\n");
			ret = -23;
			break;
		}
	} while(0);

	SAFE_FREE_HEAP(pScratchBuffer, pBufferSize);
	SAFE_FREE_HEAP(pKEResponder, pSize);
	SAFE_FREE_HEAP(pKERequester, pSize);
	free_ECC_sm2(hashHandle);
	SAFE_FREE(responderEphPublicKey);
	SAEF_FREE_ECC_PRI_KEY(responderEphPrivateKey);
	SAFE_FREE(requesterEphPublicKey);
	SAEF_FREE_ECC_PRI_KEY(requesterEphPrivateKey);
	SAFE_FREE(responderRegPublicKey);
	SAEF_FREE_ECC_PRI_KEY(responderRegPrivateKey);
	SAFE_FREE(requesterRegPublicKey);
	SAEF_FREE_ECC_PRI_KEY(requesterRegPrivateKey);

	return ret;
}

/* SM2 encrypt(GM version) */
static int sm2_encrypt_gm(const char* message, int message_len, Ipp8u** cipher_text, int* cipher_len, IppsGFpECPoint *regPublicKey, IppsGFpECPoint *ephPublicKey, IppsBigNumState *ephPrivateKey)
{
	Sm2EcHandle *ecHandle = NULL;
	IppsGFpECState *pEC = NULL;
	int maxOutlen = 0;
	int pOutSize = 0;
	int nScalars = 2; // ippsGFpECEncryptSM2_Ext requires nScalars >= 2
	int pBufferSize = 0;
	Ipp8u* pScratchBuffer = NULL;
	IppStatus ipp_ret = ippStsNoErr;
	int ret = 0;

	do {
		// 1. Create ECC context for SM2
		ecHandle = new_ECC_sm2();
		if (ecHandle == NULL) {
			printf("Error: fail to create ecc context for encrypt\n");
			ret = -1;
			break;
		}
		pEC = ecHandle->pEC;

		// 2. Allocate cipher text buffer
		maxOutlen = 64 + message_len + 32 + 1; // encrypt/decrypt buffer = pubkey (64B) + message (inpLen) + hash (32B)
		*cipher_text = (Ipp8u*)malloc(maxOutlen);
		if (*cipher_text == NULL) {
			printf("Error: fail to allocate memory for cipher text\n");
			ret = -2;
			break;
		}
		memset(*cipher_text, 0, maxOutlen);
		
		// 3. Get scratch buffer size
		ipp_ret = ippsGFpECScratchBufferSize(nScalars, pEC, &pBufferSize);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to get the size of the scratch buffer\n");
			ret = -3;
			break;
		}
		pScratchBuffer = (Ipp8u*)malloc(pBufferSize);
		if (pScratchBuffer == NULL) {
			printf("Error: fail to allocate memory for the scratch buffer\n");
			ret = -4;
			break;
		}
		ipp_ret = ippsGFpECEncryptSM2_Ext(*cipher_text, maxOutlen, &pOutSize, (const Ipp8u*)message, message_len, regPublicKey, ephPublicKey, ephPrivateKey, pEC, pScratchBuffer);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to encrypt.\n");
			ret = -5;
			break;
		}
		*cipher_len = pOutSize;
	} while(0);

	SAFE_FREE_HEAP(pScratchBuffer, pBufferSize);
	free_ECC_sm2(ecHandle);

	return ret;
}

/* SM2 decrypt(GM version) */
static int sm2_decrypt_gm(const Ipp8u* cipher_text, int cipher_len, Ipp8u** plain_text, int* plain_len, IppsBigNumState *regPrivateKey)
{
	Sm2EcHandle *ecHandle = NULL;
	IppsGFpECState *pEC = NULL;
	int maxOutlen = 0;
	int pOutSize = 0;
	int nScalars = 2; // ippsGFpECDecryptSM2_Ext requires nScalars >= 2
	int pBufferSize = 0;
	Ipp8u* pScratchBuffer = NULL;
	IppStatus ipp_ret = ippStsNoErr;
	int ret = 0;

	do {
		// 1. Create ECC context for SM2
		ecHandle = new_ECC_sm2();
		if (ecHandle == NULL) {
			printf("Error: fail to create ecc context for decrypt\n");
			ret = -1;
			break;
		}
		pEC = ecHandle->pEC;

		// 2. Allocate plain text buffer
		maxOutlen = cipher_len + 1; // Conservative upper bound for plaintext
		*plain_text = (Ipp8u*)malloc(maxOutlen);
		if (*plain_text == NULL) {
			printf("Error: fail to allocate memory for plain text\n");
			ret = -1;
			break;
		}
		memset(*plain_text, 0, maxOutlen);
		
		// 3. Get scratch buffer size
		ipp_ret = ippsGFpECScratchBufferSize(nScalars, pEC, &pBufferSize);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to get the size of the scratch buffer\n");
			ret = -2;
			break;
		}
		pScratchBuffer = (Ipp8u*)malloc(pBufferSize);
		if (pScratchBuffer == NULL) {
			printf("Error: fail to allocate memory for the scratch buffer\n");
			ret = -3;
			break;
		}
		ipp_ret = ippsGFpECDecryptSM2_Ext(*plain_text, maxOutlen, &pOutSize, cipher_text, cipher_len, regPrivateKey, pEC, pScratchBuffer);
		if (ipp_ret != ippStsNoErr) {
			printf("Error: fail to decrypt.\n");
			ret = -4;
			break;
		}
		*plain_len = pOutSize;
	} while(0);

	SAFE_FREE_HEAP(pScratchBuffer, pBufferSize);
	free_ECC_sm2(ecHandle);

	return ret;
}

/* SM2 encrypt and decrypt (GM version, standard is GM/T 0003-2012) */
int ecall_sm2_encrypt_decrypt_gm(void)
{
	IppsBigNumState *regPrivateKey = NULL;
	IppsGFpECPoint *regPublicKey = NULL;
	IppsBigNumState *ephPrivateKey = NULL;
	IppsGFpECPoint *ephPublicKey = NULL;
	Ipp8u *cipher_text = NULL, *plain_text = NULL;
	int cipher_len = 0, plain_len = 0;
	int ret = 0;

	const char *message = "context need to be encrypted";
	int message_len = (int)strlen(message);

	do {
		// 1. Create regular private key and public key
		ret = sm2_key_generation(&regPrivateKey, &regPublicKey);
		if (ret != 0) {
			printf("Error: fail to generate regular private key and public key\n");
			ret = -2;
			break;
		}

		// 2. Generate ephemeral private and public key pairs
		ret = sm2_key_generation(&ephPrivateKey, &ephPublicKey);
		if (ret != 0) {
			printf("Error: fail to generate ephemeral private key and public key\n");
			ret = -3;
			break;
		}

		// 3. Encrypt
		ret = sm2_encrypt_gm(message, message_len, &cipher_text, &cipher_len, regPublicKey, ephPublicKey, ephPrivateKey);
		if (ret != 0) {
			printf("Error: fail to encrypt.\n");
			ret = -4;
			break;
		}

		// 4. Decrypt
		ret = sm2_decrypt_gm(cipher_text, cipher_len, &plain_text, &plain_len, regPrivateKey);
		if (ret != 0) {
			printf("Error: fail to decrypt.\n");
			ret = -5;
			break;
		}

		// 5. Compare decrypted message and original message
		if(strlen(message) != strlen((char*)plain_text) || memcmp(message, plain_text, strlen(message)) != 0)
		{
			printf("Error: decrypted message does not match original message!\n");
			ret = -6;
			break;
		}

	} while(0);

	SAFE_FREE(plain_text);
	SAFE_FREE(cipher_text);
	SAFE_FREE(ephPublicKey);
	SAEF_FREE_ECC_PRI_KEY(ephPrivateKey);
	SAFE_FREE(regPublicKey);
	SAEF_FREE_ECC_PRI_KEY(regPrivateKey);

	return ret;
}

/* Compute a SM3 digest of a message. */
int ecall_sm3(void)
{
	int ctxSize = 0;
	IppsHashState_rmf* pSM3 = NULL;
	IppStatus status = ippStsNoErr;
	unsigned char msg[] = "this is a test message";
	unsigned char digest[32] = "";
	unsigned char tag[32] = "";
	int ret = 0;

	do {
		// 1. Init
		// Get size of the SM3 context
		status = ippsHashGetSize_rmf(&ctxSize);
		if (status != ippStsNoErr) {
			printf("Error: fail to get size of SM3 context\n");
			ret = -1;
			break;
		}

		// Allocate the SM3 context
		pSM3 = (IppsHashState_rmf *)(malloc(ctxSize));
		if (pSM3 == NULL) {
			printf("Error: fail to allocate memory for SM3 context\n");
			ret = -2;
			break;
		}

		// Initialize the SM3 context
		status = ippsHashInit_rmf(pSM3, ippsHashMethod_SM3());
		if (status != ippStsNoErr) {
			printf("Error: fail to initialize SM3 context\n");
			ret = -3;
			break;
		}

		// 2. Update
		// Digest the message of specified length
		status = ippsHashUpdate_rmf(msg, (int)strlen((char *)msg), pSM3);
		if (status != ippStsNoErr) {
			printf("Error: fail to digest the message of specified length\n");
			ret = -4;
			break;
		}

		// 3. GetTag
		// Compute current SM3 digest value of the processed part of the message
		status = ippsHashGetTag_rmf(tag, sizeof(tag), pSM3);
		if (status != ippStsNoErr) {
			printf("Error: fail to compute current SM3 digest value of the processed part of the message\n");
			ret = -5;
			break;
		}

		// 4. Final
		// Complete computation of the SM3 digest value
		status = ippsHashFinal_rmf(digest, pSM3);
		if (status != ippStsNoErr) {
			printf("Error: fail to complete computation of the SM3 digest value\n");
			ret = -6;
			break;
		}		
	} while(0);

	//Release resource
	SAFE_FREE_HEAP(pSM3, ctxSize);

	return ret;
}

/* SM4 block cipher mode(CBC) of operation. */
int ecall_sm4_cbc()
{
	// Plain text
	unsigned char plainText[16] = {
		0xAA,0xAA,0xAA,0xAA,0xBB,0xBB,0xBB,0xBB,
		0xCC,0xCC,0xCC,0xCC,0xDD,0xDD,0xDD,0xDD
	};

	// Generate a SM4 random secret key
	unsigned char key[16] = {0};
	if (secure_rand((unsigned int*)key, 16) != 0) {
		printf("Error: fail to generate a SM4 random secret key\n");
		SAFE_FREE_STACK(key, 16);
		return -1;
	}

	// Generate a SM4 random initialization vector(iv)
	unsigned char iv[16] = {0};
	if (secure_rand((unsigned int*)iv, 16) != 0) {
		printf("Error: fail to generate a SM4 random initialization vector\n");
		SAFE_FREE_STACK(iv, 16);
		return -2;
	}

	unsigned char encryptedText[16] = {};
	unsigned char decryptedText[16] = {};

	int ctxSize = 0;
	IppsSMS4Spec* pSM4 = 0;
	IppStatus status = ippStsNoErr, status1 = ippStsNoErr, status2 = ippStsNoErr;
	int ret = 0;

	do {
		// 1. Get size needed for SM4 context structure
		status = ippsSMS4GetSize(&ctxSize);
		if (status != ippStsNoErr) {
			printf("Error: fail to get size of SM4 context\n");
			ret = -3;
			break;
		}

		// 2. Allocate memory for SM4 context structure
		pSM4 = (IppsSMS4Spec*)malloc(ctxSize);
		if (pSM4 == NULL) {
			printf("Error: fail to allocate memory for SM4 context\n");
			ret = -4;
			break;
		}

		// 3. Initialize SM4 context
		status = ippsSMS4Init(key, sizeof(key), pSM4, ctxSize);
		if (status != ippStsNoErr) {
			printf("Error: fail to initialize SM4 context\n");
			ret = -5;
			break;
		}

		// 4. CBC Encryption and decryption
		status1 = ippsSMS4EncryptCBC(plainText, encryptedText, sizeof(plainText), pSM4, iv);
		if (status1 != ippStsNoErr) {
			printf("Error: fail to encrypt the plaintext\n");
			ret = -6;
			break;
		}
		status2 = ippsSMS4DecryptCBC(encryptedText, decryptedText, sizeof(encryptedText), pSM4, iv);
		if (status2 != ippStsNoErr) {
			printf("Error: fail to decrypt the ciphertext\n");
			ret = -7;
			break;
		}

		// 5. Compare original and decrypted text
		if (memcmp(plainText, decryptedText, sizeof(plainText)) != 0) {
			printf("Error: decrypted text is different from plaintext\n");
			ret = -8;
			break;
		}
	} while (0);

	// 6. Remove secret and release resource
	// !!!Please clear secret including key/context related buffer/big number here!!!
	SAFE_FREE_HEAP(pSM4, ctxSize);
	SAFE_FREE_STACK(key, 16);
	SAFE_FREE_STACK(iv, 16);

	return ret;
}

/* SM4 counter mode(CTR) of operation. */
int ecall_sm4_ctr()
{
	// message to be encrypted
	unsigned char msg[] = "the message to be encrypted";

	// Generate a SM4 random secret key
	unsigned char key[16] = {0};
	if (secure_rand((unsigned int*)key, 16) != 0) {
		printf("Error: fail to generate a SM4 random secret key\n");
		SAFE_FREE_STACK(key, 16);
		return -1;
	}

	// Generate a SM4 random initial counter
	unsigned char ctr0[16] = {0};
	if (secure_rand((unsigned int*)ctr0, 16) != 0) {
		printf("Error: fail to generate a SM4 random initial counter\n");
		SAFE_FREE_STACK(ctr0, 16);
		return -2;
	}

	// counter
	unsigned char ctr[16];

	unsigned char etext[sizeof(msg)];
	unsigned char dtext[sizeof(etext)];

	int ctxSize = 0;
	IppsSMS4Spec* pSM4 = 0;
	IppStatus status = ippStsNoErr, status1 = ippStsNoErr, status2 = ippStsNoErr;
	int ret = 0;

	do {
		// 1. Get size needed for SM4 context structure
		status = ippsSMS4GetSize(&ctxSize);
		if (status != ippStsNoErr) {
			printf("Error: fail to get size of SM4 context\n");
			ret = -3;
			break;
		}

		// 2. Allocate memory for SM4 context structure
		pSM4 = (IppsSMS4Spec*)malloc(ctxSize);
		if (pSM4 == NULL) {
			printf("Error: fail to allocate memory for SM4 context\n");
			ret = -4;
			break;
		}

		// 3. Initialize SM4 context
		status = ippsSMS4Init(key, sizeof(key), pSM4, ctxSize);
		if (status != ippStsNoErr) {
			printf("Error: fail to initialize SM4 context\n");
			ret = -5;
			break;
		}

		// 4. Encryption and decryption
		// Initialize counter before encryption
		memcpy(ctr, ctr0, sizeof(ctr));
		// Encrypt message
		status1 = ippsSMS4EncryptCTR(msg, etext, sizeof(msg), pSM4, ctr, 128);
		if (status1 != ippStsNoErr) {
			printf("Erro: fail to encrypt the plaintext\n");
			ret = -6;
			break;
		}		
		// Initialize counter before decryption
		memcpy(ctr, ctr0, sizeof(ctr));
		// Decrypt message
		status2 = ippsSMS4DecryptCTR(etext, dtext, sizeof(etext), pSM4, ctr, 128);
		if (status2 != ippStsNoErr) {
			printf("Error: fail to decrypt the ciphertext\n");
			ret = -7;
			break;
		}

		// 5. Compare original message and decrypted text 
		if (memcmp(msg, dtext, sizeof(msg)) != 0) {
			printf("Error: decrypted text is different from plaintext\n");
			ret = -8;
			break;
		}
	} while (0);

	// 6. Remove secret and release resource
	// !!!Please clear secret including key/context related buffer/big number here!!!
	SAFE_FREE_HEAP(pSM4, ctxSize);
	SAFE_FREE_STACK(key, 16);
	SAFE_FREE_STACK(ctr0, 16);

	return ret;
}
