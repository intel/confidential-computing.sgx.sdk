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


#include <stdlib.h>
#include "sgx_uae_quote_ex.h"
#include "util.h"
#include "se_memcpy.h"
#include "sgx_read_rand.h"
#include "se_quote_internal.h"
#include "deriv.h"
#include "cpusvn_util.h"
#include "crypto_wrapper.h"
#include "../../../common/inc/sgx_error.h"


const static sgx_att_key_id_t g_epid_unlinkable_att_key_id = {
    {
        0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0xec, 0x15,
        0xb1, 0x07, 0x87, 0xd2, 0xf8, 0x46, 0x67, 0xce,
        0xb0, 0xb5, 0x98, 0xff, 0xc4, 0x4a, 0x1f, 0x1c,
        0xb8, 0x0f, 0x67, 0x0a, 0xae, 0x5d, 0xf9, 0xe8,
        0xfa, 0x9f, 0x63, 0x76, 0xe1, 0xf8, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    }
};


/* The report key is the same as BASE_REPORT_KEY in
   /trunk/sdk/simulation/tinst/deriv.cpp, which is used in simulation
   create_report and verify_report. deriv.cpp is used inside enclave.
   So only import this structure. */
static const uint8_t BASE_REPORT_KEY[] = {
    0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00,
    0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00,
};
// The hard-coded OwnerEpoch.
static const se_owner_epoch_t SIMU_OWNER_EPOCH_MSR = {
    0x54, 0x48, 0x49, 0x53, 0x49, 0x53, 0x4f, 0x57,
    0x4e, 0x45, 0x52, 0x45, 0x50, 0x4f, 0x43, 0x48,
};

//simulated QE ISVSVN
static const sgx_isv_svn_t QE_ISVSVN = 0XEF;
static const sgx_isv_svn_t PCE_ISVSVN = 0xEF;
static const sgx_uuid_t QE_VENDOR_ID = { 0x93, 0x9A, 0x72, 0x33, 0xF7, 0x9C, 0x4C, 0xA9, 0x94, 0x0A, 0x0D, 0xB3, 0x95, 0x7F, 0x06, 0x07 };

