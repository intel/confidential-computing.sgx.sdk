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

IPPAPI(IppStatus, k1_ippsMLDSA_Verify, (const Ipp8u* pMsg, const Ipp32s msgLen, const Ipp8u* pCtx, const Ipp32s ctxLen, const Ipp8u* pPubKey, const Ipp8u* pSign, int* pIsSignValid, IppsMLDSAState* pMLDSAState, Ipp8u* pScratchBuffer))
IPPAPI(IppStatus, l9_ippsMLDSA_Verify, (const Ipp8u* pMsg, const Ipp32s msgLen, const Ipp8u* pCtx, const Ipp32s ctxLen, const Ipp8u* pPubKey, const Ipp8u* pSign, int* pIsSignValid, IppsMLDSAState* pMLDSAState, Ipp8u* pScratchBuffer))
IPPAPI(IppStatus, y8_ippsMLDSA_Verify, (const Ipp8u* pMsg, const Ipp32s msgLen, const Ipp8u* pCtx, const Ipp32s ctxLen, const Ipp8u* pPubKey, const Ipp8u* pSign, int* pIsSignValid, IppsMLDSAState* pMLDSAState, Ipp8u* pScratchBuffer))

IPPFUN(IppStatus, sgx_disp_ippsMLDSA_Verify, (const Ipp8u* pMsg, const Ipp32s msgLen, const Ipp8u* pCtx, const Ipp32s ctxLen, const Ipp8u* pPubKey, const Ipp8u* pSign, int* pIsSignValid, IppsMLDSAState* pMLDSAState, Ipp8u* pScratchBuffer))
{
    Ipp64u _features = ippcpGetEnabledCpuFeatures();

    if (AVX3I_FEATURES == (_features & AVX3I_FEATURES))
    {
        return k1_ippsMLDSA_Verify(pMsg, msgLen, pCtx, ctxLen, pPubKey, pSign, pIsSignValid, pMLDSAState, pScratchBuffer);
    }
    if (ippCPUID_AVX2 == (_features & ippCPUID_AVX2))
    {
        return l9_ippsMLDSA_Verify(pMsg, msgLen, pCtx, ctxLen, pPubKey, pSign, pIsSignValid, pMLDSAState, pScratchBuffer);
    }
    if (ippCPUID_SSE42 == (_features & ippCPUID_SSE42))
    {
        return y8_ippsMLDSA_Verify(pMsg, msgLen, pCtx, ctxLen, pPubKey, pSign, pIsSignValid, pMLDSAState, pScratchBuffer);
    }
    return ippStsCpuNotSupportedErr;
}

#ifdef __cplusplus
}
#endif

#endif
