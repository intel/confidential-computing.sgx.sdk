/*
 * Copyright(c) 2011-2026 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

/**
 * File: tdx_attest_forward_decls.h
 *
 * Description: API definitions for TDX Attestation library (-ltdx_attest)
 *
 * @warning This file freezes DCAP API at libtdx-attest-dev v1.26 (duplicated definition, to avoid a circular dependency).
 *
 * Source API is available at "QuoteGeneration/quote_wrapper/tdx_attest/tdx_attest.h".
 * In case of breaking API contract changes, please make sure to keep the two files consistent.
 *
 */

#ifndef _TDX_ATTEST_FORWARD_DECLS_H_
#define _TDX_ATTEST_FORWARD_DECLS_H_
#include <stdint.h>

typedef enum _tdx_attest_error_t {
    TDX_ATTEST_SUCCESS = 0x0000,                        ///< Success
    TDX_ATTEST_ERROR_UNEXPECTED = 0x0001,               ///< Unexpected error
    TDX_ATTEST_ERROR_INVALID_PARAMETER = 0x0002,        ///< The parameter is incorrect
    TDX_ATTEST_ERROR_OUT_OF_MEMORY = 0x0003,            ///< Not enough memory is available to complete this operation
    // (...)
} tdx_attest_error_t;

#pragma pack(push, 1)

#define TDX_UUID_SIZE 16
typedef struct _tdx_uuid_t
{
    uint8_t d[TDX_UUID_SIZE];
} tdx_uuid_t;

#define TDX_REPORT_DATA_SIZE 64
typedef struct _tdx_report_data_t
{
    uint8_t d[TDX_REPORT_DATA_SIZE];
} tdx_report_data_t;

#pragma pack(pop)

#if defined(__cplusplus)
extern "C" {
#endif

/**
 * !!!!!!!
 * @warning This definition is duplicated for the purposes of ttls.
 *        Refer to DCAP-side header (tdx_attest.h) for the actual definition of this function!
 *
 * The definitions MUST be kept consistent between this file and the DCAP-side header (tdx_attest.h).
 * !!!!!!!
 */
tdx_attest_error_t tdx_att_get_quote(
    const tdx_report_data_t *p_tdx_report_data,
    const tdx_uuid_t att_key_id_list[],
    uint32_t list_size,
    tdx_uuid_t *p_att_key_id,
    uint8_t **pp_quote,
    uint32_t *p_quote_size,
    uint32_t flags);

// /**
//  * @brief Free the Quote buffer allocated by tdx_att_get_quote.
//  *
//  * @param p_quote [in] The value of *p_quote returned by tdx_att_get_quote.
//  * @return TDX_ATTEST_SUCCESS: Successfully freed the p_quote.
//  */
tdx_attest_error_t tdx_att_free_quote(
     uint8_t *p_quote);

#if defined(__cplusplus)
}
#endif

#endif // _TDX_ATTEST_FORWARD_DECLS_H_
