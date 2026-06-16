/*
 * Copyright(c) 2011-2026 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

/**
 * File: sgx_dcap_ql_wrapper_forward_decls.h
 *
 * Description: Definitions and prototypes for SGX's quote library for use in the DCAP SDK (-lsgx_dcap_ql)
 *
 * @warning This file freezes DCAP API at libsgx-dcap-ql-dev v1.26 (duplicated definition, to avoid a circular dependency).
 *
 * Source API is available at "QuoteGeneration/quote_wrapper/ql/inc/sgx_dcap_ql_wrapper.h".
 * In case of breaking API contract changes, please make sure to keep the two files consistent.
 *
 */

#ifndef _SGX_DCAP_QL_WRAPPER_FORWARD_DECLS_H_
#define _SGX_DCAP_QL_WRAPPER_FORWARD_DECLS_H_


#if defined(__cplusplus)
extern "C" {
#endif

#include "sgx_report.h"
#include "sgx_ql_lib_common.h"

/**
 * !!!!!!!
 * @warning This definition is duplicated for the purposes of utls.
 *        Refer to DCAP-side header (sgx_dcap_ql_wrapper.h) for the actual definition of this function!
 *
 * The definitions MUST be kept consistent between this file and the DCAP-side header (sgx_dcap_ql_wrapper.h).
 * !!!!!!!
 */
quote3_error_t sgx_qe_get_target_info(sgx_target_info_t *p_qe_target_info);

/**
 * !!!!!!!
 * @warning This definition is duplicated for the purposes of utls.
 *        Refer to DCAP-side header (sgx_dcap_ql_wrapper.h) for the actual definition of this function!
 *
 * The definitions MUST be kept consistent between this file and the DCAP-side header (sgx_dcap_ql_wrapper.h).
 * !!!!!!!
 */
quote3_error_t sgx_qe_get_quote_size(uint32_t *p_quote_size);

/**
 * !!!!!!!
 * @warning This definition is duplicated for the purposes of utls.
 *        Refer to DCAP-side header (sgx_dcap_ql_wrapper.h) for the actual definition of this function!
 *
 * The definitions MUST be kept consistent between this file and the DCAP-side header (sgx_dcap_ql_wrapper.h).
 * !!!!!!!
 */
quote3_error_t sgx_qe_get_quote(const sgx_report_t *p_app_report,
                                uint32_t quote_size,
                                uint8_t *p_quote);

#if defined(__cplusplus)
}
#endif

#endif /* !_SGX_DCAP_QL_WRAPPER_FORWARD_DECLS_H_ */