static sgx_status_t create_qe_report(const sgx_report_t *p_report,
                                    const sgx_quote_nonce_t* p_quote_nonce,
                                    const uint8_t* p_quote,
                                    uint32_t quote_size,
                                    const sgx_cpu_svn_t* cpusvn,
                                    sgx_report_t *p_qe_report)
{
    sgx_report_t temp_qe_report;
    // assemble REPORT
    memset(&temp_qe_report, 0, sizeof(sgx_report_t));
    //QE_REPORT.BODY.CPUSVN = CPUSVN
    if(memcpy_s(&temp_qe_report.body.cpu_svn,
                sizeof(temp_qe_report.body.cpu_svn),
                cpusvn, sizeof(sgx_cpu_svn_t)))
        return SGX_ERROR_UNEXPECTED;
    //ProdID same as QE
    temp_qe_report.body.isv_prod_id = 1;
    //set ISVSVN
    temp_qe_report.body.isv_svn = QE_ISVSVN;
    //QE_REPORT.BODY.ATTRIBUTES = 0x30000000000000001
    temp_qe_report.body.attributes.flags = SGX_FLAGS_INITTED;
    temp_qe_report.body.attributes.xfrm = SGX_XFRM_LEGACY;
    //QE_REPORT.BODY.MRENCLAVE = 64 0xEE bytes
    memset(&temp_qe_report.body.mr_enclave, 0xEE, sizeof(sgx_measurement_t));
    //QE_REPORT.BODY.MRSIGNER = random value
    if(SGX_SUCCESS != sgx_read_rand((uint8_t *)(&temp_qe_report.body.mr_signer),
                                    sizeof(sgx_measurement_t)))
        return SGX_ERROR_UNEXPECTED;
    //QE_REPORT.KEYID = <random>
    if(SGX_SUCCESS != sgx_read_rand((unsigned char *)&temp_qe_report.key_id,
                                    sizeof(sgx_key_id_t)))
        return SGX_ERROR_UNEXPECTED;

    //QE_REPORT.BODY.REPORTDATA = SHA256(NONCE || QUOTE)
    sgx_status_t sgx_ret = SGX_ERROR_UNEXPECTED;

    //prepare reprot_data
    size_t msg_size = sizeof(sgx_quote_nonce_t) + quote_size;
    uint8_t * p_msg = (uint8_t *)malloc(msg_size);
    if(!p_msg)
        return SGX_ERROR_OUT_OF_MEMORY;
    if(memcpy_s(p_msg, msg_size, p_quote_nonce, sizeof(sgx_quote_nonce_t)))
    {
        free(p_msg);
        return sgx_ret;
    }
    if(memcpy_s(p_msg + sizeof(sgx_quote_nonce_t), msg_size - sizeof(sgx_quote_nonce_t), p_quote, quote_size))
    {
        free(p_msg);
        return sgx_ret;
    }

    unsigned int report_data_len = sizeof(temp_qe_report.body.report_data);

    if(SGX_SUCCESS != (sgx_ret = sgx_EVP_Digest(EVP_sha256(), p_msg, (unsigned int)msg_size,
                    (uint8_t *)&temp_qe_report.body.report_data, &report_data_len)))
    {
        if(sgx_ret != SGX_ERROR_OUT_OF_MEMORY)
            sgx_ret = SGX_ERROR_UNEXPECTED;
        free(p_msg);
        return sgx_ret;
    }

    free(p_msg);

    /* calculate CMAC using the report key, same as BASE_REPORT_KEY in
       sdk/simulation/tinst/deriv.cpp */
    derivation_data_t   dd;
    memset(&dd, 0, sizeof(dd));
    dd.size = sizeof(dd_report_key_t);

    dd.key_name = SGX_KEYSELECT_REPORT;
    if(memcpy_s(&dd.ddrk.mrenclave,sizeof(dd.ddrk.mrenclave),
                &p_report->body.mr_enclave, sizeof(sgx_measurement_t)))
        return SGX_ERROR_UNEXPECTED;
    if(memcpy_s(&dd.ddrk.attributes, sizeof(dd.ddrk.attributes),
                &p_report->body.attributes, sizeof(sgx_attributes_t)))
        return SGX_ERROR_UNEXPECTED;
    if(memcpy_s(&dd.ddrk.csr_owner_epoch, sizeof(dd.ddrk.csr_owner_epoch),
                SIMU_OWNER_EPOCH_MSR, sizeof(se_owner_epoch_t)))
        return SGX_ERROR_UNEXPECTED;
    if(memcpy_s(&dd.ddrk.cpu_svn, sizeof(dd.ddrk.cpu_svn),
                cpusvn, sizeof(sgx_cpu_svn_t)))
        return SGX_ERROR_UNEXPECTED;
    if(memcpy_s(&dd.ddrk.key_id, sizeof(dd.ddrk.key_id),
                &temp_qe_report.key_id, sizeof(sgx_key_id_t)))
        return SGX_ERROR_UNEXPECTED;

    sgx_key_128bit_t tmp_report_key;
    if(SGX_SUCCESS != (sgx_ret = sgx_cmac128_msg(BASE_REPORT_KEY, dd.ddbuf, dd.size, &tmp_report_key)))
    {
        if(sgx_ret != SGX_ERROR_OUT_OF_MEMORY)
            sgx_ret = SGX_ERROR_UNEXPECTED;
        return sgx_ret;
    }

    // call cryptographic CMAC function
    // CMAC data are *NOT* including MAC and KEYID
    if(SGX_SUCCESS != (sgx_ret = sgx_cmac128_msg(tmp_report_key, (const uint8_t *)&temp_qe_report.body,
                    sizeof(temp_qe_report.body), &temp_qe_report.mac)))
    {
        if(sgx_ret != SGX_ERROR_OUT_OF_MEMORY)
            sgx_ret = SGX_ERROR_UNEXPECTED;
        return sgx_ret;
    }

    if(memcpy_s(p_qe_report, sizeof(*p_qe_report),
                &temp_qe_report, sizeof(temp_qe_report)))
    {
        sgx_ret = SGX_ERROR_UNEXPECTED;
    }
    return sgx_ret;
}

sgx_status_t SGXAPI sgx_select_att_key_id(const uint8_t *p_att_key_id_list, uint32_t att_key_id_list_size,
                                                   sgx_att_key_id_t *p_selected_key_id)
{
    if (NULL == p_selected_key_id)
        return SGX_ERROR_INVALID_PARAMETER;
    if (NULL == p_att_key_id_list && att_key_id_list_size != 0)
        return SGX_ERROR_INVALID_PARAMETER;
    if (NULL != p_att_key_id_list && att_key_id_list_size == 0)
        return SGX_ERROR_INVALID_PARAMETER;
    if(memcpy_s(p_selected_key_id, sizeof(*p_selected_key_id),
             &g_epid_unlinkable_att_key_id, sizeof(g_epid_unlinkable_att_key_id)))
    {
        return SGX_ERROR_UNEXPECTED;
    }
    return SGX_SUCCESS;
}

