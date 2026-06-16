#include <ippcp.h>

#ifndef IPP_CALL
#   define IPP_CALL IPP_STDCALL
#endif

#define IPPFUN(type, name, arg) extern type IPP_CALL name arg

#ifndef NULL
#   ifdef __cplusplus
#       define NULL 0
#   else
#       define NULL ((void*)0)
#   endif
#endif

#if defined (_M_AMD64) || defined (__x86_64__)


#define AVX3I_FEATURES (ippCPUID_SHA | ippCPUID_AVX512VBMI | ippCPUID_AVX512VBMI2 | ippCPUID_AVX512IFMA | \
    ippCPUID_AVX512GFNI | ippCPUID_AVX512VAES | ippCPUID_AVX512VCLMUL)
#define AVX3X_FEATURES (ippCPUID_AVX512F | ippCPUID_AVX512CD | ippCPUID_AVX512VL | ippCPUID_AVX512BW | \
    ippCPUID_AVX512DQ)
#define APX_FEATURES   (AVX3I_FEATURES | ippCPUID_AVX10_2)

#ifdef __cplusplus
extern "C" {
#endif

IPPAPI(IppStatus, k1_ippsGFpECVerifyNR, (const IppsBigNumState* pMsgDigest, const IppsGFpECPoint* pRegPublic, const IppsBigNumState* pSignR, const IppsBigNumState* pSignS, IppECResult* pResult, IppsGFpECState* pEC, Ipp8u* pScratchBuffer))
IPPAPI(IppStatus, l9_ippsGFpECVerifyNR, (const IppsBigNumState* pMsgDigest, const IppsGFpECPoint* pRegPublic, const IppsBigNumState* pSignR, const IppsBigNumState* pSignS, IppECResult* pResult, IppsGFpECState* pEC, Ipp8u* pScratchBuffer))
IPPAPI(IppStatus, y8_ippsGFpECVerifyNR, (const IppsBigNumState* pMsgDigest, const IppsGFpECPoint* pRegPublic, const IppsBigNumState* pSignR, const IppsBigNumState* pSignS, IppECResult* pResult, IppsGFpECState* pEC, Ipp8u* pScratchBuffer))

IPPFUN(IppStatus, sgx_disp_ippsGFpECVerifyNR, (const IppsBigNumState* pMsgDigest, const IppsGFpECPoint* pRegPublic, const IppsBigNumState* pSignR, const IppsBigNumState* pSignS, IppECResult* pResult, IppsGFpECState* pEC, Ipp8u* pScratchBuffer))
{
    Ipp64u _features = ippcpGetEnabledCpuFeatures();

    if (AVX3I_FEATURES == (_features & AVX3I_FEATURES))
    {
        return k1_ippsGFpECVerifyNR(pMsgDigest, pRegPublic, pSignR, pSignS, pResult, pEC, pScratchBuffer);
    }
    if (ippCPUID_AVX2 == (_features & ippCPUID_AVX2))
    {
        return l9_ippsGFpECVerifyNR(pMsgDigest, pRegPublic, pSignR, pSignS, pResult, pEC, pScratchBuffer);
    }
    if (ippCPUID_SSE42 == (_features & ippCPUID_SSE42))
    {
        return y8_ippsGFpECVerifyNR(pMsgDigest, pRegPublic, pSignR, pSignS, pResult, pEC, pScratchBuffer);
    }
    return ippStsCpuNotSupportedErr;
}

#ifdef __cplusplus
}
#endif

#endif
