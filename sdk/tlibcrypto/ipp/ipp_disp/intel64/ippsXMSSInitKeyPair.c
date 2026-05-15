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

IPPAPI(IppStatus, k1_ippsXMSSInitKeyPair, (IppsXMSSAlgo OIDAlgo, IppsXMSSPrivateKeyState* pPrvKey, IppsXMSSPublicKeyState* pPubKey))
IPPAPI(IppStatus, l9_ippsXMSSInitKeyPair, (IppsXMSSAlgo OIDAlgo, IppsXMSSPrivateKeyState* pPrvKey, IppsXMSSPublicKeyState* pPubKey))
IPPAPI(IppStatus, y8_ippsXMSSInitKeyPair, (IppsXMSSAlgo OIDAlgo, IppsXMSSPrivateKeyState* pPrvKey, IppsXMSSPublicKeyState* pPubKey))

IPPFUN(IppStatus, sgx_disp_ippsXMSSInitKeyPair, (IppsXMSSAlgo OIDAlgo, IppsXMSSPrivateKeyState* pPrvKey, IppsXMSSPublicKeyState* pPubKey))
{
    Ipp64u _features = ippcpGetEnabledCpuFeatures();

    if (AVX3I_FEATURES == (_features & AVX3I_FEATURES))
    {
        return k1_ippsXMSSInitKeyPair(OIDAlgo, pPrvKey, pPubKey);
    }
    if (ippCPUID_AVX2 == (_features & ippCPUID_AVX2))
    {
        return l9_ippsXMSSInitKeyPair(OIDAlgo, pPrvKey, pPubKey);
    }
    if (ippCPUID_SSE42 == (_features & ippCPUID_SSE42))
    {
        return y8_ippsXMSSInitKeyPair(OIDAlgo, pPrvKey, pPubKey);
    }
    return ippStsCpuNotSupportedErr;
}

#ifdef __cplusplus
}
#endif

#endif