sgx_status_t SGXAPI sgx_init_quote_ex(const sgx_att_key_id_t* p_att_key_id,
                                            sgx_target_info_t *p_qe_target_info,
                                            size_t* p_pub_key_id_size,
                                            uint8_t* p_pub_key_id)
{
    if(NULL == p_pub_key_id_size || NULL == p_qe_target_info || NULL == p_att_key_id ||
        (NULL != p_pub_key_id && sizeof(uint32_t) != *p_pub_key_id_size))
        return SGX_ERROR_INVALID_PARAMETER;

    if(NULL == p_pub_key_id)
    {
        *p_pub_key_id_size = sizeof(uint32_t);
        return SGX_SUCCESS;
    }

    p_qe_target_info->attributes.flags = SGX_FLAGS_INITTED;
    p_qe_target_info->attributes.xfrm = SGX_XFRM_LEGACY;
    memset(&(p_qe_target_info->mr_enclave), 0xEE, sizeof(sgx_measurement_t));

    ((uint32_t *)p_pub_key_id)[0] = 0;

    return SGX_SUCCESS;
}

sgx_status_t SGXAPI sgx_get_quote_size_ex(const sgx_att_key_id_t *p_att_key_id,
                                                uint32_t* p_quote_size)
{
    if (NULL ==p_att_key_id || NULL == p_quote_size)
        return SGX_ERROR_INVALID_PARAMETER;
    *p_quote_size = static_cast<uint32_t>(sizeof(sgx_quote_t));
    return SGX_SUCCESS;
}

sgx_status_t SGXAPI  sgx_get_quote_ex(const sgx_report_t *p_app_report,
                                           const sgx_att_key_id_t *p_att_key_id,
                                           sgx_qe_report_info_t *p_qe_report_info,
                                           uint8_t *p_quote,
                                           uint32_t quote_size)
{
    if(NULL ==p_att_key_id || NULL == p_app_report || NULL == p_quote)
        return SGX_ERROR_INVALID_PARAMETER;

    sgx_status_t ret = SGX_SUCCESS;
    uint64_t required_buffer_size = sizeof(sgx_quote_t);
    sgx_cpu_svn_t cpusvn = {{0}};

    /* If the p_quote is not NULL, then we should make sure the buffer size is
    * correct. */
    if(quote_size < required_buffer_size){
        return SGX_ERROR_INVALID_PARAMETER;
    }

    sgx_quote_t * l_quote = (sgx_quote_t *)p_quote;

    if(SGX_SUCCESS != get_cpusvn(&cpusvn))
    {
        return SGX_ERROR_UNEXPECTED;
    }
    if(memcmp(&cpusvn, &((const sgx_report_t *)p_app_report)->body.cpu_svn,
              sizeof(sgx_cpu_svn_t)))
    {
        return SGX_ERROR_INVALID_PARAMETER;
    }

    /* Copy the data in the report into quote body. */
    memset(l_quote, 0xEE, quote_size);
    l_quote->version = 3;
    l_quote->sign_type = (uint16_t)2;
    l_quote->reserved = 0;
    l_quote->qe_svn = QE_ISVSVN;
    l_quote->pce_svn = PCE_ISVSVN;
    if(memcpy_s(&l_quote->qe_vendor_id, sizeof(sgx_uuid_t),
             &QE_VENDOR_ID, sizeof(QE_VENDOR_ID))){
        return SGX_ERROR_UNEXPECTED;
    }
    if(memcpy_s(&l_quote->report_body, sizeof(l_quote->report_body),
             &((const sgx_report_t *)p_app_report)->body, sizeof(sgx_report_body_t)))
    {
        return SGX_ERROR_UNEXPECTED;
    }
    l_quote->auth_data_len = (uint32_t)0;

    const sgx_quote_nonce_t *p_nonce = p_qe_report_info ? &p_qe_report_info->nonce:NULL;
    sgx_report_t *p_qe_report = p_qe_report_info ? &p_qe_report_info->qe_report:NULL;

    if(p_qe_report)
        ret = create_qe_report(p_app_report, p_nonce, (uint8_t*)l_quote,
                               quote_size, &cpusvn, p_qe_report);

    return ret;
} //sgx_get_quote_ex

sgx_status_t SGXAPI sgx_get_supported_att_key_id_num(uint32_t *p_att_key_id_num)
{
    if (NULL == p_att_key_id_num)
        return SGX_ERROR_INVALID_PARAMETER;
    *p_att_key_id_num = 1;
    return SGX_SUCCESS;
}

sgx_status_t SGXAPI sgx_get_supported_att_key_ids(sgx_att_key_id_ext_t *p_att_key_id_list, uint32_t att_key_id_num)
{
    if (NULL == p_att_key_id_list || 1 != att_key_id_num)
        return SGX_ERROR_INVALID_PARAMETER;
    if (memcpy_s(p_att_key_id_list, sizeof(*p_att_key_id_list),
        &g_epid_unlinkable_att_key_id, sizeof(g_epid_unlinkable_att_key_id)))
    {
        return SGX_ERROR_UNEXPECTED;
    }
    return SGX_SUCCESS;
}
