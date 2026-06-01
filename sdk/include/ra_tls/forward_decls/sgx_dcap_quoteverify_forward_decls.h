/*
 * Copyright(c) 2011-2026 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

/**
 * File: sgx_dcap_quoteverify_forward_decls.h
 *
 * Description: API definitions for SGX DCAP Quote Verification library  (-lsgx_dcap_quoteverify)
 *
 * @warning This file freezes DCAP API at libsgx-dcap-quote-verify-dev v1.26 (duplicated definition, to avoid a circular dependency).
 *
 * Source API is available at "QuoteVerification/dcap_quoteverify/inc/sgx_dcap_quoteverify.h".
 * In case of breaking API contract changes, please make sure to keep the two files consistent.
 *
 */

#ifndef _SGX_DCAP_QV_FORWARD_DECLS_H_
#define _SGX_DCAP_QV_FORWARD_DECLS_H_

#include "sgx_qve_header.h"
#include "sgx_ql_quote.h"

#if defined(__cplusplus)
extern "C" {
#endif

/**
 * !!!!!!!
 * @warning This definition is duplicated for the purposes of utls.
 *        Refer to DCAP-side header (sgx_dcap_quoteverify.h) for the actual definition of this function!
 *
 * The definitions MUST be kept consistent between this file and the DCAP-side header (sgx_dcap_quoteverify.h).
 * !!!!!!
 */
quote3_error_t sgx_qv_get_quote_supplemental_data_size(uint32_t *p_data_size);


/**
 * !!!!!!!
 * @warning This definition is duplicated for the purposes of utls.
 *        Refer to DCAP-side header (sgx_dcap_quoteverify.h) for the actual definition of this function!
 *
 * The definitions MUST be kept consistent between this file and the DCAP-side header (sgx_dcap_quoteverify.h).
 * !!!!!!!
 */
quote3_error_t sgx_qv_verify_quote(
    const uint8_t *p_quote,
    uint32_t quote_size,
    const sgx_ql_qve_collateral_t *p_quote_collateral,
    const time_t expiration_check_date,
    uint32_t *p_collateral_expiration_status,
    sgx_ql_qv_result_t *p_quote_verification_result,
    sgx_ql_qe_report_info_t *p_qve_report_info,
    uint32_t supplemental_data_size,
    uint8_t *p_supplemental_data);

#if defined(__cplusplus)
}
#endif

#endif /* !_SGX_DCAP_QV_FORWARD_DECLS_H_*/
